# Status Filters & Weight Progress for Spool Views

**Date:** 2026-03-07  
**Author:** Ripley (iOS Dev)  
**Status:** Implemented  

## Decision

Added status-based filtering and visual weight indicators to both SpoolInventoryView and SpoolPickerView.

## Context

Material filter chips were already in place, but users needed to filter by spool status (available, in use, low on material, empty) and see at-a-glance weight remaining without reading numbers.

## Implementation

### 1. SpoolStatus Enum
Created shared enum in SpoolInventoryViewModel.swift with four cases:
- **Available:** `!inUse && !archived` — ready to assign
- **In Use:** `inUse == true` — currently loaded on a printer
- **Low:** remaining < 20% of initial — needs attention
- **Empty:** remaining == 0 or nil with initial present — replace soon

### 2. Status Filter Chips
- Second row of horizontal scrolling capsule buttons below material chips
- Same visual style (pfAccent selected, pfBackgroundTertiary unselected)
- Uses `ForEach(SpoolStatus.allCases)` for consistency
- Filters apply in sequence: material → status → search text

### 3. Weight Progress Bars
- Horizontal capsule showing remaining/initial percentage
- Color-coded: green (>50%), yellow (20-50%), red (<20%)
- Only shown when both remainingWeightG and initialWeightG are available
- Positioned below weight text on right side of row

### 4. In-Use Badge
- Small `printer.fill` SF Symbol next to spool name
- Colored with pfAccent for visibility
- Only shown when `inUse == true`

## Files Modified
- `PrintFarmer/ViewModels/SpoolInventoryViewModel.swift`
- `PrintFarmer/ViewModels/SpoolPickerViewModel.swift`
- `PrintFarmer/Views/Filament/SpoolInventoryView.swift`
- `PrintFarmer/Views/Filament/SpoolPickerView.swift`

## Patterns Used
- Capsule filter chips (existing material filter pattern)
- Computed properties for weightPercent and weightColor
- GeometryReader for proportional progress bar width
- CaseIterable for enum-driven UI generation

## Alternatives Considered
- **Single row combining material + status:** Rejected — too crowded, poor UX
- **Gauge component:** Rejected — too large for list row context
- **Custom progress view:** Rejected — Capsule + ZStack simpler and matches design system

## Impact
- No new dependencies
- No breaking changes
- Backward compatible (filters are optional, default to "All")
- Dark mode support through semantic colors (pfAccent, pfBackgroundTertiary, etc.)

## Notes
- SpoolStatus enum placed in ViewModel file for now; could extract to separate file if reused elsewhere
- Weight progress bar uses fixed widths (60px inventory, 50px picker) for consistency
- Empty state detection handles both explicit zero and missing data scenarios
