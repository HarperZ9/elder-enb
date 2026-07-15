# Elder native color ABI

This directory is the release-candidate foundation for Elder's native typed
profile and color pipeline. It is intentionally independent of KreatE, preset
overlays, Silent Horizons, and third-party shader code.

## ABI V1 boundary

`schema/elder-native-parameters.csv` is the canonical public parameter ABI.
The compiler emits one matching HLSL UI contract, C++ defaults header, JSON
manifest, and complete default profile. Their canonical SHA-256 fingerprint is
embedded in every artifact. Runtime binding rejects a profile/schema pair when
that fingerprint differs from the fingerprint compiled into the binary.

ABI V1 exposes only controls that the current color pipeline evaluates. Night
bias, interior bias, and dark/bright adaptation are deliberately deferred until
the runtime owns a tested persistent exposure-state contract. They must not be
reintroduced as UI-only controls.

## Failure behavior

- Profiles reaching the runtime binding must be complete and have opacity 1.
  Partial-opacity layers are resolved before binding.
- Non-finite scene input fails to black even when the master effect is disabled.
- Non-finite UI float/color values fall back to generated defaults using
  exponent-bit finite checks that survive optimized legacy FXC builds.
- Shader validation uses strict syntax, warnings-as-errors, IEEE strictness,
  and optimized `ps_5_0` output.
- The four generated ABI files publish as one owned transaction. The compiled
  shader and assembly listing publish as a second two-file transaction. A failed
  replacement restores the prior set and removes only paths owned by that
  transaction.
- Every publication path is canonicalized to the Windows extended-length form.
  Per-destination owned locks prevent concurrent publishers from interleaving;
  staging, replacement, rollback, and cleanup remain valid beyond `MAX_PATH`.
- Both native command-line tools receive Windows arguments through wide entry
  points and use the same native-path layer for source reads and destination
  publication. Long and Unicode source/destination paths therefore retain their
  exact names instead of depending on the active ANSI code page.
- A failed early staging cleanup returns `stage_cleanup_incomplete`; a failed
  post-commit backup cleanup returns `backup_cleanup_incomplete` and explicitly
  reports that the outputs were committed. Neither condition can be mistaken
  for an ordinary publication success.

## Native release package

When strict FXC validation is available, the normal build produces the
production `.cso` and its release-audit `.asm`. CMake also exposes the
`elder_native_release_package` target, which fixes the archive epoch and creates
`Elder-ENB-Native-RC-win64.zip` plus its SHA-256 sidecar. The ZIP has one
deterministic root and contains exactly these release classes:

- `Elder ENB/Native/Shaders`: generated HLSL ABI, compiled production shader,
  and assembly audit output;
- `Elder ENB/Native/Include`, `Manifest`, and `Profiles`: the other three
  generated ABI/profile artifacts;
- `Elder ENB/Native/Documentation`: this README and the native notice.

No compiler, executable, test binary, library, source tree, ENBSeries binary,
or third-party shader is installed. The package test performs two independent
installs and two fixed-epoch ZIP builds, compares all eight content hashes,
checks the ZIP SHA-256 sidecar, extracts the archive, and rejects any file not
in the exact manifest.

## Release verification

Configure, build, and test both presets:

```powershell
cmake --preset vs18-x64-static
cmake --build --preset vs18-x64-static-debug
ctest --preset vs18-x64-static-debug --output-on-failure
cmake --build --preset vs18-x64-static-release
ctest --preset vs18-x64-static-release --output-on-failure
cmake --build --preset vs18-x64-static-release `
  --target elder_native_release_package
```

The release suite covers schema/profile strictness, SHA-256 known vectors,
transaction rollback, injected cleanup failures, long/Unicode CLI paths,
deterministic artifact bytes, CPU color behavior,
profile-to-core binding, strict FXC compilation, CPU/compute WARP parity, and
the exact production pixel entry point on D3D11 WARP. The production WARP cases
include min/default/max settings, a representative authored profile, master
passthrough, every generated sanitizer, and NaN/positive-infinity/negative-
infinity scene inputs.

The root project still has no selected public distribution license. Package
generation is therefore a release-candidate verification boundary, not
permission to publish; the project owner must choose the license first.
