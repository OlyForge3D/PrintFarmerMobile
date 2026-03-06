# MVP Test Architecture

**Author:** Ash (Tester/QA)
**Date:** 2025-07-17
**Status:** Implemented

---

## Decision: Test infrastructure for the MVP

### Testing Strategy
1. **Service/API tests** use `MockURLProtocol` to intercept real `URLSession` calls — tests the full code path through `APIClient` → `PrinterService` without network.
2. **ViewModel tests** use protocol-based mock services injected via `configure()` — fast, isolated, no shared state.
3. **Model decoding tests** use realistic JSON fixtures derived from backend DTOs at `~/s/PFarm1/src/infra/Dtos/`.

### Mock Infrastructure
All service protocols have mock implementations in `PrintFarmerTests/Mocks/`:
- `MockPrinterService`, `MockJobService`, `MockAuthService`, `MockNotificationService`, `MockStatisticsService`, `MockSignalRService`
- `MockAPIClient` helper for configuring `MockURLProtocol`
- `TestFixtures` with realistic JSON from the backend

### Issues Found for Team
1. **PrinterDetailViewModel method mismatch** — calls `snapshotURL(for:)`, `cancelPrint(id:)`, `setMaintenance(id:enabled:)` which don't exist on `PrinterServiceProtocol`. Ripley needs to align method names.
2. **No `AuthServiceProtocol`** — AuthService is a concrete actor. Should get a protocol for testable ViewModels (AuthViewModel).
3. **SPM `@main` duplicate symbol** — PFarmApp.swift's `@main` conflicts with test runner. Not blocking (Xcode builds fine), but SPM `swift test` won't work.

### Coverage Targets
- ✅ APIClient: JWT injection, error mapping (401/403/404/500), request building
- ✅ AuthService: login/logout, token lifecycle, URL normalization
- ✅ PrinterService: all endpoints including pause/resume/cancel/stop/emergency-stop
- ✅ Model decoding: Printer, PrintJob, Location, AuthResponse, CommandResult, QueueOverview, SignalR DTOs
- ✅ LoginViewModel: form validation, URL normalization, persistence
- ✅ DashboardViewModel: load, computed counts, error handling, refresh
- ✅ PrinterListViewModel: load, search, status filtering, pull-to-refresh
- ✅ PrinterDetailViewModel: commands, destructive action confirmations, error handling

**Impact:** All team members can now run tests to validate their work. Mocks are ready for any new ViewModel or service.
