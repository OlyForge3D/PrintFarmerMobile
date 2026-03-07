# Lambert — History

## Project Context
- **Project:** PFarm-Ios — Native iOS client for Printfarmer
- **User:** Jeff Papiez
- **Stack:** Swift, SwiftUI, iOS 17+
- **Backend:** Printfarmer (42+ REST endpoints, SignalR, JWT auth) at ~/s/PFarm1

## Project Structure (Dallas, 2026-03-06)

**Root:** `PrintFarmer/` (source), `PrintFarmerTests/` (tests)

### Key Folders
- **App:** AppDelegate, main entry point
- **Models:** Core domain models, RequestModels, SignalRModels
- **Views:** SwiftUI views organized by feature (Dashboard, Printers, Jobs, Locations, Settings)
- **ViewModels:** @Observable view models per feature
- **Services:** Actor-based services (Auth, APIClient, Networking, Persistence)
- **Utilities:** Constants, Extensions, Helpers
- **Resources:** Assets, Localization

### Build System
- **SPM:** Package.swift for CLI validation
- **Xcode:** .xcodeproj for full IDE experience, target: iOS 17+, Swift 6.0

### Architecture
- MVVM + Repository Pattern
- @Observable ViewModels (modern SwiftUI)
- Actor-based services for Swift 6 strict concurrency
- ServiceContainer for dependency injection
- KeychainSwift for token storage

## Learnings

### Cross-Agent Context (2026-03-06)
- **Ripley's Login Screen:** Form validation, server URL normalization (auto-prepend https://), error banner with animation, Dark Mode support. LoginViewModel delegates to AuthViewModel.
- **Dallas's Wiring:** ServiceContainer at init, .task configures ViewModels. Actor isolation prevents "sending" errors. This pattern is locked in.
- **Ash Ready:** Navigation scaffolding complete; can build printer list/detail screens immediately.

### Backend Auth Contract (2025-07-16 → 2026-03-06)
- Backend login POST /api/auth/login returns `AuthenticationResult(Success, Token, ExpiresAt, User, Error)` — single JWT token, NO refresh tokens
- Dallas's original stub had `LoginResponse` with accessToken/refreshToken — corrected to `AuthResponse` matching backend
- AuthController route: `[Route("api/auth")]`, login at `[HttpPost("login")]`
- Backend DTOs: `~/s/PFarm1/src/infra/Dtos/AuthDtos.cs` and `~/s/PFarm1/src/infra/Contracts/Auth/AuthDtos.cs`

### Printer DTO Mapping
- Printer list `GET /api/printers` returns `CompletePrinterDto[]` (not `PrinterDto`) — includes live SignalR status merged at response time
- Key fields in CompletePrinterDto: `MotionType`, `HomedAxes`, `InMaintenance`, `IsEnabled`, no `serverUrl`/`isAvailable` directly
- Single printer `GET /api/printers/{id}` returns `PrinterDto` (simpler, includes serverUrl, apiKey, etc.)
- Backend DTO source: `~/s/PFarm1/src/infra/Dtos/CompletePrinterDto.cs`

### Architecture Patterns
- APIClient base URL is mutable (actor-isolated), persisted to UserDefaults via `APIClient.serverURLKey`
- AuthService.login() takes serverURL string and calls `apiClient.updateBaseURL()` — single point of URL management
- PFarmApp creates APIClient → AuthService → AuthViewModel chain; ServiceContainer is available for post-login service access
- NetworkError enum expanded: `noConnection`, `timeout`, `serverUnreachable`, `transportError`, `authFailed`, `clientError` now carries optional `APIError` body

