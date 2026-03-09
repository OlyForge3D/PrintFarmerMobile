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

---

### Feature Scope: Spool NFC Tag Writing for Inventory (Dallas)
**Date:** 2026-03-08  
**Requested by:** Jeff Papiez  
**Status:** Scoped (Ready for dev)  
**Estimated Effort:** ~10.5 hours across team

## Executive Summary

Jeff wants to add NFC tag **writing** capability for filament spools in inventory. Users should be able to:
1. See which spools in inventory have NFC tags (visual indicator)
2. Filter spools to show only those without NFC tags
3. Write NFC tags for spool data so spools can be linked to printers via NFC scan

This builds on existing **NFC read + printer tag write** infrastructure (NFCService.swift already handles both). The feature plugs into the **Inventory tab** (added Phase 1) and **SpoolInventoryView**.

## Current State & Gaps

**Existing:**
- ✅ NFCService.swift — reads NFC tags, writes printer tags (`writePrinterTag()`)
- ✅ NFCTagParser.swift — converts spool ↔ OpenSpool JSON
- ✅ SpoolInventoryView/ViewModel — displays all spools, supports filters
- ✅ SpoolPickerView + AddSpoolView with NFC scan buttons
- ✅ NFCWriteDelegate — infrastructure for NDEF writes

**Missing:**
- ❌ Backend `hasNfcTag` field on SpoolmanSpool
- ❌ UI indicator badge (green ✓ / gray −)
- ❌ "No NFC Tag" filter chip
- ❌ Write button + action flow in inventory

## Work Breakdown (8 Items, ~10.5h)

| WI | Title | Owner | Effort | Depends |
|----|-------|-------|--------|---------|
| 1 | Backend: Add `hasNfcTag` field | Jeff | 1h | — |
| 2 | iOS Model: Add `hasNfcTag` | Lambert | 15m | WI-1 |
| 3 | iOS View: NFC Indicator Badge | Ripley | 1.5h | WI-2 |
| 4 | iOS View: "No NFC Tag" Filter | Ripley | 1h | WI-2 |
| 5 | iOS ViewModel: Write Action | Lambert | 1.5h | WI-2 |
| 6 | iOS View: Write Button & Flow | Ripley | 2h | WI-5 |
| 7 | Integration: Wire Services | Lambert+Ripley | 30m | WI-6 |
| 8 | Tests: Full Coverage | Ash | 2.5h | All |

**Critical Path:** WI-1 → WI-2 → (WI-3,4 ∥ WI-5) → WI-6 → WI-7 → WI-8

## Key Architectural Decisions

1. **`hasNfcTag` field:** Add as `Bool?` to SpoolmanSpool (optional for backward compat)
2. **Backend tracking:** Recommend DB column `Spool.HasNfcTag` (simpler than querying NfcScanEvents)
3. **No new URL scheme:** Spool tags use existing OpenSpool JSON (unlike printer tags which use `printfarmer://printer/{UUID}`)
4. **Post-write refresh:** Reload full spool list to update `hasNfcTag` from backend
5. **Write button placement:** Context menu (3-dot) to reduce list clutter

## NFC Payload Design (Existing)

**Format:** OpenSpool JSON  
```json
{
  "material": "PLA",
  "color_hex": "#0000FF",
  "brand": "Prusament",
  "weight_g": 250.0,
  "spoolman_id": 42
}
```

## API Contract (After WI-1)

```json
GET /api/spoolman/spools
{
  "items": [
    {
      "id": 42,
      "name": "Blue PLA",
      "material": "PLA",
      "colorHex": "#0000FF",
      "vendor": "Prusament",
      "hasNfcTag": false,
      ...
    }
  ],
  "totalCount": 5
}
```

## Risk Mitigation

| Risk | Mitigation |
|------|-----------|
| Backend `hasNfcTag` missing | Jeff confirms WI-1 before iOS dev starts |
| NFC write failure on tag already written | Show error + retry button |
| Stale cache after write | Reload full spool list (WI-5) |
| Backend never sees write (phone-only) | Acceptable — user can scan to verify; printer reader will detect on auto-load |

## Questions for Jeff (Pending Confirmation)

1. **`hasNfcTag` logic:** DB column vs NfcScanEvents query count?
2. **Spool tag URL scheme:** Keep JSON or add `printfarmer://spool/{id}` URI?
3. **Write button placement:** Context menu (rec.) vs inline vs detail sheet?

## Timeline

