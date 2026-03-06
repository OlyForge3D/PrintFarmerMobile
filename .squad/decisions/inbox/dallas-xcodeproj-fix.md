# Xcode Project Regeneration

**Author:** Dallas (Lead)
**Date:** 2026-03-06
**Status:** Implemented

## Decision

Regenerated `PrintFarmer.xcodeproj` from scratch rather than patching the damaged original. The project file is now auto-generated from the file tree using a deterministic Python script.

## Context

The original scaffolded `.xcodeproj` had three fatal issues:
1. Missing closing `}` in `project.pbxproj` (plist parse failure)
2. Empty workspace data (no `<FileRef>` in `contents.xcworkspacedata`)
3. 21 Swift files added during MVP batch (Lambert/Ripley/Ash) were never registered

## Impact

- **All agents:** When adding new `.swift` files, the xcodeproj must be regenerated. SPM (`swift build`) will work without changes, but Xcode won't see new files until the project is updated.
- **Future consideration:** A workspace-only approach (Xcode opens `Package.swift` directly) would eliminate this sync problem entirely. Deferred for now since the xcodeproj provides better Xcode integration (schemes, test plans, signing).

## Specifications

- iOS 17+, Swift 6.0
- Bundle ID: `com.printfarmer.ios`
- 47 source files, 19 test files (66 total)
- KeychainSwift SPM dependency
- Deterministic IDs (md5-based) — regeneration is idempotent
