"""
Campaigns API endpoints

Neighborhood campaigns for coordinated meter reading efforts.
"""

from datetime import datetime, timezone
from typing import Optional, List
from uuid import UUID
import secrets

from fastapi import APIRouter, Depends, HTTPException, status, Query
from pydantic import BaseModel, Field
from sqlalchemy import select, and_, or_, func, String
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..models import Campaign, CampaignParticipant, User, Reading, Meter
from ..services.auth import get_current_user

router = APIRouter()


# Pydantic schemas
class CampaignCreate(BaseModel):
    name: str = Field(..., min_length=3, max_length=200)
    description: Optional[str] = None
    center_latitude: Optional[float] = None
    center_longitude: Optional[float] = None
    radius_meters: Optional[float] = Field(None, ge=100, le=50000)
    postal_codes: Optional[List[str]] = None
    target_meter_count: int = Field(20, ge=5, le=1000)
    target_readings_per_meter: int = Field(30, ge=7, le=365)
    meter_types: List[str] = ["electric"]
    start_date: datetime
    end_date: datetime
    reading_schedule: Optional[str] = None  # daily, weekly, etc.
    is_public: bool = True
    xp_bonus: int = Field(10, ge=0, le=100)


class CampaignUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=3, max_length=200)
    description: Optional[str] = None
    target_meter_count: Optional[int] = Field(None, ge=5, le=1000)
    target_readings_per_meter: Optional[int] = Field(None, ge=7, le=365)
    end_date: Optional[datetime] = None
    is_active: Optional[bool] = None
    is_public: Optional[bool] = None
    xp_bonus: Optional[int] = Field(None, ge=0, le=100)


class CampaignResponse(BaseModel):
    id: UUID
    organizer_id: UUID
    name: str
    description: Optional[str]
    center_latitude: Optional[float]
    center_longitude: Optional[float]
    radius_meters: Optional[float]
    postal_codes: Optional[list]
    target_meter_count: int
    target_readings_per_meter: int
    meter_types: list
    participant_count: int
    meters_registered: int
    total_readings: int
    verified_readings: int
    start_date: datetime
    end_date: datetime
    reading_schedule: Optional[str]
    is_active: bool
    is_public: bool
    invite_code: Optional[str]
    xp_bonus: int
    completion_badge_id: Optional[str]
    created_at: datetime
    updated_at: datetime
    # Computed fields
    is_organizer: bool = False
    is_participant: bool = False
    progress_percent: float = 0.0

    class Config:
        from_attributes = True


class ParticipantResponse(BaseModel):
    id: UUID
    user_id: UUID
    display_name: str
    avatar_emoji: str
    readings_submitted: int
    verified_readings: int
    xp_earned: int
    is_active: bool
    joined_at: datetime
    last_reading_at: Optional[datetime]


class CampaignListResponse(BaseModel):
    campaigns: List[CampaignResponse]
    total: int


class LeaderboardEntry(BaseModel):
    rank: int
    user_id: UUID
    display_name: str
    avatar_emoji: str
    readings_submitted: int
    verified_readings: int
    xp_earned: int


class CampaignLeaderboardResponse(BaseModel):
    campaign_id: UUID
    campaign_name: str
    entries: List[LeaderboardEntry]
    my_rank: Optional[int]


class JoinCampaignRequest(BaseModel):
    invite_code: Optional[str] = None


def calculate_progress(campaign: Campaign) -> float:
    """Calculate campaign progress as percentage"""
    target = campaign.target_meter_count * campaign.target_readings_per_meter
    if target == 0:
        return 0.0
    return min(100.0, round((campaign.total_readings / target) * 100, 1))


