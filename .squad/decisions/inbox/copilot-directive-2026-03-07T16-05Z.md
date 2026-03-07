### 2026-03-07T16:05:00Z: User directive
**By:** Jeff Papiez (via Copilot)
**What:** All work must pass `swift build` before being claimed as complete. No agent should report "done" without a clean build. When `swift test` or `xcodebuild` become available (full Xcode installed), those should also gate completion.
**Why:** User request — quality gate for all future work
