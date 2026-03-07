# Session Expired Auto-Logout Pattern (Lambert, QA Audit)
**Status:** Implemented

## Decision
When the backend returns a 401 or the JWT token is expired (with 5-minute buffer), the app automatically logs out:

1. **APIClient** posts `Notification.Name.sessionExpired` on 401 responses
2. **APIClient** checks `AuthService.isTokenExpired()` (via closure) before every request — proactively catches expired tokens without a network round-trip
3. **AuthViewModel** observes `.sessionExpired` and calls `logout()`, which flips `isAuthenticated = false` → SwiftUI navigates to LoginView

## Impact
- **Ripley:** No UI changes needed — SwiftUI automatically shows LoginView when `isAuthenticated` flips to false
- **Ash:** Test mocks unaffected — `tokenExpiryChecker` is optional, defaults to nil (no pre-check)
- **AuthViewModel** is now `@MainActor @Observable` (was `@Observable @unchecked Sendable`) — any code creating/accessing it should be MainActor-aware

## Rationale
- No refresh token exists (single JWT) — re-login is the only recovery path
- Proactive expiry check avoids wasted network calls and better UX (immediate redirect vs waiting for 401)
- Notification pattern decouples APIClient from AuthViewModel (no circular dependency)
