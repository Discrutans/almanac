from typing import Any

from fastapi import APIRouter, Depends, Header, HTTPException
from fastapi.responses import JSONResponse

from ..auth import require_api_key
from ..db.repository import DatabaseRepository, get_db
from ..models.session import (
    CalendarSnapshotPayload,
    CalendarSnapshotResponse,
    EventLockHeartbeatRequest,
    EventLockRequest,
    EventLockResponse,
)

router = APIRouter(prefix="/v1/calendar", tags=["calendar"])

_WORKSPACE_SNAPSHOT_ID = "default"


def _event_count(data: dict[str, Any] | None) -> int:
    if not data:
        return 0
    snapshot = data.get("snapshot") or {}
    events = snapshot.get("eventsByProfile") or {}
    return sum(len(items or []) for items in events.values())


def _merge_workspace_snapshots(rows: list[dict[str, Any]]) -> dict[str, Any] | None:
    if not rows:
        return None
    base = max(rows, key=_event_count)
    snapshot = dict(base.get("snapshot") or {})
    events: dict[str, list[Any]] = {}
    profiles: dict[str, Any] = {}
    visible: set[str] = set(snapshot.get("visibleProfileIds") or [])

    for row in rows:
        snap = row.get("snapshot") or {}
        for profile in snap.get("profiles") or []:
            profile_id = profile.get("id") if isinstance(profile, dict) else None
            if profile_id:
                profiles[profile_id] = profile
        for profile_id, items in (snap.get("eventsByProfile") or {}).items():
            bucket = {
                item.get("id"): item
                for item in events.get(profile_id) or []
                if isinstance(item, dict) and item.get("id")
            }
            for item in items or []:
                if isinstance(item, dict) and item.get("id"):
                    bucket[item["id"]] = item
            events[profile_id] = list(bucket.values())
            if items:
                visible.add(profile_id)

    snapshot["eventsByProfile"] = events
    if profiles:
        snapshot["profiles"] = list(profiles.values())
    snapshot["visibleProfileIds"] = list(visible) or [_WORKSPACE_SNAPSHOT_ID]
    latest = max(row["updated_at"] for row in rows)
    return {"snapshot": snapshot, "updated_at": latest}


@router.get("/snapshot", response_model=CalendarSnapshotResponse)
async def get_snapshot(
    api_key: str = Depends(require_api_key),
    x_profile_id: str | None = Header(default=None, alias="X-Profile-Id"),
    db: DatabaseRepository = Depends(get_db),
) -> CalendarSnapshotResponse:
    profile_id = x_profile_id or _WORKSPACE_SNAPSHOT_ID
    merged = _merge_workspace_snapshots(await db.list_calendar_snapshots(api_key))
    if merged is None:
        data = await db.get_calendar_snapshot(api_key, profile_id)
        if profile_id != _WORKSPACE_SNAPSHOT_ID and _event_count(data) == 0:
            fallback = await db.get_calendar_snapshot(api_key, _WORKSPACE_SNAPSHOT_ID)
            if _event_count(fallback) > 0:
                data = fallback
                profile_id = _WORKSPACE_SNAPSHOT_ID
        if data is None:
            return CalendarSnapshotResponse(
                profile_id=profile_id,
                snapshot=None,
                updated_at=None,
            )
        merged = data
    return CalendarSnapshotResponse(
        profile_id=_WORKSPACE_SNAPSHOT_ID,
        snapshot=merged["snapshot"],
        updated_at=merged["updated_at"],
    )


_PROFILE_MAP_KEYS = (
    "eventsByProfile",
    "schedulesByProfile",
    "templatesByProfile",
    "requestsByProfile",
    "groupPlansByProfile",
    "savingsGoalsByProfile",
    "eventQuickTemplatesByProfile",
    "guestCalendarsByProfile",
    "platformConfigsByProfile",
)


