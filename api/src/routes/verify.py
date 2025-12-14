"""
Verification API endpoints

Community verification system for meter readings.
Users can vote on readings (correct/incorrect/unclear) to build trust.
"""

from datetime import datetime, timezone, timedelta
from typing import Optional, List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, Query
from pydantic import BaseModel
from sqlalchemy import select, func, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..models import User, Reading, VerificationVote, Meter
from ..services.auth import get_current_user

router = APIRouter()

# Constants
VOTES_REQUIRED = 3  # Minimum votes to finalize verification
CONSENSUS_THRESHOLD = 0.67  # 67% agreement required
XP_FOR_VERIFICATION = 5  # XP awarded for each verification
XP_BONUS_CONSENSUS = 10  # Bonus XP if vote matches consensus


class VoteCreate(BaseModel):
    vote: str  # "correct", "incorrect", "unclear"
    suggested_value: Optional[str] = None  # If incorrect, what should it be?


class VoteResponse(BaseModel):
    id: UUID
    reading_id: UUID
    verifier_id: UUID
    vote: str
    suggested_value: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


class ReadingForVerification(BaseModel):
    id: UUID
    meter_type: str
    raw_value: str
    normalized_value: str
    confidence: float
    image_url: Optional[str]
    captured_at: datetime
    votes_count: int
    postal_code_prefix: Optional[str]


class VerificationQueueResponse(BaseModel):
    readings: List[ReadingForVerification]
    total_available: int


class VerificationStatusResponse(BaseModel):
    reading_id: UUID
    status: str  # "pending", "verified", "rejected", "disputed"
    total_votes: int
    votes_correct: int
    votes_incorrect: int
    votes_unclear: int
    consensus_reached: bool
    your_vote: Optional[str]


class VerificationHistoryResponse(BaseModel):
    total_verifications: int
    verifications_this_week: int
    consensus_matches: int
    consensus_rate: float
    xp_earned: int
    recent_votes: List[VoteResponse]


@router.get("/queue", response_model=VerificationQueueResponse)
async def get_verification_queue(
    meter_type: Optional[str] = None,
    limit: int = Query(10, ge=1, le=50),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get readings available for verification.

    Returns readings that:
    - Are not owned by the current user
    - Have not been voted on by the current user
    - Are still pending verification
    - Have less than VOTES_REQUIRED votes
    """

    # Subquery for readings already voted on by this user
    voted_subquery = select(VerificationVote.reading_id).where(
        VerificationVote.verifier_id == current_user.id
    )

    # Subquery for vote counts
    vote_count_subquery = (
        select(
            VerificationVote.reading_id,
            func.count(VerificationVote.id).label("vote_count")
        )
        .group_by(VerificationVote.reading_id)
        .subquery()
    )

    # Main query
    query = (
        select(Reading, Meter.meter_type, Meter.postal_code)
        .join(Meter, Meter.id == Reading.meter_id)
        .outerjoin(vote_count_subquery, vote_count_subquery.c.reading_id == Reading.id)
        .where(
            and_(
                Reading.user_id != current_user.id,  # Not own readings
                Reading.id.notin_(voted_subquery),  # Not already voted
                Reading.verification_status == "pending",  # Still pending
                or_(
                    vote_count_subquery.c.vote_count.is_(None),
                    vote_count_subquery.c.vote_count < VOTES_REQUIRED
                )
            )
        )
    )

    if meter_type:
        query = query.where(Meter.meter_type == meter_type)

    # Prioritize readings with higher confidence (more likely correct)
    # and those with some votes already (closer to resolution)
    query = query.order_by(
        vote_count_subquery.c.vote_count.desc().nulls_last(),
        Reading.confidence.desc()
    ).limit(limit)

    result = await db.execute(query)
    rows = result.fetchall()

    # Get vote counts for each reading
    reading_ids = [row[0].id for row in rows]
    vote_counts = {}
    if reading_ids:
        counts_result = await db.execute(
            select(
                VerificationVote.reading_id,
                func.count(VerificationVote.id)
            )
            .where(VerificationVote.reading_id.in_(reading_ids))
            .group_by(VerificationVote.reading_id)
        )
        vote_counts = {row[0]: row[1] for row in counts_result.fetchall()}

    # Count total available
    total_query = (
        select(func.count(Reading.id))
        .where(
            and_(
                Reading.user_id != current_user.id,
                Reading.id.notin_(voted_subquery),
                Reading.verification_status == "pending"
            )
        )
    )
    total_result = await db.execute(total_query)
    total_available = total_result.scalar() or 0

    readings = []
    for row in rows:
        reading = row[0]
        meter_type_val = row[1]
        postal_code = row[2]

        readings.append(ReadingForVerification(
            id=reading.id,
            meter_type=meter_type_val,
            raw_value=reading.raw_value,
            normalized_value=reading.normalized_value,
            confidence=reading.confidence,
            image_url=reading.image_url,
            captured_at=reading.captured_at,
            votes_count=vote_counts.get(reading.id, 0),
            postal_code_prefix=postal_code[:3] if postal_code else None
        ))

    return VerificationQueueResponse(
        readings=readings,
        total_available=total_available
    )


@router.post("/{reading_id}/vote", response_model=VoteResponse)
async def vote_on_reading(
    reading_id: UUID,
    vote_data: VoteCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Submit a verification vote for a reading.

    Vote options:
    - "correct": The reading value appears accurate
    - "incorrect": The reading value is wrong (provide suggested_value)
    - "unclear": Cannot determine if correct (image quality, etc.)
    """

    # Validate vote value
    valid_votes = ["correct", "incorrect", "unclear"]
    if vote_data.vote not in valid_votes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid vote. Must be one of: {', '.join(valid_votes)}"
        )

    # If voting incorrect, require suggested value
    if vote_data.vote == "incorrect" and not vote_data.suggested_value:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Please provide suggested_value when voting 'incorrect'"
        )

    # Get the reading
    reading_result = await db.execute(
        select(Reading).where(Reading.id == reading_id)
    )
    reading = reading_result.scalar_one_or_none()

    if not reading:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Reading not found"
        )

    # Cannot vote on own readings
    if reading.user_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot verify your own readings"
        )

    # Check if already voted
    existing_vote = await db.execute(
        select(VerificationVote).where(
            and_(
                VerificationVote.reading_id == reading_id,
                VerificationVote.verifier_id == current_user.id
            )
        )
    )
    if existing_vote.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You have already voted on this reading"
        )

    # Create vote
    vote = VerificationVote(
        reading_id=reading_id,
        verifier_id=current_user.id,
        vote=vote_data.vote,
        suggested_value=vote_data.suggested_value,
        verifier_trust_score=current_user.trust_score
    )
    db.add(vote)

    # Update user stats
    current_user.verifications_performed += 1
    current_user.xp += XP_FOR_VERIFICATION

    # Check if we have enough votes to finalize
    await _check_and_finalize_verification(reading, db, current_user)

    await db.commit()
    await db.refresh(vote)

    return vote