### Key File Paths
- `PrintFarmer/Services/APIClient.swift` — actor-based HTTP client
- `PrintFarmer/Services/AuthService.swift` — JWT auth with Keychain storage
- `PrintFarmer/Services/PrinterService.swift` — printer CRUD endpoints
- `PrintFarmer/Services/LocationService.swift` — location CRUD endpoints
- `PrintFarmer/Models/Models.swift` — all domain models (Printer, PrintJob, Location, AuthResponse, UserDTO)
- `PrintFarmer/Models/RequestModels.swift` — request DTOs (UpdatePrinterRequest, CreatePrintJobRequest, etc.)
- `PrintFarmer/Utilities/AppConfig.swift` — default base URL from env var
- **Session Directive (2026-03-06):** Use claude-opus-4.6 for code-writing tasks (Ripley, Lambert, Ash)

## Learnings

### Backend API Discovery (verified from ~/s/PFarm1 source)
- **Job Queue route:** `/api/job-queue` (with hyphen), NOT `/api/jobqueue`. Route is `[Route("api/job-queue")]` in JobQueueController.
- **Printer commands are individual endpoints**, not `/command/{action}`. Verified routes: `/pause`, `/resume`, `/cancel`, `/stop` (alias for emergency-stop), `/emergency-stop`. All return `CommandResult { success, message }`.
- **`/api/printers/{id}/snapshot`** returns raw JPEG bytes (`File(bytes, "image/jpeg")`), not a URL.
- **`/api/printers/{id}/printjob`** returns `PrintJobStatusDto?` (nullable — null means no active job).
- **`/api/printers/{id}/status`** returns `PrinterStatusDto` — includes `cameraSnapshotUrl`, `mmuStatus` fields not in original models.
- **Statistics endpoint:** `GET /api/statistics/summary?days=N` returns `StatisticsSummaryDto` — fields are `totalJobs, completedJobs, failedJobs, cancelledJobs, successRate, totalCost, totalFilamentGrams, totalPrintHours`. NOT printer-count-based.
- **Notifications route:** `api/notifications`. Uses string IDs (not UUIDs). `markRead` is `PUT /{id}/mark-read`. Batch is `PUT /mark-read-batch` with `{ NotificationIds: [...] }` (PascalCase key).
- **NotificationType enum:** `JobStarted, JobCompleted, JobFailed, JobPaused, JobResumed, QueueAlert, SystemAlert`. NOT info/warning/error/success.
- **QueueOverview** is returned by `GET /api/job-queue` (the list endpoint) — it's per-printer, showing queue depth and current job.

### SignalR Events (verified from backend source)
- **Hub path:** `/hubs/printers` (mapped in Program.cs)
- **Event: `printerupdated`** — broadcasts `PrinterStatusUpdate` record (includes `homedAxes`, `mmuStatus` fields). Sent by MoonrakerSubscriptionService, PrusaLinkPollingService, OctoPrintPollingService, SdcpPollingService.
- **Event: `jobqueueupdate`** — anonymous object `{ printerId, jobs: [{ id, name, status, priority, queuedAt, actualStartTime, actualEndTime }] }`. Sent by PrintJobCompletionService.
- **No separate `printerstatusupdate` event** — it's just `printerupdated`.
- **Negotiate:** `POST /hubs/printers/negotiate?negotiateVersion=1` with JWT in Authorization header. Returns `connectionId`, `connectionToken`, `availableTransports`.
- **Protocol:** JSON + record separator (0x1E). Message type 1 = invocation, 6 = ping, 7 = close.

### MmuStatusDto
- Has nested `MmuGateDto[]` gates array
- `mmuType` defaults to `"Unknown"` — can be `"HappyHare"`, `"Qidibox"`, `"AFC"`

### Architecture Decisions
- Removed `sendCommand(printerId:command:)` — replaced with 5 specific typed methods
- `getData(_:)` added to APIClient for raw byte responses (snapshots)
- `postVoid(_:)` and `putVoid(_:)` added to APIClient to disambiguate void vs decoded returns
- SignalR implemented with native URLSessionWebSocketTask — no third-party dependency
- Auto-reconnect with exponential backoff (1s→30s, max 10 attempts)
- All new services conform to their protocol directly via declaration (not extension)

