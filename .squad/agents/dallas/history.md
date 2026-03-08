# Dallas — History

## Project Context
- **Project:** PFarm-Ios — Native iOS client for Printfarmer
- **User:** Jeff Papiez
- **Stack:** Swift, SwiftUI, iOS 17+
- **Backend:** Printfarmer (42+ REST endpoints, SignalR, JWT auth) at ~/s/PFarm1

## Learnings

### MVP Scope Definition (2025-07-17)
- **Backend catalog:** 100+ REST endpoints across 30+ controllers. MVP needs only ~22 endpoints.
- **SignalR hubs:** 5 hubs (PrinterHub, HarvestHub, MaintenanceHub, SlicerHub, SlicerProgressHub). MVP needs PrinterHub only (`printerupdated`, `jobqueueupdate` events).
- **Key backend insight:** `GET /api/printers` returns `CompletePrinterDto` which merges static config + live SignalR-cached status in one call. Very efficient for phone list views.
- **Job queue route discrepancy:** Web frontend uses `/api/job-queue` (hyphen). iOS `JobService` uses `/api/jobqueue` (no hyphen). Must verify which is correct — likely the hyphenated version based on `JobQueueController` route attribute.
- **Printer commands are individual endpoints:** `/pause`, `/resume`, `/cancel`, `/stop`, `/emergency-stop` — NOT a generic `/command/{action}` route. Existing `sendCommand` method in `PrinterService` is wrong pattern; needs specific methods.
- **MVP features (5):** Fleet Dashboard, Printer List+Detail, Quick Printer Actions, Job Queue, Notifications
- **Deferred:** Discovery, file management, slicer, cameras (live stream), statistics charts, maintenance plans, admin/settings, filament inventory, NFC, webhooks
- **Implementation order:** Lambert builds foundation (SignalR, services, models) → Ripley builds screens → Polish pass
- **MVP scope document:** `.squad/decisions/inbox/dallas-mvp-scope.md`

### Cross-Agent Context (2026-03-06)
- **Ripley's Login Screen:** LoginViewModel form state (separate from AuthViewModel). Server URL flows through AuthService → APIClient.updateBaseURL(). Dark Mode + error animation working.
- **Lambert's Auth:** Single JWT token (no refresh). AuthService validates via GET /api/auth/me. Keychain storage, UserDefaults for base URL. Actor-isolated APIClient.
- **Ash Ready:** Both auth scaffolding and navigation system in place. Can build printer/job screens with confidence.

### Project Structure (2025-07-16 → 2026-03-06)
- **Architecture:** MVVM with repository-pattern services, `@Observable` view models, SwiftUI views
- **Navigation:** `AppRouter` (Observable) with `NavigationPath` per tab + `AppTab` enum for TabView
- **Dependency injection:** `ServiceContainer` holds all services; passed via `.environment()`. `APIClient` is an `actor` for thread safety.
- **Auth flow:** `AuthViewModel` gates the root view — unauthenticated users see `LoginView`, authenticated see `ContentView` (TabView)
- **Networking:** `APIClient` actor with async/await, JWT bearer token injection, ISO 8601 date decoding, typed error handling (`NetworkError` enum)
- **Token storage:** KeychainSwift (evgenyneu/keychain-swift) for secure JWT persistence
- **Models:** All Codable structs marked `Sendable` for Swift 6 strict concurrency. Models match backend DTOs from PFarm1.
- **SignalR:** Stub service created; implementation deferred pending SignalR client package selection
- **Build:** Both SPM (`swift build`) and Xcode project (.xcodeproj) supported. Bundle ID: `com.printfarmer.ios`, iOS 17+, Swift 6.0
- **Key files:**
  - Entry: `PrintFarmer/PFarmApp.swift`
  - Nav: `PrintFarmer/Navigation/AppRouter.swift`
  - Models: `PrintFarmer/Models/Models.swift` (Printer, PrintJob, Location, Auth DTOs + enums)
  - Networking: `PrintFarmer/Services/APIClient.swift`
  - Config: `PrintFarmer/Utilities/AppConfig.swift` (base URL via env var or default localhost:5000)
