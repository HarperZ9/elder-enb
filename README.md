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

## License Status

No license has been selected. See [LICENSE](LICENSE) for the explicit placeholder notice.
