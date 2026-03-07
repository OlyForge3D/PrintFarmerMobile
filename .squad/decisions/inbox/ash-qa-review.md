# QA Review: PrintFarmer iOS MVP

**Reviewer:** Ash (Tester)  
**Date:** 2025-07-18  
**Scope:** Test coverage, error handling, edge cases, mock alignment, memory safety

---

## Executive Summary

The codebase has solid fundamentals — good architecture, safe memory patterns, and working test infrastructure. However, **test coverage sits at ~41%** (7/17 testable units), two major views silently swallow errors, and token expiration is stored but never validated. These are the items that need attention before release.

---

## 1. TEST COVERAGE GAPS

### Critical — No Tests Exist

| Component | Priority | Why It Matters |
|-----------|----------|----------------|
| **AuthViewModel** | 🔴 Critical | Controls login/logout/session restore — the gateway to the entire app |
| **JobListViewModel** | 🟡 Important | Job filtering logic (active/queued/recent) untested |
| **JobDetailViewModel** | 🟡 Important | Action guards (canDispatch, canCancel, canAbort) untested |
| **NotificationsViewModel** | 🟡 Important | Unread count tracking and optimistic delete untested |
| **JobService** | 🟡 Important | 9 endpoints, zero tests (PrinterService has tests — same pattern) |
| **NotificationService** | 🟡 Important | 5 endpoints, zero tests |
| **SignalRService** | 🟡 Important | Complex WebSocket protocol, reconnection logic untested |
| **StatisticsService** | 🟢 Minor | Single endpoint wrapper, low risk |
| **LocationService** | 🟢 Minor | Deferred feature, no protocol, not in MVP path |

**Existing coverage (working well):** DashboardViewModel, LoginViewModel, PrinterDetailViewModel, PrinterListViewModel, APIClient, AuthService, PrinterService, ModelDecoding — all solid with ~145 test cases.

---

## 2. ERROR HANDLING ISSUES

### 🔴 Critical: Two Views Silently Swallow Errors

**JobListView** — ViewModel sets `errorMessage` on failure, but the view never displays it. If job loading fails or cancel/abort fails, the user sees nothing — just an empty list or stale data.

**Fix:** Add error state branch before empty state check:
```swift
} else if let error = viewModel.errorMessage {
    ContentUnavailableView("Something Went Wrong", systemImage: "exclamationmark.triangle", description: Text(error))
}
```

**NotificationsView** — Same pattern. Errors from loading, marking read, or deleting are set on the ViewModel but never shown to the user.

**Fix:** Same pattern as JobListView — add error ContentUnavailableView.

### 🟡 Important: No Global 401 → Auto-Logout

When a token expires during active use, API calls return 401. The error is thrown and caught per-view, but **no mechanism forces the user back to login**. They'll see generic error states on every screen until they manually log out.

**Fix:** Post a `SessionExpired` notification from APIClient on 401. AuthViewModel observes it and calls `logout()`, which flips `isAuthenticated = false` and SwiftUI navigates to LoginView automatically.

### 🟡 Important: Token Expiry Stored but Never Checked

AuthService stores token expiry in Keychain (line 82-89) but never validates it before making requests. The app will attempt API calls with known-expired tokens.

**Fix:** Add `isTokenExpired()` check with 5-minute buffer. Check before API calls or on app foreground.

### 🟡 Important: DashboardView Missing Empty State

If the server legitimately returns zero printers (new account), the dashboard shows empty summary cards with "0" counts — no helpful empty state message guiding the user.

**Fix:** Add EmptyStateView branch when `printers.isEmpty && !isLoading && errorMessage == nil`.

### 🟢 Minor: Settings Server URL Not Validated

SettingsView lets users change the server URL with no format validation. An invalid URL is saved to UserDefaults and silently breaks on next login attempt.

### 🟢 Minor: Optimistic Delete Without Rollback (NotificationsViewModel)

`deleteNotification()` removes from the local array before the API confirms. If the API call fails, the notification disappears from UI but still exists on server. No rollback logic.

---

## 3. EDGE CASES

### Rapid Tab Switching
- `.task` modifiers on all tab views configure and load data. Rapid switching could trigger multiple concurrent loads. SwiftUI cancels tasks on view disappearance, so this is **low risk** — but duplicate `configure()` calls are wasteful.
- **Severity:** 🟢 Minor (SwiftUI handles this correctly in practice)

