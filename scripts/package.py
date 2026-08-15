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
    ("docs/PRESET-INTEGRATION.md", "Docs/PRESET-INTEGRATION.md"),
    ("config/quality-tiers.csv", "Docs/quality-tiers.csv"),
)


EOTE_READ_ME = """Optional: the EotE HDR compositor, wired to the Elder frame pulse.

WHAT THIS IS

enbeffect.fx from the "ENB of the Elders" preset, with two Elder changes:
the runtime frame pulse is declared, and the dither it already had is
advanced by the frame counter so the pattern moves instead of sitting
still. That removes the fixed grain you can otherwise see over smooth
gradients in night skies and fog.

WHO SHOULD INSTALL IT

Only install this if you already run the EotE preset.

The EotE stack is nine .fx files and this is one of them. Copying it over a
different preset replaces that preset's main compositor, which changes your
whole look rather than just its dithering. If you use any other preset, do
not copy this: read Docs/PRESET-INTEGRATION.md and make the same two edits
to your own enbeffect.fx instead. It is about ten lines.

HOW TO INSTALL

Copy enbeffect.fx, enbglobals.fxh, Helper/ and Addons/ into your game-root
enbseries folder, over the EotE files already there. Back up your existing
enbeffect.fx first.

The Elder runtime plugin is what publishes the pulse. Without it these
shaders still work and the dither is simply static, exactly as it was.

ATTRIBUTION

These are not Elder's shaders. Read PROVENANCE.md in this folder before
redistributing any of them.
"""


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

    # The EotE compositor that reads the frame pulse.
    #
    # Deliberately NOT placed under Root/enbseries. The full EotE stack is nine
    # .fx files and this is one of them, so copying it blindly into a user's
    # enbseries folder replaces whatever main compositor they already have.
    # For a non-EotE preset that is not a dither improvement, it is a silent
    # preset swap. It ships as an opt-in folder with instructions instead.
    #
    # PROVENANCE.md travels with the shaders. These are not Elder's files and
    # the attribution has to be in the same folder as the thing it attributes,
    # not left behind in the repository.
    for name in ("enbeffect.fx", "enbglobals.fxh", "PROVENANCE.md"):
        copy(ROOT / "presets" / "eote" / name,
             STAGE / "Optional-EotE-Compositor" / name)
    for sub in ("Helper", "Addons"):
        source_dir = ROOT / "presets" / "eote" / sub
        for produced in sorted(source_dir.glob("*.fxh")):
            copy(produced, STAGE / "Optional-EotE-Compositor" / sub / produced.name)
    (STAGE / "Optional-EotE-Compositor" / "READ-ME.txt").write_text(
        EOTE_READ_ME.replace("\n", "\r\n"), encoding="ascii"
    )

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
