"""
Tests for subscription endpoints
"""

import os
from unittest.mock import patch, MagicMock
from uuid import uuid4

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from src.models import User, Subscription


@pytest.mark.asyncio
class TestSubscriptionEndpoints:
    """Test subscription API endpoints"""

    async def test_get_tiers(self, client: AsyncClient):
        """Test getting subscription tiers"""
        response = await client.get("/api/v1/subscriptions/tiers")

        assert response.status_code == 200
        data = response.json()
        assert "tiers" in data
        assert len(data["tiers"]) == 4

        # Verify tier structure
        tier_ids = [t["id"] for t in data["tiers"]]
        assert "free" in tier_ids
        assert "neighbor" in tier_ids
        assert "block" in tier_ids
        assert "district" in tier_ids

        # Verify free tier
        free_tier = next(t for t in data["tiers"] if t["id"] == "free")
        assert free_tier["price"] == 0
        assert free_tier["name"] == "Free"

        # Verify neighbor tier
        neighbor_tier = next(t for t in data["tiers"] if t["id"] == "neighbor")
        assert neighbor_tier["price"] == 2.99
        assert neighbor_tier["name"] == "Neighbor"

    async def test_get_status_no_subscription(
        self, client: AsyncClient, test_user: User, auth_headers: dict
    ):
        """Test getting subscription status for free tier user"""
        response = await client.get(
            "/api/v1/subscriptions/status",
            headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()
        assert data["tier"] == "free"
        assert data["status"] == "active"
        assert data["current_period_end"] is None
        assert data["cancel_at_period_end"] is False

    async def test_get_status_with_subscription(
        self, client: AsyncClient, test_user: User, db_session: AsyncSession, auth_headers: dict
    ):
        """Test getting subscription status for subscribed user"""
        from datetime import datetime, timedelta

        # Create subscription
        subscription = Subscription(
            user_id=test_user.id,
            stripe_subscription_id="sub_test123",
            stripe_price_id="price_test123",
            tier="neighbor",
            status="active",
            current_period_start=datetime.utcnow(),
            current_period_end=datetime.utcnow() + timedelta(days=30),
            cancel_at_period_end=False,
        )
        db_session.add(subscription)
        await db_session.commit()

        response = await client.get(
            "/api/v1/subscriptions/status",
            headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()
        assert data["tier"] == "neighbor"
        assert data["status"] == "active"
        assert data["current_period_end"] is not None
        assert data["cancel_at_period_end"] is False

    async def test_checkout_unauthenticated(self, client: AsyncClient):
        """Test checkout without authentication"""
        response = await client.post(
            "/api/v1/subscriptions/checkout",
            json={
                "tier": "neighbor",
                "success_url": "http://example.com/success",
                "cancel_url": "http://example.com/cancel",
            }
        )

        assert response.status_code == 401

    async def test_checkout_invalid_tier(
        self, client: AsyncClient, test_user: User, auth_headers: dict
    ):
        """Test checkout with invalid tier"""
        response = await client.post(
            "/api/v1/subscriptions/checkout",
            headers=auth_headers,
            json={
                "tier": "invalid",
                "success_url": "http://example.com/success",
                "cancel_url": "http://example.com/cancel",
            }
        )

        assert response.status_code == 400
        assert "Invalid tier" in response.json()["detail"]

    @patch("src.services.stripe.stripe.checkout.Session.create")
    @patch("src.services.stripe.stripe.Customer.create")
    async def test_checkout_success(
        self,
        mock_customer_create: MagicMock,
        mock_session_create: MagicMock,
        client: AsyncClient,
        test_user: User,
        auth_headers: dict,
    ):
        """Test successful checkout session creation"""
        # Mock Stripe customer creation
        mock_customer_create.return_value = MagicMock(id="cus_test123")

        # Mock Stripe checkout session creation
        mock_session_create.return_value = MagicMock(
            id="cs_test123",
            url="https://checkout.stripe.com/test123"
        )

        # Set required env vars
        with patch.dict(os.environ, {
            "STRIPE_SECRET_KEY": "sk_test_123",
            "STRIPE_PRICE_NEIGHBOR": "price_test_neighbor",
        }):
            response = await client.post(
                "/api/v1/subscriptions/checkout",
                headers=auth_headers,
                json={
                    "tier": "neighbor",
                    "success_url": "http://example.com/success",
                    "cancel_url": "http://example.com/cancel",
                }
            )

        assert response.status_code == 200
        data = response.json()
        assert "session_id" in data
        assert "url" in data
        assert data["session_id"] == "cs_test123"

    async def test_portal_unauthenticated(self, client: AsyncClient):
        """Test portal without authentication"""
        response = await client.post(
            "/api/v1/subscriptions/portal",
            json={"return_url": "http://example.com/account"}
        )

        assert response.status_code == 401

    async def test_portal_no_customer(
        self, client: AsyncClient, test_user: User, auth_headers: dict
    ):
        """Test portal for user without Stripe customer"""
        response = await client.post(
            "/api/v1/subscriptions/portal",
            headers=auth_headers,
            json={"return_url": "http://example.com/account"}
        )

        assert response.status_code == 400
        assert "no Stripe customer" in response.json()["detail"]

    @patch("src.services.stripe.stripe.billing_portal.Session.create")
    async def test_portal_success(
        self,
        mock_portal_create: MagicMock,
        client: AsyncClient,
        test_user: User,
        db_session: AsyncSession,
        auth_headers: dict,
    ):
        """Test successful portal session creation"""
        # Add Stripe customer ID to user
        test_user.stripe_customer_id = "cus_test123"
        await db_session.commit()

        # Mock Stripe portal session creation
        mock_portal_create.return_value = MagicMock(
            url="https://billing.stripe.com/test123"
        )

        response = await client.post(
            "/api/v1/subscriptions/portal",
            headers=auth_headers,
            json={"return_url": "http://example.com/account"}
        )

        assert response.status_code == 200
        data = response.json()
        assert "url" in data
        assert "billing.stripe.com" in data["url"]


@pytest.mark.asyncio
class TestStripeWebhooks:
    """Test Stripe webhook handlers"""

    async def test_webhook_missing_signature(self, client: AsyncClient):
        """Test webhook without signature header"""
        response = await client.post(
            "/api/v1/subscriptions/webhook",
            json={"type": "test"}
        )

        assert response.status_code == 400
        assert "signature" in response.json()["detail"].lower()

    @patch("src.services.stripe.stripe.Webhook.construct_event")
    async def test_webhook_invalid_signature(
        self, mock_construct: MagicMock, client: AsyncClient
    ):
        """Test webhook with invalid signature"""
        mock_construct.side_effect = ValueError("Invalid signature")

        response = await client.post(
            "/api/v1/subscriptions/webhook",
            headers={"stripe-signature": "invalid"},
            content=b'{"type": "test"}'
        )

        assert response.status_code == 400

    @patch("src.services.stripe.stripe.Webhook.construct_event")
    @patch("src.services.stripe.stripe.Subscription.retrieve")
    async def test_webhook_checkout_completed(
        self,
        mock_subscription_retrieve: MagicMock,
        mock_construct: MagicMock,
        client: AsyncClient,
        test_user: User,
        db_session: AsyncSession,
    ):
        """Test checkout.session.completed webhook"""
        from datetime import datetime, timedelta

        # Mock webhook event
        mock_event = MagicMock()
        mock_event.type = "checkout.session.completed"
        mock_event.data.object = MagicMock(
            subscription="sub_test123",
            metadata={"user_id": str(test_user.id), "tier": "neighbor"}
        )
        mock_construct.return_value = mock_event

        # Mock Stripe subscription
        current_time = datetime.utcnow()
        mock_subscription_retrieve.return_value = {
            "id": "sub_test123",
            "status": "active",
            "current_period_start": int(current_time.timestamp()),
            "current_period_end": int((current_time + timedelta(days=30)).timestamp()),
            "cancel_at_period_end": False,
            "items": {
                "data": [{"price": {"id": "price_test123"}}]
            }
        }

        with patch.dict(os.environ, {"STRIPE_WEBHOOK_SECRET": "whsec_test"}):
            response = await client.post(
                "/api/v1/subscriptions/webhook",
                headers={"stripe-signature": "valid_signature"},
                content=b'{"type": "checkout.session.completed"}'
            )

        assert response.status_code == 200
        assert response.json()["status"] == "success"

        # Verify subscription was created
        await db_session.refresh(test_user)
        assert test_user.subscription_tier == "neighbor"

    @patch("src.services.stripe.stripe.Webhook.construct_event")
    async def test_webhook_subscription_deleted(
        self,
        mock_construct: MagicMock,
        client: AsyncClient,
        test_user: User,
        db_session: AsyncSession,
    ):
        """Test customer.subscription.deleted webhook"""
        # Create existing subscription
        subscription = Subscription(
            user_id=test_user.id,
            stripe_subscription_id="sub_test123",
            tier="neighbor",
            status="active",
        )
        db_session.add(subscription)
        test_user.subscription_tier = "neighbor"
        await db_session.commit()

        # Mock webhook event
        mock_event = MagicMock()
        mock_event.type = "customer.subscription.deleted"
        mock_event.data.object = MagicMock(id="sub_test123")
        mock_construct.return_value = mock_event

        with patch.dict(os.environ, {"STRIPE_WEBHOOK_SECRET": "whsec_test"}):
            response = await client.post(
                "/api/v1/subscriptions/webhook",
                headers={"stripe-signature": "valid_signature"},
                content=b'{"type": "customer.subscription.deleted"}'
            )

        assert response.status_code == 200

        # Verify user was downgraded to free
        await db_session.refresh(test_user)
        assert test_user.subscription_tier == "free"

        # Verify subscription status
        await db_session.refresh(subscription)
        assert subscription.status == "canceled"
