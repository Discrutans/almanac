from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Any

from pydantic import BaseModel, Field


class SessionMode(str, Enum):
    collaborative = "collaborative"
    booking = "booking"


class SessionStatus(str, Enum):
    open = "open"
    closed = "closed"


class BookingRequestStatus(str, Enum):
    pending = "pending"
    confirmed = "confirmed"
    rejected = "rejected"


class FormField(BaseModel):
    id: str
    label: str
    required: bool = True
    kind: str = "text"
    options: list[str] = Field(default_factory=list)


class SessionSlot(BaseModel):
    id: str
    start: datetime
    end: datetime
    label: str | None = None
    color: str | None = None


class SessionState(BaseModel):
    slots: list[SessionSlot] = Field(default_factory=list)
    form_fields: list[FormField] = Field(default_factory=list)
    settings: dict[str, Any] = Field(default_factory=dict)


class SessionClient(BaseModel):
    client_id: str
    display_name: str
    last_seen_at: datetime


class BookingRequest(BaseModel):
    id: str
    session_id: str
    slot_id: str
    fields: dict[str, str]
    status: BookingRequestStatus
    created_at: datetime


class Session(BaseModel):
    id: str
    token: str
    workspace_api_key: str
    profile_id: str
    mode: SessionMode
    title: str
    state: SessionState
    version: int
    status: SessionStatus
    created_at: datetime
    requests: list[BookingRequest] = Field(default_factory=list)


class CreateSessionRequest(BaseModel):
    mode: SessionMode
    title: str
    slots: list[SessionSlot] = Field(default_factory=list)
    form_fields: list[FormField] = Field(default_factory=list)
    settings: dict[str, Any] = Field(default_factory=dict)
    profile_id: str = "default"


class CreateSessionResponse(BaseModel):
    id: str
    token: str
    deep_link: str
    mode: SessionMode
    title: str


class DecideBookingRequest(BaseModel):
    status: BookingRequestStatus


class WorkspaceResponse(BaseModel):
    profile_id: str
    api_key: str
    public_origin: str


class CalendarSnapshotPayload(BaseModel):
    profile_id: str = "default"
    snapshot: dict[str, Any]
    updated_at: datetime | None = None
    merge_profile_ids: list[str] | None = None


class CalendarSnapshotResponse(BaseModel):
    profile_id: str
    snapshot: dict[str, Any] | None
    updated_at: datetime | None


class EventLockRequest(BaseModel):
    event_id: str
    device_id: str
    ttl_seconds: int = 90


class EventLockHeartbeatRequest(BaseModel):
    device_id: str
    ttl_seconds: int = 90


class EventLockResponse(BaseModel):
    acquired: bool
    event_id: str
    device_id: str
    expires_at: datetime | None = None
