from pydantic import BaseModel, Field

from fastapi import APIRouter, Depends

from ..auth import require_api_key
from ..db.repository import DatabaseRepository, get_db

router = APIRouter(prefix="/v1/devices", tags=["devices"])


class RegisterDeviceRequest(BaseModel):
    token: str
    platform: str = Field(default="unknown")


@router.post("/register")
async def register_device(
    body: RegisterDeviceRequest,
    api_key: str = Depends(require_api_key),
    db: DatabaseRepository = Depends(get_db),
) -> dict:
    await db.register_device_token(api_key, body.token, body.platform)
    return {"ok": True}
