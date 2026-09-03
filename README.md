# Elder ENB

<img src="docs/art/elder-enb-header.svg" alt="Elder ENB, an ENBSeries 0.504 shader suite for Skyrim, with its release harness. Declare every input, or the stage does not compile.">

Elder ENB is an independently authored ENBSeries 0.504 shader-suite and
release-harness project for Skyrim Special Edition / Anniversary Edition. The
public release target is a restrained, professional, cinematic baseline: one
fixed ENB render order, five real quality tiers, bounded controls, exact
identity fallbacks, and documentation that separates proven source behavior from
unfinished release acceptance.

This checkout is not a Nexus upload artifact. Upload remains blocked until the
final public archive and checksum are produced, inspected, and recorded; live
ENB 0.504 acceptance is recorded at minimum for Performance, Balanced, and
Cinematic; selected no-runtime / missing-runtime checks are recorded; and any
media or visual claims are backed by labeled real in-game captures.

<img src="docs/art/suite-table.svg" alt="A table of thirteen rows: what the suite declares, how many of it there are, and where each number is read from. There are five quality tiers and seven knobs resolve per tier. Each tier generates eleven installed files. The compile matrix is nine stages by five tiers, so forty-five compilations, and eight negative fixtures have to fail alongside them. A stage must make seventeen contract declarations before it compiles at all. The capability ladder has four rungs. The native parameter schema carries sixteen rows, the runtime publishes three hidden float4 keys, and the publication machine has eleven phases. Packaging refuses the payload on any of fifty-two rules. Forty CTest targets are declared across three CMake files. No live ENBSeries 0.504 acceptance is recorded anywhere in the tree, so nothing here is evidence about how the suite looks in the game.">

## Public release architecture

The public shader suite is organized around ENB's fixed stage order. Elder
treats that order as an API rather than as a loose pile of effects:

| Order | Stage | File | Stage contract / responsibility | Accepted live behavior in this copy |
|---:|---|---|---|---|
| 1 | Prepass | `shaders/enbeffectprepass.fx` | Depth convention, masks, room-light reach, bounded current-frame AO, and far-depth atmosphere fallback. No live fog behavior is claimed here. | Pending final archive and live ENB 0.504 evidence; unaccepted paths stay identity. |
| 2 | Depth of field | `shaders/enbdepthoffield.fx` | Lens focus only; no grading, vignette, sharpening, or atmosphere. | Pending final archive and live ENB 0.504 evidence; unaccepted paths stay identity. |
| 3 | Bloom | `shaders/enbbloom.fx` | Radiance extraction and filtering. | Pending final archive and live ENB 0.504 evidence; unaccepted paths stay identity. |
| 4 | Adaptation | `shaders/enbadaptation.fx` | Bounded luminance metering / exposure-history contract. | Pending final archive and live ENB 0.504 evidence; unaccepted paths stay identity. |
| 5 | Lens | `shaders/enblens.fx` | Restrained glare, ghost, and halo behavior when final integration is accepted; no dirt pass or dirt texture. | Pending final archive and live ENB 0.504 evidence; no dirt behavior is accepted. |
| 6 | Main effect | `shaders/enbeffect.fx` | Scene, bloom, lens, exposure, color core, tone mapping, and gamut compression. | Pending final archive and live ENB 0.504 evidence; unaccepted paths stay identity. |
| 7 | Postpass | `shaders/enbeffectpostpass.fx` | Final LDR finishing; dithering is last and sharpening is off by default. | Pending final archive and live ENB 0.504 evidence; unaccepted paths stay identity. |
| 8 | Sun sprite | `shaders/enbsunsprite.fx` | Bounded sun optical response without duplicating bloom or exposure. | Pending final archive and live ENB 0.504 evidence; unaccepted paths stay identity. |
| 9 | Underwater | `shaders/enbunderwater.fx` | One underwater medium model while suppressing incompatible air, grading, and duplicate god-ray effects. | Pending final archive and live ENB 0.504 evidence; unaccepted paths stay identity. |