@router.get("/{reading_id}/status", response_model=VerificationStatusResponse)
async def get_verification_status(
    reading_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get the verification status of a reading."""

    # Get the reading
    reading_result = await db.execute(
        select(Reading).where(Reading.id == reading_id)
    )
    reading = reading_result.scalar_one_or_none()

    if not reading:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Reading not found"
        )

    # Get vote counts
    votes_result = await db.execute(
        select(
            VerificationVote.vote,
            func.count(VerificationVote.id)
        )
        .where(VerificationVote.reading_id == reading_id)
        .group_by(VerificationVote.vote)
    )
    vote_counts = {row[0]: row[1] for row in votes_result.fetchall()}

    votes_correct = vote_counts.get("correct", 0)
    votes_incorrect = vote_counts.get("incorrect", 0)
    votes_unclear = vote_counts.get("unclear", 0)
    total_votes = votes_correct + votes_incorrect + votes_unclear

    # Check if user has voted
    user_vote_result = await db.execute(
        select(VerificationVote.vote).where(
            and_(
                VerificationVote.reading_id == reading_id,
                VerificationVote.verifier_id == current_user.id
            )
        )
    )
    user_vote = user_vote_result.scalar_one_or_none()

    # Determine if consensus reached
    consensus_reached = False
    if total_votes >= VOTES_REQUIRED:
        max_votes = max(votes_correct, votes_incorrect)
        if max_votes / total_votes >= CONSENSUS_THRESHOLD:
            consensus_reached = True

    return VerificationStatusResponse(
        reading_id=reading_id,
        status=reading.verification_status,
        total_votes=total_votes,
        votes_correct=votes_correct,
        votes_incorrect=votes_incorrect,
        votes_unclear=votes_unclear,
        consensus_reached=consensus_reached,
        your_vote=user_vote
    )


@router.get("/history", response_model=VerificationHistoryResponse)
async def get_verification_history(
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get the current user's verification history and stats."""

    # Total verifications
    total_result = await db.execute(
        select(func.count(VerificationVote.id)).where(
            VerificationVote.verifier_id == current_user.id
        )
    )
    total_verifications = total_result.scalar() or 0

    # Verifications this week
    week_ago = datetime.now(timezone.utc) - timedelta(days=7)
    week_result = await db.execute(
        select(func.count(VerificationVote.id)).where(
            and_(
                VerificationVote.verifier_id == current_user.id,
                VerificationVote.created_at >= week_ago
            )
        )
    )
    verifications_this_week = week_result.scalar() or 0

    # Get consensus matches (votes that matched final outcome)
    # This requires checking each vote against the reading's final status
    consensus_query = await db.execute(
        select(VerificationVote, Reading.verification_status)
        .join(Reading, Reading.id == VerificationVote.reading_id)
        .where(
            and_(
                VerificationVote.verifier_id == current_user.id,
                Reading.verification_status.in_(["verified", "rejected"])
            )
        )
    )
    consensus_rows = consensus_query.fetchall()

    consensus_matches = 0
    for row in consensus_rows:
        vote = row[0]
        final_status = row[1]
        if (vote.vote == "correct" and final_status == "verified") or \
           (vote.vote == "incorrect" and final_status == "rejected"):
            consensus_matches += 1

    consensus_rate = 0.0
    if len(consensus_rows) > 0:
        consensus_rate = consensus_matches / len(consensus_rows)

    # XP earned from verifications
    xp_earned = total_verifications * XP_FOR_VERIFICATION + consensus_matches * XP_BONUS_CONSENSUS

    # Recent votes
    recent_result = await db.execute(
        select(VerificationVote)
        .where(VerificationVote.verifier_id == current_user.id)
        .order_by(VerificationVote.created_at.desc())
        .limit(limit)
    )
    recent_votes = recent_result.scalars().all()

    return VerificationHistoryResponse(
        total_verifications=total_verifications,
        verifications_this_week=verifications_this_week,
        consensus_matches=consensus_matches,
        consensus_rate=round(consensus_rate, 2),
        xp_earned=xp_earned,
        recent_votes=recent_votes
    )


@router.get("/leaderboard")
async def get_verification_leaderboard(
    period: str = Query("all", regex="^(week|month|all)$"),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db)
):
    """Get top verifiers leaderboard."""

    query = (
        select(
            User.id,
            User.display_name,
            User.avatar_emoji,
            User.trust_score,
            func.count(VerificationVote.id).label("verification_count")
        )
        .join(VerificationVote, VerificationVote.verifier_id == User.id)
    )

    # Filter by period
    if period == "week":
        week_ago = datetime.now(timezone.utc) - timedelta(days=7)
        query = query.where(VerificationVote.created_at >= week_ago)
    elif period == "month":
        month_ago = datetime.now(timezone.utc) - timedelta(days=30)
        query = query.where(VerificationVote.created_at >= month_ago)

    query = (
        query
        .group_by(User.id, User.display_name, User.avatar_emoji, User.trust_score)
        .order_by(func.count(VerificationVote.id).desc())
        .limit(limit)
    )

    result = await db.execute(query)
    rows = result.fetchall()

    return [
        {
            "rank": i + 1,
            "user_id": str(row.id),
            "display_name": row.display_name,
            "avatar_emoji": row.avatar_emoji,
            "trust_score": row.trust_score,
            "verifications": row.verification_count
        }
        for i, row in enumerate(rows)
    ]


