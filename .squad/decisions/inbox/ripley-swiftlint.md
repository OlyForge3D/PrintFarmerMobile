# Decision: SwiftLint Cleanup Patterns

**Author:** Ripley  
**Date:** 2026-03-08  
**Status:** Applied

## Context
Cleaned 28 SwiftLint violations. Established patterns for the team:

## Decisions
1. **Models.swift file_length**: Suppressed with `// swiftlint:disable file_length` rather than splitting — the file is a coherent domain model collection and splitting would harm discoverability.
2. **SpoolmanSpool+ColorName refactor**: Extracted `achromaticNames` and `dominantChannelNames` helpers to reduce cyclomatic complexity. This pattern (extract branches into focused helpers) should be used for future complexity violations.
3. **PrinterDetailView extraction**: Extracted `activeSpoolContent(_:)` as a `@ViewBuilder` helper to keep `filamentSection` under 100 lines. Same pattern applies to other long view builders.
4. **NFC wiring consistency**: Both SpoolPickerView and SpoolInventoryView now configure NFC scanner in `.task` block using `#if canImport(UIKit)` guard.