@router.get("/my/organized", response_model=List[CampaignResponse])
async def get_my_organized_campaigns(
    is_active: Optional[bool] = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get campaigns organized by current user"""

    query = select(Campaign).where(Campaign.organizer_id == current_user.id)

    if is_active is not None:
        query = query.where(Campaign.is_active == is_active)

    query = query.order_by(Campaign.created_at.desc())

    result = await db.execute(query)
    campaigns = result.scalars().all()

    return [
        CampaignResponse(
            id=c.id,
            organizer_id=c.organizer_id,
            name=c.name,
            description=c.description,
            center_latitude=c.center_latitude,
            center_longitude=c.center_longitude,
            radius_meters=c.radius_meters,
            postal_codes=c.postal_codes,
            target_meter_count=c.target_meter_count,
            target_readings_per_meter=c.target_readings_per_meter,
            meter_types=c.meter_types,
            participant_count=c.participant_count,
            meters_registered=c.meters_registered,
            total_readings=c.total_readings,
            verified_readings=c.verified_readings,
            start_date=c.start_date,
            end_date=c.end_date,
            reading_schedule=c.reading_schedule,
            is_active=c.is_active,
            is_public=c.is_public,
            invite_code=c.invite_code,
            xp_bonus=c.xp_bonus,
            completion_badge_id=c.completion_badge_id,
            created_at=c.created_at,
            updated_at=c.updated_at,
            is_organizer=True,
            is_participant=True,
            progress_percent=calculate_progress(c)
        )
        for c in campaigns
    ]


@router.get("/my/joined", response_model=List[CampaignResponse])
async def get_my_joined_campaigns(
    is_active: Optional[bool] = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get campaigns the current user has joined"""

    # Get campaign IDs where user is participant
    subquery = select(CampaignParticipant.campaign_id).where(
        CampaignParticipant.user_id == current_user.id
    )

    query = select(Campaign).where(Campaign.id.in_(subquery))

    if is_active is not None:
        query = query.where(Campaign.is_active == is_active)

    query = query.order_by(Campaign.created_at.desc())

    result = await db.execute(query)
    campaigns = result.scalars().all()

    return [
        CampaignResponse(
            id=c.id,
            organizer_id=c.organizer_id,
            name=c.name,
            description=c.description,
            center_latitude=c.center_latitude,
            center_longitude=c.center_longitude,
            radius_meters=c.radius_meters,
            postal_codes=c.postal_codes,
            target_meter_count=c.target_meter_count,
            target_readings_per_meter=c.target_readings_per_meter,
            meter_types=c.meter_types,
            participant_count=c.participant_count,
            meters_registered=c.meters_registered,
            total_readings=c.total_readings,
            verified_readings=c.verified_readings,
            start_date=c.start_date,
            end_date=c.end_date,
            reading_schedule=c.reading_schedule,
            is_active=c.is_active,
            is_public=c.is_public,
            invite_code=c.invite_code if c.organizer_id == current_user.id else None,
            xp_bonus=c.xp_bonus,
            completion_badge_id=c.completion_badge_id,
            created_at=c.created_at,
            updated_at=c.updated_at,
            is_organizer=c.organizer_id == current_user.id,
            is_participant=True,
            progress_percent=calculate_progress(c)
        )
        for c in campaigns
    ]


@router.get("/", response_model=CampaignListResponse)
async def list_campaigns(
    filter_type: str = Query("public", regex="^(public|nearby|joined|organized)$"),
    postal_code: Optional[str] = None,
    meter_type: Optional[str] = None,
    is_active: bool = True,
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=50),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """List campaigns with various filters"""

    query = select(Campaign)

    if filter_type == "public":
        query = query.where(Campaign.is_public == True)
        if is_active:
            query = query.where(Campaign.is_active == True)
            query = query.where(Campaign.end_date >= datetime.now(timezone.utc))

    elif filter_type == "nearby":
        # Filter by postal code if provided or user's postal code
        pc = postal_code or current_user.postal_code
        if pc:
            # Match campaigns that include this postal code or nearby ones
            query = query.where(
                or_(
                    Campaign.postal_codes.contains([pc]),
                    func.left(Campaign.postal_codes.cast(String), 3) == pc[:3] if len(pc) >= 3 else True
                )
            )
        query = query.where(Campaign.is_public == True)
        if is_active:
            query = query.where(Campaign.is_active == True)

    elif filter_type == "joined":
        # Get campaigns where user is a participant
        subquery = select(CampaignParticipant.campaign_id).where(
            CampaignParticipant.user_id == current_user.id
        )
        query = query.where(Campaign.id.in_(subquery))

    elif filter_type == "organized":
        # Get campaigns organized by user
        query = query.where(Campaign.organizer_id == current_user.id)

    if meter_type:
        query = query.where(Campaign.meter_types.contains([meter_type]))

    # Count total
    count_query = select(func.count()).select_from(query.subquery())
    total = (await db.execute(count_query)).scalar()

    # Paginate and order
    query = query.order_by(Campaign.created_at.desc())
    query = query.offset((page - 1) * per_page).limit(per_page)

    result = await db.execute(query)
    campaigns = result.scalars().all()

    # Get user's participation status for each campaign
    campaign_ids = [c.id for c in campaigns]
    if campaign_ids:
        participation_query = await db.execute(
            select(CampaignParticipant.campaign_id).where(
                and_(
                    CampaignParticipant.campaign_id.in_(campaign_ids),
                    CampaignParticipant.user_id == current_user.id
                )
            )
        )
        participating_ids = {row[0] for row in participation_query.fetchall()}
    else:
        participating_ids = set()

    # Build response
    campaign_responses = []
    for c in campaigns:
        response = CampaignResponse(
            id=c.id,
            organizer_id=c.organizer_id,
            name=c.name,
            description=c.description,
            center_latitude=c.center_latitude,
            center_longitude=c.center_longitude,
            radius_meters=c.radius_meters,
            postal_codes=c.postal_codes,
            target_meter_count=c.target_meter_count,
            target_readings_per_meter=c.target_readings_per_meter,
            meter_types=c.meter_types,
            participant_count=c.participant_count,
            meters_registered=c.meters_registered,
            total_readings=c.total_readings,
            verified_readings=c.verified_readings,
            start_date=c.start_date,
            end_date=c.end_date,
            reading_schedule=c.reading_schedule,
            is_active=c.is_active,
            is_public=c.is_public,
            invite_code=c.invite_code if c.organizer_id == current_user.id else None,
            xp_bonus=c.xp_bonus,
            completion_badge_id=c.completion_badge_id,
            created_at=c.created_at,
            updated_at=c.updated_at,
            is_organizer=c.organizer_id == current_user.id,
            is_participant=c.id in participating_ids,
            progress_percent=calculate_progress(c)
        )
        campaign_responses.append(response)

    return CampaignListResponse(campaigns=campaign_responses, total=total)


@router.post("/", response_model=CampaignResponse, status_code=status.HTTP_201_CREATED)
async def create_campaign(
    campaign_data: CampaignCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Create a new neighborhood campaign"""

    # Validate dates
    if campaign_data.end_date <= campaign_data.start_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="End date must be after start date"
        )

    # Validate meter types
    valid_types = ["electric", "gas", "water", "solar", "other"]
    for mt in campaign_data.meter_types:
        if mt not in valid_types:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid meter type: {mt}. Must be one of: {', '.join(valid_types)}"
            )

    # Generate invite code for private campaigns
    invite_code = None
    if not campaign_data.is_public:
        invite_code = secrets.token_urlsafe(8)[:10].upper()

    campaign = Campaign(
        organizer_id=current_user.id,
        name=campaign_data.name,
        description=campaign_data.description,
        center_latitude=campaign_data.center_latitude,
        center_longitude=campaign_data.center_longitude,
        radius_meters=campaign_data.radius_meters,
        postal_codes=campaign_data.postal_codes,
        target_meter_count=campaign_data.target_meter_count,
        target_readings_per_meter=campaign_data.target_readings_per_meter,
        meter_types=campaign_data.meter_types,
        start_date=campaign_data.start_date,
        end_date=campaign_data.end_date,
        reading_schedule=campaign_data.reading_schedule,
        is_public=campaign_data.is_public,
        invite_code=invite_code,
        xp_bonus=campaign_data.xp_bonus,
    )

    db.add(campaign)
    await db.flush()  # Flush to get the campaign ID

    # Auto-join organizer as participant
    participant = CampaignParticipant(
        campaign_id=campaign.id,
        user_id=current_user.id,
    )
    db.add(participant)

    # Update participant count
    campaign.participant_count = 1

    await db.commit()
    await db.refresh(campaign)

    return CampaignResponse(
        id=campaign.id,
        organizer_id=campaign.organizer_id,
        name=campaign.name,
        description=campaign.description,
        center_latitude=campaign.center_latitude,
        center_longitude=campaign.center_longitude,
        radius_meters=campaign.radius_meters,
        postal_codes=campaign.postal_codes,
        target_meter_count=campaign.target_meter_count,
        target_readings_per_meter=campaign.target_readings_per_meter,
        meter_types=campaign.meter_types,
        participant_count=campaign.participant_count,
        meters_registered=campaign.meters_registered,
        total_readings=campaign.total_readings,
        verified_readings=campaign.verified_readings,
        start_date=campaign.start_date,
        end_date=campaign.end_date,
        reading_schedule=campaign.reading_schedule,
        is_active=campaign.is_active,
        is_public=campaign.is_public,
        invite_code=campaign.invite_code,
        xp_bonus=campaign.xp_bonus,
        completion_badge_id=campaign.completion_badge_id,
        created_at=campaign.created_at,
        updated_at=campaign.updated_at,
        is_organizer=True,
        is_participant=True,
        progress_percent=0.0
    )


@router.get("/{campaign_id}", response_model=CampaignResponse)
async def get_campaign(
    campaign_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get campaign details"""

    result = await db.execute(
        select(Campaign).where(Campaign.id == campaign_id)
    )
    campaign = result.scalar_one_or_none()

    if not campaign:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Campaign not found"
        )

    # Check if user is participant
    participation = await db.execute(
        select(CampaignParticipant).where(
            and_(
                CampaignParticipant.campaign_id == campaign_id,
                CampaignParticipant.user_id == current_user.id
            )
        )
    )
    is_participant = participation.scalar_one_or_none() is not None

    # Private campaigns require participation or organizer status
    if not campaign.is_public and not is_participant and campaign.organizer_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This is a private campaign. Use invite code to join."
        )

    return CampaignResponse(
        id=campaign.id,
        organizer_id=campaign.organizer_id,
        name=campaign.name,
        description=campaign.description,
        center_latitude=campaign.center_latitude,
        center_longitude=campaign.center_longitude,
        radius_meters=campaign.radius_meters,
        postal_codes=campaign.postal_codes,
        target_meter_count=campaign.target_meter_count,
        target_readings_per_meter=campaign.target_readings_per_meter,
        meter_types=campaign.meter_types,
        participant_count=campaign.participant_count,
        meters_registered=campaign.meters_registered,
        total_readings=campaign.total_readings,
        verified_readings=campaign.verified_readings,
        start_date=campaign.start_date,
        end_date=campaign.end_date,
        reading_schedule=campaign.reading_schedule,
        is_active=campaign.is_active,
        is_public=campaign.is_public,
        invite_code=campaign.invite_code if campaign.organizer_id == current_user.id else None,
        xp_bonus=campaign.xp_bonus,
        completion_badge_id=campaign.completion_badge_id,
        created_at=campaign.created_at,
        updated_at=campaign.updated_at,
        is_organizer=campaign.organizer_id == current_user.id,
        is_participant=is_participant,
        progress_percent=calculate_progress(campaign)
    )


