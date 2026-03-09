# Decision: Material-First Spool Picker Flow

**Date:** 2026-03-09  
**Agent:** Ripley (iOS Dev)  
**Status:** Implemented

## Context

The original SpoolPickerView loaded ALL 200 spools immediately on open, then provided material and status filter chips for manual filtering. This approach had performance and UX issues:

1. **Slow initial load** — 200 spools fetched every time
2. **Overwhelming choice** — Users faced 200 items before filtering
3. **Inconsistency** — Web UI had already moved to material-first selection
4. **Backend support** — PrintFarmer API added `/api/spoolman/materials/available` endpoint specifically for this pattern

## Decision

Redesigned SpoolPickerView as a **two-phase selection flow**:

### Phase 1: Material Selection
- Display list of available material types (from `/api/spoolman/materials/available`)
- User selects a material type (e.g., "PLA", "PETG", "ABS")
- Navigation: "Cancel" button to dismiss picker

### Phase 2: Spool Selection
- Load ONLY spools of the selected material type (using `listSpools(material: X)`)
- Display existing spool list with status filters and search
- Navigation: "Back" button returns to material selection

### Scanning Exception
- QR/NFC scanning bypasses material selection entirely
- Scan → lookup spool → auto-set material → filter → auto-select

## Implementation Details

**ViewModel Changes:**
- Added `SpoolPickerPhase` enum (`.selectMaterial`, `.selectSpool`)
- `phase` property drives which view is displayed
- `availableMaterials: [String]` loaded from backend
- `loadMaterials()` calls new API endpoint
- `selectMaterial()` transitions to phase 2
- `backToMaterialSelection()` returns to phase 1
- Enhanced scan flow to bypass phase 1 when spool ID is found

**View Changes:**
- Split body into `materialSelectionView` and `spoolSelectionView`
- Dynamic navigation title and toolbar based on phase
- Removed material filter chips from spool view (redundant)
- Status filter chips and search remain in phase 2

**Service Layer:**
- Added `listAvailableMaterials()` to `SpoolServiceProtocol`
- Implemented in `SpoolService` calling `/api/spoolman/materials/available`
- Returns `[String]` (material names only, no counts needed on client)

## Rationale

1. **Performance:** Load ~20 spools per material instead of all 200
2. **UX:** Reduced cognitive load — pick material first, then specific spool
3. **Consistency:** Matches web UI behavior users already know
4. **Backend-aligned:** Uses specialized endpoint designed for this flow
5. **Scan-friendly:** QR/NFC bypass maintains fast workflow for tagged spools

## Alternatives Considered

1. **Keep filter chips, add "material required" message** — Rejected: Still loads all 200 spools
2. **Auto-select first material** — Rejected: Assumes user intent, may be wrong material
3. **NavigationLink push for phase 2** — Rejected: Adds navigation complexity, phase enum is cleaner

## Impact

- **Users:** Faster picker load, clearer selection process
- **Backend:** Reduced load (no longer fetching 200 spools every open)
- **Developers:** Clear phase separation makes picker logic easier to maintain
- **Testing:** MockSpoolService updated with `listAvailableMaterials()` stub

## Related Files

- `PrintFarmer/Protocols/SpoolServiceProtocol.swift`
- `PrintFarmer/Services/SpoolService.swift`
- `PrintFarmer/ViewModels/SpoolPickerViewModel.swift`
- `PrintFarmer/Views/Filament/SpoolPickerView.swift`
- `PrintFarmerTests/Mocks/MockSpoolService.swift`
