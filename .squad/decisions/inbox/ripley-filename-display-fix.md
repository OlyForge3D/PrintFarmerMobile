# Decision: Fix GcodeFileName mapping in backend JobQueueService

**Date:** 2025-07-22
**Author:** Ripley (iOS Dev)
**Status:** Applied

## Context
Print job detail pages in the iOS app showed internal on-disk filenames (GUID-based) instead of the original user-uploaded filename. The `StoredFile` base class has two name fields: `Name` (original display name) and `FileName` (GUID-based disk name).

## Decision
Fixed the backend `JobQueueService.cs` to use `GcodeFile.Name` instead of `GcodeFile.FileName` when populating the `GcodeFileName` field in `JobQueuePrintJobDto`. This was a cross-repo fix applied in `~/s/PFarm1`.

## Impact
- No iOS model or view changes needed — the iOS `PrintJob.gcodeFileName` field and computed `name` property already display whatever the API sends
- All API consumers (iOS, web) will now see the original filename
- Existing print jobs in the database are unaffected since the DTO mapping is computed at query time from the GcodeFile navigation property
