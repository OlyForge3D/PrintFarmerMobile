# Squad Decisions

## Active Decisions

### Copilot Model Directive (Jeff Papiez, 2026-03-06)
**Status:** Accepted

#### Recommended Model for Code-Writing Agents
- Use **claude-opus-4.6** for Ripley (iOS Dev), Lambert (Networking), Ash (UI/Navigation)
- Use cost-optimized models (Haiku) for Scribe and non-code tasks
- **Rationale:** Code quality and architectural decisions benefit from stronger model reasoning

---

### Login Screen Architecture (Ripley, 2026-03-06)
**Status:** Implemented

#### Form State Separation
- **LoginViewModel** (`@MainActor @Observable`): Manages serverURL, username, password, validation
- **AuthViewModel** (`@Observable @unchecked Sendable`): Manages isAuthenticated, currentUser
- LoginViewModel delegates authentication to AuthViewModel, keeping form concerns isolated

#### Server URL Flow
- User enters server URL in LoginView → LoginViewModel normalizes → AuthViewModel passes to AuthService.login(serverURL:) → AuthService calls APIClient.updateBaseURL()
- Server URL persisted in UserDefaults (`pf_server_url`)
- On app launch, APIClient.savedBaseURL() restores last-used server

#### Session Restore Pattern
- AuthViewModel created as `@State` in PFarmApp; AuthService injected via configure(with:) in .task
- Dark Mode support confirmed working
- Error handling with animated banner

**Impact:** 
- Lambert's AuthService.login(serverURL:) API is concrete
- Dallas's PFarmApp wiring pattern established
- Ash has clear dependency injection precedent

---

### Auth Response Contract: Single JWT Token (Lambert, 2026-03-06)
**Status:** Implemented

#### Token Model
- Backend returns single `token` field in AuthenticationResult (not separate access/refresh)
- iOS AuthResponse updated to match (verified against PFarm1 backend)

#### Token Lifecycle
- Single JWT stored in Keychain (key: `pf_jwt_token`)
- No token refresh endpoint; re-authentication required if token expires
- Session restore via `GET /api/auth/me` validates token; logs out if expired

#### Base URL Management
- Server URL entered at login, stored in UserDefaults (`pf_server_url`)
- APIClient.updateBaseURL() is single mutation point (actor-isolated)
- Restored on app launch

**Impact:**
- Ripley's LoginViewModel can safely call AuthService.login(serverURL:)
- Dallas's DI pattern compatible with actor isolation
- No refresh logic needed; simplifies token lifecycle

---

### iOS Project Structure (Dallas, 2025-07-16)
**Status:** Accepted

#### Architecture: MVVM + Repository Pattern
- **Views** (SwiftUI) → **ViewModels** (`@Observable`) → **Services** (actor-based) → **APIClient** (actor)
- Services are actors for thread-safe network access under Swift 6 strict concurrency
- ViewModels are `@Observable` (not ObservableObject) for modern SwiftUI

#### Navigation: Router + TabView
- `AppRouter` (`@Observable`) manages tab selection and per-tab `NavigationPath`
- 5 tabs: Dashboard, Printers, Jobs, Locations, Settings
- Deep navigation via `AppDestination` enum with associated values

#### Dependency Injection: ServiceContainer
- Single `ServiceContainer` created at app launch, passed via SwiftUI environment
- No third-party DI framework — keep it simple

#### Auth: Keychain + JWT
- KeychainSwift for secure token storage
- `AuthService` manages login/logout/session restore
- `AuthViewModel` gates root view (login vs main app)

#### Networking: Actor-based APIClient
- `APIClient` is a Swift actor — all token and request state is isolated
- ISO 8601 date decoding, typed `NetworkError` enum
- Base URL configurable via `PRINTFARMER_API_URL` env var

#### Models: Sendable Codable structs
- All models conform to `Codable`, `Identifiable`, `Sendable`
- Organized: `Models.swift` (core), `RequestModels.swift` (DTOs), `SignalRModels.swift` (real-time)
- Property names match backend JSON (camelCase) — no custom CodingKeys needed

