"""
Readings API endpoints
"""

from datetime import datetime
from typing import Optional, List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, Query
from pydantic import BaseModel, Field
from sqlalchemy import select, and_, func
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..models import Reading, Meter, User, VerificationVote
from ..services.auth import get_current_user

router = APIRouter()


# Pydantic schemas
class ReadingCreate(BaseModel):
    meter_id: UUID
    raw_value: str
    normalized_value: str
    numeric_value: Optional[float] = None
    confidence: float
    all_candidates: Optional[List[dict]] = None
    processing_ms: Optional[int] = None
    image_hash: Optional[str] = None
    image_brightness: Optional[float] = None
    image_blur: Optional[float] = None
    bounding_box: Optional[dict] = None
    device_model: Optional[str] = None
    os_version: Optional[str] = None
    app_version: Optional[str] = None
    capture_method: Optional[str] = "live"
    timezone_offset: Optional[int] = None


class ReadingResponse(BaseModel):
    id: UUID
    meter_id: UUID
    user_id: UUID
    raw_value: str
    normalized_value: str
    numeric_value: Optional[float]
    confidence: float
    verification_status: str
    usage_since_last: Optional[float]
    days_since_last: Optional[float]
    captured_at: datetime
    created_at: datetime
    
    class Config:
        from_attributes = True


class ReadingListResponse(BaseModel):
    readings: List[ReadingResponse]
    total: int
    page: int
    per_page: int


@router.post("/", response_model=ReadingResponse, status_code=status.HTTP_201_CREATED)
async def create_reading(
    reading: ReadingCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Create a new meter reading"""
    
    # Verify meter belongs to user
    meter_query = await db.execute(
        select(Meter).where(
            and_(Meter.id == reading.meter_id, Meter.user_id == current_user.id)
        )
    )
    meter = meter_query.scalar_one_or_none()
    
    if not meter:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Meter not found or doesn't belong to you"
        )
    
    # Get previous reading for usage calculation
    prev_query = await db.execute(
        select(Reading)
        .where(Reading.meter_id == reading.meter_id)
        .order_by(Reading.captured_at.desc())
        .limit(1)
    )
    prev_reading = prev_query.scalar_one_or_none()
    
    # Calculate usage
    usage_since_last = None
    days_since_last = None
    flagged = False
    flag_reason = None
    
    if prev_reading and reading.numeric_value and prev_reading.numeric_value:
        usage_since_last = reading.numeric_value - prev_reading.numeric_value
        days_since_last = (datetime.utcnow() - prev_reading.captured_at).total_seconds() / 86400
        
        # Flag anomalies
        if usage_since_last < 0:
            flagged = True
            flag_reason = "Reading decreased from previous"
        elif days_since_last > 0:
            daily_usage = usage_since_last / days_since_last
            # TODO: Compare to historical average
    
    # Create reading
    new_reading = Reading(
        meter_id=reading.meter_id,
        user_id=current_user.id,
        raw_value=reading.raw_value,
        normalized_value=reading.normalized_value,
        numeric_value=reading.numeric_value,
        confidence=reading.confidence,
        all_candidates=reading.all_candidates,
        processing_ms=reading.processing_ms,
        image_hash=reading.image_hash,
        image_brightness=reading.image_brightness,
        image_blur=reading.image_blur,
        bounding_box=reading.bounding_box,
        device_model=reading.device_model,
        os_version=reading.os_version,
        app_version=reading.app_version,
        capture_method=reading.capture_method,
        timezone_offset=reading.timezone_offset,
        usage_since_last=usage_since_last,
        days_since_last=days_since_last,
        flagged_for_review=flagged,
        flag_reason=flag_reason,
    )
    
    db.add(new_reading)
    
    # Update user stats
    current_user.total_readings += 1
    current_user.xp += 10  # XP for reading
    current_user.last_reading_date = datetime.utcnow()
    
    # Update streak
    # TODO: Implement streak logic
    
    # Update meter
    meter.last_read_at = datetime.utcnow()
    if reading.normalized_value:
        samples = meter.sample_readings or []
        samples.append(reading.normalized_value)
        if len(samples) > 50:
            samples = samples[-50:]
        meter.sample_readings = samples
    
    await db.commit()
    await db.refresh(new_reading)
    
    return new_reading


@router.get("/", response_model=ReadingListResponse)
async def list_readings(
    meter_id: Optional[UUID] = None,
    from_date: Optional[datetime] = None,
    to_date: Optional[datetime] = None,
    verification_status: Optional[str] = None,
    page: int = Query(1, ge=1),
    per_page: int = Query(50, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """List readings for the current user"""
    
    query = select(Reading).where(Reading.user_id == current_user.id)
    
    if meter_id:
        query = query.where(Reading.meter_id == meter_id)
    if from_date:
        query = query.where(Reading.captured_at >= from_date)
    if to_date:
        query = query.where(Reading.captured_at <= to_date)
    if verification_status:
        query = query.where(Reading.verification_status == verification_status)
    
    # Count total
    count_query = select(func.count()).select_from(query.subquery())
    total = (await db.execute(count_query)).scalar()
    
    # Paginate
    query = query.order_by(Reading.captured_at.desc())
    query = query.offset((page - 1) * per_page).limit(per_page)
    
    result = await db.execute(query)
    readings = result.scalars().all()
    
    return ReadingListResponse(
        readings=readings,
        total=total,
        page=page,
        per_page=per_page
    )


@router.get("/latest", response_model=ReadingResponse)
async def get_latest_reading(
    meter_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get the latest reading for a meter"""
    
    query = await db.execute(
        select(Reading)
        .where(and_(Reading.meter_id == meter_id, Reading.user_id == current_user.id))
        .order_by(Reading.captured_at.desc())
        .limit(1)
    )
    reading = query.scalar_one_or_none()
    
    if not reading:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No readings found for this meter"
        )
    
    return reading


