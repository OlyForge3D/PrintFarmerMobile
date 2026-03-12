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

### 2026-03-09: Action Button Color Hierarchy & Visual Clarity
**Problem:** PrinterDetailView's `actionSection` uses seven buttons with five different colors (green, amber, red, system default), making it difficult to distinguish enabled vs disabled states. User feedback: "Too many different colored buttons makes it hard to tell what's enabled vs disabled."

**Root Causes:**
1. Manual `.opacity(0.4)` on colored buttons creates ambiguous disabled states (faded amber looks like light amber, not clearly disabled)
2. Color used for differentiation rather than semantic meaning (amber for "Pause" doesn't convey a warning)
3. No visual hierarchy — all buttons at same prominence level except Emergency Stop
4. Inconsistent with Apple HIG: HIG recommends using `.borderedProminent` vs `.bordered` for hierarchy, not color tinting

**Design Recommendation (Apple HIG-aligned):**
**3-Level Hierarchy:**
1. **Level 1 (Critical/Destructive):** Emergency Stop — `.borderedProminent` + `.pfError` (red) + 50pt height + bold → Always stands out
2. **Level 2 (Primary Contextual):** Resume — `.borderedProminent` (neutral, no custom tint) + 50pt height → Clear primary action when paused
3. **Level 3 (Secondary Actions):** All others — `.bordered` + 44pt height
   - Pause, Maintenance, Write Tag → Neutral (system default blue)
   - Cancel, Stop → `.tint(.pfError)` for semantic destructive context

**Color Usage Philosophy:**
- **Red (`.pfError`)**: ONLY for destructive actions (Emergency Stop, Cancel, Stop)
- **Green (`.pfSuccess`)**: REMOVED — prominence (size/style) handles hierarchy better than color
- **Amber (`.pfWarning`)**: REMOVED — "Pause" is a control action, not a warning
- **Neutral (system)**: All utility actions → clean, iOS-native, works in light/dark mode

**Key Changes to PrinterDetailView.swift:**
- Updated `actionButton()` helper to accept `prominence` and optional `tint` parameters
- Pause: Remove amber tint → neutral
- Resume: Add `.prominent` prominence → stands out without color
- Cancel/Stop: Change to red tint → clear destructive context
- Stop: Change from amber to red → aligns with destructive nature
- Write Tag: Remove green tint → neutral utility action
- Emergency Stop: No change (already correct)

**Benefits:**
1. **Clarity:** Emergency Stop unmistakable (only red prominent button)
2. **Disabled state:** Native SwiftUI graying works better on neutral buttons than manual opacity on colored buttons
3. **Accessibility:** Hierarchy via size/prominence, not color alone
4. **HIG compliance:** Matches Apple's recommended button hierarchy pattern
5. **Consistency:** Can be applied to JobDetailView for app-wide uniformity

**App-Wide Pattern (Current Audit):**
- LoginView, NFCWriteView, SpoolInventoryView: Use `.borderedProminent` + `.pfAccent` for primary creation/onboarding actions ✅
- JobDetailView: MIXED — uses `.borderedProminent` with various colors (.pfWarning, .pfError, .pfAccent) → Should adopt same 3-level hierarchy

**Decision Document:** `.squad/decisions/inbox/parker-action-button-hierarchy.md` — Comprehensive recommendation with code examples, visual mockups, and implementation guidance for Ripley.

**User Preference:** Jeff validated that "Emergency Stop as a big red button makes sense" and questioned whether "all the other colors [are] really needed" — this recommendation addresses that concern by reducing color usage to semantic-only (red for destructive).

