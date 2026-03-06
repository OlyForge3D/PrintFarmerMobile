# Dallas — History

## Project Context
- **Project:** PFarm-Ios — Native iOS client for Printfarmer
- **User:** Jeff Papiez
- **Stack:** Swift, SwiftUI, iOS 17+
- **Backend:** Printfarmer (42+ REST endpoints, SignalR, JWT auth) at ~/s/PFarm1

## Learnings

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
