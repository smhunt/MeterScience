"""
Statistics API endpoints
"""

from datetime import datetime, timezone, timedelta
from typing import Optional, List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, Query
from pydantic import BaseModel
from sqlalchemy import select, func, and_, case
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..models import User, Meter, Reading, Campaign
from ..services.auth import get_current_user

router = APIRouter()


class UserStatsResponse(BaseModel):
    user_id: UUID
    display_name: str
    level: int
    xp: int
    xp_to_next_level: int
    total_readings: int
    verified_readings: int
    verifications_performed: int
    streak_days: int
    trust_score: int
    badges: list
    subscription_tier: str
    meters_count: int
    readings_this_month: int
    readings_this_week: int
    average_confidence: float
    member_since: datetime
    rank: Optional[int] = None


class MeterStatsResponse(BaseModel):
    meter_id: UUID
    meter_name: str
    meter_type: str
    total_readings: int
    verified_readings: int
    average_confidence: float
    average_daily_usage: Optional[float]
    usage_this_month: Optional[float]
    usage_last_month: Optional[float]
    usage_trend_percent: Optional[float]
    first_reading_at: Optional[datetime]
    last_reading_at: Optional[datetime]


class NeighborhoodStatsResponse(BaseModel):
    postal_code_prefix: str
    meter_type: str
    household_count: int
    total_readings: int
    average_daily_usage: float
    median_daily_usage: Optional[float]
    percentile_25: Optional[float]
    percentile_75: Optional[float]
    your_average_daily_usage: Optional[float]
    your_percentile: Optional[int]
    comparison: str  # "below_average", "average", "above_average"


class PlatformStatsResponse(BaseModel):
    total_users: int
    total_meters: int
    total_readings: int
    readings_today: int
    readings_this_week: int
    readings_this_month: int
    active_campaigns: int
    countries_represented: int
    top_regions: List[dict]


class UsageTrendResponse(BaseModel):
    meter_id: UUID
    period: str  # "daily", "weekly", "monthly"
    data: List[dict]


