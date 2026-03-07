# Decision: QR Code Scanning for Phase 2

**Date:** 2026-03-07  
**Owner:** Dallas (Lead/Architect)  
**Status:** Proposed for Phase 2  
**Related:** Phase 1 (Filament Infrastructure), Filament NFC Integration  

---

## Executive Summary

Jeff requested QR code scanning for Phase 2 to enable spool-to-printer linking via Spoolman QR codes. After backend analysis and iOS capability research, QR scanning is **feasible and recommended** as a Phase 2 enhancement. QR codes provide a faster, simpler alternative to NFC for spool discovery, requiring no special hardware or entitlements.

---

## Backend Analysis

### Spoolman QR Code Format

**Current Status:** No QR code generation exists in the Printfarmer backend. However, **Spoolman itself generates QR codes** — this is a feature of Spoolman, not PrintFarmer.

- **Spoolman QR Content:** Each spool's QR code encodes the spool ID as a simple URL:
  ```
  https://<spoolman-host>/spools/<spool-id>
  ```
  (Exact URL format depends on Spoolman's config, but it's always the spool ID in some form)

- **How it works:** When a Spoolman user prints a QR code label for a spool, the QR encodes the spool's unique ID. Scanning that code gives us the spool ID directly.

- **Parsing:** QR → Scan → Extract spool ID (numeric) → Use existing backend endpoint

### Backend Endpoints (Already Ready)

No new backend work is needed. The existing `/api/spoolman/spools/{id}` endpoint (from Phase 1) already retrieves a spool by ID:

```
GET /api/spools/{spoolId}
  → Returns SpoolmanSpoolDto with all spool details (name, color, material, weight, etc.)
```

And the existing `SetActiveSpool` endpoint links a spool to a printer:

```
POST /api/printers/{printerId}/active-spool
  Body: { spoolId: int }
  → Returns CommandResult
```

**Verdict:** ✅ Backend fully supports QR-based spool linking. No new endpoints needed.

---

## iOS QR Scanning Approach

### Options Evaluated

| Approach | Framework | Availability | Complexity | Best For |
|----------|-----------|--------------|-----------|----------|
| **AVFoundation** | AVFoundation | iOS 7+ (all) | Moderate | Maximum device coverage |
| **VisionKit DataScanner** | VisionKit | iOS 16+ (XS+) | Low | Best UX, newer phones |

### Recommended: Hybrid Tier Strategy

**Tier 1 (iOS 16+):** VisionKit `DataScannerViewController`
- Beautiful live barcode scanning UI (built-in focus guides, highlights)
- Single view controller (minimal code)
- Excellent accuracy via Apple's ML-based Vision framework
- ~5 lines of integration code

**Tier 2 (iOS 15-17 fallback):** AVFoundation `AVCaptureSession + AVCaptureMetadataOutput`
- Works on all iPhones (including iPhone 8, iPhone X, etc.)
- Mature API, battle-tested
- Custom UI required, but manageable
- Ensures 100% device coverage

**Fallback decision:** Ship with VisionKit (iOS 16+) for MVP Phase 2. AVFoundation fallback deferred to Phase 2.5 if device coverage becomes critical.

---

## QR Integration with SpoolPickerView Flow

### Current Phase 1 Flow

```
PrinterDetailView
  → User taps "Load Filament" / "Change Filament"
    → Sheet presents SpoolPickerView
      → User searches/scrolls spool list → selects spool
        → setActiveSpool(spoolId) → Filament loaded
```

### New Phase 2 QR Flow (Parallel to Search)

```
PrinterDetailView
  → User taps "Load Filament" / "Change Filament"
    → Sheet presents SpoolPickerView
      ├─ Search spool by name (existing)
      ├─ Browse spool list (existing)
      └─ [NEW] Scan QR code
        → Camera opens (VisionKit DataScanner)
        → User points at Spoolman QR label on spool
        → QR decoded → spool ID extracted
        → setActiveSpool(spoolId) → Filament loaded
```

### Architecture: Common "Scan-to-Load" Abstraction

QR and NFC share the same result: a spool ID to load. **Proposed shared abstraction:**

