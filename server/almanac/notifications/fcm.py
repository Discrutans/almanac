from __future__ import annotations

import logging

import httpx

from ..config import settings

logger = logging.getLogger(__name__)


async def send_booking_request_push(
    *,
    device_tokens: list[str],
    session_title: str,
    request_id: str,
) -> None:
    if not settings.fcm_server_key or not device_tokens:
        return

    payload = {
        "registration_ids": device_tokens,
        "notification": {
            "title": "Новая заявка на запись",
            "body": f'Сессия «{session_title}» — требуется подтверждение',
        },
        "data": {
            "type": "booking_request_created",
            "requestId": request_id,
        },
    }

    try:
        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.post(
                "https://fcm.googleapis.com/fcm/send",
                headers={
                    "Authorization": f"key={settings.fcm_server_key}",
                    "Content-Type": "application/json",
                },
                json=payload,
            )
            if response.status_code >= 400:
                logger.warning("FCM push failed: %s", response.text)
    except Exception as error:
        logger.warning("FCM push error: %s", error)
