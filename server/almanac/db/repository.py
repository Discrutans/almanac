from __future__ import annotations

from abc import ABC, abstractmethod
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

import aiosqlite

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
from .session_mapping import (
    booking_request_from_row,
    datetime_from_storage,
    datetime_to_storage,
    fields_to_json,
    generate_request_id,
    generate_session_identity,
    json_decode,
    json_encode,
    session_from_row,
    state_to_json,
    utcnow,
)

_db: DatabaseRepository | None = None


class DatabaseRepository(ABC):
    @abstractmethod
    async def init(self) -> None: ...

    @abstractmethod
    async def close(self) -> None: ...

    @abstractmethod
    async def ensure_workspace(
        self, api_key: str, profile_id: str, name: str = ""
    ) -> dict[str, Any]: ...

    @abstractmethod
    async def get_workspace_by_api_key(self, api_key: str) -> dict[str, Any] | None: ...

    @abstractmethod
    async def create_session(
        self,
        *,
        api_key: str,
        profile_id: str,
        mode: SessionMode,
        title: str,
        state: SessionState,
    ) -> Session: ...

    @abstractmethod
    async def list_sessions(self, api_key: str) -> list[Session]: ...

    @abstractmethod
    async def get_session_by_token(self, token: str) -> Session | None: ...

    @abstractmethod
    async def get_session_by_id(self, session_id: str) -> Session | None: ...

    @abstractmethod
    async def update_session_state(
        self, session_id: str, state: SessionState, expected_version: int
    ) -> Session | None: ...

    @abstractmethod
    async def close_session(self, token: str, api_key: str) -> bool: ...

    @abstractmethod
    async def upsert_session_client(
        self, session_id: str, client_id: str, display_name: str
    ) -> SessionClient: ...

    @abstractmethod
    async def remove_session_client(self, session_id: str, client_id: str) -> None: ...

    @abstractmethod
    async def list_session_clients(self, session_id: str) -> list[SessionClient]: ...

    @abstractmethod
    async def create_booking_request(
        self,
        *,
        session_id: str,
        slot_id: str,
        fields: dict[str, str],
    ) -> BookingRequest: ...

    @abstractmethod
    async def get_booking_request(self, request_id: str) -> BookingRequest | None: ...

    @abstractmethod
    async def update_booking_request_status(
        self, request_id: str, status: BookingRequestStatus
    ) -> BookingRequest | None: ...

    @abstractmethod
    async def list_booking_requests(self, session_id: str) -> list[BookingRequest]: ...

    @abstractmethod
    async def get_calendar_snapshot(
        self, api_key: str, profile_id: str
    ) -> dict[str, Any] | None: ...

    async def list_calendar_snapshots(self, api_key: str) -> list[dict[str, Any]]: ...

    @abstractmethod
    async def upsert_calendar_snapshot(
        self, api_key: str, profile_id: str, snapshot: dict[str, Any]
    ) -> datetime: ...

    @abstractmethod
    async def register_device_token(
        self, api_key: str, token: str, platform: str
    ) -> None: ...

    @abstractmethod
    async def list_device_tokens(self, api_key: str) -> list[str]: ...

    @abstractmethod
    async def list_event_locks(self, api_key: str) -> list[dict[str, Any]]: ...

    @abstractmethod
    async def acquire_event_lock(
        self, api_key: str, event_id: str, device_id: str, ttl_seconds: int
    ) -> dict[str, Any]: ...

    @abstractmethod
    async def heartbeat_event_lock(
        self, api_key: str, event_id: str, device_id: str, ttl_seconds: int
    ) -> dict[str, Any] | None: ...

    @abstractmethod
    async def release_event_lock(
        self, api_key: str, event_id: str, device_id: str
    ) -> bool: ...


