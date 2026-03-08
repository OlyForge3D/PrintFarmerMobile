# Decision: Filter Chips Visible in Empty Filter States

**Author:** Ripley (iOS Dev)
**Date:** 2025-07-24
**Status:** Implemented (not yet committed)

## Context
When filter chips + search produced zero results, the `if/else` branch structure in both `SpoolInventoryView` and `SpoolPickerView` hid the filter chips entirely — users were trapped with no way to reset filters.

## Decision
- Show `materialFilterChips` and `statusFilterChips` ABOVE the empty state `ContentUnavailableView` when `hasActiveSearch && filteredSpools.isEmpty`.
- Added `clearFilters()` method to both ViewModels for centralized filter reset.
- Added `activeFilterDescription` computed property to both ViewModels for contextual empty state text showing which filters are active.
- The "Clear Filters" button resets `selectedMaterial`, `selectedStatus`, and `searchText`.

## Files Changed
- `PrintFarmer/Views/Filament/SpoolInventoryView.swift`
- `PrintFarmer/Views/Filament/SpoolPickerView.swift`
- `PrintFarmer/ViewModels/SpoolInventoryViewModel.swift`
- `PrintFarmer/ViewModels/SpoolPickerViewModel.swift`

## Team Impact
- **Pattern to follow:** Any future filterable list views should keep filter controls visible in empty states so users can always self-recover.
- **ViewModel convention:** Use a `clearFilters()` method and `activeFilterDescription` computed property for filter-heavy views.