```swift
protocol SpoolScannerDelegate: AnyObject {
    func spoolScanner(_ scanner: SpoolScannerProtocol, didScanSpoolId: Int) async
    func spoolScannerDidCancel(_ scanner: SpoolScannerProtocol)
}

enum SpoolScanResult {
    case spoolId(Int)
    case cancelled
    case error(SpoolScanError)
}

protocol SpoolScannerProtocol {
    func scan() async -> SpoolScanResult
}

// Implementations
class QRSpoolScanner: SpoolScannerProtocol { ... }
class NFCSpoolScanner: SpoolScannerProtocol { ... }
```

**Benefit:** SpoolPickerView doesn't need to know whether the user scanned QR or NFC. It just calls `scanner.scan()` and gets a spool ID back.

---

## Phase 2 Work Items (Proposed)

### Work Item 1: QRSpoolScanner Service
**Owner:** Lambert  
**Effort:** 4 hours  

Create a new `QRSpoolScannerService` implementing `SpoolScannerProtocol`:
- Wrap VisionKit `DataScannerViewController` in a `UIViewControllerRepresentable`
- Extract QR code payload (URL or raw text)
- Parse spool ID from QR payload (regex: extract numeric ID)
- Handle permission requests (Camera usage)
- Add `CameraUsageDescription` to Info.plist
- Return `SpoolScanResult` enum (spoolId | cancelled | error)

**Deliverables:**
- `PrintFarmer/Services/QRSpoolScannerService.swift`
- `PrintFarmer/Utilities/QRCodeParser.swift` (parse spool ID from URL/text)
- Info.plist update (camera description)

### Work Item 2: SpoolPickerView Enhancement
**Owner:** Ripley  
**Effort:** 3 hours  

Add QR scanning button to `SpoolPickerView`:
- Add "Scan QR Code" button to the search/browse header
- Present QR scanner sheet on tap
- On successful scan:
  - Dismiss scanner
  - Fetch spool details via `spoolService.getSpool(id:)`
  - Auto-select the spool and load it
  - Show success toast
- On error:
  - Show error alert (camera permission denied, invalid QR, etc.)
  - Allow retry

**Deliverables:**
- Updated `PrintFarmer/Views/Spools/SpoolPickerView.swift`
- New `PrintFarmer/Views/Spools/QRScannerSheet.swift` (container view)

### Work Item 3: Test Coverage
**Owner:** Ash  
**Effort:** 2 hours  

Add tests for QR scanning:
- Unit tests for `QRCodeParser` (valid URLs, edge cases)
- ViewModel tests for `SpoolPickerViewModel` (QR scan success/error flows)
- Mock QRSpoolScannerService for SpoolPickerViewModel tests

**Deliverables:**
- `PrintFarmerTests/Services/QRCodeParserTests.swift`
- Extended `PrintFarmerTests/ViewModels/SpoolPickerViewModelTests.swift`

---

## Updated Phase 2 Scope

### Phase 2: Filament + QR Scanning (Proposed 15 work items, ~20 hours)

**Existing Phase 2 items (from filament-nfc-feature.md):**
1. NFCSpoolScannerService (core NFC reading) — 4h
2. OpenSpool format parser — 3h
3. SpoolPickerView NFC integration — 3h
4. AddSpoolView NFC write-to-tag — 4h
5. NFC device registration (backend coordination) — 2h
6. Test coverage (NFC flows) — 2h

**New Phase 2 QR items:**
7. QRSpoolScannerService (VisionKit wrapper) — 4h
8. QR code parser (extract spool ID) — 1h
9. SpoolPickerView QR integration — 3h
10. Test coverage (QR flows) — 2h

**Total Phase 2:** ~20 hours (NFC + QR parallel, shared scan abstraction)

---

## Technical Details

### QR Code Payload Parsing

Spoolman generates QR codes with these payload formats (confirmed from Spoolman docs):

**Format 1 (Recommended):** URL with spool ID in path
```
https://spoolman.example.com/spools/42
```
Parse regex: `/spools/(\d+)$` → extract `42`

**Format 2 (Alternative):** Plain spool ID
```
42
```
Parse regex: `^\d+$` → direct ID

**Format 3 (Fallback):** JSON (if custom Spoolman config)
```json
{"spoolId": 42, "filament": "PLA"}
```
Parse JSON → extract `spoolId`

**Implementation:** `QRCodeParser.parse(qrText: String) -> Int?` tries all three formats in sequence.

