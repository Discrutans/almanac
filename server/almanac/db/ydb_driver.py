from __future__ import annotations

import asyncio
from functools import partial
from pathlib import Path
from typing import Any, Callable, TypeVar

import ydb
import ydb.iam

from ..config import settings

T = TypeVar("T")

_driver: ydb.Driver | None = None
_pool: ydb.SessionPool | None = None


def _build_driver() -> ydb.Driver:
    credentials = None
    if settings.ydb_service_account_key_file:
        credentials = ydb.iam.ServiceAccountCredentials.from_file(
            settings.ydb_service_account_key_file
        )
    driver = ydb.Driver(
        endpoint=settings.ydb_endpoint,
        database=settings.ydb_database,
        credentials=credentials,
    )
    driver.wait(timeout=10)
    return driver


def get_pool() -> ydb.SessionPool:
    global _driver, _pool
    if _pool is None:
        _driver = _build_driver()
        _pool = ydb.SessionPool(_driver)
    return _pool


def close_pool() -> None:
    global _driver, _pool
    if _pool is not None:
        _pool.stop()
        _pool = None
    if _driver is not None:
        _driver.stop()
        _driver = None


def run_sync(operation: Callable[[ydb.Session], T]) -> T:
    pool = get_pool()
    return pool.retry_operation_sync(operation)


async def run_async(operation: Callable[[ydb.Session], T]) -> T:
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(None, partial(run_sync, operation))


def apply_schema() -> None:
    schema_path = Path(__file__).with_name("schema.yql")
    raw = schema_path.read_text(encoding="utf-8")
    statements: list[str] = []
    for chunk in raw.split(";"):
        lines = [
            line
            for line in chunk.splitlines()
            if line.strip() and not line.strip().startswith("--")
        ]
        statement = "\n".join(lines).strip()
        if statement:
            statements.append(statement)

    def callee(session: ydb.Session) -> None:
        for statement in statements:
            if not statement.upper().startswith("CREATE TABLE"):
                continue
            try:
                session.execute_scheme(statement)
            except ydb.Error as error:
                message = str(error).lower()
                if "already exists" in message or "path exist" in message:
                    continue
                raise

    run_sync(callee)


def row_value(row: Any, index: int) -> Any:
    return row[index]
