# Elder ENB

Elder ENB begins with a transactional profile core: one `ProfilePackage` binds an overlay ID, a preset ID, and an ordered list of value operations. The engine validates and stages the complete package before changing observable state, so callers cannot accidentally apply only the overlay or only the preset and still receive success.

## What This Slice Guarantees

- `Apply` rejects malformed packages before mutation.
- Every valid package stages from the immutable baseline, preventing additive or multiplicative accumulation across selections.
- Values, active package identity, and generation commit together.
- Every API path returns a structured result and one or more stable diagnostics.
- Reapplying the exact active package returns `ALREADY_ACTIVE` without mutation or a generation increment.
- `RemoveActive` restores the baseline in one commit; removing with no active package returns `NO_ACTIVE_PROFILE`.

The current operation kinds are `Set`, `Add`, and `Multiply`. Multiply operands must be finite and strictly greater than zero.

## Build and Test

Requirements:

- CMake 4.2 or newer
- Visual Studio 18 2026 with the x64 MSVC toolchain

```powershell
cmake --preset vs2026-x64
cmake --build --preset vs2026-debug
ctest --preset vs2026-debug --output-on-failure --no-tests=error
```

The preset selects `Visual Studio 18 2026`, x64, C++23, and the static MSVC runtime (`/MT`, or `/MTd` for Debug).

## API Shape

```cpp
#include <elder/profiles/TransactionalProfile.hpp>

using namespace elder::profiles;

TransactionalProfile profiles{{
    {"exposure", 1.0},
    {"saturation", 1.0},
}};

ProfilePackage package{
    "elder.overlay.cinematic",
    "elder.preset.twilight",
    {
        {"exposure", OperationKind::Add, 0.25},
        {"saturation", OperationKind::Multiply, 1.1},
    },
};

const ProfileReport report = profiles.Apply(package);
if (!report.committed()) {
    // Inspect report.result and report.diagnostics; failure is never silent.
}
```

## Stable Diagnostic Codes

| Code | Meaning |
|---|---|
| `PROFILE_APPLIED` | A complete package committed. |
| `PROFILE_ALREADY_ACTIVE` | The exact package is already active; no state changed. |
| `PROFILE_REMOVED` | Active state was removed and baseline restored. |
| `NO_ACTIVE_PROFILE` | Removal was requested with no active package. |
| `EMPTY_OVERLAY_ID` | The overlay ID is empty. |
| `EMPTY_PRESET_ID` | The preset ID is empty. |
| `EMPTY_OPERATIONS` | The package has no operations. |
| `UNKNOWN_TARGET_KEY` | An operation targets a key absent from the baseline. |
| `DUPLICATE_TARGET_KEY` | More than one operation targets the same key. |
| `NON_FINITE_VALUE` | An operand or staged result is NaN or infinity. |
| `INVALID_MULTIPLY_OPERAND` | A multiply operand is zero or negative. |

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the state transition and failure model.

## Legacy KreatE Binding Compiler

`elder_binding_compiler` validates the recovered overlay ↔ preset relationship against [config/legacy-kreate-bindings.csv](config/legacy-kreate-bindings.csv). The reviewed catalog contains 37 selected bindings, 18 retired divergent duplicates, and four explicit aliases. It locks exact source filenames/directories and SHA-256 values; runtime selection never uses timestamps.

The scanner captures only `[OVERLAYINFO]` `UIName`, `UIGroups`, and `UIOrdering`, plus the five identity fields in `PresetInfo.ini`. Source files are otherwise handled only as opaque SHA-256 byte streams. Generated manifests contain IDs and hashes, never legacy operation bodies.

```powershell
cmake --preset vs2026-x64
cmake --build --preset vs2026-debug
ctest --preset vs2026-debug --output-on-failure --no-tests=error
```

The integration CTest runs the CLI against the configured read-only roots and writes its deterministic manifest/report under `out/build/vs2026-x64/artifacts/task-02/`. Any missing, changed, ambiguous, duplicate, orphaned, unaccounted, or unbound entry fails closed.

