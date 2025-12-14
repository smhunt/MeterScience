"""
Users API endpoints
"""

from datetime import datetime
from typing import Optional
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..models import User
from ..services.auth import get_current_user, create_access_token, hash_password, verify_password

router = APIRouter()


class UserCreate(BaseModel):
    email: Optional[EmailStr] = None
    display_name: str
    password: Optional[str] = None


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserUpdate(BaseModel):
    display_name: Optional[str] = None
    avatar_emoji: Optional[str] = None
    postal_code: Optional[str] = None
    country: Optional[str] = None


class UserResponse(BaseModel):
    id: UUID
    email: Optional[str]
    display_name: str
    avatar_emoji: str
    level: int
    xp: int
    total_readings: int
    verified_readings: int
    verifications_performed: int
    streak_days: int
    trust_score: int
    badges: list
    subscription_tier: str
    referral_code: Optional[str]
    referral_count: int
    created_at: datetime
    
    class Config:
        from_attributes = True


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse


def generate_referral_code() -> str:
    """Generate a unique referral code"""
    chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    import random
    return ''.join(random.choice(chars) for _ in range(6))


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register(
    user_data: UserCreate,
    db: AsyncSession = Depends(get_db)
):
    """Register a new user"""
    
    # Check if email exists
    if user_data.email:
        existing = await db.execute(
            select(User).where(User.email == user_data.email)
        )
        if existing.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already registered"
            )
    
    # Generate unique referral code
    referral_code = generate_referral_code()
    while True:
        check = await db.execute(
            select(User).where(User.referral_code == referral_code)
        )
        if not check.scalar_one_or_none():
            break
        referral_code = generate_referral_code()
    
    # Create user
    user = User(
        email=user_data.email,
        display_name=user_data.display_name,
        password_hash=hash_password(user_data.password) if user_data.password else None,
        referral_code=referral_code,
    )
    
    db.add(user)
    await db.commit()
    await db.refresh(user)
    
    # Generate token
    token = create_access_token({"sub": str(user.id)})
    
    return TokenResponse(access_token=token, user=user)


@router.post("/login", response_model=TokenResponse)
async def login(
    credentials: UserLogin,
    db: AsyncSession = Depends(get_db)
):
    """Login with email and password"""
    
    result = await db.execute(
        select(User).where(User.email == credentials.email)
    )
    user = result.scalar_one_or_none()
    
    if not user or not user.password_hash:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials"
        )
    
    if not verify_password(credentials.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials"
        )
    
    # Update last login
    user.last_login_at = datetime.utcnow()
    await db.commit()
    
    token = create_access_token({"sub": str(user.id)})
    
    return TokenResponse(access_token=token, user=user)


@router.get("/me", response_model=UserResponse)
async def get_current_user_info(
    current_user: User = Depends(get_current_user)
):
    """Get current user profile"""
    return current_user


@router.patch("/me", response_model=UserResponse)
async def update_current_user(
    user_update: UserUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Update current user profile"""
    
    if user_update.display_name:
        current_user.display_name = user_update.display_name
    if user_update.avatar_emoji:
        current_user.avatar_emoji = user_update.avatar_emoji
    if user_update.postal_code:
        current_user.postal_code = user_update.postal_code
    if user_update.country:
        current_user.country = user_update.country
    
    await db.commit()
    await db.refresh(current_user)
    
    return current_user


@router.post("/referral/{code}")
async def apply_referral(
    code: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Apply a referral code"""
    
    # Can't use own code
    if current_user.referral_code == code:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot use your own referral code"
        )
    
    # Already referred
    if current_user.referred_by_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Already used a referral code"
        )
    
    # Find referrer
    result = await db.execute(
        select(User).where(User.referral_code == code.upper())
    )
    referrer = result.scalar_one_or_none()
    
    if not referrer:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Invalid referral code"
        )
    
    # Apply referral
    current_user.referred_by_id = referrer.id
    referrer.referral_count += 1
    referrer.xp += 50  # Bonus XP for referral
    
    # TODO: Apply referral rewards based on count
    
    await db.commit()
    
    return {"message": "Referral applied successfully"}


@router.get("/leaderboard")
async def get_leaderboard(
    scope: str = "global",  # global, local, campaign
    postal_code: Optional[str] = None,
    campaign_id: Optional[UUID] = None,
    limit: int = 50,
    db: AsyncSession = Depends(get_db)
):
    """Get leaderboard"""
    
    query = select(User).order_by(User.total_readings.desc()).limit(limit)
    
    if scope == "local" and postal_code:
        query = query.where(User.postal_code.startswith(postal_code[:3]))
    
    result = await db.execute(query)
    users = result.scalars().all()
    
    return [
        {
            "rank": i + 1,
            "user_id": str(u.id),
            "display_name": u.display_name,
            "avatar_emoji": u.avatar_emoji,
            "level": u.level,
            "total_readings": u.total_readings,
            "streak_days": u.streak_days,
            "trust_score": u.trust_score,
        }
        for i, u in enumerate(users)
    ]
