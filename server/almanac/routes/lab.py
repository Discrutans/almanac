"""Local home-lab helper: WireGuard scripts + connection tests."""

from __future__ import annotations

import json
import socket
import uuid
from datetime import datetime, timedelta
from ipaddress import ip_address
from pathlib import Path
from typing import Any
from urllib.parse import quote

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import FileResponse, PlainTextResponse
from pydantic import BaseModel, Field

from ..config import settings
from ..db.repository import DatabaseRepository, get_db
from ..models.session import Session, SessionMode, SessionSlot, SessionState
from ..lab_wg import (
    WireGuardBundle,
    build_mikrotik_script,
    build_pc_conf,
    build_phone_conf,
    generate_keypair,
    public_key_from_private,
    wg_host_ips,
)

router = APIRouter(tags=["home-lab"])
landing_dir = Path(__file__).resolve().parents[2] / "landing"


class LabConfigIn(BaseModel):
    endpoint: str = ""
    wg_port: int = Field(default=13231, ge=1, le=65535)
    wg_network: str = "10.13.13.0/24"
    lan_cidr: str = "192.168.10.0/24,192.168.20.0/24,192.168.30.0/24"
    pc_lan_ip: str = ""
    phone_name: str = "almanac-phone"
    api_key: str = ""
    reuse_server_keys: bool = True
    generate_pc_peer: bool = False


class LabSessionIn(BaseModel):
    api_key: str = ""
    profile_id: str = "default"
    title: str = "Тест планирования"
    mode: SessionMode = SessionMode.collaborative
    max_editors: int = Field(default=3, ge=1, le=20)
    slot_count: int = Field(default=3, ge=0, le=24)
    slot_minutes: int = Field(default=60, ge=15, le=240)


def _require_home_lab() -> None:
    if not settings.home_lab:
        raise HTTPException(status_code=404, detail="Home lab is disabled")


def _require_private_client(request: Request) -> None:
    host = request.client.host if request.client else ""
    try:
        parsed = ip_address(host)
    except ValueError as exc:
        raise HTTPException(status_code=403, detail="Home lab is only for local network") from exc
    if not (parsed.is_private or parsed.is_loopback):
        raise HTTPException(status_code=403, detail="Home lab is only for local network")


def _config_path() -> Path:
    return Path(settings.sqlite_path).expanduser().resolve().parent / "home_lab.json"


def _load_saved() -> dict[str, Any]:
    path = _config_path()
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


def _save(data: dict[str, Any]) -> None:
    path = _config_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def _ip_rank(ip: str) -> int:
    if ip.startswith("192.168."):
        return 0
    if ip.startswith("10."):
        return 1
    if ip.startswith(("172.17.", "172.18.", "172.19.")):
        return 9
    return 2


def _lan_ips() -> list[str]:
    found: list[str] = []
    try:
        probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        probe.connect(("8.8.8.8", 80))
        primary = probe.getsockname()[0]
        probe.close()
        if not primary.startswith("127."):
            found.append(primary)
    except OSError:
        pass
    hostname = socket.gethostname()
    try:
        for info in socket.getaddrinfo(hostname, None, socket.AF_INET):
            ip = info[4][0]
            if ip not in found and not ip.startswith("127."):
                found.append(ip)
    except OSError:
        pass
    return sorted(found, key=_ip_rank)


def _origin(request: Request) -> str:
    public = (settings.public_origin or "").rstrip("/")
    if public:
        return public
    return str(request.base_url).rstrip("/")


def _resolve_api_key(body_key: str) -> str:
    saved = _load_saved()
    key = (body_key or "").strip() or str(saved.get("api_key") or "").strip()
    if not key:
        key = str(uuid.uuid4())
        saved["api_key"] = key
        _save(saved)
    elif saved.get("api_key") != key:
        saved["api_key"] = key
        _save(saved)
    return key


def _demo_slots(count: int, minutes: int) -> list[SessionSlot]:
    start = datetime.now().replace(minute=0, second=0, microsecond=0) + timedelta(
        hours=1
    )
    slots: list[SessionSlot] = []
    for index in range(count):
        begin = start + timedelta(minutes=minutes * index)
        slots.append(
            SessionSlot(
                id=str(uuid.uuid4()),
                start=begin,
                end=begin + timedelta(minutes=minutes),
                label=begin.strftime("%H:%M"),
            )
        )
    return slots


def _public_session(session: Session, origin: str) -> dict[str, Any]:
    data = session.model_dump(mode="json")
    data.pop("workspace_api_key", None)
    data["deep_link"] = f"{origin}/join/{session.token}"
    data["app_link"] = (
        f"almanac://join/{session.token}?server={quote(origin, safe='')}"
    )
    data["lab_url"] = f"{origin}/lab/plan?token={session.token}"
    return data


