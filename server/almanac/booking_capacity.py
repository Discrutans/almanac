from __future__ import annotations

from .models.session import BookingRequest, BookingRequestStatus, Session

_ACTIVE_STATUSES = frozenset(
    {BookingRequestStatus.pending, BookingRequestStatus.confirmed}
)


def slot_capacity(session: Session) -> int:
    raw = (session.state.settings or {}).get("slot_capacity", 1)
    try:
        return max(1, int(raw))
    except (TypeError, ValueError):
        return 1


def count_active_bookings(
    requests: list[BookingRequest],
    slot_id: str,
    *,
    exclude_request_id: str | None = None,
) -> int:
    return sum(
        1
        for request in requests
        if request.slot_id == slot_id
        and request.status in _ACTIVE_STATUSES
        and request.id != exclude_request_id
    )


def is_slot_full(
    session: Session,
    requests: list[BookingRequest],
    slot_id: str,
    *,
    exclude_request_id: str | None = None,
) -> bool:
    return (
        count_active_bookings(
            requests,
            slot_id,
            exclude_request_id=exclude_request_id,
        )
        >= slot_capacity(session)
    )
