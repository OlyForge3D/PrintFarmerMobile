# Lambert — History

## Core Context (Archived)

### Project Setup & Architecture (Dallas, 2026-03-06)
- **Project:** PFarm-Ios — Native iOS client for Printfarmer backend (~/s/PFarm1)
- **User:** Jeff Papiez
- **Stack:** Swift, SwiftUI, iOS 17+, MVVM + Repository Pattern, @Observable ViewModels, Actor-based services, ServiceContainer DI, KeychainSwift token storage
- **Build:** SPM (Package.swift) + Xcode (.xcodeproj), target iOS 17+, Swift 6.0

### Backend Integration & Patterns (Verified across 2026-03-06 → 2026-03-08)
- **Authentication:** Single JWT token (no refresh) via POST /api/auth/login; stored in Keychain; validated via GET /api/auth/me; auto-logout on 401
- **API Contracts:** 40+ endpoints across 7 services; backend uses JsonStringEnumConverter (enums as strings, not ints); ISO 8601 dates with fractional seconds; TimeSpan as "HH:MM:SS" strings
- **Service patterns:** All services conform to protocols in PrintFarmer/Services/Protocols/; MockServices available for testability; ServiceContainer provides DI
- **Printer DTOs:** CompletePrinterDto (list endpoint, includes live status) vs PrinterDto (detail endpoint, includes serverUrl/apiKey); custom init(from:) handles both
- **Resilient decoding:** Custom dual-format ISO8601 decoder (fractional → plain fallback); enum String raw values with fallback; silent error suppression for secondary data loads

### Completed Service Layers (2026-03-06 → 2026-03-08)
1. **MVP (2026-03-06):** APIClient, AuthService, PrinterService, JobService, NotificationService, StatisticsService, SignalRService (7 services, 6+ service models)
2. **Push Notifications (2026-07-17):** PushNotificationManager (@MainActor @Observable singleton), AppDelegate adapter, NotificationService extensions (registerDeviceToken/unregisterDeviceToken)
3. **Phase 1 Filament/Spool (2026-07-17):** SpoolService (CRUD + pagination), PrinterService extensions (setActiveSpool/loadFilament/unloadFilament/changeFilament), FilamentModels (SpoolmanSpool/Filament/Vendor/Material), APIClient.patch()
4. **Phase 2 Scanning (Completed 2026-03-07T16:34Z):** SpoolScannerProtocol abstraction, QRSpoolScannerService, NFCService (CoreNFC + NFC tag parsing), QR/NFC parsers, ServiceContainer conditional registration
5. **New Service Layers (2026-03-08):** MaintenanceService, AutoPrintService, JobAnalyticsService, PredictiveService, DispatchService (5 services, 30+ DTOs, all registered in ServiceContainer)

### Key Technical Decisions Codified (2026-03-07 → 2026-03-08)
- **Spoolman naming & pagination:** Model prefix `Spoolman` (avoid future collisions), limit/offset pagination (not page/pageSize), SetActiveSpoolRequest returns CommandResult, APIClient.patch() for updates
- **Filament UI architecture:** Filament section in PrinterDetailView (between Camera and Actions), SpoolService for list/create/delete, PrinterService for active spool assignment, SpoolPickerView as modal sheet, phase 2 NFC hook ready
- **iPad layout architecture:** @Environment(\.horizontalSizeClass) for adaptive layouts; NavigationSplitView (iPad) vs TabView (iPhone); sidebar with explicit Button-based rows (List(selection:) unavailable on iOS)
- **Service layer design:** PredictionRequest optional fields adapted to match existing ViewModel (not breaking existing code); FleetPrinterStatistics computed Identifiable (id backed by printerId); date query params use ISO8601Plain format; request models Encodable-only (never decoded)

