from __future__ import annotations

import json
import uuid
from typing import Any

from fastapi import APIRouter, Depends, Query, WebSocket, WebSocketDisconnect

from ..booking_capacity import is_slot_full
from ..db.repository import DatabaseRepository, get_db
from ..models.session import Session, SessionMode, SessionSlot, SessionState
from ..notifications.fcm import send_booking_request_push
from ..ws.protocol import BookingRequestMessage, PatchMessage

router = APIRouter(tags=["websocket"])


def _session_payload(session: Session) -> dict[str, Any]:
    return session.model_dump(mode="json")


def _apply_ops(state: SessionState, ops: list[dict[str, Any]]) -> SessionState:
    slots = {slot.id: slot for slot in state.slots}
    for op in ops:
        operation = op.get("op")
        if operation == "addSlot" and op.get("slot"):
            slot = SessionSlot.model_validate(op["slot"])
            slots[slot.id] = slot
        elif operation == "updateSlot" and op.get("slot"):
            slot = SessionSlot.model_validate(op["slot"])
            slots[slot.id] = slot
        elif operation == "removeSlot" and op.get("slot_id"):
            slots.pop(op["slot_id"], None)
        elif operation == "setSlots" and isinstance(op.get("slots"), list):
            slots = {
                slot.id: slot
                for slot in (
                    SessionSlot.model_validate(item) for item in op["slots"]
                )
            }
    return SessionState(
        slots=list(slots.values()),
        form_fields=state.form_fields,
        settings=dict(state.settings),
    )


