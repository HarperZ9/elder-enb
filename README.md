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
`out/build/vs2026-x64/artifacts/task-04/first-five-bundles/`:

- five complete paired profile directories;
- `bundle-index.csv` with hashes, byte sizes, repair/change counts, and debt;
- `provenance.csv` with every guarded transform and repair;
- `report.txt` with deterministic aggregate and per-profile results.

The tracked manifest intentionally preserves suspicious duplicate export names
as debt instead of conflating them with duplicate record identities. The five
current bundles carry 65 such filenames (13 each); the complete 37-profile
legacy corpus retains the previously audited total of 481.

## License Status

No license has been selected. See [LICENSE](LICENSE) for the explicit placeholder notice.
