"""
Webhooks API endpoints

Enterprise webhook configuration for receiving real-time notifications
when events occur in the MeterScience platform.
"""

import secrets
import hmac
import hashlib
from datetime import datetime, timezone
from typing import Optional, List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, Query, BackgroundTasks
from pydantic import BaseModel, HttpUrl
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
import httpx

from ..database import get_db
from ..models import User, Webhook
from ..services.auth import get_current_user

router = APIRouter()

# Valid webhook events
VALID_EVENTS = [
    "reading.created",
    "reading.verified",
    "reading.rejected",
    "meter.created",
    "meter.updated",
    "meter.deleted",
    "campaign.joined",
    "campaign.completed",
    "user.level_up",
    "user.badge_earned",
]

# Max webhooks per user
MAX_WEBHOOKS_PER_USER = 10


class WebhookCreate(BaseModel):
    url: HttpUrl
    events: List[str]
    description: Optional[str] = None


class WebhookUpdate(BaseModel):
    url: Optional[HttpUrl] = None
    events: Optional[List[str]] = None
    is_active: Optional[bool] = None


class WebhookResponse(BaseModel):
    id: UUID
    url: str
    events: List[str]
    secret: str
    is_active: bool
    failure_count: int
    last_triggered_at: Optional[datetime]
    last_success_at: Optional[datetime]
    created_at: datetime

    class Config:
        from_attributes = True


class WebhookListResponse(BaseModel):
    webhooks: List[WebhookResponse]
    total: int


class WebhookTestResponse(BaseModel):
    success: bool
    status_code: Optional[int]
    response_time_ms: Optional[int]
    error: Optional[str]


def generate_webhook_secret() -> str:
    """Generate a secure webhook secret for HMAC signing."""
    return secrets.token_hex(32)


def sign_payload(payload: str, secret: str) -> str:
    """Sign a payload with HMAC-SHA256."""
    return hmac.new(
        secret.encode(),
        payload.encode(),
        hashlib.sha256
    ).hexdigest()


@router.post("/", response_model=WebhookResponse, status_code=status.HTTP_201_CREATED)
async def create_webhook(
    webhook_data: WebhookCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Create a new webhook endpoint.

    Webhooks will receive POST requests with a JSON payload when the
    subscribed events occur. Each request includes an X-Webhook-Signature
    header containing an HMAC-SHA256 signature of the payload.

    Available events:
    - reading.created: New meter reading submitted
    - reading.verified: Reading verified by community
    - reading.rejected: Reading rejected by community
    - meter.created: New meter added
    - meter.updated: Meter configuration changed
    - meter.deleted: Meter removed
    - campaign.joined: User joined a campaign
    - campaign.completed: Campaign goal reached
    - user.level_up: User reached a new level
    - user.badge_earned: User earned a new badge
    """

    # Validate events
    invalid_events = [e for e in webhook_data.events if e not in VALID_EVENTS]
    if invalid_events:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid events: {', '.join(invalid_events)}. Valid events: {', '.join(VALID_EVENTS)}"
        )

    if not webhook_data.events:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one event must be specified"
        )

    # Check webhook limit
    count_result = await db.execute(
        select(func.count(Webhook.id)).where(Webhook.user_id == current_user.id)
    )
    webhook_count = count_result.scalar() or 0

    if webhook_count >= MAX_WEBHOOKS_PER_USER:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Maximum of {MAX_WEBHOOKS_PER_USER} webhooks allowed per user"
        )

    # Check for duplicate URL
    existing = await db.execute(
        select(Webhook).where(
            Webhook.user_id == current_user.id,
            Webhook.url == str(webhook_data.url)
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A webhook with this URL already exists"
        )

    # Create webhook with secret
    webhook = Webhook(
        user_id=current_user.id,
        url=str(webhook_data.url),
        events=webhook_data.events,
        secret=generate_webhook_secret(),
    )

    db.add(webhook)
    await db.commit()
    await db.refresh(webhook)

    return webhook


@router.get("/", response_model=WebhookListResponse)
async def list_webhooks(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """List all webhooks for the current user."""

    result = await db.execute(
        select(Webhook)
        .where(Webhook.user_id == current_user.id)
        .order_by(Webhook.created_at.desc())
    )
    webhooks = result.scalars().all()

    return WebhookListResponse(
        webhooks=webhooks,
        total=len(webhooks)
    )


@router.get("/events")
async def list_available_events():
    """List all available webhook events."""
    return {
        "events": [
            {"name": "reading.created", "description": "New meter reading submitted"},
            {"name": "reading.verified", "description": "Reading verified by community"},
            {"name": "reading.rejected", "description": "Reading rejected by community"},
            {"name": "meter.created", "description": "New meter added"},
            {"name": "meter.updated", "description": "Meter configuration changed"},
            {"name": "meter.deleted", "description": "Meter removed"},
            {"name": "campaign.joined", "description": "User joined a campaign"},
            {"name": "campaign.completed", "description": "Campaign goal reached"},
            {"name": "user.level_up", "description": "User reached a new level"},
            {"name": "user.badge_earned", "description": "User earned a new badge"},
        ]
    }


@router.get("/{webhook_id}", response_model=WebhookResponse)
async def get_webhook(
    webhook_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get a specific webhook by ID."""

    result = await db.execute(
        select(Webhook).where(
            Webhook.id == webhook_id,
            Webhook.user_id == current_user.id
        )
    )
    webhook = result.scalar_one_or_none()

    if not webhook:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Webhook not found"
        )

    return webhook


