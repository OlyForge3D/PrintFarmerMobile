# Changelog

All notable changes to PrintFarmer iOS will be documented in this file.

## [v0.1.0-beta.7] — 2025-07-21

### Added
- **Per-printer camera rotation** — Rotate button next to camera refresh in PrinterDetailView cycles through 0°→90°→180°→270° with per-printer UserDefaults persistence. Fixes upside-down camera feeds on printers like Phrozen Arco. (`c849000`)

### Changed
- **Compact button layouts & shorter labels** — Simultaneous action buttons now grouped side-by-side (Pause+Abort, Resume+Abort, Retry+Cancel, Set+Scan Tag). Labels shortened for clarity: Change Filament→Change, Write NFC Tag→Write Tag, Acknowledge→Accept, Clear Filters→Reset, Scan NFC Tag→Scan Tag. Fixed NFCWriteView error state layout (VStack→HStack). All touch targets remain ≥44pt HIG compliant. (`9f5fe50`)