### Empty Data States
- PrinterListView: ✅ Has EmptyStateView
- JobListView: ✅ Has EmptyStateView  
- NotificationsView: ✅ Has EmptyStateView
- DashboardView: ❌ Missing (see above)

### Long Text Handling
- ✅ Most views use `.lineLimit(1)` or `.lineLimit(2)` properly
- ⚠️ DashboardView maintenance printer names joined with commas — no lineLimit. Very long lists could overflow.
- **Severity:** 🟢 Minor

### Network Timeout / Offline
- All views with error states have "Retry" buttons ✅
- LoginView lacks explicit retry UX (user must re-tap Sign In) — acceptable
- No offline mode or cached data — expected for MVP

### Progress / Division Safety
- All progress calculations use guards (`eta > 0`, `target > 0`) before division ✅
- PrintProgressBar clamps to [0, 1] ✅
- TemperatureView guards `target > 0` ✅

---

## 4. MOCK ALIGNMENT

**All 6 protocol mocks perfectly match their protocol signatures.** ✅

| Mock | Protocol | Status |
|------|----------|--------|
| MockPrinterService | PrinterServiceProtocol | ✅ Perfect match |
| MockJobService | JobServiceProtocol | ✅ Perfect match |
| MockNotificationService | NotificationServiceProtocol | ✅ Perfect match |
| MockStatisticsService | StatisticsServiceProtocol | ✅ Perfect match |
| MockSignalRService | SignalRServiceProtocol | ✅ Perfect match |
| MockAuthService | AuthServiceProtocol (test-only) | ✅ Perfect match |

No broken references detected in existing tests. All type names, method signatures, and model properties are current.

---

## 5. MEMORY / RETAIN CYCLES

**Overall: ✅ Excellent — No active retain cycles found.**

| Area | Finding |
|------|---------|
| SignalRService tasks | ✅ Uses `[weak self]` correctly in receive/ping loops |
| ViewModel closures | ✅ No self-captures; SwiftUI value-type views are safe |
| ServiceContainer | ✅ Singleton ownership of services is correct pattern |
| Task lifecycle | ✅ SwiftUI `.task` modifier auto-cancels on view disappearance |

### Future Risk: SignalR Handler Accumulation

`onPrinterUpdated()` and `onJobQueueUpdated()` append handlers to arrays with **no unregister mechanism**. Currently safe (no ViewModels register handlers yet), but if a ViewModel registers a handler capturing `self`, it will leak.

**Fix:** Add `clearHandlers()` method to SignalRService, called on `disconnect()`.

### Minor: Redundant AuthService Instance

`PFarmApp.init()` creates a **new** AuthService instead of using `ServiceContainer.authService`. Two AuthService instances exist, both pointing to the same APIClient. Not a leak, but confusing.

**Fix:** Use `container.authService` instead of creating a new instance.

---

## 6. PRIORITIZED ACTION ITEMS

### Before Release
1. **🔴 Add error UI to JobListView** — users can't see job operation failures
2. **🔴 Add error UI to NotificationsView** — users can't see notification errors
3. **🔴 Add AuthViewModel tests** — auth flow is untested critical path
4. **🟡 Implement 401 → auto-logout** — prevents stuck error states on token expiry
5. **🟡 Add DashboardView empty state** — new users see confusing zero-count cards
6. **🟡 Write JobListViewModel + JobDetailViewModel tests** — mirrors existing patterns

### Post-Release
7. **🟡 Add token expiry pre-check** in AuthService
8. **🟡 Add SignalR handler cleanup** mechanism
9. **🟢 Fix redundant AuthService** in PFarmApp.init()
10. **🟢 Add JobService + NotificationService tests** (follows PrinterService pattern)
11. **🟢 Validate server URL format** in SettingsView
12. **🟢 Add rollback logic** for optimistic notification delete

---

## Owners

| Item | Owner |
|------|-------|
| #1, #2 Error UI fixes | **Ripley** |
| #3, #6, #10 Test suites | **Ash** |
| #4 Auto-logout on 401 | **Lambert** (APIClient) + **Ripley** (AuthViewModel) |
| #5 Dashboard empty state | **Ripley** |
| #7, #8 Token/SignalR | **Lambert** |
| #9 Redundant AuthService | **Dallas** |
| #11, #12 Settings/Notifications | **Ripley** |
