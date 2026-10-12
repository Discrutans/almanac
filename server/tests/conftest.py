"""Shared fixtures for Almanac API tests."""

from __future__ import annotations

import pytest
from httpx import ASGITransport, AsyncClient


@pytest.fixture
async def api_client(tmp_path, monkeypatch):
    db_path = tmp_path / "almanac-test.db"
    monkeypatch.setattr("almanac.config.settings.db_backend", "sqlite")
    monkeypatch.setattr("almanac.config.settings.sqlite_path", str(db_path))

    import almanac.db.repository as repo

    repo._db = None
    await repo.init_db()

    from almanac.main import app

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        yield client

    await repo.close_db()
    repo._db = None