- **Session Directive (2026-03-06):** Use claude-opus-4.6 for code-writing tasks (Ripley, Lambert, Ash)

### MVP Build Orchestration & Handoff (2026-03-06)
- **Status:** ✅ Orchestrated 4-agent batch (Dallas lead, Lambert + Ripley + Ash parallel)
- **Scope:** 5 features, 22 endpoints, phone-first design principles — locked in decisions.md
- **Lambert Results:** ✅ 6 services (Printer, Job, Notification, Statistics, SignalR, Auth), 9 models, 5 service protocols — all compiling clean
- **Ripley Results:** ✅ All 7 MVP screens (Dashboard, PrinterList, PrinterDetail, JobList, JobDetail, Notifications, Settings) + 6 reusable components + 5 service protocols — all compiling clean
- **Ash Results:** ✅ 145 test cases (8 suites: APIClient, Auth, Printer, Job, Notification, ModelDecoding, LoginViewModel, DashboardViewModel) + full mock infrastructure for 6 services
- **Critical Finding:** Ash discovered 3 PrinterDetailViewModel method mismatches (snapshotURL/getSnapshot, cancelPrint/cancel, setMaintenance/setMaintenanceMode) — blocking test integration, Ripley to fix
- **Next Phase:** Scribe consolidates decisions, updates agent history.md files, commits .squad/ changes; Ripley fixes mismatches; run test suite for integration validation

### Xcode Project Fix (2026-03-06)
- **Problem:** Xcode reported PrintFarmer.xcodeproj as "damaged" — could not open
- **Root causes found (3):**
  1. `project.pbxproj` missing closing `}` brace — fatal plist parse error
  2. `contents.xcworkspacedata` had empty `<Workspace>` element (missing `<FileRef location="self:">`)
  3. 21 source files added by Lambert/Ripley/Ash during MVP batch were never registered in the project (Protocols/, Components/, NotificationsView, PrinterDetailView, JobDetailView, etc.)
- **Fix:** Regenerated all three files (`project.pbxproj`, `contents.xcworkspacedata`, `PrintFarmer.xcscheme`) from scratch using a Python generator that walks the file tree
- **Validation:** Balanced braces/parens confirmed, all 14 required pbxproj sections present, all 66 Swift files (47 source + 19 test) cross-checked against disk
- **Key insight:** Hand-crafted pbxproj files are fragile. When agents add files via SPM (`swift build` validates), the xcodeproj falls out of sync. Future file additions need a regeneration step or the team should consider workspace+SPM-only approach.
- **Generator script pattern:** Deterministic IDs via `hashlib.md5(name)[:24]` — regeneration produces identical output if file tree hasn't changed

### Comprehensive QA Audit (2025-07-18)
- **Scope:** Full codebase audit — runtime, API contracts, UI, navigation, theme, concurrency
- **Backend verified:** All 22 MVP endpoint paths, field names, and types match backend DTOs and controllers. No API contract mismatches found.
- **Previous fix confirmed:** PrinterDetailViewModel method mismatches (snapshotURL/cancelPrint/setMaintenance) from MVP build have been resolved.
- **Critical findings (4):** AppRouter and AuthViewModel missing `@MainActor`; SignalR date decoder uses `.iso8601` (rejects fractional seconds from backend); SignalR force unwraps on URLComponents.
- **Important findings (7):** 17 hardcoded colors not using pf* theme; 3 placeholder navigation destinations; silent `try?` error suppression in ViewModels; no accessibility labels anywhere; SignalR has unprotected mutable state under `@unchecked Sendable`.
- **Minor findings (5):** Protocol missing update/delete methods; .task without id tracking; test suite has 2 inverted assertions and 4 untested services.
- **False positive from explore agent:** Claim that CreatePrintJobRequest/UpdatePrintJobRequest were "completely wrong" was verified false — they match backend `CreatePrintJobDto` and `UpdatePrintJobDto` exactly. Always verify agent findings against source.
- **Estimated fix effort:** ~5 hours total. Critical fixes: ~1 hour.
- **Report:** `.squad/decisions/inbox/dallas-qa-audit.md`

