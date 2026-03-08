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
- **Views:** SwiftUI views organized by feature
- **ViewModels:** @Observable view models per feature
- **Services:** Actor-based services (Auth, APIClient, Networking, Persistence)
- **Utilities:** Constants, Extensions, Helpers
- **Resources:** Assets, Localization

### Architecture
- MVVM + Repository Pattern
- @Observable ViewModels (modern SwiftUI)
- Actor-based services for Swift 6 strict concurrency
- ServiceContainer for dependency injection
- KeychainSwift for token storage

## Key Patterns & Contracts

### Authentication & Configuration
- Backend returns single JWT token (no refresh) via POST /api/auth/login
- Token stored in Keychain, validated via GET /api/auth/me
- APIClient has mutable base URL (actor-isolated), persisted to UserDefaults
- AuthService.login(serverURL:) calls apiClient.updateBaseURL()
- PFarmApp creates APIClient → AuthService → AuthViewModel chain

### Backend DTO Mapping
- **Printer list:** GET /api/printers returns CompletePrinterDto[] (includes live SignalR status)
- **Printer detail:** GET /api/printers/{id} returns PrinterDto (has serverUrl/apiKey, missing live status fields)
- Swift Printer model decodes both via custom init(from:) with decodeIfPresent + defaults
- **Key difference:** CompletePrinterDto has MotionType/HomedAxes/InMaintenance, PrinterDto lacks these but has CameraSnapshotUrl

### JSON Serialization
- Backend uses `JsonStringEnumConverter()` globally — all enums serialize as strings ("Printing", "Ready", etc.)
- Swift enums must have String raw values (not Int) with fallback decoders
- Backend `.NET 10` emits ISO 8601 dates with fractional seconds; Swift's .iso8601 rejects them
  - Solution: Custom dual-format ISO8601 decoder (tries fractional first, falls back to plain)
  - Made formatters `internal` so SignalRService can reuse them
- TimeSpan serializes as strings (e.g., "01:30:00"); Swift stores as String? with helper properties

### Error Handling & Security
- 401 responses: APIClient posts Notification.Name.sessionExpired → AuthViewModel calls logout() automatically
- Token expiry pre-check: AuthService.isTokenExpired() with 5-minute buffer checked before every request
- Force unwraps removed: URLComponents creation now uses guard let + NetworkError.invalidURL
- Silent error suppression: Secondary data loads (status, snapshot, stats) logged as warnings, don't block primary view

### Service Protocols
- All services conform to protocols in PrintFarmer/Services/Protocols/ for testability
- MockServices available for all: MockPrinterService, MockJobService, MockSpoolService, MockNFCService, etc.
- ServiceContainer registers all services and provides DI via environment injection

## Completed Implementations

### MVP Networking (2026-03-06)
- **6 services:** APIClient, AuthService, PrinterService, JobService, NotificationService, StatisticsService, SignalRService
- **9 models:** PrinterStatusDetail, PrintJobStatusInfo, CommandResult, AppNotification, QueueOverview, StatisticsSummary, MmuStatus, SpoolInfo, and 16+ supporting DTOs
- **API endpoints:** 40+ endpoints across all services verified against ~/s/PFarm1 source
- **SignalR:** Full WebSocket implementation with auto-reconnect, exponential backoff (1s→30s), 2 MVP events (printerupdated, jobqueueupdate)

### Push Notifications (2026-07-17)
- **PushNotificationManager:** @MainActor @Observable singleton handling APNs, permissions, foreground display via UNUserNotificationCenterDelegate
- **AppDelegate:** UIApplicationDelegateAdaptor for push callbacks
- **NotificationService:** registerDeviceToken() / unregisterDeviceToken() methods (backend endpoint placeholder; real endpoint needed)
- **Deep-link ready:** Tapped notifications post Notification.Name.pushNotificationTapped with userInfo for navigation
- **All code:** #if canImport(UIKit) guarded for SPM macOS build compatibility

### Phase 1 Filament/Spool Services (2026-07-17)
- **FilamentModels:** SpoolmanSpool, SpoolmanFilament, SpoolmanVendor, SpoolmanMaterial, SpoolmanPagedResult<T>, SetActiveSpoolRequest
- **SpoolService:** Actor-based CRUD for spools; list filaments/vendors/materials; pagination (limit/offset)
- **PrinterService extensions:** setActiveSpool(), loadFilament(), unloadFilament(), changeFilament()
- **APIClient.patch():** Added PATCH method support for updates
- **Key finding:** Backend uses paginated SpoolmanPagedResult (limit/offset, not page/pageSize)

