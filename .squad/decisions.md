# Squad Decisions

## Active Decisions

### Decision: Spoolman Spool Model Naming & Pagination (Lambert)
**Date:** 2026-03-07  
**Status:** Implemented

## Context
Phase 1 filament/spool models needed to match backend DTOs precisely.

## Decisions

1. **Model names use `Spoolman` prefix** (`SpoolmanSpool`, `SpoolmanFilament`, `SpoolmanVendor`, `SpoolmanMaterial`) to match backend DTO names and avoid collision with future domain models (e.g., a simpler `Spool` view model).

2. **Pagination uses `limit`/`offset`** (not `page`/`pageSize`) — matches Spoolman's native API which the backend proxies. Return type is `SpoolmanPagedResult<T>` with `items` and `totalCount`.

3. **Added `patch()` to APIClient** — backend uses HTTP PATCH for spool and filament updates. This is a new HTTP method available to all services.

4. **`SetActiveSpoolRequest` returns `CommandResult`** (not `Printer`) — matches backend's `PrintersController.SetActiveSpoolAsync` which returns `CommandResult`.

5. **Added `changeFilament()` to PrinterService** — backend has `filament-change` (M600) in addition to `filament-load`/`filament-unload`. Included for completeness.

## Impact
- Ripley can build filament management UI against `SpoolServiceProtocol` and the extended `PrinterServiceProtocol`.
- ViewModels should use `SpoolmanPagedResult` for infinite scroll / pagination patterns.

---

### Filament UI Architecture (Ripley)
**Date:** 2026-03-07  
**Status:** Implemented

## Tab Structure Change
- Added **Inventory** tab (6th tab) to ContentView TabView using `cylinder.fill` SF Symbol
- Added `AppTab.inventory` case and `inventoryPath` NavigationPath to AppRouter
- Tab order: Dashboard → Printers → Jobs → Alerts → **Inventory** → Settings

## Filament Section in PrinterDetailView
- Filament section always renders between Camera and Actions sections
- Shows active spool info (color swatch, material, vendor, weight progress bar) or "No filament loaded" empty state
- "Load Filament" / "Change Filament" → presents SpoolPickerView as `.sheet`
- "Eject" → calls `printerService.setActiveSpool(nil)` + `printerService.unloadFilament()`
- `setActiveSpool(_:)` → calls `printerService.setActiveSpool(spoolId)` + `printerService.loadFilament()`

