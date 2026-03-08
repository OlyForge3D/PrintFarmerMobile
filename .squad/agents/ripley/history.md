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

### Notable Implementation Details
- Server URL persisted in UserDefaults via APIClient.serverURLKey; auto-prepended https:// by LoginViewModel
- Theme colors all prefixed `pf` (pfBackground, pfCard, pfError, pfAccent, etc.) — use explicit Color.pfX form in ShapeStyle contexts
- Camera snapshot: service-fetched Data + AsyncImage fallback + "No camera" placeholder
- SpoolPickerView/AddSpoolView ready for NFC scan pre-fill integration (Phase 2)
- Pull-to-refresh on all list views; swipe-to-delete on SpoolInventoryView with context menu
- ScrollViewReader + onChange pattern for scroll-to-highlight on NFC scan results
- AutoPrintSection embedded in PrinterDetailView (both iPhone/iPad); Dispatch Dashboard as DashboardView card; Job Analytics/History accessible from JobListView toolbar

### Testing Infrastructure (2026-03-08)
- ViewModels + test infrastructure ready for unit testing (Ash's responsibility)
- MockSpoolService, MockScannerService stubs available
- XCUITest files ready (deferred to after target creation in Xcode)

#### 7-Feature UI Build & Service Integration (2026-03-08)
- **Built 7 ViewModels + 11 Views** across Maintenance, AutoPrint, Job Analytics, Predictive, Dispatch, Job History, Uptime
- **Pattern consistency:** All follow @MainActor @Observable + configure(services:) + loadX() async
- **Navigation:** Added AppTab.maintenance + 6 AppDestination cases for drill-down
- **iPad-adaptive:** All new views use horizontalSizeClass for multi-column layouts
- **Build status:** 33 new files added, ~10 source mismatches resolved, clean build
- **Parallel execution:** Lambert's 5 services (MaintenanceService, AutoPrintService, JobAnalyticsService, PredictiveService, DispatchService) built in parallel with UIViews; Build verification caught/fixed all integration issues
- **Key learnings:** ViewModel pattern scales cleanly; service layer design must complete before UI references; consistent naming critical for parallel execution; source mismatch resolution via build verification prevents compile surprises

---

## Recent Work (2026-03-08, Completed 2026-03-08T05:16Z → 2026-03-08T21:51Z)

### NFC Printer Tag Deep Linking (2026-03-08)
- `printfarmer://printer/{UUID}` URL scheme registered in Info.plist via CFBundleURLTypes
- DeepLinkHandler.swift parses URLs where `url.host == "printer"` and first pathComponent is the UUID
- NFCMessageWriteDelegate writes full NFCNDEFMessage (URI + text record) vs NFCWriteDelegate which writes raw OpenSpool payload bytes
- `writePrinterTag` on NFCService is concrete (not on SpoolScannerProtocol) — accessed via `nfcScanner as? NFCService` cast in ViewModel
- AppRouter.pendingNFCReadyPrinterId is the handoff mechanism for NFC "mark ready" deep links — checked in PrinterDetailView's .task
- AutoPrintServiceProtocol.markReady(printerId:) is the existing API for marking printers ready
- Adding files to Xcode project requires unique 24-char hex IDs in pbxproj; must verify against existing IDs to avoid collisions
- Key files: DeepLinkHandler.swift (Navigation/), NFCService.swift (NFCMessageWriteDelegate), AppRouter.swift (navigate method), PFarmApp.swift (.onOpenURL)

### NFC Navigation Race Condition Fix (2026-03-08)
- **NavigationPath reset + append race condition** — SwiftUI batches synchronous NavigationPath mutations in the same block. Resetting to empty and immediately appending a new destination in `AppRouter.navigate(to:)` caused SwiftUI to attempt an in-place update instead of pop-then-push, leaving the user stuck on the old printer.
- **Fix pattern:** Insert `Task.sleep(for: .milliseconds(50))` between NavigationPath reset and append, wrapped in `Task { @MainActor in }`. This forces SwiftUI to process the pop (empty path) in one render pass before the push (new destination) in the next.
- **Push notification observer gap** — `PushNotificationManager` posts `.pushNotificationTapped` but PFarmApp.swift had no `.onReceive` for it. Added `#if canImport(UIKit)` guarded `.onReceive` handler that extracts the `"link"` URL from userInfo, parses it via `DeepLinkHandler`, and calls `router.navigate(to:)`.
- **Lesson:** When SwiftUI NavigationPath changes need to pop-then-push, always separate the mutations across render cycles with an async delay.

---

## Upcoming Work: Spool NFC Tag Writing Feature (2026-03-08)

**Status:** Scoped by Dallas, ready for dev  
**Owned by:** Dallas (lead), WI-3/4/6 assigned to Ripley  
**Effort:** 4.5 hours (badge + filter + write flow)  
**Blocking on:** Backend WI-1 (Jeff, 1h) → Model WI-2 (Lambert, 15m)

### Your Responsibilities (WI-3, WI-4, WI-6)

**WI-3: NFC Indicator Badge (1.5h)**
- Edit SpoolInventoryView to add visual badge next to each spool:
  - Green checkmark (✓) if `hasNfcTag == true`
  - Gray dash (−) if `hasNfcTag == false`
  - Accessibility labels: "NFC tag present" / "NFC tag not written"
  - Position: Next to spool name or right-aligned column
- Snapshot test both states

**WI-4: "No NFC Tag" Filter Chip (1h)**
- Edit SpoolInventoryViewModel: add `showOnlyMissingNFC: Bool = false`
- Update `filteredSpools` to filter by hasNfcTag:
  ```swift
  if showOnlyMissingNFC {
      result = result.filter { ($0.hasNfcTag ?? true) == false }
  }
  ```
- Edit SpoolInventoryView: add filter chip that toggles `showOnlyMissingNFC`
- Default OFF (show all); tap toggles on

**WI-6: Write Button & Flow (2h)**
- Edit SpoolInventoryView to add "Write NFC" button (context menu 3-dot recommended)
- Show loading state while writing: `.disabled(viewModel.isWritingNFC)`
- Show error alert if `viewModel.writeNFCError != nil`
- Show success highlight for 0.5s after write (optional)
- UX flow:
  1. User taps "Write NFC" → "Hold your iPhone near the NFC tag" modal
  2. User holds near tag
  3. Either success/reload OR error + retry option

### Parallel Work (While Waiting for WI-1)
- Review SpoolInventoryView structure (line layout, context menu patterns)
- Plan badge positioning and colors
- Sketch filter chip placement (existing material chips as reference)
- Prepare snapshot test cases (HasNFC, NoNFC, FilterActive states)

### Key Architecture Notes
- Filter logic uses optional coalescing: `($0.hasNfcTag ?? true) == false` (treats missing field as "has NFC")
- No new data sources; only filtering existing `spools` array
- Badge colors: `.secondary` tint for missing tags (consistent with existing design)
- Write button goes in context menu, not as trailing button (less clutter)

### What Lambert Will Deliver (Needed for Your WI-3/4)
- **WI-2 (15m):** `hasNfcTag: Bool?` field added to SpoolmanSpool model
- **WI-5 (1.5h):** `writeNFCTag(for spool:)` method in SpoolInventoryViewModel + state props (`isWritingNFC`, `writeNFCError`)

### Coordination Notes
- Lambert finishes WI-2/5 in parallel with your WI-3/4; you can start implementation once he confirms the model/viewmodel changes
- Write button (WI-6) depends on WI-5 complete — don't start until ViewModel method exists
- Ash's tests (WI-8) will use MockSpoolService with varying `hasNfcTag` values — coordinate on mock spool fixtures

### Success Criteria
- Spool list shows badge (green ✓ / gray −) for each spool
- Filter works: tap chip, list shows only `hasNfcTag == false`
- Write button launches NFC session (uses existing NFCService infra)
- After successful write, `hasNfcTag` refreshes from backend
- All snapshot tests pass
- No regression in existing spool/filament features

### Next Steps
1. **Await:** Jeff's backend WI-1 API contract confirmation
2. **Await:** Lambert's WI-2 model changes (15m)
3. **Start:** WI-3 (badge) — can parallelize with WI-4
4. **Gate:** WI-6 (write flow) blocked until WI-5 viewmodel complete
5. **Coordinate:** Ash's test fixtures during WI-6 development

---

### Spool NFC Tag Writing Feature — Implemented (2026-03-08)

**All 6 work items completed in a single pass:**

1. **Model (WI-1):** Added `hasNfcTag: Bool?` to `SpoolmanSpool` in `FilamentModels.swift` — optional for backward compat with API responses
2. **NFCService (WI-2):** Added `writeSpoolTag(spool:)` method with dual-record NDEF format:
   - Record 1: URI `printfarmer://spool/{id}` for deep-link navigation
   - Record 2: Text payload with OpenSpool JSON (`material`, `color_hex`, `brand`, `weight_g`, `spoolman_id`)
   - Reuses existing `NFCMessageWriteDelegate` infrastructure (same as printer tags)
   - Legacy single-record `writeTag(spool:)` preserved for backward compat
3. **DeepLinkHandler (WI-3):** Added `.spoolDetail(id: Int)` case, parsing `printfarmer://spool/{id}` URLs via switch on `url.host`
4. **AppRouter (WI-3b):** Added `pendingSpoolHighlightId: Int?` handoff; navigates to inventory tab and highlights spool
5. **UI Badge (WI-4):** NFC indicator on every spool row — green `wave.3.right` if `hasNfcTag == true`, gray `minus` otherwise; accessibility labels included
6. **UI Filter (WI-5):** "No NFC Tag" filter chip using `wave.3.right.circle` SF Symbol, toggles `showOnlyMissingNFC` in ViewModel
7. **UI Write Flow (WI-6):** Context menu "Write NFC Tag" only shown when `spool.hasNfcTag != true`; wired to `viewModel.writeNFCTag(for:)` which calls `NFCService.writeSpoolTag()` and updates local `hasNfcTag` state on success

**Key files modified:**
- `PrintFarmer/Models/FilamentModels.swift` — hasNfcTag field
- `PrintFarmer/Services/NFCService.swift` — writeSpoolTag() dual-record method
- `PrintFarmer/Navigation/DeepLinkHandler.swift` — spool route parsing
- `PrintFarmer/Navigation/AppRouter.swift` — pendingSpoolHighlightId + navigate
- `PrintFarmer/ViewModels/SpoolInventoryViewModel.swift` — filter, write state, markSpoolNFCWritten
- `PrintFarmer/Views/Filament/SpoolInventoryView.swift` — badge, filter chip, write flow wiring

## Learnings

### Spool NFC Dual-Record NDEF Pattern (2026-03-08)
- **Dual-record NDEF mirrors printer tag pattern:** URI record for in-app deep links + text record for universal NFC readers. Both use `NFCMessageWriteDelegate` (not `NFCWriteDelegate` which writes raw bytes).
- **SpoolmanSpool is a Codable struct with all `let` properties** — updating a single field requires reconstructing the entire struct. The `markSpoolNFCWritten()` helper does this explicitly.
- **Optional pattern matching gotcha in Swift:** `if case SpoolScanError.cancelled = error as? SpoolScanError` fails because `as?` returns Optional and pattern matching on Optional is ambiguous. Use `if let scanError = error as? SpoolScanError, case .cancelled = scanError` instead.
- **DeepLinkHandler URL parsing:** `url.host` gives the first path segment of custom URL schemes (`printfarmer://spool/42` → host = "spool"). Path components after host are in `url.pathComponents`.
- **Filter chip pattern:** Single-purpose toggle chip with capsule background, placed in its own `HStack` with `Spacer()` for left-alignment, below the status filter chips.

---

---

## 2026-03-08T21:51Z — Spool NFC Tag Writing Feature — COMPLETE

**Status:** ✅ Implemented (Ripley) & Ready for Testing (Ash)

### All 6 Work Items Completed

**1. Model (WI-1):** Added `hasNfcTag: Bool?` to `SpoolmanSpool` in `FilamentModels.swift`
   - Optional for backward compatibility with backend responses
   - All new test fixtures include `hasNfcTag: nil` parameter

**2. NFCService (WI-2):** Added `writeSpoolTag(spool:)` method with dual-record NDEF format
   - Record 1: URI `printfarmer://spool/{id}` for deep-link navigation
   - Record 2: Text payload with OpenSpool JSON (`material`, `color_hex`, `brand`, `weight_g`, `spoolman_id`)
   - Reuses existing `NFCMessageWriteDelegate` infrastructure (same as printer tags)
   - Legacy single-record `writeTag(spool:)` preserved for backward compat

**3. DeepLinkHandler (WI-3):** Added `.spoolDetail(id: Int)` case, parsing `printfarmer://spool/{id}` URLs
   - URL parsing via `url.host` and `url.pathComponents`
   - Coordinates with AppRouter for navigation

**4. AppRouter (WI-3b):** Added `pendingSpoolHighlightId: Int?` handoff
   - Navigates to inventory tab and highlights specific spool
   - Used by DeepLinkHandler and NFC write success flow

**5. UI Badge (WI-4):** NFC indicator on every spool row
   - Green `wave.3.right` if `hasNfcTag == true`
   - Gray `minus` if `hasNfcTag == false`
   - Accessibility labels: "NFC tag present" / "NFC tag not written"

**6. UI Filter (WI-5):** "No NFC Tag" filter chip
   - Uses `wave.3.right.circle` SF Symbol
   - Toggles `showOnlyMissingNFC` in ViewModel
   - Filter logic: `if showOnlyMissingNFC { result = result.filter { ($0.hasNfcTag ?? true) == false } }`
   - Default OFF (show all spools)

**7. UI Write Flow (WI-6):** Context menu "Write NFC Tag"
   - Only shown when `spool.hasNfcTag != true`
   - Wired to `viewModel.writeNFCTag(for:)`
   - Shows loading state while writing: `.disabled(viewModel.isWritingNFC)`
   - Shows error alert if `viewModel.writeNFCError != nil`
   - Post-write: Calls `loadSpools()` to refresh `hasNfcTag` from backend
   - Auto-highlights spool for 0.5s on success

### Key Files Modified
- `PrintFarmer/Models/FilamentModels.swift` — hasNfcTag field
- `PrintFarmer/Services/NFCService.swift` — writeSpoolTag() dual-record method
- `PrintFarmer/Navigation/DeepLinkHandler.swift` — spool route parsing
- `PrintFarmer/Navigation/AppRouter.swift` — pendingSpoolHighlightId + navigate
- `PrintFarmer/ViewModels/SpoolInventoryViewModel.swift` — filter, write state, markSpoolNFCWritten
- `PrintFarmer/Views/Filament/SpoolInventoryView.swift` — badge, filter chip, write flow UI

### Build Status
✅ **Clean build** — Zero errors, zero new warnings
- Pre-existing test failures (3 XCUITest cases) unrelated to changes

### Critical Notes
- **iPhone-only feature:** Jeff confirmed iPads do NOT support Core NFC — feature restricted to iPhone devices only
- **Optional coalescing:** Filter treats missing `hasNfcTag` as "has NFC" (`($0.hasNfcTag ?? true) == false`)
- **Dual-record reuses infrastructure:** No new NFCMessageWriteDelegate classes needed — `writeSpoolTag()` uses same delegate as `writePrinterTag()`

### Learnings

#### Spool NFC Dual-Record NDEF Pattern
- **Dual-record mirrors printer tag pattern:** URI record for in-app deep links + text record for universal NFC readers. Both use `NFCMessageWriteDelegate`.
- **SpoolmanSpool is immutable:** Updating a single field requires reconstructing entire struct (all `let` properties). Helper `markSpoolNFCWritten()` does this explicitly.
- **Optional pattern matching in Swift:** `if case SpoolScanError.cancelled = error as? SpoolScanError` fails because `as?` returns Optional. Use `if let scanError = error as? SpoolScanError, case .cancelled = scanError` instead.
- **DeepLinkHandler URL parsing:** `url.host` gives first path segment of custom URL schemes (`printfarmer://spool/42` → host = "spool"). Path components after host in `url.pathComponents`.
- **Filter chip pattern:** Single-purpose toggle chip with capsule background, placed in HStack with Spacer() for left-alignment, below status filter chips.

#### TestFlight Beta Release Pipeline
- **Workflow file:** `.github/workflows/testflight-beta.yml` — triggers on `v*-beta*` / `v*-rc*` tags or manual dispatch. Archives with xcodebuild, exports IPA via `.github/ExportOptions.plist`, uploads to TestFlight via fastlane pilot.
- **Export options:** `.github/ExportOptions.plist` — app-store method, team ID `ZPKA84F3TY`, automatic signing, symbols uploaded, bitcode disabled.
- **Key improvements over initial spec:** Removed invalid `-archiveForDistribution` flag; replaced deprecated `actions/create-release@v1` with `softprops/action-gh-release@v2`; added `MATCH_GIT_URL` secret for fastlane match certificates repo; ExportOptions.plist path set to `.github/ExportOptions.plist` for consistency.
- **Required secrets:** `FASTLANE_USER`, `FASTLANE_PASSWORD`, `MATCH_PASSWORD`, `MATCH_GIT_URL`, `SLACK_WEBHOOK_URL` (optional).

### Ready for Testing (Ash — WI-8)
- All MockSpoolService fixtures should include `hasNfcTag: nil` parameter
- Test scenarios: HasNFC state, NoNFC state, FilterActive state
- Write flow tests: Success path (calls NFCService, reloads spools), error path (sets writeNFCError, user can retry)
- Highlight behavior test: spoolId set/cleared after 0.5s delay

---
