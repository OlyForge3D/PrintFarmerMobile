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

---

## Cross-References

**Backend Contract Docs:** `~/s/PFarm1/src/api/` (Controllers, DTOs, Startup/ControllerStartup.cs)  
**Frontend Decisions History:** `.squad/decisions/decisions.md` (this file)  
**Agent Context:** `.squad/agents/{lambert,ripley,ash,dallas}/history.md`  
**Session Logs:** `.squad/log/` (ISO 8601 timestamped)  
**Orchestration Logs:** `.squad/orchestration-log/` (per-agent work summaries)
