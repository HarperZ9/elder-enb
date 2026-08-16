#!/usr/bin/env python3
"""Build and verify the strict Elder ENB public release archive.

The public package is an allowlist, not a filtered copy of a staging tree.
Every archive member is selected explicitly, every selected byte is hashed in
``MANIFEST.sha256``, and every ZIP metadata field relevant to reproducibility is
fixed. Source-only validation is available while the Elder runtime plugin is
being integrated; it never emits a release-named archive.
"""
from __future__ import annotations

import argparse
import hashlib
import re
import shutil
import subprocess
import zipfile
from pathlib import Path, PurePosixPath
from typing import Mapping, NamedTuple, Sequence


ROOT = Path(__file__).resolve().parent.parent
VERSION = "1.0.0"
PACKAGE_NAME = f"Elder-ENB-{VERSION}-win64"
ARCHIVE_NAME = f"{PACKAGE_NAME}.zip"
FIXED_TIMESTAMP = (2000, 1, 1, 0, 0, 0)

STAGE_FILES = (
    "enbeffectprepass.fx",
    "enbdepthoffield.fx",
    "enbbloom.fx",
    "enbadaptation.fx",
    "enblens.fx",
    "enbeffect.fx",
    "enbeffectpostpass.fx",
    "enbsunsprite.fx",
    "enbunderwater.fx",
)

SUPPORT_INCLUDE_FILES = (
    "ElderAdaptation.fxh",
    "ElderBloom.fxh",
    "ElderDepthOfField.fxh",
    "ElderHostCapabilities.fxh",
    "ElderLens.fxh",
    "ElderPipelineCommon.fxh",
    "ElderPostFinish.fxh",
    "ElderPrepassCore.fxh",
    "ElderQuality.fxh",
    "ElderRuntimeParameters.fxh",
    "ElderScreenSpace.fxh",
    "ElderStageParameters.fxh",
    "ElderSunSprite.fxh",
    "ElderTier.fxh",
    "ElderUnderwater.fxh",
)

TIER_NAMES = ("performance", "balanced", "quality", "ultra", "cinematic")
TIER_LABELS = ("Performance", "Balanced", "Quality", "Ultra", "Cinematic")
PRESET_METADATA_FILE = "elder-quality.ini"
TIER_OVERRIDE_PATH = PurePosixPath("enbseries/elder/ElderTier.fxh")

STAGE_UI_PREFIXES = {
    "enbeffectprepass.fx": "[Elder 10] Prepass |",
    "enbdepthoffield.fx": "[Elder 20] Depth of Field |",
    "enbbloom.fx": "[Elder 30] Bloom |",
    "enbadaptation.fx": "[Elder 40] Adaptation |",
    "enblens.fx": "[Elder 50] Lens |",
    "enbeffect.fx": "[Elder 60] Main Effect |",
    "enbeffectpostpass.fx": "[Elder 70] Postpass |",
    "enbsunsprite.fx": "[Elder 80] Sun Sprite |",
    "enbunderwater.fx": "[Elder 90] Underwater |",
}

DOCUMENT_FILES = (
    ("README.md", "Docs/README.md"),
    ("LICENSE", "Docs/LICENSE"),
    ("CREDITS-AND-PROVENANCE.md", "Docs/CREDITS-AND-PROVENANCE.md"),
    ("THIRD_PARTY_NOTICES.md", "Docs/THIRD_PARTY_NOTICES.md"),
    ("native/NOTICE.md", "Docs/NATIVE-NOTICE.md"),
    ("docs/ARCHITECTURE.md", "Docs/ARCHITECTURE.md"),
    ("docs/release-validation.md", "Docs/RELEASE-VALIDATION.md"),
    ("project-docs/NEXUS-PAGE.md", "Docs/NEXUS-PAGE.md"),
    ("config/quality-tiers.csv", "Docs/quality-tiers.csv"),
    ("media/nexus/README.md", "Media/Nexus/README.md"),
)

