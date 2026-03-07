# Phase 2 Scanning UI Decisions (Ripley)
**Date:** 2025-07-19
**Status:** Implemented

## QR Scanner Architecture
- QRScannerView wraps VisionKit's `DataScannerViewController` via `UIViewControllerRepresentable`
- iOS-only (`#if os(iOS)`); SPM macOS builds skip it
- Single-scan mode: `recognizesMultipleItems: false`, stops after first barcode recognized
- Camera permission denial handled with alert + Settings link

## NFC Button Pattern
- `NFCScanButton` is a reusable component with `compact` variant for inline use
- Checks `NFCNDEFReaderSession.readingAvailable` to disable on unsupported devices
- Uses `.bordered` style uniformly (ternary ButtonStyle selection not supported by Swift type system)

## QR Text Parsing Strategy
- `SpoolPickerViewModel.parseSpoolId(from:)` supports 3 formats:
  1. Plain integer string
  2. URL with `/spool/{id}` or `/spools/{id}` path segment
  3. JSON with `id`, `spoolId`, or `spool_id` fields
- This is a UI-layer convenience parser; Lambert's `QRCodeParser` may provide more sophisticated parsing

## NFC Write Flow
- NFCWriteView presented as `.sheet(item:)` from SpoolInventoryView context menu
- Shows spool summary, status area (ready/writing/success/error), and action buttons
- `onWrite` closure returns `Bool` — will be wired to Lambert's `NFCService.writeTag()` when available

## Scan-to-Load in PrinterDetailView
- NFCScanButton added to filament section in both loaded and empty states
- On successful spool ID scan: calls `setActiveSpool` + `loadFilament` directly
- On new spool data scan: opens AddSpoolView pre-filled with scanned data

## Pre-fill Pattern for AddSpoolView
- `AddSpoolView(scannedData:)` optional parameter
- `AddSpoolViewModel.prefill(from:)` called in `.task` modifier
- `isPrefilledFromScan` flag controls banner visibility
- User can edit all pre-filled fields before saving

**Impact:**
- **Lambert:** NFCWriteView needs `NFCService.writeTag(spool:)` wired in. QRScannerView is independent of his QRCodeParser (uses its own simple parser). `configureNFCScanner(_:)` on ViewModels ready for DI wiring.
- **Ash:** SpoolPickerViewModel and AddSpoolViewModel have new properties/methods needing test coverage. MockSpoolScannerService needed.
- **Dallas:** No navigation changes. ServiceContainer may need NFCService/QRSpoolScannerService for ViewModel DI.
