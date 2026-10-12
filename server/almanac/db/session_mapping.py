"""Storage-agnostic serialization and model mapping helpers."""

from __future__ import annotations

import json
import uuid
from datetime import datetime, timezone
from enum import Enum
from typing import Any, Mapping, TypeVar

from ..models.session import (
    BookingRequest,
    BookingRequestStatus,
    Session,
    SessionMode,
    SessionState,
    SessionStatus,
)

StatusEnum = TypeVar("StatusEnum", bound=Enum)


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def datetime_to_storage(value: datetime) -> str:
    return value.astimezone(timezone.utc).isoformat()


def datetime_from_storage(value: Any) -> datetime:
    if isinstance(value, datetime):
        return value.astimezone(timezone.utc)
    if isinstance(value, (int, float)):
        return datetime.fromtimestamp(value / 1_000_000, tz=timezone.utc)

    text = str(value).strip()
    if text.isdigit():
        return datetime.fromtimestamp(int(text) / 1_000_000, tz=timezone.utc)
    return datetime.fromisoformat(text.replace("Z", "+00:00"))


def json_encode(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False)


def json_decode(value: Any) -> Any:
    if isinstance(value, (bytes, bytearray)):
        value = value.decode("utf-8")
    return json.loads(value) if isinstance(value, str) else value


def state_to_json(state: SessionState) -> str:
    """Serialize session slots, form fields, and settings for storage."""
    return json_encode(state.model_dump(mode="json"))


def state_from_json(value: Any) -> SessionState:
    return SessionState.model_validate(json_decode(value))


def fields_to_json(fields: Mapping[str, str]) -> str:
    return json_encode(dict(fields))


def fields_from_json(value: Any) -> dict[str, str]:
    fields = json_decode(value)
    return {str(key): str(item) for key, item in fields.items()}


def normalize_status(value: Any, status_type: type[StatusEnum]) -> StatusEnum:
    if isinstance(value, status_type):
        return value
    if isinstance(value, Enum):
        value = value.value
    return status_type(value)


def generate_session_identity() -> tuple[str, str]:
    return str(uuid.uuid4()), uuid.uuid4().hex[:16]


def generate_request_id() -> str:
    return str(uuid.uuid4())


def session_from_row(
    row: Mapping[str, Any],
    requests: list[BookingRequest] | None = None,
) -> Session:
    return Session(
        id=row["id"],
        token=row["token"],
        workspace_api_key=row["workspace_api_key"],
        profile_id=row["profile_id"],
        mode=SessionMode(row["mode"]),
        title=row["title"],
        state=state_from_json(row["state_json"]),
        version=int(row["version"]),
        status=normalize_status(row["status"], SessionStatus),
        created_at=datetime_from_storage(row["created_at"]),
        requests=requests or [],
    )


def session_with_requests(
    session: Session, requests: list[BookingRequest]
) -> Session:
    return session.model_copy(update={"requests": requests})


def booking_request_from_row(row: Mapping[str, Any]) -> BookingRequest:
    return BookingRequest(
        id=row["id"],
        session_id=row["session_id"],
        slot_id=row["slot_id"],
        fields=fields_from_json(row["fields_json"]),
        status=normalize_status(row["status"], BookingRequestStatus),
        created_at=datetime_from_storage(row["created_at"]),
    )
