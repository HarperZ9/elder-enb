# Spec: Legacy Overlay ↔ KreatE Binding Compiler

## Objective

Compile the recovered Elder overlay and KreatE preset metadata into a deterministic, product-owned binding catalog without importing legacy operation bodies or mutating the recovered project.

## Verified Source Baseline

- The authorized overlay root contains 55 files whose `[OVERLAYINFO]` `UIGroups` value is exactly `10 - KreatE Presets`.
- Those files expose 37 unique `UIName` identities and 18 additional divergent duplicates.
- The authorized KreatE root contains 37 immediate preset directories, each with `PresetInfo.ini`.
- Four reviewed aliases close every naming mismatch: `10.28.16 (SE)` → `10.28.16`, `11.11.11 (LE)` → `11.11.11`, `Jotunheimar` → `Jötunheimar`, and `Storm & Chaos` → `Storm and Chaos`.
- The selected overlay in each duplicate pair is the observed Feb-18 authored revision. Fixed reviewed exceptions are `034. STYLE - Elder Originals.ini` and `049. STYLE - Neutral.ini`. Runtime code never consults timestamps.

## Requirements

- [x] Use only the C++23 standard library.
- [x] Read legacy overlay metadata only from `[OVERLAYINFO]` keys `UIName`, `UIGroups`, and `UIOrdering`; stop metadata parsing when that section ends.
- [x] Read only the five identity metadata keys from each `PresetInfo.ini`: `Optional`, `ConfigVersion`, `PresetVersion`, `Author`, and `Description`.
- [x] Stream SHA-256 over source bytes without persisting or emitting operation bodies.
- [x] Commit one reviewed CSV with exactly 37 `BINDING`, 18 `RETIRED`, and 4 `ALIAS` rows, locking exact filenames/directories and lowercase SHA-256 values.
- [x] Fail closed on invalid/unknown/missing/duplicate/unaccounted catalog or source entries.
- [x] Fail closed on selected, retired, or preset metadata hash changes.
- [x] Fail closed on ambiguous aliases, divergent duplicates without disposition, orphan presets, and unbound overlays.
- [x] Emit deterministic manifest and report artifacts only to caller-selected paths outside tracked source.
- [x] Provide a CLI and public catalog/compiler API.
- [x] Bind a compiled identity to `ProfilePackage` with the exact selected overlay filename and preset directory as IDs.
- [x] Do not mutate either authorized legacy root.
- [x] Do not amend Task 01; create one new Task 02 commit and do not push.

## Technical Approach

`LegacyKreateBindings` separates four concerns: SHA-256 streaming, metadata-only scanning, reviewed CSV loading, and catalog compilation. The CSV is normalized with `BINDING`, `RETIRED`, and `ALIAS` records so every legacy file has one explicit disposition. Compilation first validates catalog structure, then inventories only the target overlay group and direct preset directories, validates all hashes and identities, detects leftovers, and produces sorted bindings only when diagnostics are empty.

The CLI accepts explicit input roots, catalog, manifest, and report paths plus expected-count/required-identity gates. It refuses output paths inside either input root. Manifest/report content contains filenames, IDs, hashes, counts, and stable diagnostic codes; it contains no operation records and no timestamps.

## Files to Modify

- `CMakeLists.txt` — binding library sources, unit test, CLI, and read-only integration CTest.
- `include/elder/bindings/LegacyKreateBindings.hpp` — catalog/compiler types and public API.
- `src/bindings/LegacyKreateBindings.cpp` — SHA-256, CSV, scanners, compiler, deterministic writers, and package adapter.
- `src/tools/LegacyKreateCompilerMain.cpp` — command-line validation and execution.
- `tests/LegacyKreateBindingsTests.cpp` — generated synthetic fixtures and fail-closed coverage.
- `config/legacy-kreate-bindings.csv` — reviewed, hash-locked product disposition.
- `README.md` and `docs/ARCHITECTURE.md` — usage and boundary documentation.
- `.superpowers/sdd/task-02-report.md` — RED/GREEN, integration, boundary, and commit evidence.

## Success Criteria

- [x] Synthetic tests are observed failing before production behavior is implemented.
- [x] Unit tests cover the known SHA-256 vector, metadata boundaries, success, every required fail-closed class, deterministic output, and `ProfilePackage` binding.
- [x] The real read-only integration reports exactly 55 overlays, 37 bindings, 18 retirements, 4 aliases, and zero unresolved, ambiguous, orphan, or unbound entries.
- [x] The real manifest contains `Arrival of Autumn`.
- [x] Two consecutive real compilations emit byte-identical manifest and report files.
- [x] Task 01 tests remain green.
- [x] Git shows one new commit named `feat: compile legacy KreatE bindings`, with no push.

## Blockers

None identified.

## Status: IMPLEMENTED

The dispatch supplied the full behavior, source boundary, reviewed selection rules, counts, and completion contract. Implementation matched that approach; the output-path guard was strengthened during GREEN so unsafe destinations are rejected before any write.
