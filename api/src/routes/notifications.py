"""
Notification routes for MeterScience API
Handles device token registration and notification preferences
"""

from typing import Optional, List
from uuid import UUID
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status, Query
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, delete

from ..database import get_db
from ..models import User, DeviceToken, NotificationPreference
from ..services.auth import get_current_user
from ..services.push import (
    push_service,
    PushPayload,
    NotificationType,
    verification_needed_notification,
    streak_reminder_notification
)

router = APIRouter()


# Request/Response Models
class RegisterDeviceRequest(BaseModel):
    """Register a device for push notifications"""
    device_token: str = Field(..., description="APNs device token")
    device_name: Optional[str] = Field(None, description="User-friendly device name")
    device_model: Optional[str] = Field(None, description="Device model (e.g., iPhone 15)")
    os_version: Optional[str] = Field(None, description="iOS version")


class DeviceResponse(BaseModel):
    """Device token response"""
    id: UUID
    device_token: str
    device_name: Optional[str]
    device_model: Optional[str]
    os_version: Optional[str]
    created_at: datetime
    last_used_at: Optional[datetime]

    class Config:
        from_attributes = True


class NotificationPreferencesRequest(BaseModel):
    """Update notification preferences"""
    reading_verified: bool = True
    verification_needed: bool = True
    streak_reminder: bool = True
    streak_milestone: bool = True
    badge_earned: bool = True
    level_up: bool = True
    campaign_updates: bool = True
    weekly_digest: bool = True
    quiet_hours_start: Optional[int] = Field(None, ge=0, le=23, description="Start of quiet hours (0-23)")
    quiet_hours_end: Optional[int] = Field(None, ge=0, le=23, description="End of quiet hours (0-23)")


class NotificationPreferencesResponse(BaseModel):
    """Notification preferences response"""
    reading_verified: bool
    verification_needed: bool
    streak_reminder: bool
    streak_milestone: bool
    badge_earned: bool
    level_up: bool
    campaign_updates: bool
    weekly_digest: bool
    quiet_hours_start: Optional[int]
    quiet_hours_end: Optional[int]
    updated_at: datetime

    class Config:
        from_attributes = True


class SendNotificationRequest(BaseModel):
    """Send a test notification (admin only)"""
    user_id: Optional[UUID] = Field(None, description="Target user ID (omit for self)")
    title: str
    body: str
    notification_type: NotificationType = NotificationType.CAMPAIGN_UPDATE


class NotificationStatusResponse(BaseModel):
    """Push notification service status"""
    configured: bool
    environment: str
    bundle_id: str


# Routes
@router.post("/devices", response_model=DeviceResponse, status_code=status.HTTP_201_CREATED)
async def register_device(
    request: RegisterDeviceRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Register a device for push notifications.
    If the device token already exists for this user, update it.
    """
    # Check if device already registered
    result = await db.execute(
        select(DeviceToken).where(
            DeviceToken.user_id == current_user.id,
            DeviceToken.device_token == request.device_token
        )
    )
    existing = result.scalar_one_or_none()

    if existing:
        # Update existing device
        existing.device_name = request.device_name or existing.device_name
        existing.device_model = request.device_model or existing.device_model
        existing.os_version = request.os_version or existing.os_version
        existing.last_used_at = datetime.utcnow()
        await db.commit()
        await db.refresh(existing)
        return existing

    # Create new device registration
    device = DeviceToken(
        user_id=current_user.id,
        device_token=request.device_token,
        device_name=request.device_name,
        device_model=request.device_model,
        os_version=request.os_version
    )
    db.add(device)
    await db.commit()
    await db.refresh(device)

    return device


@router.get("/devices", response_model=List[DeviceResponse])
async def list_devices(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """List all registered devices for the current user"""
    result = await db.execute(
        select(DeviceToken)
        .where(DeviceToken.user_id == current_user.id)
        .order_by(DeviceToken.last_used_at.desc().nullsfirst())
    )
    return result.scalars().all()


@router.delete("/devices/{device_id}", status_code=status.HTTP_204_NO_CONTENT)
async def unregister_device(
    device_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Unregister a device from push notifications"""
    result = await db.execute(
        select(DeviceToken).where(
            DeviceToken.id == device_id,
            DeviceToken.user_id == current_user.id
        )
    )
    device = result.scalar_one_or_none()

    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found"
        )

    await db.delete(device)
    await db.commit()