@router.get("/me", response_model=UserStatsResponse)
async def get_my_stats(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get comprehensive stats for the current user"""

    # Count meters
    meters_result = await db.execute(
        select(func.count(Meter.id)).where(Meter.user_id == current_user.id)
    )
    meters_count = meters_result.scalar() or 0

    # Readings this week
    week_ago = datetime.now(timezone.utc) - timedelta(days=7)
    week_readings_result = await db.execute(
        select(func.count(Reading.id)).where(
            and_(
                Reading.user_id == current_user.id,
                Reading.captured_at >= week_ago
            )
        )
    )
    readings_this_week = week_readings_result.scalar() or 0

    # Readings this month
    month_start = datetime.now(timezone.utc).replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    month_readings_result = await db.execute(
        select(func.count(Reading.id)).where(
            and_(
                Reading.user_id == current_user.id,
                Reading.captured_at >= month_start
            )
        )
    )
    readings_this_month = month_readings_result.scalar() or 0

    # Average confidence
    confidence_result = await db.execute(
        select(func.avg(Reading.confidence)).where(Reading.user_id == current_user.id)
    )
    avg_confidence = confidence_result.scalar() or 0.0

    # Get user's rank by total readings
    rank_result = await db.execute(
        select(func.count(User.id)).where(User.total_readings > current_user.total_readings)
    )
    rank = (rank_result.scalar() or 0) + 1

    # Calculate XP to next level
    xp_to_next = (current_user.level * 100 + 50) - current_user.xp

    return UserStatsResponse(
        user_id=current_user.id,
        display_name=current_user.display_name,
        level=current_user.level,
        xp=current_user.xp,
        xp_to_next_level=xp_to_next,
        total_readings=current_user.total_readings,
        verified_readings=current_user.verified_readings,
        verifications_performed=current_user.verifications_performed,
        streak_days=current_user.streak_days,
        trust_score=current_user.trust_score,
        badges=current_user.badges or [],
        subscription_tier=current_user.subscription_tier,
        meters_count=meters_count,
        readings_this_month=readings_this_month,
        readings_this_week=readings_this_week,
        average_confidence=round(avg_confidence, 3),
        member_since=current_user.created_at,
        rank=rank
    )


@router.get("/meters/{meter_id}", response_model=MeterStatsResponse)
async def get_meter_stats(
    meter_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get detailed stats for a specific meter"""

    # Get meter
    meter_result = await db.execute(
        select(Meter).where(
            and_(Meter.id == meter_id, Meter.user_id == current_user.id)
        )
    )
    meter = meter_result.scalar_one_or_none()

    if not meter:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Meter not found"
        )

    # Basic stats
    stats_result = await db.execute(
        select(
            func.count(Reading.id).label("total"),
            func.avg(Reading.confidence).label("avg_confidence"),
            func.min(Reading.captured_at).label("first_reading"),
            func.max(Reading.captured_at).label("last_reading"),
        ).where(Reading.meter_id == meter_id)
    )
    stats = stats_result.one()

    # Verified count
    verified_result = await db.execute(
        select(func.count(Reading.id)).where(
            and_(
                Reading.meter_id == meter_id,
                Reading.verification_status == "verified"
            )
        )
    )
    verified_count = verified_result.scalar() or 0

    # Calculate usage stats
    now = datetime.now(timezone.utc)
    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    last_month_start = (month_start - timedelta(days=1)).replace(day=1)

    # This month's usage
    this_month_result = await db.execute(
        select(func.sum(Reading.usage_since_last)).where(
            and_(
                Reading.meter_id == meter_id,
                Reading.captured_at >= month_start,
                Reading.usage_since_last > 0
            )
        )
    )
    usage_this_month = this_month_result.scalar()

    # Last month's usage
    last_month_result = await db.execute(
        select(func.sum(Reading.usage_since_last)).where(
            and_(
                Reading.meter_id == meter_id,
                Reading.captured_at >= last_month_start,
                Reading.captured_at < month_start,
                Reading.usage_since_last > 0
            )
        )
    )
    usage_last_month = last_month_result.scalar()

    # Average daily usage (last 30 days)
    thirty_days_ago = now - timedelta(days=30)
    daily_usage_result = await db.execute(
        select(func.sum(Reading.usage_since_last)).where(
            and_(
                Reading.meter_id == meter_id,
                Reading.captured_at >= thirty_days_ago,
                Reading.usage_since_last > 0
            )
        )
    )
    total_usage_30d = daily_usage_result.scalar() or 0
    avg_daily_usage = total_usage_30d / 30 if total_usage_30d else None

    # Usage trend
    trend_percent = None
    if usage_this_month and usage_last_month and usage_last_month > 0:
        trend_percent = ((usage_this_month - usage_last_month) / usage_last_month) * 100

    return MeterStatsResponse(
        meter_id=meter.id,
        meter_name=meter.name,
        meter_type=meter.meter_type,
        total_readings=stats.total or 0,
        verified_readings=verified_count,
        average_confidence=round(stats.avg_confidence or 0, 3),
        average_daily_usage=round(avg_daily_usage, 2) if avg_daily_usage else None,
        usage_this_month=round(usage_this_month, 2) if usage_this_month else None,
        usage_last_month=round(usage_last_month, 2) if usage_last_month else None,
        usage_trend_percent=round(trend_percent, 1) if trend_percent else None,
        first_reading_at=stats.first_reading,
        last_reading_at=stats.last_reading
    )


