from fastapi import Depends, Header, HTTPException



from .db.repository import DatabaseRepository, get_db





async def require_api_key(

    x_api_key: str | None = Header(default=None, alias="X-Api-Key"),

    x_profile_id: str | None = Header(default=None, alias="X-Profile-Id"),

    db: DatabaseRepository = Depends(get_db),

) -> str:

    if not x_api_key:

        raise HTTPException(status_code=401, detail="Missing X-Api-Key header")

    workspace = await db.get_workspace_by_api_key(x_api_key)

    if workspace is None:

        profile_id = x_profile_id or "default"

        await db.ensure_workspace(x_api_key, profile_id)

    return x_api_key

