# Decision: Predictive Insights Graceful Empty State

**Author:** Ripley  
**Date:** 2026-03-09  
**Status:** Implemented

## Context
The Predictive Insights feature showed "Failed to decode response: The data couldn't be read because it's missing" when the API returned empty/null body (no predictions available yet). This is the same class of bug as the print job empty response fix.

## Decision
1. **All predictive model fields use `decodeIfPresent` with defaults** — the API may omit fields or return partial data. Models should never crash on missing keys.
2. **`predictJobFailure` returns `JobFailurePrediction?`** — empty body returns nil instead of throwing decode error.
3. **`getActiveAlerts`/`getMaintenanceForecast` coalesce empty body to `[]`** — array endpoints return empty arrays on empty/null body.
4. **View shows "No predictions available" empty state** — instead of an error screen, users see a friendly message explaining predictions will appear once enough print history exists.
5. **Errors are logged, not displayed** — decode/network failures go to `os.Logger`, not to the user-facing error state.

## Impact
- **Lambert:** No service contract changes needed — protocol already updated.
- **Ash:** `MockPredictiveService.predictJobFailure` now returns Optional; tests expecting force-unwrap need updating.
- **Dallas:** No architecture changes.