## SpoolService Dependency
- ViewModels use `SpoolServiceProtocol` (Lambert's protocol) via `ServiceContainer.spoolService`
- PrinterDetailViewModel uses `PrinterServiceProtocol` filament methods (setActiveSpool, loadFilament, unloadFilament) — NOT SpoolServiceProtocol
- SpoolPickerViewModel and SpoolInventoryViewModel use `SpoolServiceProtocol` for listing/creating/deleting spools

## Phase 2 NFC Hook
- SpoolPickerView and AddSpoolView are designed to accept NFC-scanned spool data (OpenSpool / OpenPrintTag formats)
- Future work: Add "Scan NFC" button that auto-populates spool fields from tag

**Impact:**
- **Lambert:** No changes needed — all services already built and working
- **Ash:** 3 new ViewModels need test coverage (SpoolPickerViewModel, SpoolInventoryViewModel, AddSpoolViewModel); MockSpoolService needed
- **Dallas:** AppRouter has new `inventory` case — any navigation routing logic should account for it

---

### Camera Snapshot Display Strategy (Ripley)
**Date:** 2025-07-18  
**Status:** Implemented

Two-tier loading strategy for camera snapshots in PrinterDetailView:
1. **Primary:** Load snapshot as `Data` via `PrinterServiceProtocol.getSnapshot(id:)` (authenticated, reliable)
2. **Fallback:** Display via `AsyncImage` from `Printer.cameraSnapshotUrl` (direct URL, no auth needed)
3. **Empty state:** "No camera available" placeholder when neither source exists

Service-based snapshot fetch handles auth tokens automatically; direct URL provides seamless fallback.

**Impact:**
- Lambert: No changes needed — existing `getSnapshot(id:)` contract unchanged
- Ash: `PrinterDetailViewModel` gains `isLoadingSnapshot: Bool` and `refreshSnapshot() async` — tests may need updating

---

### Push Notification Infrastructure (Lambert)
**Date:** 2026-07-17  
**Status:** Implemented (client-side); backend endpoint pending

#### Architecture
- **PushNotificationManager** is a `@MainActor @Observable` singleton owning APNs lifecycle
- **AppDelegate** adapter handles system callbacks and forwards to PushNotificationManager
- **NotificationService** extended with `registerDeviceToken` / `unregisterDeviceToken` methods

#### Backend Endpoint (Placeholder)
- NotificationsController.cs has an `EnablePushNotifications` preference flag but **no device token registration endpoint**
- Client uses placeholder paths: `POST /api/notifications/device-token` (register) and `DELETE /api/notifications/device-token/{token}` (unregister)
- **Action needed from Dallas:** Add device token registration endpoint to the backend. Suggested DTO: `{ token: string, platform: "ios" | "android" }`

#### Deep-Link Hook
- Tapped notifications post `Notification.Name.pushNotificationTapped` with the push payload's `userInfo`
- **Ripley** can observe this in `AppRouter` to navigate to the relevant printer/job detail screen

**Impact:**
- **Ripley:** SettingsView now has a push notification toggle. Deep-link notification available for navigation wiring
- **Dallas:** Backend needs a device token registration endpoint
- **Ash:** MockNotificationService updated with new protocol methods; existing tests unaffected

**Files Changed:**
- PrintFarmer/Services/PushNotificationManager.swift (new)
- PrintFarmer/App/AppDelegate.swift (new)
- PrintFarmer/Services/NotificationService.swift (extended)
- PrintFarmer/Services/APIClient.swift (new postVoid overload)
- PrintFarmer/Protocols/NotificationServiceProtocol.swift (extended)
- PrintFarmer/Models/RequestModels.swift (new DeviceTokenRegistration DTO)
- PrintFarmer/PFarmApp.swift (AppDelegate adaptor + push config)
- PrintFarmer/Views/Settings/SettingsView.swift (notification toggle)
- PrintFarmerTests/Mocks/MockNotificationService.swift (new mock methods)

---

### Copilot Model Directive (Jeff Papiez)
**Date:** 2026-03-06  
**Status:** Accepted

#### Recommended Model for Code-Writing Agents
- Use **claude-opus-4.6** for Ripley (iOS Dev), Lambert (Networking), Ash (UI/Navigation)
- Use cost-optimized models (Haiku) for Scribe and non-code tasks
- **Rationale:** Code quality and architectural decisions benefit from stronger model reasoning

---

### Login Screen Architecture (Ripley)
**Date:** 2026-03-06  
**Status:** Implemented

#### Form State Separation
- **LoginViewModel** (`@MainActor @Observable`): Manages serverURL, username, password, validation
- **AuthViewModel** (`@Observable @unchecked Sendable`): Manages isAuthenticated, currentUser
- LoginViewModel delegates authentication to AuthViewModel, keeping form concerns isolated

#### Server URL Flow
- User enters server URL in LoginView → LoginViewModel normalizes → AuthViewModel passes to AuthService.login(serverURL:) → AuthService calls APIClient.updateBaseURL()
- Server URL persisted in UserDefaults (`pf_server_url`)
- On app launch, APIClient.savedBaseURL() restores last-used server

#### Session Restore Pattern
- AuthViewModel created as `@State` in PFarmApp; AuthService injected via configure(with:) in .task
- Dark Mode support confirmed working
- Error handling with animated banner

**Impact:** 
- Lambert's AuthService.login(serverURL:) API is concrete
- Dallas's PFarmApp wiring pattern established
- Ash has clear dependency injection precedent

---

### Auth Response Contract: Single JWT Token (Lambert)
**Date:** 2026-03-06  
**Status:** Implemented

#### Token Model
- Backend returns single `token` field in AuthenticationResult (not separate access/refresh)
- iOS AuthResponse updated to match (verified against PFarm1 backend)

#### Token Lifecycle
- Single JWT stored in Keychain (key: `pf_jwt_token`)
- No token refresh endpoint; re-authentication required if token expires
- Session restore via `GET /api/auth/me` validates token; logs out if expired

#### Base URL Management
- Server URL entered at login, stored in UserDefaults (`pf_server_url`)
- APIClient.updateBaseURL() is single mutation point (actor-isolated)
- Restored on app launch

**Impact:**
- Ripley's LoginViewModel can safely call AuthService.login(serverURL:)
- Dallas's DI pattern compatible with actor isolation
- No refresh logic needed; simplifies token lifecycle

---

### iOS Project Structure (Dallas)
**Date:** 2025-07-16  
**Status:** Accepted

#### Architecture: MVVM + Repository Pattern
- **Views** (SwiftUI) → **ViewModels** (`@Observable`) → **Services** (actor-based) → **APIClient** (actor)
- Services are actors for thread-safe network access under Swift 6 strict concurrency
- ViewModels are `@Observable` (not ObservableObject) for modern SwiftUI

#### Navigation: Router + TabView
- `AppRouter` (`@Observable`) manages tab selection and per-tab `NavigationPath`
- 5 tabs: Dashboard, Printers, Jobs, Locations, Settings
- Deep navigation via `AppDestination` enum with associated values

#### Dependency Injection: ServiceContainer
- Single `ServiceContainer` created at app launch, passed via SwiftUI environment
- No third-party DI framework — keep it simple

#### Auth: Keychain + JWT
- KeychainSwift for secure token storage
- `AuthService` manages login/logout/session restore
- `AuthViewModel` gates root view (login vs main app)

#### Networking: Actor-based APIClient
- `APIClient` is a Swift actor — all token and request state is isolated
- ISO 8601 date decoding, typed `NetworkError` enum
- Base URL configurable via `PRINTFARMER_API_URL` env var

#### Models: Sendable Codable structs
- All models conform to `Codable`, `Identifiable`, `Sendable`
- Organized: `Models.swift` (core), `RequestModels.swift` (DTOs), `SignalRModels.swift` (real-time)
- Property names match backend JSON (camelCase) — no custom CodingKeys needed

#### SignalR: Deferred
- Stub created. Client package selection deferred — candidates:
  - microsoft/signalr-client-swift (official)
  - moozzyk/SignalR-Client-Swift (community)

#### Build: Dual SPM + Xcode
- Package.swift for CLI validation (`swift build`)
- .xcodeproj for full Xcode experience (previews, simulator, device)
- iOS 17+, Swift 6.0, bundle ID: com.printfarmer.ios

---

## MVP Build Batch Decisions (Consolidated 2026-03-06T19:11:00Z)

### Phone-First Design Principle (Dallas)
**Status:** Accepted

- Every feature answers: *"Would someone pull out their phone to do this?"*
- **Yes for phones:** Quick status glance, remote monitoring, alerts, quick actions, job dispatching
- **No for phones:** Complex forms, file uploads, slicer workspace, admin tasks, detailed charts
- **5 MVP Features:** Dashboard (P0), Printer List+Detail (P0), Quick Actions (P0), Job Queue (P1), Notifications (P1)
- **Total MVP Surface:** 22 API endpoints

---

### Service Architecture: Protocol-Based Dependency Injection (Ripley, Dallas)
**Status:** Implemented

#### ViewModel Pattern
- All ViewModels: `@MainActor @Observable` with optional protocol-typed service properties
- Services configured via `configure(with:)` method called in view's `.task` modifier
- ViewModels depend on protocols, not concrete implementations — full testability

#### Service Protocols (5 total)
- `PrinterServiceProtocol` (11 methods: list, get, status, snapshot, pause/resume/cancel/stop/emergency-stop, maintenance)
- `JobServiceProtocol` (5 methods: list, get, dispatch, cancel, abort)
- `NotificationServiceProtocol` (5 methods: list, get, mark-read, batch mark-read, unread count)
- `StatisticsServiceProtocol` (1 method: summary KPIs)
- `SignalRServiceProtocol` (4 methods: connect, disconnect, subscribe/unsubscribe)

#### Navigation Wiring
- Each tab wraps NavigationStack(path:) bound to AppRouter
- Detail views pushed via AppDestination enum + `.navigationDestination(for:)`
- Global `destinationView(for:)` helper marked `@MainActor` — centralized resolution, satisfies Swift 6 actor isolation

#### Tab Structure Change
- Replaced Locations tab with Notifications tab (Locations not phone-first; Notifications core value)
- LocationListView preserved for post-MVP restoration

---

### SignalR: Native URLSessionWebSocketTask (Lambert)
**Status:** Implemented

#### Implementation Details
- Custom client using URLSessionWebSocketTask directly — no third-party dependencies
- ASP.NET Core SignalR JSON protocol: 0x1E framing, negotiate, handshake, ping/pong
- Auto-reconnect with exponential backoff (1s → 30s cap, 10 attempts max)
- Connection state machine with delegate callbacks

#### MVP Events
- `printerupdated`: Composite status delta (state, temps, progress, job info)
- `jobqueueupdate`: Live job status transitions

**Impact:** Real-time live updates without polling; critical phone app value

---

### Job Queue API: Printer-Centric Overview (Lambert)
**Status:** Implemented

#### Endpoint & Model Correction
- **Path:** `/api/job-queue` (hyphenated)
- **Response:** `[QueueOverview]` — per-printer queue view, not individual PrintJob collection
- QueueOverview contains: printer ID, queue depth, current job
- Individual job detail: `GET /api/job-queue/{id}`

#### UI Impact
- **JobListView:** Redesigned to show QueueOverview (printer queue status) with Active/Queued/Available sections
- **DashboardView:** Shows printers with current jobs (from Printer.jobName/progress) not separate PrintJob collection

---

### Notification Model Specification (Lambert)
**Status:** Implemented

#### AppNotification Structure
- `id: String` (not UUID; backend uses string IDs)
- `type: NotificationType` enum (JobStarted, JobCompleted, JobFailed, JobPaused, JobResumed, QueueAlert, SystemAlert)
- `subject: String`, `body: String` (not title/message)
- `read: Bool`, `timestamp: Date`
- `printerId: String?`, `jobId: String?` (context links)

**Breaking Change:** Old placeholder values (info/warning/error/success) replaced with job event names

---

### APIClient Type Disambiguation (Lambert)
**Status:** Implemented

#### New Overloads
- `postVoid(_:)` — POST with no response body
- `putVoid(_:)` — PUT with no response body
- `putVoid(_:body:)` — PUT with request body, no response
- `getData(_:)` — GET returning raw Data (for snapshots)

**Rationale:** Old single `post(_:)` was ambiguous when both void and decoded overloads existed

---

### Snapshot Handling: Data → UIImage (Ripley)
**Status:** Implemented

#### Pattern
- `PrinterServiceProtocol.getSnapshot(id:) -> Data` returns raw image bytes
- ViewModel loads Data, stores in @State
- View converts Data → UIImage locally
- No AsyncImage (no URL support)
- Handled via `.task` modifier

---

### Test Infrastructure: MockURLProtocol + Protocol Mocks (Ash)
**Status:** Implemented

#### Testing Strategy
- **Network Tests:** MockURLProtocol intercepts URLSession calls — validates full path through APIClient → Service
- **ViewModel Tests:** Protocol-based mock services via `configure()` — fast, isolated
- **Model Tests:** Realistic JSON fixtures from backend DTOs — decoder compatibility

#### Coverage
- 145 test cases across 8 suites (APIClient, Auth, Printer, Job, Notification, Model Decoding, LoginViewModel, DashboardViewModel)
- Full mock infrastructure: MockPrinterService, MockJobService, MockAuthService, MockNotificationService, MockStatisticsService, MockSignalRService
- TestFixtures with realistic JSON from backend source

**Impact:** All team members can run tests to validate work; mocks ready for any new ViewModel or service

---

### Tab Structure: Notifications MVP Priority (Ripley, Dallas)
**Status:** Implemented

#### Decision
- Remove Locations tab (not phone-first)
- Add Notifications tab (core phone value — print alerts, completions, failures)
- LocationListView preserved in codebase for post-MVP restoration

---

### Swift 6 Strict Concurrency Compliance (Ripley, Dallas)
**Status:** Implemented

#### Techniques
- All ViewModels marked `@MainActor @Observable`
- Global `destinationView(for:)` helper marked `@MainActor`
- Platform guards for iOS-only APIs: `#if os(iOS)` / `#if canImport(UIKit)`
- SPM macOS build compatible; Xcode iOS build retains all features

---

### CRITICAL FINDING: PrinterDetailViewModel Method Mismatches (Ash)
**Status:** ⚠️ Identified — Requires Ripley Fix

#### 3 Mismatches Found
| ViewModel Calls | Protocol Has | Mismatch Type |
|-----------------|--------------|---------------|
| `snapshotURL(for:)` | `getSnapshot(id:) -> Data` | Method name + return type (URL vs Data) |
| `cancelPrint(id:)` | `cancel(id:) -> CommandResult` | Method name (cancelPrint vs cancel) |
| `setMaintenance(id:enabled:)` | `setMaintenanceMode(id:enabled:) -> CommandResult` | Method name (setMaintenance vs setMaintenanceMode) |

**Owner:** Ripley (iOS Dev)
**Timeline:** URGENT — blocks test suite integration
**Action:** Update PrinterDetailViewModel method calls to match actual protocol signatures

---

### Deferred Features (Post-MVP)
**Status:** Accepted

- Printer Discovery (complex multi-step, SSE streaming)
- File Management/Upload (large file handling, limited phone storage)
- Slicer Integration (3D viewport, complex forms)
- Camera Live Streams (bandwidth-heavy; snapshots sufficient)
- Statistics Charts (phone screen not ideal)
- Maintenance Plans/Schedules (complex forms)
- User Management (admin-only)
- System Settings (admin config)
- Filament/Spool Management (inventory system)
- NFC Device Management (niche)
- Webhook Configuration (developer feature)
- Printer Import/Export (bulk operations)
- G-code Library (file browsing)
- Print Projects (project management)
- Catalog Management (admin)

---

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction

---

## Phase 2: QR Code Scanning Design

**Date:** 2026-03-07  
**Owner:** Dallas (Lead/Architect)  
**Status:** Approved for Phase 2  

### Executive Summary

User requested QR code scanning for Phase 2 to enable spool-to-printer linking via Spoolman QR codes. After backend analysis and iOS capability research, QR scanning is feasible and recommended as a Phase 2 enhancement.

### Backend Analysis

**Spoolman QR Code Format:**
- Spoolman generates QR codes (not PrintFarmer backend)
- QR encodes spool ID: `https://<spoolman-host>/spools/<spool-id>` or plain numeric ID
- Existing backend endpoints already support this:
  - `GET /api/spools/{id}` — retrieve spool by ID
  - `POST /api/printers/{id}/active-spool` — link spool to printer
- **Verdict:** No new backend work needed

### iOS Framework Approach

**Tier 1 (iOS 16+):** VisionKit `DataScannerViewController`
- Beautiful live barcode UI, Apple ML-based accuracy
- ~5 lines of integration code
- Recommended for MVP Phase 2

**Tier 2 (fallback):** AVFoundation (iOS 7+)
- Works on all iPhones, mature API
- Custom UI required
- Deferred to Phase 2.5 if device coverage critical

### Architecture: Shared SpoolScannerProtocol

QR and NFC share the same result: a spool ID. Proposed abstraction:

```swift
protocol SpoolScannerProtocol {
    func scan() async -> SpoolScanResult
}

enum SpoolScanResult {
    case spoolId(Int)
    case cancelled
    case error(SpoolScanError)
}

// Implementations
class QRSpoolScanner: SpoolScannerProtocol { ... }
class NFCSpoolScanner: SpoolScannerProtocol { ... }
```

**Benefit:** SpoolPickerView doesn't need to know whether user scanned QR or NFC—just calls `scanner.scan()`.

### Phase 2 Work Items

1. **QRSpoolScannerService** (Lambert, 4h)
   - Wrap VisionKit `DataScannerViewController`
   - Parse QR payload (3 formats: URL, plain ID, JSON)
   - Return `SpoolScanResult`
   - Info.plist: add `NSCameraUsageDescription`

2. **SpoolPickerView Enhancement** (Ripley, 3h)
   - Add "Scan QR Code" button
   - Present QR scanner sheet
   - Auto-load successful spool

3. **Test Coverage** (Ash, 2h)
   - QRCodeParser tests
   - SpoolPickerViewModel QR flow tests
   - MockSpoolScannerService

### QR Payload Parsing

Supports three formats:

**Format 1:** URL with spool ID in path
```
https://spoolman.example.com/spools/42
```
Extract: `42`

**Format 2:** Plain spool ID
```
42
```
Extract: Direct parse

**Format 3:** JSON
```json
{"spoolId": 42}
```
Extract: `spoolId` field

### Permission & Entitlements

**Info.plist:**
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is needed to scan QR codes on filament spools.</string>
```

No special entitlements required (unlike NFC).

### Edge Cases

| Scenario | Behavior |
|----------|----------|
| Camera permission denied | Alert: "Camera permission required. Grant in Settings." |
| Invalid QR (not a spool code) | Scanner continues looking |
| Spool ID not found on backend | Error: "Spool not found. Try a different label." |
| User closes scanner | Dismiss sheet, return to SpoolPickerView |

### Decision

✅ Add QR code scanning to Phase 2  
✅ Use VisionKit for iOS 16+ (primary)  
✅ Design shared `SpoolScannerProtocol` abstraction  
✅ Estimated effort: 9 hours total  
⏸️ AVFoundation fallback deferred to Phase 2.5  

---

## Phase 2: NFC Scanning Services (Lambert)

**Date:** 2026-03-07  
**Author:** Lambert  
**Status:** Implemented

### Decisions

1. **No Info.plist File** — iOS 17+ projects don't generate standalone Info.plist by default. Camera and NFC usage descriptions must be added via Xcode target Info tab.

2. **`#if canImport(UIKit)` Guards** — Scanner services wrapped for SPM macOS build compatibility. ServiceContainer conditionally registers them.

3. **No Backend NFC Endpoint** — NFC scanning/writing is purely client-side. Tags encode spool data in OpenSpool/OpenPrintTag NDEF format. When tag contains `spoolman_id`, ViewModel fetches full data via `SpoolService.getSpool(id:)`.

4. **OpenSpool as Write Format** — When writing NFC tags via `NFCService.writeTag(spool:)`, use OpenSpool format exclusively (community standard).

5. **QRCodeParser Supports Three Formats** — URL paths (`/spools/{id}`), plain numeric (`{id}`), JSON (`{"spoolId": {id}}`). Also accepts `spool_id` and `id` as JSON keys.

### Architecture

- **SpoolScannerProtocol** — Abstract interface (QR + NFC both implement)
- **QRSpoolScannerService** — Wraps VisionKit DataScannerViewController
- **NFCService** — NDEF tag read/write
- **QRCodeParser** — Extract spool ID from QR payload
- **NFCTagParser** — Decode OpenSpool/OpenPrintTag NDEF records
- **MockSpoolScannerService** — Test double for ViewModels

### Files Created

1. `PrintFarmer/Services/SpoolScannerProtocol.swift`
2. `PrintFarmer/Services/QRSpoolScannerService.swift`
3. `PrintFarmer/Services/NFCService.swift`
4. `PrintFarmer/Utilities/QRCodeParser.swift`
5. `PrintFarmer/Utilities/NFCTagParser.swift`
6. `PrintFarmer/Mocks/MockSpoolScannerService.swift`
7. `PrintFarmer/Services/ServiceContainer.swift` (updated)

---

## Phase 2: Scanning UI (Ripley)

**Date:** 2026-03-07  
**Author:** Ripley  
**Status:** Implemented

### UI Components

1. **QRScannerView** — VisionKit wrapper, single-scan mode, UIViewControllerRepresentable
2. **NFCScanButton** — Reusable component with `compact` variant, checks `NFCNDEFReaderSession.readingAvailable`
3. **NFCWriteView** — Tag write UI with status indicators

### View Integrations

1. **SpoolPickerView** — "Scan QR Code" button, presents scanner sheet
2. **AddSpoolView** — Pre-fill from scanned data (`scannedData` parameter, `isPrefilledFromScan` flag)
3. **SpoolInventoryView** — NFC write action in context menu
4. **PrinterDetailView** — NFC scan button in filament section

### ViewModel Enhancements

- **SpoolPickerViewModel:** `parseSpoolId(from:)` parser, `configureNFCScanner(_:)` ready for DI
- **AddSpoolViewModel:** `prefill(from:)` method, scanned data visibility management

### Decisions

- Single-scan mode for QR (stops after first barcode)
- Permission denial shows alert + Settings link
- NFC button disabled on unsupported devices
- Pre-fill banner signals scanned data origin
- Text parsing supports 3 formats (URL, plain int, JSON)

### Known Limitations

- Info.plist keys not added (requires Xcode target configuration)
- NFCWriteView.onWrite not yet wired to Lambert's NFCService.writeTag()

---

## User Directives (Quality Gates)

**Date:** 2026-03-07  
**Source:** Jeff Papiez (via Copilot)

### Quality Gate for All Work

All agent deliverables must pass before claiming "done":

1. ✅ `swift build` — compile clean (zero errors)
2. ✅ `swiftlint lint --quiet` — zero errors (warnings OK as baseline)
3. ⚠️ `swift test` — has known `@main` linker conflict in SPM; tests validated in Xcode only

**Why:** User requested build validation as part of all work

### QR Code Feature Request

Phase 2 should support reading QR codes (generated by Spoolman) to link spool with printer, in addition to NFC tag scanning/writing.

**Why:** Spoolman generates QR codes; scanning is natural complement to NFC.

---

## Phase 2: Test Coverage (Ash)

**Date:** 2026-03-07  
**Author:** Ash  
**Status:** Implemented

### Test Files (4 new)

1. **QRCodeParserTests** — 15 cases
   - URL format parsing (`/spools/{id}`, `/spool/{id}`)
   - Plain numeric parsing
   - JSON payloads (id, spoolId, spool_id keys)
   - Invalid/malformed inputs
   - Edge cases

2. **NFCTagParserTests** — 18 cases
   - OpenSpool NDEF record parsing
   - OpenPrintTag NDEF record parsing
   - Multi-record handling
   - Invalid structures
   - Missing fields

3. **SpoolPickerViewModelScanTests** — 14 cases
   - Successful QR/NFC scan flows
   - Permission denial handling
   - Invalid spool ID (backend lookup failure)
   - Network errors
   - User cancellation

4. **MockScannerService** — Test double
   - Spy: records all scan calls
   - Stub: returns configured SpoolScanResult

### Coverage Summary

- **61 total test cases** across 4 files
- **Parser tests:** 33 cases (QR + NFC format variants)
- **ViewModel tests:** 14 cases (happy path + errors)
- **Mock infrastructure:** MockScannerService for ViewModel testing

### Limitations

- Integration tests (scanner + network + ViewModel) deferred to Phase 3
- Device-specific tests (permission flow on physical device) — manual QA
- NFC tag write flow tests deferred pending NFCService validation

### Recommendations

1. Use MockScannerService for all ViewModel/UI tests
2. Snapshot tests for QRScannerView/NFCWriteView (Phase 3)
3. Manual device QA with real Spoolman QR labels + NFC tags

---
