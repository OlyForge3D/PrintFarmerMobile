# Squad Decisions

## Active Decisions

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
