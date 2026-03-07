# Decision: pbxproj UUID Generation Must Be Validated

**Date:** 2026-03-07
**Author:** Ripley (iOS Dev)
**Status:** Proposed

## Context

Xcode builds were failing because `SpoolScannerProtocol.swift` was assigned the same UUID as `AppDelegate.swift` in `project.pbxproj`. This happened because UUIDs were hand-crafted when adding Phase 2 scanning files outside of Xcode (likely by an agent generating pbxproj entries directly).

SPM builds (`swift build`) passed fine since they use `Package.swift`, masking the issue entirely.

## Decision

When any agent modifies `project.pbxproj` directly (outside Xcode):
1. **All new UUIDs must be checked for uniqueness** against every existing UUID in the file before insertion.
2. **Use random 24-character hex strings** (not human-readable patterns like `A1B2C3D4...`) to reduce collision risk.
3. **Run `plutil -lint` AND `xcodebuild` after changes** — plutil alone won't catch UUID collisions.

## Consequences

- Prevents silent build failures that only surface in Xcode
- Adds a validation step to any pbxproj-modifying workflow
