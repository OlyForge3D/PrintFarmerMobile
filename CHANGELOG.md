# Changelog

All notable changes to PrintFarmer iOS will be documented in this file.

## [v1.0-beta.12] — 2026-03-12

### Added
- **Local notifications for PendingReady** — App now sends local "Bed Clear Required" notifications when printers enter PendingReady state. Tracks per-printer to avoid spam; re-notifies if printer re-enters PendingReady.

### Fixed
- **Entitlements build failure** — Removed hardcoded `aps-environment` from entitlements file. The build system injects it automatically from the provisioning profile, fixing the "entitlements modified during build" Xcode Cloud error.

### Changed
- **Switched from APNs to local notifications** — PrintFarmer's self-hosted architecture means each installation can't hold centralized Apple credentials. Notifications now use `UNUserNotificationCenter` local notifications instead of APNs push.

## [v1.0-beta.11] — 2026-03-11

### Added
- **Real-time SignalR updates** — Temperatures, state, progress, and job info now update live via WebSocket. No more manual pull-to-refresh needed.
- **Custom nozzle & radiator icons** — Hotend and bed temperature displays now use 3D printer nozzle and radiator icons matching the web UI (replaces generic flame and stack icons).
- **`bedClearRequired` notification type** — Prepares for push notifications when a printer needs its bed cleared.
- **`fileName` field** — Dashboard, printer cards, and printer detail now show the gcode file name (e.g. `benchy.gcode`) instead of the full job path.

### Fixed
- **Bed clear UI not updating** — Tapping "Confirm Bed Clear" now immediately clears the warning banner and buttons (optimistic update with delayed reload).
- **Push notification entitlements** — Added missing `aps-environment` entitlement so push notifications can be enabled.
- **SignalR log noise** — Silenced `toolheadUpdate`, `extruderUpdate`, and `heaterBedUpdate` events that were flooding the debug log.

## [v1.0-beta.10] — 2026-03-11

### Added
- **PendingReady indicator badge** — Orange badge on the Printers tab (iPhone) and sidebar (iPad) shows count of printers waiting for bed clear, matching the web UI's pulsing alert icon.

## [v1.0-beta.9] — 2026-03-11

### Added
- **Job thumbnails** — Gcode file thumbnails now display in job detail pages and job queue list rows.

### Fixed
- **Dispatch dashboard** — Redesigned to show real metrics: pending printers, busy printers, and dispatched jobs in last 24 hours.
- **Job analytics decoding** — Fixed JSON decoding error ("data couldn't be read because it's missing").
- **Predictive insights** — Risk factor percentages now display correctly (was showing 8000%, 10000%).

## [v0.1.0-beta.7] — 2025-07-21

### Added
- **Per-printer camera rotation** — Rotate button next to camera refresh in PrinterDetailView cycles through 0°→90°→180°→270° with per-printer UserDefaults persistence. Fixes upside-down camera feeds on printers like Phrozen Arco. (`c849000`)

### Changed
- **Compact button layouts & shorter labels** — Simultaneous action buttons now grouped side-by-side (Pause+Abort, Resume+Abort, Retry+Cancel, Set+Scan Tag). Labels shortened for clarity: Change Filament→Change, Write NFC Tag→Write Tag, Acknowledge→Accept, Clear Filters→Reset, Scan NFC Tag→Scan Tag. Fixed NFCWriteView error state layout (VStack→HStack). All touch targets remain ≥44pt HIG compliant. (`9f5fe50`)
