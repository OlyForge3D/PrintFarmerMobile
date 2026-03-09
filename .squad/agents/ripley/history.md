# Ripley — History

## Core Context (Archived)

### Project Setup & Architecture (Dallas, 2026-03-06)
- **Project:** PFarm-Ios — Native iOS client for Printfarmer backend (~/s/PFarm1)
- **User:** Jeff Papiez
- **Stack:** Swift, SwiftUI, iOS 17+, MVVM + Repository Pattern, @Observable ViewModels (modern), Actor-based services, ServiceContainer DI, KeychainSwift for token storage
- **Build:** SPM (Package.swift) for CLI validation, Xcode (.xcodeproj) for IDE, target iOS 17+, Swift 6.0

### Critical Swift 6 Patterns Established
- **@MainActor requirement:** AppRouter (NavigationPath/selectedTab), AuthViewModel, and all ViewModels used as @State must be @MainActor
- **@Observable in App struct:** Never gate conditional view rendering on @Observable properties inside App struct body — tracking is unreliable. Extract gating into a View struct (RootView pattern) where observation is reliable.
- **RootView tri-state pattern:** Use hasCheckedAuth flag + three states (checking → authenticated → unauthenticated) to prevent blank screens during auth checks
- **nonisolated(unsafe) for closures:** When @Sendable closures need access to isolated state, use nonisolated(unsafe) rebinding at method entry

### Backend Contracts (Verified 2026-03-06 → 2026-03-08)
- **Auth:** Single JWT token (no refresh), stored in Keychain, validated via GET /api/auth/me
- **Printer list:** GET /api/printers returns CompletePrinterDto[] with live SignalR status
- **Printer detail:** GET /api/printers/{id} returns PrinterDto (simpler, includes serverUrl/apiKey)
- **Jobs:** GET /api/job-queue-analytics returns individual jobs (not printer-centric QueueOverview)
- **Filament:** SetActiveSpool → PrinterServiceProtocol.setActiveSpool(printerId:spoolId:) + loadFilament/unloadFilament
- **Job queue pause/resume:** Lives on JobQueueAnalyticsController (/api/job-queue-analytics/jobs/{id}/pause|resume), not JobQueueController
- **Filename mapping:** GcodeFile.Name (user-uploaded), not GcodeFile.FileName (GUID disk name)

