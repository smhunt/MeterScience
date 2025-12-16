"""
Tests for meter endpoints
"""

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from src.models import User, Meter


@pytest.fixture
async def test_meter(db_session: AsyncSession, test_user: User) -> Meter:
    """Create a test meter"""
    meter = Meter(
        user_id=test_user.id,
        name="Electric Meter",
        meter_type="electric",
        utility_provider="Hydro One",
        account_number="12345678",
        postal_code="M5V3A8",
        country="CA",
        latitude=43.6532,
        longitude=-79.3832,
        digit_count=6,
        has_decimal_point=False,
        decimal_places=0,
        is_active=True,
    )

    db_session.add(meter)
    await db_session.commit()
    await db_session.refresh(meter)

    return meter


@pytest.fixture
async def test_meter_2(db_session: AsyncSession, test_user: User) -> Meter:
    """Create a second test meter"""
    meter = Meter(
        user_id=test_user.id,
        name="Gas Meter",
        meter_type="gas",
        utility_provider="Enbridge",
        digit_count=5,
        has_decimal_point=True,
        decimal_places=2,
        is_active=True,
    )

    db_session.add(meter)
    await db_session.commit()
    await db_session.refresh(meter)

    return meter


class TestCreateMeter:
    """Test meter creation endpoint"""

    @pytest.mark.asyncio
    async def test_create_meter_success(
        self, client: AsyncClient, test_user: User, auth_headers: dict
    ):
        """Test successful meter creation"""
        response = await client.post(
            "/api/v1/meters/",
            headers=auth_headers,
            json={
                "name": "New Electric Meter",
                "meter_type": "electric",
                "utility_provider": "BC Hydro",
                "postal_code": "V6B1A1",
                "country": "CA",
                "digit_count": 6,
            },
        )

        assert response.status_code == 201
        data = response.json()
        assert data["name"] == "New Electric Meter"
        assert data["meter_type"] == "electric"
        assert data["utility_provider"] == "BC Hydro"
        assert data["user_id"] == str(test_user.id)
        assert data["digit_count"] == 6
        assert data["is_active"] is True

    @pytest.mark.asyncio
    async def test_create_meter_minimal_data(
        self, client: AsyncClient, test_user: User, auth_headers: dict
    ):
        """Test creating meter with minimal required data"""
        response = await client.post(
            "/api/v1/meters/",
            headers=auth_headers,
            json={
                "name": "Simple Meter",
                "meter_type": "water",
            },
        )

        assert response.status_code == 201
        data = response.json()
        assert data["name"] == "Simple Meter"
        assert data["meter_type"] == "water"
        assert data["digit_count"] == 6  # Default value

    @pytest.mark.asyncio
    async def test_create_meter_invalid_type(
        self, client: AsyncClient, test_user: User, auth_headers: dict
    ):
        """Test creating meter with invalid type"""
        response = await client.post(
            "/api/v1/meters/",
            headers=auth_headers,
            json={
                "name": "Invalid Meter",
                "meter_type": "invalid_type",
            },
        )

        assert response.status_code == 400
        assert "invalid meter_type" in response.json()["detail"].lower()

    @pytest.mark.asyncio
    async def test_create_meter_all_valid_types(
        self, client: AsyncClient, test_user: User, auth_headers: dict
    ):
        """Test creating meters with all valid types"""
        valid_types = ["electric", "gas", "water", "solar", "other"]

        for meter_type in valid_types:
            response = await client.post(
                "/api/v1/meters/",
                headers=auth_headers,
                json={
                    "name": f"{meter_type.capitalize()} Meter",
                    "meter_type": meter_type,
                },
            )

            assert response.status_code == 201
            assert response.json()["meter_type"] == meter_type

    @pytest.mark.asyncio
    async def test_create_meter_without_auth(self, client: AsyncClient):
        """Test creating meter without authentication"""
        response = await client.post(
            "/api/v1/meters/",
            json={
                "name": "Unauthorized Meter",
                "meter_type": "electric",
            },
        )

        assert response.status_code == 401


