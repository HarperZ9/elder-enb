# Legacy KreatE Bindings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a dependency-free compiler that turns reviewed legacy overlay/preset metadata into exact, hash-locked transactional profile bindings.

**Architecture:** A metadata-only scanner and opaque SHA-256 stream feed a normalized reviewed catalog compiler. Compilation fails closed before emitting sorted bindings; the CLI writes deterministic artifacts outside tracked source and the adapter produces exact `ProfilePackage` IDs.

**Tech Stack:** C++23 standard library, CMake 4.2, Visual Studio 18 2026 x64/MSVC static runtime, CTest.

## Global Constraints

- Read only the explicitly configured external overlay and KreatE preset roots from the recovered project; never track their workstation-specific locations.
- Never edit those roots and never copy legacy operation/record bodies into tracked source or generated reports.
- Use `apply_patch` for every source, test, catalog, and documentation edit.
- Runtime selection uses committed exact names and SHA-256 only; timestamps are forbidden inputs.
- Make one new commit after Task 01, do not amend, and do not push.

---

### Task 1: Synthetic Contract and RED

**Files:**
- Modify: `CMakeLists.txt`
- Create: `tests/LegacyKreateBindingsTests.cpp`
- Create: `.superpowers/sdd/task-02-report.md`

**Interfaces:**
- Consumes: the approved types named in `SPEC-task-02.md`.
- Produces: tests for `Sha256`, `ReadOverlayMetadata`, `ReadPresetMetadata`, `LoadDispositionCatalog`, `CompileBindings`, `WriteManifest`, `WriteReport`, and `MakeProfilePackage`.

- [ ] Write a small assertion harness whose synthetic fixture writes only invented metadata and sentinel body text under a temporary directory.
- [ ] Add tests for the SHA-256 `abc` vector, metadata stop boundary, successful accounted compilation, exact ID package binding, deterministic writers, and every stable failure class.
- [ ] Configure/build before creating the production header; record the expected missing-API RED.
- [ ] Add declarations and inert behavior only, rebuild, run CTest, and record the expected behavioral RED count.

### Task 2: Minimal Compiler Implementation

**Files:**
- Create: `include/elder/bindings/LegacyKreateBindings.hpp`
- Create: `src/bindings/LegacyKreateBindings.cpp`
- Create: `src/tools/LegacyKreateCompilerMain.cpp`

**Interfaces:**
- Consumes: explicit filesystem roots, normalized disposition records, and caller-owned operations.
- Produces: `CompileResult` with sorted `CompiledBinding` values and `CompileCounts`; deterministic CSV/text artifacts; CLI exit status; exact `ProfilePackage` IDs.

- [ ] Implement standard-library SHA-256 and verify the known vector before using it for catalog comparisons.
- [ ] Implement overlay parsing that breaks at the first post-`OVERLAYINFO` section and preset parsing that accepts only the five whitelisted keys.
- [ ] Implement RFC-4180-compatible single-record CSV parsing and catalog structural diagnostics.
- [ ] Implement complete inventory validation, hash checks, alias resolution, divergence detection, leftovers, and manifest suppression on any diagnostic.
- [ ] Implement deterministic writers and safe output-boundary checks.
- [ ] Build and run the synthetic test executable until all cases are GREEN.

### Task 3: Reviewed Real Catalog and Integration

**Files:**
- Create: `config/legacy-kreate-bindings.csv`
- Modify: `CMakeLists.txt`
- Modify: `README.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `.superpowers/sdd/task-02-report.md`

**Interfaces:**
- Consumes: 37 reviewed selected filenames/preset directories, 18 reviewed retired filenames, four aliases, and current SHA-256 values from the authorized roots.
- Produces: a CTest CLI command that gates exact counts and requires `Arrival of Autumn`.

- [ ] Encode all 59 reviewed records and verify row/type/filename uniqueness independently of the compiler.
- [ ] Add the CLI CTest with exact roots, catalog, build-tree artifact paths, counts `55/37/18/4`, and required identity `Arrival of Autumn`.
- [ ] Run the CLI twice to distinct build-tree outputs and compare manifest/report bytes.
- [ ] Confirm zero unresolved, ambiguous, orphan, and unbound diagnostics.
- [ ] Document the input/output/exposure/failure boundary without copying recovered body content.

### Task 4: Final Gate and Single Commit

**Files:**
- Modify: `project-docs/specs/SPEC-task-02.md`
- Modify: `.superpowers/sdd/task-02-report.md`

**Interfaces:**
- Consumes: fresh build, unit, integration, deterministic comparison, Git, and boundary-scan evidence.
- Produces: one clean local commit after Task 01.

- [ ] Run clean configure, build, and `ctest --output-on-failure --no-tests=error`.
- [ ] Scan tracked content and generated artifacts for authorized-root paths where expected, forbidden body sentinels, secrets, timestamps in runtime schema/code, and generated files staged by mistake.
- [ ] Inspect the complete staged diff and verify Task 01 remains the parent commit.
- [ ] Commit exactly `feat: compile legacy KreatE bindings`, leave the branch clean, and do not push.

## Plan Self-Review

- Coverage: each source boundary, failure class, count gate, deterministic artifact, package adapter, and Git constraint maps to a task.
- Placeholder scan: the plan contains no deferred behavior or unspecified interfaces.
- Type consistency: the same catalog, compile result, counts, diagnostics, writers, CLI, and package adapter names are used throughout.