@router.patch("/{campaign_id}", response_model=CampaignResponse)
async def update_campaign(
    campaign_id: UUID,
    update_data: CampaignUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Update a campaign (organizer only)"""

    result = await db.execute(
        select(Campaign).where(Campaign.id == campaign_id)
    )
    campaign = result.scalar_one_or_none()

    if not campaign:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Campaign not found"
        )

    if campaign.organizer_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the organizer can update this campaign"
        )

    # Apply updates
    update_dict = update_data.model_dump(exclude_unset=True)
    for field, value in update_dict.items():
        setattr(campaign, field, value)

    await db.commit()
    await db.refresh(campaign)

    return CampaignResponse(
        id=campaign.id,
        organizer_id=campaign.organizer_id,
        name=campaign.name,
        description=campaign.description,
        center_latitude=campaign.center_latitude,
        center_longitude=campaign.center_longitude,
        radius_meters=campaign.radius_meters,
        postal_codes=campaign.postal_codes,
        target_meter_count=campaign.target_meter_count,
        target_readings_per_meter=campaign.target_readings_per_meter,
        meter_types=campaign.meter_types,
        participant_count=campaign.participant_count,
        meters_registered=campaign.meters_registered,
        total_readings=campaign.total_readings,
        verified_readings=campaign.verified_readings,
        start_date=campaign.start_date,
        end_date=campaign.end_date,
        reading_schedule=campaign.reading_schedule,
        is_active=campaign.is_active,
        is_public=campaign.is_public,
        invite_code=campaign.invite_code,
        xp_bonus=campaign.xp_bonus,
        completion_badge_id=campaign.completion_badge_id,
        created_at=campaign.created_at,
        updated_at=campaign.updated_at,
        is_organizer=True,
        is_participant=True,
        progress_percent=calculate_progress(campaign)
    )


@router.delete("/{campaign_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_campaign(
    campaign_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Delete a campaign (organizer only)"""

    result = await db.execute(
        select(Campaign).where(Campaign.id == campaign_id)
    )
    campaign = result.scalar_one_or_none()

    if not campaign:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Campaign not found"
        )

    if campaign.organizer_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the organizer can delete this campaign"
        )

    # Delete all participants first
    await db.execute(
        select(CampaignParticipant).where(CampaignParticipant.campaign_id == campaign_id)
    )

    from sqlalchemy import delete
    await db.execute(
        delete(CampaignParticipant).where(CampaignParticipant.campaign_id == campaign_id)
    )

    await db.delete(campaign)
    await db.commit()


