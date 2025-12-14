-- MeterScience Database Schema
-- PostgreSQL with PostGIS

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE,
    display_name VARCHAR(100) NOT NULL,
    avatar_emoji VARCHAR(10) DEFAULT '📊',
    password_hash VARCHAR(255),
    
    -- Gamification
    level INTEGER DEFAULT 1,
    xp INTEGER DEFAULT 0,
    total_readings INTEGER DEFAULT 0,
    verified_readings INTEGER DEFAULT 0,
    verifications_performed INTEGER DEFAULT 0,
    streak_days INTEGER DEFAULT 0,
    last_reading_date TIMESTAMPTZ,
    trust_score INTEGER DEFAULT 50,
    badges JSONB DEFAULT '[]',
    
    -- Subscription
    subscription_tier VARCHAR(20) DEFAULT 'free',
    subscription_expires_at TIMESTAMPTZ,
    stripe_customer_id VARCHAR(100),
    
    -- Referral
    referral_code VARCHAR(10) UNIQUE,
    referred_by UUID REFERENCES users(id),
    referral_count INTEGER DEFAULT 0,
    
    -- Location (approximate, for neighbor matching)
    location GEOGRAPHY(POINT, 4326),
    postal_code VARCHAR(20),
    country VARCHAR(2),
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_login_at TIMESTAMPTZ
);

-- Meters table
CREATE TABLE meters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    name VARCHAR(100) NOT NULL,
    meter_type VARCHAR(20) NOT NULL, -- electric, gas, water, solar
    utility_provider VARCHAR(100),
    account_number VARCHAR(100),
    
    -- Location
    location GEOGRAPHY(POINT, 4326),
    postal_code VARCHAR(20),
    country VARCHAR(2),
    
    -- Learned characteristics
    digit_count INTEGER DEFAULT 6,
    has_decimal_point BOOLEAN DEFAULT FALSE,
    decimal_places INTEGER DEFAULT 0,
    bounding_box JSONB,
    sample_readings JSONB DEFAULT '[]',
    average_confidence FLOAT DEFAULT 0,
    
    -- Calibration
    calibration_image_hash VARCHAR(64),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    last_read_at TIMESTAMPTZ,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Readings table (the core data product)
CREATE TABLE readings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    meter_id UUID NOT NULL REFERENCES meters(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    
    -- The reading
    raw_value VARCHAR(50) NOT NULL,
    normalized_value VARCHAR(50) NOT NULL,
    numeric_value DOUBLE PRECISION,
    
    -- OCR metadata
    confidence FLOAT NOT NULL,
    all_candidates JSONB,
    processing_ms INTEGER,
    
    -- Image context
    image_hash VARCHAR(64),
    image_url VARCHAR(500),
    image_brightness FLOAT,
    image_blur FLOAT,
    bounding_box JSONB,
    
    -- Device context
    device_model VARCHAR(50),
    os_version VARCHAR(20),
    app_version VARCHAR(20),
    
    -- Location (for verification, not stored long-term)
    capture_location GEOGRAPHY(POINT, 4326),
    
    -- Temporal
    captured_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    timezone_offset INTEGER,
    capture_method VARCHAR(20), -- live, photo, gallery, hardware
    
    -- Verification
    verification_status VARCHAR(20) DEFAULT 'pending',
    verification_score FLOAT,
    flagged_for_review BOOLEAN DEFAULT FALSE,
    flag_reason TEXT,
    
    -- Usage calculations
    usage_since_last DOUBLE PRECISION,
    days_since_last DOUBLE PRECISION,
    
    -- Sync status
    synced_at TIMESTAMPTZ,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Verification votes table
CREATE TABLE verification_votes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reading_id UUID NOT NULL REFERENCES readings(id) ON DELETE CASCADE,
    verifier_id UUID NOT NULL REFERENCES users(id),
    
    vote VARCHAR(20) NOT NULL, -- correct, incorrect, unclear
    suggested_value VARCHAR(50),
    verifier_trust_score INTEGER,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(reading_id, verifier_id)
);

