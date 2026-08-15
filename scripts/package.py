#!/usr/bin/env python3
"""Assemble the Elder ENB staging archive.

Elder had no packaging target. CPack in native/ produces only the shader
schema, which leaves out the two things a reviewer actually wants to look at:
the five quality-tier preset trees and the runtime plugin.

    cmake --preset vs2026-x64 && cmake --build out/build/vs2026-x64 --config Release
    cmake --preset vs18-x64-static   # in native/
    cmake --build out/native-schema/vs18-x64-static --config Release
    python scripts/package.py

Deterministic: fixed ZIP timestamps, sorted entries, and a SHA-256 sidecar, so
two runs over the same inputs produce identical bytes.
"""
from __future__ import annotations

import hashlib
import os
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VERSION = "1.0.0"
DIST = ROOT / "dist"
STAGE = DIST / f"ElderENB-{VERSION}"
FIXED_TIMESTAMP = (2000, 1, 1, 0, 0, 0)

NATIVE_BUILD = ROOT / "out" / "native-schema" / "vs18-x64-static"
RUNTIME_PLUGIN = NATIVE_BUILD / "runtime" / "Release" / "ElderENBRuntime.dllplugin"

DOCS = (
    ("README.md", "Docs/README.md"),
    ("LICENSE", "Docs/LICENSE"),
    ("native/NOTICE.md", "Docs/NOTICE.md"),
    ("docs/ARCHITECTURE.md", "Docs/ARCHITECTURE.md"),
    ("config/quality-tiers.csv", "Docs/quality-tiers.csv"),
)


def copy(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dst)


def generate_presets(out_dir: Path) -> None:
    """Run the canonical generator rather than copying build leftovers."""
    subprocess.run(
        [
            "cmake",
            f"-DELDER_SOURCE_DIR={ROOT}",
            f"-DELDER_OUTPUT_DIR={out_dir}",
            "-P",
            str(ROOT / "cmake" / "GenerateElderQualityPresets.cmake"),
        ],
        check=True,
        capture_output=True,
    )


def main() -> int:
    if not RUNTIME_PLUGIN.is_file():
        raise SystemExit(f"build the native runtime first; missing {RUNTIME_PLUGIN}")

    if STAGE.exists():
        shutil.rmtree(STAGE)
    STAGE.mkdir(parents=True)

    # Five quality-tier preset trees: nine .fx.ini plus elder-quality.ini each.
    generate_presets(STAGE / "Presets")

    # The runtime plugin. It publishes the frame pulse each BeginFrame, which
    # ElderTemporalDither.fxh consumes to advance the dither pattern.
    copy(RUNTIME_PLUGIN, STAGE / "Root" / "enbseries" / RUNTIME_PLUGIN.name)

    # Native shader schema: generated HLSL, the compiled reference object, the
    # parameter manifest, and the default profile.
    schema = NATIVE_BUILD / "packages" / "_CPack_Packages"
    for produced in sorted(NATIVE_BUILD.rglob("ElderNativeParameters.fxh"))[:1]:
        copy(produced, STAGE / "Native" / "Shaders" / produced.name)

    # Hand-written shader headers. ElderRuntimeParameters.fxh declares the
    # symbol the runtime plugin writes each frame, so the plugin and this header
    # have to ship together: without it the parameter has nowhere to land.
    for name in ("ElderRuntimeParameters.fxh", "ElderTemporalDither.fxh",
                 "ElderDisplayOutput.fxh", "ElderColorCore.fxh",
                 "ElderRoomLight.fxh"):
        source = ROOT / "native" / "shaders" / name
        if source.is_file():
            copy(source, STAGE / "Native" / "Shaders" / name)
    for name in ("ElderColorReference.cso", "elder-native-parameters.json",
                 "elder-native-default.profile"):
        for produced in sorted(NATIVE_BUILD.rglob(name))[:1]:
            copy(produced, STAGE / "Native" / produced.name)
    del schema

    for source, destination in DOCS:
        path = ROOT / source
        if path.is_file():
            copy(path, STAGE / destination)

    archive = DIST / f"ElderENB-{VERSION}-staging.zip"
    if archive.exists():
        archive.unlink()
    entries = sorted(
        p for p in STAGE.rglob("*") if p.is_file()
    )
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as zf:
        for path in entries:
            relative = path.relative_to(STAGE).as_posix()
            info = zipfile.ZipInfo(relative, date_time=FIXED_TIMESTAMP)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            zf.writestr(info, path.read_bytes())

    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    archive.with_suffix(archive.suffix + ".sha256").write_text(
        f"{digest}  {archive.name}\n", encoding="ascii"
    )

    print(f"packaged {archive} ({archive.stat().st_size / 1024:.0f} KiB)")
    print(f"sha256  {digest}")
    print(f"  {len(entries)} files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
