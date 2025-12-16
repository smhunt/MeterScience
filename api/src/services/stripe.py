"""
Stripe payment integration service
"""

import os
from datetime import datetime
from typing import Optional, Dict, Any
from uuid import UUID

import stripe
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models import User, Subscription

# Initialize Stripe
stripe.api_key = os.getenv("STRIPE_SECRET_KEY")

# Price IDs from environment
STRIPE_PRICE_NEIGHBOR = os.getenv("STRIPE_PRICE_NEIGHBOR")
STRIPE_PRICE_BLOCK = os.getenv("STRIPE_PRICE_BLOCK")
STRIPE_PRICE_DISTRICT = os.getenv("STRIPE_PRICE_DISTRICT")

# Webhook secret
STRIPE_WEBHOOK_SECRET = os.getenv("STRIPE_WEBHOOK_SECRET")

# Tier to price mapping
TIER_PRICES = {
    "neighbor": STRIPE_PRICE_NEIGHBOR,
    "block": STRIPE_PRICE_BLOCK,
    "district": STRIPE_PRICE_DISTRICT,
}


async def get_or_create_stripe_customer(user: User, db: AsyncSession) -> str:
    """
    Get existing Stripe customer ID or create a new customer.

    Args:
        user: User model instance
        db: Database session

    Returns:
        Stripe customer ID
    """
    # Return existing customer ID if available
    if user.stripe_customer_id:
        return user.stripe_customer_id

    # Create new Stripe customer
    customer = stripe.Customer.create(
        email=user.email,
        metadata={
            "user_id": str(user.id),
            "display_name": user.display_name,
        }
    )

    # Save customer ID to user
    user.stripe_customer_id = customer.id
    await db.commit()

    return customer.id


async def create_checkout_session(
    user: User,
    tier: str,
    db: AsyncSession,
    success_url: str,
    cancel_url: str,
) -> Dict[str, Any]:
    """
    Create a Stripe Checkout session for subscription.

    Args:
        user: User model instance
        tier: Subscription tier (neighbor, block, district)
        db: Database session
        success_url: URL to redirect after successful payment
        cancel_url: URL to redirect after canceled payment

    Returns:
        Dict with session ID and URL
    """
    if tier not in TIER_PRICES:
        raise ValueError(f"Invalid tier: {tier}")

    price_id = TIER_PRICES[tier]
    if not price_id:
        raise ValueError(f"Price ID not configured for tier: {tier}")

    # Get or create Stripe customer
    customer_id = await get_or_create_stripe_customer(user, db)

    # Create checkout session
    session = stripe.checkout.Session.create(
        customer=customer_id,
        payment_method_types=["card"],
        line_items=[
            {
                "price": price_id,
                "quantity": 1,
            }
        ],
        mode="subscription",
        success_url=success_url,
        cancel_url=cancel_url,
        metadata={
            "user_id": str(user.id),
            "tier": tier,
        },
        subscription_data={
            "metadata": {
                "user_id": str(user.id),
                "tier": tier,
            }
        },
    )

    return {
        "session_id": session.id,
        "url": session.url,
    }


async def create_portal_session(
    user: User,
    return_url: str,
) -> Dict[str, Any]:
    """
    Create a Stripe Customer Portal session for managing subscription.

    Args:
        user: User model instance
        return_url: URL to redirect after portal session

    Returns:
        Dict with portal URL
    """
    if not user.stripe_customer_id:
        raise ValueError("User has no Stripe customer ID")

    # Create portal session
    session = stripe.billing_portal.Session.create(
        customer=user.stripe_customer_id,
        return_url=return_url,
    )

    return {
        "url": session.url,
    }


