# Stripe Subscription Integration Setup

This guide walks through setting up the Stripe subscription integration for MeterScience.

## Overview

The integration supports 4 subscription tiers:
- **Free** - $0/month - Personal data only
- **Neighbor** - $2.99/month - Same postal code data access
- **Block** - $4.99/month - 5km radius data access
- **District** - $9.99/month - 25km radius + API access

## Setup Steps

### 1. Create Stripe Account

1. Go to [https://stripe.com](https://stripe.com) and create an account
2. Complete account verification (required for live mode)

### 2. Get API Keys

1. Go to [Stripe Dashboard > Developers > API keys](https://dashboard.stripe.com/apikeys)
2. Copy your **Secret key** (starts with `sk_test_` for test mode)
3. Add to your `.env` file:
   ```
   STRIPE_SECRET_KEY=sk_test_your_key_here
   ```

### 3. Create Products and Prices

1. Go to [Stripe Dashboard > Products](https://dashboard.stripe.com/products)
2. Create a product for each tier:

#### Neighbor Tier
- Name: "MeterScience Neighbor"
- Description: "Access to neighborhood data (same postal code)"
- Pricing: $2.99/month, recurring
- Copy the **Price ID** (starts with `price_`)

#### Block Tier
- Name: "MeterScience Block"
- Description: "Access to local data (5km radius)"
- Pricing: $4.99/month, recurring
- Copy the **Price ID**

#### District Tier
- Name: "MeterScience District"
- Description: "Full data access (25km radius + API)"
- Pricing: $9.99/month, recurring
- Copy the **Price ID**

3. Add price IDs to your `.env` file:
   ```
   STRIPE_PRICE_NEIGHBOR=price_neighbor_id_here
   STRIPE_PRICE_BLOCK=price_block_id_here
   STRIPE_PRICE_DISTRICT=price_district_id_here
   ```

### 4. Set Up Webhook Endpoint

1. Start your API server:
   ```bash
   cd api
   source venv/bin/activate
   uvicorn src.main:app --reload --host 0.0.0.0 --port 8000
   ```

2. For local testing, use [Stripe CLI](https://stripe.com/docs/stripe-cli):
   ```bash
   # Install Stripe CLI
   brew install stripe/stripe-cli/stripe

   # Login to Stripe
   stripe login

   # Forward webhook events to local server
   stripe listen --forward-to localhost:8000/api/v1/subscriptions/webhook

   # Copy the webhook signing secret (starts with whsec_)
   # Add to .env:
   # STRIPE_WEBHOOK_SECRET=whsec_your_secret_here
   ```

3. For production, add webhook endpoint in [Stripe Dashboard > Developers > Webhooks](https://dashboard.stripe.com/webhooks):
   - Endpoint URL: `https://your-domain.com/api/v1/subscriptions/webhook`
   - Events to listen for:
     - `checkout.session.completed`
     - `customer.subscription.updated`
     - `customer.subscription.deleted`
     - `invoice.payment_failed`
   - Copy the **Signing secret** and add to production `.env`

### 5. Update Environment Variables

Your final `.env` should include:

```bash
# Stripe Configuration
STRIPE_SECRET_KEY=sk_test_your_stripe_secret_key
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret
STRIPE_PRICE_NEIGHBOR=price_your_neighbor_price_id
STRIPE_PRICE_BLOCK=price_your_block_price_id
STRIPE_PRICE_DISTRICT=price_your_district_price_id
```

### 6. Run Database Migration

The Subscription model needs to be added to the database:

```bash
cd api

# Create migration
alembic revision --autogenerate -m "Add subscription model"

# Apply migration
alembic upgrade head
```

## API Endpoints

### POST /api/v1/subscriptions/checkout
Create a Stripe Checkout session to start subscription.

**Request:**
```json
{
  "tier": "neighbor",
  "success_url": "https://your-app.com/success",
  "cancel_url": "https://your-app.com/cancel"
}
```

**Response:**
```json
{
  "session_id": "cs_test_...",
  "url": "https://checkout.stripe.com/c/pay/cs_test_..."
}
```

### POST /api/v1/subscriptions/portal
Create a Customer Portal session for managing subscription.

**Request:**
```json
{
  "return_url": "https://your-app.com/account"
}
```

**Response:**
```json
{
  "url": "https://billing.stripe.com/p/session/..."
}
```

### GET /api/v1/subscriptions/status
Get current subscription status.

**Response:**
```json
{
  "tier": "neighbor",
  "status": "active",
  "current_period_start": "2024-01-01T00:00:00Z",
  "current_period_end": "2024-02-01T00:00:00Z",
  "cancel_at_period_end": false,
  "trial_end": null
}
```

### GET /api/v1/subscriptions/tiers
Get available subscription tiers and pricing.

**Response:**
```json
{
  "tiers": [
    {
      "id": "free",
      "name": "Free",
      "price": 0,
      "currency": "usd",
      "interval": "month",
      "features": ["Your meter data only", "..."],
      "data_access": "Personal data only"
    },
    ...
  ]
}
```

### POST /api/v1/subscriptions/webhook (UNAUTHENTICATED)
Receive Stripe webhook events. This endpoint is called by Stripe, not by your app.

## Testing Subscription Flow

### Test Mode Cards

Use these test cards in Stripe Checkout:

- **Success**: `4242 4242 4242 4242`
- **Declined**: `4000 0000 0000 0002`
- **Requires authentication**: `4000 0027 6000 3184`

Use any future expiration date, any 3-digit CVC, and any postal code.

### Full Flow Test

1. Create a test user:
   ```bash
   curl -X POST http://localhost:8000/api/v1/users/register \
     -H "Content-Type: application/json" \
     -d '{"email": "test@example.com", "display_name": "Test User", "password": "test123"}'
   ```

2. Get the access token from the response

3. Create checkout session:
   ```bash
   curl -X POST http://localhost:8000/api/v1/subscriptions/checkout \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer YOUR_TOKEN" \
     -d '{
       "tier": "neighbor",
       "success_url": "http://localhost:3000/success",
       "cancel_url": "http://localhost:3000/cancel"
     }'
   ```

4. Open the returned `url` in your browser

5. Complete checkout with test card `4242 4242 4242 4242`

6. Verify subscription status:
   ```bash
   curl http://localhost:8000/api/v1/subscriptions/status \
     -H "Authorization: Bearer YOUR_TOKEN"
   ```

## Webhook Events

The integration handles these Stripe events:

### checkout.session.completed
Triggered when a user completes the checkout process.
- Creates or updates Subscription record
- Updates User.subscription_tier and User.subscription_expires_at

### customer.subscription.updated
Triggered when subscription changes (renewal, upgrade, downgrade).
- Updates Subscription status, billing period, cancellation status

### customer.subscription.deleted
Triggered when subscription is canceled.
- Sets Subscription.status to "canceled"
- Downgrades User.subscription_tier to "free"

### invoice.payment_failed
Triggered when a payment fails.
- Sets Subscription.status to "past_due"
- User keeps current tier but may lose access

## Security Considerations

1. **Webhook Signature Verification**: Always verify webhook signatures to ensure events come from Stripe
2. **API Keys**: Never commit API keys to git. Use environment variables
3. **HTTPS**: Use HTTPS in production for webhook endpoint
4. **Customer Portal**: Let users manage subscriptions through Stripe Customer Portal (handles PCI compliance)

## Troubleshooting

### Webhook not receiving events
- Check Stripe CLI is running: `stripe listen --forward-to localhost:8000/api/v1/subscriptions/webhook`
- Verify webhook secret in `.env` matches Stripe CLI output
- Check API server logs for errors

### Checkout session creation fails
- Verify all price IDs are correct in `.env`
- Check Stripe API key is valid
- Ensure user has an email address

### Subscription not updating after payment
- Check webhook endpoint is reachable
- Verify webhook signature is correct
- Check database logs for errors

## Production Checklist

- [ ] Switch from test mode to live mode API keys
- [ ] Create live mode products and prices
- [ ] Update price IDs in production `.env`
- [ ] Configure production webhook endpoint
- [ ] Enable Stripe Radar for fraud protection
- [ ] Set up email receipts in Stripe Dashboard
- [ ] Configure subscription email notifications
- [ ] Test full flow with real card in test mode first
- [ ] Monitor webhook events in Stripe Dashboard

## Referral Rewards Integration

The subscription system integrates with the referral system:

- 1 referral = 1 month Neighbor tier free
- 5 referrals = 25% off forever
- 10 referrals = Block tier for life
- 25 referrals = District tier for life

This logic should be implemented in the webhook handlers or in a separate referral service.

## Support

- [Stripe Documentation](https://stripe.com/docs)
- [Stripe API Reference](https://stripe.com/docs/api)
- [Stripe Subscriptions Guide](https://stripe.com/docs/billing/subscriptions/overview)
- [Testing Stripe](https://stripe.com/docs/testing)
