"""YandexDB repository — enable with ALMANAC_DB_BACKEND=ydb."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

import ydb

from ..config import settings
from ..models.session import (
    BookingRequest,
    BookingRequestStatus,
    Session,
    SessionClient,
    SessionMode,
    SessionState,
    SessionStatus,
)
from .repository import DatabaseRepository
from .session_mapping import (
    booking_request_from_row,
    datetime_from_storage,
    fields_to_json,
    generate_request_id,
    generate_session_identity,
    json_decode,
    json_encode,
    session_from_row,
    session_with_requests,
    state_to_json,
    utcnow,
)
from .ydb_driver import apply_schema, close_pool, row_value, run_async


def _timestamp(value: datetime) -> datetime:
    return value.astimezone(timezone.utc)


def _parse_session_row(row: Any, requests: list[BookingRequest] | None = None) -> Session:
    return session_from_row(
        {
            "id": row_value(row, 0),
            "token": row_value(row, 1),
            "workspace_api_key": row_value(row, 2),
            "profile_id": row_value(row, 3),
            "mode": row_value(row, 4),
            "title": row_value(row, 5),
            "state_json": row_value(row, 6),
            "version": row_value(row, 7),
            "status": row_value(row, 8),
            "created_at": row_value(row, 9),
        },
        requests,
    )


def _parse_booking_request(row: Any) -> BookingRequest:
    return booking_request_from_row(
        {
            "id": row_value(row, 0),
            "session_id": row_value(row, 1),
            "slot_id": row_value(row, 2),
            "fields_json": row_value(row, 3),
            "status": row_value(row, 4),
            "created_at": row_value(row, 5),
        }
    )


class YdbRepository(DatabaseRepository):
    def __init__(self) -> None:
        self._event_locks: dict[tuple[str, str], dict[str, Any]] = {}

    async def init(self) -> None:
        import asyncio

        await asyncio.get_running_loop().run_in_executor(None, apply_schema)

    async def close(self) -> None:
        close_pool()

    async def ensure_workspace(
        self, api_key: str, profile_id: str, name: str = ""
    ) -> dict[str, Any]:
        existing = await self.get_workspace_by_api_key(api_key)
        if existing is not None:
            return existing

        created_at = utcnow()

        def callee(session: ydb.Session) -> None:
            prepared = session.prepare(
                """
                DECLARE $api_key AS Utf8;
                DECLARE $profile_id AS Utf8;
                DECLARE $name AS Utf8;
                DECLARE $created_at AS Timestamp;
                UPSERT INTO workspaces (api_key, profile_id, name, created_at)
                VALUES ($api_key, $profile_id, $name, $created_at);
                """
            )
            session.transaction(ydb.SerializableReadWrite()).execute(
                prepared,
                {
                    "$api_key": api_key,
                    "$profile_id": profile_id,
                    "$name": name,
                    "$created_at": _timestamp(created_at),
                },
                commit_tx=True,
            )

        await run_async(callee)
        return {
            "api_key": api_key,
            "profile_id": profile_id,
            "name": name,
            "created_at": created_at,
        }

    async def get_workspace_by_api_key(self, api_key: str) -> dict[str, Any] | None:
        def callee(session: ydb.Session) -> dict[str, Any] | None:
            prepared = session.prepare(
                """
                DECLARE $api_key AS Utf8;
                SELECT api_key, profile_id, name, created_at
                FROM workspaces
                WHERE api_key = $api_key;
                """
            )
            result_sets = session.transaction(ydb.StaleReadOnly()).execute(
                prepared,
                {"$api_key": api_key},
                commit_tx=True,
            )
            rows = result_sets[0].rows
            if not rows:
                return None
            row = rows[0]
            return {
                "api_key": row_value(row, 0),
                "profile_id": row_value(row, 1),
                "name": row_value(row, 2),
                "created_at": datetime_from_storage(row_value(row, 3)),
            }

        return await run_async(callee)

    async def create_session(
        self,
        *,
        api_key: str,
        profile_id: str,
        mode: SessionMode,
        title: str,
        state: SessionState,
    ) -> Session:
        await self.ensure_workspace(api_key, profile_id)
        session_id, token = generate_session_identity()
        created_at = utcnow()
        state_json = state_to_json(state)

        def callee(session: ydb.Session) -> None:
            prepared = session.prepare(
                """
                DECLARE $id AS Utf8;
                DECLARE $token AS Utf8;
                DECLARE $workspace_api_key AS Utf8;
                DECLARE $profile_id AS Utf8;
                DECLARE $mode AS Utf8;
                DECLARE $title AS Utf8;
                DECLARE $state_json AS JsonDocument;
                DECLARE $version AS Uint64;
                DECLARE $status AS Utf8;
                DECLARE $created_at AS Timestamp;
                UPSERT INTO sessions (
                  id, token, workspace_api_key, profile_id, mode, title,
                  state_json, version, status, created_at
                ) VALUES (
                  $id, $token, $workspace_api_key, $profile_id, $mode, $title,
                  $state_json, $version, $status, $created_at
                );
                """
            )
            session.transaction(ydb.SerializableReadWrite()).execute(
                prepared,
                {
                    "$id": session_id,
                    "$token": token,
                    "$workspace_api_key": api_key,
                    "$profile_id": profile_id,
                    "$mode": mode.value,
                    "$title": title,
                    "$state_json": state_json,
                    "$version": 1,
                    "$status": SessionStatus.open.value,
                    "$created_at": _timestamp(created_at),
                },
                commit_tx=True,
            )

        await run_async(callee)
        session = await self.get_session_by_token(token)
        assert session is not None
        return session

    async def list_sessions(self, api_key: str) -> list[Session]:
        def callee(session: ydb.Session) -> list[Session]:
            prepared = session.prepare(
                """
                DECLARE $api_key AS Utf8;
                SELECT id, token, workspace_api_key, profile_id, mode, title,
                       state_json, version, status, created_at
                FROM sessions VIEW sessions_by_workspace
                WHERE workspace_api_key = $api_key;
                """
            )
            result_sets = session.transaction(ydb.StaleReadOnly()).execute(
                prepared,
                {"$api_key": api_key},
                commit_tx=True,
            )
            sessions = [
                _parse_session_row(row) for row in result_sets[0].rows
            ]
            return sessions

        sessions = await run_async(callee)
        enriched: list[Session] = []
        for item in sessions:
            requests = await self.list_booking_requests(item.id)
            enriched.append(session_with_requests(item, requests))
        return enriched

    async def _get_session_row_by_token(self, token: str) -> Any | None:
        def callee(session: ydb.Session) -> Any | None:
            prepared = session.prepare(
                """
                DECLARE $token AS Utf8;
                SELECT id, token, workspace_api_key, profile_id, mode, title,
                       state_json, version, status, created_at
                FROM sessions VIEW sessions_by_token
                WHERE token = $token;
                """
            )
            result_sets = session.transaction(ydb.StaleReadOnly()).execute(
                prepared,
                {"$token": token},
                commit_tx=True,
            )
            rows = result_sets[0].rows
            return rows[0] if rows else None

        return await run_async(callee)

    async def get_session_by_token(self, token: str) -> Session | None:
        row = await self._get_session_row_by_token(token)
        if row is None:
            return None
        session = _parse_session_row(row)
        requests = await self.list_booking_requests(session.id)
        return session_with_requests(session, requests)

    async def get_session_by_id(self, session_id: str) -> Session | None:
        def callee(session: ydb.Session) -> Any | None:
            prepared = session.prepare(
                """
                DECLARE $id AS Utf8;
                SELECT id, token, workspace_api_key, profile_id, mode, title,
                       state_json, version, status, created_at
                FROM sessions
                WHERE id = $id;
                """
            )
            result_sets = session.transaction(ydb.StaleReadOnly()).execute(
                prepared,
                {"$id": session_id},
                commit_tx=True,
            )
            rows = result_sets[0].rows
            return rows[0] if rows else None

        row = await run_async(callee)
        if row is None:
            return None
        parsed = _parse_session_row(row)
        requests = await self.list_booking_requests(parsed.id)
        return session_with_requests(parsed, requests)

    async def update_session_state(
        self, session_id: str, state: SessionState, expected_version: int
    ) -> Session | None:
        state_json = state_to_json(state)

        def callee(session: ydb.Session) -> bool:
            prepared = session.prepare(
                """
                DECLARE $id AS Utf8;
                DECLARE $state_json AS JsonDocument;
                DECLARE $expected_version AS Uint64;
                UPDATE sessions
                SET state_json = $state_json, version = version + 1u
                WHERE id = $id AND version = $expected_version;
                """
            )
            result_sets = session.transaction(ydb.SerializableReadWrite()).execute(
                prepared,
                {
                    "$id": session_id,
                    "$state_json": state_json,
                    "$expected_version": expected_version,
                },
                commit_tx=True,
            )
            return bool(result_sets[0].rows)

        updated = await run_async(callee)
        if not updated:
            return None
        return await self.get_session_by_id(session_id)

    async def close_session(self, token: str, api_key: str) -> bool:
        def callee(session: ydb.Session) -> bool:
            prepared = session.prepare(
                """
                DECLARE $token AS Utf8;
                DECLARE $api_key AS Utf8;
                DECLARE $status AS Utf8;
                UPDATE sessions
                SET status = $status
                WHERE token = $token AND workspace_api_key = $api_key;
                """
            )
            result_sets = session.transaction(ydb.SerializableReadWrite()).execute(
                prepared,
                {
                    "$token": token,
                    "$api_key": api_key,
                    "$status": SessionStatus.closed.value,
                },
                commit_tx=True,
            )
            return bool(result_sets[0].rows)

        return await run_async(callee)

    async def upsert_session_client(
        self, session_id: str, client_id: str, display_name: str
    ) -> SessionClient:
        now = utcnow()

        def callee(session: ydb.Session) -> None:
            prepared = session.prepare(
                """
                DECLARE $session_id AS Utf8;
                DECLARE $client_id AS Utf8;
                DECLARE $display_name AS Utf8;
                DECLARE $last_seen_at AS Timestamp;
                UPSERT INTO session_clients (session_id, client_id, display_name, last_seen_at)
                VALUES ($session_id, $client_id, $display_name, $last_seen_at);
                """
            )
            session.transaction(ydb.SerializableReadWrite()).execute(
                prepared,
                {
                    "$session_id": session_id,
                    "$client_id": client_id,
                    "$display_name": display_name,
                    "$last_seen_at": _timestamp(now),
                },
                commit_tx=True,
            )

        await run_async(callee)
        return SessionClient(
            client_id=client_id,
            display_name=display_name,
            last_seen_at=now,
        )

    async def remove_session_client(self, session_id: str, client_id: str) -> None:
        def callee(session: ydb.Session) -> None:
            prepared = session.prepare(
                """
                DECLARE $session_id AS Utf8;
                DECLARE $client_id AS Utf8;
                DELETE FROM session_clients
                WHERE session_id = $session_id AND client_id = $client_id;
                """
            )
            session.transaction(ydb.SerializableReadWrite()).execute(
                prepared,
                {"$session_id": session_id, "$client_id": client_id},
                commit_tx=True,
            )

        await run_async(callee)

    async def list_session_clients(self, session_id: str) -> list[SessionClient]:
        def callee(session: ydb.Session) -> list[SessionClient]:
            prepared = session.prepare(
                """
                DECLARE $session_id AS Utf8;
                SELECT client_id, display_name, last_seen_at
                FROM session_clients
                WHERE session_id = $session_id;
                """
            )
            result_sets = session.transaction(ydb.StaleReadOnly()).execute(
                prepared,
                {"$session_id": session_id},
                commit_tx=True,
            )
            clients: list[SessionClient] = []
            for row in result_sets[0].rows:
                clients.append(
                    SessionClient(
                        client_id=row_value(row, 0),
                        display_name=row_value(row, 1),
                        last_seen_at=datetime_from_storage(row_value(row, 2)),
                    )
                )
            return clients

        return await run_async(callee)

    async def create_booking_request(
        self,
        *,
        session_id: str,
        slot_id: str,
        fields: dict[str, str],
    ) -> BookingRequest:
        request_id = generate_request_id()
        created_at = utcnow()
        fields_json = fields_to_json(fields)

        def callee(session: ydb.Session) -> None:
            prepared = session.prepare(
                """
                DECLARE $id AS Utf8;
                DECLARE $session_id AS Utf8;
                DECLARE $slot_id AS Utf8;
                DECLARE $fields_json AS JsonDocument;
                DECLARE $status AS Utf8;
                DECLARE $created_at AS Timestamp;
                UPSERT INTO booking_requests (
                  id, session_id, slot_id, fields_json, status, created_at
                ) VALUES (
                  $id, $session_id, $slot_id, $fields_json, $status, $created_at
                );
                """
            )
            session.transaction(ydb.SerializableReadWrite()).execute(
                prepared,
                {
                    "$id": request_id,
                    "$session_id": session_id,
                    "$slot_id": slot_id,
                    "$fields_json": fields_json,
                    "$status": BookingRequestStatus.pending.value,
                    "$created_at": _timestamp(created_at),
                },
                commit_tx=True,
            )

        await run_async(callee)
        request = await self.get_booking_request(request_id)
        assert request is not None
        return request

    async def get_booking_request(self, request_id: str) -> BookingRequest | None:
        def callee(session: ydb.Session) -> BookingRequest | None:
            prepared = session.prepare(
                """
                DECLARE $id AS Utf8;
                SELECT id, session_id, slot_id, fields_json, status, created_at
                FROM booking_requests
                WHERE id = $id;
                """
            )
            result_sets = session.transaction(ydb.StaleReadOnly()).execute(
                prepared,
                {"$id": request_id},
                commit_tx=True,
            )
            rows = result_sets[0].rows
            if not rows:
                return None
            return _parse_booking_request(rows[0])

        return await run_async(callee)

    async def update_booking_request_status(
        self, request_id: str, status: BookingRequestStatus
    ) -> BookingRequest | None:
        def callee(session: ydb.Session) -> None:
            prepared = session.prepare(
                """
                DECLARE $id AS Utf8;
                DECLARE $status AS Utf8;
                UPDATE booking_requests
                SET status = $status
                WHERE id = $id;
                """
            )
            session.transaction(ydb.SerializableReadWrite()).execute(
                prepared,
                {"$id": request_id, "$status": status.value},
                commit_tx=True,
            )

        await run_async(callee)
        return await self.get_booking_request(request_id)

    async def list_booking_requests(self, session_id: str) -> list[BookingRequest]:
        def callee(session: ydb.Session) -> list[BookingRequest]:
            prepared = session.prepare(
                """
                DECLARE $session_id AS Utf8;
                SELECT id, session_id, slot_id, fields_json, status, created_at
                FROM booking_requests VIEW booking_requests_by_session
                WHERE session_id = $session_id;
                """
            )
            result_sets = session.transaction(ydb.StaleReadOnly()).execute(
                prepared,
                {"$session_id": session_id},
                commit_tx=True,
            )
            return [_parse_booking_request(row) for row in result_sets[0].rows]

        return await run_async(callee)

    async def get_calendar_snapshot(
        self, api_key: str, profile_id: str
    ) -> dict[str, Any] | None:
        def callee(session: ydb.Session) -> dict[str, Any] | None:
            prepared = session.prepare(
                """
                DECLARE $api_key AS Utf8;
                DECLARE $profile_id AS Utf8;
                SELECT snapshot_json, updated_at
                FROM calendar_snapshots
                WHERE api_key = $api_key AND profile_id = $profile_id;
                """
            )
            result_sets = session.transaction(ydb.StaleReadOnly()).execute(
                prepared,
                {"$api_key": api_key, "$profile_id": profile_id},
                commit_tx=True,
            )
            rows = result_sets[0].rows
            if not rows:
                return None
            row = rows[0]
            snapshot = json_decode(row_value(row, 0))
            updated_at = datetime_from_storage(row_value(row, 1))
            return {"snapshot": snapshot, "updated_at": updated_at}

        return await run_async(callee)

    async def list_calendar_snapshots(self, api_key: str) -> list[dict[str, Any]]:
        def callee(session: ydb.Session) -> list[dict[str, Any]]:
            prepared = session.prepare(
                """
                DECLARE $api_key AS Utf8;
                SELECT profile_id, snapshot_json, updated_at
                FROM calendar_snapshots
                WHERE api_key = $api_key;
                """
            )
            result_sets = session.transaction(ydb.StaleReadOnly()).execute(
                prepared,
                {"$api_key": api_key},
                commit_tx=True,
            )
            out: list[dict[str, Any]] = []
            for row in result_sets[0].rows:
                out.append(
                    {
                        "profile_id": row_value(row, 0),
                        "snapshot": json_decode(row_value(row, 1)),
                        "updated_at": datetime_from_storage(row_value(row, 2)),
                    }
                )
            return out

        return await run_async(callee)

    async def upsert_calendar_snapshot(
        self, api_key: str, profile_id: str, snapshot: dict[str, Any]
    ) -> datetime:
        await self.ensure_workspace(api_key, profile_id)
        updated_at = utcnow()
        snapshot_json = json_encode(snapshot)

        def callee(session: ydb.Session) -> None:
            prepared = session.prepare(
                """
                DECLARE $api_key AS Utf8;
                DECLARE $profile_id AS Utf8;
                DECLARE $snapshot_json AS JsonDocument;
                DECLARE $updated_at AS Timestamp;
                UPSERT INTO calendar_snapshots (api_key, profile_id, snapshot_json, updated_at)
                VALUES ($api_key, $profile_id, $snapshot_json, $updated_at);
                """
            )
            session.transaction(ydb.SerializableReadWrite()).execute(
                prepared,
                {
                    "$api_key": api_key,
                    "$profile_id": profile_id,
                    "$snapshot_json": snapshot_json,
                    "$updated_at": _timestamp(updated_at),
                },
                commit_tx=True,
            )

        await run_async(callee)
        return updated_at

    async def register_device_token(
        self, api_key: str, token: str, platform: str
    ) -> None:
        created_at = utcnow()

        def callee(session: ydb.Session) -> None:
            prepared = session.prepare(
                """
                DECLARE $api_key AS Utf8;
                DECLARE $token AS Utf8;
                DECLARE $platform AS Utf8;
                DECLARE $created_at AS Timestamp;
                UPSERT INTO device_tokens (api_key, token, platform, created_at)
                VALUES ($api_key, $token, $platform, $created_at);
                """
            )
            session.transaction(ydb.SerializableReadWrite()).execute(
                prepared,
                {
                    "$api_key": api_key,
                    "$token": token,
                    "$platform": platform,
                    "$created_at": _timestamp(created_at),
                },
                commit_tx=True,
            )

        await run_async(callee)

    async def list_device_tokens(self, api_key: str) -> list[str]:
        def callee(session: ydb.Session) -> list[str]:
            prepared = session.prepare(
                """
                DECLARE $api_key AS Utf8;
                SELECT token FROM device_tokens
                WHERE api_key = $api_key;
                """
            )
            result_sets = session.transaction(ydb.StaleReadOnly()).execute(
                prepared,
                {"$api_key": api_key},
                commit_tx=True,
            )
            return [row_value(row, 0) for row in result_sets[0].rows]

        return await run_async(callee)

    async def acquire_event_lock(
        self, api_key: str, event_id: str, device_id: str, ttl_seconds: int
    ) -> dict[str, Any]:
        now = utcnow()
        key = (api_key, event_id)
        existing = self._event_locks.get(key)
        if (
            existing is not None
            and existing["expires_at"] > now
            and existing["device_id"] != device_id
        ):
            return {
                "acquired": False,
                "event_id": event_id,
                "device_id": existing["device_id"],
                "expires_at": existing["expires_at"],
            }
        payload = {
            "acquired": True,
            "event_id": event_id,
            "device_id": device_id,
            "expires_at": now + timedelta(seconds=max(ttl_seconds, 15)),
        }
        self._event_locks[key] = payload
        return payload

    async def heartbeat_event_lock(
        self, api_key: str, event_id: str, device_id: str, ttl_seconds: int
    ) -> dict[str, Any] | None:
        now = utcnow()
        key = (api_key, event_id)
        existing = self._event_locks.get(key)
        if existing is None or existing["device_id"] != device_id:
            return None
        if existing["expires_at"] <= now:
            return None
        existing["expires_at"] = now + timedelta(seconds=max(ttl_seconds, 15))
        return existing

    async def release_event_lock(
        self, api_key: str, event_id: str, device_id: str
    ) -> bool:
        key = (api_key, event_id)
        existing = self._event_locks.get(key)
        if existing is None or existing["device_id"] != device_id:
            return False
        del self._event_locks[key]
        return True

    async def list_event_locks(self, api_key: str) -> list[dict[str, Any]]:
        now = utcnow()
        out: list[dict[str, Any]] = []
        for (key_api, event_id), payload in self._event_locks.items():
            if key_api != api_key:
                continue
            expires = payload.get("expires_at")
            if expires is None or expires <= now:
                continue
            out.append(
                {
                    "event_id": event_id,
                    "device_id": payload.get("device_id") or "",
                    "expires_at": expires,
                }
            )
        return out

