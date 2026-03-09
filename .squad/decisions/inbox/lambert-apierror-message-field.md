# Decision: APIError now captures CommandResult.message

**Author:** Lambert (Networking)
**Date:** 2025-07-24

## Context
Backend printer command endpoints (filament-load/unload, active-spool, etc.) return `CommandResult` bodies on HTTP 400, using a `message` field. The iOS `APIError` model only had `title`/`detail` (matching ASP.NET ProblemDetails), silently losing the actual error reason.

## Decision
Added `message: String?` to `APIError`. The error description fallback chain is now: `detail → message → title → "Client error (code)"`.

## Impact
- All 400-level errors from printer command endpoints now surface the backend's actual error message to the user.
- No breaking changes — `message` is optional, existing ProblemDetails-shaped errors still work via `detail`/`title`.
- Ripley: error messages in the UI will now be more descriptive for spool/filament operations (e.g., "Spool 42 is already loaded on printer X" instead of "Client error (400)").