def _bundle_from_saved(saved: dict[str, Any], body: LabConfigIn | None = None) -> WireGuardBundle:
    data = {**saved}
    if body is not None:
        data.update(body.model_dump())
    return WireGuardBundle(
        endpoint=str(data.get("endpoint") or ""),
        wg_port=int(data.get("wg_port") or 13231),
        wg_network=str(data.get("wg_network") or "10.13.13.0/24"),
        lan_cidr=str(data.get("lan_cidr") or "192.168.10.0/24,192.168.20.0/24,192.168.30.0/24"),
        pc_lan_ip=str(data.get("pc_lan_ip") or ""),
        phone_name=str(data.get("phone_name") or "almanac-phone"),
        mikrotik_private_key=str(data.get("mikrotik_private_key") or ""),
        mikrotik_public_key=str(data.get("mikrotik_public_key") or ""),
        phone_private_key=str(data.get("phone_private_key") or ""),
        phone_public_key=str(data.get("phone_public_key") or ""),
        pc_private_key=str(data.get("pc_private_key") or ""),
        pc_public_key=str(data.get("pc_public_key") or ""),
        generate_pc_peer=bool(data.get("generate_pc_peer")),
    )


@router.get("/lab")
async def lab_page(request: Request):
    _require_home_lab()
    _require_private_client(request)
    index_path = landing_dir / "lab.html"
    if not index_path.exists():
        raise HTTPException(status_code=404, detail="lab.html is missing")
    return FileResponse(index_path)


@router.get("/lab/plan")
async def lab_plan_page(request: Request):
    _require_home_lab()
    _require_private_client(request)
    index_path = landing_dir / "lab_plan.html"
    if not index_path.exists():
        raise HTTPException(status_code=404, detail="lab_plan.html is missing")
    return FileResponse(index_path)


@router.get("/v1/lab/status")
async def lab_status(request: Request) -> dict[str, Any]:
    _require_home_lab()
    _require_private_client(request)
    saved = _load_saved()
    lan_ips = _lan_ips()
    pc_ip = str(saved.get("pc_lan_ip") or (lan_ips[0] if lan_ips else ""))
    server_url = f"http://{pc_ip}:8080" if pc_ip else settings.public_origin
    bundle = _bundle_from_saved(saved)
    ready = bool(bundle.mikrotik_public_key and bundle.phone_private_key)
    return {
        "enabled": True,
        "lan_ips": lan_ips,
        "pc_lan_ip": pc_ip,
        "server_url": server_url,
        "public_origin": settings.public_origin,
        "health": "/health",
        "config": {
            "endpoint": bundle.endpoint,
            "wg_port": bundle.wg_port,
            "wg_network": bundle.wg_network,
            "lan_cidr": bundle.lan_cidr,
            "pc_lan_ip": pc_ip,
            "phone_name": bundle.phone_name,
            "api_key": saved.get("api_key") or "",
            "generate_pc_peer": bundle.generate_pc_peer,
            "mikrotik_public_key": bundle.mikrotik_public_key,
            "phone_public_key": bundle.phone_public_key,
        },
        "ready": ready,
        "mikrotik_script": build_mikrotik_script(bundle) if ready else "",
        "phone_conf": build_phone_conf(bundle) if ready else "",
        "pc_conf": build_pc_conf(bundle) if ready and bundle.generate_pc_peer else "",
        "router_ip": wg_host_ips(bundle.wg_network)[0],
        "phone_ip": wg_host_ips(bundle.wg_network)[1],
    }


@router.post("/v1/lab/generate")
async def lab_generate(body: LabConfigIn, request: Request) -> dict[str, Any]:
    _require_home_lab()
    _require_private_client(request)
    saved = _load_saved()
    reuse = body.reuse_server_keys and saved.get("mikrotik_private_key")
    if reuse:
        mikrotik_private = str(saved["mikrotik_private_key"])
        mikrotik_public = public_key_from_private(mikrotik_private)
    else:
        mikrotik_private, mikrotik_public = generate_keypair()
    phone_private, phone_public = generate_keypair()
    pc_private, pc_public = ("", "")
    if body.generate_pc_peer:
        pc_private, pc_public = generate_keypair()
    pc_ip = body.pc_lan_ip.strip() or (_lan_ips()[0] if _lan_ips() else "")
    payload = {
        **body.model_dump(),
        "pc_lan_ip": pc_ip,
        "mikrotik_private_key": mikrotik_private,
        "mikrotik_public_key": mikrotik_public,
        "phone_private_key": phone_private,
        "phone_public_key": phone_public,
        "pc_private_key": pc_private,
        "pc_public_key": pc_public,
    }
    _save(payload)
    bundle = _bundle_from_saved(payload)
    return {
        "server_url": bundle.server_url,
        "mikrotik_public_key": mikrotik_public,
        "phone_public_key": phone_public,
        "pc_public_key": pc_public,
        "mikrotik_script": build_mikrotik_script(bundle),
        "phone_conf": build_phone_conf(bundle),
        "pc_conf": build_pc_conf(bundle) if body.generate_pc_peer else "",
        "router_ip": bundle.router_ip,
        "phone_ip": bundle.phone_ip,
    }