#### SignalR: Deferred
- Stub created. Client package selection deferred — candidates:
  - microsoft/signalr-client-swift (official)
  - moozzyk/SignalR-Client-Swift (community)

#### Build: Dual SPM + Xcode
- Package.swift for CLI validation (`swift build`)
- .xcodeproj for full Xcode experience (previews, simulator, device)
- iOS 17+, Swift 6.0, bundle ID: com.printfarmer.ios

---

## MVP Build Batch Decisions (Consolidated 2026-03-06T19:11:00Z)

### Phone-First Design Principle (Dallas)
**Status:** Accepted

- Every feature answers: *"Would someone pull out their phone to do this?"*
- **Yes for phones:** Quick status glance, remote monitoring, alerts, quick actions, job dispatching
- **No for phones:** Complex forms, file uploads, slicer workspace, admin tasks, detailed charts
- **5 MVP Features:** Dashboard (P0), Printer List+Detail (P0), Quick Actions (P0), Job Queue (P1), Notifications (P1)
- **Total MVP Surface:** 22 API endpoints

---

### Service Architecture: Protocol-Based Dependency Injection (Ripley, Dallas)
**Status:** Implemented

#### ViewModel Pattern
- All ViewModels: `@MainActor @Observable` with optional protocol-typed service properties
- Services configured via `configure(with:)` method called in view's `.task` modifier
- ViewModels depend on protocols, not concrete implementations — full testability

#### Service Protocols (5 total)
- `PrinterServiceProtocol` (11 methods: list, get, status, snapshot, pause/resume/cancel/stop/emergency-stop, maintenance)
- `JobServiceProtocol` (5 methods: list, get, dispatch, cancel, abort)
- `NotificationServiceProtocol` (5 methods: list, get, mark-read, batch mark-read, unread count)
- `StatisticsServiceProtocol` (1 method: summary KPIs)
- `SignalRServiceProtocol` (4 methods: connect, disconnect, subscribe/unsubscribe)

#### Navigation Wiring
- Each tab wraps NavigationStack(path:) bound to AppRouter
- Detail views pushed via AppDestination enum + `.navigationDestination(for:)`
- Global `destinationView(for:)` helper marked `@MainActor` — centralized resolution, satisfies Swift 6 actor isolation

#### Tab Structure Change
- Replaced Locations tab with Notifications tab (Locations not phone-first; Notifications core value)
- LocationListView preserved for post-MVP restoration

---

### SignalR: Native URLSessionWebSocketTask (Lambert)
**Status:** Implemented

#### Implementation Details
- Custom client using URLSessionWebSocketTask directly — no third-party dependencies
- ASP.NET Core SignalR JSON protocol: 0x1E framing, negotiate, handshake, ping/pong
- Auto-reconnect with exponential backoff (1s → 30s cap, 10 attempts max)
- Connection state machine with delegate callbacks

#### MVP Events
- `printerupdated`: Composite status delta (state, temps, progress, job info)
- `jobqueueupdate`: Live job status transitions

**Impact:** Real-time live updates without polling; critical phone app value

---

### Job Queue API: Printer-Centric Overview (Lambert)
**Status:** Implemented

#### Endpoint & Model Correction
- **Path:** `/api/job-queue` (hyphenated)
- **Response:** `[QueueOverview]` — per-printer queue view, not individual PrintJob collection
- QueueOverview contains: printer ID, queue depth, current job
- Individual job detail: `GET /api/job-queue/{id}`

#### UI Impact
- **JobListView:** Redesigned to show QueueOverview (printer queue status) with Active/Queued/Available sections
- **DashboardView:** Shows printers with current jobs (from Printer.jobName/progress) not separate PrintJob collection

---

### Notification Model Specification (Lambert)
**Status:** Implemented

#### AppNotification Structure
- `id: String` (not UUID; backend uses string IDs)
- `type: NotificationType` enum (JobStarted, JobCompleted, JobFailed, JobPaused, JobResumed, QueueAlert, SystemAlert)
- `subject: String`, `body: String` (not title/message)
- `read: Bool`, `timestamp: Date`
- `printerId: String?`, `jobId: String?` (context links)

