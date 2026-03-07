# Feature Decomposition: Filament Management + NFC Tag Support

**Author:** Dallas (Lead/Architect)  
**Date:** 2025-07-19  
**Status:** Proposed  

---

## Executive Summary

The backend is **fully ready** — FilamentType, Spool, NfcDevice, and NfcScanEvent entities already exist with complete CRUD endpoints, Spoolman integration, and NFC scan event processing. The iOS app already has the `PrinterSpoolInfo` model embedded in `Printer` but **never displays it**. This is primarily an iOS-side feature build.

---

## Backend API Inventory (Already Exists)

### Filament / Spool Endpoints (No Backend Work Needed)

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `GET /api/filament-types` | GET | List all filament types (PLA, PETG, etc.) |
| `GET /api/filament-types/presets` | GET | Temperature presets per material |
| `GET /api/spoolman/spools` | GET | List spools from Spoolman (paginated) |
| `POST /api/spoolman/spools` | POST | Create new spool |
| `PATCH /api/spoolman/spools/{id}` | PATCH | Update spool |
| `DELETE /api/spoolman/spools/{id}` | DELETE | Delete spool |
| `GET /api/spoolman/filaments` | GET | List filaments from Spoolman |
| `GET /api/spoolman/vendors` | GET | List vendors |
| `GET /api/spoolman/materials` | GET | List materials |
| `POST /api/printers/{id}/active-spool` | POST | Set/clear active spool for printer |
| `GET /api/printers/{id}/spoolman/spools` | GET | List available spools for a printer |
| `POST /api/printers/{id}/filament-load` | POST | Load filament command |
| `POST /api/printers/{id}/filament-unload` | POST | Unload filament command |

### NFC Endpoints (Already Exists)

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `GET /api/nfc-devices` | GET | List NFC devices |
| `GET /api/nfc-devices/{id}` | GET | Get NFC device details |
| `POST /api/nfc-devices` | POST | Register NFC device |
| `POST /api/nfc-devices/scan` | POST | Submit NFC scan event |
| `GET /api/nfc-devices/{id}/history` | GET | Scan history for device |

### Backend Gap: iOS-Initiated NFC Scanning

The existing NFC flow assumes **ESP32 hardware** pushes scan events to the server. For **phone-initiated NFC scans**, we need the iOS app to:
1. Read NFC tag locally via CoreNFC
2. Parse the tag payload (OpenSpool/OpenPrintTag format)
3. POST the parsed data to `POST /api/nfc-devices/scan` (or a new phone-specific endpoint)

**Decision:** Reuse `POST /api/nfc-devices/scan` for phone scans. The iOS device acts as a virtual NFC reader. May need a backend tweak to accept scans without a registered `NfcDeviceId` (or auto-register the phone as a device). **Flag for Dallas to coordinate with backend.**

---

## iOS Models (Existing vs. New)

### Already Exists
- `Printer.spoolInfo: PrinterSpoolInfo?` — has `hasActiveSpool`, `activeSpoolId`, `spoolName`, `material`, `colorHex`, `filamentName`, `vendor`, `remainingWeightG`
- `PrintJob` has `spoolmanFilamentId`, `filamentName`, `filamentVendor`, `filamentColor`

### New Models Needed

```
Spool — id: Int, name: String?, material: String?, colorHex: String?,
         vendor: String?, remainingWeight: Double?, totalWeight: Double?,
         filamentName: String?, inUse: Bool

FilamentType — id: UUID, name: String, defaultHotendTemp: Double?,
               defaultBedTemp: Double?, isAbrasive: Bool, needsEnclosure: Bool

SpoolmanConfig — baseUrl: String (for settings display)

NfcTagPayload — spoolId: Int?, material: String?, brand: String?,
                 tagFormat: String (openspool/openprinttag/raw)

SetActiveSpoolRequest — spoolId: Int? (nil to clear)
```

---

## Phase 1: Filament Management

### Work Items

#### P1-1: Filament Section in PrinterDetailView
**Owner:** Ripley (iOS UI)  
**Priority:** High  
**Dependencies:** P1-2 (service methods)

Display current spool info in PrinterDetailView using existing `printer.spoolInfo`:
- Show material type, color swatch (from colorHex), filament name, vendor
- Show remaining weight with visual indicator
- "No filament loaded" empty state when `spoolInfo.hasActiveSpool == false`
- "Load Filament" / "Eject Filament" action buttons

#### P1-2: SpoolService + PrinterService Extensions
**Owner:** Lambert (Networking)  
**Priority:** High  
**Dependencies:** None (backend ready)

New `SpoolService` actor with:
- `listSpools(page:pageSize:) async throws -> [Spool]` — `GET /api/spoolman/spools`
- `createSpool(_:) async throws -> Spool` — `POST /api/spoolman/spools`
- `updateSpool(id:_:) async throws -> Spool` — `PATCH /api/spoolman/spools/{id}`
- `deleteSpool(id:) async throws` — `DELETE /api/spoolman/spools/{id}`
- `listMaterials() async throws -> [String]` — `GET /api/spoolman/materials`
- `listVendors() async throws -> [SpoolmanVendor]` — `GET /api/spoolman/vendors`

