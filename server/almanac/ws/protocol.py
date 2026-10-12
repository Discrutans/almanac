from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field


class PatchOperation(BaseModel):
    op: str
    slot_id: str | None = None
    slot: dict[str, Any] | None = None


class PatchMessage(BaseModel):
    type: str = "patch"
    base_version: int = Field(alias="baseVersion")
    ops: list[PatchOperation]

    model_config = {"populate_by_name": True}


class BookingRequestMessage(BaseModel):
    type: str = "booking_request"
    slot_id: str = Field(alias="slotId")
    fields: dict[str, str]

    model_config = {"populate_by_name": True}