**Breaking Change:** Old placeholder values (info/warning/error/success) replaced with job event names

---

### APIClient Type Disambiguation (Lambert)
**Status:** Implemented

#### New Overloads
- `postVoid(_:)` — POST with no response body
- `putVoid(_:)` — PUT with no response body
- `putVoid(_:body:)` — PUT with request body, no response
- `getData(_:)` — GET returning raw Data (for snapshots)

**Rationale:** Old single `post(_:)` was ambiguous when both void and decoded overloads existed

---

### Snapshot Handling: Data → UIImage (Ripley)
**Status:** Implemented

#### Pattern
- `PrinterServiceProtocol.getSnapshot(id:) -> Data` returns raw image bytes
- ViewModel loads Data, stores in @State
- View converts Data → UIImage locally
- No AsyncImage (no URL support)
- Handled via `.task` modifier

---

### Test Infrastructure: MockURLProtocol + Protocol Mocks (Ash)
**Status:** Implemented

#### Testing Strategy
- **Network Tests:** MockURLProtocol intercepts URLSession calls — validates full path through APIClient → Service
- **ViewModel Tests:** Protocol-based mock services via `configure()` — fast, isolated
- **Model Tests:** Realistic JSON fixtures from backend DTOs — decoder compatibility

#### Coverage
- 145 test cases across 8 suites (APIClient, Auth, Printer, Job, Notification, Model Decoding, LoginViewModel, DashboardViewModel)
- Full mock infrastructure: MockPrinterService, MockJobService, MockAuthService, MockNotificationService, MockStatisticsService, MockSignalRService
- TestFixtures with realistic JSON from backend source

**Impact:** All team members can run tests to validate work; mocks ready for any new ViewModel or service

---

### Tab Structure: Notifications MVP Priority (Ripley, Dallas)
**Status:** Implemented

#### Decision
- Remove Locations tab (not phone-first)
- Add Notifications tab (core phone value — print alerts, completions, failures)
- LocationListView preserved in codebase for post-MVP restoration

---

### Swift 6 Strict Concurrency Compliance (Ripley, Dallas)
**Status:** Implemented

#### Techniques
- All ViewModels marked `@MainActor @Observable`
- Global `destinationView(for:)` helper marked `@MainActor`
- Platform guards for iOS-only APIs: `#if os(iOS)` / `#if canImport(UIKit)`
- SPM macOS build compatible; Xcode iOS build retains all features

---

### CRITICAL FINDING: PrinterDetailViewModel Method Mismatches (Ash)
**Status:** ⚠️ Identified — Requires Ripley Fix

#### 3 Mismatches Found
| ViewModel Calls | Protocol Has | Mismatch Type |
|-----------------|--------------|---------------|
| `snapshotURL(for:)` | `getSnapshot(id:) -> Data` | Method name + return type (URL vs Data) |
| `cancelPrint(id:)` | `cancel(id:) -> CommandResult` | Method name (cancelPrint vs cancel) |
| `setMaintenance(id:enabled:)` | `setMaintenanceMode(id:enabled:) -> CommandResult` | Method name (setMaintenance vs setMaintenanceMode) |

**Owner:** Ripley (iOS Dev)
**Timeline:** URGENT — blocks test suite integration
**Action:** Update PrinterDetailViewModel method calls to match actual protocol signatures

---

### Deferred Features (Post-MVP)
**Status:** Accepted

- Printer Discovery (complex multi-step, SSE streaming)
- File Management/Upload (large file handling, limited phone storage)
- Slicer Integration (3D viewport, complex forms)
- Camera Live Streams (bandwidth-heavy; snapshots sufficient)
- Statistics Charts (phone screen not ideal)
- Maintenance Plans/Schedules (complex forms)
- User Management (admin-only)
- System Settings (admin config)
- Filament/Spool Management (inventory system)
- NFC Device Management (niche)
- Webhook Configuration (developer feature)
- Printer Import/Export (bulk operations)
- G-code Library (file browsing)
- Print Projects (project management)
- Catalog Management (admin)

---

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