class SQLiteRepository(DatabaseRepository):
    def __init__(self, path: str) -> None:
        self._path = path
        self._conn: aiosqlite.Connection | None = None

    async def init(self) -> None:
        Path(self._path).parent.mkdir(parents=True, exist_ok=True)
        self._conn = await aiosqlite.connect(self._path)
        self._conn.row_factory = aiosqlite.Row
        schema_path = Path(__file__).with_name("schema.sql")
        await self._conn.executescript(schema_path.read_text(encoding="utf-8"))
        await self._conn.commit()

    async def close(self) -> None:
        if self._conn is not None:
            await self._conn.close()
            self._conn = None

    def _connection(self) -> aiosqlite.Connection:
        if self._conn is None:
            raise RuntimeError("Database not initialized")
        return self._conn

    async def _load_requests(self, session_id: str) -> list[BookingRequest]:
        cursor = await self._connection().execute(
            """
            SELECT id, session_id, slot_id, fields_json, status, created_at
            FROM booking_requests
            WHERE session_id = ?
            ORDER BY created_at ASC
            """,
            (session_id,),
        )
        rows = await cursor.fetchall()
        return [booking_request_from_row(row) for row in rows]

    async def _session_with_requests(self, row: aiosqlite.Row) -> Session:
        requests = await self._load_requests(row["id"])
        return session_from_row(row, requests)

    async def ensure_workspace(
        self, api_key: str, profile_id: str, name: str = ""
    ) -> dict[str, Any]:
        existing = await self.get_workspace_by_api_key(api_key)
        if existing is not None:
            return existing
        created_at = utcnow()
        await self._connection().execute(
            """
            INSERT OR IGNORE INTO workspaces (api_key, profile_id, name, created_at)
            VALUES (?, ?, ?, ?)
            """,
            (api_key, profile_id, name, datetime_to_storage(created_at)),
        )
        await self._connection().commit()
        created = await self.get_workspace_by_api_key(api_key)
        if created is not None:
            return created
        return {
            "api_key": api_key,
            "profile_id": profile_id,
            "name": name,
            "created_at": created_at,
        }

    async def get_workspace_by_api_key(self, api_key: str) -> dict[str, Any] | None:
        cursor = await self._connection().execute(
            "SELECT api_key, profile_id, name, created_at FROM workspaces WHERE api_key = ?",
            (api_key,),
        )
        row = await cursor.fetchone()
        if row is None:
            return None
        return {
            "api_key": row["api_key"],
            "profile_id": row["profile_id"],
            "name": row["name"],
            "created_at": datetime_from_storage(row["created_at"]),
        }

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
        await self._connection().execute(
            """
            INSERT INTO sessions (
              id, token, workspace_api_key, profile_id, mode, title,
              state_json, version, status, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                session_id,
                token,
                api_key,
                profile_id,
                mode.value,
                title,
                state_to_json(state),
                1,
                SessionStatus.open.value,
                datetime_to_storage(created_at),
            ),
        )
        await self._connection().commit()
        session = await self.get_session_by_token(token)
        assert session is not None
        return session

    async def list_sessions(self, api_key: str) -> list[Session]:
        cursor = await self._connection().execute(
            """
            SELECT id, token, workspace_api_key, profile_id, mode, title,
                   state_json, version, status, created_at
            FROM sessions
            WHERE workspace_api_key = ?
            ORDER BY created_at DESC
            """,
            (api_key,),
        )
        rows = await cursor.fetchall()
        return [await self._session_with_requests(row) for row in rows]

    async def get_session_by_token(self, token: str) -> Session | None:
        cursor = await self._connection().execute(
            """
            SELECT id, token, workspace_api_key, profile_id, mode, title,
                   state_json, version, status, created_at
            FROM sessions
            WHERE token = ?
            """,
            (token,),
        )
        row = await cursor.fetchone()
        if row is None:
            return None
        return await self._session_with_requests(row)

    async def get_session_by_id(self, session_id: str) -> Session | None:
        cursor = await self._connection().execute(
            """
            SELECT id, token, workspace_api_key, profile_id, mode, title,
                   state_json, version, status, created_at
            FROM sessions
            WHERE id = ?
            """,
            (session_id,),
        )
        row = await cursor.fetchone()
        if row is None:
            return None
        return await self._session_with_requests(row)

    async def update_session_state(
        self, session_id: str, state: SessionState, expected_version: int
    ) -> Session | None:
        cursor = await self._connection().execute(
            """
            UPDATE sessions
            SET state_json = ?, version = version + 1
            WHERE id = ? AND version = ?
            """,
            (state_to_json(state), session_id, expected_version),
        )
        await self._connection().commit()
        if cursor.rowcount == 0:
            return None
        return await self.get_session_by_id(session_id)

    async def close_session(self, token: str, api_key: str) -> bool:
        cursor = await self._connection().execute(
            """
            UPDATE sessions
            SET status = ?
            WHERE token = ? AND workspace_api_key = ?
            """,
            (SessionStatus.closed.value, token, api_key),
        )
        await self._connection().commit()
        return cursor.rowcount > 0

    async def upsert_session_client(
        self, session_id: str, client_id: str, display_name: str
    ) -> SessionClient:
        now = utcnow()
        await self._connection().execute(
            """
            INSERT INTO session_clients (session_id, client_id, display_name, last_seen_at)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(session_id, client_id) DO UPDATE SET
              display_name = excluded.display_name,
              last_seen_at = excluded.last_seen_at
            """,
            (session_id, client_id, display_name, datetime_to_storage(now)),
        )
        await self._connection().commit()
        return SessionClient(
            client_id=client_id,
            display_name=display_name,
            last_seen_at=now,
        )

    async def remove_session_client(self, session_id: str, client_id: str) -> None:
        await self._connection().execute(
            "DELETE FROM session_clients WHERE session_id = ? AND client_id = ?",
            (session_id, client_id),
        )
        await self._connection().commit()

    async def list_session_clients(self, session_id: str) -> list[SessionClient]:
        cursor = await self._connection().execute(
            """
            SELECT client_id, display_name, last_seen_at
            FROM session_clients
            WHERE session_id = ?
            ORDER BY last_seen_at DESC
            """,
            (session_id,),
        )
        rows = await cursor.fetchall()
        return [
            SessionClient(
                client_id=row["client_id"],
                display_name=row["display_name"],
                last_seen_at=datetime_from_storage(row["last_seen_at"]),
            )
            for row in rows
        ]

    async def create_booking_request(
        self,
        *,
        session_id: str,
        slot_id: str,
        fields: dict[str, str],
    ) -> BookingRequest:
        request_id = generate_request_id()
        created_at = utcnow()
        await self._connection().execute(
            """
            INSERT INTO booking_requests (id, session_id, slot_id, fields_json, status, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (
                request_id,
                session_id,
                slot_id,
                fields_to_json(fields),
                BookingRequestStatus.pending.value,
                datetime_to_storage(created_at),
            ),
        )
        await self._connection().commit()
        request = await self.get_booking_request(request_id)
        assert request is not None
        return request

    async def get_booking_request(self, request_id: str) -> BookingRequest | None:
        cursor = await self._connection().execute(
            """
            SELECT id, session_id, slot_id, fields_json, status, created_at
            FROM booking_requests
            WHERE id = ?
            """,
            (request_id,),
        )
        row = await cursor.fetchone()
        if row is None:
            return None
        return booking_request_from_row(row)

    async def update_booking_request_status(
        self, request_id: str, status: BookingRequestStatus
    ) -> BookingRequest | None:
        await self._connection().execute(
            "UPDATE booking_requests SET status = ? WHERE id = ?",
            (status.value, request_id),
        )
        await self._connection().commit()
        return await self.get_booking_request(request_id)

    async def list_booking_requests(self, session_id: str) -> list[BookingRequest]:
        return await self._load_requests(session_id)

    async def get_calendar_snapshot(
        self, api_key: str, profile_id: str
    ) -> dict[str, Any] | None:
        cursor = await self._connection().execute(
            """
            SELECT snapshot_json, updated_at
            FROM calendar_snapshots
            WHERE api_key = ? AND profile_id = ?
            """,
            (api_key, profile_id),
        )
        row = await cursor.fetchone()
        if row is None:
            return None
        return {
            "snapshot": json_decode(row["snapshot_json"]),
            "updated_at": datetime_from_storage(row["updated_at"]),
        }

    async def list_calendar_snapshots(self, api_key: str) -> list[dict[str, Any]]:
        cursor = await self._connection().execute(
            """
            SELECT profile_id, snapshot_json, updated_at
            FROM calendar_snapshots
            WHERE api_key = ?
            """,
            (api_key,),
        )
        rows = await cursor.fetchall()
        return [
            {
                "profile_id": row["profile_id"],
                "snapshot": json_decode(row["snapshot_json"]),
                "updated_at": datetime_from_storage(row["updated_at"]),
            }
            for row in rows
        ]

    async def upsert_calendar_snapshot(
        self, api_key: str, profile_id: str, snapshot: dict[str, Any]
    ) -> datetime:
        await self.ensure_workspace(api_key, profile_id)
        updated_at = utcnow()
        await self._connection().execute(
            """
            INSERT INTO calendar_snapshots (api_key, profile_id, snapshot_json, updated_at)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(api_key, profile_id) DO UPDATE SET
              snapshot_json = excluded.snapshot_json,
              updated_at = excluded.updated_at
            """,
            (
                api_key,
                profile_id,
                json_encode(snapshot),
                datetime_to_storage(updated_at),
            ),
        )
        await self._connection().commit()
        return updated_at

    async def register_device_token(
        self, api_key: str, token: str, platform: str
    ) -> None:
        await self.ensure_workspace(api_key, "default")
        created_at = utcnow()
        await self._connection().execute(
            """
            INSERT INTO device_tokens (api_key, token, platform, created_at)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(api_key, token) DO UPDATE SET
              platform = excluded.platform,
              created_at = excluded.created_at
            """,
            (api_key, token, platform, datetime_to_storage(created_at)),
        )
        await self._connection().commit()

    async def list_device_tokens(self, api_key: str) -> list[str]:
        cursor = await self._connection().execute(
            "SELECT token FROM device_tokens WHERE api_key = ?",
            (api_key,),
        )
        rows = await cursor.fetchall()
        return [row["token"] for row in rows]

    async def acquire_event_lock(
        self, api_key: str, event_id: str, device_id: str, ttl_seconds: int
    ) -> dict[str, Any]:
        await self.ensure_workspace(api_key, "default")
        now = utcnow()
        expires = now + timedelta(seconds=max(ttl_seconds, 15))
        cursor = await self._connection().execute(
            """
            SELECT device_id, expires_at FROM event_locks
            WHERE api_key = ? AND event_id = ?
            """,
            (api_key, event_id),
        )
        row = await cursor.fetchone()
        if row is not None:
            current_expires = datetime_from_storage(row["expires_at"])
            if current_expires > now and row["device_id"] != device_id:
                return {
                    "acquired": False,
                    "event_id": event_id,
                    "device_id": row["device_id"],
                    "expires_at": current_expires,
                }
        await self._connection().execute(
            """
            INSERT INTO event_locks (api_key, event_id, device_id, expires_at)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(api_key, event_id) DO UPDATE SET
              device_id = excluded.device_id,
              expires_at = excluded.expires_at
            """,
            (api_key, event_id, device_id, datetime_to_storage(expires)),
        )
        await self._connection().commit()
        return {
            "acquired": True,
            "event_id": event_id,
            "device_id": device_id,
            "expires_at": expires,
        }

    async def heartbeat_event_lock(
        self, api_key: str, event_id: str, device_id: str, ttl_seconds: int
    ) -> dict[str, Any] | None:
        now = utcnow()
        cursor = await self._connection().execute(
            """
            SELECT device_id, expires_at FROM event_locks
            WHERE api_key = ? AND event_id = ?
            """,
            (api_key, event_id),
        )
        row = await cursor.fetchone()
        if row is None or row["device_id"] != device_id:
            return None
        if datetime_from_storage(row["expires_at"]) <= now:
            return None
        expires = now + timedelta(seconds=max(ttl_seconds, 15))
        await self._connection().execute(
            """
            UPDATE event_locks SET expires_at = ?
            WHERE api_key = ? AND event_id = ? AND device_id = ?
            """,
            (datetime_to_storage(expires), api_key, event_id, device_id),
        )
        await self._connection().commit()
        return {
            "acquired": True,
            "event_id": event_id,
            "device_id": device_id,
            "expires_at": expires,
        }

    async def release_event_lock(
        self, api_key: str, event_id: str, device_id: str
    ) -> bool:
        cursor = await self._connection().execute(
            """
            DELETE FROM event_locks
            WHERE api_key = ? AND event_id = ? AND device_id = ?
            """,
            (api_key, event_id, device_id),
        )
        await self._connection().commit()
        return cursor.rowcount > 0

    async def list_event_locks(self, api_key: str) -> list[dict[str, Any]]:
        now = utcnow()
        cursor = await self._connection().execute(
            """
            SELECT event_id, device_id, expires_at FROM event_locks
            WHERE api_key = ? AND expires_at > ?
            """,
            (api_key, datetime_to_storage(now)),
        )
        rows = await cursor.fetchall()
        return [
            {
                "event_id": row["event_id"],
                "device_id": row["device_id"],
                "expires_at": datetime_from_storage(row["expires_at"]),
            }
            for row in rows
        ]


def create_db() -> DatabaseRepository:
    if settings.db_backend == "ydb":
        from .ydb_repository import YdbRepository

        return YdbRepository()
    return SQLiteRepository(settings.sqlite_path)


def get_db() -> DatabaseRepository:
    global _db
    if _db is None:
        _db = create_db()
    return _db


async def init_db() -> DatabaseRepository:
    db = get_db()
    await db.init()
    return db


async def close_db() -> None:
    global _db
    if _db is not None:
        await _db.close()
        _db = None
