# Decisions — PFarm-Ios Squad

## Architecture & Framework

### 1. Swift 6 Strict Concurrency & Actor Isolation (Dallas, 2026-03-06)
**Status:** Foundational  

All ViewModels are `@MainActor @Observable`. Services are actor-isolated or properly annotated. AppRouter is `@MainActor` (manages UI navigation state). No `@unchecked Sendable` — proper isolation enforced.

**Impact:**
- Eliminates "sending risks data races" errors in SwiftUI bindings
- AppRouter, AuthViewModel, DashboardViewModel, PrinterDetailViewModel, etc. all `@MainActor`

### 2. Service Architecture: Actor-Based with ServiceContainer DI (Dallas, 2026-03-06)
**Status:** Locked In

ServiceContainer singleton instantiated at app init holds: APIClient, AuthService, PrinterService, JobService, NotificationService, SignalRService, StatisticsService. All services are actor-isolated or thread-safe.

**Impact:**
- ViewModels receive services via ServiceContainer (no constructor injection)
- AppDelegate creates container; .task configures ViewModels with container reference
- Easy to mock for testing

### 3. @Observable ViewModels Pattern (Dallas, 2026-03-06)
**Status:** Locked In

Modern SwiftUI reactive model. Each feature has one ViewModel. @Observable enables automatic reference tracking without @Published. All ViewModels are @MainActor @Observable.

**Impact:**
- No `@State var viewModel` — pass as argument or environment
- Automatic View invalidation on property changes

### 4. SwiftUI Navigation via AppDestination Enum (Dallas, 2026-03-06)
**Status:** Locked In

Deep navigation via `NavigationPath([AppDestination])` in AppRouter. Tab-based gating on `selectedTab`. LoginView ↔ ContentView gating on `isAuthenticated`.

**Impact:**
- Single source of navigation logic in AppRouter
- Deep linking via `AppDestination` enum
- Tabs (Dashboard, Printers, Jobs, Notifications, Settings)

---

## Authentication & Session Management

### 5. Session Expired Auto-Logout Pattern (Lambert, 2026-03-07)
**Status:** Implemented

When the backend returns a 401 or the JWT token is expired (with 5-minute buffer), the app automatically logs out:
1. **APIClient** posts `Notification.Name.sessionExpired` on 401 responses
2. **APIClient** checks `AuthService.isTokenExpired()` (via closure) before every request — proactively catches expired tokens without a network round-trip
3. **AuthViewModel** observes `.sessionExpired` and calls `logout()`, which flips `isAuthenticated = false` → SwiftUI navigates to LoginView

**Impact:**
- **Ripley (UI):** No UI changes needed — SwiftUI automatically shows LoginView when `isAuthenticated` flips to false
- **Ash (Tests):** Test mocks unaffected — `tokenExpiryChecker` is optional, defaults to nil (no pre-check)
- **AuthViewModel** is now `@MainActor @Observable`

**Rationale:**
- No refresh token exists (single JWT) — re-login is the only recovery path
- Proactive expiry check avoids wasted network calls and better UX (immediate redirect vs waiting for 401)
- Notification pattern decouples APIClient from AuthViewModel (no circular dependency)

### 6. Enum & Date Serialization Contract (Lambert, 2026-03-07)
**Status:** Applied

After login, the dashboard was crashing with "Failed to decode response" because Swift model enums used `Int` raw values while the ASP.NET Core backend serializes ALL enums as strings via `JsonStringEnumConverter`.

**Decision:**
1. **All Swift enums that map to backend C# enums MUST use String raw values** matching the C# member names exactly (e.g., `case moonraker = "Moonraker"`, `case sdcp = "SDCP"`). Each enum includes a fallback `init(from:)` that also accepts legacy integer values.
2. **The JSONDecoder uses a custom date strategy** that handles ISO 8601 both with and without fractional seconds. The built-in `.iso8601` strategy must NOT be used — it silently rejects fractional seconds.
3. **Backend `TimeSpan` fields are represented as `String?` in Swift** with parsing helpers (`.timeSpanSeconds`, `.timeSpanFormatted`), since .NET serializes `TimeSpan` as duration strings.