class SessionHub:
    def __init__(self) -> None:
        self._rooms: dict[str, set[WebSocket]] = {}

    async def connect(
        self,
        token: str,
        websocket: WebSocket,
        *,
        client_id: str,
        display_name: str,
        db: DatabaseRepository,
    ) -> Session | None:
        await websocket.accept()
        session = await db.get_session_by_token(token)
        if session is None:
            await websocket.send_json({"type": "error", "message": "Session not found"})
            await websocket.close(code=4404)
            return None

        self._rooms.setdefault(token, set()).add(websocket)
        await db.upsert_session_client(session.id, client_id, display_name)
        clients = await db.list_session_clients(session.id)
        await websocket.send_json(
            {
                "type": "state",
                "version": session.version,
                "session": _session_payload(session),
                "clients": [client.model_dump(mode="json") for client in clients],
            }
        )
        await self.broadcast(
            token,
            {
                "type": "presence",
                "clients": [client.model_dump(mode="json") for client in clients],
            },
            exclude=websocket,
        )
        return session

    async def disconnect(
        self,
        token: str,
        websocket: WebSocket,
        *,
        client_id: str,
        db: DatabaseRepository,
        session_id: str | None,
    ) -> None:
        room = self._rooms.get(token)
        if room is not None:
            room.discard(websocket)
            if not room:
                self._rooms.pop(token, None)
        if session_id is not None:
            await db.remove_session_client(session_id, client_id)
            clients = await db.list_session_clients(session_id)
            await self.broadcast(
                token,
                {
                    "type": "presence",
                    "clients": [client.model_dump(mode="json") for client in clients],
                },
            )

    async def broadcast(
        self,
        token: str,
        message: dict[str, Any],
        *,
        exclude: WebSocket | None = None,
    ) -> None:
        room = self._rooms.get(token, set())
        dead: list[WebSocket] = []
        for connection in room:
            if connection is exclude:
                continue
            try:
                await connection.send_json(message)
            except Exception:
                dead.append(connection)
        for connection in dead:
            room.discard(connection)

    async def handle_message(
        self,
        *,
        token: str,
        websocket: WebSocket,
        session: Session,
        raw: str,
        db: DatabaseRepository,
        api_key: str | None = None,
        client_id: str | None = None,
    ) -> None:
        payload = json.loads(raw)
        message_type = payload.get("type")

        if message_type == "patch":
            state = session.state
            if session.mode == SessionMode.collaborative:
                settings = dict(state.settings or {})
                max_editors = max(1, int(settings.get("max_editors", 1)))
                editors = list(settings.get("editors") or [])
                is_owner = bool(api_key and api_key == session.workspace_api_key)
                if not is_owner:
                    if not client_id:
                        await websocket.send_json(
                            {
                                "type": "error",
                                "message": "Missing client id",
                            }
                        )
                        return
                    if client_id not in editors:
                        if len(editors) >= max_editors:
                            await websocket.send_json(
                                {
                                    "type": "error",
                                    "message": "Editor limit reached",
                                }
                            )
                            return
                        editors.append(client_id)
                        settings["editors"] = editors
                        state = SessionState(
                            slots=list(state.slots),
                            form_fields=list(state.form_fields),
                            settings=settings,
                        )
            message = PatchMessage.model_validate(payload)
            updated = await db.update_session_state(
                session.id,
                _apply_ops(state, [op.model_dump() for op in message.ops]),
                message.base_version,
            )
            if updated is None:
                fresh = await db.get_session_by_token(token)
                if fresh is not None:
                    await websocket.send_json(
                        {
                            "type": "state",
                            "version": fresh.version,
                            "session": _session_payload(fresh),
                            "clients": [
                                client.model_dump(mode="json")
                                for client in await db.list_session_clients(fresh.id)
                            ],
                        }
                    )
                return

            await self.broadcast(
                token,
                {
                    "type": "patch_applied",
                    "version": updated.version,
                    "ops": [op.model_dump() for op in message.ops],
                    "session": _session_payload(updated),
                },
            )
            return

        if message_type == "booking_request":
            message = BookingRequestMessage.model_validate(payload)
            slot_ids = {slot.id for slot in session.state.slots}
            if message.slot_id not in slot_ids:
                await websocket.send_json(
                    {"type": "error", "message": "Slot not found"}
                )
                return
            requests = await db.list_booking_requests(session.id)
            if is_slot_full(session, requests, message.slot_id):
                await websocket.send_json(
                    {
                        "type": "error",
                        "message": "Это время уже занято. Выберите другой слот.",
                    }
                )
                return
            request = await db.create_booking_request(
                session_id=session.id,
                slot_id=message.slot_id,
                fields=message.fields,
            )
            fresh = await db.get_session_by_token(token)
            await self.broadcast(
                token,
                {
                    "type": "booking_request_created",
                    "request": request.model_dump(mode="json"),
                    "session": _session_payload(fresh) if fresh else None,
                },
            )
            tokens = await db.list_device_tokens(session.workspace_api_key)
            await send_booking_request_push(
                device_tokens=tokens,
                session_title=session.title,
                request_id=request.id,
            )
            return

        await websocket.send_json(
            {"type": "error", "message": f"Unknown message type: {message_type}"}
        )


session_hub = SessionHub()


@router.websocket("/v1/ws/sessions/{token}")
async def session_websocket(
    websocket: WebSocket,
    token: str,
    client_id: str | None = Query(default=None),
    name: str | None = Query(default=None),
    api_key: str | None = Query(default=None, alias="apiKey"),
    db: DatabaseRepository = Depends(get_db),
) -> None:
    resolved_client_id = client_id or str(uuid.uuid4())
    display_name = name or "Guest"
    session = await session_hub.connect(
        token,
        websocket,
        client_id=resolved_client_id,
        display_name=display_name,
        db=db,
    )
    if session is None:
        return

    try:
        while True:
            raw = await websocket.receive_text()
            await session_hub.handle_message(
                token=token,
                websocket=websocket,
                session=session,
                raw=raw,
                db=db,
                api_key=api_key,
                client_id=resolved_client_id,
            )
            session = await db.get_session_by_token(token)
            if session is None:
                break
    except WebSocketDisconnect:
        pass
    finally:
        await session_hub.disconnect(
            token,
            websocket,
            client_id=resolved_client_id,
            db=db,
            session_id=session.id if session else None,
        )
