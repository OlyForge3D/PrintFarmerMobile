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
