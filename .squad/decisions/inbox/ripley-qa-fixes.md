# QA Audit Fixes — Theme Color Extensions (Ripley, 2025-07-18)

## Decision
Added 3 new theme colors to `PrintFarmer/Theme/ThemeColors.swift`:
- **`pfMaintenance`** — purple, adaptive (light: #7c3aed, dark: #a78bfa). Used for maintenance mode badges in StatusBadge and PrinterDetailView.
- **`pfAssigned`** — teal/cyan, adaptive (light: #0891b2, dark: #22d3ee). Used for "Assigned" job status in StatusBadge.
- **`pfTempMild`** — yellow, adaptive (light: #ca8a04, dark: #facc15). Used for temperature display when >50°C in TemperatureView.

## Rationale
QA audit identified 17 hardcoded colors (.red, .orange, .purple, .cyan, etc.) across 7 view files. Existing pf* palette covered most cases (pfError→red, pfWarning→orange, pfHomed→blue, pfNotHomed→orange) but purple (maintenance), cyan (assigned), and yellow (mild temp) had no equivalents.

## Impact
- All views now use theme-consistent colors that adapt properly between light/dark modes.
- Any future views needing maintenance, assigned, or mild-temperature colors should use these instead of raw system colors.
- AuthViewModel now uses `@MainActor` instead of `@unchecked Sendable` — aligns with the existing ViewModel pattern documented in decisions.md.
