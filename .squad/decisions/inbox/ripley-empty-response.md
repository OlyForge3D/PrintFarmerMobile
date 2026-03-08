# Decision: APIClient Empty Response Handling for Optional Types

**Date:** 2026-03-08  
**Author:** Ripley (iOS Dev)  
**Status:** Implemented

## Context

The PrintFarmer API returns empty response bodies (HTTP 204 No Content or 200 with empty body) when certain resources don't exist. For example, `/api/printers/{id}/printjob` returns an empty body when no print job is active.

Previously, `APIClient.execute<T: Decodable>()` always attempted to JSON-decode the response body, which failed with "dataCorrupted" errors on empty data, even when the method signature indicated an Optional return type (e.g., `PrintJobStatusInfo?`).

## Decision

Modified `APIClient.execute<T: Decodable>()` to handle empty response bodies intelligently:

1. **Before attempting decode**, check if `data.isEmpty`
2. **If empty and T is Optional**: Return `nil` (tested via `Optional<Any>.none as? T`)
3. **If empty and T is non-Optional**: Throw `NetworkError.decodingFailed` with descriptive message
4. **If non-empty**: Proceed with normal JSON decode

## Rationale

- **Type-safe handling**: Uses Swift's type system to distinguish Optional vs non-Optional at runtime
- **Contract enforcement**: Empty bodies for non-Optional types still error (catches API bugs)
- **Better error messages**: Non-Optional empty responses get a clear error ("Empty response body for non-optional type X")
- **Minimal change**: Single check before decode, doesn't affect existing decode paths

## Alternatives Considered

1. **Add `getOptional<T>()` method**: Rejected — duplicates logic, requires callsite changes
2. **Return nil for all empty responses**: Rejected — hides API contract violations for non-Optional types
3. **Check HTTP status code (204)**: Rejected — some 200 responses also have empty bodies

## Impact

- **Affected endpoints**: Currently only `PrinterService.getCurrentJob()`, but pattern now works for any future Optional-returning endpoints
- **Backward compatible**: No changes to method signatures or callsites
- **Build status**: Clean build, no regressions

## Follow-up

- Consider documenting this pattern in API client usage guidelines
- Monitor for other endpoints that might benefit from Optional returns
