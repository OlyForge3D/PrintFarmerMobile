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
