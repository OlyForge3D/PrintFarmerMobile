# Decision: Persist NFC Tag Association via API After Write

**Date:** 2025-07
**Author:** Ripley
**Status:** Implemented (d903173)

## Context

When a user wrote an NFC tag for a spool, the NFC icon appeared immediately but disappeared on pull-to-refresh. The `hasNfcTag` flag was only updated in the local in-memory `spools` array — no API call was made to persist it.

## Decision

After a successful physical NFC tag write, call `spoolService.updateSpool(id:, SpoolmanSpoolRequest(hasNfcTag: true))` to persist the flag to the backend before updating local state.

## Changes

- Added `hasNfcTag: Bool?` field to `SpoolmanSpoolRequest` (was missing from the request model despite existing on the response DTO)
- Added `updateSpool` API call in `SpoolInventoryViewModel.writeNFCTag(for:)` between the physical write and local state update

## Pattern

**Any client-side state change that should survive a data refresh must be persisted to the backend.** Local state updates (like `markSpoolNFCWritten`) are optimistic UI — they make the change feel instant — but must always be backed by an API call.
