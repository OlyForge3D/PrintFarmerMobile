# Squad Decisions

## Active Decisions

### Decision: Spoolman Spool Model Naming & Pagination (Lambert)
**Date:** 2026-03-07  
**Status:** Implemented

## Context
Phase 1 filament/spool models needed to match backend DTOs precisely.

## Decisions

1. **Model names use `Spoolman` prefix** (`SpoolmanSpool`, `SpoolmanFilament`, `SpoolmanVendor`, `SpoolmanMaterial`) to match backend DTO names and avoid collision with future domain models (e.g., a simpler `Spool` view model).

2. **Pagination uses `limit`/`offset`** (not `page`/`pageSize`) — matches Spoolman's native API which the backend proxies. Return type is `SpoolmanPagedResult<T>` with `items` and `totalCount`.

3. **Added `patch()` to APIClient** — backend uses HTTP PATCH for spool and filament updates. This is a new HTTP method available to all services.

4. **`SetActiveSpoolRequest` returns `CommandResult`** (not `Printer`) — matches backend's `PrintersController.SetActiveSpoolAsync` which returns `CommandResult`.

5. **Added `changeFilament()` to PrinterService** — backend has `filament-change` (M600) in addition to `filament-load`/`filament-unload`. Included for completeness.

## Impact
- Ripley can build filament management UI against `SpoolServiceProtocol` and the extended `PrinterServiceProtocol`.
- ViewModels should use `SpoolmanPagedResult` for infinite scroll / pagination patterns.

---

### Filament UI Architecture (Ripley)
**Date:** 2026-03-07  
**Status:** Implemented

## Tab Structure Change
- Added **Inventory** tab (6th tab) to ContentView TabView using `cylinder.fill` SF Symbol
- Added `AppTab.inventory` case and `inventoryPath` NavigationPath to AppRouter
- Tab order: Dashboard → Printers → Jobs → Alerts → **Inventory** → Settings

## Filament Section in PrinterDetailView
- Filament section always renders between Camera and Actions sections
- Shows active spool info (color swatch, material, vendor, weight progress bar) or "No filament loaded" empty state
- "Load Filament" / "Change Filament" → presents SpoolPickerView as `.sheet`
- "Eject" → calls `printerService.setActiveSpool(nil)` + `printerService.unloadFilament()`
- `setActiveSpool(_:)` → calls `printerService.setActiveSpool(spoolId)` + `printerService.loadFilament()`

