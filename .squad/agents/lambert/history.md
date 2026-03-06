# Lambert — History

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

_Lambert ready to implement unit tests and integration tests against project structure._