async def get_subscription_status(user: User, db: AsyncSession) -> Dict[str, Any]:
    """
    Get current subscription status for a user.

    Args:
        user: User model instance
        db: Database session

    Returns:
        Dict with subscription details
    """
    # Check database for subscription
    result = await db.execute(
        select(Subscription).where(Subscription.user_id == user.id)
    )
    subscription = result.scalar_one_or_none()

    if not subscription:
        # No subscription record, return free tier
        return {
            "tier": "free",
            "status": "active",
            "current_period_end": None,
            "cancel_at_period_end": False,
        }

    return {
        "tier": subscription.tier,
        "status": subscription.status,
        "current_period_start": subscription.current_period_start,
        "current_period_end": subscription.current_period_end,
        "cancel_at_period_end": subscription.cancel_at_period_end,
        "trial_end": subscription.trial_end,
    }


async def verify_webhook_signature(payload: bytes, signature: str) -> stripe.Event:
    """
    Verify Stripe webhook signature and construct event.

    Args:
        payload: Request body bytes
        signature: Stripe-Signature header value

    Returns:
        Stripe Event object

    Raises:
        ValueError: If signature is invalid
    """
    if not STRIPE_WEBHOOK_SECRET:
        raise ValueError("STRIPE_WEBHOOK_SECRET not configured")

    try:
        event = stripe.Webhook.construct_event(
            payload, signature, STRIPE_WEBHOOK_SECRET
        )
        return event
    except stripe.error.SignatureVerificationError as e:
        raise ValueError("Invalid signature") from e


async def handle_checkout_completed(
    event: stripe.Event,
    db: AsyncSession,
) -> None:
    """
    Handle checkout.session.completed webhook event.

    Creates or updates subscription record when checkout is successful.

    Args:
        event: Stripe Event object
        db: Database session
    """
    session = event.data.object

    user_id = session.metadata.get("user_id")
    tier = session.metadata.get("tier")

    if not user_id or not tier:
        raise ValueError("Missing user_id or tier in session metadata")

    # Get user
    result = await db.execute(
        select(User).where(User.id == UUID(user_id))
    )
    user = result.scalar_one_or_none()

    if not user:
        raise ValueError(f"User not found: {user_id}")

    # Get Stripe subscription details
    stripe_subscription_id = session.subscription
    stripe_subscription = stripe.Subscription.retrieve(stripe_subscription_id)

    # Create or update subscription record
    result = await db.execute(
        select(Subscription).where(Subscription.user_id == user.id)
    )
    subscription = result.scalar_one_or_none()

    if subscription:
        # Update existing
        subscription.stripe_subscription_id = stripe_subscription.id
        subscription.stripe_price_id = stripe_subscription["items"]["data"][0]["price"]["id"]
        subscription.tier = tier
        subscription.status = stripe_subscription.status
        subscription.current_period_start = datetime.fromtimestamp(stripe_subscription.current_period_start)
        subscription.current_period_end = datetime.fromtimestamp(stripe_subscription.current_period_end)
        subscription.cancel_at_period_end = stripe_subscription.cancel_at_period_end
    else:
        # Create new
        subscription = Subscription(
            user_id=user.id,
            stripe_subscription_id=stripe_subscription.id,
            stripe_price_id=stripe_subscription["items"]["data"][0]["price"]["id"],
            tier=tier,
            status=stripe_subscription.status,
            current_period_start=datetime.fromtimestamp(stripe_subscription.current_period_start),
            current_period_end=datetime.fromtimestamp(stripe_subscription.current_period_end),
            cancel_at_period_end=stripe_subscription.cancel_at_period_end,
        )
        db.add(subscription)

    # Update user tier (backward compatibility)
    user.subscription_tier = tier
    user.subscription_expires_at = datetime.fromtimestamp(stripe_subscription.current_period_end)

    await db.commit()