### Completed Implementations (2026-03-06 → 2026-03-08)
1. **MVP Phase (2026-03-06):** 7 screens (Login, Dashboard, Printers, Printer Detail, Jobs, Alerts, Settings), 5 ViewModels + Views, theme system with pf-prefixed colors
2. **Filament/Inventory Phase (2026-03-07):** Inventory tab (cylinder.fill), 6 new files (SpoolPickerView/ViewModel, SpoolInventoryView/ViewModel, AddSpoolView, ColorName extension)
3. **Spool Filtering & Enhancements (2026-03-08):** Material type chips, status filters (Available/In Use/Low/Empty), expanded search (color + location + comment), weight progress bar, in-use badge, SwiftLint cleanup (28 violations)
4. **iPad Layout Pass (2026-03-07 → 2026-03-08):** Adaptive layouts via horizontalSizeClass; NavigationSplitView sidebar (iPad) vs TabView (iPhone); 2-column grids (PrinterList, DashboardView); 2-column detail layout (PrinterDetailView); form width cap (LoginView)
5. **Launch Screen (2026-03-08):** LaunchScreen.storyboard (centered 🌾 + "PrintFarmer" text), 3 color sets (LaunchBackground, LaunchText, LaunchAccent), pbxproj update (UILaunchStoryboardName)
6. **7 New Feature UIs (2026-03-08):** Maintenance Analytics, AutoPrint, Job Analytics, Predictive Insights, Dispatch Dashboard, Job History/Timeline, Uptime/Reliability (7 ViewModels + 11 Views, all iPad-adaptive)
7. **NFC Features (2026-03-08):** Printer NFC tag deep linking (printfarmer://printer/{UUID}), spool NFC tag writing with dual-record NDEF format (URI + text records), DeepLinkHandler URL parsing, AppRouter handoff mechanism
8. **Spool NFC Tag Writing (2026-03-08):** 6 work items (model, NFCService, DeepLinkHandler, AppRouter, UI badge, UI filter, UI write flow); hasNfcTag field added; writeSpoolTag() dual-record method; badge (green ✓ / gray −) per spool; "No NFC Tag" filter chip; context menu write flow with loading/error states
9. **APIClient Empty Response Handling (2026-03-08):** Modified execute<T: Decodable>() to return nil for Optional types on empty response bodies; non-Optional types still error (contract enforcement); tested via Optional<Any>.none as? T
10. **CI/CD Fixes (2026-03-08):** @preconcurrency import UserNotifications to handle UNNotificationSettings non-Sendable type in Swift 6 strict mode; TestFlight beta workflow (xcodebuild archive + fastlane pilot)
11. **Observable ViewModel Sheet Dismissal Pattern (2025-07):** SpoolPickerView sheet now explicitly resets showSpoolPicker = false in action method, not just relying on dismiss() from presented view

### Notable Implementation Details
- Server URL persisted in UserDefaults via APIClient.serverURLKey; auto-prepended https:// by LoginViewModel
- Theme colors all prefixed `pf` (pfBackground, pfCard, pfError, pfAccent, etc.) — use explicit Color.pfX form in ShapeStyle contexts
- Camera snapshot: service-fetched Data + AsyncImage fallback + "No camera" placeholder
- SpoolPickerView/AddSpoolView ready for NFC scan pre-fill integration
- Pull-to-refresh on all list views; swipe-to-delete on SpoolInventoryView with context menu
- ScrollViewReader + onChange pattern for scroll-to-highlight on NFC scan results
- Spool NFC write uses same NFCMessageWriteDelegate infrastructure as printer tags (dual-record: URI + text)
- DeepLinkHandler parses custom URL schemes via url.host and url.pathComponents; AppRouter.navigate(to:) uses Task.sleep(50ms) between path reset/append to avoid SwiftUI race condition

### Testing Infrastructure (2026-03-08)
- ViewModels + test infrastructure ready for unit testing (Ash's responsibility)
- MockSpoolService, MockScannerService stubs available; MockSpool fixtures include `hasNfcTag: nil` parameter
- XCUITest files ready (deferred to after target creation in Xcode)

---

## Latest Work: PrusaLink Temperature Display Fix (2026-03-08T23:47)

**Status:** Complete and committed  
**Task:** Fix temperature display on printer detail view for PrusaLink printers

### Problem
PrusaLink printers showed "--" for hotend and bed temperatures in PrinterDetailView, despite:
- Temperatures working correctly in list view (PrinterCardView)
- Web UI displaying them correctly
- Root cause: Backend's `/api/printers/{id}` endpoint (via `PrusaLinkClient.CreatePrinterDtoAsync()`) omits temperature fields from `PrinterDto`

### Solution
Modified `PrinterDetailView.temperatureSection()` to use nil-coalescing fallback:
```swift
printer.hotendTemp ?? viewModel.statusDetail?.hotendTemp
printer.bedTemp ?? viewModel.statusDetail?.bedTemp
```

This pattern:
- **Backend-agnostic:** Works for all printer types (Moonraker, Bambu, PrusaLink) without conditional logic
- **Preserves list data:** Uses list-view temps when available (Moonraker/Bambu)
- **Falls back gracefully:** Uses status endpoint temps for PrusaLink's missing detail temps

### Build Status
✓ Clean build, no warnings  
✓ Committed to development branch

### Backend Follow-up
`PrusaLinkClient.CreatePrinterDtoAsync()` should also be fixed to include temp fields (backend team item).

### Related Decisions
- **Decision: Fall Back to StatusDetail for Temperature Display** → decisions.md
- **Decision: APIClient Empty Response Handling for Optional Types** → decisions.md

---

## Learnings

### Swift 6 & Concurrency
- **@preconcurrency import for Apple frameworks:** When Apple types like `UNNotificationSettings`, `CLLocation`, etc. aren't Sendable yet, use `@preconcurrency import` to suppress the error. Don't use `nonisolated(unsafe)` on local variables — that's for stored properties only.
- **Optional pattern matching:** `if case SpoolScanError.cancelled = error as? SpoolScanError` fails because `as?` returns Optional. Use `if let scanError = error as? SpoolScanError, case .cancelled = scanError` instead.
- **Optional type detection at runtime:** Use `Optional<Any>.none as? T` to check if the generic type `T` is an Optional.

### NFC & Deep Linking
- **SwiftUI NavigationPath race condition:** Resetting NavigationPath to empty and immediately appending a new destination causes SwiftUI to attempt in-place update instead of pop-then-push. Fix: Insert `Task.sleep(for: .milliseconds(50))` between reset and append, wrapped in `Task { @MainActor in }`.
- **Custom URL scheme parsing:** `url.host` gives the first path segment (`printfarmer://spool/42` → host = "spool"). Path components after host are in `url.pathComponents`.
- **Dual-record NDEF pattern:** URI record (for in-app deep links) + text record (for universal NFC readers). Both use `NFCMessageWriteDelegate`. Mirrors printer tag implementation.
- **iPhone-only Core NFC:** iPads do NOT support Core NFC — feature restricted to iPhone devices only.

### API & Empty Responses
- **Empty response handling for Optional types:** When API returns 204 No Content or 200 with empty body, check `data.isEmpty` before JSON decode. Return `nil` for Optional types; throw error for non-Optional (contract enforcement).
- **PrusaLink temperature fallback:** When same data available from multiple endpoints with different completeness, prefer richer source or merge both.

### Filament & Spool UI
- **Immutable struct field updates:** SpoolmanSpool has all `let` properties — updating a single field requires reconstructing entire struct. Use helper methods like `markSpoolNFCWritten()` for clarity.
- **Filter chip pattern:** Single-purpose toggle chip with capsule background, placed in HStack with Spacer() for left-alignment, below status filter chips.
- **Optional coalescing in filters:** `($0.hasNfcTag ?? true) == false` treats missing field as "has NFC".

### CI/Build
- **CI error vs local build:** Release archive uses `-O` optimization (not `-Onone`), which can trigger stricter checking. Always verify with `xcodebuild archive`.
- **Parse CI logs thoroughly:** Search for `: error:`, `ARCHIVE FAILED`, `signal`, `Segmentation fault`, `FAILED`, `fatal:`. Sometimes compiler crashes without clear messages — check "build commands failed" section.
- **Tag retag workflow:** Delete remote first: `git push release :refs/tags/TAG && git tag -d TAG && git tag TAG main && git push release TAG`.
- **Predictive Insights empty response fix:** The `predictJobFailure` endpoint can return empty body when no predictions are available. Changed return type to `JobFailurePrediction?` across protocol/service/mock, and all model fields to use `decodeIfPresent` with sensible defaults. View now shows graceful "No predictions available" empty state instead of decode error. Same pattern applied to `getActiveAlerts`/`getMaintenanceForecast` (return `[]` on empty body).

### Local State Override Pattern (Set Filament Fix)
- **Problem:** `GET /api/printers/{id}` (PrinterDto) doesn't return `spoolInfo`, so after `setActiveSpool` succeeds, the UI still shows "Set Filament" because `printer.spoolInfo` is nil.
- **Solution:** `lastSetSpoolInfo` local override in ViewModel, constructed from the `SpoolmanSpool` we just set. `effectiveSpoolInfo` computed property merges server data with local override. Same nil-coalescing fallback pattern used for PrusaLink temperatures.
- **Key files:** `PrinterDetailViewModel.swift` (effectiveSpoolInfo, lastSetSpoolInfo), `PrinterDetailView.swift` (filamentSection uses viewModel.effectiveSpoolInfo), `Models.swift` (PrinterSpoolInfo memberwise init).
- **Applies to both paths:** spool picker selection AND NFC scan-to-load. Cleared on eject.

---

## Latest Work: Set Filament Button Visibility Fix (2026-03-09T00:08)

**Status:** Complete and committed  
**Task:** Fix "Set Filament" button remaining visible after successful spool assignment

### Problem
After `setActiveSpool` succeeds, the printer detail endpoint (`GET /api/printers/{id}`) returns `PrinterDto` without `spoolInfo`, causing the button to remain visible despite the spool being assigned.

### Solution
Implemented local state override pattern:
- `PrinterDetailViewModel.lastSetSpoolInfo: PrinterSpoolInfo?` populated immediately after successful `setActiveSpool`
- `effectiveSpoolInfo` computed property returns server `spoolInfo` when available, falls back to local override
- `PrinterDetailView.filamentSection()` reads `viewModel.effectiveSpoolInfo` instead of direct `printer.spoolInfo`

### Key Points
- Reused same nil-coalescing fallback pattern as PrusaLink temperature display
- Applies to both spool picker selection and NFC scan-to-load flows
- Button correctly hides after assignment; state cleared on spool eject
- Related Decision: **Local State Override for Filament Button After SetActiveSpool** → decisions.md

### Build Status
✓ Clean build, no warnings  
✓ Committed to development branch as 4b3f20c

---

## Latest Work: Material-First Spool Picker Redesign (2026-03-09T01:00)

**Status:** Complete and built successfully  
**Task:** Redesign SpoolPickerView to require material type selection BEFORE showing spools

### Problem
The existing picker loaded ALL 200 spools immediately, making selection slow and requiring users to manually filter by material type. The web UI had already moved to a two-step flow (material → spool) for better UX and performance.

### Solution
Implemented two-phase picker flow:

**Phase 1: Material Selection**
- Added `SpoolPickerPhase` enum (`.selectMaterial`, `.selectSpool`) to ViewModel
- Call `/api/spoolman/materials/available` endpoint to get material names with available spools
- Display clean List view with material names and chevron indicators
- QR/NFC scanning still available in this phase (bypasses material selection)

**Phase 2: Spool Selection**
- User selects material → loads ONLY spools of that material type via `listSpools(material: selectedMaterial)`
- Show existing spool list with SpoolRowView items
- "Back" button in toolbar returns to material selection
- Status filter chips and search remain available
- Material filter chips removed (redundant since material already selected)

**Scanning Flow Enhancement**
- QR/NFC scan bypasses material selection entirely
- Loads ALL spools, finds the scanned spool, auto-sets `selectedMaterial`, filters to that material, and auto-selects the spool
- Seamless experience: scan → dismiss with selected spool

### Key Changes

**Files Modified:**
1. `SpoolServiceProtocol.swift` — Added `listAvailableMaterials()` method
2. `SpoolService.swift` — Implemented `listAvailableMaterials()` calling `/api/spoolman/materials/available`
3. `SpoolPickerViewModel.swift` — Added phase state, `selectMaterial()`, `backToMaterialSelection()`, `loadMaterials()` methods; updated `loadSpools()` to use material filter; enhanced scan flow
4. `SpoolPickerView.swift` — Split into `materialSelectionView` and `spoolSelectionView`; dynamic title/toolbar based on phase; removed material filter chips from spool view
5. `MockSpoolService.swift` — Added `listAvailableMaterials()` stub and tracking

### Build Status
✓ Clean build, no warnings  
✓ All changes compile successfully on iOS 17+ simulator

### Related Patterns
- **Two-phase selection pattern:** Material → Spool reduces cognitive load and improves performance
- **Backend-driven material list:** Using `/materials/available` ensures only materials with actual inventory are shown
- **Bypass-on-scan pattern:** Direct ID lookup skips manual selection for QR/NFC workflows
- **NavigationStack phase switching:** Use phase enum + conditional view composition instead of navigation push


### Learnings from This Work

**Two-Phase Picker UI Pattern:**
- Use phase enum in ViewModel to control which view is shown
- Keep both phases in same NavigationStack (not separate sheets/navigation pushes)
- Dynamic toolbar: "Cancel" in phase 1, "Back" in phase 2
- Keep scanning buttons visible in both phases for seamless QR/NFC flow

**Backend Integration:**
- `/api/spoolman/materials/available` returns `[String]` — just material names with available spools
- Prefer specialized "available" endpoints over loading everything and client-side filtering
- Material filter param on `listSpools()` keeps the load fast and focused

**Scan Flow Architecture:**
- When scanned spool ID is found, bypass phase 1 by setting material + phase + filtered spools
- Load without material filter temporarily to find the spool, then filter down
- Auto-selection with `onAutoSelect` callback dismisses picker immediately after scan

## 12. Material-First Spool Picker Redesign (2026-03-09)

**Orchestration Log:** `.squad/orchestration-log/2026-03-09T0150-ripley.md`

Completed two-phase spool picker flow aligned with web UI:
- **Phase 1:** Load material types from `/api/spoolman/materials/available`, user selects one
- **Phase 2:** Load spools of selected material, existing filter/search flow
- **Scanning exception:** QR/NFC bypasses phase 1, auto-sets material + auto-selects
- **Files:** SpoolPickerViewModel (phase enum, loadMaterials, selectMaterial), SpoolPickerView (split views, dynamic toolbar), SpoolService (listAvailableMaterials), MockSpoolService (stub)
- **Outcome:** ✅ Performance improved (20 spools vs 200), UX simplified, web UI aligned

**Lambert Integration:** New SpoolService.listAvailableMaterials() no contract-breaking changes.
**Ash Integration:** Material selection flow + back-navigation paths ready for test coverage.

## 13. Public Repo Readiness Prep (2025-07)

**Status:** Complete and committed (a1c74a2)
**Task:** Fix all public repo readiness issues from Dallas's audit

### Changes
- **LICENSE:** Added MIT License with OlyForge3D copyright (2025-present)
- **README.md:** Professional project overview with tech stack, architecture, getting started, and configuration sections
- **AppConfig.swift:** Changed hardcoded dev IP `10.0.0.20:5000` → `localhost:5000` as default (env var override still works)
- **.gitignore:** Added patterns for secrets & certificates (.env, .p8, .p12, .pem, .key, secrets/)

### Learnings
- **Default config safety:** Always use `localhost` as default server URL, never a LAN IP. Environment variable override handles real deployments.
- **gitignore layering:** Keep secret/cert patterns separate from build artifact patterns for clarity.

### NFC Tag Persistence
- **Always persist to backend after NFC write:** `markSpoolNFCWritten()` only updates local state — must also call `spoolService.updateSpool(id:, SpoolmanSpoolRequest(hasNfcTag: true))` so the flag survives refresh.
- **SpoolmanSpoolRequest needs parity with SpoolmanSpool:** Any new field on the response DTO that users can modify (like `hasNfcTag`) must also exist on the request DTO.
- **Key files:** `SpoolInventoryViewModel.writeNFCTag(for:)`, `FilamentModels.swift` (SpoolmanSpoolRequest).


---

## 14. Button Sizing & Touch Target Compliance (2026-03-09T21:06)

**Status:** Complete and committed  
**Agent:** Parker (UI/UX Designer)  
**Task:** Audit and fix button touch targets across all full-width action buttons

### Problem
Full-width action buttons were too short (~34-36pt), violating Apple Human Interface Guidelines (44pt minimum) and causing accessibility issues.

### Solution
Created `.fullWidthActionButton()` view modifier in `ActionButtonStyle.swift` with two levels:
- **Standard:** 44pt (Apple HIG compliance)
- **Prominent:** 50pt (critical actions: Start Print, Sign In, Emergency Stop)

Applied to 7 view files; also fixed LoginView height:22 bug during migration.

### Key Changes
- **Created:** `PrintFarmer/Views/Components/ActionButtonStyle.swift`
- **Modified:** LoginView, JobDetailView, PrinterDetailView, NFCScanButton, NFCWriteView, AutoPrintSection, MaintenanceAlertRow
- **Outcome:** ✅ Build passed, button sizing now compliant across app

### Design Guidelines
- Primary actions (Start Print, Sign In, Emergency Stop) use `.prominent` (50pt)
- Secondary actions (Pause, Cancel, Acknowledge) use standard (44pt)
- Font minimum `.subheadline` (avoid `.caption` on buttons)
- Weight `.semibold` for primary actions

### Integration Points
- **Ripley:** All future full-width buttons should use `.fullWidthActionButton()` for consistency
- **Related Decision:** Touch-Compliant Button Sizing System → decisions.md