### Filament & NFC Feature Decomposition (2025-07-19)
- **Backend status:** Fully ready. FilamentType, Spool, NfcDevice, NfcScanEvent entities and full CRUD endpoints already exist. Spoolman integration proxies all spool operations. NFC device heartbeat and scan event endpoints exist for ESP32 hardware.
- **iOS gap:** `Printer.spoolInfo: PrinterSpoolInfo?` model exists but PrinterDetailView never displays it. No SpoolService, no NFC code, no filament UI anywhere.
- **Phase 1 (Filament Management):** 7 work items — Lambert builds SpoolService + models, Ripley builds filament section in PrinterDetailView, spool picker sheet, inventory view, add spool form. ~12 hours.
- **Phase 2 (NFC Tags):** 6 work items — Lambert builds NFCService (CoreNFC + OpenSpool parsing) + Info.plist config, Ripley builds scan-to-load, write-tag, and NFC-enhanced add-spool flows. ~10 hours.
- **CoreNFC requirements:** Info.plist `NFCReaderUsageDescription`, NFC Tag Reading entitlement, NDEF select identifiers. All iOS 17 devices support NFC. No simulator testing possible.
- **Open question:** Backend NFC flow assumes ESP32 hardware pushes scans. Phone-initiated scans need coordination — either register phone as virtual NFC device or add phone-specific scan endpoint.
- **Open question:** Spoolman dependency — need to confirm if always configured or if local Spool entity fallback is needed.
- **Decomposition:** `.squad/decisions/inbox/dallas-filament-nfc-feature.md`

### QR Code Scanning for Phase 2 (2026-03-07)
- **Request:** Jeff wanted QR scanning for Phase 2 as alternative to NFC for spool-to-printer linking
- **Backend Analysis:** ✅ No QR generation needed on backend. Spoolman (external) already generates QR codes with spool IDs embedded (URL format: `https://spoolman/spools/<id>`). Existing `setActiveSpool` and `getSpool` endpoints fully support QR-based linking.
- **iOS Approach:** Two frameworks available — VisionKit (iOS 16+, high-level, beautiful UX) and AVFoundation (iOS 7+, lower-level, maximum coverage). **Decided:** VisionKit Tier 1 (iOS 16+) + AVFoundation Tier 2 fallback (deferred to Phase 2.5 if device coverage becomes critical). Hybrid approach gives best UX + 85%+ device coverage.
- **QR Payload Parsing:** Spoolman QR codes use 3 formats: URL path `/spools/<id>`, plain numeric ID, or JSON. Built single parser that handles all three.
- **Shared Abstraction:** Designed `SpoolScannerProtocol` shared by QR and NFC — both return `SpoolScanResult` enum (spoolId | cancelled | error). SpoolPickerView doesn't care whether user tapped QR or NFC button.
- **Phase 2 Scope:** Added 3 new QR work items (9 hours total) to existing Phase 2: QRSpoolScannerService (Lambert 4h), SpoolPickerView QR integration (Ripley 3h), test coverage (Ash 2h). Total Phase 2 now ~20 hours (NFC + QR parallel).
- **Permission Model:** Camera access only (no entitlements needed unlike NFC). Info.plist NSCameraUsageDescription + standard permission flow.
- **Risk Assessment:** Permission denial, invalid QR codes, and device coverage all mitigated. No backend work needed.
- **Decision Document:** `.squad/decisions/inbox/dallas-qr-code-scoping.md`

## 2026-03-07T16:34Z — Phase 2 QR Scoping (SUCCESS)