@router.delete("/devices", status_code=status.HTTP_204_NO_CONTENT)
async def unregister_all_devices(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Unregister all devices for the current user"""
    await db.execute(
        delete(DeviceToken).where(DeviceToken.user_id == current_user.id)
    )
    await db.commit()


@router.get("/preferences", response_model=NotificationPreferencesResponse)
async def get_preferences(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get notification preferences for the current user"""
    result = await db.execute(
        select(NotificationPreference).where(
            NotificationPreference.user_id == current_user.id
        )
    )
    prefs = result.scalar_one_or_none()

    if not prefs:
        # Create default preferences
        prefs = NotificationPreference(user_id=current_user.id)
        db.add(prefs)
        await db.commit()
        await db.refresh(prefs)

    return prefs


@router.put("/preferences", response_model=NotificationPreferencesResponse)
async def update_preferences(
    request: NotificationPreferencesRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Update notification preferences"""
    result = await db.execute(
        select(NotificationPreference).where(
            NotificationPreference.user_id == current_user.id
        )
    )
    prefs = result.scalar_one_or_none()

    if not prefs:
        prefs = NotificationPreference(user_id=current_user.id)
        db.add(prefs)

    # Update all fields
    prefs.reading_verified = request.reading_verified
    prefs.verification_needed = request.verification_needed
    prefs.streak_reminder = request.streak_reminder
    prefs.streak_milestone = request.streak_milestone
    prefs.badge_earned = request.badge_earned
    prefs.level_up = request.level_up
    prefs.campaign_updates = request.campaign_updates
    prefs.weekly_digest = request.weekly_digest
    prefs.quiet_hours_start = request.quiet_hours_start
    prefs.quiet_hours_end = request.quiet_hours_end
    prefs.updated_at = datetime.utcnow()

    await db.commit()
    await db.refresh(prefs)

    return prefs


@router.post("/test", status_code=status.HTTP_200_OK)
async def send_test_notification(
    request: SendNotificationRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Send a test notification to your devices.
    Useful for verifying push notification setup.
    """
    # Get user's devices
    result = await db.execute(
        select(DeviceToken).where(DeviceToken.user_id == current_user.id)
    )
    devices = result.scalars().all()

    if not devices:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No devices registered for push notifications"
        )

    # Create payload
    payload = PushPayload(
        title=request.title,
        body=request.body,
        notification_type=request.notification_type
    )

    # Send to all devices
    device_tokens = [d.device_token for d in devices]
    result = await push_service.send_bulk_notifications(device_tokens, payload)

    return {
        "message": "Test notification sent",
        "devices_targeted": len(device_tokens),
        "successful": result["successful"],
        "failed": result["failed"]
    }


@router.get("/status", response_model=NotificationStatusResponse)
async def get_notification_status(
    current_user: User = Depends(get_current_user)
):
    """Check push notification service status"""
    return {
        "configured": push_service.is_configured,
        "environment": "production" if push_service.is_production else "development",
        "bundle_id": push_service.bundle_id
    }


# Helper function for other routes to send notifications
async def notify_user(
    db: AsyncSession,
    user_id: UUID,
    payload: PushPayload,
    check_preferences: bool = True
) -> dict:
    """
    Send notification to a user's devices.
    Checks notification preferences if check_preferences is True.

    Returns dict with success status and delivery info.
    """
    # Check preferences
    if check_preferences:
        result = await db.execute(
            select(NotificationPreference).where(
                NotificationPreference.user_id == user_id
            )
        )
        prefs = result.scalar_one_or_none()

        if prefs:
            # Check if this notification type is enabled
            pref_map = {
                NotificationType.READING_VERIFIED: prefs.reading_verified,
                NotificationType.VERIFICATION_NEEDED: prefs.verification_needed,
                NotificationType.STREAK_REMINDER: prefs.streak_reminder,
                NotificationType.STREAK_MILESTONE: prefs.streak_milestone,
                NotificationType.BADGE_EARNED: prefs.badge_earned,
                NotificationType.LEVEL_UP: prefs.level_up,
                NotificationType.CAMPAIGN_UPDATE: prefs.campaign_updates,
                NotificationType.WEEKLY_DIGEST: prefs.weekly_digest,
            }

            if not pref_map.get(payload.notification_type, True):
                return {
                    "sent": False,
                    "reason": "User disabled this notification type"
                }

            # Check quiet hours
            if prefs.quiet_hours_start is not None and prefs.quiet_hours_end is not None:
                current_hour = datetime.utcnow().hour
                if prefs.quiet_hours_start <= current_hour < prefs.quiet_hours_end:
                    return {
                        "sent": False,
                        "reason": "User is in quiet hours"
                    }

    # Get devices
    result = await db.execute(
        select(DeviceToken).where(DeviceToken.user_id == user_id)
    )
    devices = result.scalars().all()

    if not devices:
        return {
            "sent": False,
            "reason": "No devices registered"
        }

    # Send notifications
    device_tokens = [d.device_token for d in devices]
    send_result = await push_service.send_bulk_notifications(device_tokens, payload)

    return {
        "sent": True,
        "devices": send_result["total"],
        "successful": send_result["successful"],
        "failed": send_result["failed"]
    }
