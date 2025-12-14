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
    
    # Subscription
    subscription_tier: Mapped[str] = mapped_column(String(20), default="free")
    subscription_expires_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    stripe_customer_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    
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
