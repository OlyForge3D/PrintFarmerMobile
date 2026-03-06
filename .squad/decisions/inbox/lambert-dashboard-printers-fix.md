# Decision: Resilient Codable Decoders for All Backend DTOs

**Author:** Lambert (Networking/API Dev)
**Date:** 2026-07-16
**Status:** Implemented

## Context

Dashboard and Printers tabs were broken after login. The Swift `Printer` model used auto-synthesized `Codable` which requires ALL non-optional fields to be present in JSON. The backend has TWO different printer DTOs:

- `CompletePrinterDto` (list endpoint) — has `inMaintenance`, `isEnabled`, `manufacturerId`, etc.
- `PrinterDto` (detail endpoint) — missing those fields, but has `cameraSnapshotUrl`, `username`, `password`

The Swift `Printer` struct must decode both shapes without crashing.

## Decision

All models that decode backend JSON now use custom `init(from decoder: Decoder)` with `decodeIfPresent` + sensible defaults for fields that might be absent. This includes: `Printer`, `PrinterSpoolInfo`, `StatisticsSummary`, `MmuStatus`, `MmuGate`.

## Impact

- **Ripley/Ash:** `Printer` now has `cameraSnapshotUrl: String?` field available for UI use.
- **Ripley:** `PrinterListView` now shows error messages with retry — previously silently showed "No Printers" on decode failure.
- **All:** Test fixtures updated to use string enum values (matching backend's `JsonStringEnumConverter`). Old integer-based fixtures were stale.
- **All:** `#if DEBUG` logging in `APIClient.execute()` prints raw response body on decode failure.

## Rationale

Defensive decoding prevents silent failures when the backend evolves. The backend uses `WhenWritingNull` which omits null fields entirely — combined with different DTO shapes per endpoint, strict auto-synthesized Codable is too fragile.