The release target is broader than the earlier dither-focused slice. Temporal
dither is one native helper and optional integration point; the public suite is
the ordered nine-stage shader contract above, with the current implementation
kept identity-preserving where a later visual payload has not yet been accepted.

## Quality tiers

<img src="docs/art/tier-to-archive.svg" alt="Eight stages taking a quality tier to an installed preset: tier row, generator, stage ini, tier header, compile, refusals, package, archive. The canonical manifest is a five-row table with ten fields per row, and the generator raises a fatal error rather than guessing when a row is short, misordered or non-canonical. Each tier produces eleven files: one quality ini, one tier include that carries the budgets, and nine per-stage ini files. Every stage ini writes TECHNIQUE=1 directly under its stage section, because without that key ENB falls back to its own internal default shader and none of the Elder passes render at all. Seven knobs resolve per tier: ambient occlusion directions and steps, screen-space reflection steps, depth of field rings, bloom radius, lens ghosts and room light refinement. The same seven are declared twice, once as columns in the manifest and once as preprocessor arms in the shader header, and a change to one alone is caught as disagreement. Nine ENB stage effects are then compiled once per tier for forty-five builds: prepass, depth of field, bloom, adaptation, lens, main effect, postpass, sun sprite and underwater. Eight negative fixtures edit a stage source and each has to be rejected, covering full-frame history, object motion, foreign scratch reads, scratch treated as history, cross-effect alpha packing, non-adaptation previous-texture reads, a false resource declaration and a synthesized vertex stage. Packaging validates the source payload against fifty-two refusal rules spanning forbidden path components, name markers, binary suffixes, ENB binary names and secret patterns. Three outcomes: every stage compiles at every tier, a compiled shader is not an accepted one, and a tier outside zero through four is refused.">

`config/quality-tiers.csv` defines five quality tiers, and
`shaders/elder/ElderQuality.fxh` defaults `ELDER_QUALITY_TIER` to `1`
(`Balanced`):

| Tier | Name | Role |
|---:|---|---|
| 0 | Performance | Essential color / room-light path, low sample budgets, DOF disabled by default, SSR identity/unshipped. |
| 1 | Balanced | Default tier; restrained DOF, low-cost AO budget, simple lens response, stable scene readability. |
| 2 | Quality | Standard optical budgets; SSR budget is reserved/configured only. |
| 3 | Ultra | Higher optical and scene-space budgets with improved depth refinement. |
| 4 | Cinematic | Highest bounded budgets and photographic refinement without effect stacking. |

The public archive must contain complete tier outputs generated from this
manifest, but this README intentionally does not claim a current release-archive
file count. The final package manifest is a release gate, not a marketing
sentence.

Each tier's nine per-stage `.fx.ini` files carry `TECHNIQUE=1` directly under
the stage section. Index 1 selects the first declared Elder technique in that
stage; without the key, ENB falls back to its internal DEFAULT shader in every
stage and none of the Elder passes render.

Reserved/configured SSR budgets are not a live effect claim. SSR remains
identity/unshipped until an implementation is integrated, accepted, and recorded
in the final archive evidence.

## Capability ladder and fail-closed behavior

<img src="docs/art/capability-ladder.svg" alt="Eight stages resolving one shader input: stage header, capability level, ownership, scratch, native, bridge, spatial, identity. Every Elder stage must define seventeen contract macros before it includes the shared header, and a missing one raises a compile error naming the declaration that is absent. The capability level is one of four rungs, ordered identity, spatial, bridge, native, and a stage that declares an input above its own level is refused. Ownership is declared per surface: colour, depth, normal, mask, the native celestial and view inputs, the previous scalar adaptation, and the bridge value. Current-frame scratch has ten named surfaces, and a stage may read only the one it owns. Resolution then descends the ladder. The native route is taken first when the stage declares a native input and that input reports availability. The bridge route is a versioned SkyrimBridge-compatible value, one rung down. The spatial route is a bounded reconstruction from what is already drawn. When no route has confidence, the stage returns the exact Elder-authored identity pixel. Full-frame history, object motion, scratch treated as history and cross-effect alpha packing are each refused outright in this release. Three outcomes: a declared input answered on the native or bridge route, a bounded spatial fallback that is named as a fallback, and the authored pixel unchanged.">

