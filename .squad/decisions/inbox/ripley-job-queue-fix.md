# Decision: Job Queue UX — Pause/Resume API Routes

**Date:** 2025-07-25
**Author:** Ripley (iOS Dev)
**Status:** Implemented

## Context

The backend has two separate controllers for job operations:
- `JobQueueController` at `/api/job-queue` — CRUD, dispatch, cancel, abort
- `JobQueueAnalyticsController` at `/api/job-queue-analytics` — listing with metadata, pause, resume

## Decision

Pause and resume call the analytics controller routes (`/api/job-queue-analytics/jobs/{id}/pause` and `/resume`) rather than the queue controller, because that's where the backend implements them.

## Impact

- Lambert: If the API client or service layer is refactored, note the split routes
- Ash: MockJobService now has `pauseCalledWith` and `resumeCalledWith` for test tracking
- Dallas: No navigation changes — actions are within existing JobDetailView