-- Campaigns table
CREATE TABLE campaigns (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organizer_id UUID NOT NULL REFERENCES users(id),
    
    name VARCHAR(200) NOT NULL,
    description TEXT,
    
    -- Location
    center_location GEOGRAPHY(POINT, 4326),
    radius_meters DOUBLE PRECISION,
    postal_codes JSONB,
    
    -- Goals
    target_meter_count INTEGER DEFAULT 20,
    target_readings_per_meter INTEGER DEFAULT 30,
    meter_types JSONB DEFAULT '["electric"]',
    
    -- Progress
    participant_count INTEGER DEFAULT 0,
    meters_registered INTEGER DEFAULT 0,
    total_readings INTEGER DEFAULT 0,
    verified_readings INTEGER DEFAULT 0,
    
    -- Timing
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    reading_schedule VARCHAR(20), -- daily, weekly, synchronized, continuous
    
    -- Settings
    is_active BOOLEAN DEFAULT TRUE,
    is_public BOOLEAN DEFAULT TRUE,
    invite_code VARCHAR(20) UNIQUE,
    
    -- Rewards
    xp_bonus INTEGER DEFAULT 10,
    completion_badge_id VARCHAR(50),
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Campaign participants
CREATE TABLE campaign_participants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    campaign_id UUID NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    readings_count INTEGER DEFAULT 0,
    last_reading_at TIMESTAMPTZ,
    
    UNIQUE(campaign_id, user_id)
);

-- Hardware devices (MeterPi)
CREATE TABLE devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id),
    meter_id UUID REFERENCES meters(id),
    
    device_id VARCHAR(64) UNIQUE NOT NULL,
    device_type VARCHAR(50) DEFAULT 'meterpi',
    firmware_version VARCHAR(20),
    
    -- Status
    is_online BOOLEAN DEFAULT FALSE,
    last_seen_at TIMESTAMPTZ,
    last_reading_at TIMESTAMPTZ,
    
    -- Config
    config JSONB,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- API keys (for District tier)
CREATE TABLE api_keys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id),
    
    key_hash VARCHAR(64) NOT NULL,
    key_prefix VARCHAR(10) NOT NULL, -- For identification
    name VARCHAR(100),
    
    -- Limits
    rate_limit INTEGER DEFAULT 60, -- Per minute
    request_count INTEGER DEFAULT 0,
    last_used_at TIMESTAMPTZ,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    expires_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Webhooks (for District tier)
CREATE TABLE webhooks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id),
    
    url VARCHAR(500) NOT NULL,
    events JSONB NOT NULL, -- ['reading.created', 'reading.verified']
    secret VARCHAR(64),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    failure_count INTEGER DEFAULT 0,
    last_triggered_at TIMESTAMPTZ,
    last_success_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_readings_meter_id ON readings(meter_id);
CREATE INDEX idx_readings_user_id ON readings(user_id);
CREATE INDEX idx_readings_captured_at ON readings(captured_at DESC);
CREATE INDEX idx_readings_verification_status ON readings(verification_status);
CREATE INDEX idx_readings_flagged ON readings(flagged_for_review) WHERE flagged_for_review = TRUE;

CREATE INDEX idx_meters_user_id ON meters(user_id);
CREATE INDEX idx_meters_location ON meters USING GIST(location);
CREATE INDEX idx_meters_postal_code ON meters(postal_code);

CREATE INDEX idx_users_referral_code ON users(referral_code);
CREATE INDEX idx_users_location ON users USING GIST(location);
CREATE INDEX idx_users_postal_code ON users(postal_code);

CREATE INDEX idx_campaigns_location ON campaigns USING GIST(center_location);
CREATE INDEX idx_campaigns_active ON campaigns(is_active, is_public, end_date);

-- Functions
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers
CREATE TRIGGER users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER meters_updated_at BEFORE UPDATE ON meters
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER campaigns_updated_at BEFORE UPDATE ON campaigns
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER devices_updated_at BEFORE UPDATE ON devices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Materialized view for neighbor stats (refreshed periodically)
CREATE MATERIALIZED VIEW neighbor_stats AS
SELECT 
    LEFT(m.postal_code, 3) as postal_prefix,
    m.meter_type,
    COUNT(DISTINCT m.id) as meter_count,
    COUNT(r.id) as reading_count,
    AVG(r.usage_since_last / NULLIF(r.days_since_last, 0)) as avg_daily_usage,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY r.usage_since_last / NULLIF(r.days_since_last, 0)) as median_daily_usage,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY r.usage_since_last / NULLIF(r.days_since_last, 0)) as p25_daily_usage,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY r.usage_since_last / NULLIF(r.days_since_last, 0)) as p75_daily_usage,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY r.usage_since_last / NULLIF(r.days_since_last, 0)) as p90_daily_usage
FROM meters m
JOIN readings r ON r.meter_id = m.id
WHERE r.captured_at > NOW() - INTERVAL '30 days'
    AND r.usage_since_last IS NOT NULL
    AND r.days_since_last > 0
GROUP BY LEFT(m.postal_code, 3), m.meter_type
HAVING COUNT(DISTINCT m.user_id) >= 5; -- Privacy threshold

CREATE UNIQUE INDEX ON neighbor_stats(postal_prefix, meter_type);

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;
