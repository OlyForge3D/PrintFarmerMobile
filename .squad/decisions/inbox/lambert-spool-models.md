# Decision: Spoolman Spool Model Naming & Pagination

**Author:** Lambert  
**Date:** 2026-07-17  
**Status:** Implemented

## Context
Phase 1 filament/spool models needed to match backend DTOs precisely.

## Decisions

1. **Model names use `Spoolman` prefix** (`SpoolmanSpool`, `SpoolmanFilament`, `SpoolmanVendor`, `SpoolmanMaterial`) to match backend DTO names and avoid collision with future domain models (e.g., a simpler `Spool` view model).

2. **Pagination uses `limit`/`offset`** (not `page`/`pageSize`) — matches Spoolman's native API which the backend proxies. Return type is `SpoolmanPagedResult<T>` with `items` and `totalCount`.

3. **Added `patch()` to APIClient** — backend uses HTTP PATCH for spool and filament updates. This is a new HTTP method available to all services.

4. **`SetActiveSpoolRequest` returns `CommandResult`** (not `Printer`) — matches backend's `PrintersController.SetActiveSpoolAsync` which returns `CommandResult`.

5. **Added `changeFilament()` to PrinterService** — backend has `filament-change` (M600) in addition to `filament-load`/`filament-unload`. Included for completeness.

## Impact
- Ripley can build filament management UI against `SpoolServiceProtocol` and the extended `PrinterServiceProtocol`.
- ViewModels should use `SpoolmanPagedResult` for infinite scroll / pagination patterns.
