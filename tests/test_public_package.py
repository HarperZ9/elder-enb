from __future__ import annotations

import csv
import hashlib
import importlib.util
import io
import os
import struct
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PACKAGE_SCRIPT = ROOT / "scripts" / "package.py"


def load_package_module():
    spec = importlib.util.spec_from_file_location(
        "elder_public_package", PACKAGE_SCRIPT
    )
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {PACKAGE_SCRIPT}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


package = load_package_module()


def _git(root: Path, *arguments: str) -> str:
    return subprocess.run(
        ("git", "-C", str(root), *arguments),
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


def _native_parameter_contract() -> bytes:
    rows = csv.DictReader(
        io.StringIO(
            (ROOT / "native" / "schema" / "elder-native-parameters.csv").read_text(
                encoding="utf-8"
            )
        )
    )
    hlsl_types = {"bool": "bool", "float": "float", "color3": "float3"}
    lines = [
        "#ifndef ELDER_NATIVE_PARAMETERS_FXH",
        "#define ELDER_NATIVE_PARAMETERS_FXH",
    ]
    for row in rows:
        symbol = row["symbol"]
        hlsl_type = hlsl_types[row["type"]]
        lines.extend(
            (
                f"{hlsl_type} {symbol};",
                f"{hlsl_type} ElderNativeSanitize_{symbol}() {{ return {symbol}; }}",
                f"bool ElderNativeActive_{symbol}() {{ return true; }}",
            )
        )
    lines.append("#endif")
    return ("\n".join(lines) + "\n").encode("utf-8")


def _amd64_elder_runtime() -> bytes:
    data = bytearray(512)
    data[0:2] = b"MZ"
    struct.pack_into("<I", data, 0x3C, 0x80)
    data[0x80:0x84] = b"PE\0\0"
    struct.pack_into("<H", data, 0x84, 0x8664)
    struct.pack_into("<H", data, 0x94, 0xF0)
    struct.pack_into("<H", data, 0x96, 0x2022)
    struct.pack_into("<H", data, 0x98, 0x20B)
    data.extend(
        b"ElderRuntimeFramePulse\0"
        b"ElderRuntimeRoomLight\0"
        b"ElderRuntimeExposureColor\0"
        b"ElderRuntimeStatus\0"
    )
    return bytes(data)


def _runtime_receipt(runtime_data: bytes, runtime_core_root: Path) -> bytes:
    lock = dict(
        line.split("=", 1)
        for line in (ROOT / "native" / "runtime" / "enb-runtime-core.lock")
        .read_text(encoding="utf-8")
        .splitlines()
        if line
    )
    return (
        "schema=ELDER_RUNTIME_RECEIPT_V1\n"
        "runtime_file=ElderENBRuntime.dllplugin\n"
        f"runtime_sha256={hashlib.sha256(runtime_data).hexdigest()}\n"
        f"elder_revision={_git(ROOT, 'rev-parse', 'HEAD')}\n"
        f"elder_runtime_tree={_git(ROOT, 'rev-parse', 'HEAD:native/runtime')}\n"
        f"runtime_core_repository={lock['repository']}\n"
        f"runtime_core_revision={_git(runtime_core_root, 'rev-parse', 'HEAD')}\n"
    ).encode("ascii")


class ElderPublicPackageTests(unittest.TestCase):
    def test_default_runtime_core_root_finds_the_shared_corpus_checkout(self) -> None:
        expected = Path(r"C:\dev\enb-runtime-core").resolve()
        if expected.is_dir():
            self.assertEqual(expected, package.default_runtime_core_root(ROOT))

    def test_forbidden_member_paths_are_rejected(self) -> None:
        forbidden_paths = (
            "Root/enbseries/d3d11.dll",
            "Root/enbseries/enbhost.exe",
            "Optional-EotE-Compositor/enbeffect.fx",
            "Root/enbseries/Addons/Effect_ColorGrading.fxh",
            "Private/reversal-notes.txt",
            "Protected/plugin.bin",
            "Build/Release/Elder.pdb",
            "RC/compiler-output.cso",
            "Tests/shader-probe.exe",
            "Root/enbseries/.env",
            "Native/KiLoader.dllplugin",
            "GPL/sky-mesh/COPYING",
        )
        for member_path in forbidden_paths:
            with self.subTest(member_path=member_path):
                with self.assertRaises(package.PackageError):
                    package.reject_forbidden_members({member_path: b"fixture"})

    def test_secret_material_is_rejected(self) -> None:
        secret = b"-----BEGIN PRIVATE KEY-----\nfixture\n-----END PRIVATE KEY-----\n"
        with self.assertRaises(package.PackageError):
            package.reject_forbidden_members({"Docs/accidental.txt": secret})

    def test_only_the_elder_runtime_binary_name_is_accepted(self) -> None:
        package.reject_forbidden_members(
            {"Root/enbseries/ElderENBRuntime.dllplugin": b"MZfixture"}
        )
        with self.assertRaises(package.PackageError):
            package.reject_forbidden_members(
                {"Root/enbseries/OtherRuntime.dllplugin": b"MZfixture"}
            )

    def test_synthetic_mz_runtime_is_rejected(self) -> None:
        with self.assertRaises(package.PackageError):
            package.validate_runtime_plugin(b"MZfixture")

    def test_incomplete_native_parameter_contract_is_rejected(self) -> None:
        incomplete = (
            b"#ifndef ELDER_NATIVE_PARAMETERS_FXH\n"
            b"#define ELDER_NATIVE_PARAMETERS_FXH\n"
            b"bool ElderMasterEnabled;\n"
            b"#endif\n"
        )
        with self.assertRaises(package.PackageError):
            package.validate_native_parameters(ROOT, incomplete)

    def test_unlocked_runtime_core_root_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory(prefix="elder-fake-core-") as temporary:
            fake_core = Path(temporary)
            (fake_core / "CMakeLists.txt").write_text(
                "cmake_minimum_required(VERSION 4.0)\n"
            )
            (fake_core / "LICENSE").write_text("MIT License\n")
            with self.assertRaises(package.PackageError):
                package.validate_runtime_core(ROOT, fake_core)

    def test_allowlisted_source_symlink_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory(prefix="elder-source-link-") as temporary:
            temporary_root = Path(temporary)
            source_root = temporary_root / "source"
            source_root.mkdir()
            outside = temporary_root / "outside.txt"
            outside.write_text("external bytes", encoding="utf-8")
            link = source_root / "README.md"
            try:
                os.symlink(outside, link)
            except OSError as error:
                self.skipTest(f"symlink creation unavailable: {error}")
            with self.assertRaises(package.PackageError):
                package.read_public_source(source_root, Path("README.md"), "fixture")

    def test_source_payload_has_exact_shader_preset_and_media_boundaries(self) -> None:
        with tempfile.TemporaryDirectory(prefix="elder-source-package-") as temporary:
            members = package.build_source_payload(ROOT, Path(temporary))

        stage_members = [
            path
            for path in members
            if path.startswith("Root/enbseries/") and path.endswith(".fx")
        ]
        include_members = [
            path
            for path in members
            if path.startswith("Root/enbseries/elder/") and path.endswith(".fxh")
        ]
        preset_members = [path for path in members if path.startswith("Presets/")]
        media_members = [
            path
            for path in members
            if path.startswith("Media/Nexus/") and path.endswith(".png")
        ]

        self.assertEqual(9, len(stage_members))
        self.assertEqual(15, len(include_members))
        self.assertEqual(55, len(preset_members))
        self.assertEqual(3, len(media_members))
        self.assertNotIn("Root/enbseries/ElderENBRuntime.dllplugin", members)
        package.reject_forbidden_members(members)

    def test_two_release_builds_are_byte_identical_and_self_describing(self) -> None:
        with tempfile.TemporaryDirectory(prefix="elder-release-package-") as temporary:
            temporary_root = Path(temporary)
            native_parameters = temporary_root / "ElderNativeParameters.fxh"
            native_parameters.write_bytes(_native_parameter_contract())
            runtime_plugin = temporary_root / "ElderENBRuntime.dllplugin"
            runtime_data = _amd64_elder_runtime()
            runtime_plugin.write_bytes(runtime_data)
            runtime_receipt = temporary_root / "ElderENBRuntime.dllplugin.receipt"
            runtime_core_root = package.default_runtime_core_root(ROOT)
            if not (runtime_core_root / ".git").exists():
                self.skipTest("pinned enb-runtime-core checkout is unavailable")
            runtime_receipt.write_bytes(
                _runtime_receipt(runtime_data, runtime_core_root)
            )

            first = package.build_release(
                source_root=ROOT,
                output_dir=temporary_root / "first",
                work_dir=temporary_root / "work-first",
                native_parameters=native_parameters,
                runtime_plugin=runtime_plugin,
                runtime_receipt=runtime_receipt,
                runtime_core_root=runtime_core_root,
            )
            second = package.build_release(
                source_root=ROOT,
                output_dir=temporary_root / "second",
                work_dir=temporary_root / "work-second",
                native_parameters=native_parameters,
                runtime_plugin=runtime_plugin,
                runtime_receipt=runtime_receipt,
                runtime_core_root=runtime_core_root,
            )

            self.assertEqual(first.archive.read_bytes(), second.archive.read_bytes())
            self.assertEqual(first.checksum.read_bytes(), second.checksum.read_bytes())
            verified = package.verify_archive(first.archive)
            self.assertEqual(first.sha256, verified.sha256)
            package.verify_checksum_sidecar(first.archive)
            first.checksum.write_text(
                f"{'0' * 64}  {package.ARCHIVE_NAME}\n", encoding="ascii"
            )
            with self.assertRaises(package.PackageError):
                package.verify_checksum_sidecar(first.archive)

            with zipfile.ZipFile(first.archive) as archive:
                names = archive.namelist()
                self.assertEqual(sorted(names), names)
                self.assertEqual(len(names), len(set(names)))
                self.assertTrue(
                    all(
                        info.date_time == package.FIXED_TIMESTAMP
                        for info in archive.infolist()
                    )
                )
                self.assertIn("MANIFEST.sha256", names)
                self.assertIn("Root/enbseries/ElderENBRuntime.dllplugin", names)
                self.assertIn("Docs/ElderENBRuntime.receipt", names)
                self.assertIn("Docs/ThirdParty/enb-runtime-core-LICENSE", names)
                self.assertIn("Docs/ThirdParty/enb-runtime-core-NOTICE.md", names)
                manifest_lines = (
                    archive.read("MANIFEST.sha256").decode("ascii").splitlines()
                )
                self.assertEqual(len(names) - 1, len(manifest_lines))
                manifest_paths = [line.split("  ", 1)[1] for line in manifest_lines]
                self.assertEqual(sorted(manifest_paths), manifest_paths)


if __name__ == "__main__":
    unittest.main()
