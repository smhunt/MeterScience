"""
Activity Log API endpoints
"""

from datetime import datetime
from typing import Optional, List
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..models import ActivityLog, User
from ..services.auth import get_current_user

router = APIRouter()


# Pydantic schemas
class ActivityResponse(BaseModel):
    id: UUID
    user_id: UUID
    activity_type: str
    description: str
    metadata: Optional[dict]
    created_at: datetime

    class Config:
        from_attributes = True


class ActivityListResponse(BaseModel):
    activities: List[ActivityResponse]
    total: int
    page: int
    per_page: int


@router.get("/", response_model=ActivityListResponse)
async def list_activities(
    activity_type: Optional[str] = None,
    page: int = Query(1, ge=1),
    per_page: int = Query(50, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """List activity logs for the current user"""

    query = select(ActivityLog).where(ActivityLog.user_id == current_user.id)

    # Filter by activity type if provided
    if activity_type:
        query = query.where(ActivityLog.activity_type == activity_type)

    # Count total
    count_query = select(func.count()).select_from(query.subquery())
    total = (await db.execute(count_query)).scalar()

    # Paginate (newest first)
    query = query.order_by(ActivityLog.created_at.desc())
    query = query.offset((page - 1) * per_page).limit(per_page)

    result = await db.execute(query)
    activities = result.scalars().all()

    return ActivityListResponse(
        activities=activities,
        total=total,
        page=page,
        per_page=per_page
    )


# Helper function to log activity
async def log_activity(
    db: AsyncSession,
    user_id: UUID,
    activity_type: str,
    description: str,
    metadata: Optional[dict] = None
) -> ActivityLog:
    """
    Helper function to create an activity log entry.

    Args:
        db: Database session
        user_id: User ID
        activity_type: Type of activity (reading, verification, xp_gain, badge_earned, level_up, streak)
        description: Human-readable description
        metadata: Additional data (xp_amount, badge_name, etc.)

    Returns:
        ActivityLog object
    """
    activity = ActivityLog(
        user_id=user_id,
        activity_type=activity_type,
        description=description,
        metadata=metadata or {}
    )

    db.add(activity)
    await db.flush()  # Flush to get ID without committing

    return activity
