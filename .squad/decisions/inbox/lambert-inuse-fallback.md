# Decision: Remove `!archived` fallback for `inUse` in SpoolmanJsonParser

**Author:** Lambert (Networking)
**Date:** 2026-07-18
**Status:** Proposed (pending Jeff's review of backend change)
**Issue:** #1

## Context
The backend's `SpoolmanJsonParser.cs` had fallback logic: when the Spoolman API's JSON didn't include an `in_use` field, it inferred `inUse = !archived`. Since most spools are not archived (`archived: false`), this made `inUse = true` for virtually every spool. The iOS "Available" filter (`!spool.inUse && !archived`) then correctly returned zero results — there were no spools marked as available.

## Decision
Remove the `!archived` → `inUse` fallback. When `in_use` is absent from the JSON, default to `false` (not in use). The concepts are independent:
- **Archived** = spool is retired/hidden from active lists
- **In use** = spool is currently loaded in a printer

## Consequences
- The "Available" spool filter in the iOS app will now work correctly without any iOS code changes.
- Spools that are genuinely in use must have `in_use: true` set explicitly by Spoolman or by Printfarmer when assigning a spool to a printer.
- No risk to archived spool handling — the `Archived` field is parsed independently (line 125) and passed through separately.
