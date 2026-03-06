# Squad Decisions

## Active Decisions

### Copilot Model Directive (Jeff Papiez, 2026-03-06)
**Status:** Accepted

#### Recommended Model for Code-Writing Agents
- Use **claude-opus-4.6** for Ripley (iOS Dev), Lambert (Networking), Ash (UI/Navigation)
- Use cost-optimized models (Haiku) for Scribe and non-code tasks
- **Rationale:** Code quality and architectural decisions benefit from stronger model reasoning

---

### Login Screen Architecture (Ripley, 2026-03-06)
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

### Auth Response Contract: Single JWT Token (Lambert, 2026-03-06)
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

### iOS Project Structure (Dallas, 2025-07-16)
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

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
