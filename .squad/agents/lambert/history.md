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

### Cross-Agent Context (2026-03-06)
- **Ripley's Login Screen:** Form validation, server URL normalization (auto-prepend https://), error banner with animation, Dark Mode support. LoginViewModel delegates to AuthViewModel.
- **Dallas's Wiring:** ServiceContainer at init, .task configures ViewModels. Actor isolation prevents "sending" errors. This pattern is locked in.
- **Ash Ready:** Navigation scaffolding complete; can build printer list/detail screens immediately.

### Backend Auth Contract (2025-07-16 → 2026-03-06)
- Backend login POST /api/auth/login returns `AuthenticationResult(Success, Token, ExpiresAt, User, Error)` — single JWT token, NO refresh tokens
- Dallas's original stub had `LoginResponse` with accessToken/refreshToken — corrected to `AuthResponse` matching backend
- AuthController route: `[Route("api/auth")]`, login at `[HttpPost("login")]`
- Backend DTOs: `~/s/PFarm1/src/infra/Dtos/AuthDtos.cs` and `~/s/PFarm1/src/infra/Contracts/Auth/AuthDtos.cs`

### Printer DTO Mapping
- Printer list `GET /api/printers` returns `CompletePrinterDto[]` (not `PrinterDto`) — includes live SignalR status merged at response time
- Key fields in CompletePrinterDto: `MotionType`, `HomedAxes`, `InMaintenance`, `IsEnabled`, no `serverUrl`/`isAvailable` directly
- Single printer `GET /api/printers/{id}` returns `PrinterDto` (simpler, includes serverUrl, apiKey, etc.)
- Backend DTO source: `~/s/PFarm1/src/infra/Dtos/CompletePrinterDto.cs`

### Architecture Patterns
- APIClient base URL is mutable (actor-isolated), persisted to UserDefaults via `APIClient.serverURLKey`
- AuthService.login() takes serverURL string and calls `apiClient.updateBaseURL()` — single point of URL management
- PFarmApp creates APIClient → AuthService → AuthViewModel chain; ServiceContainer is available for post-login service access
- NetworkError enum expanded: `noConnection`, `timeout`, `serverUnreachable`, `transportError`, `authFailed`, `clientError` now carries optional `APIError` body

### Key File Paths
- `PrintFarmer/Services/APIClient.swift` — actor-based HTTP client
- `PrintFarmer/Services/AuthService.swift` — JWT auth with Keychain storage
- `PrintFarmer/Services/PrinterService.swift` — printer CRUD endpoints
- `PrintFarmer/Services/LocationService.swift` — location CRUD endpoints
- `PrintFarmer/Models/Models.swift` — all domain models (Printer, PrintJob, Location, AuthResponse, UserDTO)
- `PrintFarmer/Models/RequestModels.swift` — request DTOs (UpdatePrinterRequest, CreatePrintJobRequest, etc.)
- `PrintFarmer/Utilities/AppConfig.swift` — default base URL from env var
- **Session Directive (2026-03-06):** Use claude-opus-4.6 for code-writing tasks (Ripley, Lambert, Ash)