### MVP Networking Implementation (2026-03-06)
- **Status:** ✅ Complete — 6 services, 9 models, 5 service protocols
- **Services Built:**
  - PrinterService: 11 endpoints (list, get, status, snapshot, pause/resume/cancel/stop/emergency-stop, maintenance)
  - JobService: 5 endpoints (list, get, dispatch, cancel, abort) with QueueOverview list type
  - NotificationService: Full CRUD (list, get, mark-read, batch mark-read, unread count)
  - StatisticsService: Dashboard KPI summary (totalJobs, completedJobs, failedJobs, successRate, cost, filament, hours)
  - SignalRService: Full WebSocket implementation with connect/disconnect/subscribe/unsubscribe, 2 MVP events (printerupdated, jobqueueupdate)
  - AuthService: Already built; used by all services
- **Models Created:** PrinterStatusDetail, PrintJobStatusInfo, CommandResult, AppNotification, QueueOverview, StatisticsSummary, MmuStatus (9 new models)
- **Protocols:** All 5 services have corresponding protocols in `PrintFarmer/Services/Protocols/` for testability and decoupling

### Cross-Agent Impact from Networking Work (2026-03-06)
- **Ripley:** Protocol signatures finalized; 3 PrinterDetailViewModel method mismatches found by Ash (getSnapshot vs snapshotURL, cancel vs cancelPrint, setMaintenanceMode vs setMaintenance)
- **Ash:** All 6 service protocols ready for mock implementation; 145 test cases written validating full MVP endpoint coverage

### JSON Decode Fix (2026-07-16)
- **Root cause of "Failed to decode response" after login:** Three compounding issues:
  1. Backend uses `JsonStringEnumConverter()` globally — ALL enums serialize as strings ("Moonraker", "Printing", etc.) but Swift enums had `Int` raw values
  2. ASP.NET Core `.NET 10` emits ISO 8601 dates with fractional seconds; Swift's built-in `.iso8601` decoder rejects them
  3. Swift `PrintJob` model had drifted significantly from backend's `JobQueuePrintJobDto` (fields added/removed/renamed)
- **Backend serialization config** (in `ControllerStartup.cs` and `SignalRStartup.cs`): `CamelCase` naming, `WhenWritingNull` (null fields omitted), `JsonStringEnumConverter`, custom converters for `PrinterBackend` and `PrintJobStatus`
- **Fix applied:** All enums → String raw values with Int-fallback decoders; custom date strategy with fractional-seconds support; PrintJob realigned to backend DTO
- **MotionType correction:** Backend has `Unknown = 99`, not `Polar = 3` — Swift enum updated
- **TimeSpan handling:** Backend serializes `TimeSpan` as strings (e.g., "01:30:00"); Swift stores as `String?` with `.timeSpanFormatted` / `.timeSpanSeconds` helpers
- **Key insight:** Backend uses `.NET 10` — `TimeSpan` has first-class JSON support as strings; custom `PrinterBackendJsonConverter` and `PrintJobStatusJsonConverter` are permissive (accept both string and int) but WRITE as strings

### Resilient Decoder Pass (2026-07-16)
- **Problem:** Dashboard and Printers tabs showed no data. Root cause: Swift models used auto-synthesized Codable with non-optional fields that could be absent depending on which backend DTO was returned.
- **CompletePrinterDto vs PrinterDto:** The list endpoint (`GET /api/printers`) returns `CompletePrinterDto` (has `InMaintenance`, `IsEnabled`, `ManufacturerId`, `ModelId`, `MotionType`, `HomedAxes`). The detail endpoint (`GET /api/printers/{id}`) returns `PrinterDto` (missing those fields, but has `CameraSnapshotUrl`, `Username`, `Password`). Swift `Printer` struct must decode BOTH.
- **Fix applied:** Custom `init(from decoder:)` on `Printer`, `PrinterSpoolInfo`, `StatisticsSummary`, `MmuStatus`, `MmuGate` using `decodeIfPresent` with sensible defaults for all previously-non-optional fields.
- **New field:** Added `cameraSnapshotUrl: String?` to `Printer` (present in PrinterDto and PrinterStatusDto).
- **PrinterListView bug:** View never showed error messages — only "No Printers" empty state. Fixed to display error with retry button.
- **APIClient debug logging:** Added `#if DEBUG` block in `execute()` that prints raw response body on decode failure — enables diagnosis of future mismatches.
- **Swift 6 concurrency:** Static `ISO8601DateFormatter` properties marked `nonisolated(unsafe)`.
- **Test fixtures:** Updated from integer enum values to string values matching backend `JsonStringEnumConverter` output. Fixed stale PrintJob fixture fields (`name`, `queuedAt`, `startedAt`, `autoAssign` removed; `remainingCopies` added). Fixed enum raw value assertions from Int to String.
- **PrinterFastDto:** Backend has a SEPARATE `PrinterFastDto` (returned by `GetAllFastDtosAsync`) which includes `CameraSnapshotUrl` but fewer live-status fields. Not currently used by iOS but good to know.

