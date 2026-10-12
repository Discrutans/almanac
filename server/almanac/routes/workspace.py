from fastapi import APIRouter, Depends, Header, HTTPException

from ..auth import require_api_key
from ..config import settings
from ..db.repository import DatabaseRepository, get_db
from ..models.session import WorkspaceResponse

router = APIRouter(prefix="/v1", tags=["workspace"])


@router.get("/workspace", response_model=WorkspaceResponse)
async def get_workspace(
    api_key: str = Depends(require_api_key),
    x_profile_id: str | None = Header(default=None, alias="X-Profile-Id"),
    db: DatabaseRepository = Depends(get_db),
) -> WorkspaceResponse:
    profile_id = x_profile_id or "default"
    await db.ensure_workspace(api_key, profile_id)
    return WorkspaceResponse(
        profile_id=profile_id,
        api_key=api_key,
        public_origin=settings.public_origin,
    )
