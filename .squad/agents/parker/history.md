# Parker — History

## Project Context
- **Project:** PFarm-Ios — Native iOS client for Printfarmer 3D printer farm management
- **User:** Jeff Papiez
- **Stack:** Swift, SwiftUI, iOS 17+, Xcode
- **Backend:** Printfarmer (ASP.NET Core 9.0, REST API, SignalR, JWT)

## Learnings

### 2026-03-09: Touch Target Compliance & Button Sizing
**Problem:** Full-width action buttons throughout the app were too short (~34-36pt), making them difficult to tap accurately, especially for users with larger fingers.

**Solution Implemented:**
- Created `ActionButtonStyle.swift` in `PrintFarmer/Views/Components/`
- Introduced `.fullWidthActionButton()` view modifier with two prominence levels:
  - `.standard` = 44pt height (Apple HIG minimum)
  - `.prominent` = 50pt height (for primary actions like "Start Print", "Emergency Stop", "Sign In")
- Applied to all full-width action buttons across 8 view files

**Files Modified:**
1. `PrintFarmer/Views/Auth/LoginView.swift` — Fixed harmful `.frame(height: 22)` on Sign In button
2. `PrintFarmer/Views/Printers/PrinterDetailView.swift` — Updated `actionButton()` helper + maintenance, NFC, emergency stop
3. `PrintFarmer/Views/Jobs/JobDetailView.swift` — All job action buttons (Start, Pause, Resume, Cancel, Abort)
4. `PrintFarmer/Views/Filament/NFCScanButton.swift` — Scan NFC Tag button
5. `PrintFarmer/Views/Filament/NFCWriteView.swift` — Write, Done, Retry, Cancel buttons
6. `PrintFarmer/Views/Printers/AutoPrintSection.swift` — Next Job, Skip buttons (also upgraded font from `.caption` to `.subheadline`)
7. `PrintFarmer/Views/Maintenance/MaintenanceAlertRow.swift` — Acknowledge, Dismiss buttons (also upgraded font)

**Design Decisions:**
- Minimum 44pt touch target for all action buttons per Apple HIG
- 50pt for primary actions requiring extra prominence
- Font size increased from `.caption` to `.subheadline` for AutoPrint and MaintenanceAlert buttons to improve readability
- Maintained existing color tinting, font weights, and button roles (.destructive)
- Consistent spacing (8pt between vertically stacked buttons)

**Key File Paths:**
- Reusable components: `PrintFarmer/Views/Components/`
- Theme/colors: `PrintFarmer/Theme/ThemeColors.swift`
- Auth views: `PrintFarmer/Views/Auth/`
- Printer views: `PrintFarmer/Views/Printers/`
- Job views: `PrintFarmer/Views/Jobs/`
- Filament/NFC views: `PrintFarmer/Views/Filament/`
- Maintenance views: `PrintFarmer/Views/Maintenance/`

