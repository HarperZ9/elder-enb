# Transactional Elder Profiles Design

## Problem

Overlay and preset selection must be one transaction. A caller must never receive success when only one half of a profile was accepted or when a malformed operation list partially changed live values.

## Design

The engine has four observable state elements: immutable baseline values, current values, optional active identity, and generation. `Apply` first validates every package field and operation. If validation succeeds, it evaluates operations in order against a private baseline copy. Only a complete, finite staged result is committed; values, the full active package, and generation change together.

The public report always carries an outcome, generation before/after, and at least one stable diagnostic. Rejections may carry multiple diagnostics in deterministic order. Exact package re-selection is an explicit `ALREADY_ACTIVE` no-op with no generation change. A changed package always restages from baseline, preventing additive or multiplicative accumulation.

`RemoveActive` stages the baseline and commits it with a single generation increment. With no active profile, it returns `NO_ACTIVE_PROFILE` and leaves state unchanged.

## Boundaries

This slice has no persistence, parsing, filesystem access, threading contract, or third-party dependency. Package construction and baseline ownership remain caller responsibilities.

## Testing

A small real assertion harness exercises commit behavior, immutable-baseline staging, exact re-selection, same-identity package replacement, every validation code, multi-error reporting, overflow rejection, atomic rollback, active identity, generation accounting, and both removal paths.