Extend `PrinterService` with:
- `setActiveSpool(printerId:spoolId:) async throws -> Printer` — `POST /api/printers/{id}/active-spool`
- `listAvailableSpools(printerId:) async throws -> [Spool]` — `GET /api/printers/{id}/spoolman/spools`
- `loadFilament(id:) async throws -> CommandResult` — `POST /api/printers/{id}/filament-load`
- `unloadFilament(id:) async throws -> CommandResult` — `POST /api/printers/{id}/filament-unload`

Add `SpoolServiceProtocol` and register in `ServiceContainer`.

#### P1-3: Spool Picker Sheet
**Owner:** Ripley (iOS UI)  
**Priority:** High  
**Dependencies:** P1-2

New `SpoolPickerView` + `SpoolPickerViewModel`:
- Presented as sheet from PrinterDetailView "Load Filament" button
- Lists available spools with color swatches, material type, remaining weight
- Search/filter by material type
- Selecting a spool calls `printerService.setActiveSpool()` then `loadFilament()`
- Empty state if no spools in inventory

#### P1-4: Spool Inventory View (Tab or Settings Sub-screen)
**Owner:** Ripley (iOS UI)  
**Priority:** Medium  
**Dependencies:** P1-2

New `SpoolInventoryView` + `SpoolInventoryViewModel`:
- List all spools in the Spoolman database
- Color swatch, material, vendor, weight remaining
- Swipe to delete
- Add button → `AddSpoolView` form
- Navigation from Settings tab or dedicated Inventory tab

#### P1-5: Add Spool Form
**Owner:** Ripley (iOS UI)  
**Priority:** Medium  
**Dependencies:** P1-2

New `AddSpoolView` + `AddSpoolViewModel`:
- Material picker (from `listMaterials()`)
- Vendor picker (from `listVendors()`)
- Color picker (hex)
- Total weight (grams)
- Filament name (free text)
- Calls `spoolService.createSpool()`

#### P1-6: PrinterDetailViewModel Extensions
**Owner:** Ripley (iOS UI)  
**Priority:** High  
**Dependencies:** P1-2

Add to `PrinterDetailViewModel`:
- `loadFilament()` / `ejectFilament()` actions
- `showSpoolPicker: Bool` state
- `spoolService` dependency (from ServiceContainer)
- Wire up filament section interactions

#### P1-7: Model Definitions
**Owner:** Lambert (Networking)  
**Priority:** High  
**Dependencies:** None

Add `Spool`, `FilamentType`, `SpoolmanVendor`, `SetActiveSpoolRequest` models to Models.swift.
Verify field names match backend DTOs (check Spoolman proxy response format).

---

## Phase 2: NFC Tag Support

### iOS NFC Requirements

**Framework:** CoreNFC  
**Minimum OS:** iOS 13+ (we target iOS 17, so fine)  
**Device Requirement:** iPhone 7 or later (all devices running iOS 17 support NFC)

**Info.plist entries required:**
```xml
<key>NFCReaderUsageDescription</key>
<string>PrintFarmer uses NFC to identify filament spools and associate them with printers.</string>
<key>com.apple.developer.nfc.readersession.iso7816.select-identifiers</key>
<array>
    <string>D276000085010100</string>
</array>
<key>com.apple.developer.nfc.readersession.felica.systemcodes</key>
<array/>
```

**Entitlements required:**
- `com.apple.developer.nfc.readersession.formats` — add NFC Tag Reading capability in Xcode Signing & Capabilities

**Tag formats to support (from backend NfcScanEvent):**
- `openspool` — community standard for filament NFC tags
- `openprinttag` — alternative format
- `raw` — fallback for unrecognized tags

**Limitations:**
- NFC scanning requires user interaction (system sheet appears)
- Background tag reading available but requires NDEF format
- Writing NFC tags supported via `NFCNDEFSession` (for creating new tags)

### Work Items

#### P2-1: NFCService
**Owner:** Lambert (Networking)  
**Priority:** High  
**Dependencies:** None

New `NFCService` (not an actor — must be `NSObject` subclass for `NFCNDEFReaderSessionDelegate`):
- `scanTag() async throws -> NfcTagPayload` — initiate NFC scan, parse NDEF records
- `writeTag(spoolId:material:brand:) async throws` — write spool data to NFC tag
- Parse OpenSpool and OpenPrintTag NDEF record formats
- Handle `NFCReaderSession` lifecycle and errors
- Protocol: `NFCServiceProtocol` for testability

#### P2-2: Info.plist + Entitlements
**Owner:** Lambert (Networking)  
**Priority:** High  
**Dependencies:** None