@router.patch("/{webhook_id}", response_model=WebhookResponse)
async def update_webhook(
    webhook_id: UUID,
    webhook_data: WebhookUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Update a webhook configuration."""

    result = await db.execute(
        select(Webhook).where(
            Webhook.id == webhook_id,
            Webhook.user_id == current_user.id
        )
    )
    webhook = result.scalar_one_or_none()

    if not webhook:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Webhook not found"
        )

    # Validate events if provided
    if webhook_data.events is not None:
        invalid_events = [e for e in webhook_data.events if e not in VALID_EVENTS]
        if invalid_events:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid events: {', '.join(invalid_events)}"
            )
        if not webhook_data.events:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="At least one event must be specified"
            )
        webhook.events = webhook_data.events

    if webhook_data.url is not None:
        # Check for duplicate URL (excluding current webhook)
        existing = await db.execute(
            select(Webhook).where(
                Webhook.user_id == current_user.id,
                Webhook.url == str(webhook_data.url),
                Webhook.id != webhook_id
            )
        )
        if existing.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="A webhook with this URL already exists"
            )
        webhook.url = str(webhook_data.url)

    if webhook_data.is_active is not None:
        webhook.is_active = webhook_data.is_active
        # Reset failure count when re-enabling
        if webhook_data.is_active:
            webhook.failure_count = 0

    await db.commit()
    await db.refresh(webhook)

    return webhook


@router.delete("/{webhook_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_webhook(
    webhook_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Delete a webhook."""

    result = await db.execute(
        select(Webhook).where(
            Webhook.id == webhook_id,
            Webhook.user_id == current_user.id
        )
    )
    webhook = result.scalar_one_or_none()

    if not webhook:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Webhook not found"
        )

    await db.delete(webhook)
    await db.commit()


@router.post("/{webhook_id}/rotate-secret", response_model=WebhookResponse)
async def rotate_webhook_secret(
    webhook_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Rotate the webhook secret. The old secret will be invalidated immediately."""

    result = await db.execute(
        select(Webhook).where(
            Webhook.id == webhook_id,
            Webhook.user_id == current_user.id
        )
    )
    webhook = result.scalar_one_or_none()

    if not webhook:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Webhook not found"
        )

    webhook.secret = generate_webhook_secret()
    await db.commit()
    await db.refresh(webhook)

    return webhook


@router.post("/{webhook_id}/test", response_model=WebhookTestResponse)
async def test_webhook(
    webhook_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Send a test event to the webhook endpoint.

    This will send a test payload to verify connectivity and that
    your endpoint is correctly handling webhook deliveries.
    """

    result = await db.execute(
        select(Webhook).where(
            Webhook.id == webhook_id,
            Webhook.user_id == current_user.id
        )
    )
    webhook = result.scalar_one_or_none()

    if not webhook:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Webhook not found"
        )

    # Create test payload
    test_payload = {
        "event": "test",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "data": {
            "message": "This is a test webhook delivery from MeterScience",
            "webhook_id": str(webhook_id),
        }
    }

    import json
    payload_str = json.dumps(test_payload)
    signature = sign_payload(payload_str, webhook.secret)

    # Send test request
    start_time = datetime.now(timezone.utc)
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                webhook.url,
                json=test_payload,
                headers={
                    "Content-Type": "application/json",
                    "X-Webhook-Signature": f"sha256={signature}",
                    "X-Webhook-Event": "test",
                    "User-Agent": "MeterScience-Webhook/1.0",
                }
            )

        elapsed = (datetime.now(timezone.utc) - start_time).total_seconds() * 1000

        return WebhookTestResponse(
            success=response.status_code < 400,
            status_code=response.status_code,
            response_time_ms=int(elapsed),
            error=None if response.status_code < 400 else f"Received status {response.status_code}"
        )

    except httpx.TimeoutException:
        return WebhookTestResponse(
            success=False,
            status_code=None,
            response_time_ms=None,
            error="Request timed out after 10 seconds"
        )
    except httpx.RequestError as e:
        return WebhookTestResponse(
            success=False,
            status_code=None,
            response_time_ms=None,
            error=f"Connection error: {str(e)}"
        )


# Webhook delivery service (to be called from other parts of the application)
async def trigger_webhooks(
    db: AsyncSession,
    user_id: UUID,
    event: str,
    data: dict
):
    """
    Trigger all active webhooks for a user that are subscribed to an event.

    This function should be called from other routes when events occur.
    """

    result = await db.execute(
        select(Webhook).where(
            Webhook.user_id == user_id,
            Webhook.is_active == True,
            Webhook.failure_count < 5  # Disable after 5 consecutive failures
        )
    )
    webhooks = result.scalars().all()

    for webhook in webhooks:
        if event not in webhook.events:
            continue

        payload = {
            "event": event,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "data": data
        }

        import json
        payload_str = json.dumps(payload)
        signature = sign_payload(payload_str, webhook.secret)

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.post(
                    webhook.url,
                    json=payload,
                    headers={
                        "Content-Type": "application/json",
                        "X-Webhook-Signature": f"sha256={signature}",
                        "X-Webhook-Event": event,
                        "User-Agent": "MeterScience-Webhook/1.0",
                    }
                )

            webhook.last_triggered_at = datetime.now(timezone.utc)

            if response.status_code < 400:
                webhook.last_success_at = datetime.now(timezone.utc)
                webhook.failure_count = 0
            else:
                webhook.failure_count += 1

        except Exception:
            webhook.failure_count += 1
            webhook.last_triggered_at = datetime.now(timezone.utc)

        # Auto-disable after too many failures
        if webhook.failure_count >= 5:
            webhook.is_active = False

    await db.commit()
