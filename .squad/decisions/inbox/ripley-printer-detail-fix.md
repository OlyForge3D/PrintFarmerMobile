# Decision: PrinterDetailView Blank Page Fix

**Author:** Ripley (iOS Dev)
**Date:** 2025-07-18
**Status:** Applied

## Context
Users reported a blank page when tapping a printer in the list. PrinterDetailView rendered nothing.

## Root Cause
Two bugs combined:
1. The view body had three `if/else if` branches (loading, error, content) but **no final `else`**. The initial render state matched none of them → blank.
2. `loadPrinter()` set `isLoading = true` *after* a `guard let printerService` check. If the guard failed, the method returned silently — no loading indicator, no error, permanent blank.

## Decision
- **View pattern:** Always have a default `else` branch in conditional view bodies. Use: content first → error second → else ProgressView.
- **ViewModel pattern:** Set loading state *before* any guards in async load methods. If a guard fails, surface it as an `errorMessage` rather than silently returning.

## Team Impact
- **All agents:** Apply the same defensive rendering pattern to other detail views (JobDetailView, etc.) to prevent similar blank-page bugs.
- **Lambert:** `GET /api/printers/{id}` returns `PrinterDto` which lacks `InMaintenance`/`IsEnabled` fields. Consider either adding those to `PrinterDto` or having the iOS app call `/api/printers/{id}/details` instead. Low priority — defaults work fine for now.
