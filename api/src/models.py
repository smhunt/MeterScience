"""
SQLAlchemy ORM Models
"""

from datetime import datetime
from typing import Optional, List
from uuid import uuid4

from sqlalchemy import (
    String, Integer, Float, Boolean, DateTime, Text, ForeignKey,
    JSON, Index, UniqueConstraint
)
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship
from geoalchemy2 import Geography

from .database import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    email: Mapped[Optional[str]] = mapped_column(String(255), unique=True, nullable=True)
    email_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    display_name: Mapped[str] = mapped_column(String(100), nullable=False)
    avatar_emoji: Mapped[str] = mapped_column(String(10), default="📊")
    password_hash: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

    # Gamification
    level: Mapped[int] = mapped_column(Integer, default=1)
    xp: Mapped[int] = mapped_column(Integer, default=0)
    total_readings: Mapped[int] = mapped_column(Integer, default=0)
    verified_readings: Mapped[int] = mapped_column(Integer, default=0)
    verifications_performed: Mapped[int] = mapped_column(Integer, default=0)
    streak_days: Mapped[int] = mapped_column(Integer, default=0)
    last_reading_date: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    trust_score: Mapped[int] = mapped_column(Integer, default=50)
    badges: Mapped[dict] = mapped_column(JSONB, default=list)

    # Subscription (legacy fields maintained for backward compatibility)
    subscription_tier: Mapped[str] = mapped_column(String(20), default="free")
    subscription_expires_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    stripe_customer_id: Mapped[Optional[str]] = mapped_column(String(255), nullable=True, unique=True)
    
    # Referral
    referral_code: Mapped[Optional[str]] = mapped_column(String(10), unique=True, nullable=True)
    referred_by_id: Mapped[Optional[UUID]] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    referral_count: Mapped[int] = mapped_column(Integer, default=0)
    
    # Location
    postal_code: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    country: Mapped[Optional[str]] = mapped_column(String(2), nullable=True)
    
    # Timestamps
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)
    last_login_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    
    # Relationships
    meters: Mapped[List["Meter"]] = relationship("Meter", back_populates="user", cascade="all, delete-orphan")
    readings: Mapped[List["Reading"]] = relationship("Reading", back_populates="user")


class Meter(Base):
    __tablename__ = "meters"
    
    id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    meter_type: Mapped[str] = mapped_column(String(20), nullable=False)  # electric, gas, water, solar
    utility_provider: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    account_number: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    
    # Location
    postal_code: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    country: Mapped[Optional[str]] = mapped_column(String(2), nullable=True)
    latitude: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    longitude: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    
    # Learned characteristics
    digit_count: Mapped[int] = mapped_column(Integer, default=6)
    has_decimal_point: Mapped[bool] = mapped_column(Boolean, default=False)
    decimal_places: Mapped[int] = mapped_column(Integer, default=0)
    bounding_box: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)
    sample_readings: Mapped[dict] = mapped_column(JSONB, default=list)
    average_confidence: Mapped[float] = mapped_column(Float, default=0.0)
    
    # Calibration
    calibration_image_hash: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    
    # Status
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    last_read_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    
    # Timestamps
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="meters")
    readings: Mapped[List["Reading"]] = relationship("Reading", back_populates="meter", cascade="all, delete-orphan")