MEDIA_FILES = (
    "elder-enb-nexus-header-1600x900.png",
    "elder-enb-nexus-header-3200x1800.png",
    "elder-enb-nexus-thumbnail-1400x1400.png",
)

RUNTIME_MEMBER = "Root/enbseries/ElderENBRuntime.dllplugin"
NATIVE_PARAMETERS_MEMBER = "Root/enbseries/ElderNativeParameters.fxh"
RUNTIME_CORE_LICENSE_MEMBER = "Docs/ThirdParty/enb-runtime-core-LICENSE"
RUNTIME_CORE_NOTICE_MEMBER = "Docs/ThirdParty/enb-runtime-core-NOTICE.md"
MANIFEST_MEMBER = "MANIFEST.sha256"

FORBIDDEN_COMPONENTS = frozenset(
    {
        ".git",
        ".scratch",
        "addons",
        "build",
        "compiler",
        "compilers",
        "eote",
        "gpl",
        "out",
        "private",
        "protected",
        "rc",
        "recovered",
        "scratch",
        "sky-mesh",
        "sky_mesh",
        "skymesh",
        "temp",
        "tests",
        "test",
        "tmp",
    }
)

FORBIDDEN_NAME_MARKERS = (
    "aelas",
    "elif",
    "evlas",
    "kiloader",
    "kitsuune",
    "kreate",
    "lonelykitsuune",
    "nativeeditorid",
    "weatherlists",
)

FORBIDDEN_BINARY_SUFFIXES = frozenset(
    {
        ".7z",
        ".asm",
        ".bin",
        ".cso",
        ".dll",
        ".exe",
        ".exp",
        ".ilk",
        ".lib",
        ".obj",
        ".pdb",
        ".sys",
        ".zip",
    }
)

FORBIDDEN_ENB_BINARY_NAMES = frozenset(
    {
        "d3d11.dll",
        "d3dcompiler_46e.dll",
        "enbhost.exe",
        "enbseries.dll",
    }
)

SECRET_PATTERNS = (
    re.compile(rb"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----"),
    re.compile(rb"AKIA[0-9A-Z]{16}"),
    re.compile(rb"gh[pousr]_[A-Za-z0-9]{30,}"),
    re.compile(rb"xox[baprs]-[A-Za-z0-9-]{20,}"),
    re.compile(rb"sk-[A-Za-z0-9_-]{20,}"),
)


class PackageError(RuntimeError):
    """A public-release boundary was violated."""


class ReleaseArtifacts(NamedTuple):
    archive: Path
    checksum: Path
    sha256: str
    file_count: int


class VerificationResult(NamedTuple):
    sha256: str
    file_count: int


def _read_required(path: Path, description: str) -> bytes:
    if not path.is_file():
        raise PackageError(f"missing {description}: {path}")
    data = path.read_bytes()
    if not data:
        raise PackageError(f"empty {description}: {path}")
    return data


def _reset_owned_directory(path: Path, owner: Path) -> None:
    resolved_owner = owner.resolve()
    resolved_path = path.resolve()
    if resolved_path == resolved_owner or resolved_owner not in resolved_path.parents:
        raise PackageError(f"refusing to reset path outside package work root: {path}")
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True)


def _validate_source_inventory(source_root: Path) -> None:
    actual_stages = {
        path.name for path in (source_root / "shaders").glob("*.fx") if path.is_file()
    }
    expected_stages = set(STAGE_FILES)
    if actual_stages != expected_stages:
        raise PackageError(
            "public stage inventory changed; update the explicit release boundary: "
            f"missing={sorted(expected_stages - actual_stages)}, "
            f"unexpected={sorted(actual_stages - expected_stages)}"
        )

    actual_includes = {
        path.name
        for path in (source_root / "shaders" / "elder").glob("*.fxh")
        if path.is_file()
    }
    expected_includes = set(SUPPORT_INCLUDE_FILES)
    if actual_includes != expected_includes:
        raise PackageError(
            "public include inventory changed; update the explicit release boundary: "
            f"missing={sorted(expected_includes - actual_includes)}, "
            f"unexpected={sorted(actual_includes - expected_includes)}"
        )