The normal build contains no workstation-specific source path. To enable the
read-only recovery integration test, configure both external roots explicitly:

```powershell
cmake --preset vs2026-x64 `
  -DELDER_LEGACY_OVERLAY_ROOT="<absolute overlay directory>" `
  -DELDER_LEGACY_PRESET_ROOT="<absolute KreatE preset directory>"
```

If neither root is supplied, the portable unit-test suite remains enabled and
the recovery-only integration test is omitted. Supplying only one root, or a
relative root, fails configuration.

## Legacy KreatE Record Auditor

`elder_preset_auditor` recursively validates only the 37 preset directories
selected by the binding catalog. It tokenizes UTF-8 INI structure, validates
record identity and typed values, detects duplicate keys/sections and record
identities, and hashes every INI plus a normalized per-preset tree. Its
manifest and report contain only relative identities/paths, hashes, counts,
line numbers, and stable diagnostic codes; legacy record bodies are never
copied into generated output.

Content findings do not abort the default audit. `--fail-on-findings` provides
an explicit strict mode for release gates, while I/O, UTF-8, and structural
parse faults always fail. The large read-only corpus integration is Release
only; Debug retains the fast unit and binding suites:

```powershell
cmake --build --preset vs2026-debug
ctest --preset vs2026-debug --output-on-failure --no-tests=error
cmake --build --preset vs2026-release
ctest --preset vs2026-release --output-on-failure --no-tests=error
```

Against the current recovered corpus, the integration accounts for 37 presets
and 49,358 INIs. It reports 1,077 `INVALID_NUMERIC_TOKEN` findings across four
presets and 481 `SUSPICIOUS_DUPLICATE_FILENAME` findings (13 per preset), with
zero fatal errors. These are repair inputs rather than silently ignored load
failures.

## First-Five Paired Improvement Bundles

`elder_profile_bundle_compiler` turns the guarded rules in
[`config/first-five-improvements.csv`](config/first-five-improvements.csv) into
complete one-selection bundles for 10.28.16, 11.11.11, Arrival of Autumn,
Jötunheimar, and Neutral. Each bundle contains exactly one overlay and its full
KreatE preset tree. They are not independent menu choices.

The compiler verifies the selected binding, source file SHA-256 values, preset
tree SHA-256, exact old values, semantic types, and numeric bounds before it
copies anything. It repairs only the exact fused form
`Tint = r,g,b,a[DepthOfField]`; near matches fail closed. Generated trees are
then re-audited for malformed or non-finite values, invalid numeric tokens,
record identity drift, unsupported overlay keys, and pairing drift. Source
roots are re-hashed after compilation and are never modified.

For every changed `OVERLAYPARAM`, the compiler also resolves the source
section's existing `Category`, `Name`, and `Operation` fields into an exact
target filename, category, key, and operation type. Missing, duplicate,
malformed, or unsupported bindings abort publication. These verified binding
strings are written to `provenance.csv`; each artistic rationale is explicitly
classified as `INTENDED_OUTCOME` and is not treated as proof of shader-runtime
semantics.

When the two external legacy roots are configured, the real-corpus integration
test emits ignored build artifacts under
`out/build/vs2026-x64/artifacts/task-04/<configuration>/first-five-bundles/`:

- five complete paired profile directories;
- `bundle-index.csv` with hashes, byte sizes, repair/change counts, and debt;
- `provenance.csv` with every guarded transform and repair;
- `report.txt` with deterministic aggregate and per-profile results.

The tracked manifest intentionally preserves suspicious duplicate export names
as debt instead of conflating them with duplicate record identities. The five
current bundles carry 65 such filenames (13 each); the complete 37-profile
legacy corpus retains the previously audited total of 481.

## Five-Profile Weather Themes

`elder_weather_theme_compiler` matures the complete weather set for the same
five paired bundles. It first reproduces the guarded first-pass bundle and then
transforms every selected weather record as one transactional publication. The
tracked [theme registry](config/five-profile-weather-themes.csv) separates
profile intent from six weather-family targets and four time-of-day targets.
The project-owned world-weather layer owns physical scene color; the overlay
remains the photographic response layer.