| Phase | Work Items | Owner | Duration |
|-------|-----------|-------|----------|
| Prep | WI-1 | Jeff | 1 day |
| Backend Ready | WI-2, WI-5, WI-7 | Lambert | 2h |
| UI Dev | WI-3, WI-4, WI-6 | Ripley | 4.5h |
| Testing | WI-8 | Ash | 2.5h |
| QA/Polish | — | Dallas | 1h |
| **TOTAL** | — | — | **~2 days, 10.5h** |

## Success Criteria

- ✅ Spool list shows `hasNfcTag` badge for each spool
- ✅ "No NFC Tag" filter works (shows only `hasNfcTag == false`)
- ✅ Write button launches NFC session
- ✅ After successful write, `hasNfcTag` updates in UI
- ✅ Error handling for write failures (user-friendly messages, retry option)
- ✅ All tests pass (unit + snapshot)
- ✅ No regression in existing filament/spool features

## Cross-Team Impact

- **Lambert:** WI-2 (model), WI-5 (viewmodel), WI-7 (services)
- **Ripley:** WI-3/4 (badge + filter), WI-6 (write button + flow)
- **Ash:** WI-8 full coverage (unit + snapshot tests)
- **Dallas:** Orchestration, architecture review, test validation

---

---

## Spool NFC Tag Dual-Record NDEF Format (Ripley, 2026-03-08)

**Status:** Implemented

### Context
Spool NFC tags need to work both for in-app deep linking and for universal NFC readers (e.g., OpenSpool-compatible printers).

### Decision
Spool NFC tags use the same dual-record NDEF pattern as printer tags:
1. **URI record:** `printfarmer://spool/{spoolmanId}` — triggers deep link navigation to spool in inventory
2. **Text record:** OpenSpool JSON (`material`, `color_hex`, `brand`, `weight_g`, `spoolman_id`) — readable by any NFC reader

Both records are written via `NFCMessageWriteDelegate` (full NDEF message writer), not `NFCWriteDelegate` (raw bytes).

### Key Implementation Details
- DeepLinkHandler now supports `printfarmer://spool/{id}` URLs
- AppRouter navigates to inventory tab and highlights spool via `pendingSpoolHighlightId`
- `writeSpoolTag()` reuses the same delegate as `writePrinterTag()` — no new delegate classes
- Legacy `writeTag(spool:)` preserved for backward compat but should be deprecated in future