def _run_preset_generator(source_root: Path, output_dir: Path) -> None:
    command = (
        "cmake",
        f"-DELDER_SOURCE_DIR={source_root}",
        f"-DELDER_OUTPUT_DIR={output_dir}",
        "-P",
        str(source_root / "cmake" / "GenerateElderQualityPresets.cmake"),
    )
    result = subprocess.run(
        command,
        cwd=source_root,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise PackageError(
            "quality-preset generation failed\n"
            f"stdout:\n{result.stdout}\n"
            f"stderr:\n{result.stderr}"
        )


def _expected_raw_preset_paths() -> set[str]:
    expected: set[str] = set()
    for tier in TIER_NAMES:
        expected.add(f"{tier}/{PRESET_METADATA_FILE}")
        expected.add(f"{tier}/{TIER_OVERRIDE_PATH.as_posix()}")
        expected.update(f"{tier}/{stage}.ini" for stage in STAGE_FILES)
    return expected


def _parse_ini(path: Path, expected_section: str) -> dict[str, str]:
    lines = path.read_text(encoding="utf-8").splitlines()
    section_lines = [line for line in lines if line.startswith("[") and line.endswith("]")]
    if section_lines != [expected_section]:
        raise PackageError(
            f"preset {path} must contain exactly section {expected_section}; "
            f"found {section_lines}"
        )

    parsed: dict[str, str] = {}
    for line in lines:
        if not line or line.startswith(";") or (line.startswith("[") and line.endswith("]")):
            continue
        if "=" not in line:
            raise PackageError(f"malformed preset line in {path}: {line}")
        key, value = line.split("=", 1)
        if key in parsed:
            raise PackageError(f"duplicate preset key in {path}: {key}")
        if not (
            value in {"true", "false"}
            or re.fullmatch(r"-?[0-9]+(?:\.[0-9]+)?", value)
        ):
            raise PackageError(f"invalid preset value in {path}: {key}={value}")
        parsed[key] = value
    return parsed


def validate_generated_presets(source_root: Path, generated_root: Path) -> None:
    actual_paths = {
        path.relative_to(generated_root).as_posix()
        for path in generated_root.rglob("*")
        if path.is_file()
    }
    expected_paths = _expected_raw_preset_paths()
    if actual_paths != expected_paths:
        raise PackageError(
            "generated preset inventory must be the exact 55-file contract: "
            f"missing={sorted(expected_paths - actual_paths)}, "
            f"unexpected={sorted(actual_paths - expected_paths)}"
        )

    parameter_source = _read_required(
        source_root / "shaders" / "elder" / "ElderStageParameters.fxh",
        "Elder stage UI contract",
    ).decode("utf-8")
    ui_names = set(re.findall(r'UIName\s*=\s*"(\[Elder \d{2}\][^"]+)"', parameter_source))

    for tier_index, (tier, tier_label) in enumerate(zip(TIER_NAMES, TIER_LABELS)):
        tier_root = generated_root / tier
        metadata = _read_required(
            tier_root / PRESET_METADATA_FILE, f"{tier} quality metadata"
        ).decode("utf-8").replace("\r\n", "\n").replace("\r", "\n")
        for required_line in (
            "; Elder ENB quality preset",
            f"; Tier: {tier_label} ({tier_index})",
            f"QualityTier={tier_index}",
            f"TierId={tier}",
            f"TierLabel={tier_label}",
        ):
            if required_line not in metadata:
                raise PackageError(
                    f"{tier}/{PRESET_METADATA_FILE} lacks exact metadata: {required_line}"
                )

        tier_override = _read_required(
            tier_root / Path(TIER_OVERRIDE_PATH.as_posix()),
            f"{tier} compile-time tier override",
        ).decode("utf-8").replace("\r\n", "\n").replace("\r", "\n")
        tier_defines = re.findall(
            r"^#define\s+ELDER_QUALITY_TIER\s+([0-4])$",
            tier_override,
            flags=re.MULTILINE,
        )
        if tier_defines != [str(tier_index)]:
            raise PackageError(
                f"{tier} must define ELDER_QUALITY_TIER exactly once as {tier_index}"
            )

        for stage in STAGE_FILES:
            preset_path = tier_root / f"{stage}.ini"
            preset_source = _read_required(
                preset_path, f"{tier} {stage} configuration"
            ).decode("utf-8").replace("\r\n", "\n").replace("\r", "\n")
            if not preset_source.startswith(
                f"; Elder ENB quality preset\n; Tier: {tier_label} ({tier_index})\n"
            ):
                raise PackageError(f"preset provenance is not canonical: {preset_path}")
            expected_section = f"[{stage.upper()}]"
            parsed = _parse_ini(preset_path, expected_section)
            prefix = STAGE_UI_PREFIXES[stage]
            expected_keys = {name for name in ui_names if name.startswith(prefix)}
            if set(parsed) != expected_keys:
                raise PackageError(
                    f"preset keys do not exactly match shader UIName controls: {preset_path}; "
                    f"missing={sorted(expected_keys - set(parsed))}, "
                    f"unexpected={sorted(set(parsed) - expected_keys)}"
                )


def _copy_generated_presets(members: dict[str, bytes], generated_root: Path) -> None:
    for tier in TIER_NAMES:
        tier_root = generated_root / tier
        for stage in STAGE_FILES:
            members[f"Presets/{tier}/enbseries/{stage}.ini"] = _read_required(
                tier_root / f"{stage}.ini", f"{tier} {stage} preset"
            )
        members[f"Presets/{tier}/enbseries/{PRESET_METADATA_FILE}"] = _read_required(
            tier_root / PRESET_METADATA_FILE, f"{tier} preset metadata"
        )
        members[f"Presets/{tier}/{TIER_OVERRIDE_PATH.as_posix()}"] = _read_required(
            tier_root / Path(TIER_OVERRIDE_PATH.as_posix()),
            f"{tier} tier override",
        )


def build_source_payload(source_root: Path, work_dir: Path) -> dict[str, bytes]:
    source_root = source_root.resolve()
    work_dir = work_dir.resolve()
    work_dir.mkdir(parents=True, exist_ok=True)
    _validate_source_inventory(source_root)

    generated_root = work_dir / "generated-presets"
    _reset_owned_directory(generated_root, work_dir)
    _run_preset_generator(source_root, generated_root)
    validate_generated_presets(source_root, generated_root)

    members: dict[str, bytes] = {}
    for stage in STAGE_FILES:
        members[f"Root/enbseries/{stage}"] = _read_required(
            source_root / "shaders" / stage, f"Elder stage {stage}"
        )
    for include_name in SUPPORT_INCLUDE_FILES:
        members[f"Root/enbseries/elder/{include_name}"] = _read_required(
            source_root / "shaders" / "elder" / include_name,
            f"Elder support include {include_name}",
        )

    members["Root/enbseries/ElderColorCore.fxh"] = _read_required(
        source_root / "native" / "shaders" / "ElderColorCore.fxh",
        "Elder color-core include",
    )
    _copy_generated_presets(members, generated_root)

    balanced_root = generated_root / "balanced"
    for stage in STAGE_FILES:
        members[f"Root/enbseries/{stage}.ini"] = _read_required(
            balanced_root / f"{stage}.ini", f"Balanced {stage} default"
        )
    members[f"Root/enbseries/{PRESET_METADATA_FILE}"] = _read_required(
        balanced_root / PRESET_METADATA_FILE, "Balanced quality metadata"
    )
    members[f"Root/enbseries/elder/{TIER_OVERRIDE_PATH.name}"] = _read_required(
        balanced_root / Path(TIER_OVERRIDE_PATH.as_posix()),
        "Balanced compile-time tier override",
    )

    for source_relative, member_path in DOCUMENT_FILES:
        members[member_path] = _read_required(
            source_root / Path(source_relative), f"public document {source_relative}"
        )
    for media_name in MEDIA_FILES:
        members[f"Media/Nexus/{media_name}"] = _read_required(
            source_root / "media" / "nexus" / media_name,
            f"Nexus media {media_name}",
        )

    reject_forbidden_members(members)
    expected = expected_source_members()
    if set(members) != expected:
        raise PackageError(
            "source payload differs from exact public allowlist: "
            f"missing={sorted(expected - set(members))}, "
            f"unexpected={sorted(set(members) - expected)}"
        )
    return members


def expected_source_members() -> set[str]:
    expected = {f"Root/enbseries/{stage}" for stage in STAGE_FILES}
    expected.update(
        f"Root/enbseries/elder/{include_name}"
        for include_name in SUPPORT_INCLUDE_FILES
    )
    expected.add("Root/enbseries/ElderColorCore.fxh")
    expected.update(f"Root/enbseries/{stage}.ini" for stage in STAGE_FILES)
    expected.add(f"Root/enbseries/{PRESET_METADATA_FILE}")
    for tier in TIER_NAMES:
        expected.update(
            f"Presets/{tier}/enbseries/{stage}.ini" for stage in STAGE_FILES
        )
        expected.add(f"Presets/{tier}/enbseries/{PRESET_METADATA_FILE}")
        expected.add(f"Presets/{tier}/{TIER_OVERRIDE_PATH.as_posix()}")
    expected.update(member_path for _, member_path in DOCUMENT_FILES)
    expected.update(f"Media/Nexus/{name}" for name in MEDIA_FILES)
    return expected


def _runtime_core_notice(source_root: Path) -> bytes:
    lock_source = _read_required(
        source_root / "native" / "runtime" / "enb-runtime-core.lock",
        "enb-runtime-core lock",
    ).decode("utf-8").replace("\r\n", "\n").replace("\r", "\n")
    repository_match = re.search(r"^repository=(\S+)$", lock_source, re.MULTILINE)
    revision_match = re.search(r"^revision=([0-9a-f]{40})$", lock_source, re.MULTILINE)
    if repository_match is None or revision_match is None:
        raise PackageError("enb-runtime-core.lock lacks canonical repository/revision fields")
    return (
        "# enb-runtime-core notice\n\n"
        "ElderENBRuntime.dllplugin statically links the independently maintained "
        "enb-runtime-core library.\n\n"
        f"- Source: {repository_match.group(1)}\n"
        f"- Pinned revision: `{revision_match.group(1)}`\n"
        "- License: MIT; see `enb-runtime-core-LICENSE` in this directory.\n\n"
        "No enb-runtime-core test, compiler, or intermediate binary is included.\n"
    ).encode("utf-8")


def reject_forbidden_members(members: Mapping[str, bytes]) -> None:
    for raw_path, data in members.items():
        normalized = raw_path.replace("\\", "/")
        path = PurePosixPath(normalized)
        if (
            normalized != path.as_posix()
            or path.is_absolute()
            or not path.parts
            or any(part in {"", ".", ".."} for part in path.parts)
            or ":" in path.parts[0]
        ):
            raise PackageError(f"unsafe archive member path: {raw_path}")

        lowered_parts = tuple(part.lower() for part in path.parts)
        if any(part in FORBIDDEN_COMPONENTS for part in lowered_parts):
            raise PackageError(f"forbidden public-package path: {raw_path}")
        basename = lowered_parts[-1]
        if basename == ".env" or basename.startswith(".env."):
            raise PackageError(f"environment/secrets file is forbidden: {raw_path}")
        if basename in FORBIDDEN_ENB_BINARY_NAMES:
            raise PackageError(f"ENB binary is forbidden: {raw_path}")
        if any(
            marker in part
            for part in lowered_parts
            for marker in FORBIDDEN_NAME_MARKERS + ("eote",)
        ):
            raise PackageError(f"permission-dependent component is forbidden: {raw_path}")

        suffix = PurePosixPath(basename).suffix
        if suffix == ".dllplugin":
            if path.as_posix() != RUNTIME_MEMBER:
                raise PackageError(f"only the Elder-owned runtime plugin may ship: {raw_path}")
        elif suffix in FORBIDDEN_BINARY_SUFFIXES:
            raise PackageError(f"compiler, test, archive, or binary artifact is forbidden: {raw_path}")

        for secret_pattern in SECRET_PATTERNS:
            if secret_pattern.search(data):
                raise PackageError(f"secret-like material is forbidden: {raw_path}")


def _manifest_bytes(members: Mapping[str, bytes]) -> bytes:
    return "".join(
        f"{hashlib.sha256(members[path]).hexdigest()}  {path}\n"
        for path in sorted(members)
    ).encode("ascii")


def _expected_release_members(require_runtime: bool) -> set[str]:
    expected = expected_source_members()
    expected.add(NATIVE_PARAMETERS_MEMBER)
    if require_runtime:
        expected.update(
            {
                RUNTIME_MEMBER,
                RUNTIME_CORE_LICENSE_MEMBER,
                RUNTIME_CORE_NOTICE_MEMBER,
            }
        )
    expected.add(MANIFEST_MEMBER)
    return expected


def validate_release_members(
    members: Mapping[str, bytes], *, require_runtime: bool
) -> None:
    reject_forbidden_members(members)
    expected = _expected_release_members(require_runtime)
    actual = set(members)
    if actual != expected:
        raise PackageError(
            "archive member set differs from the exact public manifest: "
            f"missing={sorted(expected - actual)}, "
            f"unexpected={sorted(actual - expected)}"
        )
    if not members[NATIVE_PARAMETERS_MEMBER].startswith(
        b"#ifndef ELDER_NATIVE_PARAMETERS_FXH"
    ):
        raise PackageError("generated Elder native parameter include is not canonical")
    if b"ElderNativeSanitize_ElderMasterEnabled" not in members[NATIVE_PARAMETERS_MEMBER]:
        raise PackageError("generated Elder native parameter include lacks its sanitizer ABI")
    if require_runtime and not members[RUNTIME_MEMBER].startswith(b"MZ"):
        raise PackageError("Elder runtime plugin is not a Windows PE binary")


def _write_archive(archive_path: Path, members: Mapping[str, bytes]) -> None:
    archive_path.parent.mkdir(parents=True, exist_ok=True)
    if archive_path.exists():
        archive_path.unlink()
    with zipfile.ZipFile(
        archive_path,
        mode="w",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=9,
        strict_timestamps=True,
    ) as archive:
        for member_path in sorted(members):
            info = zipfile.ZipInfo(member_path, date_time=FIXED_TIMESTAMP)
            info.create_system = 3
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, members[member_path], compresslevel=9)