### Phase 2 Scanning Services (2026-07-17, Completed 2026-03-07T16:34Z)
- **SpoolScannerProtocol:** Shared abstraction for QR + NFC scanners with error types + ScannedSpoolData
- **QRSpoolScannerService:** VisionKit DataScannerViewController wrapper, supports single-scan mode
- **NFCService:** CoreNFC read/write with NDEF support, ISO 14443 tag support, OpenSpool + OpenPrintTag parsing
- **Parsers:** QRCodeParser (3 formats: URL /spools/{id}, plain int, JSON), NFCTagParser (OpenSpool + OpenPrintTag)
- **ServiceContainer:** Conditionally registers behind #if canImport(UIKit)
- **pbxproj:** 7 new files registered with collision-free UUIDs
- **Build:** Zero errors, plutil validates clean
- **Info.plist:** NSCameraUsageDescription, NFCReaderUsageDescription not yet set in target (requires Xcode or manual plist)

### QA Fixes (2026-07-16 → 2026-03-07)
- JSON decode: Enum serialization (string not int), fractional seconds in dates
- Resilient decoding: CompletePrinterDto vs PrinterDto mapped via custom init(from:)
- SignalR date decoder: Made formatters internal for reuse
- 401 auto-logout: Posts sessionExpired notification → AuthViewModel logout
- Token pre-check: isTokenExpired() closure called before each request
- APIClient debug logging: #if DEBUG block prints raw response on decode failure
- All test fixtures updated: String enum values, stale PrintJob fields corrected

## Recent Work (2026-03-07)

### NFCService Sendable Conformance
- Fixed Sendable warning at line 201 in tagReaderSession(_:didDetect:)
- Pattern: Move nonisolated(unsafe) rebinding to method entry (before first closure)
- Both @Sendable closures now safely capture binding references
- Ensures NFCService works in @Observable ViewModels without "sending risk" errors

### Ripley's Filename Mapping Fix
- Backend JobQueueService.cs was mapping GcodeFile.FileName (GUID disk name) instead of GcodeFile.Name (original filename)
- Fixed 6 locations across JobQueueService (committed to ~/s/PFarm1)
- iOS models/views require no changes — DTO contract unchanged
- Users now see original filenames instead of internal GUIDs

## Cross-Agent Dependencies

**Ripley (UI Layer) depends on:**
- ✓ SpoolServiceProtocol (list, get, create, update, delete with pagination)
- ✓ PrinterService filament methods (setActiveSpool, loadFilament, unloadFilament, changeFilament)
- ✓ SpoolScannerProtocol + QRSpoolScannerService + NFCService (ready for scanning UI)
- ✓ APIClient.patch() for updates

**Ash (Testing) depends on:**
- ✓ All service protocols with mocks available
- ✓ 145+ test cases validating MVP endpoint coverage
- ✓ Parser contracts defined via 61 test cases

**Dallas (Architecture) depends on:**
- ✓ ServiceContainer pre-populated for DI
- ✓ No breaking changes to startup or configuration patterns

## Archived Entries

For full details on earlier work (JSON decoding, resilient decoders, QA audit fixes, SignalR implementation), see git history and decisions.md. Key archived topics:

- Backend API discovery & verification from ~/s/PFarm1 source
- SignalR event mapping (printerupdated, jobqueueupdate)
- Enum serialization fix (string vs int)
- Fractional seconds in ISO 8601 dates
- 401 auto-logout pattern
- Token expiry pre-check
- Silent error suppression pattern
- Test fixture updates

### Issue #1: "Available" Spool Filter Fix (2026-07-18)
- **Root cause:** `SpoolmanJsonParser.cs` in `~/s/PFarm1` had a fallback where absent `in_use` field defaulted to `!archived`. Since most spools have `archived: false`, this set `inUse = true` for ALL non-archived spools, making the iOS "Available" filter (`!spool.inUse && !archived`) return zero results.
- **Fix:** Removed the `!archived` fallback entirely. When `in_use` is absent from Spoolman JSON, the parser now falls through to the existing `?? false` default on the DTO constructor (line 145). "Archived" and "in use" are independent concepts.
- **Scope:** Backend-only change in `~/s/PFarm1/src/infra/Parsing/SpoolmanJsonParser.cs`. No iOS code changes needed — the iOS filter logic was correct all along.
