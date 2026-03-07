# QA Audit — PrintFarmer iOS MVP

**Auditor:** Dallas (Lead)
**Date:** 2025-07-18
**Scope:** Full codebase audit — runtime, API contracts, UI, navigation, theme, concurrency
**Backend Reference:** ~/s/PFarm1/src/api/Controllers/ and ~/s/PFarm1/src/infra/Dtos/

---

## Summary

**Verdict: 🟡 NOT YET PRODUCTION READY — 4 critical fixes required**

| Severity | Count |
|----------|-------|
| 🔴 Critical | 4 |
| 🟡 Important | 7 |
| 🟢 Minor | 5 |

API contract verification: ✅ All endpoints and request/response models match the backend. No mismatches found in endpoint paths, field names, or types.

The previously reported "PrinterDetailViewModel method mismatches" (from MVP build) have been resolved.

---

## 🔴 Critical Issues (Crashes or Data Corruption)

### C1. AppRouter Missing @MainActor
- **File:** `PrintFarmer/Navigation/AppRouter.swift` line 3
- **Issue:** `AppRouter` is `@Observable` but NOT `@MainActor`. It manages `NavigationPath` and `selectedTab` which are UI state. Any background task mutating these properties causes a race condition and potential crash.
- **Fix:** Add `@MainActor` annotation to the class.

### C2. AuthViewModel Missing @MainActor
- **File:** `PrintFarmer/ViewModels/AuthViewModel.swift` line 5-6
- **Issue:** Uses `@unchecked Sendable` instead of `@MainActor`. Mutates `isAuthenticated`, `currentUser`, `isLoading`, `errorMessage` — all UI-driving properties — without main actor isolation. The `login()` and `restoreSession()` methods update these from async contexts.
- **Fix:** Replace `@unchecked Sendable` with `@MainActor`.

### C3. SignalR Date Decoder Will Reject Backend Timestamps
- **File:** `PrintFarmer/Services/SignalRService.swift` line 38
- **Issue:** Uses `.iso8601` date decoding strategy, which rejects fractional seconds. The backend (ASP.NET Core) sends timestamps like `2024-01-15T10:30:45.1234567Z`. Every `printerupdated` and `jobqueueupdate` message with a timestamp will fail to decode, making real-time updates completely non-functional.
- **Impact:** SignalR updates silently fail. Printers appear stale.
- **Fix:** Use the same custom date decoder as `APIClient` (lines 36-45) with dual-format fallback.

### C4. SignalR Force Unwraps on URLComponents
- **File:** `PrintFarmer/Services/SignalRService.swift` lines 93 and 117
- **Issue:** `URLComponents(url: serverURL, resolvingAgainstBaseURL: true)!` — force unwrap crashes if the URL has unusual encoding or format. This is in the connection path, so any URL edge case crashes the entire app when SignalR connects.
- **Fix:** Use `guard let` with error throwing.

---

## 🟡 Important Issues (Broken UX or Incorrect Data)

### I1. 17 Hardcoded Colors Instead of Theme Colors
Breaks dark mode consistency and theme cohesion.

| File | Lines | Colors Used |
|------|-------|-------------|
| `Views/Components/PrinterCardView.swift` | 38, 49 | `.orange`, `.blue` |
| `Views/Components/TemperatureView.swift` | 46-49 | `.red`, `.orange`, `.yellow`, `.blue` |
| `Views/Components/StatusBadge.swift` | 42, 58 | `.purple`, `.cyan` |
| `Views/Printers/PrinterDetailView.swift` | 100, 231, 235, 247, 254, 280 | `.purple`, `.orange`, `.red` |
| `Views/Jobs/JobDetailView.swift` | 238 | `.red` |
| `Views/Jobs/JobListView.swift` | 216, 244 | `.red`, `.orange` |
| `Views/Notifications/NotificationsView.swift` | 66 | `.blue` |

**Fix:** Define `pfMaintenance`, `pfHotend`, `pfBed`, `pfDanger` in the Theme and replace all instances.

### I2. Three Placeholder Navigation Destinations
- **File:** `PrintFarmer/Views/Dashboard/DashboardView.swift` lines 226-231
- **Issue:** `locationDetail`, `createJob`, and `createPrinter` destinations render empty `Text()` placeholders. Users who trigger these routes see a blank screen with no way to understand what happened.
- **Fix:** Either implement the views or remove these cases from `AppDestination` enum and any code that navigates to them.

### I3. Silent Error Suppression in ViewModels
- **Files:**
  - `ViewModels/PrinterDetailViewModel.swift` lines 61-63: `try?` for status, current job, and snapshot
  - `ViewModels/DashboardViewModel.swift` line 36: `try?` for statistics summary
- **Issue:** Secondary data loads fail silently. User gets no indication that snapshot, status, or stats failed. No retry available.
- **Fix:** Catch errors and set a secondary error state, or at minimum log them.

### I4. Partial Error State Hidden in Dashboard
- **File:** `PrintFarmer/Views/Dashboard/DashboardView.swift` lines 16-17
- **Issue:** Error view only shows when `printers.isEmpty && error != nil`. If some printers load but the request partially fails, the error is swallowed and the user sees an incomplete list with no indication of failure.
- **Fix:** Show an inline error banner even when partial data is present.

