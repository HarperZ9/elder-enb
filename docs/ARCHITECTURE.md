# Transactional Profile Architecture

## State

`TransactionalProfile` owns four pieces of state:

1. A const baseline map supplied at construction.
2. The currently observable value map.
3. An optional full active package; the public accessor projects only overlay and preset identity.
4. A generation counter that advances once per committed apply or removal.

## Apply Transition

```text
ProfilePackage
    -> validate every field and operation
       -> diagnostics present: REJECTED, state unchanged
       -> exact active package: ALREADY_ACTIVE, state unchanged
       -> copy immutable baseline
          -> evaluate ordered operations
             -> non-finite result: REJECTED, state unchanged
             -> prepare package/report
                -> no-throw swaps + one generation increment: APPLIED
```

Validation gathers deterministic diagnostics in this order: package-level fields, then each operation in list order with unknown-target, duplicate-target, and numeric checks. Numeric staging is private. A valid operation earlier in a package cannot leak into current values if a later operation fails.

All potentially allocating copies and the success report are prepared before commit. The commit itself uses no-throw swaps, then increments generation once. A changed package always starts from `baseline_`, including when it reuses the same overlay and preset IDs.

## Removal Transition

When active, `RemoveActive` copies the baseline before mutation, swaps it into current values, clears active package state, increments generation once, and returns `REMOVED`. When inactive, it returns `NO_ACTIVE_PROFILE` with identical before/after generations and no state change.

## Scope

This vertical slice intentionally excludes persistence, file parsing, synchronization, rendering integration, and third-party dependencies. It is the in-memory transaction boundary those later adapters can call.

## Legacy Binding Compilation

The binding compiler is a read-only adapter in front of the transaction boundary:

```text
reviewed CSV + authorized overlay/preset roots
    -> validate catalog structure
    -> parse whitelisted identity metadata + stream SHA-256
    -> account for every selected, retired, and preset entry
       -> any diagnostic: no bindings, deterministic failure report
       -> no diagnostics: sorted binding manifest
          -> exact overlay filename + preset directory -> ProfilePackage IDs
```

The reviewed CSV—not file order, numeric prefixes, or timestamps—is the disposition authority. `BINDING`, `RETIRED`, and `ALIAS` rows make every one of the 55 target overlays explicit. Outputs must be distinct and outside both input roots; the CLI rejects unsafe paths before attempting any write.

The compiler does not load runtime operations. Overlay parsing stops when `[OVERLAYINFO]` ends, `PresetInfo.ini` retains only five identity fields, and manifest/report surfaces expose only identities, filenames, hashes, counts, and stable diagnostic codes.
