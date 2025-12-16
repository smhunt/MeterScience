"""
Meters API endpoints
"""

from datetime import datetime
from typing import Optional, List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..models import Meter, User
from ..services.auth import get_current_user

router = APIRouter()


class MeterCreate(BaseModel):
    name: str
    meter_type: str  # electric, gas, water, solar, other
    utility_provider: Optional[str] = None
    account_number: Optional[str] = None
    postal_code: Optional[str] = None
    country: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    digit_count: int = 6
    has_decimal_point: bool = False
    decimal_places: int = 0


class MeterUpdate(BaseModel):
    name: Optional[str] = None
    meter_type: Optional[str] = None
    utility_provider: Optional[str] = None
    account_number: Optional[str] = None
    postal_code: Optional[str] = None
    country: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    digit_count: Optional[int] = None
    has_decimal_point: Optional[bool] = None
    decimal_places: Optional[int] = None
    is_active: Optional[bool] = None


class MeterCalibration(BaseModel):
    bounding_box: Optional[dict] = None
    sample_readings: Optional[List[str]] = None
    calibration_image_hash: Optional[str] = None


class MeterResponse(BaseModel):
    id: UUID
    user_id: UUID
    name: str
    meter_type: str
    utility_provider: Optional[str]
    account_number: Optional[str]
    postal_code: Optional[str]
    country: Optional[str]
    latitude: Optional[float]
    longitude: Optional[float]
    digit_count: int
    has_decimal_point: bool
    decimal_places: int
    bounding_box: Optional[dict]
    sample_readings: Optional[list]
    average_confidence: float
    is_active: bool
    last_read_at: Optional[datetime]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


@router.get("/", response_model=List[MeterResponse])
async def list_meters(
    meter_type: Optional[str] = None,
    is_active: Optional[bool] = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """List all meters for the current user"""
    query = select(Meter).where(Meter.user_id == current_user.id)

    if meter_type:
        query = query.where(Meter.meter_type == meter_type)
    if is_active is not None:
        query = query.where(Meter.is_active == is_active)

    query = query.order_by(Meter.created_at.desc())

    result = await db.execute(query)
    meters = result.scalars().all()

    return meters


@router.post("/", response_model=MeterResponse, status_code=status.HTTP_201_CREATED)
async def create_meter(
    meter_data: MeterCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Create a new meter"""

    # Validate meter type
    valid_types = ["electric", "gas", "water", "solar", "other"]
    if meter_data.meter_type not in valid_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid meter_type. Must be one of: {', '.join(valid_types)}"
        )

    meter = Meter(
        user_id=current_user.id,
        name=meter_data.name,
        meter_type=meter_data.meter_type,
        utility_provider=meter_data.utility_provider,
        account_number=meter_data.account_number,
        postal_code=meter_data.postal_code,
        country=meter_data.country,
        latitude=meter_data.latitude,
        longitude=meter_data.longitude,
        digit_count=meter_data.digit_count,
        has_decimal_point=meter_data.has_decimal_point,
        decimal_places=meter_data.decimal_places,
    )

    db.add(meter)
    await db.commit()
    await db.refresh(meter)

    return meter


@router.get("/{meter_id}", response_model=MeterResponse)
async def get_meter(
    meter_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get a specific meter by ID"""

    result = await db.execute(
        select(Meter).where(
            Meter.id == meter_id,
            Meter.user_id == current_user.id
        )
    )
    meter = result.scalar_one_or_none()

    if not meter:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Meter not found"
        )

    return meter


@router.patch("/{meter_id}", response_model=MeterResponse)
async def update_meter(
    meter_id: UUID,
    meter_update: MeterUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Update a meter"""

    result = await db.execute(
        select(Meter).where(
            Meter.id == meter_id,
            Meter.user_id == current_user.id
        )
    )
    meter = result.scalar_one_or_none()

    if not meter:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Meter not found"
        )

    # Validate meter_type if provided
    if meter_update.meter_type is not None:
        valid_types = ["electric", "gas", "water", "solar", "other"]
        if meter_update.meter_type not in valid_types:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid meter_type. Must be one of: {', '.join(valid_types)}"
            )

    # Update fields
    update_data = meter_update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(meter, field, value)

    await db.commit()
    await db.refresh(meter)

    return meter


@router.delete("/{meter_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_meter(
    meter_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Delete a meter"""

    result = await db.execute(
        select(Meter).where(
            Meter.id == meter_id,
            Meter.user_id == current_user.id
        )
    )
    meter = result.scalar_one_or_none()

    if not meter:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Meter not found"
        )

    await db.delete(meter)
    await db.commit()

    return None


@router.post("/{meter_id}/calibrate", response_model=MeterResponse)
async def calibrate_meter(
    meter_id: UUID,
    calibration: MeterCalibration,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Update meter calibration data (bounding box, sample readings)"""

    result = await db.execute(
        select(Meter).where(
            Meter.id == meter_id,
            Meter.user_id == current_user.id
        )
    )
    meter = result.scalar_one_or_none()

    if not meter:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Meter not found"
        )

    if calibration.bounding_box is not None:
        meter.bounding_box = calibration.bounding_box

    if calibration.sample_readings is not None:
        # Append to existing samples, keep last 10
        existing = meter.sample_readings or []
        combined = existing + calibration.sample_readings
        meter.sample_readings = combined[-10:]

    if calibration.calibration_image_hash is not None:
        meter.calibration_image_hash = calibration.calibration_image_hash

    await db.commit()
    await db.refresh(meter)

    return meter


@router.get("/{meter_id}/stats")
async def get_meter_stats(
    meter_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get statistics for a specific meter"""

    result = await db.execute(
        select(Meter).where(
            Meter.id == meter_id,
            Meter.user_id == current_user.id
        )
    )
    meter = result.scalar_one_or_none()

    if not meter:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Meter not found"
        )

    # Count readings
    from ..models import Reading
    from sqlalchemy import func

    readings_result = await db.execute(
        select(
            func.count(Reading.id).label("total_readings"),
            func.avg(Reading.confidence).label("avg_confidence"),
            func.min(Reading.captured_at).label("first_reading"),
            func.max(Reading.captured_at).label("last_reading"),
        ).where(Reading.meter_id == meter_id)
    )
    stats = readings_result.one()

    # Get verified count
    verified_result = await db.execute(
        select(func.count(Reading.id)).where(
            Reading.meter_id == meter_id,
            Reading.verification_status == "verified"
        )
    )
    verified_count = verified_result.scalar() or 0

    return {
        "meter_id": str(meter_id),
        "meter_name": meter.name,
        "meter_type": meter.meter_type,
        "total_readings": stats.total_readings or 0,
        "verified_readings": verified_count,
        "average_confidence": round(stats.avg_confidence or 0, 3),
        "first_reading_at": stats.first_reading,
        "last_reading_at": stats.last_reading,
        "is_active": meter.is_active,
    }