@router.post("/{campaign_id}/join", response_model=ParticipantResponse)
async def join_campaign(
    campaign_id: UUID,
    join_request: JoinCampaignRequest = JoinCampaignRequest(),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Join a campaign"""

    result = await db.execute(
        select(Campaign).where(Campaign.id == campaign_id)
    )
    campaign = result.scalar_one_or_none()

    if not campaign:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Campaign not found"
        )

    # Check if campaign is active
    if not campaign.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This campaign is no longer active"
        )

    # Check if campaign has ended
    if campaign.end_date < datetime.now(timezone.utc):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This campaign has ended"
        )

    # For private campaigns, require invite code
    if not campaign.is_public:
        if not join_request.invite_code:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Invite code required for private campaigns"
            )
        if join_request.invite_code.upper() != campaign.invite_code:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Invalid invite code"
            )

    # Check if already participating
    existing = await db.execute(
        select(CampaignParticipant).where(
            and_(
                CampaignParticipant.campaign_id == campaign_id,
                CampaignParticipant.user_id == current_user.id
            )
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Already participating in this campaign"
        )

    # Create participation
    participant = CampaignParticipant(
        campaign_id=campaign_id,
        user_id=current_user.id,
    )
    db.add(participant)

    # Update campaign participant count
    campaign.participant_count += 1

    # Award XP for joining
    current_user.xp += 5

    await db.commit()
    await db.refresh(participant)

    return ParticipantResponse(
        id=participant.id,
        user_id=current_user.id,
        display_name=current_user.display_name,
        avatar_emoji=current_user.avatar_emoji,
        readings_submitted=0,
        verified_readings=0,
        xp_earned=0,
        is_active=True,
        joined_at=participant.joined_at,
        last_reading_at=None
    )


@router.post("/{campaign_id}/leave", status_code=status.HTTP_204_NO_CONTENT)
async def leave_campaign(
    campaign_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Leave a campaign"""

    result = await db.execute(
        select(Campaign).where(Campaign.id == campaign_id)
    )
    campaign = result.scalar_one_or_none()

    if not campaign:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Campaign not found"
        )

    # Organizer cannot leave their own campaign
    if campaign.organizer_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Organizers cannot leave their own campaign. Delete it instead."
        )

    # Find participation
    participation_result = await db.execute(
        select(CampaignParticipant).where(
            and_(
                CampaignParticipant.campaign_id == campaign_id,
                CampaignParticipant.user_id == current_user.id
            )
        )
    )
    participant = participation_result.scalar_one_or_none()

    if not participant:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Not participating in this campaign"
        )

    # Remove participation
    await db.delete(participant)

    # Update campaign participant count
    campaign.participant_count = max(0, campaign.participant_count - 1)

    await db.commit()


