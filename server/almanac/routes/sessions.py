from fastapi import APIRouter, Depends, HTTPException

from ..auth import require_api_key
from ..config import settings
from ..db.repository import DatabaseRepository, get_db
from ..models.session import (
    CreateSessionRequest,
    CreateSessionResponse,
    Session,
    SessionState,
)

router = APIRouter(prefix="/v1/sessions", tags=["sessions"])


def _session_to_dict(session: Session) -> dict:
    return session.model_dump(mode="json")


@router.post("", response_model=CreateSessionResponse)
async def create_session(
    body: CreateSessionRequest,
    api_key: str = Depends(require_api_key),
    db: DatabaseRepository = Depends(get_db),
) -> CreateSessionResponse:
    state = SessionState(
        slots=body.slots,
        form_fields=body.form_fields,
        settings=body.settings,
    )
    session = await db.create_session(
        api_key=api_key,
        profile_id=body.profile_id,
        mode=body.mode,
        title=body.title,
        state=state,
    )
    deep_link = f"{settings.public_origin.rstrip('/')}/join/{session.token}"
    return CreateSessionResponse(
        id=session.id,
        token=session.token,
        deep_link=deep_link,
        mode=session.mode,
        title=session.title,
    )


@router.get("")
async def list_sessions(
    api_key: str = Depends(require_api_key),
    db: DatabaseRepository = Depends(get_db),
) -> dict:
    sessions = await db.list_sessions(api_key)
    return {"sessions": [_session_to_dict(session) for session in sessions]}


@router.get("/{token}")
async def get_session(
    token: str,
    db: DatabaseRepository = Depends(get_db),
) -> dict:
    session = await db.get_session_by_token(token)
    if session is None:
        raise HTTPException(status_code=404, detail="Session not found")
    return _session_to_dict(session)


@router.delete("/{token}")
async def delete_session(
    token: str,
    api_key: str = Depends(require_api_key),
    db: DatabaseRepository = Depends(get_db),
) -> dict:
    closed = await db.close_session(token, api_key)
    if not closed:
        raise HTTPException(status_code=404, detail="Session not found")
    return {"ok": True}
