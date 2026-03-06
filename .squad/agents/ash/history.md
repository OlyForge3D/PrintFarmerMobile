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
