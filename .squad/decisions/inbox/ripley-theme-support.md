# Theme Support: Light + PrintFarmer Dark

**Author:** Ripley (iOS Dev)  
**Date:** 2025-07-17  
**Status:** Implemented

## Decision

Added light and dark theme support matching the Printfarmer web app's color system. Two themes: **Light** and **PrintFarmer Dark** (the branded dark navy theme, not generic system dark).

## Implementation

### New Files
- `PrintFarmer/Theme/Color+Hex.swift` — Hex color initializer for `Color` and `UIColor`
- `PrintFarmer/Theme/ThemeColors.swift` — All branded colors as adaptive `Color` statics (`pf*` prefix)
- `PrintFarmer/Theme/ThemeManager.swift` — `@Observable` class with `ThemeMode` enum (system/light/dark), persists to UserDefaults

### Color System
- **Adaptive colors** via `UIColor { traitCollection in ... }` — automatically respond to iOS appearance changes
- **22 named color tokens** covering backgrounds, text, accents, borders, status, buttons, hardware status
- **Brand accent: green (#10b981)** set as global `.tint()` on the root view

### Theme Toggle
- Settings → Appearance → Theme picker with System / Light / PrintFarmer Dark options
- `.preferredColorScheme()` applied at root view level in PFarmApp
- System mode follows iOS appearance setting; manual override persists across launches

### Views Updated
All major views updated to use `pf*` theme colors: Dashboard, PrinterDetail, JobDetail, LoginView, NotificationsView, PrinterListView, and all shared components (StatusBadge, PrinterCardView, PrintProgressBar).

## Impact
- **All agents:** New views should use `Color.pf*` tokens instead of raw SwiftUI colors (`.blue`, `.green`, etc.)
- **Ash (Testing):** ThemeManager is `@Observable` and injected via `.environment()` — mock or create in tests that need it
- **Key convention:** Use `Color.pfCard` (not `.pfCard`) in `.background()`, `.foregroundStyle()`, `.strokeBorder()` contexts due to ShapeStyle resolution
