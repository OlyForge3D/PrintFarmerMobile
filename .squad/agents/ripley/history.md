# Ripley — History

## Core Context (Archived)

### Project Setup & Architecture (Dallas, 2026-03-06)
- **Project:** PFarm-Ios — Native iOS client for Printfarmer backend (~/s/PFarm1)
- **User:** Jeff Papiez
- **Stack:** Swift, SwiftUI, iOS 17+, MVVM + Repository Pattern, @Observable ViewModels (modern), Actor-based services, ServiceContainer DI, KeychainSwift for token storage
- **Build:** SPM (Package.swift) for CLI validation, Xcode (.xcodeproj) for IDE, target iOS 17+, Swift 6.0

### Critical Swift 6 Patterns Established
- **@MainActor requirement:** AppRouter (NavigationPath/selectedTab), AuthViewModel, and all ViewModels used as @State must be @MainActor
- **@Observable in App struct:** Never gate conditional view rendering on @Observable properties inside App struct body — tracking is unreliable. Extract gating into a View struct (RootView pattern) where observation is reliable.
- **RootView tri-state pattern:** Use hasCheckedAuth flag + three states (checking → authenticated → unauthenticated) to prevent blank screens during auth checks
- **nonisolated(unsafe) for closures:** When @Sendable closures need access to isolated state, use nonisolated(unsafe) rebinding at method entry

### Backend Contracts (Verified 2026-03-06 → 2026-03-08)
- **Auth:** Single JWT token (no refresh), stored in Keychain, validated via GET /api/auth/me
- **Printer list:** GET /api/printers returns CompletePrinterDto[] with live SignalR status
- **Printer detail:** GET /api/printers/{id} returns PrinterDto (simpler, includes serverUrl/apiKey)
- **Jobs:** GET /api/job-queue-analytics returns individual jobs (not printer-centric QueueOverview)
- **Filament:** SetActiveSpool → PrinterServiceProtocol.setActiveSpool(printerId:spoolId:) + loadFilament/unloadFilament
- **Job queue pause/resume:** Lives on JobQueueAnalyticsController (/api/job-queue-analytics/jobs/{id}/pause|resume), not JobQueueController
- **Filename mapping:** GcodeFile.Name (user-uploaded), not GcodeFile.FileName (GUID disk name)

### Completed Implementations (2026-03-06 → 2026-03-08)
1. **MVP Phase (2026-03-06):** 7 screens (Login, Dashboard, Printers, Printer Detail, Jobs, Alerts, Settings), 5 ViewModels + Views, theme system with pf-prefixed colors
2. **Filament/Inventory Phase (2026-03-07):** Inventory tab (cylinder.fill), 6 new files (SpoolPickerView/ViewModel, SpoolInventoryView/ViewModel, AddSpoolView, ColorName extension)
3. **Spool Filtering & Enhancements (2026-03-08):** Material type chips, status filters (Available/In Use/Low/Empty), expanded search (color + location + comment), weight progress bar, in-use badge, SwiftLint cleanup (28 violations)
4. **iPad Layout Pass (2026-03-07 → 2026-03-08):** Adaptive layouts via horizontalSizeClass; NavigationSplitView sidebar (iPad) vs TabView (iPhone); 2-column grids (PrinterList, DashboardView); 2-column detail layout (PrinterDetailView); form width cap (LoginView)
5. **Launch Screen (2026-03-08):** LaunchScreen.storyboard (centered 🌾 + "PrintFarmer" text), 3 color sets (LaunchBackground, LaunchText, LaunchAccent), pbxproj update (UILaunchStoryboardName)
6. **7 New Feature UIs (2026-03-08):** Maintenance Analytics, AutoPrint, Job Analytics, Predictive Insights, Dispatch Dashboard, Job History/Timeline, Uptime/Reliability (7 ViewModels + 11 Views, all iPad-adaptive)

### Notable Implementation Details
- Server URL persisted in UserDefaults via APIClient.serverURLKey; auto-prepended https:// by LoginViewModel
- Theme colors all prefixed `pf` (pfBackground, pfCard, pfError, pfAccent, etc.) — use explicit Color.pfX form in ShapeStyle contexts
- Camera snapshot: service-fetched Data + AsyncImage fallback + "No camera" placeholder
- SpoolPickerView/AddSpoolView ready for NFC scan pre-fill integration (Phase 2)
- Pull-to-refresh on all list views; swipe-to-delete on SpoolInventoryView with context menu
- ScrollViewReader + onChange pattern for scroll-to-highlight on NFC scan results
- AutoPrintSection embedded in PrinterDetailView (both iPhone/iPad); Dispatch Dashboard as DashboardView card; Job Analytics/History accessible from JobListView toolbar

