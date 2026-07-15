# Legacy KreatE Binding Compiler Design

## Boundary

The recovered project is evidence, not source material for the clean repository. Overlay metadata parsing enters `[OVERLAYINFO]`, captures only `UIName`, `UIGroups`, and `UIOrdering`, and stops at the next section. `PresetInfo.ini` parsing accepts only its five observed identity metadata keys. SHA-256 sees all bytes as an opaque stream but never interprets, stores, or emits operation records.

## Product Authority

The committed CSV is the sole runtime disposition authority. It contains one `BINDING` row per canonical identity, one `RETIRED` row per divergent duplicate, and one `ALIAS` row per reviewed mismatch. Selected and retired overlay filenames and hashes, preset directory names and metadata hashes, and aliases are explicit. Timestamps are absent from the schema and all runtime APIs.

## Compiler Transaction

Compilation validates catalog structure before scanning. It then builds isolated overlay and preset inventories, resolves names through a one-to-one alias map, verifies every selected/retired/preset hash, and calculates leftovers. Any diagnostic suppresses the binding manifest. A successful result contains 37 sorted bindings and exact counts; a helper turns a binding plus operations into the existing transactional `ProfilePackage` IDs.

## Failure Model

Stable diagnostic codes distinguish invalid catalog rows, duplicate records, ambiguous aliases, unknown identities, missing selected/retired/preset entries, changed hashes, unaccounted and unbound overlays, divergent undisposed duplicates, orphan presets, and invalid metadata. The CLI exits nonzero on any compiler or expectation diagnostic and always writes a deterministic report when the requested output boundary is safe.

## Testing

Generated synthetic fixtures exercise success and every failure class without relying on recovered bodies. A separate CTest invokes the CLI against only the two authorized roots and writes artifacts under the ignored build tree. Repeated CLI runs are compared byte-for-byte.