class TestListMeters:
    """Test listing meters endpoint"""

    @pytest.mark.asyncio
    async def test_get_meters_success(
        self,
        client: AsyncClient,
        test_user: User,
        test_meter: Meter,
        test_meter_2: Meter,
        auth_headers: dict,
    ):
        """Test getting list of user's meters"""
        response = await client.get("/api/v1/meters/", headers=auth_headers)

        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert len(data) == 2
        meter_ids = [m["id"] for m in data]
        assert str(test_meter.id) in meter_ids
        assert str(test_meter_2.id) in meter_ids

    @pytest.mark.asyncio
    async def test_get_meters_filter_by_type(
        self,
        client: AsyncClient,
        test_user: User,
        test_meter: Meter,
        test_meter_2: Meter,
        auth_headers: dict,
    ):
        """Test filtering meters by type"""
        response = await client.get(
            "/api/v1/meters/?meter_type=electric", headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()
        assert len(data) == 1
        assert data[0]["meter_type"] == "electric"
        assert data[0]["id"] == str(test_meter.id)

    @pytest.mark.asyncio
    async def test_get_meters_filter_by_active(
        self,
        client: AsyncClient,
        test_user: User,
        test_meter: Meter,
        auth_headers: dict,
        db_session: AsyncSession,
    ):
        """Test filtering meters by active status"""
        # Deactivate test_meter
        test_meter.is_active = False
        await db_session.commit()

        response = await client.get(
            "/api/v1/meters/?is_active=true", headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()
        # Should not include deactivated meter
        meter_ids = [m["id"] for m in data]
        assert str(test_meter.id) not in meter_ids

    @pytest.mark.asyncio
    async def test_get_meters_empty_list(
        self, client: AsyncClient, test_user: User, auth_headers: dict
    ):
        """Test getting empty list when user has no meters"""
        response = await client.get("/api/v1/meters/", headers=auth_headers)

        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert len(data) == 0

    @pytest.mark.asyncio
    async def test_get_meters_without_auth(self, client: AsyncClient):
        """Test getting meters without authentication"""
        response = await client.get("/api/v1/meters/")

        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_get_meters_only_own_meters(
        self,
        client: AsyncClient,
        test_user: User,
        test_user_2: User,
        test_meter: Meter,
        auth_headers_user_2: dict,
        db_session: AsyncSession,
    ):
        """Test that users only see their own meters"""
        # Create meter for user 2
        meter_user_2 = Meter(
            user_id=test_user_2.id,
            name="User 2 Meter",
            meter_type="water",
        )
        db_session.add(meter_user_2)
        await db_session.commit()

        response = await client.get("/api/v1/meters/", headers=auth_headers_user_2)

        assert response.status_code == 200
        data = response.json()
        assert len(data) == 1
        assert data[0]["id"] == str(meter_user_2.id)
        assert str(test_meter.id) not in [m["id"] for m in data]


class TestGetMeter:
    """Test getting single meter endpoint"""

    @pytest.mark.asyncio
    async def test_get_meter_success(
        self,
        client: AsyncClient,
        test_user: User,
        test_meter: Meter,
        auth_headers: dict,
    ):
        """Test getting a specific meter"""
        response = await client.get(
            f"/api/v1/meters/{test_meter.id}", headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == str(test_meter.id)
        assert data["name"] == test_meter.name
        assert data["meter_type"] == test_meter.meter_type

    @pytest.mark.asyncio
    async def test_get_meter_not_found(
        self, client: AsyncClient, test_user: User, auth_headers: dict
    ):
        """Test getting non-existent meter"""
        from uuid import uuid4

        fake_id = uuid4()
        response = await client.get(f"/api/v1/meters/{fake_id}", headers=auth_headers)

        assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_get_meter_other_user(
        self,
        client: AsyncClient,
        test_meter: Meter,
        auth_headers_user_2: dict,
    ):
        """Test getting another user's meter"""
        response = await client.get(
            f"/api/v1/meters/{test_meter.id}", headers=auth_headers_user_2
        )

        assert response.status_code == 404


class TestUpdateMeter:
    """Test meter update endpoint"""

    @pytest.mark.asyncio
    async def test_update_meter_name(
        self,
        client: AsyncClient,
        test_user: User,
        test_meter: Meter,
        auth_headers: dict,
    ):
        """Test updating meter name"""
        response = await client.patch(
            f"/api/v1/meters/{test_meter.id}",
            headers=auth_headers,
            json={"name": "Updated Meter Name"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "Updated Meter Name"

    @pytest.mark.asyncio
    async def test_update_meter_type(
        self,
        client: AsyncClient,
        test_user: User,
        test_meter: Meter,
        auth_headers: dict,
    ):
        """Test updating meter type"""
        response = await client.patch(
            f"/api/v1/meters/{test_meter.id}",
            headers=auth_headers,
            json={"meter_type": "solar"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["meter_type"] == "solar"

    @pytest.mark.asyncio
    async def test_update_meter_invalid_type(
        self,
        client: AsyncClient,
        test_user: User,
        test_meter: Meter,
        auth_headers: dict,
    ):
        """Test updating meter with invalid type"""
        response = await client.patch(
            f"/api/v1/meters/{test_meter.id}",
            headers=auth_headers,
            json={"meter_type": "invalid"},
        )

        assert response.status_code == 400

    @pytest.mark.asyncio
    async def test_update_meter_multiple_fields(
        self,
        client: AsyncClient,
        test_user: User,
        test_meter: Meter,
        auth_headers: dict,
    ):
        """Test updating multiple meter fields"""
        response = await client.patch(
            f"/api/v1/meters/{test_meter.id}",
            headers=auth_headers,
            json={
                "name": "New Name",
                "utility_provider": "New Provider",
                "digit_count": 7,
                "is_active": False,
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "New Name"
        assert data["utility_provider"] == "New Provider"
        assert data["digit_count"] == 7
        assert data["is_active"] is False

    @pytest.mark.asyncio
    async def test_update_meter_not_found(
        self, client: AsyncClient, test_user: User, auth_headers: dict
    ):
        """Test updating non-existent meter"""
        from uuid import uuid4

        fake_id = uuid4()
        response = await client.patch(
            f"/api/v1/meters/{fake_id}",
            headers=auth_headers,
            json={"name": "Update"},
        )

        assert response.status_code == 404


class TestDeleteMeter:
    """Test meter deletion endpoint"""

    @pytest.mark.asyncio
    async def test_delete_meter_success(
        self,
        client: AsyncClient,
        test_user: User,
        test_meter: Meter,
        auth_headers: dict,
        db_session: AsyncSession,
    ):
        """Test successfully deleting a meter"""
        response = await client.delete(
            f"/api/v1/meters/{test_meter.id}", headers=auth_headers
        )

        assert response.status_code == 204

        # Verify meter is deleted
        from sqlalchemy import select

        result = await db_session.execute(select(Meter).where(Meter.id == test_meter.id))
        assert result.scalar_one_or_none() is None

    @pytest.mark.asyncio
    async def test_delete_meter_not_found(
        self, client: AsyncClient, test_user: User, auth_headers: dict
    ):
        """Test deleting non-existent meter"""
        from uuid import uuid4

        fake_id = uuid4()
        response = await client.delete(
            f"/api/v1/meters/{fake_id}", headers=auth_headers
        )

        assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_delete_meter_other_user(
        self,
        client: AsyncClient,
        test_meter: Meter,
        auth_headers_user_2: dict,
    ):
        """Test deleting another user's meter"""
        response = await client.delete(
            f"/api/v1/meters/{test_meter.id}", headers=auth_headers_user_2
        )

        assert response.status_code == 404


class TestMeterCalibration:
    """Test meter calibration endpoint"""

    @pytest.mark.asyncio
    async def test_calibrate_meter_bounding_box(
        self,
        client: AsyncClient,
        test_user: User,
        test_meter: Meter,
        auth_headers: dict,
    ):
        """Test updating meter bounding box"""
        response = await client.post(
            f"/api/v1/meters/{test_meter.id}/calibrate",
            headers=auth_headers,
            json={
                "bounding_box": {"x": 100, "y": 200, "width": 300, "height": 150},
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["bounding_box"]["x"] == 100
        assert data["bounding_box"]["y"] == 200

    @pytest.mark.asyncio
    async def test_calibrate_meter_sample_readings(
        self,
        client: AsyncClient,
        test_user: User,
        test_meter: Meter,
        auth_headers: dict,
    ):
        """Test adding sample readings"""
        response = await client.post(
            f"/api/v1/meters/{test_meter.id}/calibrate",
            headers=auth_headers,
            json={
                "sample_readings": ["12345", "12346", "12347"],
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert "12345" in data["sample_readings"]
        assert len(data["sample_readings"]) == 3

    @pytest.mark.asyncio
    async def test_calibrate_meter_image_hash(
        self,
        client: AsyncClient,
        test_user: User,
        test_meter: Meter,
        auth_headers: dict,
    ):
        """Test updating calibration image hash"""
        response = await client.post(
            f"/api/v1/meters/{test_meter.id}/calibrate",
            headers=auth_headers,
            json={
                "calibration_image_hash": "abc123def456",
            },
        )

        assert response.status_code == 200
        # Note: calibration_image_hash not in response model


class TestMeterStats:
    """Test meter statistics endpoint"""

    @pytest.mark.asyncio
    async def test_get_meter_stats_no_readings(
        self,
        client: AsyncClient,
        test_user: User,
        test_meter: Meter,
        auth_headers: dict,
    ):
        """Test getting stats for meter with no readings"""
        response = await client.get(
            f"/api/v1/meters/{test_meter.id}/stats", headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()
        assert data["meter_id"] == str(test_meter.id)
        assert data["total_readings"] == 0
        assert data["verified_readings"] == 0
        assert data["average_confidence"] == 0

    @pytest.mark.asyncio
    async def test_get_meter_stats_not_found(
        self, client: AsyncClient, test_user: User, auth_headers: dict
    ):
        """Test getting stats for non-existent meter"""
        from uuid import uuid4

        fake_id = uuid4()
        response = await client.get(
            f"/api/v1/meters/{fake_id}/stats", headers=auth_headers
        )

        assert response.status_code == 404