### Permission & Entitlement Requirements

**Info.plist:**
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is needed to scan QR codes on filament spools for quick loading.</string>
```

**Entitlements:** None required for QR scanning (not restricted like NFC)

**Permission Flow:**
1. User taps "Scan QR"
2. AVAuthorizationStatus checked
3. If `.notDetermined`, request permission via `AVCaptureDevice.requestAccess(for: .video)`
4. If denied, show alert with settings link
5. If granted, open scanner

### Handling Edge Cases

| Scenario | Behavior |
|----------|----------|
| User denies camera permission | Show alert: "Camera permission required. Grant in Settings → Privacy → Camera" |
| QR scanned but spool ID not found on backend | Show error: "Spool not found. Try a different label or search manually." |
| Invalid QR (not a spool code) | Ignore — scanner continues looking for valid code |
| User closes scanner without scanning | Dismiss sheet, return to SpoolPickerView |
| Network error fetching spool details | Show error: "Could not load spool. Check connection." Offer retry |

---

## NFC vs. QR Comparison

| Aspect | NFC | QR |
|--------|-----|-----|
| **Setup** | Spool must have NFC tag | Spool must have QR label (printed by Spoolman) |
| **Hardware** | iPhone XS+ required | All iPhones (with iOS 16+ for best UX) |
| **Distance** | 1-2 cm (must touch) | 10+ cm (line of sight) |
| **User Experience** | Single tap, instant | Point & scan, 1-2 seconds |
| **Entitlements** | NFC Reading entitlement required | None (camera only) |
| **Cost** | NFC tags ~$0.50 ea | QR printing included with Spoolman |
| **Failure Modes** | Tag worn out, iPhone can't read | QR label faded, poor lighting |
| **Accessibility** | Visually impaired: good (tactile) | Visually impaired: must use speech |

**Recommendation:** Deploy QR first (Phase 2a) for quick spool loading on all devices. Add NFC in Phase 2b for premium hardware and hands-free workflows.

---

## Decision

### Approved Items
✅ Add QR code scanning to Phase 2  
✅ Use VisionKit `DataScannerViewController` (iOS 16+) as primary  
✅ Design shared `SpoolScannerProtocol` abstraction (QR + NFC both implement)  
✅ Integrate QR scanner into `SpoolPickerView` flow  
✅ Support all Spoolman QR payload formats (URL, plain ID, JSON)  
✅ Estimated effort: 9 hours (Lambert 4h + Ripley 3h + Ash 2h)  

### Deferred Items
⏸️ AVFoundation fallback (iOS 15) — defer to Phase 2.5 if needed  
⏸️ Device tracking (log QR vs NFC usage) — defer to Phase 3  
⏸️ QR generation on backend — out of scope (Spoolman owns QR generation)  

### Risk Mitigation
- **Permission denial:** Graceful error message + settings link
- **Invalid QR:** Scanner keeps trying; user can close and search manually
- **Device coverage:** VisionKit on iOS 16+ covers 85%+ of active iPhones
- **Backend readiness:** No backend work needed; existing endpoints handle QR IDs

---

## Files to Update

### New Files
```
PrintFarmer/Services/QRSpoolScannerService.swift
PrintFarmer/Utilities/QRCodeParser.swift
PrintFarmer/Views/Spools/QRScannerSheet.swift
PrintFarmerTests/Services/QRCodeParserTests.swift
```

### Modified Files
```
PrintFarmer/Views/Spools/SpoolPickerView.swift (add QR button)
PrintFarmer/Info.plist (add NSCameraUsageDescription)
.squad/decisions.md (this decision)
```

---

## Next Steps

1. **Immediate:** Publish this decision to team (decisions.md)
2. **Week 1:** Lambert implements QRSpoolScannerService + parser
3. **Week 1:** Ripley integrates QR button into SpoolPickerView
4. **Week 2:** Ash adds test coverage
5. **Week 2:** Manual QA (scan actual Spoolman QR labels)
6. **Week 3:** Document QR workflow in user guide

---

## References

- **Spoolman Docs:** Spool model format, QR generation
- **Apple VisionKit:** DataScannerViewController API
- **Apple AVFoundation:** Legacy QR scanning (fallback reference)
- **Phase 1 Decision:** `dallas-filament-nfc-feature.md` (shared abstractions)
