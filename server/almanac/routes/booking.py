from fastapi import APIRouter, Depends, HTTPException

from ..auth import require_api_key
from ..booking_capacity import is_slot_full
from ..db.repository import DatabaseRepository, get_db
from ..models.session import BookingRequestStatus, DecideBookingRequest
from ..ws.hub import session_hub

router = APIRouter(prefix="/v1/sessions", tags=["booking"])


@router.patch("/{token}/requests/{request_id}")
async def decide_booking_request(
    token: str,
    request_id: str,
    body: DecideBookingRequest,
    api_key: str = Depends(require_api_key),
    db: DatabaseRepository = Depends(get_db),
) -> dict:
    if body.status not in (
        BookingRequestStatus.confirmed,
        BookingRequestStatus.rejected,
    ):
        raise HTTPException(status_code=400, detail="Status must be confirmed or rejected")

    session = await db.get_session_by_token(token)
    if session is None or session.workspace_api_key != api_key:
        raise HTTPException(status_code=404, detail="Session not found")

    request = await db.get_booking_request(request_id)
    if request is None or request.session_id != session.id:
        raise HTTPException(status_code=404, detail="Request not found")

    if body.status == BookingRequestStatus.confirmed:
        requests = await db.list_booking_requests(session.id)
        if is_slot_full(
            session,
            requests,
            request.slot_id,
            exclude_request_id=request_id,
        ):
            raise HTTPException(
                status_code=409,
                detail="Slot is full — cannot confirm this request",
            )

    updated = await db.update_booking_request_status(request_id, body.status)
    if updated is None:
        raise HTTPException(status_code=404, detail="Request not found")

    fresh = await db.get_session_by_token(token)
    await session_hub.broadcast(
        token,
        {
            "type": "booking_request_decided",
            "requestId": updated.id,
            "status": updated.status.value,
            "request": updated.model_dump(mode="json"),
            "session": fresh.model_dump(mode="json") if fresh else None,
        },
    )
    return updated.model_dump(mode="json")