The emitted profile and weather content is self-contained. The current adapter
preserves the recovered KreatE directory shape only for one-time offline
migration and evidence. The validated result is a seed corpus for Elder's own
typed native profile format; it is not a runtime compatibility promise. KreatE,
Extender, and Silent Horizons are not runtime requirements and none of their
shader payloads are shipped here. The finished Elder distribution's only true
external runtime requirements are ENBSeries and Address Library.

The pass covers sky upper/lower, horizon and far fog, sunlight, ambient and
directional ambient, cloud LOD, and all 29 authored cloud layers. It validates
every cloud component with the authored alpha contribution (412,380 checks in
the current five-profile corpus), preserves alpha tokens, and does not alter
effect lighting, water multipliers, volumetrics, precipitation, or ImageSpace
references. Publication fails on missing fields, changed source trees,
non-finite or out-of-range values, temporal inversion, fog/horizon divergence,
lost cloud/sky separation, unreadable nights, clipped snow, protected-field
drift, a profile's cross-layer tint budget, a mismatched expected count, or any
unlisted bundle/file outside the exact first-pass payload contract. Every
successful package carries `input-tree-manifest.csv`, a deterministic manifest
of every snapshotted input file, byte count, and SHA-256.

The tracked [shader semantic registry](config/shader-semantic-registry.csv) is
a clean-room manifest. It contains only project semantic IDs, opaque evidence
IDs, artifact and span fingerprints, span lengths, flank-context fingerprints,
paraphrased meaning, and the exact profiles that require each typed binding.
Each tuple is checked independently in every listed profile; bindings from one
overlay cannot satisfy another. Raw source paths, symbols, and source spans live
only in an ignored protected sidecar outside this repository. Structural
registry validation is a non-publishing dry run and never creates a compile
capability. Weather publication requires the protected evidence pass, which
re-hashes the protected artifacts and re-checks every exact span and its
context before minting the opaque capability. The unresolved
Vignette intensity binding remains explicit uncertainty, so the compiler does
not guess or emit a mutation for it. External evidence is read-only, is not
shipped, and is neither a runtime nor ordinary-build dependency.

Weather publication uses an exclusive destination lock and unique owned stage,
backup, snapshot, and scratch trees. The source is copied into an owned snapshot,
the snapshot hash is checked against the initial source hash, and all validation
and transformation reads only that snapshot. The original source and snapshot
must match during snapshot creation, and the immutable snapshot is re-hashed
before publication. Existing output is replaceable only when it
carries the exact versioned Elder ownership marker. Canonical, final-path,
case-insensitive, file-identity, ancestor/descendant, and reparse-point checks
reject aliases before staging. A failed swap rolls the owned backup back into
place. Backup-cleanup failure is also rolled back before failure is reported;
if rollback is impossible after a committed swap, the transaction reports the
commit explicitly. Cleanup verifies the original marker and never recreates or
"repairs" ownership evidence. All `--expect-*` gates run before the final swap,
so a mismatch leaves an absent or pre-existing destination byte-identical.

Enable the full read-only integration by supplying the recovered shader source
root and its separately protected evidence sidecar in addition to the two
legacy roots:

```powershell
cmake --preset vs2026-x64 `
  -DELDER_LEGACY_OVERLAY_ROOT="<absolute overlay directory>" `
  -DELDER_LEGACY_PRESET_ROOT="<absolute KreatE preset directory>" `
  -DELDER_SH2_SOURCE_ROOT="<absolute protected shader source directory>" `
  -DELDER_SH2_EVIDENCE_SIDECAR="<absolute protected evidence sidecar>"
cmake --build --preset vs2026-release
ctest --preset vs2026-release -R elder_five_profile_weather_theme_integration `
  --output-on-failure --no-tests=error
```

Generated bundles and their index, per-record provenance, and validation report
are written only under
`out/build/.../artifacts/task-05/<configuration>/weather-theme-bundles/`.

## License Status

No license has been selected. See [LICENSE](LICENSE) for the explicit placeholder notice.