class Reading(Base):
    __tablename__ = "readings"
    
    id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    meter_id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("meters.id"), nullable=False)
    user_id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    
    # The reading
    raw_value: Mapped[str] = mapped_column(String(50), nullable=False)
    normalized_value: Mapped[str] = mapped_column(String(50), nullable=False)
    numeric_value: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    
    # OCR metadata
    confidence: Mapped[float] = mapped_column(Float, nullable=False)
    all_candidates: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)
    processing_ms: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    
    # Image context
    image_hash: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    image_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    image_brightness: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    image_blur: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    bounding_box: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)
    
    # Device context
    device_model: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    os_version: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    app_version: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    
    # Temporal
    captured_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    timezone_offset: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    capture_method: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)  # live, photo, gallery, hardware
    
    # Verification
    verification_status: Mapped[str] = mapped_column(String(20), default="pending")
    verification_score: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    flagged_for_review: Mapped[bool] = mapped_column(Boolean, default=False)
    flag_reason: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    
    # Usage calculations
    usage_since_last: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    days_since_last: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    
    # Sync
    synced_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    
    # Timestamps
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    
    # Relationships
    meter: Mapped["Meter"] = relationship("Meter", back_populates="readings")
    user: Mapped["User"] = relationship("User", back_populates="readings")
    votes: Mapped[List["VerificationVote"]] = relationship("VerificationVote", back_populates="reading", cascade="all, delete-orphan")
    
    # Indexes
    __table_args__ = (
        Index("idx_readings_meter_id", "meter_id"),
        Index("idx_readings_user_id", "user_id"),
        Index("idx_readings_captured_at", "captured_at"),
        Index("idx_readings_verification_status", "verification_status"),
    )


class VerificationVote(Base):
    __tablename__ = "verification_votes"
    
    id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    reading_id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("readings.id"), nullable=False)
    verifier_id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    
    vote: Mapped[str] = mapped_column(String(20), nullable=False)  # correct, incorrect, unclear
    suggested_value: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    verifier_trust_score: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    
    # Relationships
    reading: Mapped["Reading"] = relationship("Reading", back_populates="votes")
    
    __table_args__ = (
        UniqueConstraint("reading_id", "verifier_id", name="unique_vote_per_user"),
    )


class Campaign(Base):
    __tablename__ = "campaigns"
    
    id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    organizer_id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    
    # Location
    center_latitude: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    center_longitude: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    radius_meters: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    postal_codes: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)
    
    # Goals
    target_meter_count: Mapped[int] = mapped_column(Integer, default=20)
    target_readings_per_meter: Mapped[int] = mapped_column(Integer, default=30)
    meter_types: Mapped[dict] = mapped_column(JSONB, default=lambda: ["electric"])
    
    # Progress
    participant_count: Mapped[int] = mapped_column(Integer, default=0)
    meters_registered: Mapped[int] = mapped_column(Integer, default=0)
    total_readings: Mapped[int] = mapped_column(Integer, default=0)
    verified_readings: Mapped[int] = mapped_column(Integer, default=0)
    
    # Timing
    start_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    end_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    reading_schedule: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    
    # Settings
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    is_public: Mapped[bool] = mapped_column(Boolean, default=True)
    invite_code: Mapped[Optional[str]] = mapped_column(String(20), unique=True, nullable=True)
    
    # Rewards
    xp_bonus: Mapped[int] = mapped_column(Integer, default=10)
    completion_badge_id: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    
    # Timestamps
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)


class CampaignParticipant(Base):
    __tablename__ = "campaign_participants"

    id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    campaign_id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("campaigns.id"), nullable=False)
    user_id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    # Participation stats
    readings_submitted: Mapped[int] = mapped_column(Integer, default=0)
    verified_readings: Mapped[int] = mapped_column(Integer, default=0)
    xp_earned: Mapped[int] = mapped_column(Integer, default=0)

    # Status
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    # Timestamps
    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    last_reading_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    __table_args__ = (
        UniqueConstraint("campaign_id", "user_id", name="unique_participant"),
    )


class Device(Base):
    __tablename__ = "devices"
    
    id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    meter_id: Mapped[Optional[UUID]] = mapped_column(UUID(as_uuid=True), ForeignKey("meters.id"), nullable=True)
    
    device_id: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    device_type: Mapped[str] = mapped_column(String(50), default="meterpi")
    firmware_version: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    
    # Status
    is_online: Mapped[bool] = mapped_column(Boolean, default=False)
    last_seen_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    last_reading_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    
    # Config
    config: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)
    
    # Timestamps
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)


class APIKey(Base):
    __tablename__ = "api_keys"
    
    id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    
    key_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    key_prefix: Mapped[str] = mapped_column(String(10), nullable=False)
    name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    
    # Limits
    rate_limit: Mapped[int] = mapped_column(Integer, default=60)
    request_count: Mapped[int] = mapped_column(Integer, default=0)
    last_used_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    
    # Status
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    expires_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)


