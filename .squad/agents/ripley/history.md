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

## Key Learnings & Patterns

### Critical Swift 6 Patterns
- **@MainActor requirement:** AppRouter (NavigationPath/selectedTab), AuthViewModel, and all ViewModels used as @State must be @MainActor
- **@Observable in App struct:** Never gate conditional view rendering on @Observable properties inside App struct body — tracking is unreliable. Extract gating into a View struct (RootView pattern) where observation is reliable.
- **RootView tri-state pattern:** Use hasCheckedAuth flag + three states (checking → authenticated → unauthenticated) to prevent blank screens during auth checks
- **nonisolated(unsafe) for closures:** When @Sendable closures need access to isolated state, use nonisolated(unsafe) rebinding at method entry

### Backend Contracts (Verified 2026-03-07)
- **Auth:** Single JWT token (no refresh), stored in Keychain, validated via GET /api/auth/me
- **Printer list:** GET /api/printers returns CompletePrinterDto[] with live SignalR status
- **Printer detail:** GET /api/printers/{id} returns PrinterDto (simpler, includes serverUrl/apiKey)
- **Jobs:** GET /api/job-queue-analytics returns individual jobs (not printer-centric QueueOverview)
- **Filament:** SetActiveSpool → PrinterServiceProtocol.setActiveSpool(printerId:spoolId:) + loadFilament/unloadFilament
- **Job queue pause/resume:** Lives on JobQueueAnalyticsController (/api/job-queue-analytics/jobs/{id}/pause|resume), not JobQueueController
- **Filename mapping:** GcodeFile.Name (user-uploaded), not GcodeFile.FileName (GUID disk name)

### Completed Phases
- **Phase 1:** 7 MVP screens, 5 services, theme system, filament UI (6 new files)
- **Phase 2:** Scanning UI (QR + NFC), 3 new views, SpoolPickerView + SpoolInventoryView extensions

### Notable Implementation Details
- Server URL persisted in UserDefaults via APIClient.serverURLKey; auto-prepended https:// by LoginViewModel
- Theme colors all prefixed `pf` (pfBackground, pfCard, pfError, pfAccent, etc.) — use explicit Color.pfX form in ShapeStyle contexts
- Camera snapshot: service-fetched Data + AsyncImage fallback + "No camera" placeholder
- SpoolPickerView/AddSpoolView ready for NFC scan pre-fill integration
- Pull-to-refresh on all list views; swipe-to-delete on SpoolInventoryView with context menu
- ScrollViewReader + onChange pattern for scroll-to-highlight on NFC scan results

### Cross-Agent Integrations
- **Lambert (Services):** SpoolServiceProtocol, PrinterServiceProtocol extensions, FilamentModels, SpoolScannerProtocol, NFCService (Sendable), QRSpoolScannerService
- **Dallas (Architecture):** ServiceContainer DI, AppRouter with NavigationStack pattern, routing contracts
- **Ash (Testing):** MockSpoolService, MockScannerService, ViewModel test infrastructure

## Recent Work (2026-03-07)

### Material Type Filter Chips + Expanded Search (2026-03-07)
- Added material type filter chips to both SpoolInventoryView and SpoolPickerView (FilterChip-based segmented control)
- Expanded search filter to include color (hex-to-name heuristic), location, and comment fields
- Created `SpoolmanSpool+ColorName.swift` extension for lightweight color matching (common filament palette)
- Added `hasActiveSearch` computed property to both ViewModels for empty-state gating
- Implemented `ContentUnavailableView.search` empty state when filtered results yield nothing
- Updated search bar prompts: "Search by name, material, color…"
- Key files: `SpoolInventoryView.swift`, `SpoolPickerView.swift`, `SpoolInventoryViewModel.swift`, `SpoolPickerViewModel.swift`, `SpoolmanSpool+ColorName.swift` (new)

