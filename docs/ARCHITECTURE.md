# Elder ENB architecture

Elder is an independently authored ENBSeries 0.504 shader suite with a small,
typed native publication boundary. Rendering remains in ENB's normal shader
stages; the runtime does not inject draw calls or replace the engine pipeline.

## Ordered shader frame

The host order is fixed and treated as an API:

1. `enbeffectprepass.fx` — depth-safe masks, room-light reach, bounded
   current-frame scene effects, and far-depth atmosphere fallback.
2. `enbdepthoffield.fx` — focus and circle-of-confusion response only.
3. `enbbloom.fx` — contribution-only HDR radiance extraction and filtering.
4. `enbadaptation.fx` — finite luminance metering and bounded scalar history.
5. `enblens.fx` — contribution-only glare, ghost, and halo response sourced
   from bloom.
6. `enbeffect.fx` — single scene/bloom/lens composition, exposure, color core,
   tone mapping, and gamut control.
7. `enbeffectpostpass.fx` — minimal display-space finish with dithering as its
   final color operation.
8. `enbsunsprite.fx` — bounded celestial optics without a second exposure or
   bloom pass.
9. `enbunderwater.fx` — one exclusive underwater absorption/scattering medium.

Each stage has one owner and an identity value. A disabled stage, zero
intensity, invalid input, or unavailable capability chooses that identity or a
documented finite fallback instead of leaking an invalid intermediate into the
next stage.

## Shared shader contracts

`shaders/elder/` contains the shared stage, quality, finite-value, capability,
and effect modules. `native/shaders/ElderColorCore.fxh` is the Elder-owned typed
color implementation consumed by the main effect. The generated
`ElderNativeParameters.fxh` is built from the canonical native schema and ships
beside the main shader.

Modern inputs follow one capability order:

```text
valid native host input
    -> versioned SkyrimBridge-compatible input
        -> stable bounded spatial fallback
            -> exact identity
```

No stage may promote a current-frame target to persistent history, invent
object motion, or share packed channels without a declared ownership contract.
Bridge-consuming stages retain direct bindings where required, while the public
suite remains usable without SkyrimBridge.

## Five quality tiers

`config/quality-tiers.csv` owns Performance (0), Balanced (1), Quality (2),
Ultra (3), and Cinematic (4). `ElderTier.fxh` selects the tier at compile time;
loop bounds and feature budgets are therefore fixed shader permutations rather
than runtime branches. Balanced is the copy-ready default.

The preset generator emits exactly 55 files: five directories, each with nine
stage `.fx.ini` files, one `elder-quality.ini`, and one
`enbseries/elder/ElderTier.fxh` override. Stage INI keys are the exact shader
`UIName` labels, so configuration cannot silently target an HLSL identifier the
ENB serializer does not recognize.

## Runtime publication boundary

`ElderENBRuntime.dllplugin` uses the pinned `enb-runtime-core` dependency and
ENB's parameter API to publish validated hidden values. A frame transaction
writes invalid status first, payload values second, and valid status last.
Failure restores captured authored values. Reset, save, and exit restore the
baseline; malformed or unavailable payloads fail closed.

The plugin is the only binary admitted to the public archive. ENB binaries,
native replacement suites, compiler outputs, debug symbols, and test programs
are outside the runtime boundary.

## Supporting tools

The transactional profile, legacy identity audit, and migration tools under
`src/`, `include/`, and `config/` are maintainer infrastructure. They can read
explicitly supplied historical inputs to produce Elder-owned metadata and
configuration, but historical record bodies, recovered shaders, and protected
evidence never enter the public package.

## Release boundary

The public packager constructs an exact allowlist instead of copying a staging
directory. It generates presets from the canonical CSV, selects the nine stage
files and support includes, installs Balanced as the default, adds the Elder
runtime and required licenses, then hashes every member in `MANIFEST.sha256`.
ZIP entry order, timestamps, permissions, compression settings, archive name,
and checksum format are fixed. Two independent builds must be byte-identical.

Generated Nexus artwork is packaged separately under `Media/Nexus/` and is
explicitly promotional, not gameplay evidence. Public upload remains gated on
the final runtime-complete archive and the recorded ENB 0.504 live acceptance
matrix.
