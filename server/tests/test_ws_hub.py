"""Tests for collaborative session patch authorization."""

from almanac.models.session import SessionMode, SessionState, SessionStatus
from almanac.ws.hub import SessionHub, _apply_ops
import pytest


@pytest.mark.asyncio
async def test_collaborative_patch_rejected_when_editor_limit_reached():
    from datetime import datetime, timezone
    from almanac.models.session import Session

    hub = SessionHub()
    session = Session(
        id="s1",
        token="tok",
        workspace_api_key="owner-key",
        profile_id="default",
        mode=SessionMode.collaborative,
        title="Test",
        state=SessionState(
            slots=[],
            form_fields=[],
            settings={"max_editors": 1, "editors": ["existing-client"]},
        ),
        version=1,
        status=SessionStatus.open,
        created_at=datetime.now(timezone.utc),
    )

    class FakeWebSocket:
        sent: list[dict] = []

        async def send_json(self, payload: dict) -> None:
            self.sent.append(payload)

    ws = FakeWebSocket()
    ws.sent = []

    class FakeDb:
        pass

    await hub.handle_message(
        token="tok",
        websocket=ws,
        session=session,
        raw='{"type":"patch","baseVersion":1,"ops":[{"op":"addSlot","slot":{"id":"1","start":"2026-01-01T10:00:00Z","end":"2026-01-01T11:00:00Z"}}]}',
        db=FakeDb(),
        api_key=None,
        client_id="new-client",
    )

    assert ws.sent[-1]["type"] == "error"
    assert "editor limit" in ws.sent[-1]["message"].lower()


def test_apply_ops_add_slot():
    from datetime import datetime, timezone

    state = SessionState(slots=[], form_fields=[])
    updated = _apply_ops(
        state,
        [
            {
                "op": "addSlot",
                "slot": {
                    "id": "slot-1",
                    "start": datetime(2026, 1, 1, 10, tzinfo=timezone.utc).isoformat(),
                    "end": datetime(2026, 1, 1, 11, tzinfo=timezone.utc).isoformat(),
                },
            }
        ],
    )
    assert len(updated.slots) == 1
    assert updated.slots[0].id == "slot-1"