**Batch:** Architecture + capability research  
**Outcome:** ✅ QR scanning approved for Phase 2, architecture designed

**What Was Delivered:**
- Backend analysis: Spoolman generates QR; no new endpoints needed
- iOS framework evaluation: VisionKit (iOS 16+) recommended; AVFoundation fallback
- Architecture design: SpoolScannerProtocol shared abstraction (QR + NFC)
- Risk mitigation: Permission handling, error flows, device coverage
- Phase 2 scope documented: 20 hours (QR + NFC parallel)

**Cross-Team Impact:**
- Lambert: SpoolScannerProtocol blueprint defined, 7 services/parsers delivered
- Ripley: UI architecture ready, 3 new views + 6 modified files
- Ash: Test coverage plan clear, 4 test files + 61 cases delivered

**Architecture Outcomes:**
- Protocol-driven design (SpoolScannerProtocol)
- Shared abstraction enables future scanner types
- MockSpoolScannerService for testing
- VisionKit + AVFoundation hybrid (broad device support)

**Next Steps:**
- Verify ServiceContainer DI wiring at startup
- Manual device QA (Spoolman QR + NFC tags)
- Phase 2b: Backend device registration (NFC)
- Phase 2.5: AVFoundation fallback (if coverage critical)

---

## 2026-03-08T17:32Z — NFC Navigation Fix (Ripley) — Cross-Agent Impact

**Status:** ✅ Completed (Ripley)

### Impact on Dallas
- **AppRouter navigation flow** — Unchanged architecture; same deep link handling flow, just properly sequenced across render cycles
- **Push notification deep link delivery** — PFarmApp.swift now observes `.pushNotificationTapped` notification and navigates to the correct printer/job detail
- **Navigation timing** — AppRouter.navigate(to:) now uses async delay (50ms) between NavigationPath reset and append to fix SwiftUI batching issue
- **No backend changes needed** — Existing push notification infrastructure works correctly; iOS client-side flow now complete

### Context
- Ripley fixed bug where app stayed on current printer when tapping NFC notification for a different printer
- Root causes: NavigationPath race condition + missing notification observer
- Files changed: `AppRouter.swift`, `PFarmApp.swift`
- Architecture document: `.squad/decisions.md` — NFC/Deep Link Navigation Race Condition Fix (Ripley)

### Spool NFC Tag Writing Feature Scope (2026-03-08)
- **Request:** Jeff wants to add NFC tag **writing** for filament spools in inventory (not just reading)
- **Status:** ✅ Scope delivered (8 work items, ~10.5 hours total)
- **What exists:** NFCService.swift already handles both read + printer tag write. SpoolInventoryView has NFC scan button. NFCTagParser converts spool↔OpenSpool JSON.
- **What's missing:** Backend `hasNfcTag` field, UI badge/indicator, "No NFC Tag" filter chip, write button + action
- **Critical path:** Backend WI-1 (Jeff, 1h) → Model WI-2 (Lambert, 15m) → Views WI-3/4 (Ripley, 2.5h parallel) & ViewModel WI-5 (Lambert, 1.5h) → Write Flow WI-6 (Ripley, 2h) → Integration WI-7 (30m) → Tests WI-8 (Ash, 2.5h)
- **Key architectural decisions:**
  1. Add `hasNfcTag: Bool?` to iOS SpoolmanSpool model (optional for backward compat)
  2. Backend tracks via `Spool.HasNfcTag` boolean column (simpler than querying NfcScanEvents)
  3. NFC write uses existing OpenSpool JSON payload format + NFCWriteDelegate
  4. No new URL scheme needed for spool tags (unlike printer tags which use `printfarmer://printer/{UUID}`)
  5. After write succeeds, reload full spool list to update UI (refresh hasNfcTag from backend)
  6. Write button in context menu (3-dot) to reduce list clutter