Every modern technique follows the same route:

1. use a valid native ENB / Elder runtime input;
2. use a versioned SkyrimBridge-compatible value or reconstruction when the
   user has such a bridge and the stage declares that input;
3. use a stable, bounded spatial fallback;
4. return the exact Elder-authored identity when confidence is insufficient.

`shaders/elder/ElderPipelineCommon.fxh` resolves capability in that order and
returns identity when no higher-confidence route is available. Stage intensity
`0` is identity, disabled stages are identity, and non-finite values are handled
at stage boundaries rather than being allowed to leak into later composition.

SkyrimBridge, KreatE, Silent Horizons, AELAS/EVLaS, ELIF, NativeEditorID Fix,
ENBWorldspaceWeatherlists/KiLoader, and other permission-gated or historical
tools are not hard runtime requirements for the independent public suite. Elder
may interoperate with compatible public formats and workflows, but it does not
ship proprietary implementations or permission-dependent replacement components.

## Runtime payload status

The native runtime source defines an optional ENB parameter payload named
`ElderRuntimeFramePulse`. The runtime policy is fail-closed: a withheld,
rejected, malformed, or absent live pulse becomes the all-zero inactive payload
instead of leaving stale values visible to shaders.

Treat all runtime-payload shipping and gameplay claims as conditional until the
public archive proves the runtime is integrated and live ENB 0.504 acceptance is
recorded. If the runtime is not present, shaders must select the documented
fallback or identity path.

## Source areas

- `shaders/` and `shaders/elder/` contain the public ENB stage files and shared
  Elder shader contracts.
- `config/quality-tiers.csv` is the canonical five-tier manifest.
- `native/` contains the typed native parameter ABI, color/room-light helpers,
  artifact publication code, and optional runtime source.
- `src/`, `include/`, and `config/legacy-kreate-bindings.csv` contain the
  transactional profile, legacy metadata/audit, first-five bundle, and weather
  migration tooling. These tools are recovery and generation infrastructure;
  legacy record bodies and protected evidence are not copied into public source
  or package output.
- `CREDITS-AND-PROVENANCE.md` and `THIRD_PARTY_NOTICES.md` record attribution,
  ownership boundaries, and excluded third-party/proprietary material.

## Maintainer build and verification commands

The root CMake presets target Visual Studio 18 2026 x64, C++23, and the static
MSVC runtime:

```powershell
cmake --preset vs2026-x64
cmake --build --preset vs2026-debug
ctest --preset vs2026-debug --output-on-failure --no-tests=error
```

Release gates for the public shader suite are broader than a normal build. The
ordered-suite plan requires strict stage compilation across all five tiers,
native/color/room-light parity checks, generated preset/package determinism,
archive exclusion checks, and live ENB 0.504 acceptance before public upload.
This documentation pass did not run builds, tests, package generation, or live
game validation.

## License

The Elder-owned source and documentation in this repository are licensed under
the MIT License; see [LICENSE](LICENSE). MIT applies only to code and
documentation the project owns. It does not grant rights to ENBSeries,
SkyrimBridge, Kitsuune/LonelyKitsuune/Skratzer/T. Thanner implementations,
ReShade/ADOF work, ReforgedUI, recovered legacy material, protected evidence,
proprietary plugin binaries, or any other third-party material.

Preserve prior shader-author attribution in headers, notices, public pages, and
archives. If the final archive adds any third-party file or linked component,
update `THIRD_PARTY_NOTICES.md` before upload.
