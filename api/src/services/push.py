"""
Push Notification Service for MeterScience
Supports Apple Push Notification service (APNs) via HTTP/2
"""

import os
import json
import time
import jwt
import httpx
from typing import Optional, List, Dict, Any
from dataclasses import dataclass
from enum import Enum
from datetime import datetime, timedelta


class NotificationType(str, Enum):
    """Types of push notifications"""
    READING_VERIFIED = "reading_verified"
    VERIFICATION_NEEDED = "verification_needed"
    STREAK_REMINDER = "streak_reminder"
    STREAK_MILESTONE = "streak_milestone"
    BADGE_EARNED = "badge_earned"
    LEVEL_UP = "level_up"
    CAMPAIGN_UPDATE = "campaign_update"
    WEEKLY_DIGEST = "weekly_digest"


@dataclass
class PushPayload:
    """Push notification payload"""
    title: str
    body: str
    notification_type: NotificationType
    data: Optional[Dict[str, Any]] = None
    badge: Optional[int] = None
    sound: str = "default"
    category: Optional[str] = None


class APNsService:
    """
    Apple Push Notification service (APNs) client
    Uses JWT authentication with HTTP/2
    """

    APNS_DEV_HOST = "https://api.development.push.apple.com"
    APNS_PROD_HOST = "https://api.push.apple.com"

    def __init__(self):
        self.team_id = os.getenv("APNS_TEAM_ID")
        self.key_id = os.getenv("APNS_KEY_ID")
        self.bundle_id = os.getenv("APNS_BUNDLE_ID", "com.meterscience.app")
        self.key_path = os.getenv("APNS_KEY_PATH")
        self.is_production = os.getenv("APNS_PRODUCTION", "false").lower() == "true"

        self._token: Optional[str] = None
        self._token_expires: Optional[float] = None
        self._private_key: Optional[str] = None

        # Load private key if path provided
        if self.key_path and os.path.exists(self.key_path):
            with open(self.key_path, 'r') as f:
                self._private_key = f.read()
        else:
            # Try loading from environment variable
            self._private_key = os.getenv("APNS_PRIVATE_KEY")

    @property
    def is_configured(self) -> bool:
        """Check if APNs is properly configured"""
        return all([
            self.team_id,
            self.key_id,
            self._private_key
        ])

    @property
    def host(self) -> str:
        """Get APNs host based on environment"""
        return self.APNS_PROD_HOST if self.is_production else self.APNS_DEV_HOST

    def _generate_token(self) -> str:
        """Generate JWT token for APNs authentication"""
        if not self._private_key:
            raise ValueError("APNs private key not configured")

        # Token valid for 1 hour, regenerate after 50 minutes
        now = time.time()
        if self._token and self._token_expires and now < self._token_expires:
            return self._token

        headers = {
            "alg": "ES256",
            "kid": self.key_id
        }

        payload = {
            "iss": self.team_id,
            "iat": int(now)
        }

        self._token = jwt.encode(
            payload,
            self._private_key,
            algorithm="ES256",
            headers=headers
        )
        self._token_expires = now + 3000  # 50 minutes

        return self._token

    async def send_notification(
        self,
        device_token: str,
        payload: PushPayload,
        priority: int = 10,
        expiration: Optional[int] = None,
        collapse_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Send push notification to a single device

        Args:
            device_token: APNs device token
            payload: Notification payload
            priority: 10 for immediate, 5 for power-saving
            expiration: Unix timestamp when notification expires
            collapse_id: Identifier for collapsing multiple notifications

        Returns:
            Response dict with success status and apns_id
        """
        if not self.is_configured:
            return {
                "success": False,
                "error": "APNs not configured",
                "device_token": device_token
            }

        url = f"{self.host}/3/device/{device_token}"

        # Build APNs payload
        aps = {
            "alert": {
                "title": payload.title,
                "body": payload.body
            },
            "sound": payload.sound
        }

        if payload.badge is not None:
            aps["badge"] = payload.badge

        if payload.category:
            aps["category"] = payload.category

        apns_payload = {"aps": aps}

        # Add custom data
        if payload.data:
            apns_payload.update(payload.data)

        # Add notification type for client handling
        apns_payload["notification_type"] = payload.notification_type.value

        # Build headers
        headers = {
            "authorization": f"bearer {self._generate_token()}",
            "apns-topic": self.bundle_id,
            "apns-push-type": "alert",
            "apns-priority": str(priority)
        }

        if expiration:
            headers["apns-expiration"] = str(expiration)

        if collapse_id:
            headers["apns-collapse-id"] = collapse_id

        try:
            async with httpx.AsyncClient(http2=True) as client:
                response = await client.post(
                    url,
                    json=apns_payload,
                    headers=headers,
                    timeout=30.0
                )

                if response.status_code == 200:
                    return {
                        "success": True,
                        "apns_id": response.headers.get("apns-id"),
                        "device_token": device_token
                    }
                else:
                    error_body = response.json() if response.content else {}
                    return {
                        "success": False,
                        "status_code": response.status_code,
                        "error": error_body.get("reason", "Unknown error"),
                        "device_token": device_token
                    }

        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "device_token": device_token
            }

    async def send_bulk_notifications(
        self,
        device_tokens: List[str],
        payload: PushPayload,
        priority: int = 10
    ) -> Dict[str, Any]:
        """
        Send notification to multiple devices

        Returns summary with success/failure counts
        """
        results = []
        for token in device_tokens:
            result = await self.send_notification(token, payload, priority)
            results.append(result)

        successful = sum(1 for r in results if r.get("success"))
        failed = len(results) - successful

        return {
            "total": len(device_tokens),
            "successful": successful,
            "failed": failed,
            "results": results
        }


# Singleton instance
push_service = APNsService()


# Notification templates
def reading_verified_notification(reading_value: str, meter_name: str) -> PushPayload:
    """Create notification for verified reading"""
    return PushPayload(
        title="Reading Verified!",
        body=f"Your reading of {reading_value} for {meter_name} has been verified by the community.",
        notification_type=NotificationType.READING_VERIFIED,
        data={"meter_name": meter_name, "reading_value": reading_value}
    )


def verification_needed_notification(count: int) -> PushPayload:
    """Create notification for pending verifications"""
    return PushPayload(
        title="Verifications Needed",
        body=f"Help verify {count} meter readings from your neighbors!",
        notification_type=NotificationType.VERIFICATION_NEEDED,
        badge=count,
        data={"pending_count": count}
    )


def streak_reminder_notification(current_streak: int) -> PushPayload:
    """Create streak reminder notification"""
    return PushPayload(
        title="Don't Break Your Streak!",
        body=f"You're on a {current_streak}-day streak! Take a reading today to keep it going.",
        notification_type=NotificationType.STREAK_REMINDER,
        data={"current_streak": current_streak}
    )


def streak_milestone_notification(streak_days: int, xp_bonus: int) -> PushPayload:
    """Create streak milestone notification"""
    return PushPayload(
        title=f"{streak_days}-Day Streak!",
        body=f"Amazing! You've earned {xp_bonus} bonus XP for your dedication.",
        notification_type=NotificationType.STREAK_MILESTONE,
        sound="celebration.caf",
        data={"streak_days": streak_days, "xp_bonus": xp_bonus}
    )


def badge_earned_notification(badge_name: str, badge_description: str) -> PushPayload:
    """Create badge earned notification"""
    return PushPayload(
        title="New Badge Earned!",
        body=f"You've earned the {badge_name} badge: {badge_description}",
        notification_type=NotificationType.BADGE_EARNED,
        sound="badge.caf",
        data={"badge_name": badge_name}
    )


def level_up_notification(new_level: int) -> PushPayload:
    """Create level up notification"""
    return PushPayload(
        title=f"Level {new_level}!",
        body=f"Congratulations! You've reached level {new_level}. Keep up the great work!",
        notification_type=NotificationType.LEVEL_UP,
        sound="levelup.caf",
        data={"new_level": new_level}
    )


def campaign_update_notification(campaign_name: str, message: str) -> PushPayload:
    """Create campaign update notification"""
    return PushPayload(
        title=campaign_name,
        body=message,
        notification_type=NotificationType.CAMPAIGN_UPDATE,
        data={"campaign_name": campaign_name}
    )


def weekly_digest_notification(readings_count: int, xp_earned: int) -> PushPayload:
    """Create weekly digest notification"""
    return PushPayload(
        title="Your Weekly Summary",
        body=f"This week: {readings_count} readings, {xp_earned} XP earned. Keep it up!",
        notification_type=NotificationType.WEEKLY_DIGEST,
        data={"readings_count": readings_count, "xp_earned": xp_earned}
    )