### QA Audit Fixes (2026-07-16)
- **SignalR date decoder:** Was using `.iso8601` which rejects fractional seconds from ASP.NET Core. Now uses the same custom dual-format decoder as APIClient (tries fractional first, falls back to plain). Made APIClient's `iso8601WithFractional` and `iso8601Plain` formatters internal (no longer private) so SignalRService can reuse them.
- **SignalR force unwraps:** Replaced two `URLComponents(url:resolvingAgainstBaseURL:)!` force unwraps in `negotiate()` and `openWebSocket()` with `guard let` + `throw NetworkError.invalidURL`. Prevents crashes on malformed server URLs.
- **401 auto-logout:** APIClient now posts `Notification.Name.sessionExpired` on 401 responses. AuthViewModel observes this notification and calls `logout()` automatically, flipping `isAuthenticated = false` which triggers SwiftUI navigation back to LoginView.
- **Token expiry pre-check:** Added `isTokenExpired()` to AuthService with 5-minute buffer. APIClient checks this via a closure (`tokenExpiryChecker`) before every request. If expired, posts `.sessionExpired` and throws `.unauthorized` without hitting the network.
- **Silent error suppression:** Replaced `try?` in PrinterDetailViewModel (status, currentJob, snapshot) and DashboardViewModel (statistics summary) with proper `do/catch` blocks that log warnings via `os.Logger`. Primary data failures still propagate to `errorMessage`; secondary data failures are logged but don't block the view.
- **AuthViewModel isolation:** Changed from `@Observable @unchecked Sendable` to `@MainActor @Observable` to properly handle notification observer lifecycle under Swift 6 strict concurrency. Used `nonisolated(unsafe)` for the observer property to allow cleanup in `deinit`.