@router.get("/{campaign_id}/participants", response_model=List[ParticipantResponse])
async def get_campaign_participants(
    campaign_id: UUID,
    page: int = Query(1, ge=1),
    per_page: int = Query(50, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get campaign participants"""

    # Verify campaign exists and user has access
    result = await db.execute(
        select(Campaign).where(Campaign.id == campaign_id)
    )
    campaign = result.scalar_one_or_none()

    if not campaign:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Campaign not found"
        )

    # Check access for private campaigns
    if not campaign.is_public and campaign.organizer_id != current_user.id:
        participation = await db.execute(
            select(CampaignParticipant).where(
                and_(
                    CampaignParticipant.campaign_id == campaign_id,
                    CampaignParticipant.user_id == current_user.id
                )
            )
        )
        if not participation.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied to private campaign"
            )

    # Get participants with user info
    query = (
        select(CampaignParticipant, User)
        .join(User, CampaignParticipant.user_id == User.id)
        .where(CampaignParticipant.campaign_id == campaign_id)
        .order_by(CampaignParticipant.readings_submitted.desc())
        .offset((page - 1) * per_page)
        .limit(per_page)
    )

    result = await db.execute(query)
    rows = result.all()

    participants = []
    for participant, user in rows:
        participants.append(ParticipantResponse(
            id=participant.id,
            user_id=user.id,
            display_name=user.display_name,
            avatar_emoji=user.avatar_emoji,
            readings_submitted=participant.readings_submitted,
            verified_readings=participant.verified_readings,
            xp_earned=participant.xp_earned,
            is_active=participant.is_active,
            joined_at=participant.joined_at,
            last_reading_at=participant.last_reading_at
        ))

    return participants


@router.get("/{campaign_id}/leaderboard", response_model=CampaignLeaderboardResponse)
async def get_campaign_leaderboard(
    campaign_id: UUID,
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get campaign leaderboard"""

    # Verify campaign exists
    result = await db.execute(
        select(Campaign).where(Campaign.id == campaign_id)
    )
    campaign = result.scalar_one_or_none()

    if not campaign:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Campaign not found"
        )

    # Get top participants
    query = (
        select(CampaignParticipant, User)
        .join(User, CampaignParticipant.user_id == User.id)
        .where(CampaignParticipant.campaign_id == campaign_id)
        .order_by(CampaignParticipant.readings_submitted.desc())
        .limit(limit)
    )

    result = await db.execute(query)
    rows = result.all()

    entries = []
    for rank, (participant, user) in enumerate(rows, 1):
        entries.append(LeaderboardEntry(
            rank=rank,
            user_id=user.id,
            display_name=user.display_name,
            avatar_emoji=user.avatar_emoji,
            readings_submitted=participant.readings_submitted,
            verified_readings=participant.verified_readings,
            xp_earned=participant.xp_earned
        ))

    # Find current user's rank
    my_rank = None
    for entry in entries:
        if entry.user_id == current_user.id:
            my_rank = entry.rank
            break

    # If not in top N, find actual rank
    if my_rank is None:
        rank_query = await db.execute(
            select(func.count())
            .select_from(CampaignParticipant)
            .where(
                and_(
                    CampaignParticipant.campaign_id == campaign_id,
                    CampaignParticipant.readings_submitted > (
                        select(CampaignParticipant.readings_submitted)
                        .where(
                            and_(
                                CampaignParticipant.campaign_id == campaign_id,
                                CampaignParticipant.user_id == current_user.id
                            )
                        )
                        .scalar_subquery()
                    )
                )
            )
        )
        count = rank_query.scalar()
        if count is not None:
            my_rank = count + 1

    return CampaignLeaderboardResponse(
        campaign_id=campaign_id,
        campaign_name=campaign.name,
        entries=entries,
        my_rank=my_rank
    )


@router.post("/{campaign_id}/regenerate-invite", response_model=dict)
async def regenerate_invite_code(
    campaign_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Regenerate invite code for a private campaign (organizer only)"""

    result = await db.execute(
        select(Campaign).where(Campaign.id == campaign_id)
    )
    campaign = result.scalar_one_or_none()

    if not campaign:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Campaign not found"
        )

    if campaign.organizer_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the organizer can regenerate the invite code"
        )

    if campaign.is_public:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Public campaigns don't have invite codes"
        )

    # Generate new invite code
    campaign.invite_code = secrets.token_urlsafe(8)[:10].upper()

    await db.commit()

    return {"invite_code": campaign.invite_code}
