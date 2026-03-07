# Camera Snapshot Display Strategy

**Date:** 2025-07-18
**Author:** Ripley
**Status:** Implemented

## Decision
Camera snapshot in PrinterDetailView uses a two-tier loading strategy:
1. **Primary:** Load snapshot as `Data` via `PrinterServiceProtocol.getSnapshot(id:)` (authenticated, reliable)
2. **Fallback:** Display via `AsyncImage` from `Printer.cameraSnapshotUrl` (direct URL, no auth needed)
3. **Empty state:** "No camera available" placeholder when neither source exists

## Rationale
The service-based snapshot fetch handles auth tokens automatically, but if it fails (e.g., service not configured yet), the direct URL from the Printer model provides a seamless fallback since backend serves it as a public URL.

## Impact
- Lambert: No changes needed — existing `getSnapshot(id:)` contract unchanged
- Ash: `PrinterDetailViewModel` gains `isLoadingSnapshot: Bool` and `refreshSnapshot() async` — tests may need updating