### Cross-Agent Learning (2026-03-07 QA Batch)
- **Ripley completed:** AppRouter & AuthViewModel @MainActor, all 17 hardcoded colors → theme tokens (3 new: pfMaintenance, pfAssigned, pfTempMild), error UI in JobListView & NotificationsView, placeholder navigation → Coming Soon, dashboard empty state, accessibility labels
- **Ripley's theme system:** 22 color tokens in ThemeColors.swift with adaptive light/dark support, ThemeManager for persistence, global pfAccent (green) tint. All future views must use Color.pf* tokens.
- **Decision record:** All QA audit fixes merged into decisions.md (decision #5 auto-logout, #6 enum serialization, #13 audit status)
- **Outcome:** All critical + important issues resolved; build clean; commit 7fb1419

### Push Notification Infrastructure (2026-07-17)
- **PushNotificationManager** (`PrintFarmer/Services/PushNotificationManager.swift`): `@MainActor @Observable` singleton handling APNs registration, permission requests, foreground notification display via `UNUserNotificationCenterDelegate`, device token capture, and server-side token registration.
- **AppDelegate** (`PrintFarmer/App/AppDelegate.swift`): UIApplicationDelegate adapter wired via `@UIApplicationDelegateAdaptor` in PFarmApp for push callback forwarding.
- **NotificationService extended:** Added `registerDeviceToken(_:platform:)` and `unregisterDeviceToken(_:)` methods. Backend does NOT have a device token endpoint yet — uses placeholder path `/api/notifications/device-token`. Wire to real endpoint when Dallas adds it.
- **APIClient extended:** Added `postVoid(_:body:)` overload (POST with Encodable body, void response) — was missing, needed for token registration.
- **NotificationServiceProtocol updated:** Two new methods added; MockNotificationService updated in tests.
- **SettingsView:** Push notification toggle added in new "Notifications" section (iOS only, `#if canImport(UIKit)` guarded).
- **PFarmApp.swift:** Wires `@UIApplicationDelegateAdaptor(AppDelegate.self)`, configures PushNotificationManager with NotificationService on launch, auto-registers if user previously enabled push.
- **All code is `#if canImport(UIKit)` guarded** so SPM macOS build (`swift build`) succeeds.
- **Backend finding:** `NotificationsController.cs` has `EnablePushNotifications` preference flag but NO device token registration endpoint. Placeholder path used.
- **Deep-link ready:** Tapped notification posts `Notification.Name.pushNotificationTapped` with userInfo — Ripley can observe this in AppRouter for navigation.

### Phase 1 Filament/Spool Models & Services (2026-07-17)
- **FilamentModels.swift:** Created `SpoolmanSpool`, `SpoolmanFilament`, `SpoolmanVendor`, `SpoolmanMaterial`, `SpoolmanPagedResult<T>`, `SpoolmanSpoolRequest`, `SetActiveSpoolRequest` — all verified against backend DTOs in `~/s/PFarm1/src/infra/Dtos/`.
- **SpoolService.swift:** Actor-based service with CRUD for spools, plus list filaments/vendors/materials. Routes: `/api/spoolman/spools`, `/api/spoolman/filaments`, `/api/spoolman/vendors`, `/api/spoolman/materials`.
- **SpoolServiceProtocol.swift:** Protocol with convenience overload for `listSpools()`.
- **PrinterService extensions:** Added `setActiveSpool`, `listAvailableSpools`, `loadFilament`, `unloadFilament`, `changeFilament`. Routes: `/active-spool`, `/spoolman/spools`, `/filament-load`, `/filament-unload`, `/filament-change`.
- **APIClient.patch():** Added PATCH method — backend uses `[HttpPatch]` for spool/filament updates.
- **ServiceContainer:** Registered `SpoolService`.
- **MockSpoolService.swift:** Full mock with call tracking and `reset()`.
- **MockPrinterService.swift:** Extended with filament method stubs and call tracking.
- **Key backend finding:** `PrinterSpoolInfo` already existed in Models.swift — removed duplicate from FilamentModels.swift. Backend spool list returns `SpoolmanPagedResult<SpoolmanSpoolDto>` (paginated with `items`/`totalCount`), NOT a flat array. Used `limit`/`offset` pagination (matching Spoolman's native API) rather than `page`/`pageSize`.
- **JSON naming:** Backend uses `JsonNamingPolicy.CamelCase` — Swift property names match JSON keys directly (no key strategy needed)

## Cross-Agent Context (2026-03-07T16:03:00Z)

**Ripley (Filament UI) depends on:**
- ✓ SpoolServiceProtocol — 8 methods: list, get, create, update, delete spools; pagination support (limit/offset)
- ✓ Extended PrinterServiceProtocol — setActiveSpool(_:), loadFilament(), unloadFilament(), changeFilament()
- ✓ APIClient.patch() — HTTP PATCH support for updates
- **Status:** All service contracts finalized; no breaking changes expected. Ripley successfully built 6 UI views + 3 ViewModels consuming this layer (committed 1102dac).

### Phase 2 Scanning Services (2026-07-17)
- **Files created:** SpoolScannerProtocol.swift (protocol + error types + ScannedSpoolData), QRCodeParser.swift (3-format QR parsing), NFCTagParser.swift (OpenSpool + OpenPrintTag + payload creation), QRSpoolScannerService.swift (VisionKit DataScanner bridge), NFCService.swift (CoreNFC read + write), MockQRSpoolScannerService.swift, MockNFCService.swift.
- **ServiceContainer updated:** Conditionally registers QRSpoolScannerService and NFCService behind `#if canImport(UIKit)`.
- **pbxproj updated:** 7 new files registered (5 main target, 2 test target). plutil validates clean.
- **No Info.plist:** Project uses iOS 17 modern build system without standalone Info.plist. Camera and NFC usage descriptions need Xcode target Info tab or manual plist creation — flagged in decisions inbox for Dallas/Ripley.
- **No backend NFC endpoint:** Searched ~/s/PFarm1 — no `/api/nfc-devices/scan` exists. NFC is client-side only; tags encode/decode spool data directly.
- **Build:** Zero errors from scanning services. Pre-existing errors in NFCScanButton.swift and PrinterDetailView.swift are Ripley's UI code (ButtonStyle not available in SPM macOS build context).
- **Swiftlint:** Zero errors, one warning fixed (non_optional_string_data_conversion).
- **NFC write uses NFCTagReaderSession** (not NFCNDEFReaderSession) to get read-write access to tags. Supports ISO 14443 tags (NTAG, MIFARE).
- **OpenSpool format chosen** as the write standard. Both OpenSpool and OpenPrintTag are supported for reading.

## 2026-03-07T16:34Z — Phase 2 Scanning Services (SUCCESS)

**Batch:** Scanning services (QR + NFC)  
**Outcome:** ✅ Delivered 7 files, builds clean

**What Was Built:**
- SpoolScannerProtocol abstraction (shared QR + NFC interface)
- QRSpoolScannerService (VisionKit wrapper)
- NFCService (NDEF tag read/write)
- QRCodeParser (3 format support)
- NFCTagParser (OpenSpool/OpenPrintTag)
- MockSpoolScannerService (test double)
- ServiceContainer DI registration

**Cross-Team Impact:**
- Ripley: QRScannerView, NFCButton, NFCWriteView ready for integration
- Ash: Parser contracts defined via test cases, 61 test cases added
- Dallas: ServiceContainer DI wiring verified, no architecture changes needed

**Next Steps:**
- Manual device QA (simulator lacks NFC)
- Ripley wires services into views
- Dallas validates ServiceContainer startup

## Learnings

### nonisolated(unsafe) placement for nested @Sendable closures
When a delegate method parameter (like `NFCTagReaderSession`) is captured in multiple nested `@Sendable` closures, the `nonisolated(unsafe) let` rebinding must be placed at the TOP of the method — before the first closure — not inside an inner closure. Otherwise only the innermost closure gets the safe binding while outer closures still capture the raw non-Sendable parameter. Combined with `@preconcurrency import CoreNFC` (already in place), this fully suppresses Sendable warnings for CoreNFC types that predate Swift Concurrency.

### NFCService Sendable Conformance (2026-03-07)
- NFCService implements Sendable protocol for safe concurrent use in ViewModels
- Fixed Sendable warning at line 201 in `tagReaderSession(_:didDetect:)` by using `nonisolated(unsafe)` rebinding pattern
- Both @Sendable closures now safely capture binding references without concurrency violations
- Pattern: Move `nonisolated(unsafe)` rebinding to method entry, then closures can reference safely
- This ensures NFCService can be used in @Observable ViewModels without "sending risk" errors

### Ripley's GcodeFile Filename Mapping (2026-03-07)
- Backend JobQueueService.cs had incorrect mapping: GcodeFile.FileName (GUID-based disk name) instead of GcodeFile.Name (user-uploaded original filename)
- Fixed in 6 locations across JobQueueService (change committed to ~/s/PFarm1)
- iOS models/views require no changes — the DTO field contract remains unchanged, backend now sends correct value
- Job detail view now displays original filenames to users instead of internal GUIDs
