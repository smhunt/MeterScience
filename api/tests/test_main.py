"""
Tests for main API endpoints
"""

import pytest
from httpx import AsyncClient


class TestRootEndpoints:
    """Test root and health check endpoints"""

    @pytest.mark.asyncio
    async def test_root_endpoint(self, client: AsyncClient):
        """Test root endpoint returns API info"""
        response = await client.get("/")

        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "MeterScience API"
        assert data["version"] == "1.0.0"
        assert data["docs"] == "/docs"
        assert data["status"] == "operational"

    @pytest.mark.asyncio
    async def test_health_endpoint(self, client: AsyncClient):
        """Test health check endpoint"""
        response = await client.get("/health")

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert "timestamp" in data
        assert data["version"] == "1.0.0"

    @pytest.mark.asyncio
    async def test_api_v1_info(self, client: AsyncClient):
        """Test API v1 info endpoint"""
        response = await client.get("/api/v1")

        assert response.status_code == 200
        data = response.json()
        assert data["version"] == "1.0.0"
        assert "endpoints" in data
        assert "users" in data["endpoints"]
        assert "meters" in data["endpoints"]
        assert "readings" in data["endpoints"]
        assert "campaigns" in data["endpoints"]
        assert "verify" in data["endpoints"]
        assert "stats" in data["endpoints"]
        assert "webhooks" in data["endpoints"]


class TestCORS:
    """Test CORS middleware"""

    @pytest.mark.asyncio
    async def test_cors_headers(self, client: AsyncClient):
        """Test that CORS headers are present"""
        response = await client.options(
            "/api/v1/users/me",
            headers={
                "Origin": "http://localhost:3000",
                "Access-Control-Request-Method": "GET",
            },
        )

        # CORS should allow the request
        assert response.status_code in [200, 204]


class TestNotFound:
    """Test 404 handling"""

    @pytest.mark.asyncio
    async def test_invalid_endpoint_404(self, client: AsyncClient):
        """Test that invalid endpoints return 404"""
        response = await client.get("/api/v1/nonexistent")

        assert response.status_code == 404
