"""
Subscription API endpoints
"""

from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, Request, Header
from pydantic import BaseModel, HttpUrl
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..models import User
from ..services.auth import get_current_user
from ..services import stripe as stripe_service

router = APIRouter()


class CheckoutRequest(BaseModel):
    tier: str  # neighbor, block, district
    success_url: HttpUrl
    cancel_url: HttpUrl


class CheckoutResponse(BaseModel):
    session_id: str
    url: str


class PortalRequest(BaseModel):
    return_url: HttpUrl


class PortalResponse(BaseModel):
    url: str


class SubscriptionStatusResponse(BaseModel):
    tier: str
    status: str
    current_period_start: Optional[str] = None
    current_period_end: Optional[str] = None
    cancel_at_period_end: bool
    trial_end: Optional[str] = None


@router.post("/checkout", response_model=CheckoutResponse)
async def create_checkout_session(
    request: CheckoutRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Create a Stripe Checkout session for subscription.

    Initiates the payment flow for upgrading to a paid tier.

    Args:
        request: Checkout request with tier and redirect URLs
        db: Database session
        current_user: Authenticated user

    Returns:
        Checkout session with URL to redirect user

    Raises:
        HTTPException: If tier is invalid or Stripe configuration is missing
    """
    # Validate tier
    if request.tier not in ["neighbor", "block", "district"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid tier. Must be one of: neighbor, block, district"
        )

    try:
        session = await stripe_service.create_checkout_session(
            user=current_user,
            tier=request.tier,
            db=db,
            success_url=str(request.success_url),
            cancel_url=str(request.cancel_url),
        )
        return CheckoutResponse(**session)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create checkout session: {str(e)}"
        )


@router.post("/portal", response_model=PortalResponse)
async def create_portal_session(
    request: PortalRequest,
    current_user: User = Depends(get_current_user),
):
    """
    Create a Stripe Customer Portal session.

    Allows users to manage their subscription, update payment methods, view invoices, etc.

    Args:
        request: Portal request with return URL
        current_user: Authenticated user

    Returns:
        Portal session with URL to redirect user

    Raises:
        HTTPException: If user has no Stripe customer or portal creation fails
    """
    try:
        session = await stripe_service.create_portal_session(
            user=current_user,
            return_url=str(request.return_url),
        )
        return PortalResponse(**session)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create portal session: {str(e)}"
        )


@router.get("/status", response_model=SubscriptionStatusResponse)
async def get_subscription_status(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Get current subscription status for authenticated user.

    Returns:
        Current subscription details including tier, status, and billing period
    """
    try:
        status_data = await stripe_service.get_subscription_status(current_user, db)

        # Convert datetime objects to ISO strings
        return SubscriptionStatusResponse(
            tier=status_data["tier"],
            status=status_data["status"],
            current_period_start=status_data.get("current_period_start").isoformat() if status_data.get("current_period_start") else None,
            current_period_end=status_data.get("current_period_end").isoformat() if status_data.get("current_period_end") else None,
            cancel_at_period_end=status_data["cancel_at_period_end"],
            trial_end=status_data.get("trial_end").isoformat() if status_data.get("trial_end") else None,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get subscription status: {str(e)}"
        )


@router.post("/webhook", status_code=status.HTTP_200_OK)
async def stripe_webhook(
    request: Request,
    db: AsyncSession = Depends(get_db),
    stripe_signature: Optional[str] = Header(None, alias="stripe-signature"),
):
    """
    Handle Stripe webhook events (UNAUTHENTICATED).

    This endpoint receives events from Stripe when subscription changes occur.

    Supported events:
    - checkout.session.completed: Subscription created
    - customer.subscription.updated: Subscription changed
    - customer.subscription.deleted: Subscription canceled
    - invoice.payment_failed: Payment failed

    Args:
        request: FastAPI request with raw body
        db: Database session
        stripe_signature: Stripe signature header for verification

    Returns:
        Success message

    Raises:
        HTTPException: If signature is invalid or event processing fails
    """
    if not stripe_signature:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Missing stripe-signature header"
        )

    # Get raw body
    payload = await request.body()

    # Verify webhook signature
    try:
        event = await stripe_service.verify_webhook_signature(payload, stripe_signature)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )

    # Handle different event types
    try:
        if event.type == "checkout.session.completed":
            await stripe_service.handle_checkout_completed(event, db)

        elif event.type == "customer.subscription.updated":
            await stripe_service.handle_subscription_updated(event, db)

        elif event.type == "customer.subscription.deleted":
            await stripe_service.handle_subscription_deleted(event, db)

        elif event.type == "invoice.payment_failed":
            await stripe_service.handle_invoice_payment_failed(event, db)

        else:
            # Unhandled event type, just log and return success
            print(f"Unhandled event type: {event.type}")

    except Exception as e:
        # Log error but return 200 to prevent Stripe from retrying
        print(f"Error processing webhook {event.type}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to process webhook: {str(e)}"
        )

    return {"status": "success"}


@router.get("/tiers")
async def get_subscription_tiers():
    """
    Get available subscription tiers and pricing.

    Returns:
        List of subscription tiers with details
    """
    return {
        "tiers": [
            {
                "id": "free",
                "name": "Free",
                "price": 0,
                "currency": "usd",
                "interval": "month",
                "features": [
                    "Your meter data only",
                    "OCR meter reading",
                    "Basic statistics",
                    "Community verification",
                ],
                "data_access": "Personal data only"
            },
            {
                "id": "neighbor",
                "name": "Neighbor",
                "price": 2.99,
                "currency": "usd",
                "interval": "month",
                "features": [
                    "Everything in Free",
                    "Same postal code data access",
                    "Neighborhood trends",
                    "Email support",
                ],
                "data_access": "Same postal code"
            },
            {
                "id": "block",
                "name": "Block",
                "price": 4.99,
                "currency": "usd",
                "interval": "month",
                "features": [
                    "Everything in Neighbor",
                    "5km radius data access",
                    "Advanced analytics",
                    "Priority support",
                ],
                "data_access": "5km radius"
            },
            {
                "id": "district",
                "name": "District",
                "price": 9.99,
                "currency": "usd",
                "interval": "month",
                "features": [
                    "Everything in Block",
                    "25km radius data access",
                    "API access",
                    "Export data",
                    "Dedicated support",
                ],
                "data_access": "25km radius + API"
            },
        ]
    }
