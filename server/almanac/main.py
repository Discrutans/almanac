from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles

from .config import settings
from .db.repository import close_db, init_db
from .routes.booking import router as booking_router
from .routes.calendar import router as calendar_router
from .routes.devices import router as devices_router
from .routes.lab import router as lab_router
from .routes.sessions import router as sessions_router
from .routes.workspace import router as workspace_router
from .ws.hub import router as ws_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield
    await close_db()


app = FastAPI(title="Almanac Platform API", version="2.0.0", lifespan=lifespan)

origins = [origin.strip() for origin in settings.cors_origins.split(",") if origin.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins if origins != ["*"] else ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(workspace_router)
app.include_router(sessions_router)
app.include_router(booking_router)
app.include_router(calendar_router)
app.include_router(devices_router)
app.include_router(lab_router)
app.include_router(ws_router)

landing_dir = Path(__file__).resolve().parents[1] / "landing"
if landing_dir.exists():
    app.mount("/static", StaticFiles(directory=landing_dir), name="static")


@app.get("/")
async def root() -> dict[str, str]:
    return {"status": "ok", "health": "/health", "api": "/v1/workspace"}


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/join/{token}")
async def join_landing(token: str):
    index_path = landing_dir / "index.html"
    if index_path.exists():
        return FileResponse(index_path)
    return HTMLResponse(
        f"""
        <!DOCTYPE html>
        <html lang="ru">
          <head><meta charset="utf-8"><title>Almanac</title></head>
          <body>
            <h1>Almanac session</h1>
            <p>Token: {token}</p>
            <p><a href="almanac://join/{token}">Open in Almanac app</a></p>
          </body>
        </html>
        """
    )


@app.get("/.well-known/apple-app-site-association")
async def apple_app_site_association() -> dict:
    app_id = f"{settings.ios_team_id}.{settings.ios_bundle_id}"
    return {
        "applinks": {
            "apps": [],
            "details": [
                {
                    "appID": app_id,
                    "paths": ["/join/*", "/book/*", "/plan/*"],
                }
            ],
        }
    }


@app.get("/.well-known/assetlinks.json")
async def android_asset_links() -> list[dict]:
    if not settings.android_sha256_cert:
        return []
    return [
        {
            "relation": ["delegate_permission/common.handle_all_urls"],
            "target": {
                "namespace": "android_app",
                "package_name": settings.android_package,
                "sha256_cert_fingerprints": [
                    fingerprint.strip()
                    for fingerprint in settings.android_sha256_cert.split(",")
                    if fingerprint.strip()
                ],
            },
        }
    ]
