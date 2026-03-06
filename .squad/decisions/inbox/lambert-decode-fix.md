# Decision: Enum & Date Serialization Contract

**Date:** 2026-07-16
**Author:** Lambert (Networking/API Dev)
**Status:** Applied

## Context
After login, the dashboard crashed with "Failed to decode response" because Swift model enums used `Int` raw values while the ASP.NET Core backend serializes ALL enums as strings via `JsonStringEnumConverter`.

## Decision
1. **All Swift enums that map to backend C# enums MUST use String raw values** matching the C# member names exactly (e.g., `case moonraker = "Moonraker"`, `case sdcp = "SDCP"`). Each enum includes a fallback `init(from:)` that also accepts legacy integer values.

2. **The JSONDecoder uses a custom date strategy** that handles ISO 8601 both with and without fractional seconds. The built-in `.iso8601` strategy must NOT be used — it silently rejects fractional seconds.

3. **Backend `TimeSpan` fields are represented as `String?` in Swift** with parsing helpers (`.timeSpanSeconds`, `.timeSpanFormatted`), since .NET serializes `TimeSpan` as duration strings.

## Impact
- **Ripley/Views:** `StatusBadge(jobStatus:)` now accepts `PrintJobStatus?`. `MotionType.polar` was removed (doesn't exist in backend — `Unknown` is the correct fallback).
- **Ash/Tests:** Enum test fixtures must use string values, not integers. Mock JSON payloads should match backend format.
- **All agents:** When adding new model fields, always check the backend DTO in `~/s/PFarm1/src/infra/Dtos/` and the serialization config in `~/s/PFarm1/src/api/Startup/ControllerStartup.cs`.