class Webhook(Base):
    __tablename__ = "webhooks"

    id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    url: Mapped[str] = mapped_column(String(500), nullable=False)
    events: Mapped[dict] = mapped_column(JSONB, nullable=False)
    secret: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)

    # Status
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    failure_count: Mapped[int] = mapped_column(Integer, default=0)
    last_triggered_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    last_success_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)


class ActivityLog(Base):
    __tablename__ = "activity_logs"

    id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    activity_type: Mapped[str] = mapped_column(String(50), nullable=False)  # reading, verification, xp_gain, badge_earned, level_up, streak
    description: Mapped[str] = mapped_column(String(500), nullable=False)
    metadata: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)  # Extra data like xp_amount, badge_name, etc.

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    # Indexes
    __table_args__ = (
        Index("idx_activity_logs_user_id", "user_id"),
        Index("idx_activity_logs_created_at", "created_at"),
        Index("idx_activity_logs_activity_type", "activity_type"),
    )


class Subscription(Base):
    __tablename__ = "subscriptions"

    id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, unique=True)

    # Stripe details
    stripe_subscription_id: Mapped[Optional[str]] = mapped_column(String(255), nullable=True, unique=True)
    stripe_price_id: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

    # Subscription details
    tier: Mapped[str] = mapped_column(String(20), nullable=False, default="free")  # free, neighbor, block, district
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="active")  # active, canceled, past_due, incomplete, trialing

    # Billing period
    current_period_start: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    current_period_end: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    cancel_at_period_end: Mapped[bool] = mapped_column(Boolean, default=False)
    canceled_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    # Trial
    trial_start: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    trial_end: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    # Timestamps
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    # Indexes
    __table_args__ = (
        Index("idx_subscriptions_user_id", "user_id"),
        Index("idx_subscriptions_stripe_subscription_id", "stripe_subscription_id"),
        Index("idx_subscriptions_status", "status"),
    )


class EmailVerification(Base):
    __tablename__ = "email_verifications"

    id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    token: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    used: Mapped[bool] = mapped_column(Boolean, default=False)
    used_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    # Indexes
    __table_args__ = (
        Index("idx_email_verifications_token", "token"),
        Index("idx_email_verifications_user_id", "user_id"),
    )


class PasswordReset(Base):
    __tablename__ = "password_resets"

    id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    token: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    used: Mapped[bool] = mapped_column(Boolean, default=False)
    used_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    # Indexes
    __table_args__ = (
        Index("idx_password_resets_token", "token"),
        Index("idx_password_resets_user_id", "user_id"),
    )


class DeviceToken(Base):
    """Push notification device tokens"""
    __tablename__ = "device_tokens"

    id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    device_token: Mapped[str] = mapped_column(String(255), nullable=False)
    device_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    device_model: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    os_version: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    last_used_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    __table_args__ = (
        UniqueConstraint("user_id", "device_token", name="unique_user_device"),
        Index("idx_device_tokens_user_id", "user_id"),
    )


class NotificationPreference(Base):
    """User notification preferences"""
    __tablename__ = "notification_preferences"

    id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, unique=True)

    # Notification types
    reading_verified: Mapped[bool] = mapped_column(Boolean, default=True)
    verification_needed: Mapped[bool] = mapped_column(Boolean, default=True)
    streak_reminder: Mapped[bool] = mapped_column(Boolean, default=True)
    streak_milestone: Mapped[bool] = mapped_column(Boolean, default=True)
    badge_earned: Mapped[bool] = mapped_column(Boolean, default=True)
    level_up: Mapped[bool] = mapped_column(Boolean, default=True)
    campaign_updates: Mapped[bool] = mapped_column(Boolean, default=True)
    weekly_digest: Mapped[bool] = mapped_column(Boolean, default=True)

    # Quiet hours (UTC)
    quiet_hours_start: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)  # 0-23
    quiet_hours_end: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)  # 0-23

    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)