@router.get("/neighborhood", response_model=NeighborhoodStatsResponse)
async def get_neighborhood_stats(
    meter_type: str = "electric",
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get aggregate stats for your neighborhood (requires subscription)"""

    # Check subscription
    if current_user.subscription_tier == "free":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Upgrade to Neighbor tier or higher to access neighborhood stats"
        )

    # Get user's postal code prefix (first 3 chars)
    postal_prefix = None
    if current_user.postal_code:
        postal_prefix = current_user.postal_code[:3]
    else:
        # Try to get from user's meters
        meter_result = await db.execute(
            select(Meter.postal_code).where(
                and_(
                    Meter.user_id == current_user.id,
                    Meter.postal_code.isnot(None)
                )
            ).limit(1)
        )
        meter_postal = meter_result.scalar_one_or_none()
        if meter_postal:
            postal_prefix = meter_postal[:3]

    if not postal_prefix:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No postal code found. Please update your profile or meter settings."
        )

    # Get neighborhood meters
    neighborhood_meters = await db.execute(
        select(Meter.id).where(
            and_(
                Meter.postal_code.startswith(postal_prefix),
                Meter.meter_type == meter_type
            )
        )
    )
    meter_ids = [m[0] for m in neighborhood_meters.fetchall()]

    if len(meter_ids) < 5:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Not enough data in your area (minimum 5 households required for privacy)"
        )

    # Calculate neighborhood stats (last 30 days)
    thirty_days_ago = datetime.now(timezone.utc) - timedelta(days=30)

    # Get total readings
    total_readings_result = await db.execute(
        select(func.count(Reading.id)).where(
            and_(
                Reading.meter_id.in_(meter_ids),
                Reading.captured_at >= thirty_days_ago
            )
        )
    )
    total_readings = total_readings_result.scalar() or 0

    # Get average daily usage per meter
    usage_per_meter = await db.execute(
        select(
            Reading.meter_id,
            func.sum(Reading.usage_since_last).label("total_usage")
        ).where(
            and_(
                Reading.meter_id.in_(meter_ids),
                Reading.captured_at >= thirty_days_ago,
                Reading.usage_since_last > 0
            )
        ).group_by(Reading.meter_id)
    )
    usage_data = usage_per_meter.fetchall()

    # Calculate average daily usage
    daily_usages = [row.total_usage / 30 for row in usage_data if row.total_usage]

    if not daily_usages:
        avg_daily = 0
        median_daily = None
        p25 = None
        p75 = None
    else:
        daily_usages.sort()
        avg_daily = sum(daily_usages) / len(daily_usages)
        median_daily = daily_usages[len(daily_usages) // 2]
        p25 = daily_usages[int(len(daily_usages) * 0.25)] if len(daily_usages) >= 4 else None
        p75 = daily_usages[int(len(daily_usages) * 0.75)] if len(daily_usages) >= 4 else None

    # Get user's own usage
    user_meters_result = await db.execute(
        select(Meter.id).where(
            and_(
                Meter.user_id == current_user.id,
                Meter.meter_type == meter_type
            )
        )
    )
    user_meter_ids = [m[0] for m in user_meters_result.fetchall()]

    user_usage_result = await db.execute(
        select(func.sum(Reading.usage_since_last)).where(
            and_(
                Reading.meter_id.in_(user_meter_ids),
                Reading.captured_at >= thirty_days_ago,
                Reading.usage_since_last > 0
            )
        )
    )
    user_total_usage = user_usage_result.scalar() or 0
    user_daily_usage = user_total_usage / 30 if user_total_usage else None

    # Calculate percentile
    user_percentile = None
    comparison = "average"
    if user_daily_usage and daily_usages:
        below_count = sum(1 for u in daily_usages if u < user_daily_usage)
        user_percentile = int((below_count / len(daily_usages)) * 100)

        if user_percentile < 33:
            comparison = "below_average"
        elif user_percentile > 66:
            comparison = "above_average"

    return NeighborhoodStatsResponse(
        postal_code_prefix=postal_prefix,
        meter_type=meter_type,
        household_count=len(meter_ids),
        total_readings=total_readings,
        average_daily_usage=round(avg_daily, 2),
        median_daily_usage=round(median_daily, 2) if median_daily else None,
        percentile_25=round(p25, 2) if p25 else None,
        percentile_75=round(p75, 2) if p75 else None,
        your_average_daily_usage=round(user_daily_usage, 2) if user_daily_usage else None,
        your_percentile=user_percentile,
        comparison=comparison
    )


@router.get("/platform", response_model=PlatformStatsResponse)
async def get_platform_stats(
    db: AsyncSession = Depends(get_db)
):
    """Get overall platform statistics (public)"""

    now = datetime.now(timezone.utc)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    week_ago = now - timedelta(days=7)
    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)

    # Total users
    users_result = await db.execute(select(func.count(User.id)))
    total_users = users_result.scalar() or 0

    # Total meters
    meters_result = await db.execute(select(func.count(Meter.id)))
    total_meters = meters_result.scalar() or 0

    # Total readings
    readings_result = await db.execute(select(func.count(Reading.id)))
    total_readings = readings_result.scalar() or 0

    # Readings today
    today_result = await db.execute(
        select(func.count(Reading.id)).where(Reading.captured_at >= today_start)
    )
    readings_today = today_result.scalar() or 0

    # Readings this week
    week_result = await db.execute(
        select(func.count(Reading.id)).where(Reading.captured_at >= week_ago)
    )
    readings_this_week = week_result.scalar() or 0

    # Readings this month
    month_result = await db.execute(
        select(func.count(Reading.id)).where(Reading.captured_at >= month_start)
    )
    readings_this_month = month_result.scalar() or 0

    # Active campaigns
    campaigns_result = await db.execute(
        select(func.count(Campaign.id)).where(
            and_(
                Campaign.is_active == True,
                Campaign.end_date >= now
            )
        )
    )
    active_campaigns = campaigns_result.scalar() or 0

    # Countries represented
    countries_result = await db.execute(
        select(func.count(func.distinct(User.country))).where(User.country.isnot(None))
    )
    countries = countries_result.scalar() or 0

    # Top regions by readings
    region_expr = func.left(Meter.postal_code, 3)
    top_regions_result = await db.execute(
        select(
            region_expr.label("region"),
            func.count(Reading.id).label("reading_count")
        )
        .join(Reading, Reading.meter_id == Meter.id)
        .where(Meter.postal_code.isnot(None))
        .group_by(region_expr)
        .order_by(func.count(Reading.id).desc())
        .limit(10)
    )
    top_regions = [
        {"region": row.region, "readings": row.reading_count}
        for row in top_regions_result.fetchall()
    ]

    return PlatformStatsResponse(
        total_users=total_users,
        total_meters=total_meters,
        total_readings=total_readings,
        readings_today=readings_today,
        readings_this_week=readings_this_week,
        readings_this_month=readings_this_month,
        active_campaigns=active_campaigns,
        countries_represented=countries,
        top_regions=top_regions
    )


@router.get("/usage/trends", response_model=UsageTrendResponse)
async def get_usage_trends(
    meter_id: UUID,
    period: str = Query("daily", regex="^(daily|weekly|monthly)$"),
    days: int = Query(30, ge=7, le=365),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get usage trends for a meter over time"""

    # Verify meter ownership
    meter_result = await db.execute(
        select(Meter).where(
            and_(Meter.id == meter_id, Meter.user_id == current_user.id)
        )
    )
    meter = meter_result.scalar_one_or_none()

    if not meter:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Meter not found"
        )

    now = datetime.now(timezone.utc)
    start_date = now - timedelta(days=days)

    # Get readings with usage data
    readings_result = await db.execute(
        select(Reading.captured_at, Reading.usage_since_last, Reading.numeric_value)
        .where(
            and_(
                Reading.meter_id == meter_id,
                Reading.captured_at >= start_date,
                Reading.usage_since_last.isnot(None)
            )
        )
        .order_by(Reading.captured_at)
    )
    readings = readings_result.fetchall()

    # Aggregate by period
    data = []

    if period == "daily":
        # Group by date
        daily_data = {}
        for reading in readings:
            date_key = reading.captured_at.strftime("%Y-%m-%d")
            if date_key not in daily_data:
                daily_data[date_key] = {"usage": 0, "count": 0}
            if reading.usage_since_last and reading.usage_since_last > 0:
                daily_data[date_key]["usage"] += reading.usage_since_last
                daily_data[date_key]["count"] += 1

        for date_key in sorted(daily_data.keys()):
            data.append({
                "date": date_key,
                "usage": round(daily_data[date_key]["usage"], 2),
                "readings": daily_data[date_key]["count"]
            })

    elif period == "weekly":
        # Group by week
        weekly_data = {}
        for reading in readings:
            # Get ISO week
            week_key = reading.captured_at.strftime("%Y-W%W")
            if week_key not in weekly_data:
                weekly_data[week_key] = {"usage": 0, "count": 0}
            if reading.usage_since_last and reading.usage_since_last > 0:
                weekly_data[week_key]["usage"] += reading.usage_since_last
                weekly_data[week_key]["count"] += 1

        for week_key in sorted(weekly_data.keys()):
            data.append({
                "week": week_key,
                "usage": round(weekly_data[week_key]["usage"], 2),
                "readings": weekly_data[week_key]["count"]
            })

    elif period == "monthly":
        # Group by month
        monthly_data = {}
        for reading in readings:
            month_key = reading.captured_at.strftime("%Y-%m")
            if month_key not in monthly_data:
                monthly_data[month_key] = {"usage": 0, "count": 0}
            if reading.usage_since_last and reading.usage_since_last > 0:
                monthly_data[month_key]["usage"] += reading.usage_since_last
                monthly_data[month_key]["count"] += 1

        for month_key in sorted(monthly_data.keys()):
            data.append({
                "month": month_key,
                "usage": round(monthly_data[month_key]["usage"], 2),
                "readings": monthly_data[month_key]["count"]
            })

    return UsageTrendResponse(
        meter_id=meter_id,
        period=period,
        data=data
    )


