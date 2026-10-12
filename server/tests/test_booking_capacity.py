"""Tests for per-slot booking capacity."""

from datetime import datetime, timezone

from almanac.booking_capacity import (
    count_active_bookings,
    is_slot_full,
    slot_capacity,
)
from almanac.models.session import (
    BookingRequest,
    BookingRequestStatus,
    Session,
    SessionMode,
    SessionState,
    SessionStatus,
)


def _session(*, capacity: int = 1) -> Session:
    return Session(
        id="s1",
        token="tok",
        workspace_api_key="key",
        profile_id="default",
        mode=SessionMode.booking,
        title="Test",
        state=SessionState(settings={"slot_capacity": capacity}),
        version=1,
        status=SessionStatus.open,
        created_at=datetime.now(timezone.utc),
    )


def _request(
    request_id: str,
    *,
    slot_id: str = "slot-1",
    status: BookingRequestStatus = BookingRequestStatus.pending,
) -> BookingRequest:
    return BookingRequest(
        id=request_id,
        session_id="s1",
        slot_id=slot_id,
        fields={"name": "User"},
        status=status,
        created_at=datetime.now(timezone.utc),
    )


def test_slot_capacity_defaults_to_one():
    session = _session(capacity=0)
    assert slot_capacity(session) == 1


def test_slot_capacity_reads_settings():
    session = _session(capacity=5)
    assert slot_capacity(session) == 5


def test_count_active_bookings_ignores_rejected():
    requests = [
        _request("r1", status=BookingRequestStatus.pending),
        _request("r2", status=BookingRequestStatus.rejected),
        _request("r3", status=BookingRequestStatus.confirmed),
    ]
    assert count_active_bookings(requests, "slot-1") == 2


def test_is_slot_full_when_capacity_reached():
    session = _session(capacity=1)
    requests = [_request("r1")]
    assert is_slot_full(session, requests, "slot-1")


def test_confirm_excludes_current_request_from_count():
    session = _session(capacity=1)
    requests = [_request("r1")]
    assert not is_slot_full(session, requests, "slot-1", exclude_request_id="r1")