### Testing Infrastructure (2026-07-18 → 2026-03-08)
- **Unit tests:** MockURLProtocol for in-process mocking; MockServices for all protocols; 145+ test cases validating MVP endpoint coverage; 61 test cases for parser contracts (QR/NFC)
- **XCUITest infrastructure:** MockAPIServer (NWListener-based TCP server, not MockURLProtocol, due to process isolation); environment variable injection (PFARM_MOCK_SERVER_URL); wildcard route matching (/api/printers/*); canned JSON responses (MockResponses enum); Spoolman test fixtures
- **Build verification:** 33 new files added to Xcode.pbxproj (2026-03-08); ~10 source mismatches reconciled between Lambert models/protocols and Ripley ViewModels

### Known Issues & Resolutions
- **Spoolman "Available" filter (Issue #1, 2026-07-18):** SpoolmanJsonParser.cs had fallback `inUse = !archived` when in_use absent — set all non-archived spools to inUse=true, breaking Available filter. Fixed: removed fallback, defaults to false. iOS filter logic was correct all along.
- **XCUITest target setup (Decision, 2026-07-20):** XCUITest files ready, but target creation requires manual Xcode step (UI Testing Bundle wizard); deferred to Ripley UI test implementation
- **NFCService Sendable (2026-03-07):** Fixed Sendable warning at line 201 using nonisolated(unsafe) rebinding pattern for @Sendable closures in tagReaderSession callback
- **SwiftLint violations (2026-03-08):** Fixed 28 violations across 10 files (trailing whitespace, vertical whitespace, control statements, line length, cyclomatic complexity)

---

## Recent Work (2026-03-08, Completed 2026-03-08T05:16Z)

### New Service Layers (5 files, 15 total with models & protocols)
- Created 5 new service layers (15 files) for Maintenance, AutoPrint, JobAnalytics, Predictive, Dispatch
- **Models:** 30+ new DTOs across 5 model files in PrintFarmer/Models/ServiceModels/
- **Protocols:** 5 protocol files with default-parameter extensions (same pattern as StatisticsServiceProtocol)
- **Services:** 5 actor-based service implementations using apiClient.get/post/put
- **ServiceContainer:** Registered all 5 new services as `let` properties in init
- **PredictionRequest adapted:** Existing PredictiveViewModel expected `material: String?` and `estimatedDurationSeconds: Int?` (not the task spec's non-optional String and Double). Added `failureProbability` field alongside `predictedFailureLikelihood` to match ViewModel usage.
- **Date query params:** Used `APIClient.iso8601Plain.string(from:)` for date→string in URL query parameters
- **FleetPrinterStatistics:** Used computed `id` property (backed by `printerId`) with explicit CodingKeys to satisfy Identifiable without a dedicated `id` JSON field
- **Build verified:** Zero errors, zero new warnings

### Cross-Agent Work: Ripley's 7-Feature UI Build (2026-03-08)
- **Ripley (agent-33)** built 7 feature UIs (18 files: 7 ViewModels + 11 Views) in parallel
- **Features delivered:** Maintenance Analytics, AutoPrint, Job Analytics, Predictive Insights, Dispatch Dashboard, Job History/Timeline, Uptime/Reliability
- **Navigation:** New Maintenance tab added (6th tab after Inventory); 6 AppDestination cases for drill-down navigation
- **Integration points:** PrinterDetailView has new AutoPrintSection + Predictive Insights link; DashboardView has Dispatch card; JobListView has Job Analytics/History toolbar buttons
- **iPad-adaptive:** All new views use horizontalSizeClass for proper multi-column layouts on iPad
- **Build verification:** Added 33 new files to Xcode, fixed ~10 source mismatches between Lambert's models/protocols and Ripley's ViewModels
- **Dependency:** All 7 ViewModels reference this batch of 5 service layers; Ripley waiting for final ServiceContainer integration

### Cross-Agent Work: Build Verification & Source Reconciliation (2026-03-08)
- **Build verification agent** (sync mode) validated Lambert's 15 files + Ripley's 18 files
- **Source mismatches fixed:** ~10 mismatches between Lambert's model names/protocol methods and Ripley's ViewModel references
- **Files added:** All 33 new files properly registered in Xcode project.pbxproj with collision-free UUIDs
- **Outcome:** All code compiled successfully; zero errors, zero new warnings

## Learnings

### Cross-Team Collaboration (2026-03-08)
- Parallel agent execution (Lambert + Ripley + Build verification) requires upfront planning for source compatibility
- Model/protocol naming must be coordinated before ViewModels reference them; build verification catches mismatches early
- Service patterns should be established once (StatisticsServiceProtocol) and replicated for consistency
- ServiceContainer DI pattern scales well to 12+ services (MVP 7 + new 5) with no friction

### Service Layer Design at Scale
- 5 new service layers (MaintenanceService, AutoPrintService, JobAnalyticsService, PredictiveService, DispatchService) follow existing Actor-based patterns
- Optional fields in request DTOs must match existing ViewModel expectations (PredictionRequest adapted to support both String? and Int?, not forcing breaking changes)
- Computed Identifiable properties (FleetPrinterStatistics.id) enable DTOs without explicit id JSON fields
- ISO8601 formatters reused across services for consistency (date query params use iso8601Plain)
