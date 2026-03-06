# Ash — History

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

## Learnings

### Cross-Agent Context (2026-03-06)
- **Ripley's Login Screen:** LoginView + LoginViewModel (form state), AuthViewModel (auth state gating). Server URL flows: LoginView → LoginViewModel → AuthViewModel → AuthService.login(serverURL:) → APIClient.updateBaseURL(). Dark Mode + animated error banner working.
- **Lambert's Networking:** APIClient actor (thread-safe), AuthService with single JWT (no refresh tokens). Base URL mutable, stored in UserDefaults. Session restore via GET /api/auth/me.
- **Dallas's Pattern:** ServiceContainer at init, .task configures ViewModels. This is the canonical dependency injection pattern for the project.

_Ash ready to implement feature screens and navigation flows._
- **Session Directive (2026-03-06):** Use claude-opus-4.6 for code-writing tasks (Ripley, Lambert, Ash)

### MVP Test Suite (2025-07-17)
- **Test architecture:** MockURLProtocol for service/APIClient integration tests, protocol-based mocks for ViewModel unit tests.
- **19 test files created:** 2 helpers, 8 mocks, 1 model decoding suite, 3 service test suites, 4 ViewModel test suites. ~80 test cases total.
- **ViewModel DI pattern:** Ripley adopted `configure(printerService:)` pattern with protocol-based DI. All ViewModel tests use protocol mocks — no network calls.
- **Protocol coverage:** PrinterServiceProtocol, JobServiceProtocol, NotificationServiceProtocol, StatisticsServiceProtocol, SignalRServiceProtocol all have mock implementations.
- **AuthService has no protocol yet** — AuthService is a concrete actor. Tests use MockURLProtocol for integration testing. Created `AuthServiceProtocol` in TestProtocols.swift for future use.
- **PrinterDetailViewModel uses methods not in protocol:** `snapshotURL(for:)`, `cancelPrint(id:)`, `setMaintenance(id:enabled:)` — these don't match `PrinterServiceProtocol`. Ripley needs to fix.
- **SPM test linking issue:** `@main` in PFarmApp.swift causes duplicate `_main` symbol when linking SPM test target. Xcode build works fine. Not a test code issue.
- **DashboardViewModel changed:** `activeJobs: [PrintJob]` → `queueOverview: [QueueOverview]`. JobService.list() now returns `[QueueOverview]` not `[PrintJob]`.
- **Backend JSON format:** Backend uses camelCase — no CodingKeys needed for most models. ISO 8601 dates. Enum raw values are integers matching backend C# enums.
