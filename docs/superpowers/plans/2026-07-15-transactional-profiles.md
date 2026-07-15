# Transactional Elder Profiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and verify a dependency-free C++23 transactional profile engine that cannot partially or silently apply an Elder overlay/preset package.

**Architecture:** `TransactionalProfile` owns immutable baseline state and commits only from a fully validated staged copy. Reports make apply, rejection, re-selection, removal, and no-active outcomes explicit with stable diagnostic codes.

**Tech Stack:** C++23 standard library, CMake 4.2, Visual Studio 18 2026 x64/MSVC static runtime, CTest.

## Global Constraints

- Work only in `C:\dev\elder-enb`; do not inspect or alter the evidence directory.
- Use exactly one independent repository on `chore/bootstrap-elder`; do not create a worktree or remote.
- Use `apply_patch` for every owned file creation or edit.
- Keep the engine dependency-free beyond the C++23 standard library.
- Record observed RED and GREEN commands and results in `.superpowers/sdd/task-01-report.md`.
- Commit only after fresh verification, using `feat: bootstrap transactional Elder profiles`.

---

### Task 1: Behavioral Contract and RED Evidence

**Files:**
- Create: `CMakeLists.txt`
- Create: `CMakePresets.json`
- Create: `tests/TransactionalProfileTests.cpp`
- Create: `.superpowers/sdd/task-01-report.md`

**Interfaces:**
- Consumes: the approved package, operation, report, and engine contract from `project-docs/specs/SPEC-task-01.md`.
- Produces: executable behavioral expectations for `TransactionalProfile::Apply`, `TransactionalProfile::RemoveActive`, and state accessors.

- [ ] **Step 1: Write the assertion harness and behavioral tests against the wished-for API.**
- [ ] **Step 2: Configure and build with `cmake --preset vs2026-x64` and `cmake --build --preset vs2026-debug`; expect failure because the public engine header is absent.**
- [ ] **Step 3: Add only the declarations and inert implementation needed to compile, then run `ctest --preset vs2026-debug --output-on-failure --no-tests=error`; expect behavioral assertions to fail.**
- [ ] **Step 4: Record both observed RED stages verbatim enough to reproduce them.**

### Task 2: Minimal Transactional Implementation

**Files:**
- Create: `include/elder/profiles/TransactionalProfile.hpp`
- Create: `src/profiles/TransactionalProfile.cpp`

**Interfaces:**
- Consumes: `ProfilePackage`, ordered `ProfileOperation` values, and a baseline `ValueMap`.
- Produces: `TransactionalProfile(ValueMap)`, `Apply(const ProfilePackage&)`, `RemoveActive()`, `values()`, `active_identity()`, `generation()`, `ToString(DiagnosticCode)`, and `ToString(ProfileResult)`.

- [ ] **Step 1: Implement package-wide validation that only reads engine state.**
- [ ] **Step 2: Implement ordered staging from a baseline copy and reject non-finite staged results.**
- [ ] **Step 3: Implement atomic commit, exact-package no-op, and atomic removal.**
- [ ] **Step 4: Run the full preset build and CTest command; expect every case to pass.**
- [ ] **Step 5: Record the observed GREEN counts and output.**

### Task 3: Bootstrap Documentation and Release Gate

**Files:**
- Create: `README.md`
- Create: `docs/ARCHITECTURE.md`
- Create: `LICENSE`
- Create: `.gitignore`
- Create: `.gitattributes`
- Modify: `.superpowers/sdd/task-01-report.md`
- Modify: `project-docs/specs/SPEC-task-01.md`

**Interfaces:**
- Consumes: verified commands and implemented behavior.
- Produces: reproducible build instructions, explicit license status, architecture rationale, and final evidence.

- [ ] **Step 1: Document the public contract, diagnostics, and requested presets.**
- [ ] **Step 2: Mark the spec requirements implemented only after fresh verification.**
- [ ] **Step 3: Review all owned changes for scope, secrets, and generated artifacts.**
- [ ] **Step 4: Run fresh configure, build, and CTest commands and capture exact results.**
- [ ] **Step 5: Commit the complete vertical slice with the requested message.**

## Plan Self-Review

- Spec coverage: every requested behavior and repository artifact maps to a task.
- Placeholder scan: no implementation placeholders or deferred behaviors are present.
- Type consistency: the same engine, package, operation, report, result, and diagnostic names are used throughout.
