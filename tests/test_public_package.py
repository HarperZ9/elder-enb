from __future__ import annotations

import importlib.util
import tempfile
import unittest
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PACKAGE_SCRIPT = ROOT / "scripts" / "package.py"


def load_package_module():
    spec = importlib.util.spec_from_file_location("elder_public_package", PACKAGE_SCRIPT)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {PACKAGE_SCRIPT}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


package = load_package_module()


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
            native_parameters.write_text(
                "#ifndef ELDER_NATIVE_PARAMETERS_FXH\n"
                "#define ELDER_NATIVE_PARAMETERS_FXH\n"
                "bool ElderMasterEnabled = true;\n"
                "bool ElderNativeSanitize_ElderMasterEnabled() { return true; }\n"
                "#endif\n",
                encoding="utf-8",
            )
            runtime_plugin = temporary_root / "ElderENBRuntime.dllplugin"
            runtime_plugin.write_bytes(b"MZ\x00\x00Elder ENB Runtime fixture")
            runtime_core_root = temporary_root / "enb-runtime-core"
            runtime_core_root.mkdir()
            (runtime_core_root / "LICENSE").write_bytes((ROOT / "LICENSE").read_bytes())

            first = package.build_release(
                source_root=ROOT,
                output_dir=temporary_root / "first",
                work_dir=temporary_root / "work-first",
                native_parameters=native_parameters,
                runtime_plugin=runtime_plugin,
                runtime_core_root=runtime_core_root,
            )
            second = package.build_release(
                source_root=ROOT,
                output_dir=temporary_root / "second",
                work_dir=temporary_root / "work-second",
                native_parameters=native_parameters,
                runtime_plugin=runtime_plugin,
                runtime_core_root=runtime_core_root,
            )

            self.assertEqual(first.archive.read_bytes(), second.archive.read_bytes())
            self.assertEqual(first.checksum.read_bytes(), second.checksum.read_bytes())
            verified = package.verify_archive(first.archive, require_runtime=True)
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
                self.assertTrue(all(info.date_time == package.FIXED_TIMESTAMP for info in archive.infolist()))
                self.assertIn("MANIFEST.sha256", names)
                self.assertIn("Root/enbseries/ElderENBRuntime.dllplugin", names)
                self.assertIn("Docs/ThirdParty/enb-runtime-core-LICENSE", names)
                self.assertIn("Docs/ThirdParty/enb-runtime-core-NOTICE.md", names)
                manifest_lines = archive.read("MANIFEST.sha256").decode("ascii").splitlines()
                self.assertEqual(len(names) - 1, len(manifest_lines))
                manifest_paths = [line.split("  ", 1)[1] for line in manifest_lines]
                self.assertEqual(sorted(manifest_paths), manifest_paths)


if __name__ == "__main__":
    unittest.main()
