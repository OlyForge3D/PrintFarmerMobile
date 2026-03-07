# Test Coverage Extension Decision

**Author:** Ash (Tester)
**Date:** 2025-07-18
**Status:** Implemented

## Summary
Extended test suite from 146 → 226 test cases (+80). Four new ViewModel test suites cover all previously untested ViewModels.

## Key Decisions

### AuthViewModel Testing Pattern
AuthViewModel depends on concrete `AuthService` actor (no protocol). Tests use MockURLProtocol integration testing through the full AuthVM → AuthService → APIClient stack. This is different from other ViewModel tests which use protocol-based mocks via `configure()`.

**Recommendation for Ripley/Lambert:** Consider extracting `AuthServiceProtocol` from the concrete `AuthService` to enable protocol-based mock testing. `AuthServiceProtocol` already exists in TestProtocols.swift but isn't used by production code.

### PushNotificationManager Not Testable
PushNotificationManager is a singleton with concrete UIKit dependencies (UNUserNotificationCenter, UIApplication). Cannot be unit tested without significant refactoring. **Acceptable risk** for MVP — push notification flows should be validated via manual QA on device.

## Coverage Gaps Remaining
| Component | Status | Notes |
|-----------|--------|-------|
| JobService (actor) | Indirect | Tested via ViewModel mocks; needs dedicated MockURLProtocol tests like PrinterServiceTests |
| StatisticsService (actor) | Indirect | Same as above |
| NotificationService (actor) | Indirect | Same as above |
| PushNotificationManager | Untestable | Singleton + UIKit runtime dependency |

## Impact
- All team members: new test suites follow established patterns and should pass in Xcode
- SPM `swift build` still blocked by pre-existing XCTest module limitation (not related to changes)
