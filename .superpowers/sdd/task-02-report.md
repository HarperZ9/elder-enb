# Task 02 — Legacy Overlay ↔ KreatE Binding Compiler TDD Report

Date: 2026-07-15

Repository: Elder ENB clean implementation repository

Branch: `chore/bootstrap-elder`

Task 01 parent: `f9fe6f41f778a0021439bce0848b1a47db5e7c76`

## Read-Only Source Inventory

Only the two explicitly configured external, read-only recovery roots were
read: the legacy ENB preset-overlay directory and the legacy KreatE preset
directory. Their workstation-specific locations are intentionally not tracked.

Observed metadata-only baseline:

- 55 overlay files matched `UIGroups = 10 - KreatE Presets`.
- 37 unique `UIName` identities were observed.
- 18 duplicate files had SHA-256 values different from their selected counterpart.
- 37 immediate preset directories each contained `PresetInfo.ini`.
- Four reviewed aliases account for the four name differences.

Overlay reads captured only the three `[OVERLAYINFO]` keys and stopped at the next section. `PresetInfo.ini` reads enumerated only the five identity metadata keys. Full-file access was limited to opaque SHA-256 streaming. No operation or record body was copied into the clean repository.

## Reviewed Disposition Rule

The selected member of each duplicate pair is the observed Feb-18 authored revision, with the explicit fixed selections `034. STYLE - Elder Originals.ini` and `049. STYLE - Neutral.ini`. This observation is used only to author the reviewed CSV. Runtime code and catalog schema contain no timestamp heuristic.

## RED Evidence

### RED 1 — Tests and targets precede production files

Command:

```powershell
cmake --preset vs2026-x64
```

Observed result: exit code `1`. CMake found the Task 02 test/target wiring and failed because production files did not exist:

```text
Cannot find source file: src/bindings/LegacyKreateBindings.cpp
Cannot find source file: src/tools/LegacyKreateCompilerMain.cpp
No SOURCES given to target: elder_profiles
No SOURCES given to target: elder_binding_compiler
CMake Generate step failed.
```

This is the expected first RED: the synthetic behavioral contract was written before production implementation.

### RED 2 — Compile-enabling scaffold has no compiler behavior

Commands:

```powershell
cmake --preset vs2026-x64
cmake --build --preset vs2026-debug
ctest --preset vs2026-debug --output-on-failure --no-tests=error
```

Observed configure/build result: exit code `0`; the inert library, CLI, Task 01 tests, and Task 02 tests compiled with MSVC `/W4 /WX /permissive- /utf-8`.

Observed CTest result: exit code `1`:

```text
transactional_profile_tests: Passed
legacy_kreate_binding_tests: Failed
0/13 binding tests passed
50% tests passed, 1 tests failed out of 2
```

All 13 new behavioral cases failed for the intended missing behavior: no SHA-256, no metadata parse, no successful binding, no deterministic writers, no required fail-closed diagnostics, and no stable code strings. Task 01 remained green throughout RED.

### RED 3 — Real integration precedes CLI behavior

After committing the reviewed 59-row table and the exact-count CTest command, the inert CLI was run:

```powershell
ctest --test-dir out/build/vs2026-x64 -C Debug -R legacy_kreate_readonly_integration --output-on-failure --no-tests=error
```

Observed result: exit code `1`; `0% tests passed, 1 tests failed out of 1`. The CLI still returned its inert status and produced no success manifest.

### RED 4 — Unsafe-output regression

A review found that the initial CLI detected an output inside an input root but could still attempt to write its failure report. A regression test was added before the fix.

```text
error C2039: 'OutputPathsAreSafe': is not a member of 'elder::bindings'
```

The subsequent implementation moved the boundary predicate into the tested library API and made the CLI exit before loading inputs or writing any artifact.

## GREEN Evidence

### Synthetic compiler suite

The final harness contains 14 invented-fixture cases. It covers the SHA-256 `abc` vector, overlay section stop boundary, five-key preset metadata whitelist, successful compilation, exact `ProfilePackage` IDs, deterministic/body-free outputs, unsafe output paths, selected/retired/preset hash drift, missing entries, duplicate records, ambiguous aliases, unknown/unaccounted/unbound overlays, divergent undisposed duplicates, orphan presets, invalid metadata, and stable diagnostic codes.

Observed result:

```text
14/14 binding tests passed
```

### Reviewed catalog and real read-only integration

Independent CSV checks:

```text
ROWS=59
BINDINGS=37 UNIQUE_IDENTITIES=37 UNIQUE_SELECTED=37 UNIQUE_PRESETS=37
RETIRED=18 UNIQUE_RETIRED=18
ALIASES=4 UNIQUE_ALIASES=4
INVALID_HASH_ROWS=0
```

Compiler report:

```text
status=OK
discovered_overlays=55
compiled_bindings=37
retired_overlays=18
aliases=4
unresolved_entries=0
ambiguous_aliases=0
orphan_presets=0
unbound_overlays=0
diagnostics=0
```

`Arrival of Autumn` is present in the manifest.

### Determinism

Two separate real CLI runs produced byte-identical outputs:

```text
MANIFEST_IDENTICAL=True SHA256=f365eb0c0de3ac51bb7cf1378bc66a37efda1b78b077f25e5e7d9b6ba63f46bf
REPORT_IDENTICAL=True SHA256=7761ef45a23c6a56b23271c842430b10f3c19eac1966d6630278cf8b9ff8a87f
```

Primary generated evidence paths (ignored by Git):

- `C:\dev\elder-enb\out\build\vs2026-x64\artifacts\task-02\legacy-kreate-manifest.csv`
- `C:\dev\elder-enb\out\build\vs2026-x64\artifacts\task-02\legacy-kreate-report.txt`

## Source-Boundary Gate

Direct scans before the final test run reported:

```text
RUNTIME_TIMESTAMP_HEURISTIC_HITS=0
DIVERGENT_RETIRED=18/18
ELDER_SELECTED=034. STYLE - Elder Originals.ini
NEUTRAL_SELECTED=049. STYLE - Neutral.ini
GENERATED_SYNTHETIC_BODY_HITS[manifest]=0
GENERATED_SYNTHETIC_BODY_HITS[report]=0
```

Build outputs remain ignored under `out/`; only product source, metadata dispositions, tests, and documentation are commit candidates.

## Final Clean Verification

A fresh configure and build from an absent `out/` directory completed with exit code `0` under Visual Studio 18 2026 / MSVC 19.50.35721.0. The final clean verification produced:

```text
CTest: 3/3 passed
Task 01 transactional profile harness: 16/16 passed
Task 02 legacy binding harness: 14/14 passed
Real integration: overlays=55 bindings=37 retired=18 aliases=4
Real integration failures: unresolved=0 ambiguous=0 orphans=0 unbound=0 diagnostics=0
```

Two independent final compiler runs remained byte-identical:

```text
manifest SHA256=f365eb0c0de3ac51bb7cf1378bc66a37efda1b78b077f25e5e7d9b6ba63f46bf
report SHA256=7761ef45a23c6a56b23271c842430b10f3c19eac1966d6630278cf8b9ff8a87f
```