@router.get("/comparison")
async def get_usage_comparison(
    meter_type: str = "electric",
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Compare your usage against regional averages"""

    # Get user's meters of this type
    user_meters = await db.execute(
        select(Meter.id).where(
            and_(
                Meter.user_id == current_user.id,
                Meter.meter_type == meter_type
            )
        )
    )
    user_meter_ids = [m[0] for m in user_meters.fetchall()]

    if not user_meter_ids:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No {meter_type} meters found"
        )

    thirty_days_ago = datetime.now(timezone.utc) - timedelta(days=30)

    # Your usage
    your_usage_result = await db.execute(
        select(func.sum(Reading.usage_since_last)).where(
            and_(
                Reading.meter_id.in_(user_meter_ids),
                Reading.captured_at >= thirty_days_ago,
                Reading.usage_since_last > 0
            )
        )
    )
    your_total = your_usage_result.scalar() or 0
    your_daily_avg = your_total / 30

    # Platform average
    platform_result = await db.execute(
        select(
            func.sum(Reading.usage_since_last).label("total"),
            func.count(func.distinct(Reading.meter_id)).label("meter_count")
        ).join(Meter, Meter.id == Reading.meter_id).where(
            and_(
                Meter.meter_type == meter_type,
                Reading.captured_at >= thirty_days_ago,
                Reading.usage_since_last > 0
            )
        )
    )
    platform_stats = platform_result.one()

    platform_avg = 0
    if platform_stats.meter_count and platform_stats.total:
        platform_avg = (platform_stats.total / platform_stats.meter_count) / 30

    # Calculate comparison
    diff_percent = 0
    if platform_avg > 0:
        diff_percent = ((your_daily_avg - platform_avg) / platform_avg) * 100

    return {
        "meter_type": meter_type,
        "your_daily_average": round(your_daily_avg, 2),
        "platform_daily_average": round(platform_avg, 2),
        "difference_percent": round(diff_percent, 1),
        "comparison": "below" if diff_percent < -10 else "above" if diff_percent > 10 else "similar",
        "meters_compared": platform_stats.meter_count or 0,
        "period_days": 30
    }