async def handle_subscription_updated(
    event: stripe.Event,
    db: AsyncSession,
) -> None:
    """
    Handle customer.subscription.updated webhook event.

    Updates subscription status when subscription changes.

    Args:
        event: Stripe Event object
        db: Database session
    """
    stripe_subscription = event.data.object

    # Find subscription by Stripe ID
    result = await db.execute(
        select(Subscription).where(
            Subscription.stripe_subscription_id == stripe_subscription.id
        )
    )
    subscription = result.scalar_one_or_none()

    if not subscription:
        # Subscription not found, might be a new one
        user_id = stripe_subscription.metadata.get("user_id")
        if not user_id:
            raise ValueError("Missing user_id in subscription metadata")

        result = await db.execute(
            select(User).where(User.id == UUID(user_id))
        )
        user = result.scalar_one_or_none()

        if not user:
            raise ValueError(f"User not found: {user_id}")

        tier = stripe_subscription.metadata.get("tier", "neighbor")

        subscription = Subscription(
            user_id=user.id,
            stripe_subscription_id=stripe_subscription.id,
            stripe_price_id=stripe_subscription["items"]["data"][0]["price"]["id"],
            tier=tier,
        )
        db.add(subscription)

    # Update subscription
    subscription.status = stripe_subscription.status
    subscription.current_period_start = datetime.fromtimestamp(stripe_subscription.current_period_start)
    subscription.current_period_end = datetime.fromtimestamp(stripe_subscription.current_period_end)
    subscription.cancel_at_period_end = stripe_subscription.cancel_at_period_end

    if stripe_subscription.canceled_at:
        subscription.canceled_at = datetime.fromtimestamp(stripe_subscription.canceled_at)

    # Update user tier (backward compatibility)
    result = await db.execute(
        select(User).where(User.id == subscription.user_id)
    )
    user = result.scalar_one_or_none()

    if user:
        if stripe_subscription.status == "active":
            user.subscription_tier = subscription.tier
            user.subscription_expires_at = subscription.current_period_end
        elif stripe_subscription.status in ["canceled", "past_due"]:
            user.subscription_tier = "free"
            user.subscription_expires_at = None

    await db.commit()


async def handle_subscription_deleted(
    event: stripe.Event,
    db: AsyncSession,
) -> None:
    """
    Handle customer.subscription.deleted webhook event.

    Downgrades user to free tier when subscription is canceled.

    Args:
        event: Stripe Event object
        db: Database session
    """
    stripe_subscription = event.data.object

    # Find subscription by Stripe ID
    result = await db.execute(
        select(Subscription).where(
            Subscription.stripe_subscription_id == stripe_subscription.id
        )
    )
    subscription = result.scalar_one_or_none()

    if not subscription:
        return  # Subscription not found, nothing to do

    # Update subscription status
    subscription.status = "canceled"
    subscription.canceled_at = datetime.utcnow()

    # Downgrade user to free tier
    result = await db.execute(
        select(User).where(User.id == subscription.user_id)
    )
    user = result.scalar_one_or_none()

    if user:
        user.subscription_tier = "free"
        user.subscription_expires_at = None

    await db.commit()


async def handle_invoice_payment_failed(
    event: stripe.Event,
    db: AsyncSession,
) -> None:
    """
    Handle invoice.payment_failed webhook event.

    Updates subscription status when payment fails.

    Args:
        event: Stripe Event object
        db: Database session
    """
    invoice = event.data.object
    stripe_subscription_id = invoice.subscription

    if not stripe_subscription_id:
        return  # Not a subscription invoice

    # Find subscription by Stripe ID
    result = await db.execute(
        select(Subscription).where(
            Subscription.stripe_subscription_id == stripe_subscription_id
        )
    )
    subscription = result.scalar_one_or_none()

    if not subscription:
        return  # Subscription not found

    # Update subscription status to past_due
    subscription.status = "past_due"

    # Update user tier (keep current tier but mark as past due)
    result = await db.execute(
        select(User).where(User.id == subscription.user_id)
    )
    user = result.scalar_one_or_none()

    if user:
        # Optionally downgrade to free or keep current tier
        # For now, we'll keep the tier but they won't have access
        pass

    await db.commit()
