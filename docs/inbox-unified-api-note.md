# Inbox — optional unified API (design note)

**Status:** not implemented; UI uses REST pending + legacy local panels.

## Today

- Remote: `GET` session pending lists, poll ~10s (`PlatformBootstrap`).
- Local: `BookingRepository.getPendingRequests` when no server.

## Future (optional)

Single facade endpoint, e.g. `GET /v1/inbox/pending?profileId=` returning tagged items `{ source: rest|legacy, ... }` so one client model and one poll loop.

Until then: `PendingBookingsFacade` + section headers in UI.