- Add `NFCReaderUsageDescription` to Info.plist
- Add NFC Tag Reading capability to entitlements
- Add NDEF select identifiers for tag detection

#### P2-3: Scan-to-Load Flow (PrinterDetail)
**Owner:** Ripley (iOS UI)  
**Priority:** High  
**Dependencies:** P1-1, P2-1

On PrinterDetailView, add "Scan Spool NFC" button:
- Triggers `nfcService.scanTag()`
- Parses spool ID from tag
- Looks up spool in Spoolman database
- If found: calls `printerService.setActiveSpool()` to assign
- If not found: prompt to create new spool with scanned data
- Reports scan to backend via `POST /api/nfc-devices/scan`

#### P2-4: Write NFC Tag Flow
**Owner:** Ripley (iOS UI)  
**Priority:** Medium  
**Dependencies:** P2-1

New `WriteNfcTagView`:
- Select spool from inventory
- Tap "Write Tag" → hold phone to blank NFC tag
- Writes OpenSpool format NDEF record with spool metadata
- Confirmation on success

#### P2-5: Add Spool via NFC Scan
**Owner:** Ripley (iOS UI)  
**Priority:** Medium  
**Dependencies:** P1-5, P2-1

Enhance `AddSpoolView`:
- "Scan NFC Tag" button pre-fills form fields from tag data
- If tag has unknown spool ID, creates new spool with tag metadata
- After creation, optionally writes Spoolman ID back to tag

#### P2-6: PrinterDetailViewModel NFC Extensions
**Owner:** Ripley (iOS UI)  
**Priority:** High  
**Dependencies:** P2-1, P2-3

Add to `PrinterDetailViewModel`:
- `scanAndLoadSpool()` action
- `nfcService` dependency
- NFC scan state management (scanning, success, error)

---

## Dependency Graph

```
Phase 1:
  P1-7 (Models) ─┐
  P1-2 (SpoolService) ──┬── P1-1 (Filament Section UI)
                         ├── P1-3 (Spool Picker)
                         ├── P1-4 (Inventory View)
                         ├── P1-5 (Add Spool Form)
                         └── P1-6 (ViewModel Extensions)

Phase 2:
  P2-2 (Info.plist) ─┐
  P2-1 (NFCService) ──┬── P2-3 (Scan-to-Load Flow)
                       ├── P2-4 (Write NFC Tag)
                       ├── P2-5 (Add via NFC)
                       └── P2-6 (ViewModel NFC Extensions)

Cross-phase:
  P1-1 ──── P2-3 (scan button lives in filament section)
  P1-5 ──── P2-5 (add spool form gets NFC pre-fill)
```

---

## Implementation Order

### Sprint 1 (Phase 1 Core)
1. **P1-7** Lambert: Models — 1 hour
2. **P1-2** Lambert: SpoolService + PrinterService extensions — 2 hours
3. **P1-1** Ripley: Filament section in PrinterDetailView — 2 hours
4. **P1-6** Ripley: ViewModel extensions — 1 hour
5. **P1-3** Ripley: Spool picker sheet — 2 hours

### Sprint 2 (Phase 1 Complete)
6. **P1-4** Ripley: Spool inventory view — 3 hours
7. **P1-5** Ripley: Add spool form — 2 hours

### Sprint 3 (Phase 2)
8. **P2-2** Lambert: Info.plist + entitlements — 30 min
9. **P2-1** Lambert: NFCService — 4 hours (CoreNFC + OpenSpool parsing)
10. **P2-3** Ripley: Scan-to-load flow — 2 hours
11. **P2-6** Ripley: ViewModel NFC extensions — 1 hour
12. **P2-4** Ripley: Write NFC tag — 2 hours
13. **P2-5** Ripley: Add spool via NFC — 1 hour

**Total estimate:** ~22 hours of implementation

---

## Open Questions for Jeff

1. **Spoolman dependency:** The backend proxies all spool operations through Spoolman. Is Spoolman always configured, or do we need a fallback using the local `Spool` entity? This affects whether we hit `/api/spoolman/spools` or need a separate `/api/spools` endpoint.

2. **Phone as NFC device:** Should the iOS device register itself as an NFC device in the backend (`POST /api/nfc-devices`), or should phone-initiated scans use a different flow? The current backend expects scans from ESP32 hardware.

3. **NFC tag format:** Which format should we write — OpenSpool or OpenPrintTag? OpenSpool appears to be the community standard.

4. **Inventory access:** Should spool inventory be a new tab, a sub-screen under Settings, or accessible only from printer detail? Affects navigation changes.

---

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| CoreNFC requires physical device testing (no simulator) | Flag early; all NFC work needs device testing |
| OpenSpool NDEF format may vary by manufacturer | Implement flexible parser with fallback to raw |
| Spoolman may not be configured on all deployments | Check `/api/spoolman/config` and show setup prompt if missing |
| NFC entitlement requires specific App ID configuration | Lambert handles in P2-2; must be done in Apple Developer Portal |
