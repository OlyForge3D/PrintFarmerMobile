# Ripley — History

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
- **Lambert's Auth Contract:** Backend returns single JWT token (no refresh). AuthService stores in Keychain, validates via GET /api/auth/me. No token refresh logic needed.
- **Dallas's Wiring Pattern:** ServiceContainer at init; `.task` modifier configures ViewModels. This pattern is locked in.
- **Ash's Navigation:** Deep navigation via AppDestination enum. LoginView → ContentView gating confirmed working.

### Login Screen (2025-07-16 → 2026-03-06)
- **LoginView.swift** (`Views/Auth/LoginView.swift`): Full login UI with collapsible server URL, credential fields, error banner, loading state
- **LoginViewModel.swift** (`ViewModels/LoginViewModel.swift`): `@MainActor @Observable` — form state, URL validation, server URL persistence
- **AuthViewModel** uses `configure(with:)` pattern (not constructor injection) — set up in PFarmApp `.task`
- **PFarmApp.swift** creates APIClient/AuthService at init, configures AuthViewModel in `.task`, gates on `isAuthenticated`
- Server URL persisted in UserDefaults via `APIClient.serverURLKey` ("pf_server_url") — shared between LoginViewModel and APIClient
- LoginViewModel auto-prepends `https://` if user omits scheme
- AuthService handles server URL internally via `apiClient.updateBaseURL()` — no need to rebuild service chain
- `#Preview` macro doesn't work in SPM builds — only Xcode. Other views don't include previews.
- Swift 6 strict concurrency: ViewModels that are `@State` in views need `@MainActor` to avoid "sending risks data races" errors
- Auth models: `AuthResponse` (success/token/user/error), `LoginRequest` (usernameOrEmail/password/rememberMe), `UserDTO`
- NetworkError has friendly variants: `.noConnection`, `.serverUnreachable`, `.timeout`, `.authFailed(String)`
- **Session Directive (2026-03-06):** Use claude-opus-4.6 for code-writing tasks (Ripley, Lambert, Ash)

### MVP Screens Build (2026-03-06)
- **All 7 MVP screens built:** Dashboard, PrinterList, PrinterDetail, JobList, JobDetail, Notifications, Settings
- **6 reusable components:** StatusBadge, TemperatureView, PrintProgressBar, PrinterCardView, JobCardView, EmptyStateView
- **5 service protocols defined:** PrinterServiceProtocol, JobServiceProtocol, NotificationServiceProtocol, StatisticsServiceProtocol, SignalRServiceProtocol — in `Protocols/` directory
- **ViewModel pattern:** `@MainActor @Observable` with `configure()` for protocol-typed service injection. Services are optionals set via `.task` modifier in views.
- **Navigation wiring:** Each tab wraps a `NavigationStack(path:)` bound to AppRouter. Detail views pushed via `AppDestination` enum with `.navigationDestination(for:)`.
- **Tab change:** Replaced Locations tab (not MVP) with Notifications tab. Locations tab still exists but unused.
- **PFarmApp now creates ServiceContainer** and injects it as `@Environment` alongside router and authViewModel.
- **Platform guards:** iOS-only APIs (`navigationBarTitleDisplayMode`, `topBarTrailing`, `UIImage`, `UINotificationFeedbackGenerator`) wrapped in `#if os(iOS)` / `#if canImport(UIKit)` for SPM macOS build compatibility.
- **Lambert parallel work:** Lambert already built real NotificationService, StatisticsService, expanded PrinterService/JobService, full SignalR WebSocket implementation, and new models (PrinterStatusDetail, PrintJobStatusInfo, QueueOverview, MmuStatus, CommandResult, AppNotification). Had to reconcile my protocols and views with his actual types.
- **Key model differences from spec:** `AppNotification.id` is `String` not `UUID`; fields are `subject`/`body` not `title`/`message`; `NotificationType` uses job-specific cases (JobStarted, JobCompleted, etc.); `StatisticsSummary` has no printer counts (only job stats); `JobService.list()` returns `[QueueOverview]` (printer-centric) not `[PrintJob]` (job-centric).
- **JobListView redesign:** Shows QueueOverview (per-printer queue status) with Active/Queued/Available sections instead of individual job list, since the API returns printer-centric queue data.
- **DashboardView active jobs:** Shows printers currently running jobs (from Printer model's jobName/progress fields) rather than individual PrintJob items.
- **Global `destinationView(for:)` helper:** Marked `@MainActor` to avoid Swift 6 actor isolation warnings when constructing views with `@State` init parameters.
- **Snapshot handling:** PrinterDetailView loads snapshot as `Data` from `getSnapshot(id:)` and converts to `UIImage` on iOS. No URL-based `AsyncImage`.

### Critical Findings from Ash (2026-03-06 Post-Build)

**3 PrinterDetailViewModel Method Mismatches Found by Test Coverage:**

Ash's test suite discovered that PrinterDetailViewModel calls methods that don't exist on PrinterServiceProtocol:

| Issue | ViewModel Calls | Protocol Has | Status |
|-------|-----------------|--------------|--------|
| 1 | `snapshotURL(for:)` | `getSnapshot(id:) -> Data` | ⚠️ Method name mismatch; return type (URL vs Data) requires ViewModel conversion logic |
| 2 | `cancelPrint(id:)` | `cancel(id:) -> CommandResult` | ⚠️ Method name mismatch (cancelPrint vs cancel) |
| 3 | `setMaintenance(id:enabled:)` | `setMaintenanceMode(id:enabled:) -> CommandResult` | ⚠️ Method name mismatch (setMaintenance vs setMaintenanceMode) |

**Action Required:** Update PrinterDetailViewModel method calls to match PrinterServiceProtocol signatures. This is blocking the test suite integration.

**Context:** Lambert built the actual PrinterServiceProtocol with these exact method names. The ViewModel was built against an earlier protocol spec. Ripley needs to reconcile the implementation.
