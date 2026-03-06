# Dallas — History

## Project Context
- **Project:** PFarm-Ios — Native iOS client for Printfarmer
- **User:** Jeff Papiez
- **Stack:** Swift, SwiftUI, iOS 17+
- **Backend:** Printfarmer (42+ REST endpoints, SignalR, JWT auth) at ~/s/PFarm1

## Learnings

### MVP Scope Definition (2025-07-17)
- **Backend catalog:** 100+ REST endpoints across 30+ controllers. MVP needs only ~22 endpoints.
- **SignalR hubs:** 5 hubs (PrinterHub, HarvestHub, MaintenanceHub, SlicerHub, SlicerProgressHub). MVP needs PrinterHub only (`printerupdated`, `jobqueueupdate` events).
- **Key backend insight:** `GET /api/printers` returns `CompletePrinterDto` which merges static config + live SignalR-cached status in one call. Very efficient for phone list views.
- **Job queue route discrepancy:** Web frontend uses `/api/job-queue` (hyphen). iOS `JobService` uses `/api/jobqueue` (no hyphen). Must verify which is correct — likely the hyphenated version based on `JobQueueController` route attribute.
- **Printer commands are individual endpoints:** `/pause`, `/resume`, `/cancel`, `/stop`, `/emergency-stop` — NOT a generic `/command/{action}` route. Existing `sendCommand` method in `PrinterService` is wrong pattern; needs specific methods.
- **MVP features (5):** Fleet Dashboard, Printer List+Detail, Quick Printer Actions, Job Queue, Notifications
- **Deferred:** Discovery, file management, slicer, cameras (live stream), statistics charts, maintenance plans, admin/settings, filament inventory, NFC, webhooks
- **Implementation order:** Lambert builds foundation (SignalR, services, models) → Ripley builds screens → Polish pass
- **MVP scope document:** `.squad/decisions/inbox/dallas-mvp-scope.md`

### Cross-Agent Context (2026-03-06)
- **Ripley's Login Screen:** LoginViewModel form state (separate from AuthViewModel). Server URL flows through AuthService → APIClient.updateBaseURL(). Dark Mode + error animation working.
- **Lambert's Auth:** Single JWT token (no refresh). AuthService validates via GET /api/auth/me. Keychain storage, UserDefaults for base URL. Actor-isolated APIClient.
- **Ash Ready:** Both auth scaffolding and navigation system in place. Can build printer/job screens with confidence.

### Project Structure (2025-07-16 → 2026-03-06)
- **Architecture:** MVVM with repository-pattern services, `@Observable` view models, SwiftUI views
- **Navigation:** `AppRouter` (Observable) with `NavigationPath` per tab + `AppTab` enum for TabView
- **Dependency injection:** `ServiceContainer` holds all services; passed via `.environment()`. `APIClient` is an `actor` for thread safety.
- **Auth flow:** `AuthViewModel` gates the root view — unauthenticated users see `LoginView`, authenticated see `ContentView` (TabView)
- **Networking:** `APIClient` actor with async/await, JWT bearer token injection, ISO 8601 date decoding, typed error handling (`NetworkError` enum)
- **Token storage:** KeychainSwift (evgenyneu/keychain-swift) for secure JWT persistence
- **Models:** All Codable structs marked `Sendable` for Swift 6 strict concurrency. Models match backend DTOs from PFarm1.
- **SignalR:** Stub service created; implementation deferred pending SignalR client package selection
- **Build:** Both SPM (`swift build`) and Xcode project (.xcodeproj) supported. Bundle ID: `com.printfarmer.ios`, iOS 17+, Swift 6.0
- **Key files:**
  - Entry: `PrintFarmer/PFarmApp.swift`
  - Nav: `PrintFarmer/Navigation/AppRouter.swift`
  - Models: `PrintFarmer/Models/Models.swift` (Printer, PrintJob, Location, Auth DTOs + enums)
  - Networking: `PrintFarmer/Services/APIClient.swift`
  - Config: `PrintFarmer/Utilities/AppConfig.swift` (base URL via env var or default localhost:5000)
- **Session Directive (2026-03-06):** Use claude-opus-4.6 for code-writing tasks (Ripley, Lambert, Ash)

### MVP Build Orchestration & Handoff (2026-03-06)
- **Status:** ✅ Orchestrated 4-agent batch (Dallas lead, Lambert + Ripley + Ash parallel)
- **Scope:** 5 features, 22 endpoints, phone-first design principles — locked in decisions.md
- **Lambert Results:** ✅ 6 services (Printer, Job, Notification, Statistics, SignalR, Auth), 9 models, 5 service protocols — all compiling clean
- **Ripley Results:** ✅ All 7 MVP screens (Dashboard, PrinterList, PrinterDetail, JobList, JobDetail, Notifications, Settings) + 6 reusable components + 5 service protocols — all compiling clean
- **Ash Results:** ✅ 145 test cases (8 suites: APIClient, Auth, Printer, Job, Notification, ModelDecoding, LoginViewModel, DashboardViewModel) + full mock infrastructure for 6 services
- **Critical Finding:** Ash discovered 3 PrinterDetailViewModel method mismatches (snapshotURL/getSnapshot, cancelPrint/cancel, setMaintenance/setMaintenanceMode) — blocking test integration, Ripley to fix
- **Next Phase:** Scribe consolidates decisions, updates agent history.md files, commits .squad/ changes; Ripley fixes mismatches; run test suite for integration validation

### Xcode Project Fix (2026-03-06)
- **Problem:** Xcode reported PrintFarmer.xcodeproj as "damaged" — could not open
- **Root causes found (3):**
  1. `project.pbxproj` missing closing `}` brace — fatal plist parse error
  2. `contents.xcworkspacedata` had empty `<Workspace>` element (missing `<FileRef location="self:">`)
  3. 21 source files added by Lambert/Ripley/Ash during MVP batch were never registered in the project (Protocols/, Components/, NotificationsView, PrinterDetailView, JobDetailView, etc.)
- **Fix:** Regenerated all three files (`project.pbxproj`, `contents.xcworkspacedata`, `PrintFarmer.xcscheme`) from scratch using a Python generator that walks the file tree
- **Validation:** Balanced braces/parens confirmed, all 14 required pbxproj sections present, all 66 Swift files (47 source + 19 test) cross-checked against disk
- **Key insight:** Hand-crafted pbxproj files are fragile. When agents add files via SPM (`swift build` validates), the xcodeproj falls out of sync. Future file additions need a regeneration step or the team should consider workspace+SPM-only approach.
- **Generator script pattern:** Deterministic IDs via `hashlib.md5(name)[:24]` — regeneration produces identical output if file tree hasn't changed