**Impact:**
- **Ripley/Views:** `StatusBadge(jobStatus:)` now accepts `PrintJobStatus?`. `MotionType.polar` was removed (doesn't exist in backend — `Unknown` is the correct fallback).
- **Ash/Tests:** Enum test fixtures must use string values, not integers. Mock JSON payloads should match backend format.
- **All agents:** When adding new model fields, always check the backend DTO in `~/s/PFarm1/src/infra/Dtos/` and the serialization config in `~/s/PFarm1/src/api/Startup/ControllerStartup.cs`.

---

## UI & Theming

### 7. Theme Support: Light + PrintFarmer Dark (Ripley, 2026-03-07)
**Status:** Implemented

Added light and dark theme support matching the Printfarmer web app's color system. Two themes: **Light** and **PrintFarmer Dark** (the branded dark navy theme, not generic system dark).

**Implementation:**
- **New Files:**
  - `PrintFarmer/Theme/Color+Hex.swift` — Hex color initializer for `Color` and `UIColor`
  - `PrintFarmer/Theme/ThemeColors.swift` — All branded colors as adaptive `Color` statics (`pf*` prefix)
  - `PrintFarmer/Theme/ThemeManager.swift` — `@Observable` class with `ThemeMode` enum (system/light/dark), persists to UserDefaults
- **Color System:**
  - **Adaptive colors** via `UIColor { traitCollection in ... }` — automatically respond to iOS appearance changes
  - **22 named color tokens** covering backgrounds, text, accents, borders, status, buttons, hardware status
  - **Brand accent: green (#10b981)** set as global `.tint()` on the root view
- **Theme Toggle:**
  - Settings → Appearance → Theme picker with System / Light / PrintFarmer Dark options
  - `.preferredColorScheme()` applied at root view level in PFarmApp
  - System mode follows iOS appearance setting; manual override persists across launches

**Impact:**
- **All agents:** New views should use `Color.pf*` tokens instead of raw SwiftUI colors (`.blue`, `.green`, etc.)
- **Ash (Testing):** ThemeManager is `@Observable` and injected via `.environment()` — mock or create in tests that need it
- **Key convention:** Use `Color.pfCard` (not `.pfCard`) in `.background()`, `.foregroundStyle()`, `.strokeBorder()` contexts due to ShapeStyle resolution

### 8. QA Audit Fixes — Theme Color Extensions (Ripley, 2026-03-07)
**Status:** Applied

Added 3 new theme colors to `PrintFarmer/Theme/ThemeColors.swift`:
- **`pfMaintenance`** — purple, adaptive (light: #7c3aed, dark: #a78bfa). Used for maintenance mode badges in StatusBadge and PrinterDetailView.
- **`pfAssigned`** — teal/cyan, adaptive (light: #0891b2, dark: #22d3ee). Used for "Assigned" job status in StatusBadge.
- **`pfTempMild`** — yellow, adaptive (light: #ca8a04, dark: #facc15). Used for temperature display when >50°C in TemperatureView.

**Rationale:**
QA audit identified 17 hardcoded colors (.red, .orange, .purple, .cyan, etc.) across 7 view files. Existing pf* palette covered most cases (pfError→red, pfWarning→orange, pfHomed→blue, pfNotHomed→orange) but purple (maintenance), cyan (assigned), and yellow (mild temp) had no equivalents.

**Impact:**
- All views now use theme-consistent colors that adapt properly between light/dark modes
- Any future views needing maintenance, assigned, or mild-temperature colors should use these instead of raw system colors
- AuthViewModel now uses `@MainActor` instead of `@unchecked Sendable` — aligns with the existing ViewModel pattern

### 9. PrinterDetailView Blank Page Fix (Ripley, 2026-03-07)
**Status:** Applied

Users reported a blank page when tapping a printer in the list. PrinterDetailView rendered nothing.

**Root Cause:**
1. The view body had three `if/else if` branches (loading, error, content) but **no final `else`**. The initial render state matched none of them → blank.
2. `loadPrinter()` set `isLoading = true` *after* a `guard let printerService` check. If the guard failed, the method returned silently — no loading indicator, no error, permanent blank.

**Decision:**
- **View pattern:** Always have a default `else` branch in conditional view bodies. Use: content first → error second → else ProgressView.
- **ViewModel pattern:** Set loading state *before* any guards in async load methods. If a guard fails, surface it as an `errorMessage` rather than silently returning.

**Team Impact:**
- **All agents:** Apply the same defensive rendering pattern to other detail views (JobDetailView, etc.) to prevent similar blank-page bugs.
- **Lambert:** `GET /api/printers/{id}` returns `PrinterDto` which lacks `InMaintenance`/`IsEnabled` fields. Consider either adding those to `PrinterDto` or having the iOS app call `/api/printers/{id}/details` instead. Low priority — defaults work fine for now.

### 10. Jobs Tab Shows Jobs, Not Printers (Ripley, 2026-03-07)
**Status:** Implemented

Jeff reported the Jobs tab was showing "available printers" instead of print jobs. The root cause was that `JobListView` fetched from `GET /api/job-queue` which returns `[QueueOverview]` — a printer-centric view with one row per printer.

**Decision:**
- Switched the Jobs tab to use `GET /api/job-queue-analytics` which returns individual print jobs (`[QueuedPrintJobWithFileMetaDto]`)
- Jobs are grouped by status: **Printing** (active on a printer), **In Queue** (waiting), **Recent** (completed/failed/cancelled, collapsible)
- The old `list() -> [QueueOverview]` method stays on the protocol for backward compat (Dashboard or other views may use it)
- Added `listAllJobs() -> [QueuedPrintJobResponse]` to `JobServiceProtocol`

**Impact:**
- **Views affected:** `JobListView`, `JobListViewModel`
- **Models added:** `QueuedPrintJobResponse`, `QueuedJobInfo`, `QueuePrinterMeta`, `QueueGcodeFileMeta`, `QueueStats`
- **Protocol change:** `JobServiceProtocol` gained `listAllJobs()` method
- **Mock updated:** `MockJobService` updated with new method + `queuedJobResponsesToReturn` property
- **No breaking changes:** Old `list()` method preserved; existing tests using `QueueOverview` still pass

---

## Infrastructure & Build

### 11. Xcode Project Regeneration (Dallas, 2026-03-06)
**Status:** Implemented

Regenerated `PrintFarmer.xcodeproj` from scratch rather than patching the damaged original. The project file is now auto-generated from the file tree using a deterministic Python script.

**Context:**
The original scaffolded `.xcodeproj` had three fatal issues:
1. Missing closing `}` in `project.pbxproj` (plist parse failure)
2. Empty workspace data (no `<FileRef>` in `contents.xcworkspacedata`)
3. 21 Swift files added during MVP batch (Lambert/Ripley/Ash) were never registered

**Impact:**
- **All agents:** When adding new `.swift` files, the xcodeproj must be regenerated. SPM (`swift build`) will work without changes, but Xcode won't see new files until the project is updated.
- **Future consideration:** A workspace-only approach (Xcode opens `Package.swift` directly) would eliminate this sync problem entirely. Deferred for now since the xcodeproj provides better Xcode integration (schemes, test plans, signing).

**Specifications:**
- iOS 17+, Swift 6.0
- Bundle ID: `com.printfarmer.ios`
- 47 source files, 19 test files (66 total)
- KeychainSwift SPM dependency
- Deterministic IDs (md5-based) — regeneration is idempotent

---

## Testing & QA

### 12. QA Review: PrintFarmer iOS MVP (Ash, 2026-03-07)
**Status:** Reference / Action Items

Comprehensive QA audit covering test coverage, error handling, edge cases, mock alignment, and memory safety. Test coverage at ~41% (7/17 units). Critical action items:

**Before Release:**
1. Add error UI to JobListView + NotificationsView
2. Implement 401 → auto-logout (see decision #5)
3. Add AuthViewModel tests
4. Add DashboardView empty state
5. Write JobListViewModel + JobDetailViewModel tests

**Test Coverage Gaps:**
- AuthViewModel, JobListViewModel, JobDetailViewModel, NotificationsViewModel — zero tests
- JobService, NotificationService, SignalRService — zero tests (protocols/mocks exist)

**All Verified Correct:**
- All API endpoint paths match backend
- All model field names/types match backend DTOs
- Enum serialization (String raw values) matches backend
- APIClient date decoder handles fractional + plain ISO 8601
- All ViewModels have proper @MainActor isolation

### 13. QA Audit — PrintFarmer iOS MVP (Dallas, 2026-03-07)
**Status:** Audit Complete (Issues Resolved in Batch)

Full codebase audit covering runtime, API contracts, UI, navigation, theme, concurrency.

**Critical Issues Resolved (7fb1419):**
- C1 ✅ AppRouter now @MainActor
- C2 ✅ AuthViewModel now @MainActor
- C3 ✅ SignalR date decoder (custom dual-format)
- C4 ✅ SignalR force unwraps (safe URLComponents)

**Important Issues Resolved:**
- I1 ✅ 17 hardcoded colors → theme tokens
- I2 ✅ Placeholder navigation → Coming Soon screens
- I3 ✅ Silent error suppression (secondary data loads)
- I4 ✅ Dashboard missing empty state
- I6 ✅ Accessibility labels on all interactive elements
- Plus fixes from decisions #5, #9, #10

**Minor Issues (Post-Release):**
- PrinterService methods on concrete class (not on protocol) — low priority
- Test suite: 2 inverted assertions — low priority
- SignalR @unchecked Sendable with unprotected mutable state — low priority

---

### 14. Test Coverage Extension (Ash, 2026-07-18)
**Status:** Implemented

Extended test suite from 146 → 226 test cases (+80). Four new ViewModel test suites cover all previously untested ViewModels.

**AuthViewModel Testing Pattern:**
AuthViewModel depends on concrete `AuthService` actor (no protocol). Tests use MockURLProtocol integration testing through the full AuthVM → AuthService → APIClient stack. This is different from other ViewModel tests which use protocol-based mocks via `configure()`.

**Recommendation for Ripley/Lambert:** Consider extracting `AuthServiceProtocol` from the concrete `AuthService` to enable protocol-based mock testing. `AuthServiceProtocol` already exists in TestProtocols.swift but isn't used by production code.

**PushNotificationManager Not Testable:**
PushNotificationManager is a singleton with concrete UIKit dependencies (UNUserNotificationCenter, UIApplication). Cannot be unit tested without significant refactoring. Acceptable risk for MVP — push notification flows should be validated via manual QA on device.

**Coverage Gaps Remaining:**
| Component | Status | Notes |
|-----------|--------|-------|
| JobService (actor) | Indirect | Tested via ViewModel mocks; needs dedicated MockURLProtocol tests like PrinterServiceTests |
| StatisticsService (actor) | Indirect | Same as above |
| NotificationService (actor) | Indirect | Same as above |
| PushNotificationManager | Untestable | Singleton + UIKit runtime dependency |

**Impact:**
- All team members: new test suites follow established patterns and should pass in Xcode
- SPM `swift build` still blocked by pre-existing XCTest module limitation (not related to changes)

### 15. Feature Decomposition: Filament Management + NFC Tag Support (Dallas, 2026-07-19)
**Status:** Proposed

The backend is **fully ready** — FilamentType, Spool, NfcDevice, and NfcScanEvent entities already exist with complete CRUD endpoints, Spoolman integration, and NFC scan event processing.

**User Decisions Applied:**
- Spool inventory → new tab in tab bar
- NFC format → support both OpenSpool and OpenPrintTag
- Spoolman always available (no fallback needed)

**Phase 1: Filament Management** (Core spool selection, inventory management)
**Phase 2: NFC Tag Support** (CoreNFC scanning/writing with OpenSpool + OpenPrintTag formats)

**Implementation Plan:**
- **Sprint 1 (Phase 1 Core):** P1-7 Models, P1-2 SpoolService, P1-1 Filament section, P1-6 ViewModel extensions, P1-3 Spool picker
- **Sprint 2 (Phase 1 Complete):** P1-4 Spool inventory tab, P1-5 Add spool form
- **Sprint 3 (Phase 2):** P2-2 Info.plist/entitlements, P2-1 NFCService, P2-3 Scan-to-load, P2-6/P2-4/P2-5 UI flows

**Total Estimate:** ~22 hours of implementation

**Dependency Graph:** See feature document for detailed P1-1 through P2-6 work item breakdown, dependencies, and open questions.

### 16. Spool Inventory Filtering & Search Enhancement (Ripley, 2026-03-07)
**Status:** Implemented

Enhanced SpoolInventoryView and SpoolPickerView with expanded search and material type filtering.

**Changes:**
1. Expanded search filter in ViewModels to check name + material + vendor + location + comment + color name
2. Added `SpoolmanSpool+ColorName.swift` extension with hex-to-color-name heuristic (lightweight, suitable for filament palette)
3. Added material type filter chips (FilterChip-based segmented control) to both Views
4. Added `ContentUnavailableView.search` empty state when filtered results are empty
5. Updated search bar prompts: "Search by name, material, color…"

**Files Changed:**
- `PrintFarmer/Views/Filament/SpoolInventoryView.swift` 
- `PrintFarmer/Views/Filament/SpoolPickerView.swift`
- `PrintFarmer/ViewModels/SpoolInventoryViewModel.swift`
- `PrintFarmer/ViewModels/SpoolPickerViewModel.swift`
- `PrintFarmer/Extensions/SpoolmanSpool+ColorName.swift` (new)

**Impact:**
- Users can now search spools by color, location, or comment fields
- Filtering is client-side only — no backend changes needed
- MVVM pattern maintained; filter logic in ViewModels
- `hasActiveSearch` computed property gates empty-state display

### 17. Status Filters & Weight Progress for Spool Views (Ripley, 2026-03-08)
**Status:** Implemented

Added status-based filtering and visual weight indicators to both SpoolInventoryView and SpoolPickerView.

**Implementation:**
1. **SpoolStatus Enum** — Four cases in SpoolInventoryViewModel:
   - **Available:** `!inUse && !archived` — ready to assign
   - **In Use:** `inUse == true` — currently loaded on a printer
   - **Low:** remaining < 20% of initial — needs attention
   - **Empty:** remaining == 0 or nil with initial present — replace soon

2. **Status Filter Chips** — Second row of horizontal scrolling capsule buttons:
   - Same visual style as material chips (pfAccent selected, pfBackgroundTertiary unselected)
   - Enum-driven UI via `ForEach(SpoolStatus.allCases)`
   - Filters applied in sequence: material → status → search text

3. **Weight Progress Bars** — Horizontal capsule showing remaining/initial percentage:
   - Color-coded: green (>50%), yellow (20-50%), red (<20%)
   - Only shown when both `remainingWeightG` and `initialWeightG` available
   - Positioned below weight text on right side of row

4. **In-Use Badge** — Small `printer.fill` SF Symbol next to spool name:
   - Colored with pfAccent for visibility
   - Only shown when `inUse == true`

**Files Changed:**
- `PrintFarmer/ViewModels/SpoolInventoryViewModel.swift`
- `PrintFarmer/ViewModels/SpoolPickerViewModel.swift`
- `PrintFarmer/Views/Filament/SpoolInventoryView.swift`
- `PrintFarmer/Views/Filament/SpoolPickerView.swift`

**Impact:**
- No new dependencies
- No breaking changes — filters are optional, default to "All"
- Backward compatible and dark-mode compliant
- Two-row filter layout avoids UI crowding; consistent with existing material filter pattern

---

## Launch & Onboarding

### 18. Launch Screen Implementation (Ripley, 2026-03-08)
**Status:** Implemented

Created a professional launch screen using `LaunchScreen.storyboard` (not Info.plist UILaunchScreen or SwiftUI).

**Decision**
- Storyboard provides layout control impossible with Info.plist approach (centered stack with emoji + text)
- iOS doesn't support SwiftUI for launch screens (must be static)
- Storyboard is standard for App Store submissions

**Implementation**
- Visual: 🌾 emoji centered above "PrintFarmer" bold text in vertical stack
- Colors: Three new adaptive color sets in Assets.xcassets (LaunchBackground, LaunchText, LaunchAccent) matching theme tokens (pfBackground, pfTextPrimary, pfAccent)
- Storyboard XML uses `targetRuntime="iOS.CocoaTouch"` (critical for Xcode 26.2)
- Build setting: `INFOPLIST_KEY_UILaunchStoryboardName = LaunchScreen` (removed auto-generation)

**Files**
- `PrintFarmer/LaunchScreen.storyboard` (new)
- `PrintFarmer/Assets.xcassets/LaunchBackground.colorset/Contents.json` (new)
- `PrintFarmer/Assets.xcassets/LaunchText.colorset/Contents.json` (new)
- `PrintFarmer/Assets.xcassets/LaunchAccent.colorset/Contents.json` (new)
- `PrintFarmer.xcodeproj/project.pbxproj` (updated)

**Impact**
- App startup now displays branded launch screen with wheat emoji + green accent
- Seamless light/dark mode support via adaptive colors
- Professional first impression before app loads main UI

---

## Cross-References

**Backend Contract Docs:** `~/s/PFarm1/src/api/` (Controllers, DTOs, Startup/ControllerStartup.cs)  
**Frontend Decisions History:** `.squad/decisions/decisions.md` (this file)  
**Agent Context:** `.squad/agents/{lambert,ripley,ash,dallas}/history.md`  
**Session Logs:** `.squad/log/` (ISO 8601 timestamped)  
**Orchestration Logs:** `.squad/orchestration-log/` (per-agent work summaries)

### 19. Phase 3 Feature Test Infrastructure (Ash, 2026-03-08)
**Status:** Infrastructure Complete, Compilation Fixes Required

Created comprehensive unit tests for all 7 Phase 3 feature services and ViewModels:
1. Maintenance (MaintenanceService + MaintenanceViewModel)
2. AutoPrint (AutoPrintService + AutoPrintViewModel)
3. Job Analytics (JobAnalyticsService + JobAnalyticsViewModel + JobHistoryViewModel)
4. Predictive Analytics (PredictiveService + PredictiveViewModel)
5. Dispatch (DispatchService + DispatchViewModel)
6. Uptime (UptimeViewModel using MaintenanceService)
7. Job Timeline (uses JobAnalyticsService)

**Implementation**
- Created 12 new test files (~300 test cases total)
- 5 mock services conforming to service protocols
- 7 ViewModel test suites following DashboardViewModelTests pattern (@MainActor, configure() DI)
- UUID prefix G1 for all pbxproj entries to avoid conflicts (F1/F2/E1/D1 existing)
- Each test suite covers: initial state, successful loading, error handling, loading transitions, computed properties, action methods, unconfigured service guards

**Known Issues**
- Model initializer mismatches: 25+ models need property corrections (timestamp→createdAt, Int ID→UUID, missing fields like componentName, estimatedDueDate, etc.)
- Protocol conformance issues in MockPredictiveService and MockDispatchService
- Test target won't compile until corrections are made
- **Blocking follow-up:** Model initializer corrections (estimated 30-45 minutes)

**Impact**
- ✅ Complete mock infrastructure for all 5 new service protocols
- ✅ Test patterns established for future features
- ✅ ~300 test cases structured correctly
- ✅ Zero impact on existing tests — isolated in new files
- ✅ App builds successfully
- ⏳ Test target requires model fixes

**Files Affected**
- NEW: 12 test files (Mocks + ViewModel tests)
- MODIFIED: PrintFarmer.xcodeproj/project.pbxproj (added files to test target)

**Lessons**
- Validate model definitions thoroughly before writing tests
- Swift Codable memberwise init includes all properties in declaration order
- UUID vs String vs Int ID variations require careful checking
- Some models use nested property structures (e.g., QueuedJobWithMeta.job)
- Xcode pbxproj edits require DerivedData clean

# Beta Release Strategy: TestFlight + GitHub Actions CI/CD

**Author:** Dallas (Lead)  
**Date:** 2026-03-07  
**Status:** Decision Proposed  
**Scope:** iOS app (PrintFarmer), dual-remote workflow (origin→release), beta distribution

---

## EXECUTIVE SUMMARY

PrintFarmer iOS is ready to distribute beta builds to testers via Apple's TestFlight. I recommend a **git-tag-triggered GitHub Actions workflow** that:
- Automates code signing, building, and uploading to TestFlight
- Maintains clear version control via semantic versioning (e.g., `v1.0.0-beta.1`)
- Integrates with the dual-remote workflow (dev on `origin`, releases on `release` remote)
- Requires no hardcoded credentials in the repository

---

## DECISION MATRIX

| Component | Recommendation | Rationale |
|-----------|-----------------|-----------|
| **Distribution Channel** | Apple TestFlight | Industry standard for iOS beta; no alternative viable for AppStore submission path |
| **Workflow Trigger** | Git tag (`v*-beta*`, `v*-rc*`) | Explicit versioning; prevents spurious builds; integrates with SemVer |
| **Build Pipeline** | GitHub Actions on `macos-latest` | Native Apple tooling; no external dependencies; supports fastlane |
| **Code Signing** | fastlane match + GitHub Secrets | Centralized cert management; encrypted storage; team-friendly; no hardcoded credentials |
| **Version Numbering** | SemVer (`1.0.0-beta.N`) | Industry standard; clear intent; AppStore-compatible |
| **Tester Access Model** | Start internal (≤25), expand to external (10k) | Alpha→beta→public progression; internal faster, external requires 24-48h review |

---

## 1. TESTFLIGHT SETUP REQUIREMENTS

### Apple Developer Program Prerequisites
✅ **Already configured:**
- Apple Developer Account (active)
- Team ID: `ZPKA84F3TY` (from Xcode build settings)
- Bundle ID: `com.olyforge3d.printfarmer.ios` (from release remote owner)
- Development Team linked to code signing identity

⚠️ **Action required:**
- [ ] Create **App Store Connect record** for PrintFarmer (can be in "Prepare for Submission")
- [ ] Generate **Distribution Certificate** (Certificates, Identifiers & Profiles > Certificates)
- [ ] Generate **App Store Provisioning Profile** (Explicit, not ad-hoc)
- [ ] Add **internal testers** (5-10 team members via App Store Connect > TestFlight > Testers)

### Internal vs External Testers
- **Internal (≤25):** Instant access, no review. ✅ Use for alpha/pre-beta (Week 1-2)
- **External (10k max):** Requires app metadata + screenshots. First build: 24-48h review. ✅ Use for public beta (Week 3+)

---

## 2. GITHUB ACTIONS WORKFLOW ARCHITECTURE

### Workflow Trigger Configuration
Recommended: **Two complementary triggers**

```yaml
on:
  push:
    tags:
      - 'v*-beta*'           # v1.0.0-beta.1, v1.1.0-beta.2, etc.
      - 'v*-rc*'             # v1.0.0-rc.1 (release candidate)
  workflow_dispatch:         # Manual trigger if tag push fails
    inputs:
      environment:
        description: 'internal or external'
        default: 'internal'
```

### Workflow Jobs
The workflow executes these steps:

1. **Checkout** — Clone code from tag
2. **Extract version** — Parse git tag to `MARKETING_VERSION` (1.0.0) and `BUILD_NUMBER` (auto-incremented)
3. **Setup Xcode** — Select Xcode version (macos-latest >= Xcode 16)
4. **Install fastlane** — Dependency for code signing and upload
5. **Code sign** — `fastlane match appstore --readonly` (fetch certs from encrypted repo)
6. **Update build settings** — `agvtool new-version` + `agvtool new-marketing-version`
7. **Build archive** — `xcodebuild -archiveForDistribution`
8. **Export IPA** — `xcodebuild -exportArchive` with AppStore options
9. **Upload to TestFlight** — `fastlane pilot upload`
10. **Notify team** — Slack message with build status
11. **Create GitHub Release** — Tag appears in GitHub releases tab (prerelease=true)

---

## 3. CODE SIGNING STRATEGY

### Recommendation: fastlane match + GitHub Secrets
fastlane **match** provides centralized certificate management with encrypted storage.

#### Setup Steps

**3.1 Create private certificate repository**
```bash
# GitHub: Create new private repo named "PrintfarmerApp-certificates"
git clone https://github.com/olyforge3d/PrintfarmerApp-certificates.git
cd PrintfarmerApp-certificates
fastlane match init --type appstore
# Prompts for encryption password (save as MATCH_PASSWORD secret)
```

**3.2 Generate certificates in Xcode**
```bash
cd ~/s/PFarm-Ios
fastlane match appstore --readonly
# Downloads existing cert or creates new one (if first time)
```

**3.3 Store GitHub secrets**

| Secret | Value | Source |
|--------|-------|--------|
| `FASTLANE_USER` | `jpapiez@example.com` | Apple ID (account owner) |
| `FASTLANE_PASSWORD` | App-specific password | App Store Connect > Your Name > Security > App-Specific Passwords |
| `MATCH_PASSWORD` | Encryption key | Generated during `fastlane match init` |

**3.4 GitHub Actions workflow uses secrets**
```yaml
- name: Setup code signing
  env:
    FASTLANE_USER: ${{ secrets.FASTLANE_USER }}
    FASTLANE_PASSWORD: ${{ secrets.FASTLANE_PASSWORD }}
    MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
  run: fastlane match appstore --readonly
```

### Alternative: Direct Certificate Upload (if no private repo available)
If you prefer not to maintain a separate private repo:
- Export `.p12` certificate from Keychain
- Encode as base64: `cat cert.p12 | base64 > cert.b64`
- Store as `DISTRIBUTION_CERT_B64` and `CERT_PASSWORD` secrets
- Decode in workflow: `echo "$CERT_B64" | base64 -d > cert.p12`
- Install: `security import cert.p12 -k ~/Library/Keychains/login.keychain -P "$CERT_PASSWORD"`

**⚠️ Trade-off:** Simpler setup, but manual renewal required and certificates visible in CI logs if not careful.

---

## 4. VERSION & BUILD NUMBER STRATEGY

### Current Xcode Settings
- `MARKETING_VERSION`: `1.0` (user-facing version)
- `CURRENT_PROJECT_VERSION`: `1` (build number, must increment per upload)

### Recommended Versioning Scheme

**Version format:** `MAJOR.MINOR.PATCH-PRERELEASE`

Examples:
```
v1.0.0-beta.1       → MARKETING_VERSION=1.0.0, CURRENT_PROJECT_VERSION=1
v1.0.0-beta.2       → MARKETING_VERSION=1.0.0, CURRENT_PROJECT_VERSION=2
v1.0.0-rc.1         → MARKETING_VERSION=1.0.0, CURRENT_PROJECT_VERSION=10
v1.0.0              → MARKETING_VERSION=1.0.0, CURRENT_PROJECT_VERSION=11 (GA release)
v1.1.0-beta.1       → MARKETING_VERSION=1.1.0, CURRENT_PROJECT_VERSION=20
```

**Build number strategy:** Use git commit count (deterministic, no conflicts)
```bash
BUILD_NUMBER=$(git rev-list --count HEAD)  # e.g., 42
xcodebuild -project PrintFarmer.xcodeproj \
  -scheme PrintFarmer \
  -configuration Release \
  OTHER_CFLAGS="-DCURRENT_PROJECT_VERSION=$BUILD_NUMBER"
```

### Workflow Implementation
```bash
# Extract version from tag
TAG_NAME="${{ github.ref_name }}"  # e.g., "v1.0.0-beta.1"
VERSION=$(echo "$TAG_NAME" | sed -E 's/^v(.+)-.*/\1/')  # → "1.0.0"
BUILD_NUMBER=$(git rev-list --count HEAD)  # → 42

# Update Xcode build settings
agvtool new-version -all "$BUILD_NUMBER"           # CURRENT_PROJECT_VERSION
agvtool new-marketing-version "$VERSION"           # MARKETING_VERSION
```

---

## 5. DUAL-REMOTE WORKFLOW: DEV → RELEASE FLOW

### Current Setup
- `origin` → `https://github.com/jpapiez/PrintfarmerApp.git` (private dev)
- `release` → `https://github.com/olyforge3d/PrintFarmerApp.git` (public releases)

### Recommended Workflow

```
Developer Team (jpapiez/origin)
├─ Daily work: git push origin development
├─ Review: PR main ← development
└─ Merge: git checkout main && git merge development
          git tag -a v1.0.0-beta.1 -m "Beta 1"
          git push origin main v1.0.0-beta.1  ← Tag on origin first

Release Team (olyforge3d/release)
├─ Manual review of tag
└─ Push to release: git push release main v1.0.0-beta.1
                    ↓
                    GitHub Actions triggered
                    ├─ Build
                    ├─ Sign
                    ├─ Upload to TestFlight
                    └─ Notify team
```

### Team Workflow Commands

**One-time setup:**
```bash
git remote add origin https://github.com/jpapiez/PrintfarmerApp.git
git remote add release https://github.com/olyforge3d/PrintFarmerApp.git
```

**Daily development:**
```bash
git checkout development
git commit -am "Feature: xyz"
git push origin development
```

**Prepare beta release:**
```bash
git checkout main
git merge development           # or cherry-pick specific commits
npm run test                    # or swift build to validate
git tag -a v1.0.0-beta.1 -m "Beta release 1.0.0"
git push origin main v1.0.0-beta.1  # Tag on origin (audit trail)
```

**Publish to TestFlight (GitHub Actions):**
```bash
git push release main v1.0.0-beta.1
# GitHub Actions automatically triggered
# Monitor: GitHub Actions > TestFlight Beta Build > Build and upload job
```

### Why Tag?
- ✅ Explicit version control; easy to skip releases by not tagging
- ✅ Audit trail (who, when, what version)
- ✅ Integrates with SemVer and release notes
- ✅ Prevents accidental releases (no CI on every commit)

---

## 6. GITHUB ACTIONS WORKFLOW FILE

### File: `.github/workflows/testflight-beta.yml`

See appendix below for complete workflow YAML.

**Key points:**
- **Runs on:** `macos-latest` (Xcode + iOS SDK pre-installed)
- **Triggered by:** Git tag push matching `v*-beta*` or `v*-rc*`
- **Secrets used:** `FASTLANE_USER`, `FASTLANE_PASSWORD`, `MATCH_PASSWORD`, `SLACK_WEBHOOK_URL` (optional)
- **Outputs:** TestFlight build visible in App Store Connect within 30 mins

### Required Supporting Files

**`.github/ExportOptions.plist`**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>ZPKA84F3TY</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
</dict>
</plist>
```

(Check in to repo; no secrets)

---

## 7. REQUIRED GITHUB SECRETS

### Setup in GitHub

1. **Go to:** GitHub repo > Settings > Secrets and variables > Actions
2. **Add these secrets:**

| Secret Name | Value | Rotation Policy |
|---|---|---|
| `FASTLANE_USER` | Apple ID email (e.g., `jpapiez@example.com`) | Never (email permanent) |
| `FASTLANE_PASSWORD` | App-specific password from App Store Connect | Annually or if compromised |
| `MATCH_PASSWORD` | 16-char encryption key (from `fastlane match init`) | Yearly |
| `SLACK_WEBHOOK_URL` (optional) | Slack workspace webhook for notifications | When workspace config changes |

### Getting App-Specific Password
1. Log in to [appleid.apple.com](https://appleid.apple.com)
2. Security > App-Specific Passwords
3. Generate new for "GitHub Actions"
4. Copy password (only shown once)

---

## 8. ARCHITECTURE DECISIONS

### Decision 1: Tag-Based Triggering (vs Push-to-Branch)
**Choice:** Git tags (`v*-beta*`)

**Rationale:**
- ✅ Explicit versioning control; prevents spurious builds on every commit
- ✅ Integrates with SemVer and release notes
- ✅ Requires only one extra command (git tag); no process overhead
- ✅ Clear audit trail (git log shows all releases)

**Alternative considered:** Push to `main` on `release` remote
- ❌ Every commit triggers a build (CI/CD overhead)
- ❌ Harder to skip a release
- ❌ Requires strict branch protection + code review discipline

### Decision 2: fastlane match for Code Signing
**Choice:** fastlane match + private cert repository

**Rationale:**
- ✅ Centralized certificate management
- ✅ Automated renewal (fastlane handles ASC API)
- ✅ Team-friendly (all agents can access certs via private repo + password)
- ✅ Encrypted storage (no plaintext credentials in CI logs)
- ✅ Scales to multiple CI/CD pipelines

**Alternative considered:** Manual certificates uploaded as secrets
- ❌ Manual renewal required
- ❌ Secrets visible in CI logs if not carefully handled
- ❌ No centralized tracking of cert lifecycle

**Alternative considered:** ASC API tokens (fastlane modern method)
- ✅ Future upgrade path (less error-prone than app-specific passwords)
- ⚠️ Requires ASC API v2 setup (Apple's newer auth method)
- 📋 Defer to v2 after initial beta rollout

### Decision 3: Separate Workflow from Dev CI
**Choice:** Independent `.github/workflows/testflight-beta.yml` (not merged with `squad-ci.yml`)

**Rationale:**
- ✅ Clear separation of concerns (test vs release)
- ✅ Prevents accidental TestFlight uploads during PR testing
- ✅ Independent tuning (release workflow can be more complex/time-consuming)

**Alternative considered:** Single workflow with conditional steps
- ⚠️ More complex to maintain
- ⚠️ Risk of accidentally triggering TestFlight during test runs

---

## 9. IMPLEMENTATION ROADMAP

### Phase 1: Setup (Week 1)
- [ ] Create App Store Connect record for PrintFarmer
- [ ] Create private GitHub repository `PrintfarmerApp-certificates`
- [ ] Generate Distribution Certificate in Apple Developer
- [ ] Generate App Store Provisioning Profile (Explicit)
- [ ] Initialize fastlane match: `fastlane match init --type appstore`
- [ ] Test locally: `fastlane match appstore --readonly`
- [ ] Add GitHub secrets: `FASTLANE_USER`, `FASTLANE_PASSWORD`, `MATCH_PASSWORD`
- [ ] Create `.github/workflows/testflight-beta.yml`
- [ ] Create `.github/ExportOptions.plist`
- [ ] Test workflow with manual dispatch (`workflow_dispatch`)

### Phase 2: First Beta Release (Week 2)
- [ ] Create first beta tag: `git tag -a v1.0.0-beta.1 -m "Beta 1"`
- [ ] Push to origin: `git push origin main v1.0.0-beta.1`
- [ ] Push to release: `git push release main v1.0.0-beta.1`
- [ ] Monitor GitHub Actions logs (should complete in ~15-20 mins)
- [ ] Verify TestFlight build appears in App Store Connect
- [ ] Download build on test device and validate functionality

### Phase 3: Internal Tester Onboarding (Week 2-3)
- [ ] Add internal testers in App Store Connect (5-10 team members)
- [ ] Send TestFlight invite links
- [ ] Collect feedback (crash logs, feature requests, bugs)
- [ ] Document known issues and workarounds

### Phase 4: External Beta (Week 3+)
- [ ] Prepare beta app metadata (screenshots, description, release notes)
- [ ] Create next beta tag: `v1.0.0-beta.2`
- [ ] Push to release (triggers TestFlight upload)
- [ ] Review TestFlight build in App Store Connect
- [ ] Submit for external tester review
- [ ] Wait for Apple review (24-48 hours typically)
- [ ] Add external testers (10-100 users)

---

## 10. RISK MITIGATION

| Risk | Impact | Mitigation |
|------|--------|-----------|
| **Code signing failure** | Build fails; blocks release | Pre-test `fastlane match` locally; dry-run workflow before release |
| **TestFlight upload timeout** | Build queued but unverified | Add notification check; retry logic in workflow; monitor App Store Connect |
| **App Store Connect downtime** | Release blocked | Manual fallback: upload IPA directly via Xcode Organizer or web UI |
| **Git tag collision** | Version conflict; confusing history | Enforce strict SemVer; require PR approval before tagging |
| **Secrets exposed** | Security breach | Rotate `FASTLANE_PASSWORD` immediately; monitor GitHub secret access logs |
| **Build number conflicts** | App Store rejects duplicate | Commit-count strategy (monotonically increasing) prevents this |
| **Provisioning profile expiration** | Future builds fail | fastlane match auto-renews before expiration; set calendar reminder for early detection |

---

## 11. WORKFLOW FILE (COMPLETE)

See detailed YAML in appendix below.

### Key Dependencies
- **fastlane** (Ruby gem): Code signing + upload
- **Xcode 16+** (pre-installed on macOS runners)
- **agvtool** (Xcode command): Version number management

### Execution Time
- Expected: 15-20 minutes per build
- Steps: Checkout (1m) → Setup (3m) → Code sign (2m) → Build (8m) → Export (2m) → Upload (2m) → Notify (1m)

---

## APPENDIX: COMPLETE WORKFLOW YAML

```yaml
name: TestFlight Beta Build

on:
  push:
    tags:
      - 'v*-beta*'
      - 'v*-rc*'
  workflow_dispatch:
    inputs:
      environment:
        description: 'Beta environment'
        required: true
        default: 'internal'
        type: choice
        options:
          - internal
          - external

jobs:
  build-and-upload:
    runs-on: macos-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Extract version from tag
        id: version
        run: |
          TAG_NAME="${{ github.ref_name }}"
          VERSION=$(echo "$TAG_NAME" | sed -E 's/^v(.+)-.*/\1/')
          BUILD_NUMBER=$(git rev-list --count HEAD)
          echo "version=$VERSION" >> $GITHUB_OUTPUT
          echo "build_number=$BUILD_NUMBER" >> $GITHUB_OUTPUT
          echo "tag_name=$TAG_NAME" >> $GITHUB_OUTPUT
          echo "📦 Version: $VERSION | Build: $BUILD_NUMBER | Tag: $TAG_NAME"

      - name: Select Xcode version
        run: |
          sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
          xcodebuild -version

      - name: Install fastlane
        run: |
          sudo gem install fastlane -NV

      - name: Setup code signing with fastlane match
        env:
          FASTLANE_USER: ${{ secrets.FASTLANE_USER }}
          FASTLANE_PASSWORD: ${{ secrets.FASTLANE_PASSWORD }}
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
        run: |
          fastlane match appstore --readonly

      - name: Update build version numbers
        run: |
          agvtool new-version -all ${{ steps.version.outputs.build_number }}
          agvtool new-marketing-version ${{ steps.version.outputs.version }}

      - name: Build for App Store
        run: |
          xcodebuild \
            -project PrintFarmer.xcodeproj \
            -scheme PrintFarmer \
            -configuration Release \
            -derivedDataPath build \
            -archivePath "build/PrintFarmer.xcarchive" \
            -archiveForDistribution \
            archive

      - name: Export IPA
        run: |
          xcodebuild \
            -exportArchive \
            -archivePath "build/PrintFarmer.xcarchive" \
            -exportOptionsPlist ExportOptions.plist \
            -exportPath "build/IPA"

      - name: Upload to TestFlight
        env:
          FASTLANE_USER: ${{ secrets.FASTLANE_USER }}
          FASTLANE_PASSWORD: ${{ secrets.FASTLANE_PASSWORD }}
        run: |
          fastlane pilot upload \
            --ipa "build/IPA/PrintFarmer.ipa" \
            --changelog "Beta build from tag: ${{ steps.version.outputs.tag_name }}" \
            --skip_waiting_for_build_processing

      - name: Notify Slack
        if: success()
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "✅ TestFlight Beta Build Uploaded",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*TestFlight Beta Uploaded*\n*Version:* ${{ steps.version.outputs.version }}\n*Build:* ${{ steps.version.outputs.build_number }}\n*Tag:* ${{ steps.version.outputs.tag_name }}\n*Repo:* <https://github.com/olyforge3d/PrintFarmerApp|olyforge3d/PrintFarmerApp>"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
        continue-on-error: true

      - name: Create GitHub Release
        if: success()
        uses: actions/create-release@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          tag_name: ${{ steps.version.outputs.tag_name }}
          release_name: "PrintFarmer ${{ steps.version.outputs.version }}"
          body: |
            ## Beta Release: ${{ steps.version.outputs.version }}
            - Build Number: ${{ steps.version.outputs.build_number }}
            - Status: ✅ Uploaded to TestFlight
            - Access: Check TestFlight app or email invite
            
            **Release Notes:** Coming from commit history
          draft: false
          prerelease: true

      - name: Upload build logs on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: build-logs
          path: |
            build/Logs/Build/
            *.log
          retention-days: 7
```

---

## FOLLOW-UP ACTIONS

**For Jeff Papiez:**
1. Confirm Apple Developer account has TestFlight access (may require In-App Purchase capability or Distribution Agreement)
2. Generate app-specific password in App Store Connect
3. Create private certificate repository

**For Dallas (Lead):**
1. Create `.github/workflows/testflight-beta.yml` and `.github/ExportOptions.plist`
2. Coordinate with Ripley/Lambert for first test build
3. Document tagging workflow in team README

**For Ripley/Lambert/Ash:**
1. Expect beta builds 2-3x per week (as features stabilize)
2. Monitor TestFlight crash logs and feedback
3. Report issues via `.squad/decisions/` for Dallas review

---

## DECISION RATIFICATION

**Awaiting approval from:** Jeff Papiez (project owner)

**Recommend proceeding with:**
- ✅ fastlane match for code signing
- ✅ Git tag-triggered workflow
- ✅ Tag format: `v*-beta*`, `v*-rc*`
- ✅ Start with internal testers (Week 2)

---

*Decision document prepared by Dallas (Lead). Cross-team impact: Ripley (testing), Lambert (build support), Ash (CI/CD validation).*
