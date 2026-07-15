# Spec: Transactional Elder Profile Vertical Slice

## Objective

Build the first dependency-free C++23 Elder profile engine so one package binds overlay identity, preset identity, and ordered operations, eliminating split configuration paths that could report success without applying a coherent profile.

## Requirements

- [x] A `ProfilePackage` owns a non-empty `overlay_id`, non-empty `preset_id`, and non-empty ordered operation list.
- [x] `Apply` validates the whole package before mutation and reports stable diagnostic codes.
- [x] Empty IDs, empty operations, unknown targets, duplicate targets, non-finite operands/results, and non-positive multiply operands are rejected.
- [x] Rejection preserves current values, active package identity, and generation.
- [x] Valid application stages from the immutable baseline, commits atomically, and increments generation exactly once.
- [x] Exact re-selection returns `ALREADY_ACTIVE` without mutation or a generation increment.
- [x] A changed package, including changed operations under the same IDs, stages from baseline and commits as a new generation.
- [x] `RemoveActive` restores baseline atomically and increments generation once.
- [x] Removing without an active package returns `NO_ACTIVE_PROFILE` without mutation.
- [x] The public API exposes values, active package identity, generation, and a structured report.
- [x] CMake uses C++23, Visual Studio 18 2026 x64, and the static MSVC runtime.

## Technical Approach

`TransactionalProfile` owns a const baseline map, a current-value map, an optional full active package, and a generation counter. Validation collects diagnostics without touching state. A valid package is evaluated into a local copy of the baseline; only a fully finite staged map is swapped into current state. Exact package equality is checked only after validation and produces the explicit, user-safe `ALREADY_ACTIVE` result.

Operations are `Set`, `Add`, and `Multiply`. Multiply operands must be finite and strictly positive. Diagnostics are returned in deterministic validation order: package fields first, then each operation in list order with target, duplicate, and numeric checks.

## Files to Modify

- `CMakeLists.txt` — library and test targets.
- `CMakePresets.json` — requested MSVC generator, architecture, runtime, build, and test presets.
- `include/elder/profiles/TransactionalProfile.hpp` — public value types and engine API.
- `src/profiles/TransactionalProfile.cpp` — validation, staging, commit, removal, and code rendering.
- `tests/TransactionalProfileTests.cpp` — dependency-free assertion harness and behavioral coverage.
- `docs/ARCHITECTURE.md` — minimal state-transition architecture note.
- `README.md`, `LICENSE`, `.gitignore`, `.gitattributes` — repository bootstrap and usage metadata.
- `.superpowers/sdd/task-01-report.md` — RED/GREEN and final verification evidence.

## Success Criteria

- [x] The behavioral test executable first fails for missing transactional behavior.
- [x] Configure and build succeed with the `Visual Studio 18 2026` generator.
- [x] `ctest --output-on-failure --no-tests=error` reports all tests passing.
- [x] No rejection changes any observable engine state.
- [x] All successful and no-op paths return explicit structured diagnostics.
- [x] One owned commit exists on `chore/bootstrap-elder` with the requested message and no remote or push.

## Blockers

None identified.

## Status: IMPLEMENTED

The dispatching task supplied the complete design and authorized implementation. The exact re-selection policy above is the deliberately selected simpler, user-safe behavior.

Implementation matched the approved approach without deviation. Final verification is recorded in `.superpowers/sdd/task-01-report.md`.
