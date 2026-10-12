"""Home-lab helper: WireGuard scripts and /lab API."""

from __future__ import annotations

import pytest
from httpx import ASGITransport, AsyncClient

from almanac.lab_wg import (
    WireGuardBundle,
    build_mikrotik_script,
    build_phone_conf,
    generate_keypair,
    public_key_from_private,
    x25519,
)


def test_x25519_rfc7748_vector():
    scalar = bytes.fromhex("a546e36bf0527c9d3b16154b82465edd62144c0ac1fc5a18506a2244ba449ac4")
    u_coord = bytes.fromhex("e6db6867583030db3594c1a424b15f7c726624ec26b3353b10a903a6d0ab1c4c")
    expected = bytes.fromhex("c3da55379de9c6908e94ea4df28d084f32eccf03491c71f754b4075577a28552")
    assert x25519(scalar, u_coord) == expected


def test_keypair_roundtrip():
    private_b64, public_b64 = generate_keypair()
    assert public_key_from_private(private_b64) == public_b64
    assert private_b64.endswith("=")


def test_mikrotik_script_contains_peer_and_port():
    phone_priv, phone_pub = generate_keypair()
    mt_priv, mt_pub = generate_keypair()
    bundle = WireGuardBundle(
        endpoint="home.example.ru",
        wg_port=13231,
        wg_network="10.13.13.0/24",
        lan_cidr="192.168.88.0/24",
        pc_lan_ip="192.168.88.50",
        phone_name="almanac-phone",
        mikrotik_private_key=mt_priv,
        mikrotik_public_key=mt_pub,
        phone_private_key=phone_priv,
        phone_public_key=phone_pub,
    )
    script = build_mikrotik_script(bundle)
    assert "listen-port=13231" in script
    assert phone_pub in script
    assert "10.13.13.2/32" in script
    assert "dst-port=13231" in script
    conf = build_phone_conf(bundle)
    assert "Endpoint = home.example.ru:13231" in conf
    assert "192.168.88.0/24" in conf
    assert "DNS = 192.168.88.1" in conf
    assert "http://192.168.88.50:8080" == bundle.server_url


@pytest.fixture
async def lab_client(tmp_path, monkeypatch):
    db_path = tmp_path / "almanac-test.db"
    monkeypatch.setattr("almanac.config.settings.db_backend", "sqlite")
    monkeypatch.setattr("almanac.config.settings.sqlite_path", str(db_path))
    monkeypatch.setattr("almanac.config.settings.home_lab", True)

    import almanac.db.repository as repo

    repo._db = None
    await repo.init_db()

    from almanac.main import app

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://127.0.0.1") as client:
        yield client

    await repo.close_db()
    repo._db = None


@pytest.mark.asyncio
async def test_lab_disabled_by_default(api_client):
    response = await api_client.get("/lab")
    assert response.status_code == 404
    plan = await api_client.get("/lab/plan")
    assert plan.status_code == 404


@pytest.mark.asyncio
async def test_lab_status_generate_and_test(lab_client):
    page = await lab_client.get("/lab")
    assert page.status_code == 200
    assert "домашний сервер" in page.text

    status = await lab_client.get("/v1/lab/status")
    assert status.status_code == 200
    assert status.json()["enabled"] is True

    generated = await lab_client.post(
        "/v1/lab/generate",
        json={
            "endpoint": "home.example.ru",
            "wg_port": 13231,
            "lan_cidr": "192.168.88.0/24",
            "pc_lan_ip": "192.168.88.50",
            "phone_name": "pixel",
            "reuse_server_keys": False,
        },
    )
    assert generated.status_code == 200, generated.text
    body = generated.json()
    assert "listen-port=13231" in body["mikrotik_script"]
    assert "Endpoint = home.example.ru:13231" in body["phone_conf"]
    assert body["server_url"] == "http://192.168.88.50:8080"

    probed = await lab_client.post(
        "/v1/lab/test",
        json={"pc_lan_ip": "192.168.88.50", "api_key": "lab-key"},
    )
    assert probed.status_code == 200
    assert probed.json()["health_ok"] is True
    assert probed.json()["workspace_ok"] is True


@pytest.mark.asyncio
async def test_lab_plan_page_and_collaborative_session(lab_client):
    page = await lab_client.get("/lab/plan")
    assert page.status_code == 200
    assert "Совместное планирование" in page.text

    created = await lab_client.post(
        "/v1/lab/sessions",
        json={
            "title": "Лаборатория",
            "max_editors": 2,
            "slot_count": 2,
            "slot_minutes": 30,
        },
    )
    assert created.status_code == 200, created.text
    body = created.json()
    assert body["mode"] == "collaborative"
    assert body["title"] == "Лаборатория"
    assert "/join/" in body["deep_link"]
    assert "almanac://join/" in body["app_link"]
    assert "server=" in body["app_link"]
    assert body["token"]
    assert len(body["state"]["slots"]) == 2
    assert body["state"]["settings"]["max_editors"] == 2
    assert body["api_key"]

    listed = await lab_client.get("/v1/lab/sessions", params={"api_key": body["api_key"]})
    assert listed.status_code == 200
    tokens = [item["token"] for item in listed.json()["sessions"]]
    assert body["token"] in tokens

    public = await lab_client.get(f"/v1/sessions/{body['token']}")
    assert public.status_code == 200
    assert public.json()["title"] == "Лаборатория"

    closed = await lab_client.delete(
        f"/v1/lab/sessions/{body['token']}",
        params={"api_key": body["api_key"]},
    )
    assert closed.status_code == 200
    assert closed.json()["ok"] is True
