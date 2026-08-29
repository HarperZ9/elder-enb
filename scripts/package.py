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
import csv
import hashlib
import io
import re
import shutil
import struct
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
    "enbeffectprepass.fx": "Elder 10 | Prepass |",
    "enbdepthoffield.fx": "Elder 20 | Depth of Field |",
    "enbbloom.fx": "Elder 30 | Bloom |",
    "enbadaptation.fx": "Elder 40 | Adaptation |",
    "enblens.fx": "Elder 50 | Lens |",
    "enbeffect.fx": "Elder 60 | Main Effect |",
    "enbeffectpostpass.fx": "Elder 70 | Postpass |",
    "enbsunsprite.fx": "Elder 80 | Sun Sprite |",
    "enbunderwater.fx": "Elder 90 | Underwater |",
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
RUNTIME_RECEIPT_MEMBER = "Docs/ElderENBRuntime.receipt"
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


class RuntimeCoreIdentity(NamedTuple):
    license: bytes
    repository: str
    revision: str


class PeSection(NamedTuple):
    name: str
    virtual_address: int
    virtual_size: int
    raw_offset: int
    raw_size: int
    characteristics: int


def _read_required(path: Path, description: str) -> bytes:
    if not path.is_file():
        raise PackageError(f"missing {description}: {path}")
    data = path.read_bytes()
    if not data:
        raise PackageError(f"empty {description}: {path}")
    return data


def read_public_source(
    source_root: Path, relative_path: Path, description: str
) -> bytes:
    """Read one allowlisted source without following links outside the checkout."""
    source_root = source_root.resolve()
    if relative_path.is_absolute() or any(
        part in {"", ".", ".."} for part in relative_path.parts
    ):
        raise PackageError(f"unsafe {description} source path: {relative_path}")

    candidate = source_root / relative_path
    cursor = source_root
    for part in relative_path.parts:
        cursor /= part
        is_junction = getattr(cursor, "is_junction", lambda: False)
        if cursor.is_symlink() or is_junction():
            raise PackageError(f"linked {description} source is forbidden: {cursor}")

    resolved = candidate.resolve()
    if resolved == source_root or source_root not in resolved.parents:
        raise PackageError(f"{description} source escapes the checkout: {candidate}")
    return _read_required(resolved, description)


def _reset_owned_directory(path: Path, owner: Path) -> None:
    resolved_owner = owner.resolve()
    resolved_path = path.resolve()
    if resolved_path == resolved_owner or resolved_owner not in resolved_path.parents:
        raise PackageError(f"refusing to reset path outside package work root: {path}")
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True)


def _validate_source_inventory(source_root: Path) -> None:
    for relative_dir, description in (
        (Path("shaders"), "shader directory"),
        (Path("shaders/elder"), "shader include directory"),
    ):
        directory = source_root / relative_dir
        is_junction = getattr(directory, "is_junction", lambda: False)
        if directory.is_symlink() or is_junction():
            raise PackageError(f"linked {description} is forbidden: {directory}")
        resolved = directory.resolve()
        if source_root not in resolved.parents or not resolved.is_dir():
            raise PackageError(f"invalid {description}: {directory}")

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
    for stage in STAGE_FILES:
        read_public_source(source_root, Path("shaders") / stage, f"Elder stage {stage}")

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
    for include_name in SUPPORT_INCLUDE_FILES:
        read_public_source(
            source_root,
            Path("shaders/elder") / include_name,
            f"Elder support include {include_name}",
        )


