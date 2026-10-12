"""HTTP API smoke tests (SQLite in-memory file per test run)."""

import pytest


@pytest.mark.asyncio
async def test_health(api_client):
    response = await api_client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


@pytest.mark.asyncio
async def test_workspace_requires_api_key(api_client):
    response = await api_client.get("/v1/workspace")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_workspace_and_booking_session(api_client):
    headers = {"X-Api-Key": "test-api-key", "X-Profile-Id": "default"}

    workspace = await api_client.get("/v1/workspace", headers=headers)
    assert workspace.status_code == 200

    create = await api_client.post(
        "/v1/sessions",
        headers=headers,
        json={
            "mode": "booking",
            "title": "Test booking",
            "slots": [
                {
                    "id": "slot-1",
                    "start": "2026-06-27T12:00:00+00:00",
                    "end": "2026-06-27T13:00:00+00:00",
                }
            ],
            "form_fields": [{"id": "name", "label": "Name", "required": True}],
            "settings": {"slot_capacity": 1},
        },
    )
    assert create.status_code == 200, create.text
    body = create.json()
    assert body["token"]
    assert "deep_link" in body

    public = await api_client.get(f"/v1/sessions/{body['token']}")
    assert public.status_code == 200
    session = public.json()
    assert session["title"] == "Test booking"
    assert session["state"]["settings"]["slot_capacity"] == 1


@pytest.mark.asyncio
async def test_snapshot_falls_back_to_default_when_profile_empty(api_client):
    headers = {"X-Api-Key": "snap-key", "X-Profile-Id": "default"}
    posted = await api_client.post(
        "/v1/calendar/snapshot",
        headers=headers,
        json={
            "profile_id": "default",
            "snapshot": {
                "activeProfileId": "default",
                "eventsByProfile": {
                    "default": [{"id": "e1", "title": "Meeting"}],
                },
            },
        },
    )
    assert posted.status_code == 200, posted.text

    empty_headers = {"X-Api-Key": "snap-key", "X-Profile-Id": "profile-2-empty"}
    empty = await api_client.post(
        "/v1/calendar/snapshot",
        headers=empty_headers,
        json={
            "profile_id": "profile-2-empty",
            "snapshot": {
                "activeProfileId": "profile-2-empty",
                "eventsByProfile": {"profile-2-empty": []},
            },
        },
    )
    assert empty.status_code == 200, empty.text

    solo = await api_client.post(
        "/v1/calendar/snapshot",
        headers={"X-Api-Key": "snap-key", "X-Profile-Id": "profile-2-solo"},
        json={
            "profile_id": "profile-2-solo",
            "snapshot": {
                "activeProfileId": "profile-2-solo",
                "eventsByProfile": {
                    "profile-2-solo": [{"id": "e2", "title": "Solo"}],
                },
            },
        },
    )
    assert solo.status_code == 200, solo.text

    pulled = await api_client.get("/v1/calendar/snapshot", headers=empty_headers)
    assert pulled.status_code == 200
    body = pulled.json()
    titles = [
        event.get("title")
        for event in body["snapshot"]["eventsByProfile"]["default"]
    ]
    assert "Meeting" in titles
    assert "Solo" not in titles
    solo_titles = [
        event.get("title")
        for event in body["snapshot"]["eventsByProfile"]["profile-2-solo"]
    ]
    assert "Solo" in solo_titles


@pytest.mark.asyncio
async def test_snapshot_merges_selected_profile_without_wiping_others(api_client):
    headers = {"X-Api-Key": "merge-key", "X-Profile-Id": "default"}
    first = await api_client.post(
        "/v1/calendar/snapshot",
        headers=headers,
        json={
            "profile_id": "default",
            "snapshot": {
                "activeProfileId": "default",
                "profiles": [{"id": "default", "name": "Main"}],
                "eventsByProfile": {
                    "default": [{"id": "e1", "title": "Meeting"}],
                },
            },
        },
    )
    assert first.status_code == 200, first.text

    work = await api_client.post(
        "/v1/calendar/snapshot",
        headers=headers,
        json={
            "profile_id": "default",
            "merge_profile_ids": ["work"],
            "snapshot": {
                "activeProfileId": "work",
                "profiles": [{"id": "work", "name": "Work"}],
                "eventsByProfile": {
                    "work": [{"id": "e2", "title": "Shift"}],
                },
            },
        },
    )
    assert work.status_code == 200, work.text

    pulled = await api_client.get("/v1/calendar/snapshot", headers=headers)
    assert pulled.status_code == 200
    events = pulled.json()["snapshot"]["eventsByProfile"]
    assert events["default"][0]["title"] == "Meeting"
    assert events["work"][0]["title"] == "Shift"


@pytest.mark.asyncio
async def test_event_lock_conflict_heartbeat_and_release(api_client):
    headers = {"X-Api-Key": "lock-key"}
    acquired = await api_client.post(
        "/v1/calendar/locks",
        headers=headers,
        json={"event_id": "evt-1", "device_id": "device-a", "ttl_seconds": 90},
    )
    assert acquired.status_code == 200, acquired.text
    body = acquired.json()
    assert body["acquired"] is True
    assert body["device_id"] == "device-a"

    same_device = await api_client.post(
        "/v1/calendar/locks",
        headers=headers,
        json={"event_id": "evt-1", "device_id": "device-a"},
    )
    assert same_device.status_code == 200, same_device.text

    conflict = await api_client.post(
        "/v1/calendar/locks",
        headers=headers,
        json={"event_id": "evt-1", "device_id": "device-b"},
    )
    assert conflict.status_code == 409
    held = conflict.json()
    assert held["acquired"] is False
    assert held["device_id"] == "device-a"

    heartbeat = await api_client.post(
        "/v1/calendar/locks/evt-1/heartbeat",
        headers=headers,
        json={"device_id": "device-a"},
    )
    assert heartbeat.status_code == 200, heartbeat.text
    assert heartbeat.json()["acquired"] is True

    other_heartbeat = await api_client.post(
        "/v1/calendar/locks/evt-1/heartbeat",
        headers=headers,
        json={"device_id": "device-b"},
    )
    assert other_heartbeat.status_code == 409

    other_release = await api_client.delete(
        "/v1/calendar/locks/evt-1",
        headers=headers,
        params={"device_id": "device-b"},
    )
    assert other_release.status_code == 200
    assert other_release.json()["released"] is False

    released = await api_client.delete(
        "/v1/calendar/locks/evt-1",
        headers=headers,
        params={"device_id": "device-a"},
    )
    assert released.status_code == 200
    assert released.json()["released"] is True

    second = await api_client.post(
        "/v1/calendar/locks",
        headers=headers,
        json={"event_id": "evt-1", "device_id": "device-b"},
    )
    assert second.status_code == 200, second.text
    assert second.json()["device_id"] == "device-b"

    listed = await api_client.get("/v1/calendar/locks", headers=headers)
    assert listed.status_code == 200, listed.text
    ids = [item["event_id"] for item in listed.json()["locks"]]
    assert "evt-1" in ids

