### 2026-03-07T16:12:00Z: User directive (updated)
**By:** Jeff Papiez (via Copilot)
**What:** Quality gate for all agent work — must pass before claiming "done":
1. `swift build` — must compile clean (zero errors)
2. `swiftlint lint --quiet` — zero errors (warnings OK as baseline, should trend down)
Tests (`swift test`) have a known `@main` linker conflict in SPM — tests run in Xcode only.
**Why:** User requested build validation as part of all work