### Team Notes
- Backend `hasNfcTag: Bool?` field supported by SpoolmanSpoolDto (Jeff's WI-1)
- Test fixtures need `hasNfcTag: nil` parameter in all SpoolmanSpool initializers going forward
- Feature restricted to iPhone devices only (Core NFC not available on iPad)

### Decision: Swift 6 Concurrency Fixes with @preconcurrency (Ripley)
**Date:** 2026-03-08  
**Status:** Applied

## Context
Swift 6 strict concurrency mode treats Apple framework types like `UNNotificationSettings` as non-Sendable. These types cross actor boundaries (e.g., nonisolated methods returning to @MainActor), causing compiler errors that break TestFlight archive builds.

## Decision
Use `@preconcurrency import` for Apple frameworks with non-Sendable types. This is Apple's recommended migration path for Swift 6. Do NOT use `nonisolated(unsafe)` on local variables — that modifier is for stored properties only.

## Applies To
- UserNotifications
- CoreLocation
- CoreNFC
- UIKit types crossing actor boundaries

**Key File:** `PrintFarmer/Services/PushNotificationManager.swift`

### Decision: Observable ViewModel Sheet Dismissal (Ripley)
**Date:** 2025-07  
**Status:** Applied

## Context
SpoolPickerView sheet failed to dismiss reliably after selection. The environment `dismiss()` action didn't propagate `showSpoolPicker = false` through `@State`/`@Observable` bindings when async state mutations ran concurrently on the same observable.

## Decision
For `@Observable` ViewModels controlling sheet presentation via boolean properties, explicitly reset the property in the action method (e.g., `showSpoolPicker = false`) rather than relying solely on `dismiss()` from the presented view.

## Applies To
All sheet-presenting flows using `@Observable` ViewModels with `@State` ownership.

---

### Decision: Fall Back to StatusDetail for Temperature Display (Ripley)
**Date:** 2026-03-08  
**Status:** Applied

## Context
PrusaLink printers showed "--" for hotend and bed temperatures in the iOS app, despite the web UI displaying them correctly. The backend's `PrusaLinkClient.CreatePrinterDtoAsync()` omits temperature fields from the `PrinterDto` response (used by `GET /api/printers/{id}`), but the `/status` endpoint returns them in `PrinterStatusDto`.

## Decision
`PrinterDetailView.temperatureSection()` uses nil-coalescing to fall back from `printer.hotendTemp` (etc.) to `viewModel.statusDetail?.hotendTemp`. This is backend-agnostic and works for all printer types without conditional logic per backend.

## Alternatives Considered
1. **Fix the backend** — Add temps to `PrusaLinkClient.CreatePrinterDtoAsync()`. Correct long-term fix, but requires backend deploy. Filed as known gap.
2. **Use only statusDetail** — Would work but loses the benefit of printer data that already has temps (Moonraker/Bambu).

## Applies To
`PrinterDetailView.swift` — `temperatureSection()` method.

## Team Notes
- The backend `PrusaLinkClient.CreatePrinterDtoAsync()` should also be fixed to include temp fields (backend team item).
- The `PrinterCardView` (list view) is not affected because the list endpoint uses `CompletePrinterDto` which includes temps from SignalR cache.

---

### Decision: APIClient Empty Response Handling for Optional Types (Ripley)
**Date:** 2026-03-08  
**Status:** Implemented

## Context
The PrintFarmer API returns empty response bodies (HTTP 204 No Content or 200 with empty body) when certain resources don't exist. For example, `/api/printers/{id}/printjob` returns an empty body when no print job is active.

Previously, `APIClient.execute<T: Decodable>()` always attempted to JSON-decode the response body, which failed with "dataCorrupted" errors on empty data, even when the method signature indicated an Optional return type (e.g., `PrintJobStatusInfo?`).

## Decision
Modified `APIClient.execute<T: Decodable>()` to handle empty response bodies intelligently:

1. **Before attempting decode**, check if `data.isEmpty`
2. **If empty and T is Optional**: Return `nil` (tested via `Optional<Any>.none as? T`)
3. **If empty and T is non-Optional**: Throw `NetworkError.decodingFailed` with descriptive message
4. **If non-empty**: Proceed with normal JSON decode

## Rationale
- **Type-safe handling**: Uses Swift's type system to distinguish Optional vs non-Optional at runtime
- **Contract enforcement**: Empty bodies for non-Optional types still error (catches API bugs)
- **Better error messages**: Non-Optional empty responses get a clear error ("Empty response body for non-optional type X")
- **Minimal change**: Single check before decode, doesn't affect existing decode paths

## Alternatives Considered
1. **Add `getOptional<T>()` method**: Rejected — duplicates logic, requires callsite changes
2. **Return nil for all empty responses**: Rejected — hides API contract violations for non-Optional types
3. **Check HTTP status code (204)**: Rejected — some 200 responses also have empty bodies

## Impact
- **Affected endpoints**: Currently only `PrinterService.getCurrentJob()`, but pattern now works for any future Optional-returning endpoints
- **Backward compatible**: No changes to method signatures or callsites
- **Build status**: Clean build, no regressions

## Follow-up
- Consider documenting this pattern in API client usage guidelines
- Monitor for other endpoints that might benefit from Optional returns


---

### Decision: Predictive Insights Graceful Empty State (Ripley)
**Date:** 2026-03-09  
**Status:** Implemented

## Context
The Predictive Insights feature showed "Failed to decode response: The data couldn't be read because it's missing" when the API returned empty/null body (no predictions available yet). This is the same class of bug as the print job empty response fix.

## Decision
1. **All predictive model fields use `decodeIfPresent` with defaults** — the API may omit fields or return partial data. Models should never crash on missing keys.
2. **`predictJobFailure` returns `JobFailurePrediction?`** — empty body returns nil instead of throwing decode error.
3. **`getActiveAlerts`/`getMaintenanceForecast` coalesce empty body to `[]`** — array endpoints return empty arrays on empty/null body.
4. **View shows "No predictions available" empty state** — instead of an error screen, users see a friendly message explaining predictions will appear once enough print history exists.
5. **Errors are logged, not displayed** — decode/network failures go to `os.Logger`, not to the user-facing error state.

## Impact
- **Lambert:** No service contract changes needed — protocol already updated.
- **Ash:** `MockPredictiveService.predictJobFailure` now returns Optional; tests expecting force-unwrap need updating.
- **Dallas:** No architecture changes.
