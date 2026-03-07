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

### MVP Screens Build (2026-03-06)
- **All 7 MVP screens built:** Dashboard, PrinterList, PrinterDetail, JobList, JobDetail, Notifications, Settings
- **6 reusable components:** StatusBadge, TemperatureView, PrintProgressBar, PrinterCardView, JobCardView, EmptyStateView
- **5 service protocols defined:** PrinterServiceProtocol, JobServiceProtocol, NotificationServiceProtocol, StatisticsServiceProtocol, SignalRServiceProtocol — in `Protocols/` directory
- **ViewModel pattern:** `@MainActor @Observable` with `configure()` for protocol-typed service injection. Services are optionals set via `.task` modifier in views.
- **Navigation wiring:** Each tab wraps a `NavigationStack(path:)` bound to AppRouter. Detail views pushed via `AppDestination` enum with `.navigationDestination(for:)`.
- **Tab change:** Replaced Locations tab (not MVP) with Notifications tab. Locations tab still exists but unused.
- **PFarmApp now creates ServiceContainer** and injects it as `@Environment` alongside router and authViewModel.
- **Platform guards:** iOS-only APIs (`navigationBarTitleDisplayMode`, `topBarTrailing`, `UIImage`, `UINotificationFeedbackGenerator`) wrapped in `#if os(iOS)` / `#if canImport(UIKit)` for SPM macOS build compatibility.
- **Lambert parallel work:** Lambert already built real NotificationService, StatisticsService, expanded PrinterService/JobService, full SignalR WebSocket implementation, and new models (PrinterStatusDetail, PrintJobStatusInfo, QueueOverview, MmuStatus, CommandResult, AppNotification). Had to reconcile my protocols and views with his actual types.
- **Key model differences from spec:** `AppNotification.id` is `String` not `UUID`; fields are `subject`/`body` not `title`/`message`; `NotificationType` uses job-specific cases (JobStarted, JobCompleted, etc.); `StatisticsSummary` has no printer counts (only job stats); `JobService.list()` returns `[QueueOverview]` (printer-centric) not `[PrintJob]` (job-centric).
- **JobListView redesign:** Shows QueueOverview (per-printer queue status) with Active/Queued/Available sections instead of individual job list, since the API returns printer-centric queue data.
- **DashboardView active jobs:** Shows printers currently running jobs (from Printer model's jobName/progress fields) rather than individual PrintJob items.
- **Global `destinationView(for:)` helper:** Marked `@MainActor` to avoid Swift 6 actor isolation warnings when constructing views with `@State` init parameters.
- **Snapshot handling:** PrinterDetailView loads snapshot as `Data` from `getSnapshot(id:)` and converts to `UIImage` on iOS. No URL-based `AsyncImage`.

### Critical Findings from Ash (2026-03-06 Post-Build)

**3 PrinterDetailViewModel Method Mismatches Found by Test Coverage:**

Ash's test suite discovered that PrinterDetailViewModel calls methods that don't exist on PrinterServiceProtocol:

| Issue | ViewModel Calls | Protocol Has | Status |
|-------|-----------------|--------------|--------|
| 1 | `snapshotURL(for:)` | `getSnapshot(id:) -> Data` | ⚠️ Method name mismatch; return type (URL vs Data) requires ViewModel conversion logic |
| 2 | `cancelPrint(id:)` | `cancel(id:) -> CommandResult` | ⚠️ Method name mismatch (cancelPrint vs cancel) |
| 3 | `setMaintenance(id:enabled:)` | `setMaintenanceMode(id:enabled:) -> CommandResult` | ⚠️ Method name mismatch (setMaintenance vs setMaintenanceMode) |

**Action Required:** Update PrinterDetailViewModel method calls to match PrinterServiceProtocol signatures. This is blocking the test suite integration.

**Context:** Lambert built the actual PrinterServiceProtocol with these exact method names. The ViewModel was built against an earlier protocol spec. Ripley needs to reconcile the implementation.

### Jobs Tab Redesign: Printer-Centric → Job-Centric (2025-07-17)
- **Problem:** Jeff reported the Jobs tab showed "available printers" instead of print jobs. The old design used `GET /api/job-queue` which returns `[QueueOverview]` (one row per printer), making the tab feel like a printer list.
- **Fix:** Switched to `GET /api/job-queue-analytics` which returns `[QueuedPrintJobWithFileMetaDto]` — actual individual jobs with full metadata.
- **New models added:** `QueuedPrintJobResponse`, `QueuedJobInfo`, `QueuePrinterMeta`, `QueueGcodeFileMeta`, `QueueStats` in Models.swift
- **Protocol change:** Added `listAllJobs() -> [QueuedPrintJobResponse]` to `JobServiceProtocol`. Kept old `list() -> [QueueOverview]` for backward compat.
- **View redesign:** Jobs tab now shows three sections: "Printing" (active jobs with progress bars), "In Queue" (queued jobs with position/priority), "Recent" (completed/failed, collapsible). No more "Available printers" section.
- **Backend insight:** The `/api/job-queue-analytics` controller has rich endpoints: stats, history, timeline, per-printer jobs, duration analytics. Only using the main listing for now.
- **Key detail:** Analytics DTOs use `String` IDs (not UUID). Added `jobUUID` computed property for navigation to `JobDetailView` which expects UUID.

### Theme Support: Light + PrintFarmer Dark (2025-07-17)
- **3 new files in `PrintFarmer/Theme/`:** `Color+Hex.swift` (hex initializer for Color & UIColor), `ThemeColors.swift` (all PrintFarmer branded colors as adaptive `Color` statics), `ThemeManager.swift` (@Observable class managing system/light/dark preference via UserDefaults).
- **Adaptive color pattern:** `Color.adaptive(light:dark:)` uses `UIColor { traitCollection in ... }` on iOS for dynamic trait-based colors; falls back to light hex on macOS/SPM.
- **All theme colors prefixed `pf`:** `pfBackground`, `pfCard`, `pfBorder`, `pfAccent`, `pfSuccess`, `pfError`, `pfWarning`, `pfTextPrimary/Secondary/Tertiary`, `pfSecondaryAccent`, `pfButtonPrimary`, `pfHomed`, `pfNotHomed`.
- **ShapeStyle gotcha:** Custom `Color` static properties can't be used with dot syntax (`.pfCard`) in `.background()`, `.foregroundStyle()`, `.strokeBorder()` — must use `Color.pfCard` explicitly because those APIs accept `ShapeStyle` and Swift's implicit member lookup doesn't resolve `Color` statics on `ShapeStyle`.
- **ThemeManager injected via `.environment()`** in PFarmApp; theme picker added to SettingsView Appearance section; `.preferredColorScheme()` applied at root.
- **Global tint set to `.pfAccent` (green #10b981)** — makes all buttons, links, pickers brand-green.
- **Views updated:** Dashboard, PrinterDetail, JobDetail, LoginView, NotificationsView, PrinterListView, StatusBadge, PrinterCardView, PrintProgressBar all use `pf*` colors for cards, borders, status indicators, progress bars.
- **PrintProgressBar default color changed** from `.blue` to `.pfAccent` (green) — brand-consistent progress bars.
- **Status colors unified:** Printing→pfSecondaryAccent (blue), Ready→pfSuccess (green), Paused→pfWarning (amber), Error→pfError (red), Offline→pfTextTertiary.
- **Pre-existing build errors:** APIClient.swift has Swift 6 concurrency warnings for ISO8601DateFormatter statics; not related to theme work.

### Xcode pbxproj Theme File Registration (2025-07-17)
- **Problem:** 3 Theme files (Color+Hex.swift, ThemeColors.swift, ThemeManager.swift) existed on disk in `PrintFarmer/Theme/` but were not referenced in `PrintFarmer.xcodeproj/project.pbxproj`. SPM auto-discovers sources so `swift build` worked, but Xcode builds failed with 22 errors (`Type 'Color' has no member 'pfCard'` etc).
- **Fix:** Manually edited project.pbxproj to add: 3 PBXFileReference entries, 3 PBXBuildFile entries (linked to Sources build phase), a new "Theme" PBXGroup under the PrintFarmer group, and 3 entries in PBXSourcesBuildPhase for the PrintFarmer target.
- **Pattern for future files:** When adding files outside Xcode (e.g., via squad agents), 4 pbxproj touches are needed per file: PBXFileReference, PBXBuildFile, PBXGroup child, and PBXSourcesBuildPhase entry. UUIDs are 24-char uppercase hex and must not collide.
- **Validation:** Always run `plutil -lint PrintFarmer.xcodeproj/project.pbxproj` after edits — pbxproj is plist-format and fragile.

### PrinterDetailView Blank Page Fix (2025-07-18)
- **Root cause:** Two bugs combined to produce a blank page:
  1. `PrinterDetailView.body` had three conditional branches (loading+nil, error+nil, printer) but **no else fallback**. The initial state (isLoading=false, printer=nil, errorMessage=nil) matched none of them → blank Group.
  2. `PrinterDetailViewModel.loadPrinter()` set `isLoading = true` AFTER a `guard let printerService` check. If the guard failed (service not yet configured), the method returned silently with no state change, leaving the view permanently blank.
- **Fix applied:**
  - Reordered view conditionals: content first (printer non-nil), error second, else shows ProgressView. This guarantees something always renders.
  - Moved `isLoading = true` before the guard in `loadPrinter()`. If the guard fails, an error message is now set instead of silent return.
- **Backend note:** `GET /api/printers/{id}` returns `PrinterDto` which lacks `InMaintenance`/`IsEnabled` fields present in `CompletePrinterDto` (list endpoint). Our Printer model handles this via `decodeIfPresent` defaults, so decoding works but maintenance status may show incorrect after detail fetch. Separate issue to address later.

### QA Audit Fixes (2025-07-18 → 2026-03-07)
- **C1 — AppRouter @MainActor:** Added `@MainActor` annotation to AppRouter. It manages NavigationPath and selectedTab (UI state) and must be main-actor-isolated.
- **C2 — AuthViewModel @MainActor:** Replaced `@unchecked Sendable` with `@MainActor`. Required `nonisolated deinit` and `nonisolated(unsafe)` for the NotificationCenter observer to satisfy Swift 6 concurrency rules.
- **JobListView & NotificationsView error display:** Both ViewModels set `errorMessage` on failure but views never showed it. Added `ContentUnavailableView` error states with retry buttons before the empty state checks.
- **17 hardcoded colors replaced:** All `.red`, `.orange`, `.blue`, `.yellow`, `.purple`, `.cyan` instances replaced with theme colors (`pfError`, `pfWarning`, `pfHomed`, `pfNotHomed`, `pfMaintenance`, `pfAssigned`, `pfTempMild`). Added 3 new colors to ThemeColors.swift: `pfMaintenance` (purple), `pfAssigned` (teal), `pfTempMild` (yellow).
- **Placeholder navigation destinations:** Replaced empty `Text()` for locationDetail, createJob, createPrinter with `ContentUnavailableView` "Coming Soon" screens.
- **Dashboard empty state:** Added `EmptyStateView` when printer list is empty instead of showing "0" counts in summary cards.
- **Accessibility labels:** Added `.accessibilityLabel()` to StatusBadge (all instances), TemperatureView (combined element with label+current+target), PrinterListView cards (printer name+state+online), and PrinterDetailView action buttons (maintenance toggle, emergency stop).
- **ShapeStyle gotcha revisited:** When using `Color.pfError` in `.tint()`, must use explicit `Color.pfError` form since `.tint()` accepts `ShapeStyle` and implicit member lookup won't find custom `Color` statics.

### Cross-Agent Learning (2026-03-07 QA Batch)
- **Lambert completed:** SignalR date decoder (dual-format), safe URLComponents, 401 auto-logout pattern, token expiry pre-check (5-min buffer), silent error suppression in secondary data loads (status, currentJob, stats)
- **Lambert's token validation:** AuthService.isTokenExpired() checked via closure before every APIClient request. 401 posts Notification.Name.sessionExpired → AuthViewModel logout → LoginView
- **Pattern alignment:** AppRouter & AuthViewModel both now @MainActor; all ViewModels follow same pattern
- **Decision record:** All QA audit fixes merged into decisions.md (decision #7 theme system, #8 color extensions, #9 printer detail fix, #10 jobs tab fix)
- **Outcome:** All critical + important issues resolved; build clean; commit 7fb1419

### Camera Snapshot UI Enhancement (2025-07-18)
- **PrinterDetailView camera section redesigned:** Now always visible — shows snapshot from `snapshotData` (service-fetched Data), falls back to `AsyncImage` from `printer.cameraSnapshotUrl` (direct URL), or shows "No camera available" placeholder when neither exists.
- **Refresh button added:** Camera section header has a refresh button that calls `viewModel.refreshSnapshot()` — only shown when snapshot data or URL is available.
- **`isLoadingSnapshot` property** added to PrinterDetailViewModel to disable refresh button during load.
- **Pull-to-refresh was already implemented** on all four list views (PrinterListView, JobListView, NotificationsView, DashboardView) and PrinterDetailView from the MVP build.
- **`AsyncImage` fallback pattern:** When the authenticated `getSnapshot(id:)` service call fails or hasn't loaded, we try the direct `cameraSnapshotUrl` from the Printer model via AsyncImage. This URL is a direct public URL from the backend's CompletePrinterDto.

### Phase 1 Filament Management UI (2025-07-18)
- **6 new files created:** SpoolPickerView, SpoolInventoryView, AddSpoolView (in Views/Filament/), SpoolPickerViewModel, SpoolInventoryViewModel, AddSpoolViewModel (in ViewModels/)
- **PrinterDetailView extended:** New "Filament" section showing active spool info (color swatch, material, vendor, remaining weight progress bar), "Load Filament" button → SpoolPickerView sheet, "Eject" button → unloads filament. Empty state when no spool loaded.
- **PrinterDetailViewModel extended:** Added `showSpoolPicker`, `loadFilament()`, `ejectFilament()`, `setActiveSpool(_:)` using `PrinterServiceProtocol.setActiveSpool(printerId:spoolId:)`, `.loadFilament(printerId:)`, `.unloadFilament(printerId:)`.
- **New Inventory tab:** Added `AppTab.inventory` to AppRouter + ContentView TabView. SF Symbol: `cylinder.fill`. SpoolInventoryView with search, swipe-to-delete, pull-to-refresh, "+" toolbar button → AddSpoolView sheet.
- **AddSpoolView:** Form with material picker, vendor picker, color swatches + hex input, total/spool weight fields. References data from SpoolService.listMaterials/listVendors/listFilaments. Dismisses on save.
- **Lambert's work consumed:** SpoolService (actor), SpoolServiceProtocol, FilamentModels (SpoolmanSpool, SpoolmanFilament, SpoolmanVendor, SpoolmanMaterial, SpoolmanPagedResult, SpoolmanSpoolRequest, SetActiveSpoolRequest) — all already built and working.
- **Duplicate PrinterSpoolInfo removed** from FilamentModels.swift (kept canonical version in Models.swift with custom decoder).
- **Platform guards:** `#if os(iOS)` for `.keyboardType()`, `.textInputAutocapitalization()`, `.topBarTrailing` toolbar placement.
- **pbxproj registration:** 9 new files + 1 new group (Filament) registered in project.pbxproj. Also registered Lambert's 3 unregistered files (FilamentModels.swift, SpoolService.swift, SpoolServiceProtocol.swift).
- **Phase 2 NFC note:** SpoolPickerView and AddSpoolView are ready for OpenSpool/OpenPrintTag NFC scan integration (Phase 2). Future "Scan NFC" button will auto-populate spool data from tag.
- **SPM build clean:** `swift build` succeeds with zero errors.

### Phase 2 Scanning UI (2025-07-19)
- **3 new view files created:** QRScannerView (VisionKit DataScannerViewController wrapper), NFCScanButton (reusable NFC scan button component), NFCWriteView (sheet for writing NFC tags from spool data)
- **SpoolPickerView extended:** Added QR scan and NFC scan toolbar buttons. QR scan presents QRScannerView as sheet; NFC scan triggers SpoolScannerProtocol.scan(). Both auto-select spool on successful ID match, or navigate to AddSpoolView with pre-filled data for new spool data.
- **SpoolPickerViewModel extended:** Added `isQRScannerPresented`, `isScanning`, `scanError`, `scannedSpoolData` state. Added `handleQRScan(qrText:)` with QR text parser (supports plain int, URL path, JSON formats), `handleNFCScan()`, `handleScanResult(_:)` shared logic, `parseSpoolId(from:)` private helper.
- **AddSpoolView/ViewModel extended:** Accept optional `ScannedSpoolData` parameter. Pre-fills material, color, vendor, weight, diameter, temperature. Shows "Pre-filled from NFC tag scan" banner when `isPrefilledFromScan` is true. Added `diameterMm` and `extruderTempC` fields to ViewModel.
- **PrinterDetailView extended:** Added NFCScanButton "Scan to Load" in filament section (both when spool is loaded and when empty). Compact variant when spool loaded, full-width when empty. Added NFC scan error alert and scanned data sheet.
- **PrinterDetailViewModel extended:** Added `handleNFCScanToLoad()` method, `loadSpoolById(_:)` private helper, `nfcScanError`, `nfcScannedData`, `showScannedDataSheet` state, `configureNFCScanner(_:)` for DI.
- **SpoolInventoryView extended:** Added context menu on each spool row with "Write NFC Tag" option. Long-press presents NFCWriteView as sheet via `.sheet(item:)`.
- **SpoolmanSpool used as `.sheet(item:)` binding** — works because it conforms to `Identifiable` (id: Int).
- **NFCScanButton uses `.bordered` style only** — ternary between `.bordered` and `.borderedProminent` doesn't work with Swift's type system for ButtonStyle.
- **QRScannerView iOS-only:** Wrapped in `#if os(iOS)` since VisionKit DataScannerViewController is iOS-only. AVCaptureDevice permission check on `.task`.
- **pbxproj:** 3 new files registered with E1-prefixed UUIDs (non-conflicting with Lambert's). plutil lint passes.
- **Lambert dependency:** Views reference SpoolScannerProtocol (Lambert's file, already committed). NFCService.writeTag() not yet wired in NFCWriteView — placeholder returns false until Lambert delivers.

## Cross-Agent Context (2026-03-07T16:03:00Z)

**Lambert (Filament Models & Services) provides:**
- ✓ SpoolServiceProtocol — 8 methods: list, get, create, update, delete; pagination (limit/offset)
- ✓ Extended PrinterServiceProtocol — setActiveSpool(_:), loadFilament(), unloadFilament(), changeFilament()
- ✓ FilamentModels — SpoolmanSpool, SpoolmanFilament, SpoolmanVendor, SpoolmanMaterial, SpoolmanPagedResult
- ✓ APIClient.patch() — HTTP PATCH support
- **Delivered:** All service contracts finalized and tested (committed 758e10a)

**Ash (Test Coverage) needs:**
- MockSpoolService — full mock with call tracking
- 3 new ViewModel tests — SpoolPickerViewModel, SpoolInventoryViewModel, AddSpoolViewModel
- Integration with existing mock infrastructure

## 2026-03-07T16:34Z — Phase 2 Scanning UI (SUCCESS)

**Batch:** Scanning UI (QR + NFC)  
**Outcome:** ✅ Delivered 3 new + 6 modified files, builds clean

**What Was Built:**
- QRScannerView (VisionKit UIViewControllerRepresentable)
- NFCScanButton (reusable, checks device support)
- NFCWriteView (tag write UI with status indicators)
- SpoolPickerView: "Scan QR" button, QR integration
- AddSpoolView: pre-fill from scanned data
- SpoolInventoryView: NFC write action
- PrinterDetailView: NFC scan button
- ViewModels: parseSpoolId(), prefill(), scanner config

**Cross-Team Impact:**
- Lambert: Services (QRSpoolScannerService, NFCService) ready to integrate
- Ash: ViewModel test methods ready, MockScannerService available
- Dallas: Navigation impact minimal, AppRouter verified

**Known Limitations:**
- NSCameraUsageDescription, NFCReaderUsageDescription not in Info.plist (Xcode target required)
- NFCWriteView.onWrite not yet wired to Lambert's NFCService.writeTag()

**Next Steps:**
- Add Info.plist keys via Xcode target
- Device QA testing
- Wire NFCWriteView to Lambert's service
