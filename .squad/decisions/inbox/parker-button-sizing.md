# Decision: Touch-Compliant Button Sizing System

**Date:** 2026-03-09  
**Author:** Parker (UI/UX Designer)  
**Status:** Implemented  

## Context
The PrintFarmer iOS app had full-width action buttons that were too short (~34-36pt), violating Apple Human Interface Guidelines (44pt minimum touch target) and causing usability issues for users with larger fingers.

## Decision
Created a reusable `.fullWidthActionButton()` view modifier with two prominence levels:
- **Standard:** 44pt minimum height (Apple HIG compliance)
- **Prominent:** 50pt minimum height (for critical primary actions)

## Implementation
- **File:** `PrintFarmer/Views/Components/ActionButtonStyle.swift`
- **Usage:** `.fullWidthActionButton(prominence: .prominent)` or `.fullWidthActionButton()` (defaults to .standard)
- **Applied to:** 8 view files containing full-width action buttons

## Design Guidelines
1. **Primary Actions** (50pt) — Actions requiring extra emphasis:
   - Start Print, Resume Print
   - Emergency Stop
   - Sign In
   - Write NFC Tag (when primary action)

2. **Secondary Actions** (44pt) — Standard action buttons:
   - Pause, Cancel, Stop
   - Next Job, Skip
   - Acknowledge, Dismiss
   - Scan NFC Tag

3. **Font Sizing:**
   - Avoid `.caption` font on buttons — use `.subheadline` minimum
   - Maintain `.semibold` weight for primary actions

## Benefits
- ✅ Apple HIG compliance (44pt minimum touch targets)
- ✅ Improved accessibility for all users
- ✅ Consistent button sizing across the app
- ✅ Easy to apply to new buttons via view modifier
- ✅ Prominent treatment for critical actions

## Migration Notes
- Replace `.frame(maxWidth: .infinity)` with `.fullWidthActionButton()`
- Use `.prominent` for primary/critical actions
- Remove any explicit height constraints that conflict (e.g., `height: 22`)
- Upgrade `.caption` fonts to `.subheadline` on action buttons
