# Decision: Jobs Tab Shows Jobs, Not Printers

**Author:** Ripley (iOS Dev)
**Date:** 2025-07-17
**Status:** Implemented

## Context

Jeff reported the Jobs tab was showing "available printers" instead of print jobs. The root cause was that `JobListView` fetched from `GET /api/job-queue` which returns `[QueueOverview]` — a printer-centric view with one row per printer. This made the Jobs tab look like a printer list with an "Available" section showing idle printers.

## Decision

- Switched the Jobs tab to use `GET /api/job-queue-analytics` which returns individual print jobs (`[QueuedPrintJobWithFileMetaDto]`)
- Jobs are grouped by status: **Printing** (active on a printer), **In Queue** (waiting), **Recent** (completed/failed/cancelled, collapsible)
- The old `list() -> [QueueOverview]` method stays on the protocol for backward compat (Dashboard or other views may use it)
- Added `listAllJobs() -> [QueuedPrintJobResponse]` to `JobServiceProtocol`

## Impact

- **Views affected:** `JobListView`, `JobListViewModel`
- **Models added:** `QueuedPrintJobResponse`, `QueuedJobInfo`, `QueuePrinterMeta`, `QueueGcodeFileMeta`, `QueueStats`
- **Protocol change:** `JobServiceProtocol` gained `listAllJobs()` method
- **Mock updated:** `MockJobService` updated with new method + `queuedJobResponsesToReturn` property
- **No breaking changes:** Old `list()` method preserved; existing tests using `QueueOverview` still pass