def _run_preset_generator(source_root: Path, output_dir: Path) -> None:
    generator = Path("cmake/GenerateElderQualityPresets.cmake")
    read_public_source(source_root, generator, "quality preset generator")
    command = (
        "cmake",
        f"-DELDER_SOURCE_DIR={source_root}",
        f"-DELDER_OUTPUT_DIR={output_dir}",
        "-P",
        str(source_root / generator),
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
    # Windows INI readers treat any line whose first character is '[' as a
    # section header, whether or not it carries an '=' further along.
    section_lines = [line for line in lines if line.startswith("[")]
    if section_lines != [expected_section]:
        raise PackageError(
            f"preset {path} must contain exactly section {expected_section}; "
            f"found {section_lines}"
        )

    parsed: dict[str, str] = {}
    for line in lines:
        if not line or line.startswith(";") or line.startswith("["):
            continue
        if "=" not in line:
            raise PackageError(f"malformed preset line in {path}: {line}")
        key, value = line.split("=", 1)
        if key in parsed:
            raise PackageError(f"duplicate preset key in {path}: {key}")
        if not (
            value in {"true", "false"} or re.fullmatch(r"-?[0-9]+(?:\.[0-9]+)?", value)
        ):
            raise PackageError(f"invalid preset value in {path}: {key}={value}")
        parsed[key] = value
    return parsed


def _check_knob_ui_names_ini_safe(source_root: Path) -> None:
    # ENB persists each annotated knob to the stage .fx.ini keyed by its
    # UIName. A label that opens with '[' reads back as a section header,
    # and an embedded '=' or ';' splits or comments the saved line, so the
    # value can never round-trip. Technique-level UINames are exempt: the
    # host persists technique selection as TECHNIQUE=<index>, never by
    # label, and every technique annotation sits on its own technique11
    # line, so stripping those lines leaves exactly the knob annotations.
    scan_paths = [Path("shaders/elder") / name for name in SUPPORT_INCLUDE_FILES]
    scan_paths.extend(Path("shaders") / name for name in STAGE_FILES)
    for scan_path in scan_paths:
        scan_source = read_public_source(
            source_root, scan_path, "Elder knob UI scan"
        ).decode("utf-8")
        knob_source = re.sub(r"technique11[^\n]*", "", scan_source)
        for ui_name in re.findall(r'UIName\s*=\s*"([^"]*)"', knob_source):
            if not re.fullmatch(r"[A-Za-z0-9][^\[\]=;]*", ui_name):
                raise PackageError(
                    "UIName cannot round-trip as an INI key in "
                    f"{scan_path.as_posix()}: {ui_name!r}"
                )


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

    _check_knob_ui_names_ini_safe(source_root)
    parameter_source = read_public_source(
        source_root,
        Path("shaders/elder/ElderStageParameters.fxh"),
        "Elder stage UI contract",
    ).decode("utf-8")
    all_ui_names = re.findall(r'UIName\s*=\s*"([^"]*)"', parameter_source)
    if not all_ui_names:
        raise PackageError("Elder stage UI contract declares no UIName controls")
    ui_names = {
        ui_name for ui_name in all_ui_names if re.match(r"Elder \d{2} \| ", ui_name)
    }

    for tier_index, (tier, tier_label) in enumerate(zip(TIER_NAMES, TIER_LABELS)):
        tier_root = generated_root / tier
        metadata = (
            _read_required(tier_root / PRESET_METADATA_FILE, f"{tier} quality metadata")
            .decode("utf-8")
            .replace("\r\n", "\n")
            .replace("\r", "\n")
        )
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

        tier_override = (
            _read_required(
                tier_root / Path(TIER_OVERRIDE_PATH.as_posix()),
                f"{tier} compile-time tier override",
            )
            .decode("utf-8")
            .replace("\r\n", "\n")
            .replace("\r", "\n")
        )
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
            preset_source = (
                _read_required(preset_path, f"{tier} {stage} configuration")
                .decode("utf-8")
                .replace("\r\n", "\n")
                .replace("\r", "\n")
            )
            if not preset_source.startswith(
                f"; Elder ENB quality preset\n; Tier: {tier_label} ({tier_index})\n"
            ):
                raise PackageError(f"preset provenance is not canonical: {preset_path}")
            expected_section = f"[{stage.upper()}]"
            # TECHNIQUE=1 must sit directly under the section header, matching
            # ENB's own save format; index 1 activates the first declared
            # Elder technique instead of ENB's internal DEFAULT shader.
            if f"{expected_section}\nTECHNIQUE=1\n" not in preset_source:
                raise PackageError(
                    f"preset must set TECHNIQUE=1 directly under "
                    f"{expected_section}: {preset_path}"
                )
            parsed = _parse_ini(preset_path, expected_section)
            if parsed.pop("TECHNIQUE", None) != "1":
                raise PackageError(
                    f"preset technique must be exactly TECHNIQUE=1: {preset_path}"
                )
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
        members[f"Root/enbseries/{stage}"] = read_public_source(
            source_root, Path("shaders") / stage, f"Elder stage {stage}"
        )
    for include_name in SUPPORT_INCLUDE_FILES:
        members[f"Root/enbseries/elder/{include_name}"] = read_public_source(
            source_root,
            Path("shaders/elder") / include_name,
            f"Elder support include {include_name}",
        )

    members["Root/enbseries/ElderColorCore.fxh"] = read_public_source(
        source_root,
        Path("native/shaders/ElderColorCore.fxh"),
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
        members[member_path] = read_public_source(
            source_root, Path(source_relative), f"public document {source_relative}"
        )
    for media_name in MEDIA_FILES:
        members[f"Media/Nexus/{media_name}"] = read_public_source(
            source_root,
            Path("media/nexus") / media_name,
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
        f"Root/enbseries/elder/{include_name}" for include_name in SUPPORT_INCLUDE_FILES
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


def _runtime_core_lock(source_root: Path) -> tuple[str, str]:
    lock_source = (
        read_public_source(
            source_root,
            Path("native/runtime/enb-runtime-core.lock"),
            "enb-runtime-core lock",
        )
        .decode("utf-8")
        .replace("\r\n", "\n")
        .replace("\r", "\n")
    )
    repository_match = re.search(r"^repository=(\S+)$", lock_source, re.MULTILINE)
    revision_match = re.search(r"^revision=([0-9a-f]{40})$", lock_source, re.MULTILINE)
    if repository_match is None or revision_match is None:
        raise PackageError(
            "enb-runtime-core.lock lacks canonical repository/revision fields"
        )
    expected = (
        f"repository={repository_match.group(1)}\nrevision={revision_match.group(1)}\n"
    )
    if lock_source != expected:
        raise PackageError(
            "enb-runtime-core.lock contains non-canonical or extra fields"
        )
    return repository_match.group(1), revision_match.group(1)


def _git_text(root: Path, *arguments: str) -> str:
    result = subprocess.run(
        ("git", "-C", str(root), *arguments),
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise PackageError(
            f"git {' '.join(arguments)} failed for {root}: {result.stderr.strip()}"
        )
    return result.stdout.strip()


def _normalized_repository(repository: str) -> str:
    normalized = repository.strip().replace("\\", "/").rstrip("/")
    if normalized.casefold().endswith(".git"):
        normalized = normalized[:-4]
    if normalized.startswith("git@") and ":" in normalized:
        host, path = normalized[4:].split(":", 1)
        normalized = f"https://{host}/{path}"
    return normalized.casefold()


def validate_runtime_core(
    source_root: Path, runtime_core_root: Path
) -> RuntimeCoreIdentity:
    repository, revision = _runtime_core_lock(source_root)
    runtime_core_root = runtime_core_root.resolve()
    cmake_project = _read_required(
        runtime_core_root / "CMakeLists.txt", "enb-runtime-core CMake project"
    )
    if b"project(" not in cmake_project:
        raise PackageError("enb-runtime-core CMake project is not canonical")
    license_data = _read_required(
        runtime_core_root / "LICENSE", "enb-runtime-core license"
    )
    if not license_data.startswith(b"MIT License"):
        raise PackageError("enb-runtime-core license is not the admitted MIT license")

    actual_revision = _git_text(runtime_core_root, "rev-parse", "HEAD").casefold()
    if actual_revision != revision:
        raise PackageError(
            "enb-runtime-core revision mismatch: "
            f"expected {revision}, found {actual_revision}"
        )
    actual_repository = _git_text(runtime_core_root, "remote", "get-url", "origin")
    if _normalized_repository(actual_repository) != _normalized_repository(repository):
        raise PackageError(
            "enb-runtime-core repository mismatch: "
            f"expected {repository}, found {actual_repository}"
        )
    tracked_status = _git_text(
        runtime_core_root, "status", "--porcelain", "--untracked-files=no"
    )
    if tracked_status:
        raise PackageError("enb-runtime-core contains tracked local changes")
    return RuntimeCoreIdentity(license_data, repository, revision)


def validate_native_parameters(source_root: Path, data: bytes) -> None:
    try:
        source = data.decode("utf-8")
    except UnicodeDecodeError as error:
        raise PackageError(
            "generated Elder native parameter include is not UTF-8"
        ) from error
    if not source.startswith(
        "#ifndef ELDER_NATIVE_PARAMETERS_FXH\n#define ELDER_NATIVE_PARAMETERS_FXH\n"
    ):
        raise PackageError("generated Elder native parameter include is not canonical")

    schema_source = read_public_source(
        source_root,
        Path("native/schema/elder-native-parameters.csv"),
        "Elder native parameter schema",
    ).decode("utf-8-sig")
    rows = list(csv.DictReader(io.StringIO(schema_source)))
    if not rows:
        raise PackageError("Elder native parameter schema is empty")
    hlsl_types = {"bool": "bool", "float": "float", "color3": "float3"}
    symbols: list[str] = []
    for row in rows:
        symbol = row.get("symbol", "")
        schema_type = row.get("type", "")
        if (
            not re.fullmatch(r"Elder[A-Za-z0-9]+", symbol)
            or schema_type not in hlsl_types
        ):
            raise PackageError(f"unsupported Elder native schema row: {row}")
        if symbol in symbols:
            raise PackageError(f"duplicate Elder native schema symbol: {symbol}")
        symbols.append(symbol)
        hlsl_type = hlsl_types[schema_type]
        required_patterns = (
            rf"(?m)^\s*{hlsl_type}\s+{re.escape(symbol)}\b",
            rf"(?m)^\s*{hlsl_type}\s+ElderNativeSanitize_{re.escape(symbol)}\s*\(",
            rf"(?m)^\s*bool\s+ElderNativeActive_{re.escape(symbol)}\s*\(",
        )
        if any(re.search(pattern, source) is None for pattern in required_patterns):
            raise PackageError(f"generated Elder native parameter ABI lacks {symbol}")

    expected_symbols = set(symbols)
    for prefix, return_type in (
        ("Sanitize", r"(?:bool|float|float3)"),
        ("Active", "bool"),
    ):
        actual_symbols = set(
            re.findall(
                rf"(?m)^\s*{return_type}\s+ElderNative{prefix}_(Elder[A-Za-z0-9]+)\s*\(",
                source,
            )
        )
        if actual_symbols != expected_symbols:
            raise PackageError(
                f"generated Elder native {prefix.lower()} ABI differs from schema: "
                f"missing={sorted(expected_symbols - actual_symbols)}, "
                f"unexpected={sorted(actual_symbols - expected_symbols)}"
            )

    main_effect = read_public_source(
        source_root, Path("shaders/enbeffect.fx"), "Elder main effect"
    ).decode("utf-8")
    used_contracts = set(
        re.findall(r"ElderNative(?:Sanitize|Active)_Elder[A-Za-z0-9]+", main_effect)
    )
    missing_contracts = sorted(
        name for name in used_contracts if f"{name}(" not in source
    )
    if missing_contracts:
        raise PackageError(
            f"generated Elder native ABI omits main-effect contracts: {missing_contracts}"
        )


def _pe_section_offset(
    data: bytes,
    sections: Sequence[PeSection],
    rva: int,
    size: int,
    description: str,
) -> tuple[PeSection, int]:
    if rva <= 0 or size <= 0:
        raise PackageError(f"Elder runtime {description} has an invalid RVA/size")
    matches: list[tuple[PeSection, int]] = []
    for section in sections:
        delta = rva - section.virtual_address
        if delta < 0 or delta + size > section.raw_size:
            continue
        offset = section.raw_offset + delta
        if offset + size <= len(data):
            matches.append((section, offset))
    if len(matches) != 1:
        raise PackageError(
            f"Elder runtime {description} is not uniquely backed by a PE section"
        )
    return matches[0]


def _pe_export_string(
    data: bytes, sections: Sequence[PeSection], rva: int, description: str
) -> str:
    value = bytearray()
    for index in range(256):
        _, offset = _pe_section_offset(data, sections, rva + index, 1, description)
        byte = data[offset]
        if byte == 0:
            if not value:
                raise PackageError(f"Elder runtime {description} is empty")
            try:
                return value.decode("ascii")
            except UnicodeDecodeError as error:
                raise PackageError(
                    f"Elder runtime {description} is not ASCII"
                ) from error
        value.append(byte)
    raise PackageError(f"Elder runtime {description} is not NUL terminated")


def validate_runtime_plugin(data: bytes) -> None:
    if len(data) < 0x9A or data[:2] != b"MZ":
        raise PackageError("Elder runtime plugin lacks a valid DOS header")
    pe_offset = struct.unpack_from("<I", data, 0x3C)[0]
    if pe_offset < 0x40 or pe_offset + 26 > len(data):
        raise PackageError("Elder runtime plugin has an invalid PE header offset")
    if data[pe_offset : pe_offset + 4] != b"PE\0\0":
        raise PackageError("Elder runtime plugin lacks a PE signature")
    machine = struct.unpack_from("<H", data, pe_offset + 4)[0]
    section_count = struct.unpack_from("<H", data, pe_offset + 6)[0]
    optional_size = struct.unpack_from("<H", data, pe_offset + 20)[0]
    characteristics = struct.unpack_from("<H", data, pe_offset + 22)[0]
    if machine != 0x8664:
        raise PackageError("Elder runtime plugin is not AMD64")
    if not 3 <= section_count <= 96:
        raise PackageError("Elder runtime plugin has an invalid PE section count")
    optional_offset = pe_offset + 24
    if optional_size < 120 or optional_offset + optional_size > len(data):
        raise PackageError("Elder runtime plugin has an invalid optional header")
    if struct.unpack_from("<H", data, optional_offset)[0] != 0x20B:
        raise PackageError("Elder runtime plugin is not PE32+")
    if characteristics & 0x2000 == 0:
        raise PackageError("Elder runtime plugin is not marked as a DLL")

    entrypoint_rva = struct.unpack_from("<I", data, optional_offset + 16)[0]
    section_alignment = struct.unpack_from("<I", data, optional_offset + 32)[0]
    file_alignment = struct.unpack_from("<I", data, optional_offset + 36)[0]
    size_of_image = struct.unpack_from("<I", data, optional_offset + 56)[0]
    size_of_headers = struct.unpack_from("<I", data, optional_offset + 60)[0]
    directory_count = struct.unpack_from("<I", data, optional_offset + 108)[0]
    if (
        file_alignment < 0x200
        or file_alignment > 0x10000
        or file_alignment & (file_alignment - 1)
        or section_alignment < file_alignment
        or section_alignment & (section_alignment - 1)
    ):
        raise PackageError("Elder runtime plugin has invalid PE alignments")
    section_table = optional_offset + optional_size
    section_table_end = section_table + section_count * 40
    if (
        size_of_headers < section_table_end
        or size_of_headers > len(data)
        or size_of_image <= size_of_headers
        or directory_count < 1
    ):
        raise PackageError("Elder runtime plugin has invalid PE image bounds")

    sections: list[PeSection] = []
    raw_ranges: list[tuple[int, int]] = []
    virtual_ranges: list[tuple[int, int]] = []
    for index in range(section_count):
        offset = section_table + index * 40
        raw_name = data[offset : offset + 8].split(b"\0", 1)[0]
        try:
            name = raw_name.decode("ascii")
        except UnicodeDecodeError as error:
            raise PackageError("Elder runtime PE section name is not ASCII") from error
        if not re.fullmatch(r"[.A-Za-z0-9_$-]{1,8}", name):
            raise PackageError("Elder runtime PE section name is invalid")
        virtual_size, virtual_address, raw_size, raw_offset = struct.unpack_from(
            "<IIII", data, offset + 8
        )
        section_characteristics = struct.unpack_from("<I", data, offset + 36)[0]
        if (
            virtual_size == 0
            or virtual_address == 0
            or virtual_address % section_alignment != 0
            or raw_size == 0
            or raw_offset < size_of_headers
            or raw_offset % file_alignment != 0
            or raw_size % file_alignment != 0
            or raw_offset + raw_size > len(data)
        ):
            raise PackageError(f"Elder runtime PE section {name} has invalid bounds")
        virtual_end = virtual_address + max(virtual_size, raw_size)
        if virtual_end > size_of_image:
            raise PackageError(f"Elder runtime PE section {name} escapes the image")
        raw_ranges.append((raw_offset, raw_offset + raw_size))
        virtual_ranges.append((virtual_address, virtual_end))
        sections.append(
            PeSection(
                name,
                virtual_address,
                virtual_size,
                raw_offset,
                raw_size,
                section_characteristics,
            )
        )
    if len({section.name for section in sections}) != len(sections):
        raise PackageError("Elder runtime plugin has duplicate PE section names")
    for ranges, description in (
        (sorted(raw_ranges), "raw"),
        (sorted(virtual_ranges), "virtual"),
    ):
        if any(
            previous[1] > current[0] for previous, current in zip(ranges, ranges[1:])
        ):
            raise PackageError(
                f"Elder runtime plugin has overlapping {description} sections"
            )

    entry_section, _ = _pe_section_offset(
        data, sections, entrypoint_rva, 1, "entrypoint"
    )
    if entry_section.characteristics & 0x20000020 != 0x20000020:
        raise PackageError("Elder runtime entrypoint is not in executable code")

    export_rva, export_size = struct.unpack_from("<II", data, optional_offset + 112)
    if export_size < 40:
        raise PackageError("Elder runtime plugin lacks a PE export directory")
    export_section, export_offset = _pe_section_offset(
        data, sections, export_rva, export_size, "export directory"
    )
    if export_section.characteristics & 0x40000040 != 0x40000040:
        raise PackageError("Elder runtime export directory is not readable data")
    (
        dll_name_rva,
        _ordinal_base,
        function_count,
        name_count,
        functions_rva,
        names_rva,
        ordinals_rva,
    ) = struct.unpack_from("<IIIIIII", data, export_offset + 12)
    if not 2 <= name_count <= function_count <= 4096:
        raise PackageError("Elder runtime export counts are invalid")
    if (
        _pe_export_string(data, sections, dll_name_rva, "export DLL name")
        != "ElderENBRuntime.dllplugin"
    ):
        raise PackageError("Elder runtime export directory names a different DLL")

    _, functions_offset = _pe_section_offset(
        data, sections, functions_rva, function_count * 4, "export function table"
    )
    _, names_offset = _pe_section_offset(
        data, sections, names_rva, name_count * 4, "export name table"
    )
    _, ordinals_offset = _pe_section_offset(
        data, sections, ordinals_rva, name_count * 2, "export ordinal table"
    )
    exported_names: set[str] = set()
    for index in range(name_count):
        name_rva = struct.unpack_from("<I", data, names_offset + index * 4)[0]
        export_name = _pe_export_string(
            data, sections, name_rva, f"export name {index}"
        )
        ordinal = struct.unpack_from("<H", data, ordinals_offset + index * 2)[0]
        if ordinal >= function_count:
            raise PackageError("Elder runtime export ordinal is out of range")
        function_rva = struct.unpack_from("<I", data, functions_offset + ordinal * 4)[0]
        if export_rva <= function_rva < export_rva + export_size:
            raise PackageError("Elder runtime probe export is unexpectedly forwarded")
        function_section, _ = _pe_section_offset(
            data, sections, function_rva, 1, f"export {export_name} target"
        )
        if function_section.characteristics & 0x20000020 != 0x20000020:
            raise PackageError(
                "Elder runtime probe export does not target executable code"
            )
        if export_name in exported_names:
            raise PackageError("Elder runtime plugin has duplicate named exports")
        exported_names.add(export_name)

    expected_exports = {
        "ElderEnbRuntimeProbeV1",
        "ElderEnbRuntimeFrameProbeV1",
    }
    if exported_names != expected_exports:
        raise PackageError(
            "Elder runtime exports differ from the public probe ABI: "
            f"missing={sorted(expected_exports - exported_names)}, "
            f"unexpected={sorted(exported_names - expected_exports)}"
        )
    for symbol in (
        b"ElderRuntimeFramePulse",
        b"ElderRuntimeRoomLight",
        b"ElderRuntimeExposureColor",
        b"ElderRuntimeStatus",
    ):
        if symbol not in data:
            raise PackageError(f"Elder runtime plugin omits {symbol.decode('ascii')}")


def _normalized_runtime_receipt(receipt_data: bytes) -> bytes:
    try:
        receipt = receipt_data.decode("ascii")
    except UnicodeDecodeError as error:
        raise PackageError("Elder runtime receipt is not ASCII") from error
    receipt = receipt.replace("\r\n", "\n")
    if "\r" in receipt:
        raise PackageError("Elder runtime receipt contains invalid line endings")
    return receipt.encode("ascii")


def validate_runtime_receipt(
    source_root: Path,
    receipt_data: bytes,
    runtime_data: bytes,
    runtime_core: RuntimeCoreIdentity,
) -> None:
    receipt = _normalized_runtime_receipt(receipt_data).decode("ascii")
    lines = receipt.splitlines(keepends=True)
    if any(not line.endswith("\n") for line in lines):
        raise PackageError("Elder runtime receipt must contain complete records")
    parsed: dict[str, str] = {}
    for line in lines:
        key, separator, value = line[:-1].partition("=")
        if not separator or not key or not value or key in parsed:
            raise PackageError("Elder runtime receipt contains malformed records")
        parsed[key] = value
    expected_keys = (
        "schema",
        "runtime_file",
        "runtime_sha256",
        "elder_revision",
        "elder_runtime_tree",
        "runtime_core_repository",
        "runtime_core_revision",
    )
    if tuple(parsed) != expected_keys:
        raise PackageError("Elder runtime receipt fields are not canonical")
    if parsed["schema"] != "ELDER_RUNTIME_RECEIPT_V1":
        raise PackageError("Elder runtime receipt schema is unsupported")
    if parsed["runtime_file"] != "ElderENBRuntime.dllplugin":
        raise PackageError("Elder runtime receipt names a different binary")
    runtime_digest = hashlib.sha256(runtime_data).hexdigest()
    if parsed["runtime_sha256"] != runtime_digest:
        raise PackageError("Elder runtime receipt hash does not match the plugin")
    elder_revision = _git_text(source_root, "rev-parse", "HEAD").casefold()
    elder_runtime_tree = _git_text(
        source_root, "rev-parse", "HEAD:native/runtime"
    ).casefold()
    if parsed["elder_revision"] != elder_revision:
        raise PackageError("Elder runtime receipt does not match the source revision")
    if parsed["elder_runtime_tree"] != elder_runtime_tree:
        raise PackageError(
            "Elder runtime receipt does not match the runtime source tree"
        )
    if _normalized_repository(
        parsed["runtime_core_repository"]
    ) != _normalized_repository(runtime_core.repository):
        raise PackageError(
            "Elder runtime receipt names a different runtime-core repository"
        )
    if parsed["runtime_core_revision"] != runtime_core.revision:
        raise PackageError(
            "Elder runtime receipt names a different runtime-core revision"
        )


def _runtime_core_notice(source_root: Path) -> bytes:
    repository, revision = _runtime_core_lock(source_root)
    return (
        "# enb-runtime-core notice\n\n"
        "ElderENBRuntime.dllplugin statically links the independently maintained "
        "enb-runtime-core library.\n\n"
        f"- Source: {repository}\n"
        f"- Pinned revision: `{revision}`\n"
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
            raise PackageError(
                f"permission-dependent component is forbidden: {raw_path}"
            )

        suffix = PurePosixPath(basename).suffix
        if suffix == ".dllplugin":
            if path.as_posix() != RUNTIME_MEMBER:
                raise PackageError(
                    f"only the Elder-owned runtime plugin may ship: {raw_path}"
                )
        elif suffix in FORBIDDEN_BINARY_SUFFIXES:
            raise PackageError(
                f"compiler, test, archive, or binary artifact is forbidden: {raw_path}"
            )

        for secret_pattern in SECRET_PATTERNS:
            if secret_pattern.search(data):
                raise PackageError(f"secret-like material is forbidden: {raw_path}")


def _manifest_bytes(members: Mapping[str, bytes]) -> bytes:
    return "".join(
        f"{hashlib.sha256(members[path]).hexdigest()}  {path}\n"
        for path in sorted(members)
    ).encode("ascii")


def _expected_release_members() -> set[str]:
    expected = expected_source_members()
    expected.update(
        {
            NATIVE_PARAMETERS_MEMBER,
            RUNTIME_MEMBER,
            RUNTIME_RECEIPT_MEMBER,
            RUNTIME_CORE_LICENSE_MEMBER,
            RUNTIME_CORE_NOTICE_MEMBER,
        }
    )
    expected.add(MANIFEST_MEMBER)
    return expected


def validate_release_members(source_root: Path, members: Mapping[str, bytes]) -> None:
    reject_forbidden_members(members)
    expected = _expected_release_members()
    actual = set(members)
    if actual != expected:
        raise PackageError(
            "archive member set differs from the exact public manifest: "
            f"missing={sorted(expected - actual)}, "
            f"unexpected={sorted(actual - expected)}"
        )
    validate_native_parameters(source_root, members[NATIVE_PARAMETERS_MEMBER])
    validate_runtime_plugin(members[RUNTIME_MEMBER])
    repository, revision = _runtime_core_lock(source_root)
    runtime_core = RuntimeCoreIdentity(
        members[RUNTIME_CORE_LICENSE_MEMBER], repository, revision
    )
    if not runtime_core.license.startswith(b"MIT License"):
        raise PackageError("packaged enb-runtime-core license is not MIT")
    if members[RUNTIME_CORE_NOTICE_MEMBER] != _runtime_core_notice(source_root):
        raise PackageError("packaged enb-runtime-core notice is not canonical")
    if members[RUNTIME_RECEIPT_MEMBER] != _normalized_runtime_receipt(
        members[RUNTIME_RECEIPT_MEMBER]
    ):
        raise PackageError("packaged Elder runtime receipt is not LF-normalized")
    validate_runtime_receipt(
        source_root,
        members[RUNTIME_RECEIPT_MEMBER],
        members[RUNTIME_MEMBER],
        runtime_core,
    )


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
    runtime_receipt: Path,
    runtime_core_root: Path,
) -> ReleaseArtifacts:
    source_root = source_root.resolve()
    members = build_source_payload(source_root, work_dir)

    native_parameters_data = _read_required(
        native_parameters.resolve(), "generated Elder native parameter include"
    )
    validate_native_parameters(source_root, native_parameters_data)
    runtime_plugin = runtime_plugin.resolve()
    if runtime_plugin.name != "ElderENBRuntime.dllplugin":
        raise PackageError(
            "runtime input must be the Elder-owned ElderENBRuntime.dllplugin"
        )
    runtime_data = _read_required(runtime_plugin, "Elder runtime plugin")
    validate_runtime_plugin(runtime_data)
    runtime_receipt = runtime_receipt.resolve()
    if (
        runtime_receipt.name != "ElderENBRuntime.dllplugin.receipt"
        or runtime_receipt.parent != runtime_plugin.parent
    ):
        raise PackageError(
            "runtime receipt must be adjacent to ElderENBRuntime.dllplugin"
        )
    runtime_receipt_data = _normalized_runtime_receipt(
        _read_required(runtime_receipt, "Elder runtime receipt")
    )
    runtime_core = validate_runtime_core(source_root, runtime_core_root)
    validate_runtime_receipt(
        source_root, runtime_receipt_data, runtime_data, runtime_core
    )

    members[NATIVE_PARAMETERS_MEMBER] = native_parameters_data
    members[RUNTIME_MEMBER] = runtime_data
    members[RUNTIME_RECEIPT_MEMBER] = runtime_receipt_data
    members[RUNTIME_CORE_LICENSE_MEMBER] = runtime_core.license
    members[RUNTIME_CORE_NOTICE_MEMBER] = _runtime_core_notice(source_root)
    members[MANIFEST_MEMBER] = _manifest_bytes(members)
    validate_release_members(source_root, members)

    output_dir = output_dir.resolve()
    archive_path = output_dir / ARCHIVE_NAME
    checksum_path = output_dir / f"{ARCHIVE_NAME}.sha256"
    _write_archive(archive_path, members)
    digest = hashlib.sha256(archive_path.read_bytes()).hexdigest()
    output_dir.mkdir(parents=True, exist_ok=True)
    checksum_path.write_bytes(f"{digest}  {ARCHIVE_NAME}\n".encode("ascii"))
    verified = verify_archive(archive_path, source_root=source_root)
    if verified.sha256 != digest:
        raise PackageError(
            "post-write archive verification produced a different digest"
        )
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


def verify_archive(
    archive_path: Path, *, source_root: Path = ROOT
) -> VerificationResult:
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
                    raise PackageError(
                        f"archive must not contain directory entries: {info.filename}"
                    )
            members = {name: archive.read(name) for name in names}
    except (OSError, zipfile.BadZipFile) as error:
        raise PackageError(
            f"cannot read public archive {archive_path}: {error}"
        ) from error

    validate_release_members(source_root.resolve(), members)
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
            raise PackageError(
                f"source payload generation is not byte deterministic: {path}"
            )
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


def _default_runtime_receipt(source_root: Path) -> Path:
    return _default_runtime_plugin(source_root).with_suffix(".dllplugin.receipt")


def default_runtime_core_root(source_root: Path) -> Path:
    source_root = source_root.resolve()
    candidates = [source_root.parent / "enb-runtime-core"]
    if len(source_root.parents) > 1:
        candidates.append(source_root.parents[1] / "enb-runtime-core")
    for candidate in candidates:
        if (candidate / "LICENSE").is_file() and (
            candidate / "CMakeLists.txt"
        ).is_file():
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
    build_parser.add_argument("--runtime-receipt", type=Path)
    build_parser.add_argument(
        "--runtime-core-root", type=Path, default=default_runtime_core_root(ROOT)
    )

    verify_parser = subparsers.add_parser(
        "verify", help="verify an existing public archive"
    )
    verify_parser.add_argument("archive", type=Path)
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
                runtime_receipt=(
                    arguments.runtime_receipt
                    if arguments.runtime_receipt is not None
                    else _default_runtime_receipt(source_root)
                ),
                runtime_core_root=arguments.runtime_core_root,
            )
            print(f"packaged {artifacts.archive}")
            print(f"sha256  {artifacts.sha256}")
            print(f"files   {artifacts.file_count}")
            return 0

        verification = verify_archive(arguments.archive)
        print(
            f"verified {arguments.archive}: {verification.file_count} files; "
            f"SHA-256 {verification.sha256}"
        )
        return 0
    except PackageError as error:
        parser.exit(2, f"error: {error}\n")


if __name__ == "__main__":
    raise SystemExit(main())
