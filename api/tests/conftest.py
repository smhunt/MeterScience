"""
Test fixtures and configuration
"""

import asyncio
import os
from typing import AsyncGenerator, Generator
from uuid import uuid4

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.pool import NullPool

from src.main import app
from src.database import Base, get_db
from src.models import User
from src.services.auth import hash_password, create_access_token


# Test database URL (SQLite in-memory for speed)
TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"

# Create test engine with NullPool to avoid connection issues
test_engine = create_async_engine(
    TEST_DATABASE_URL,
    echo=False,
    poolclass=NullPool,
)

test_async_session_maker = async_sessionmaker(
    test_engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)


@pytest.fixture(scope="session")
def event_loop() -> Generator:
    """Create event loop for async tests"""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(autouse=True)
async def setup_database():
    """Create tables before each test and drop after"""
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


async def override_get_db() -> AsyncGenerator[AsyncSession, None]:
    """Override database dependency for testing"""
    async with test_async_session_maker() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


# Override the dependency
app.dependency_overrides[get_db] = override_get_db


@pytest.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    """Get test database session"""
    async for session in override_get_db():
        yield session


@pytest.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    """Get test HTTP client"""
    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac


@pytest.fixture
async def test_user(db_session: AsyncSession) -> User:
    """Create a test user"""
    user = User(
        email="test@example.com",
        display_name="Test User",
        password_hash=hash_password("password123"),
        avatar_emoji="🧪",
        level=1,
        xp=0,
        total_readings=0,
        verified_readings=0,
        verifications_performed=0,
        streak_days=0,
        trust_score=50,
        badges=[],
        subscription_tier="free",
        referral_code="TEST01",
        referral_count=0,
    )

    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    return user


@pytest.fixture
async def test_user_2(db_session: AsyncSession) -> User:
    """Create a second test user"""
    user = User(
        email="test2@example.com",
        display_name="Test User 2",
        password_hash=hash_password("password456"),
        avatar_emoji="🔬",
        level=2,
        xp=150,
        total_readings=10,
        verified_readings=8,
        verifications_performed=5,
        streak_days=3,
        trust_score=75,
        badges=[],
        subscription_tier="neighbor",
        referral_code="TEST02",
        referral_count=1,
    )

    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    return user


@pytest.fixture
def auth_headers(test_user: User) -> dict:
    """Get authorization headers for test user"""
    token = create_access_token({"sub": str(test_user.id)})
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def auth_headers_user_2(test_user_2: User) -> dict:
    """Get authorization headers for second test user"""
    token = create_access_token({"sub": str(test_user_2.id)})
    return {"Authorization": f"Bearer {token}"}
