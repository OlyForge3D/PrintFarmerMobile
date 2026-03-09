# Ash — History

## Core Context (Archived)

### Project Setup & Architecture (Dallas, 2026-03-06)
- **Project:** PFarm-Ios — Native iOS client for Printfarmer backend (~/s/PFarm1)
- **User:** Jeff Papiez
- **Stack:** Swift, SwiftUI, iOS 17+, MVVM + Repository Pattern, @Observable ViewModels, Actor-based services, ServiceContainer DI, KeychainSwift for token storage
- **Build:** SPM (Package.swift) for CLI validation, Xcode (.xcodeproj) for IDE, target iOS 17+, Swift 6.0

### Test Infrastructure Established (2025-07-17 → 2026-03-08)
- **Unit test architecture:** MockURLProtocol for service/APIClient integration tests; protocol-based mocks for ViewModel unit tests
- **19+ test files created:** 2 helpers, 8+ mocks, 1 model decoding suite, 3+ service test suites, 4+ ViewModel test suites; ~150+ test cases total
- **ViewModel DI pattern:** `configure(services:)` method with protocol-based DI; all ViewModel tests use protocol mocks — no network calls
- **Protocol coverage:** PrinterServiceProtocol, JobServiceProtocol, NotificationServiceProtocol, StatisticsServiceProtocol, SignalRServiceProtocol, SpoolServiceProtocol all have mock implementations
- **Mock services:** MockPrinterService, MockJobService, MockSpoolService, MockNFCService, MockAuthService, MockAPIClient all available in test helpers
- **XCUITest scaffolding:** PrintFarmerUITests.swift (base), LoginFlowUITests.swift, PrinterListUITests.swift created; target creation deferred to manual Xcode step
- **XCUITest infrastructure:** Ready to integrate with Lambert's MockAPIServer for deterministic UI test scenarios; environment variable injection pattern established (PFARM_MOCK_SERVER_URL)

### Known Test Patterns & Gotchas
- **Status filters:** SpoolmanSpool.inUse is Bool?; all filter tests cover nil/true/false edge cases
- **Empty filter behavior:** nil remainingWeightG with non-nil initialWeightG treated as empty — documented false positive from UI audit
- **Test simulator:** iPhone 17 for test runs
- **`.constant()` binding anti-pattern:** Used in 5 alert presentations; works but fragile, should be refactored to proper Binding eventually
- **UUID prefix:** F2 used for pbxproj test entries to avoid conflicts with F1

### Test Suite Growth (2025-07-17 → 2026-03-08)
1. **MVP test suite (2025-07-17):** ~80 test cases across service + ViewModel tests
2. **Spool feature tests (2025-07-20):** 68 new test cases (AddSpoolViewModelTests 25 cases, SpoolInventoryViewModelTests 43 cases)
3. **Phase 3 tests (2026-03-07 → 2026-03-08):** 7 new feature ViewModels + 5 new services with ~300 test cases total

### Completed Work (2026-03-08)
- **Phase 3 Feature Tests:** Comprehensive test coverage for all 7 new feature services and ViewModels (MaintenanceService, AutoPrintService, JobAnalyticsService, PredictiveService, DispatchService)
- **Test files created:** 5 mock services + 7 ViewModel test suites (~300 test cases)
- **DeepLinkHandler Tests:** 8 test cases covering printer/spool URL scheme parsing
- **NFC Navigation Integration:** Tests coordinated with Ripley's AppRouter.navigate(to:) async delay (50ms sleep between path reset and append)
- **Spool NFC Tests:** Fixtures include `hasNfcTag: nil` parameter for backward compat testing

---

## Learnings

### Test Architecture Patterns (2025-07-17 → 2026-03-08)
- **MockURLProtocol** works well for APIClient integration tests; allows in-process HTTP mocking without external servers
- **Protocol-based DI** in ViewModels enables clean unit testing without network calls; `configure(services:)` pattern adopted project-wide
- **MockServices** should mirror protocol signatures exactly; any protocol change requires corresponding mock updates
- **Status filter edge cases** (Bool? fields) require explicit nil/true/false test paths to catch filter logic bugs
- **Combined filters** (material AND status AND search) need intersection logic tests to verify all combinations

### XCUITest Infrastructure
- **Process isolation** requires real TCP mock server (MockAPIServer), not in-process URLSession interception
- **Environment variable injection** (PFARM_MOCK_SERVER_URL) allows XCUITests to redirect all API calls to mock server
- **Scenario-based test data** — MockAPIServer supports configurable responses for deterministic UI testing
- **UI test target creation** is a manual Xcode step; test files can be pre-written and added to target later

### New Service Layer Testing Patterns
- 5 new service protocols follow existing Actor-based pattern
- Mock implementations should verify: success paths, error paths, empty result paths, state mutations
- Request DTO validation should be tested in ViewModel layer, not service layer
- Date query parameters (ISO8601Plain format) should be validated in APIClient tests

### Cross-Team Dependency Management
- Parallel execution (Lambert services + Ripley UIs) requires upfront protocol definitions; Ash waits for both to complete
- Mock service implementations depend on finalized protocol signatures; changes to Lambert's protocols require corresponding mock updates
- ViewModel tests depend on stable mock interfaces; test cases should verify that ViewModels use services correctly
- ServiceContainer registration must be complete before integration testing

### NFC Testing Integration
- **DeepLinkHandler tests** cover URL scheme parsing for both printer (`printfarmer://printer/{UUID}`) and spool (`printfarmer://spool/{id}`) deep links
- **Navigation race condition:** AppRouter.navigate(to:) uses async sleep; tests calling this directly should use `await` or integration test patterns
- **Spool NFC tests** should verify: badge rendering (hasNfcTag nil/true/false), filter logic (coalescing pattern), write flow (success/error states)
- **iPhone-only Core NFC:** All NFC tests confined to iPhone, not iPad

### Cross-Agent Update: Ripley — Predictive Insights Fix (2026-03-08T2356)
**From:** Ripley  
**Task:** Fixed Predictive Insights decode error
**Impact to Ash:**
- `MockPredictiveService.predictJobFailure` now returns `Optional<JobFailurePrediction>` instead of non-optional
- Tests expecting force-unwrap of this value require updating (use optional binding or nil coalescing)
- View tests should verify "No predictions available" empty state when service returns nil
- Decode tests should verify decodeIfPresent behavior for predictive models with missing fields

---

### Cross-Agent Update: Ripley — Set Filament Button Visibility Fix (2026-03-09T00:08)
**From:** Ripley  
**Task:** Fixed "Set Filament" button remaining visible after spool assignment  
**Impact to Ash:**
- `PrinterDetailViewModel` now has testable `effectiveSpoolInfo` computed property
- New `lastSetSpoolInfo: PrinterSpoolInfo?` property gets populated after successful `setActiveSpool`
- Tests should verify: button visibility depends on `effectiveSpoolInfo` (not direct `printer.spoolInfo`), fallback to local override when server data unavailable, cleared on spool eject
- Test fixture: `PrinterSpoolInfo` requires memberwise init (already available in Models.swift)