def build_release(
    *,
    source_root: Path,
    output_dir: Path,
    work_dir: Path,
    native_parameters: Path,
    runtime_plugin: Path,
    runtime_core_root: Path,
) -> ReleaseArtifacts:
    source_root = source_root.resolve()
    members = build_source_payload(source_root, work_dir)

    native_parameters_data = _read_required(
        native_parameters.resolve(), "generated Elder native parameter include"
    )
    runtime_plugin = runtime_plugin.resolve()
    if runtime_plugin.name != "ElderENBRuntime.dllplugin":
        raise PackageError(
            "runtime input must be the Elder-owned ElderENBRuntime.dllplugin"
        )
    runtime_data = _read_required(runtime_plugin, "Elder runtime plugin")
    if not runtime_data.startswith(b"MZ"):
        raise PackageError("Elder runtime plugin is not a Windows PE binary")

    runtime_core_license = _read_required(
        runtime_core_root.resolve() / "LICENSE", "enb-runtime-core license"
    )
    if b"MIT License" not in runtime_core_license:
        raise PackageError("enb-runtime-core license is not the admitted MIT license")

    members[NATIVE_PARAMETERS_MEMBER] = native_parameters_data
    members[RUNTIME_MEMBER] = runtime_data
    members[RUNTIME_CORE_LICENSE_MEMBER] = runtime_core_license
    members[RUNTIME_CORE_NOTICE_MEMBER] = _runtime_core_notice(source_root)
    members[MANIFEST_MEMBER] = _manifest_bytes(members)
    validate_release_members(members, require_runtime=True)

    output_dir = output_dir.resolve()
    archive_path = output_dir / ARCHIVE_NAME
    checksum_path = output_dir / f"{ARCHIVE_NAME}.sha256"
    _write_archive(archive_path, members)
    digest = hashlib.sha256(archive_path.read_bytes()).hexdigest()
    output_dir.mkdir(parents=True, exist_ok=True)
    checksum_path.write_bytes(f"{digest}  {ARCHIVE_NAME}\n".encode("ascii"))
    verified = verify_archive(archive_path, require_runtime=True)
    if verified.sha256 != digest:
        raise PackageError("post-write archive verification produced a different digest")
    return ReleaseArtifacts(archive_path, checksum_path, digest, verified.file_count)


