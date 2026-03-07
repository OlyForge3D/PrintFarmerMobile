# Lambert Phase 2 — Scanning Services Decisions

**Date:** 2026-07-17  
**Author:** Lambert  
**Status:** Implemented

## Decision: No Info.plist File

iOS 17+ projects using Xcode's modern build system don't generate a standalone Info.plist by default. The project has no `PrintFarmer/Info.plist`. Camera and NFC usage descriptions (`NSCameraUsageDescription`, `NFCReaderUsageDescription`) need to be added via the target's Info tab in Xcode or by creating an Info.plist manually.

**Action needed (Ripley/Dallas):** Add these keys to the Xcode target:
- `NSCameraUsageDescription`: "Camera access is needed to scan QR codes on filament spools."
- `NFCReaderUsageDescription`: "NFC is used to read and write filament spool tags."
- Also ensure the `com.apple.developer.nfc.readersession.formats` entitlement includes `NDEF`.

## Decision: `#if canImport(UIKit)` Guards on Scanner Services

Both `QRSpoolScannerService` and `NFCService` are wrapped in `#if canImport(UIKit)` so the SPM macOS build (`swift build`) succeeds. ServiceContainer conditionally registers them with the same guard. This matches the pattern established for PushNotificationManager.

## Decision: No Backend NFC Endpoint

Searched `~/s/PFarm1/src/` — there is no `/api/nfc-devices/scan` or similar NFC endpoint in the backend. NFC scanning/writing is purely client-side. Tags encode spool data in OpenSpool/OpenPrintTag NDEF format. When a tag contains a `spoolman_id`, the ViewModel uses the existing `SpoolService.getSpool(id:)` to fetch full data.

## Decision: OpenSpool as Primary Write Format

When writing NFC tags via `NFCService.writeTag(spool:)`, we use OpenSpool format exclusively (not OpenPrintTag). OpenSpool is the community standard for 3D printing filament tags. Reading supports both formats.

## Decision: QRCodeParser Supports Three Formats

QR code parsing handles: URL paths (`/spools/42`), plain numeric (`42`), and JSON (`{"spoolId": 42}`). Also accepts `spool_id` and `id` as JSON keys for flexibility with different Spoolman frontend versions.