### Testing Infrastructure (2026-03-08)
- ViewModels + test infrastructure ready for unit testing (Ash's responsibility)
- MockSpoolService, MockScannerService stubs available
- XCUITest files ready (deferred to after target creation in Xcode)

---

## Recent Work (2026-03-08, Completed 2026-03-08T05:16Z)

### 7-Feature UI Build (18 files: 7 ViewModels + 11 Views)
- **Created 7 ViewModels + 11 Views** across Maintenance, AutoPrint, Job Analytics, Predictive Insights, Dispatch, Job History/Timeline, and Uptime/Reliability features
- **Pattern consistency:** All ViewModels follow `@MainActor @Observable` + `configure(services:)` + `loadX() async` pattern
- **Navigation integration:** Added `AppTab.maintenance` + `maintenancePath` to AppRouter; 6 new `AppDestination` cases for drill-down navigation
- **Tab order updated:** Dashboard → Printers → Jobs → Inventory → Alerts → Maintenance → Settings (7 tabs, wrench.adjustable icon)
- **ContentView:** Added Maintenance tab to both compact (TabView) and regular (NavigationSplitView sidebar) layouts
- **PrinterDetailView:** Added AutoPrintSection component + Predictive Insights NavigationLink to both iPhone and iPad layouts
- **DashboardView:** Added Dispatch Dashboard NavigationLink card at bottom
- **JobListView:** Added toolbar buttons for Job Analytics and Job History navigation
- **destinationView() helper:** Extended with 6 new cases for routing to all new views
- **Service protocols referenced:** MaintenanceServiceProtocol, AutoPrintServiceProtocol, JobAnalyticsServiceProtocol, PredictiveServiceProtocol, DispatchServiceProtocol
- **ServiceContainer expectations:** maintenanceService, autoPrintService, jobAnalyticsService, predictiveService, dispatchService properties (Lambert building these in parallel)
- **iPad-adaptive:** All new views use `@Environment(\.horizontalSizeClass)` for adaptive grid layouts where applicable
- **SF Symbols used:** wrench.adjustable, gauge.with.dots.needle.33percent, chart.bar, clock.arrow.circlepath, arrow.triangle.branch, chart.line.text.clipboard
- **Build status:** 33 new files added to Xcode; ~10 source mismatches with Lambert's models/protocols fixed by build verification; all compiled successfully

### Cross-Agent Work: Lambert's 5 Service Layers (2026-03-08)
- **Lambert (agent-32)** built 5 service layers (15 files: 5 models, 5 protocols, 5 services) in parallel
- **Services delivered:** MaintenanceService, AutoPrintService, JobAnalyticsService, PredictiveService, DispatchService
- **Models:** 30+ new DTOs covering maintenance issues, auto-print rules, job analytics metrics, failure predictions, dispatch routing
- **Protocols:** All follow existing pattern (actor-based, with default-parameter extensions)
- **ServiceContainer:** All 5 services registered and ready for dependency injection
- **Key design decisions:** PredictionRequest adapted to match ViewModel expectations; FleetPrinterStatistics uses computed Identifiable; date query params use ISO 8601 plain format
- **Dependency:** All 7 new ViewModels reference these 5 service protocols; ready to integrate once Lambert confirms ServiceContainer registration

### Cross-Agent Work: Build Verification & Source Reconciliation (2026-03-08)
- **Build verification agent** (sync mode) added 33 new files to Xcode.pbxproj
- **Source mismatches fixed:** ~10 mismatches between Lambert's model names/protocol methods and Ripley's ViewModel references reconciled
- **Outcome:** All code compiled; zero errors, zero new warnings across new files

## Learnings

### 7-Feature UI Build at Scale (2026-03-08)
- **ViewModel pattern consistency** — All 7 new ViewModels follow the established @MainActor @Observable + configure(services:) + loadX() async pattern established by earlier ViewModels
- **Navigation structure scalability** — AppRouter's AppTab enum + NavigationPath + AppDestination cases scale cleanly; 6 new feature screens added without disrupting existing navigation
- **Parallel agent execution** — Lambert (services) + Ripley (UIs) + Build verification (source reconciliation) worked seamlessly when contracts are well-defined upfront
- **Source mismatch resolution** — Build verification caught ~10 mismatches between Lambert's model/protocol naming and Ripley's ViewModel references; all resolved with zero rework
- **iPad-adaptive patterns** — Using @Environment(\.horizontalSizeClass) throughout new features ensures consistent multi-column experience on iPad without duplicating view code

### Service Layer Consumption Patterns (2026-03-08)
- ViewModels receive ServiceContainer in configure(services:), extract needed protocols, avoid tight coupling
- Service protocols pre-computed Identifiable (FleetPrinterStatistics) work seamlessly in List/ForEach
- Optional fields in request DTOs (PredictionRequest) support flexible API responses without breaking UI
- Date query parameters use ISO8601Plain format for consistent URL serialization across all services

### Cross-Agent Dependency Management (2026-03-08)
- Service layer design (Lambert) must be completed and validated before UI implementation (Ripley) can reference them
- Build verification as a separate agent catches integration issues early; prevents compile-time surprises
- Maintaining consistent naming conventions across service models/protocols/ViewModels is critical for parallel team execution
- Testing infrastructure (mocks, fixtures) should be pre-built for services before UIs consume them (Ash's responsibility)