def verify_checksum_sidecar(archive_path: Path) -> Path:
    archive_path = archive_path.resolve()
    checksum_path = archive_path.with_suffix(archive_path.suffix + ".sha256")
    checksum_data = _read_required(checksum_path, "public archive checksum")
    digest = hashlib.sha256(_read_required(archive_path, "public archive")).hexdigest()
    expected = f"{digest}  {ARCHIVE_NAME}\n".encode("ascii")
    if checksum_data != expected:
        raise PackageError(
            f"checksum sidecar does not exactly match {ARCHIVE_NAME}: {checksum_path}"
        )
    return checksum_path


def verify_archive(archive_path: Path, *, require_runtime: bool) -> VerificationResult:
    archive_path = archive_path.resolve()
    if archive_path.name != ARCHIVE_NAME:
        raise PackageError(
            f"public archive must be named {ARCHIVE_NAME}, found {archive_path.name}"
        )
    try:
        with zipfile.ZipFile(archive_path, mode="r") as archive:
            infos = archive.infolist()
            names = [info.filename for info in infos]
            if names != sorted(names):
                raise PackageError("archive members are not sorted")
            if len(names) != len(set(names)):
                raise PackageError("archive contains duplicate member names")
            for info in infos:
                if info.date_time != FIXED_TIMESTAMP:
                    raise PackageError(
                        f"archive timestamp is not deterministic: {info.filename}"
                    )
                if info.is_dir():
                    raise PackageError(f"archive must not contain directory entries: {info.filename}")
            members = {name: archive.read(name) for name in names}
    except (OSError, zipfile.BadZipFile) as error:
        raise PackageError(f"cannot read public archive {archive_path}: {error}") from error

    validate_release_members(members, require_runtime=require_runtime)
    expected_manifest = _manifest_bytes(
        {path: data for path, data in members.items() if path != MANIFEST_MEMBER}
    )
    if members[MANIFEST_MEMBER] != expected_manifest:
        raise PackageError("MANIFEST.sha256 does not exactly hash the archive payload")
    verify_checksum_sidecar(archive_path)
    return VerificationResult(
        hashlib.sha256(archive_path.read_bytes()).hexdigest(), len(members)
    )


