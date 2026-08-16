# Elder ENB release validation

This document describes the public archive contract. It is not a record of
live-game acceptance. Live ENBSeries 0.504 results remain pending until they are
entered after the final runtime-complete archive is built and exercised in the
isolated Mod Organizer profile.

## Archive layout

- `Root/enbseries/` is the copy-ready Balanced installation. It contains the
  nine ordered shader stages, their support includes, exact `.fx.ini` controls,
  the generated native parameter include, and the Elder runtime plugin.
- `Presets/<tier>/enbseries/` contains one complete overlay for Performance,
  Balanced, Quality, Ultra, or Cinematic. Each overlay contains nine exact
  stage configurations, `elder-quality.ini`, and the compile-time
  `elder/ElderTier.fxh` override.
- `Docs/` contains the Elder MIT license, credits, provenance, third-party
  notices, architecture, the runtime build receipt, and the pinned
  `enb-runtime-core` license/notice.
- `Media/Nexus/` contains generated promotional artwork. It is not an in-game
  screenshot and must not be used as rendering evidence.
- `MANIFEST.sha256` hashes every other archive member. The adjacent archive
  checksum hashes the ZIP itself.

## Installation and tier selection

Back up the current game-root `enbseries` directory. Copy the contents of
`Root/` into the game root. Balanced is installed by default.

To select another tier, copy the contents of that tier's `Presets/<tier>/`
directory into the game root and allow it to replace the matching `.fx.ini`
files and `elder/ElderTier.fxh`. The override is compile-time, so reload the ENB
configuration or restart the game after changing tiers.

Do not mix configuration files from different tiers. Runtime sliders remain
available for granular tuning, but the tier file owns fixed sample budgets.

## Offline package checks

Maintainers can validate the shader, preset, documentation, and media boundary
without producing a release archive:

```powershell
python scripts/package.py check-source --work-dir out/public-package/source-check
```

The final build additionally requires the complete generated native-parameter
ABI, the Elder-owned AMD64 PE32+ `ElderENBRuntime.dllplugin`, its adjacent build
receipt, and the clean pinned `enb-runtime-core` checkout:

```powershell
python scripts/package.py build
python scripts/package.py verify dist/Elder-ENB-1.0.0-win64.zip
```

The packager uses an exact allowlist, fixed ZIP timestamps, sorted entries,
and a content manifest. It rejects ENB binaries, legacy Addons/EotE material,
recovered or protected inputs, permission-dependent native replacements,
compiler/debug outputs, nested archives, environment files, and secret-like
material. Verification is always runtime-complete; `check-source` is the only
source-only mode and never emits a release-named archive.

## Live acceptance record

Do not upload the archive until the final release candidate has recorded, at
minimum:

- Performance, Balanced, and Cinematic compilation under ENBSeries 0.504;
- representative exterior, interior, underwater, menu, save/load, and
  configuration-reload behavior;
- high-contrast edge, sky, fog, adaptation, and optical artifact observations;
- selected missing-runtime and no-runtime fail-closed checks;
- the exact game version, tier, location, weather, and runtime status for every
  visual comparison.

Unrun combinations remain unaccepted and must not be described as passing.
