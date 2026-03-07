# Decision: Spool Search Filtering Enhancement

**Author:** Ripley (iOS Dev)
**Date:** 2025-07-23
**Status:** Implemented

## Context
Both SpoolInventoryView and SpoolPickerView had `.searchable()` modifiers and `filteredSpools` computed properties, but the filter only checked name, material, vendor, and filamentName. Users couldn't search by color, location, or comment. No empty-search-results state was shown.

## Decision
1. Expanded filter in both ViewModels to also match `location`, `comment`, and approximate color names derived from `colorHex`.
2. Created `SpoolmanSpool+ColorName.swift` with a hex-to-color-name heuristic (maps hex values to common names like "red", "blue", "green", etc.).
3. Added `ContentUnavailableView.search` empty state when search yields no results.
4. Updated search bar prompts to hint at available search criteria.

## Rationale
- Color name matching uses a lightweight heuristic rather than a full color database — good enough for filament colors which tend to be primary/saturated.
- `ContentUnavailableView.search` is the standard iOS pattern for empty search states.
- Filter logic stays in ViewModels (not views) per our MVVM pattern.

## Files Changed
- `PrintFarmer/ViewModels/SpoolInventoryViewModel.swift`
- `PrintFarmer/ViewModels/SpoolPickerViewModel.swift`
- `PrintFarmer/Views/Filament/SpoolInventoryView.swift`
- `PrintFarmer/Views/Filament/SpoolPickerView.swift`
- `PrintFarmer/Extensions/SpoolmanSpool+ColorName.swift` (new)
