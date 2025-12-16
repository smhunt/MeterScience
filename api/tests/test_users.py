"""
Tests for user endpoints
"""

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from src.models import User


class TestUserRegistration:
    """Test user registration endpoint"""

    @pytest.mark.asyncio
    async def test_register_user_success(self, client: AsyncClient):
        """Test successful user registration"""
        response = await client.post(
            "/api/v1/users/register",
            json={
                "email": "newuser@example.com",
                "display_name": "New User",
                "password": "secure_password",
            },
        )

        assert response.status_code == 201
        data = response.json()
        assert data["access_token"]
        assert data["token_type"] == "bearer"
        assert data["user"]["email"] == "newuser@example.com"
        assert data["user"]["display_name"] == "New User"
        assert data["user"]["level"] == 1
        assert data["user"]["xp"] == 0
        assert data["user"]["referral_code"]  # Should generate a code
        assert "password" not in data["user"]  # Should not expose password

    @pytest.mark.asyncio
    async def test_register_user_without_email(self, client: AsyncClient):
        """Test registration without email (anonymous)"""
        response = await client.post(
            "/api/v1/users/register",
            json={
                "display_name": "Anonymous User",
            },
        )

        assert response.status_code == 201
        data = response.json()
        assert data["access_token"]
        assert data["user"]["email"] is None
        assert data["user"]["display_name"] == "Anonymous User"
        assert data["user"]["referral_code"]

    @pytest.mark.asyncio
    async def test_register_duplicate_email(self, client: AsyncClient, test_user: User):
        """Test registration with duplicate email"""
        response = await client.post(
            "/api/v1/users/register",
            json={
                "email": test_user.email,
                "display_name": "Duplicate User",
                "password": "password",
            },
        )

        assert response.status_code == 400
        assert "already registered" in response.json()["detail"].lower()

    @pytest.mark.asyncio
    async def test_register_invalid_email(self, client: AsyncClient):
        """Test registration with invalid email format"""
        response = await client.post(
            "/api/v1/users/register",
            json={
                "email": "not-an-email",
                "display_name": "Test User",
                "password": "password",
            },
        )

        assert response.status_code == 422  # Validation error