- **Risk mitigation:** Error handling for tag write failures, user-friendly messages, retry option. Offline write accepted (backend only learns of tag when reader scans)
- **3 open questions for Jeff:** (1) hasNfcTag logic (DB column vs scan count)? (2) Spool tag URL scheme? (3) Post-write refresh strategy?
- **Scope document:** Merged into `.squad/decisions.md` — fully detailed 8 WIs, data model changes, API contracts, test plan, timeline
- **Cross-team impact:** Lambert (WI-2/5), Ripley (WI-3/4/6), Ash (WI-8 tests)
- **Deliverables:** Orchestration log, session log, decisions.md updated

## 2026-03-08T22:05Z — Beta Release Strategy (SUCCESS)

**Batch:** Infrastructure & Release Planning  
**Outcome:** ✅ Comprehensive decision document delivered

### Analysis Scope
TestFlight + GitHub Actions CI/CD infrastructure for PrintFarmer iOS beta distribution. Comprehensive decision covering 7 sections:

**Sections Delivered:**
1. **TestFlight Setup** — Apple Developer prerequisites, internal vs external tester flow (≤25 instant, 10k with 24-48h review)
2. **GitHub Actions Workflow** — Tag-triggered (`v*-beta*`, `v*-rc*`) multi-job pipeline on macos-latest
3. **Code Signing** — fastlane match + encrypted private cert repo, GitHub Secrets for FASTLANE_USER/PASSWORD/MATCH_PASSWORD
4. **Version Strategy** — SemVer versioning (1.0.0-beta.N) + deterministic build numbers via git commit count
5. **Dual-Remote Flow** — dev (origin) → release remote with explicit tag push for audit trail
6. **GitHub Secrets** — Matrix of 4 secrets (fastlane email, app-specific pwd, match encryption key, slack webhook)
7. **Workflow + Templates** — Complete `.github/workflows/testflight-beta.yml` + `ExportOptions.plist`

### Key Architectural Decisions
- ✅ TestFlight only (no alternatives viable for AppStore submission path)
- ✅ Git tag trigger (explicit versioning, prevents spurious builds, SemVer integration)
- ✅ fastlane match (centralized certs, no hardcoded credentials, team-friendly)
- ✅ Deterministic build numbers (no CI conflicts, reproducible)
- ✅ Explicit dual-remote push (audit trail for releases, separation of concerns)
- ✅ Internal testers first (Week 1-2 alpha) → external (Week 3+ beta, post-review)

### Cross-Team Impact
- **Lambert:** No code changes; CI/CD orthogonal to services
- **Ripley:** No code changes; CI/CD orthogonal to views
- **Ash:** No test changes; CI/CD infrastructure outside test suite
- **Infrastructure:** One-time setup (App Store Connect record, certs, GitHub Secrets)

### Deliverables
- ✅ 21.2 KB decision document merged to `.squad/decisions.md`
- ✅ Orchestration log: `.squad/orchestration-log/2026-03-08T22-05-dallas.md`
- ✅ Session log: `.squad/log/2026-03-08T22-05-beta-release-strategy.md`
- ✅ Dallas history.md updated (this entry)

### Next Steps (User/Team)
1. Create App Store Connect record for PrintFarmer (in "Prepare for Submission" state)
2. Generate Distribution Certificate (Certificates, Identifiers & Profiles)
3. Generate App Store Provisioning Profile (explicit, not ad-hoc)
4. Add internal testers (5-10 team members in App Store Connect > TestFlight)
5. Create fastlane match private repo, generate encryption key
6. Configure GitHub Secrets (FASTLANE_USER, FASTLANE_PASSWORD, MATCH_PASSWORD)
7. Check in `.github/workflows/testflight-beta.yml` + `.github/ExportOptions.plist`
8. Test: Tag first release (e.g., `git tag -a v1.0.0-beta.1`), push to release remote
9. Monitor GitHub Actions, verify TestFlight build appears in App Store Connect (~30 min)