def _merge_profile_slice(
    existing: dict[str, Any], incoming: dict[str, Any], profile_ids: list[str]
) -> dict[str, Any]:
    merged = dict(existing)
    profiles = {
        profile.get("id"): profile
        for profile in (existing.get("profiles") or [])
        if isinstance(profile, dict) and profile.get("id")
    }
    wanted = set(profile_ids)
    for profile in incoming.get("profiles") or []:
        profile_id = profile.get("id") if isinstance(profile, dict) else None
        if profile_id and profile_id in wanted:
            profiles[profile_id] = profile
    if profiles:
        merged["profiles"] = list(profiles.values())

    visible = list(existing.get("visibleProfileIds") or [])
    for profile_id in profile_ids:
        if profile_id not in visible:
            visible.append(profile_id)
    merged["visibleProfileIds"] = visible

    for key in _PROFILE_MAP_KEYS:
        current = dict(existing.get(key) or {})
        incoming_map = incoming.get(key) or {}
        if not isinstance(incoming_map, dict):
            incoming_map = {}
        for profile_id in profile_ids:
            if profile_id in incoming_map:
                current[profile_id] = incoming_map[profile_id]
        merged[key] = current
    return merged


@router.post("/snapshot", response_model=CalendarSnapshotResponse)
async def upsert_snapshot(
    body: CalendarSnapshotPayload,
    api_key: str = Depends(require_api_key),
    db: DatabaseRepository = Depends(get_db),
) -> CalendarSnapshotResponse:
    store_id = body.profile_id or _WORKSPACE_SNAPSHOT_ID
    snapshot = body.snapshot
    if body.merge_profile_ids:
        store_id = _WORKSPACE_SNAPSHOT_ID
        existing = await db.get_calendar_snapshot(api_key, store_id)
        base = (existing or {}).get("snapshot") or {}
        snapshot = _merge_profile_slice(base, body.snapshot, body.merge_profile_ids)
    updated_at = await db.upsert_calendar_snapshot(api_key, store_id, snapshot)
    return CalendarSnapshotResponse(
        profile_id=store_id,
        snapshot=snapshot,
        updated_at=updated_at,
    )


def _lock_response(payload: dict) -> EventLockResponse:
    return EventLockResponse(
        acquired=bool(payload.get("acquired")),
        event_id=str(payload.get("event_id") or ""),
        device_id=str(payload.get("device_id") or ""),
        expires_at=payload.get("expires_at"),
    )


@router.get("/locks")
async def list_locks(
    api_key: str = Depends(require_api_key),
    db: DatabaseRepository = Depends(get_db),
) -> dict[str, list[dict[str, Any]]]:
    locks = await db.list_event_locks(api_key)
    return {
        "locks": [
            {
                "event_id": item.get("event_id") or "",
                "device_id": item.get("device_id") or "",
                "expires_at": item.get("expires_at"),
            }
            for item in locks
        ]
    }


@router.post("/locks", response_model=None)
async def acquire_lock(
    body: EventLockRequest,
    api_key: str = Depends(require_api_key),
    db: DatabaseRepository = Depends(get_db),
) -> JSONResponse:
    result = await db.acquire_event_lock(
        api_key, body.event_id, body.device_id, body.ttl_seconds
    )
    status = 200 if result.get("acquired") else 409
    return JSONResponse(
        status_code=status,
        content=_lock_response(result).model_dump(mode="json"),
    )


@router.post("/locks/{event_id}/heartbeat", response_model=EventLockResponse)
async def heartbeat_lock(
    event_id: str,
    body: EventLockHeartbeatRequest,
    api_key: str = Depends(require_api_key),
    db: DatabaseRepository = Depends(get_db),
) -> EventLockResponse:
    result = await db.heartbeat_event_lock(
        api_key, event_id, body.device_id, body.ttl_seconds
    )
    if result is None:
        raise HTTPException(status_code=409, detail="lock_not_held")
    return _lock_response(result)


@router.delete("/locks/{event_id}")
async def release_lock(
    event_id: str,
    device_id: str,
    api_key: str = Depends(require_api_key),
    db: DatabaseRepository = Depends(get_db),
) -> dict[str, bool]:
    released = await db.release_event_lock(api_key, event_id, device_id)
    return {"released": released}