def check_source_determinism(source_root: Path, work_dir: Path) -> tuple[str, int]:
    work_dir = work_dir.resolve()
    work_dir.mkdir(parents=True, exist_ok=True)
    first = build_source_payload(source_root, work_dir / "first")
    second = build_source_payload(source_root, work_dir / "second")
    if set(first) != set(second):
        raise PackageError("source payload generation is not path deterministic")
    for path in sorted(first):
        if first[path] != second[path]:
            raise PackageError(f"source payload generation is not byte deterministic: {path}")
    digest = hashlib.sha256(_manifest_bytes(first)).hexdigest()
    return digest, len(first)


def _default_native_parameters(source_root: Path) -> Path:
    return (
        source_root
        / "out"
        / "native-schema"
        / "vs18-x64-static"
        / "generated"
        / "Release"
        / "shaders"
        / "ElderNativeParameters.fxh"
    )


def _default_runtime_plugin(source_root: Path) -> Path:
    return (
        source_root
        / "out"
        / "native-schema"
        / "vs18-x64-static"
        / "runtime"
        / "Release"
        / "ElderENBRuntime.dllplugin"
    )


def default_runtime_core_root(source_root: Path) -> Path:
    source_root = source_root.resolve()
    candidates = [source_root.parent / "enb-runtime-core"]
    if len(source_root.parents) > 1:
        candidates.append(source_root.parents[1] / "enb-runtime-core")
    for candidate in candidates:
        if (candidate / "LICENSE").is_file() and (candidate / "CMakeLists.txt").is_file():
            return candidate.resolve()
    return candidates[0].resolve()


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    source_parser = subparsers.add_parser(
        "check-source",
        help="validate deterministic shader/docs/media payload without emitting a release",
    )
    source_parser.add_argument("--source-root", type=Path, default=ROOT)
    source_parser.add_argument("--work-dir", type=Path, required=True)

    build_parser = subparsers.add_parser(
        "build", help="build the strict runtime-complete public archive"
    )
    build_parser.add_argument("--source-root", type=Path, default=ROOT)
    build_parser.add_argument("--output-dir", type=Path, default=ROOT / "dist")
    build_parser.add_argument(
        "--work-dir", type=Path, default=ROOT / "out" / "public-package"
    )
    build_parser.add_argument("--native-parameters", type=Path)
    build_parser.add_argument("--runtime-plugin", type=Path)
    build_parser.add_argument(
        "--runtime-core-root", type=Path, default=default_runtime_core_root(ROOT)
    )

    verify_parser = subparsers.add_parser("verify", help="verify an existing public archive")
    verify_parser.add_argument("archive", type=Path)
    verify_parser.add_argument("--require-runtime", action="store_true")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = _build_parser()
    arguments = parser.parse_args(argv)
    try:
        if arguments.command == "check-source":
            digest, file_count = check_source_determinism(
                arguments.source_root, arguments.work_dir
            )
            print(
                f"validated deterministic Elder source payload: {file_count} files; "
                f"manifest digest {digest}"
            )
            print("runtime-complete release archive intentionally not emitted")
            return 0

        if arguments.command == "build":
            source_root = arguments.source_root.resolve()
            artifacts = build_release(
                source_root=source_root,
                output_dir=arguments.output_dir,
                work_dir=arguments.work_dir,
                native_parameters=(
                    arguments.native_parameters
                    if arguments.native_parameters is not None
                    else _default_native_parameters(source_root)
                ),
                runtime_plugin=(
                    arguments.runtime_plugin
                    if arguments.runtime_plugin is not None
                    else _default_runtime_plugin(source_root)
                ),
                runtime_core_root=arguments.runtime_core_root,
            )
            print(f"packaged {artifacts.archive}")
            print(f"sha256  {artifacts.sha256}")
            print(f"files   {artifacts.file_count}")
            return 0

        verification = verify_archive(
            arguments.archive, require_runtime=arguments.require_runtime
        )
        print(
            f"verified {arguments.archive}: {verification.file_count} files; "
            f"SHA-256 {verification.sha256}"
        )
        return 0
    except PackageError as error:
        parser.exit(2, f"error: {error}\n")


if __name__ == "__main__":
    raise SystemExit(main())
