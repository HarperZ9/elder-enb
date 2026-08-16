# Elder ENB Ordered Five-Tier Public Shader Suite

## Purpose

Elder ENB will replace its dense legacy-adapted surround with an independently
authored, restrained, coherent ENBSeries 0.504 shader suite. The release look is
professional, seamless, timeless, and cinematic, with granular controls that
remain safe and understandable.

The rewrite covers the complete shipped shader chain and its configuration:

1. `enbeffectprepass.fx`
2. `enbdepthoffield.fx`
3. `enbbloom.fx`
4. `enbadaptation.fx`
5. `enblens.fx`
6. `enbeffect.fx`
7. `enbeffectpostpass.fx`
8. `enbsunsprite.fx`
9. `enbunderwater.fx`

The existing Elder color core, room-light model, typed parameter ABI,
transactional profile system, WARP parity tests, runtime-core dependency, and
attribution are retained. Legacy shader source is evidence and lineage, not an
implementation base for the new public tree.

## Selected architecture

Elder uses one modular source tree with five compile-time permutations and five
generated complete presets. It does not duplicate five shader trees and does
not place all features behind runtime branches in a monolithic effect.

Product modules have one responsibility:

- `contract`: ENB host inputs, finite-value sanitizers, depth convention,
  runtime publication, and `SB_Retain` interoperability;
- `scene`: depth-safe masks and HDR scene augmentation;
- `lighting`: Elder room light, exterior reach, ambient response, and weather
  coupling;
- `optics`: depth of field, bloom, lens response, and sun sprite;
- `color`: exposure, `ElderColorCore`, gamut management, and restrained finish;
- `quality`: tier constants, feature availability, and stage budgets.

The runtime callback is a parameter-publication boundary, not a hidden renderer.
It publishes validated Elder state through ENB's parameter API; the nine normal
ENB shader files own rendering. This avoids an unsupported draw-injection path
and makes the visual payload inspectable and user-configurable.

## Modern-technique compatibility renderer

Elder treats ENB's fixed stages, ordered sub-techniques, and named render
targets as a small compatibility framegraph. Modern effects are backported
inside that graph when Skyrim does not expose their ideal engine pipeline;
missing compute, arbitrary history, or object motion does not automatically
remove an effect.

The verified installed host surface includes HDR color and depth, engine
normals and material mask in prepass, celestial/view data, a multiresolution
bloom chain, one-pixel adaptation history, and current-frame scratch targets.
Each stage declares its inputs, scratch owner, lifetime, resolution, and
fallback level. A render target is current-frame-only unless live validation
proves persistence. Alpha or spare color channels cannot be shared by effects
without an explicit packing contract and round-trip test.

Every modern technique follows the same capability ladder:

1. use a valid native ENB input;
2. use a versioned SkyrimBridge value or reconstruction;
3. use a stable, bounded spatial approximation;
4. return the exact Elder-authored identity when confidence is insufficient.

The public suite may backport depth/normal horizon AO and contact shadows,
material-aware separable SSS, bounded far-depth atmosphere fallback,
signed-circle-of-confusion DOF, multiresolution bloom, robust adaptation, and
luminance-preserving tone/gamut mapping. Reserved/configured SSR budgets remain
identity/unshipped until implemented and accepted. Camera-only reprojection is
never presented as object motion, a luma delta is not a motion vector, and a
current-frame target is not persistent history. Temporal upscaling, temporal
SSGI/SSR denoising, frame generation, and reservoir reuse remain Bridge-assisted
upgrade paths; the initial release uses documented spatial fallbacks.