### GcodeFile Filename Mapping Fix
- Fixed backend JobQueueService.cs mapping: GcodeFile.FileName → GcodeFile.Name (6 locations)
- User-uploaded filenames now display in job detail views instead of internal GUID-based disk names
- Change applied to ~/s/PFarm1 (backend repo) — iOS app requires no model or view changes
- DTO contract unchanged; backend now sends correct original filename value
- Impact: All API consumers (iOS, web, etc.) see user-friendly filenames

### Spool Filtering (Enhanced)
- Both SpoolInventoryView and SpoolPickerView had `.searchable()` + `filteredSpools` but filtering was limited to name/material/vendor
- Expanded filter criteria: now includes location, comment, and hex-to-color-name matching
- Added `SpoolmanSpool+ColorName.swift` extension for approximate color name lookup from hex codes (e.g., searching "red" matches #FF0000)
- Added `ContentUnavailableView.search` empty state when filtered results are empty
- Added `hasActiveSearch` computed property to both ViewModels for empty-state gating
- Updated search bar prompts to "Search by name, material, color…" for discoverability
- Key files: `PrintFarmer/Extensions/SpoolmanSpool+ColorName.swift`, both ViewModels, both Views

### Status Filter Chips & Weight Progress Indicators (2026-03-07)
- **Status filters:** Added second row of filter chips (Available, In Use, Low, Empty) below material chips on both SpoolInventoryView and SpoolPickerView
- **SpoolStatus enum:** Created in SpoolInventoryViewModel.swift with cases: available, inUse, low, empty
  - Available: `!inUse && !archived`
  - In Use: `inUse == true`
  - Low: remaining weight < 20% of initial weight
  - Empty: remaining weight == 0 or remaining is nil while initial exists
- **Weight progress bar:** Added horizontal capsule progress indicator on spool rows showing remaining/initial percentage
  - Color coded: green (>50%), yellow (20-50%), red (<20%)
  - Shows below weight text on SpoolInventoryRowView (60px wide, 4px tall)
  - Shows on SpoolRowView in picker (50px wide, 3px tall)
- **In-use badge:** Added `printer.fill` SF Symbol next to spool name when `inUse == true`, colored with pfAccent
- **Updated filteredSpools:** Now applies material + status + search filters in sequence (intersection logic)
- **Updated hasActiveSearch:** Now includes `selectedStatus != nil` check for proper empty state handling
- Key files: `SpoolInventoryViewModel.swift`, `SpoolPickerViewModel.swift`, `SpoolInventoryView.swift`, `SpoolPickerView.swift`
- Design pattern: Same capsule chip style as material filters (pfAccent when selected, pfBackgroundTertiary when not)

### NFCService Sendable Pattern (Lambert)
- NFCService implements Sendable protocol for safe concurrent use in ViewModels
- Fixed Sendable warning at line 201 using nonisolated(unsafe) rebinding pattern
- Both @Sendable closures now safely capture binding references
- Pattern: Move nonisolated(unsafe) rebinding to method entry, then closures reference safely

## Archived Entries (2025-07-16 → 2025-07-22)

For full details on previous work, see git history and .squad/decisions.md. Summary:

- **MVP implementation:** Dashboard, PrinterList, PrinterDetail, JobList, JobDetail, Notifications, Settings screens with MVVM + Repository pattern
- **Theme system:** 3 new files (Color+Hex, ThemeColors, ThemeManager), 17 hardcoded colors replaced
- **Filament UI:** Inventory tab, SpoolPickerView, SpoolInventoryView, AddSpoolView with load/eject actions
- **QA audit:** @MainActor annotations, error handling, accessibility labels, placeholder navigation
- **Blank screen fix:** RootView extraction + hasCheckedAuth flag pattern
- **Camera enhancement:** Service-based snapshot + AsyncImage fallback
- **Phase 2 scanning:** QRScannerView, NFCScanButton, NFCWriteView with pre-fill from scans
