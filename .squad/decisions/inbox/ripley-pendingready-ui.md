# AutoDispatch PendingReady State UI Design

**Date:** 2026-03-11  
**Agent:** Ripley  
**Status:** Implemented

## Context

The auto-dispatch system has three states (`None`, `PendingReady`, `Ready`) but the UI was only showing a generic state string. When a print completes with auto-dispatch enabled, the printer enters `PendingReady` state — waiting for operator confirmation that the bed is clear before dispatching the next job.

## Decision

Implemented state-specific UI with three distinct presentations:

### 1. PendingReady State (Bed Clear Required)
- **Visual:** Warning banner with exclamation triangle icon + `.pfWarning` color
- **Message:** "🔔 Bed Clear Required" with subtitle
- **Primary action:** "Confirm Bed Clear" button (prominent, warning-colored)
- **Secondary action:** "Skip" button (bordered)
- **Additional info:** Queue count if available

### 2. Ready State (Dispatching)
- **Visual:** Success indicator with checkmark icon + `.pfSuccess` color
- **Message:** "✅ Bed cleared — dispatching next job..."
- **Additional info:** Filament check result + next job name
- **No actions:** System is handling dispatch

### 3. None State (Idle)
- **Visual:** Simple state indicator
- **Message:** Current state string ("Unknown", etc.)
- **Actions:** Standard "Next Job" + "Skip" buttons

## Design Rationale

### State Handling
- Used **if/else conditional** instead of switch for Optional<AutoDispatchState>
  - Cleaner than exhaustive switch with separate nil and .none cases
  - Swift treats `.none` as ambiguous between enum case and Optional.none
  
### Button Contextualization
- Same "mark ready" action, different labels based on state:
  - PendingReady: "Confirm Bed Clear" (urgent, warning tint)
  - Other states: "Next Job" (standard, accent tint)
- Reduces cognitive load: one primary action per state

### Visual Hierarchy
- Warning banner stands out but isn't alarming (not error red)
- Banner padding (12pt) and corner radius (10pt) match existing card style
- Full banner width with internal HStack layout

## Technical Implementation

**AutoDispatchViewModel:**
```swift
var parsedState: AutoDispatchState? {
    guard let stateStr = status?.state else { return nil }
    return AutoDispatchState(rawValue: stateStr)
}
```

**AutoDispatchSection:**
- Three computed views: `pendingReadyView`, `readyView`, `idleView`
- One `actionButtons` view with context-aware button text/tint
- State icon/color helpers use enum cases instead of string lowercasing

## Alternatives Considered

1. **Switch statement for state:** Rejected due to Optional enum exhaustiveness issues
2. **Separate buttons for each state:** Rejected to avoid UI layout shifts
3. **Error-colored banner:** Rejected as PendingReady is normal operation, not failure

## Impact

- **UX:** Operators have clear guidance on when bed-clear is needed
- **Performance:** No additional API calls; uses existing status data
- **Maintenance:** State-specific views are isolated and testable
- **Consistency:** Follows existing color token usage (`.pfWarning`, `.pfSuccess`, `.pfAccent`)

## Related Files
- `PrintFarmer/ViewModels/AutoDispatchViewModel.swift`
- `PrintFarmer/Views/Printers/AutoDispatchSection.swift`
- `PrintFarmer/Models/Models.swift` (AutoDispatchState enum)