class TestUserLogin:
    """Test user login endpoint"""

    @pytest.mark.asyncio
    async def test_login_success(self, client: AsyncClient, test_user: User):
        """Test successful login"""
        response = await client.post(
            "/api/v1/users/login",
            json={
                "email": test_user.email,
                "password": "password123",
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["access_token"]
        assert data["token_type"] == "bearer"
        assert data["user"]["email"] == test_user.email
        assert data["user"]["id"] == str(test_user.id)

    @pytest.mark.asyncio
    async def test_login_wrong_password(self, client: AsyncClient, test_user: User):
        """Test login with wrong password"""
        response = await client.post(
            "/api/v1/users/login",
            json={
                "email": test_user.email,
                "password": "wrong_password",
            },
        )

        assert response.status_code == 401
        assert "invalid credentials" in response.json()["detail"].lower()

    @pytest.mark.asyncio
    async def test_login_nonexistent_user(self, client: AsyncClient):
        """Test login with non-existent email"""
        response = await client.post(
            "/api/v1/users/login",
            json={
                "email": "nonexistent@example.com",
                "password": "password",
            },
        )

        assert response.status_code == 401
        assert "invalid credentials" in response.json()["detail"].lower()

    @pytest.mark.asyncio
    async def test_login_missing_password(self, client: AsyncClient):
        """Test login with missing password"""
        response = await client.post(
            "/api/v1/users/login",
            json={
                "email": "test@example.com",
            },
        )

        assert response.status_code == 422  # Validation error


class TestGetCurrentUser:
    """Test get current user endpoint"""

    @pytest.mark.asyncio
    async def test_get_current_user_success(
        self, client: AsyncClient, test_user: User, auth_headers: dict
    ):
        """Test getting current user profile"""
        response = await client.get("/api/v1/users/me", headers=auth_headers)

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == str(test_user.id)
        assert data["email"] == test_user.email
        assert data["display_name"] == test_user.display_name
        assert data["level"] == test_user.level
        assert data["xp"] == test_user.xp
        assert data["referral_code"] == test_user.referral_code

    @pytest.mark.asyncio
    async def test_get_current_user_without_auth(self, client: AsyncClient):
        """Test getting current user without authentication"""
        response = await client.get("/api/v1/users/me")

        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_get_current_user_invalid_token(self, client: AsyncClient):
        """Test getting current user with invalid token"""
        response = await client.get(
            "/api/v1/users/me", headers={"Authorization": "Bearer invalid_token"}
        )

        assert response.status_code == 401


class TestUpdateCurrentUser:
    """Test update current user endpoint"""

    @pytest.mark.asyncio
    async def test_update_display_name(
        self, client: AsyncClient, test_user: User, auth_headers: dict
    ):
        """Test updating display name"""
        response = await client.patch(
            "/api/v1/users/me",
            headers=auth_headers,
            json={"display_name": "Updated Name"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["display_name"] == "Updated Name"

    @pytest.mark.asyncio
    async def test_update_avatar_emoji(
        self, client: AsyncClient, test_user: User, auth_headers: dict
    ):
        """Test updating avatar emoji"""
        response = await client.patch(
            "/api/v1/users/me",
            headers=auth_headers,
            json={"avatar_emoji": "🚀"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["avatar_emoji"] == "🚀"

    @pytest.mark.asyncio
    async def test_update_location(
        self, client: AsyncClient, test_user: User, auth_headers: dict
    ):
        """Test updating location"""
        response = await client.patch(
            "/api/v1/users/me",
            headers=auth_headers,
            json={"postal_code": "M5V3A8", "country": "CA"},
        )

        assert response.status_code == 200
        data = response.json()
        # Note: postal_code and country not in response model, but should be updated

    @pytest.mark.asyncio
    async def test_update_multiple_fields(
        self, client: AsyncClient, test_user: User, auth_headers: dict
    ):
        """Test updating multiple fields at once"""
        response = await client.patch(
            "/api/v1/users/me",
            headers=auth_headers,
            json={
                "display_name": "New Name",
                "avatar_emoji": "⚡",
                "postal_code": "V6B1A1",
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["display_name"] == "New Name"
        assert data["avatar_emoji"] == "⚡"

    @pytest.mark.asyncio
    async def test_update_without_auth(self, client: AsyncClient):
        """Test updating user without authentication"""
        response = await client.patch(
            "/api/v1/users/me",
            json={"display_name": "Hacker"},
        )

        assert response.status_code == 401


class TestReferralCode:
    """Test referral code functionality"""

    @pytest.mark.asyncio
    async def test_apply_referral_code_success(
        self,
        client: AsyncClient,
        test_user: User,
        test_user_2: User,
        auth_headers: dict,
        db_session: AsyncSession,
    ):
        """Test successfully applying a referral code"""
        response = await client.post(
            f"/api/v1/users/referral/{test_user_2.referral_code}",
            headers=auth_headers,
        )

        assert response.status_code == 200
        assert "success" in response.json()["message"].lower()

        # Verify user was updated
        await db_session.refresh(test_user)
        await db_session.refresh(test_user_2)
        assert test_user.referred_by_id == test_user_2.id
        assert test_user_2.referral_count == 2  # Started with 1

    @pytest.mark.asyncio
    async def test_apply_referral_code_own_code(
        self, client: AsyncClient, test_user: User, auth_headers: dict
    ):
        """Test applying own referral code"""
        response = await client.post(
            f"/api/v1/users/referral/{test_user.referral_code}",
            headers=auth_headers,
        )

        assert response.status_code == 400
        assert "own" in response.json()["detail"].lower()

    @pytest.mark.asyncio
    async def test_apply_referral_code_already_referred(
        self,
        client: AsyncClient,
        test_user: User,
        test_user_2: User,
        auth_headers: dict,
        db_session: AsyncSession,
    ):
        """Test applying referral code when already referred"""
        # First application
        await client.post(
            f"/api/v1/users/referral/{test_user_2.referral_code}",
            headers=auth_headers,
        )

        # Second application (should fail)
        response = await client.post(
            f"/api/v1/users/referral/{test_user_2.referral_code}",
            headers=auth_headers,
        )

        assert response.status_code == 400
        assert "already" in response.json()["detail"].lower()

    @pytest.mark.asyncio
    async def test_apply_invalid_referral_code(
        self, client: AsyncClient, test_user: User, auth_headers: dict
    ):
        """Test applying invalid referral code"""
        response = await client.post(
            "/api/v1/users/referral/INVALID",
            headers=auth_headers,
        )

        assert response.status_code == 404
        assert "invalid" in response.json()["detail"].lower()

    @pytest.mark.asyncio
    async def test_apply_referral_code_case_insensitive(
        self,
        client: AsyncClient,
        test_user: User,
        test_user_2: User,
        auth_headers: dict,
    ):
        """Test that referral codes are case insensitive"""
        response = await client.post(
            f"/api/v1/users/referral/{test_user_2.referral_code.lower()}",
            headers=auth_headers,
        )

        assert response.status_code == 200


class TestLeaderboard:
    """Test leaderboard endpoint"""

    @pytest.mark.asyncio
    async def test_get_global_leaderboard(
        self, client: AsyncClient, test_user: User, test_user_2: User
    ):
        """Test getting global leaderboard"""
        response = await client.get("/api/v1/users/leaderboard?scope=global")

        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert len(data) == 2
        # Should be sorted by total_readings DESC
        assert data[0]["total_readings"] >= data[1]["total_readings"]
        assert "display_name" in data[0]
        assert "level" in data[0]
        assert "rank" in data[0]

    @pytest.mark.asyncio
    async def test_get_leaderboard_with_limit(
        self, client: AsyncClient, test_user: User, test_user_2: User
    ):
        """Test getting leaderboard with limit"""
        response = await client.get("/api/v1/users/leaderboard?limit=1")

        assert response.status_code == 200
        data = response.json()
        assert len(data) == 1

    @pytest.mark.asyncio
    async def test_leaderboard_contains_required_fields(
        self, client: AsyncClient, test_user: User
    ):
        """Test that leaderboard entries contain required fields"""
        response = await client.get("/api/v1/users/leaderboard")

        assert response.status_code == 200
        data = response.json()
        if len(data) > 0:
            entry = data[0]
            assert "rank" in entry
            assert "user_id" in entry
            assert "display_name" in entry
            assert "avatar_emoji" in entry
            assert "level" in entry
            assert "total_readings" in entry
            assert "streak_days" in entry
            assert "trust_score" in entry