Atmosphere guidance is adapted to ENB's budget and stage order from Sébastien
Hillaire's production atmosphere technique
(https://sebh.github.io/publications/egsr2020.pdf) and Maxime Heckel's
explanatory implementation
(https://blog.maximeheckel.com/posts/on-rendering-the-sky-sunsets-and-planets/).
It does not transplant a full-resolution nested view/light march.

## ENB render order and ownership

The fixed host order is treated as an API:

1. **Prepass, HDR:** reconstruct depth once; create exterior/interior and
   material-safe masks; provide room-light reach, bounded current-frame AO, and
   far-depth atmosphere fallback. No live fog behavior is claimed until final
   integration and acceptance evidence records it.
2. **Depth of field, HDR:** perform lens focus only. No grading, vignette,
   sharpening, or atmosphere is allowed here.
3. **Bloom, HDR:** extract and filter radiance. No tone mapping, dirt pass, or
   unrelated blur.
4. **Adaptation, HDR:** meter robust luminance and publish bounded exposure
   history with stable interior/exterior transitions.
5. **Lens, HDR:** consume bloom for restrained glare, ghosts, and halo only
   after accepted final integration. No dirt pass or dirt texture is part of the
   accepted behavior. Zero intensity is an exact identity.
6. **Main effect, HDR to display:** combine scene, bloom, and lens once; apply
   exposure, `ElderColorCore`, tone mapping, and gamut compression.
7. **Postpass, LDR:** optional fine grain and vignette, then final triangular
   dithering. Sharpening is disabled by default and never follows dithering.
8. **Sun sprite:** add a bounded optical response without duplicating bloom or
   exposure.
9. **Underwater:** use one underwater medium model and suppress incompatible
   air, grading, and duplicate god-ray effects.

## Five quality tiers

`ELDER_QUALITY_TIER` is an integer from 0 through 4. Tier loop bounds and
feature availability are compile-time constants. Runtime intensities are
granular but bounded.

| Tier | Name | Baseline |
|---:|---|---|
| 0 | Performance | Essential color/room light, low-sample bloom, DOF disabled by default, SSR identity/unshipped |
| 1 | Balanced | Restrained DOF, low-cost AO budget, simple lens response, stable scene readability |
| 2 | Quality | Standard DOF/bloom, reserved/configured SSR budget that remains identity/unshipped until implemented and accepted |
| 3 | Ultra | Higher optical and scene-space sampling with improved depth refinement |
| 4 | Cinematic | Highest bounded sampling and photographic refinement without effect stacking |

Each tier has a complete preset containing shader flags, intensities, sample
budgets, ENB configuration, and metadata. All tiers preserve the Elder look:
the same exposure intent, neutral balance, black point, highlight behavior, and
scene readability. The authored default is **Balanced**.

Granular controls are grouped by render stage and ordered by common use:
master, tier/reset, intensity, advanced shape, diagnostics. Resetting a tier
restores its complete baseline.

## Artifact prevention

- One declared depth convention and sky/interior feather is shared by every
  depth-aware module.
- World-stable sampling replaces uncontrolled frame-random jitter when no
  temporal resolve exists.
- Missing history or velocity selects the documented spatial fallback; it does
  not enable guessed reprojection or unverified target persistence.
- Scratch-target and packed-channel ownership is statically checked so one
  modern effect cannot consume another effect's transient data.
- Room light, bloom, lens, vignette, grain, and underwater response each compose
  exactly once when accepted; live fog behavior is not claimed without final
  integration evidence.
- The room-light input is validated and bounded before publication. Sealed
  rooms preserve only their authored ambient floor.
- Every public control has an exact identity value and bounded maximum.
- Non-finite scene and parameter values are handled at stage boundaries.
- LDR postpass writes stable alpha and applies dithering last.

## Configuration and packaging

The existing typed native parameter schema remains canonical for the color
core. A new canonical tier manifest describes the nine-stage suite. A generator
emits all five preset directories and `.ini` values deterministically, with the
manifest hash recorded in generated output.

The public package contains Elder-authored shaders/configuration, generated
presets, documentation, and the Elder runtime plugin. It does not contain ENB
binaries, legacy adapted shaders, protected evidence, recovered corpus,
compiler/test binaries, or uncleared plugin replacements.

## Provenance and interoperability

Kitsuune/LonelyKitsuune is credited for KreatE, AELAS/EVLaS, ELIF,
NativeEditorID Fix, ENBWorldspaceWeatherlists/KiLoader, and the relevant legacy
shader lineage. Elder compatibility uses independently authored typed schemas
and adapters for public formats and workflows.

Public source and packages contain no proprietary plugin binaries, private
reverse-engineering specifications, or recovered implementation. A component
whose replacement distribution requires permission remains outside the public
archive until that permission is recorded. Credits distinguish original
authorship, compatible interface behavior, and Elder implementation ownership.

## Verification

Implementation is accepted when:

- all nine stages compile in all five tiers with strict FXC settings;
- stage and tier instruction/sample budgets are recorded;
- Elder color and room-light CPU/WARP parity stays green;
- reference cases cover daylight, night, exterior/interior transitions, sealed
  room, high-contrast edges, underwater, and missing-runtime fallback;
- exact identity controls and single-application composition are checked;
- native, Bridge-assisted, spatial-fallback, and identity capability paths are
  exercised without changing stage order;
- scratch lifetimes and packed-channel ownership match the declared
  compatibility framegraph;
- generated presets match the tier manifest and shader symbols;
- two package runs produce byte-identical archives and checksums;
- the archive contains no protected input, private reversal material, legacy
  shader source, or ENB binary;
- live ENB 0.504 validation covers camera/FOV, weather, interiors, menus,
  save/load, configuration reload, and fail-closed runtime removal.

Offline checks establish compilation, math, budgets, determinism, and package
contents. Final public upload still requires the live-game acceptance matrix.