@router.get("/{reading_id}", response_model=ReadingResponse)
async def get_reading(
    reading_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get a specific reading"""
    
    query = await db.execute(
        select(Reading).where(Reading.id == reading_id)
    )
    reading = query.scalar_one_or_none()
    
    if not reading:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Reading not found"
        )
    
    # Check access (owner or neighbor with subscription)
    if reading.user_id != current_user.id:
        # TODO: Check subscription tier for neighbor access
        if current_user.subscription_tier == "free":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Upgrade to access neighbor readings"
            )
    
    return reading


@router.delete("/{reading_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_reading(
    reading_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Delete a reading"""
    
    query = await db.execute(
        select(Reading).where(
            and_(Reading.id == reading_id, Reading.user_id == current_user.id)
        )
    )
    reading = query.scalar_one_or_none()
    
    if not reading:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Reading not found"
        )
    
    await db.delete(reading)
    await db.commit()


# Hardware endpoint (for MeterPi devices)
@router.post("/hardware", response_model=ReadingResponse, status_code=status.HTTP_201_CREATED)
async def create_hardware_reading(
    reading: ReadingCreate,
    device_id: str = Query(...),
    db: AsyncSession = Depends(get_db)
):
    """Create reading from hardware device (MeterPi)"""
    
    from ..models import Device
    
    # Verify device
    device_query = await db.execute(
        select(Device).where(Device.device_id == device_id)
    )
    device = device_query.scalar_one_or_none()
    
    if not device:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Unknown device"
        )
    
    # Get user from device
    user_query = await db.execute(
        select(User).where(User.id == device.user_id)
    )
    user = user_query.scalar_one_or_none()
    
    # Create reading (reuse create_reading logic)
    # ... similar to above but with device context
    
    new_reading = Reading(
        meter_id=reading.meter_id,
        user_id=device.user_id,
        raw_value=reading.raw_value,
        normalized_value=reading.normalized_value,
        numeric_value=reading.numeric_value,
        confidence=reading.confidence,
        capture_method="hardware",
        device_model=f"meterpi_{device.device_type}",
        app_version=device.firmware_version,
    )
    
    db.add(new_reading)
    
    # Update device status
    device.last_reading_at = datetime.utcnow()
    device.last_seen_at = datetime.utcnow()
    device.is_online = True
    
    await db.commit()
    await db.refresh(new_reading)
    
    return new_reading