@router.post("/v1/lab/test")
async def lab_test(body: LabConfigIn, request: Request) -> dict[str, Any]:
    _require_home_lab()
    _require_private_client(request)
    from httpx import ASGITransport, AsyncClient

    lan_ips = _lan_ips()
    pc_ip = body.pc_lan_ip.strip() or (lan_ips[0] if lan_ips else "")
    server_url = f"http://{pc_ip}:8080" if pc_ip else settings.public_origin
    result: dict[str, Any] = {
        "server_url": server_url,
        "health_ok": False,
        "workspace_ok": False,
        "message": "",
    }
    try:
        transport = ASGITransport(app=request.app)
        async with AsyncClient(transport=transport, base_url="http://lab.local") as client:
            health = await client.get("/health")
            result["health_ok"] = health.status_code == 200 and health.json().get("status") == "ok"
            if body.api_key.strip():
                workspace = await client.get(
                    "/v1/workspace",
                    headers={
                        "X-Api-Key": body.api_key.strip(),
                        "X-Profile-Id": "default",
                    },
                )
                result["workspace_ok"] = workspace.status_code == 200
    except Exception as exc:  # noqa: BLE001 — show bind/app errors in the UI
        result["message"] = str(exc)
        return result
    if result["health_ok"] and (result["workspace_ok"] or not body.api_key.strip()):
        result["message"] = "Сервер отвечает. В Almanac → Ссылки и API вставьте этот Server URL."
    elif result["health_ok"]:
        result["message"] = "Health ок, но API key не принят — скопируйте ключ из приложения."
    else:
        result["message"] = "Сервер не ответил на /health."
    saved = _load_saved()
    saved.update(body.model_dump())
    saved["pc_lan_ip"] = pc_ip
    _save(saved)
    return result


@router.get("/v1/lab/phone.conf")
async def lab_phone_conf(request: Request):
    _require_home_lab()
    _require_private_client(request)
    saved = _load_saved()
    bundle = _bundle_from_saved(saved)
    if not bundle.phone_private_key:
        raise HTTPException(status_code=400, detail="Сначала сгенерируйте ключи")
    return PlainTextResponse(
        build_phone_conf(bundle),
        media_type="text/plain",
        headers={"Content-Disposition": 'attachment; filename="almanac-phone.conf"'},
    )


@router.get("/v1/lab/sessions")
async def lab_list_sessions(
    request: Request,
    api_key: str = "",
    db: DatabaseRepository = Depends(get_db),
) -> dict[str, Any]:
    _require_home_lab()
    _require_private_client(request)
    key = _resolve_api_key(api_key)
    await db.ensure_workspace(key, "default")
    origin = _origin(request)
    sessions = await db.list_sessions(key)
    return {
        "api_key": key,
        "server_url": origin,
        "sessions": [_public_session(session, origin) for session in sessions],
    }


@router.post("/v1/lab/sessions")
async def lab_create_session(
    body: LabSessionIn,
    request: Request,
    db: DatabaseRepository = Depends(get_db),
) -> dict[str, Any]:
    _require_home_lab()
    _require_private_client(request)
    key = _resolve_api_key(body.api_key)
    title = body.title.strip() or "Тест планирования"
    state = SessionState(
        slots=_demo_slots(body.slot_count, body.slot_minutes),
        settings={"max_editors": body.max_editors},
    )
    session = await db.create_session(
        api_key=key,
        profile_id=body.profile_id.strip() or "default",
        mode=body.mode,
        title=title,
        state=state,
    )
    origin = _origin(request)
    payload = _public_session(session, origin)
    payload["api_key"] = key
    return payload


@router.delete("/v1/lab/sessions/{token}")
async def lab_close_session(
    token: str,
    request: Request,
    api_key: str = "",
    db: DatabaseRepository = Depends(get_db),
) -> dict[str, Any]:
    _require_home_lab()
    _require_private_client(request)
    key = _resolve_api_key(api_key)
    closed = await db.close_session(token, key)
    if not closed:
        raise HTTPException(status_code=404, detail="Session not found")
    return {"ok": True}