### I5. No Feedback on Failed Job Navigation
- **File:** `PrintFarmer/Views/Jobs/JobListView.swift` lines 81-82, 131-132, 186-187
- **Issue:** Navigation to job detail only fires if `jobUUID` can be parsed. If the analytics endpoint returns a string ID that isn't a valid UUID, the tap does nothing — no error, no feedback.
- **Fix:** Show an alert or toast when navigation can't resolve.

### I6. Zero Accessibility Labels
- **Issue:** No `accessibilityLabel`, `accessibilityHint`, or `accessibilityValue` modifiers anywhere in the codebase. The entire app is inaccessible to VoiceOver users. All buttons, status badges, progress indicators, and interactive elements lack labels.
- **Fix:** Add accessibility modifiers to all interactive and informational elements. Priority: action buttons (pause/resume/stop/cancel/emergency-stop), status badges, temperature displays.

### I7. SignalR @unchecked Sendable With Unprotected Mutable State
- **File:** `PrintFarmer/Services/SignalRService.swift` lines 25-26
- **Issue:** `reconnectAttempt` and `intentionalDisconnect` are mutable properties accessed from multiple Task contexts without lock protection. Only the handler arrays are lock-protected. Could cause reconnection logic to misbehave under concurrent disconnects.
- **Fix:** Protect with `handlerLock` or convert to actor isolation.

---

## 🟢 Minor Issues (Polish, Cosmetic)

### M1. PrinterService Has Methods Not on Protocol
- **File:** `PrintFarmer/Services/PrinterService.swift` lines 22-27
- **Issue:** `update(id:_:)` and `delete(id:)` exist on the concrete `PrinterService` but not on `PrinterServiceProtocol`. Can't call through the protocol abstraction; tests can't mock them.
- **Fix:** Add to protocol or remove if not MVP.

### M2. Missing .task(id:) Dependency Tracking
- **Files:** `PrinterDetailView.swift` line 56, `JobDetailView.swift` line 52
- **Issue:** `.task { }` fires once on appear. If the view is reused with a different ID (e.g., via NavigationPath manipulation), data won't reload.
- **Fix:** Use `.task(id: printerId) { ... }`.

### M3. AppConfig Force Unwrap
- **File:** `PrintFarmer/Utilities/AppConfig.swift` line 12
- **Issue:** `URL(string: "http://localhost:5000")!` — safe for this constant but fragile pattern. Any future edit to the string could introduce a crash.
- **Fix:** Use `guard let` or add a comment documenting why force unwrap is safe.

### M4. Test Suite: 2 Inverted Assertions
- **Files:** `DashboardViewModelTests.testLoadWithoutConfigureDoesNotCrash()`, `PrinterListViewModelTests.testLoadWithoutConfigureDoesNotCrash()`
- **Issue:** Assertions are inverted and always pass regardless of behavior. Gives false confidence.
- **Fix:** Fix assertion logic.

### M5. Test Suite: 4 Services Completely Untested
- **Issue:** JobService, NotificationService, StatisticsService, and SignalRService have zero test coverage. Only the protocols and mocks exist.
- **Fix:** Add test suites for these services before production release.

---

## ✅ Verified Correct

- **All API endpoint paths match backend** — including `/api/job-queue` (hyphenated), `/api/printers/{id}/emergency-stop`, `/api/printers/{id}/maintenance`, `/api/job-queue/{id}/abort-print`
- **All iOS model field names and types match backend DTOs** — camelCase mapping works correctly with ASP.NET Core's default JSON serializer settings
- **CreatePrintJobRequest and UpdatePrintJobRequest match backend** — fields align with `CreatePrintJobDto` and `UpdatePrintJobDto` in `PrintJobDtos.cs`
- **QueueOverview matches QueueOverviewDto** — all 11 fields match
- **All enum raw values match backend** — PrintJobStatus, PrintJobPriority, PrinterBackend, MotionType, AutoPrintState all verified
- **APIClient date decoder handles both fractional and plain ISO 8601** — custom strategy with dual-format fallback
- **Debug logging properly guarded with `#if DEBUG`** — lines 153-158 in APIClient.swift
- **PrinterDetailViewModel method signatures match protocol** — previous mismatch (snapshotURL/cancelPrint/setMaintenance) has been fixed
- **All 6 ViewModels (except AuthViewModel) have @MainActor @Observable** — proper actor isolation

---

## Recommended Fix Order

1. **C1 + C2** (15 min): Add `@MainActor` to AppRouter and AuthViewModel
2. **C3** (15 min): Copy APIClient's custom date decoder to SignalRService
3. **C4** (10 min): Replace force unwraps with guard-let in SignalR
4. **I1** (45 min): Define theme colors and replace 17 hardcoded instances
5. **I2** (10 min): Remove unused AppDestination cases or add "coming soon" views
6. **I3 + I4** (30 min): Add proper error handling for secondary data loads
7. **I6** (2 hours): Add accessibility labels throughout
8. **Remaining** (1-2 hours): Minor items

**Total estimated effort: ~5 hours for all fixes**