## SpoolService Dependency
- ViewModels use `SpoolServiceProtocol` (Lambert's protocol) via `ServiceContainer.spoolService`
- PrinterDetailViewModel uses `PrinterServiceProtocol` filament methods (setActiveSpool, loadFilament, unloadFilament) — NOT SpoolServiceProtocol
- SpoolPickerViewModel and SpoolInventoryViewModel use `SpoolServiceProtocol` for listing/creating/deleting spools

## Phase 2 NFC Hook
- SpoolPickerView and AddSpoolView are designed to accept NFC-scanned spool data (OpenSpool / OpenPrintTag formats)
- Future work: Add "Scan NFC" button that auto-populates spool fields from tag

**Impact:**
- **Lambert:** No changes needed — all services already built and working
- **Ash:** 3 new ViewModels need test coverage (SpoolPickerViewModel, SpoolInventoryViewModel, AddSpoolViewModel); MockSpoolService needed
- **Dallas:** AppRouter has new `inventory` case — any navigation routing logic should account for it

---

### Camera Snapshot Display Strategy (Ripley)
**Date:** 2025-07-18  
**Status:** Implemented

Two-tier loading strategy for camera snapshots in PrinterDetailView:
1. **Primary:** Load snapshot as `Data` via `PrinterServiceProtocol.getSnapshot(id:)` (authenticated, reliable)
2. **Fallback:** Display via `AsyncImage` from `Printer.cameraSnapshotUrl` (direct URL, no auth needed)
3. **Empty state:** "No camera available" placeholder when neither source exists

Service-based snapshot fetch handles auth tokens automatically; direct URL provides seamless fallback.

**Impact:**
- Lambert: No changes needed — existing `getSnapshot(id:)` contract unchanged
- Ash: `PrinterDetailViewModel` gains `isLoadingSnapshot: Bool` and `refreshSnapshot() async` — tests may need updating

---

### Push Notification Infrastructure (Lambert)
**Date:** 2026-07-17  
**Status:** Implemented (client-side); backend endpoint pending

#### Architecture
- **PushNotificationManager** is a `@MainActor @Observable` singleton owning APNs lifecycle
- **AppDelegate** adapter handles system callbacks and forwards to PushNotificationManager
- **NotificationService** extended with `registerDeviceToken` / `unregisterDeviceToken` methods

#### Backend Endpoint (Placeholder)
- NotificationsController.cs has an `EnablePushNotifications` preference flag but **no device token registration endpoint**
- Client uses placeholder paths: `POST /api/notifications/device-token` (register) and `DELETE /api/notifications/device-token/{token}` (unregister)
- **Action needed from Dallas:** Add device token registration endpoint to the backend. Suggested DTO: `{ token: string, platform: "ios" | "android" }`

#### Deep-Link Hook
- Tapped notifications post `Notification.Name.pushNotificationTapped` with the push payload's `userInfo`
- **Ripley** can observe this in `AppRouter` to navigate to the relevant printer/job detail screen

**Impact:**
- **Ripley:** SettingsView now has a push notification toggle. Deep-link notification available for navigation wiring
- **Dallas:** Backend needs a device token registration endpoint
- **Ash:** MockNotificationService updated with new protocol methods; existing tests unaffected

---

### Decision: XCUITest Target Setup (Ash)
**Date:** 2025-07-20  
**Status:** Needs Action (manual Xcode step required)

## Context
Created XCUITest scaffolding files in `PrintFarmerUITests/` directory to support cross-process UI testing.

## Decision
XCUITest **files** (PrintFarmerUITests.swift, LoginFlowUITests.swift, PrinterListUITests.swift) are ready, but the **XCUITest target** must be added to `PrintFarmer.xcodeproj` manually in Xcode because:
1. XCUITest targets require a specific target type (`com.apple.product-type.bundle.ui-testing`) with host app dependency
2. Build settings (TEST_HOST, TEST_TARGET_NAME) are complex and error-prone to hand-edit in pbxproj
3. Xcode's "Add Target → UI Testing Bundle" wizard handles all of this correctly

## Required Steps
1. Open `PrintFarmer.xcodeproj` in Xcode
2. File → New → Target → "UI Testing Bundle"
3. Name: `PrintFarmerUITests`, Language: Swift, Target to Test: `PrintFarmer`
4. Delete the auto-generated test file (our files already exist in `PrintFarmerUITests/`)
5. Add the 3 existing `.swift` files to the new target
6. Verify the `--uitesting` launch argument is picked up by the app

## Impact
- **Ripley:** Should check for `--uitesting` in `ProcessInfo.processInfo.arguments` in `PFarmApp.swift` to enable mock mode
- **Lambert:** Mock server URL will be passed via launch argument `--mock-server-url=<url>`
- **All:** UI tests won't run until target is created in Xcode

## Mock Mode Contract
The UI tests pass `--uitesting` as a launch argument. The app should:
1. Check `ProcessInfo.processInfo.arguments.contains("--uitesting")`
2. If true, use stub/mock services instead of real network calls
3. Optionally accept `--mock-server-url=<url>` for Lambert's mock server

---

### Decision: MockAPIServer for XCUITest Support (Lambert)
**Date:** 2026-07-18  
**Status:** Implemented

## Context
XCUITests run the app in a separate process, so `MockURLProtocol` (in-process URLSession interception) cannot mock API responses for UI tests. We needed a cross-process solution.

## Decision
Built a real localhost HTTP server (`MockAPIServer`) using Apple's `NWListener` (Network framework) — zero external dependencies. The app checks a `PFARM_MOCK_SERVER_URL` environment variable at launch to redirect API calls to the mock server.

## Key Design Choices
1. **NWListener over URLProtocol** — works across process boundaries for XCUITest
2. **Random port** — avoids conflicts when tests run in parallel
3. **Wildcard routes** (`/api/printers/*`) — one route handles all ID-parameterized endpoints
4. **Environment variable injection** (`PFARM_MOCK_SERVER_URL`) — XCUITests set `app.launchEnvironment["PFARM_MOCK_SERVER_URL"]` to point at mock server
5. **Configurable responses** — tests can `resetRoutes()` and register scenario-specific routes

## Impact on Other Agents
- **Ripley (UI):** Can now build XCUITests that run against deterministic mock data. Use `MockAPIServer` in test setUp, pass `baseURL` via launch environment.
- **Ash (Testing):** Unit tests still use `MockURLProtocol` — no change. `MockAPIServer` is additive for integration/UI tests.
- **Dallas (Architecture):** `PFarmApp.init()` now checks `PFARM_MOCK_SERVER_URL` env var before `APIClient.savedBaseURL()`.

## Files Changed
- `PrintFarmerTests/Helpers/MockAPIServer.swift` — new (server + `MockResponses` enum)
- `PrintFarmerTests/Helpers/TestFixtures.swift` — added Spoolman fixtures
- `PrintFarmer/PFarmApp.swift` — added `PFARM_MOCK_SERVER_URL` env var check
- `PrintFarmer.xcodeproj/project.pbxproj` — registered MockAPIServer.swift

---

### Decision: iPad Layout Architecture (Ripley)
**Date:** 2026-03-07
**Status:** Implemented

## Context
The app needed iPad-optimized layouts. All views were iPhone-only (single column, TabView navigation).

## Decision
Used `@Environment(\.horizontalSizeClass)` throughout to provide adaptive layouts:

1. **ContentView** switches between TabView (compact) and NavigationSplitView with sidebar (regular).
2. **Dashboard, PrinterList** use multi-column grids on iPad.
3. **PrinterDetail** uses a two-column layout (info left, camera/job right) on iPad.
4. **LoginView** caps form width at 500pt on iPad.

## Rationale
- `horizontalSizeClass` is the standard SwiftUI mechanism for device-adaptive layouts (iOS 17+).
- NavigationSplitView gives iPad users the expected sidebar pattern without breaking iPhone.
- `List(selection:)` binding is unavailable on iOS, so sidebar uses explicit Button-based rows with manual highlight.

## Impact
- All existing iPhone layouts are unchanged (guarded by `sizeClass == .regular` checks).
- `AppRouter` gained a `sidebarVisibility` property for sidebar column management.
- No new dependencies or services introduced.

---

---

### Decision: 5 New Service Layers (Lambert)
**Date:** 2026-03-08
**Status:** Implemented

## Context
Built service layers for Maintenance, AutoPrint, JobAnalytics, Predictive, and Dispatch features.

## Decisions

1. **PredictionRequest uses optional fields** — Existing PredictiveViewModel passes `material: String?` and `estimatedDurationSeconds: Int?`. Model adapted to match rather than break the ViewModel.

2. **JobFailurePrediction has dual probability fields** — Both `failureProbability` (used by ViewModel) and `predictedFailureLikelihood` (from API spec) are present as optionals. Backend can return either.

3. **Date query parameters use ISO 8601 plain format** — `APIClient.iso8601Plain.string(from:)` for URL query string dates, consistent with backend expectations.

4. **FleetPrinterStatistics uses computed Identifiable** — `var id: UUID { printerId }` with explicit CodingKeys since JSON has no `id` field.

5. **Request models are Encodable only** — Request DTOs (AcknowledgeAlertRequest, ResolveAlertRequest, etc.) conform to `Encodable, Sendable` but not `Decodable`, since they're never decoded from responses.

## Impact
- **Ripley:** Can build UI against 5 new protocols (MaintenanceServiceProtocol, AutoPrintServiceProtocol, JobAnalyticsServiceProtocol, PredictiveServiceProtocol, DispatchServiceProtocol)
- **Ash:** Needs mock implementations for all 5 new service protocols for testing
- **Dallas:** ServiceContainer now has 5 new `let` properties; any DI routing should account for them

---

### Decision: New Features UI Architecture (Ripley)
**Date:** 2026-03-08
**Status:** Implemented

## Context
Built ViewModels and Views for 7 new features: Maintenance, AutoPrint, Job Analytics, Predictive Insights, Dispatch Dashboard, Job History/Timeline, and Uptime/Reliability.

## Decisions

1. **Maintenance tab added** — `AppTab.maintenance` with `wrench.adjustable` icon, inserted after Alerts in both TabView and NavigationSplitView sidebar. Tab order: Dashboard → Printers → Jobs → Inventory → Alerts → Maintenance → Settings.

2. **6 new AppDestination cases** — `maintenanceAnalytics`, `uptimeReliability`, `predictiveInsights(printerId:)`, `jobAnalytics`, `jobHistory`, `jobTimeline`, `dispatchDashboard`. All handled in the shared `destinationView(for:)` helper.

3. **AutoPrintSection is a standalone component** — Embedded directly in PrinterDetailView (both iPhone and iPad layouts) rather than being part of PrinterDetailViewModel. Has its own `AutoPrintViewModel` and loads its own data via `.task`.

4. **Job Analytics and History accessible from Jobs tab toolbar** — NavigationLink toolbar buttons on JobListView navigate to JobAnalyticsView and JobHistoryView. Timeline accessible from within JobHistoryView.

5. **Dispatch Dashboard accessible from Dashboard** — NavigationLink card at bottom of DashboardView content area.

## Impact
- **Lambert:** ServiceContainer needs 5 new service properties: `maintenanceService`, `autoPrintService`, `jobAnalyticsService`, `predictiveService`, `dispatchService`. All ViewModels use `configure()` pattern with these service protocols.
- **Ash:** 7 new ViewModels need test coverage with mock services.
- **Dallas:** AppRouter has new `maintenance` tab case and `maintenancePath` NavigationPath. AppDestination has 6 new cases.

---

### Decision: NFC Printer Tag Write Delegate Architecture (Ripley)
**Date:** 2026-03-08
**Status:** Implemented

## Context
The existing NFCWriteDelegate takes raw `Data` bytes and wraps them in an OpenSpool media-type NDEF record. Printer tags need a URI record (`printfarmer://printer/{UUID}`) plus a text record with the printer name.

## Decision
Created a separate `NFCMessageWriteDelegate` that accepts a full `NFCNDEFMessage` rather than refactoring the existing delegate. The `writePrinterTag` method on `NFCService` is concrete (not added to `SpoolScannerProtocol`) since printer tag writing is NFC-specific and doesn't apply to QR scanner implementations.

## Rationale
- Keeps the existing spool writing path untouched and stable
- `NFCMessageWriteDelegate` is more flexible — can write any NDEF message composition
- Accessing via `nfcScanner as? NFCService` cast is acceptable since printer tag writing is inherently NFC-only
- iOS handles URI record recognition automatically — no need to modify the read delegate for printer tags

## Alternatives Considered
- Refactoring NFCWriteDelegate to accept either Data or NFCNDEFMessage — rejected, adds complexity to working code
- Adding `writePrinterTag` to SpoolScannerProtocol — rejected, QR scanners can't write NFC tags

---

### Decision: NFC/Deep Link Navigation Race Condition Fix (Ripley)
**Date:** 2026-03-08
**Status:** Implemented

## Context
When a user had Printer A open and tapped an NFC notification for Printer B, the app stayed on Printer A. Two issues:
1. `AppRouter.navigate(to:)` reset NavigationPath and appended synchronously — SwiftUI batched this as a single update and did an in-place view update instead of pop-then-push.
2. `PushNotificationManager` posted `.pushNotificationTapped` but no view observed it, so server push notification deep links were silently dropped.

## Decisions

1. **Async delay between NavigationPath reset and append** — `navigate(to:)` now resets `printersPath` synchronously, then appends the new destination after a 50ms `Task.sleep` in a `@MainActor` Task. This ensures SwiftUI processes the pop before the push.

2. **Added `.onReceive` for `.pushNotificationTapped`** — PFarmApp.swift now observes this notification, extracts the `"link"` URL from userInfo, parses via `DeepLinkHandler`, and calls `router.navigate(to:)`. Guarded with `#if canImport(UIKit)`.

## Impact
- **Lambert:** No changes needed — PushNotificationManager already posts the notification correctly.
- **Ash:** AppRouter.navigate(to:) is now async internally — any tests calling it should account for the 50ms delay before asserting NavigationPath contents.
- **Dallas:** No architectural changes — same deep link flow, just properly separated across render cycles.

## Files Changed
- `PrintFarmer/Navigation/AppRouter.swift` — navigate(to:) uses async delay
- `PrintFarmer/PFarmApp.swift` — added .onReceive for .pushNotificationTapped