async def _check_and_finalize_verification(
    reading: Reading,
    db: AsyncSession,
    current_user: User
):
    """
    Check if a reading has enough votes and finalize its verification status.
    Awards bonus XP to users who voted with the consensus.
    """

    # Get all votes for this reading
    votes_result = await db.execute(
        select(VerificationVote).where(VerificationVote.reading_id == reading.id)
    )
    votes = votes_result.scalars().all()

    if len(votes) < VOTES_REQUIRED:
        return  # Not enough votes yet

    # Count votes (weighted by trust score)
    weighted_correct = 0
    weighted_incorrect = 0
    total_weight = 0

    for vote in votes:
        weight = vote.verifier_trust_score or 50  # Default trust score
        total_weight += weight
        if vote.vote == "correct":
            weighted_correct += weight
        elif vote.vote == "incorrect":
            weighted_incorrect += weight

    if total_weight == 0:
        return

    # Determine outcome
    correct_ratio = weighted_correct / total_weight
    incorrect_ratio = weighted_incorrect / total_weight

    new_status = None
    winning_vote = None

    if correct_ratio >= CONSENSUS_THRESHOLD:
        new_status = "verified"
        winning_vote = "correct"
    elif incorrect_ratio >= CONSENSUS_THRESHOLD:
        new_status = "rejected"
        winning_vote = "incorrect"
    elif len(votes) >= VOTES_REQUIRED * 2:
        # If we have double the votes and still no consensus, mark as disputed
        new_status = "disputed"

    if new_status:
        reading.verification_status = new_status

        # Calculate verification score
        reading.verification_score = max(correct_ratio, incorrect_ratio)

        # Get reading owner and update their stats
        owner_result = await db.execute(
            select(User).where(User.id == reading.user_id)
        )
        owner = owner_result.scalar_one_or_none()

        if owner and new_status == "verified":
            owner.verified_readings += 1
            owner.xp += 5  # Bonus for verified reading

        # Award bonus XP to voters who matched consensus
        if winning_vote:
            for vote in votes:
                if vote.vote == winning_vote:
                    voter_result = await db.execute(
                        select(User).where(User.id == vote.verifier_id)
                    )
                    voter = voter_result.scalar_one_or_none()
                    if voter:
                        voter.xp += XP_BONUS_CONSENSUS
                        # Increase trust score for correct votes
                        voter.trust_score = min(100, voter.trust_score + 1)
                elif vote.vote != "unclear":
                    # Decrease trust score for incorrect votes
                    voter_result = await db.execute(
                        select(User).where(User.id == vote.verifier_id)
                    )
                    voter = voter_result.scalar_one_or_none()
                    if voter:
                        voter.trust_score = max(0, voter.trust_score - 1)
