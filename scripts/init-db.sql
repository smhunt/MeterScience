-- MeterScience Database Schema
-- PostgreSQL with PostGIS

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";  -- For text search

-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE,
    display_name VARCHAR(100) NOT NULL DEFAULT 'Reader',
    avatar_emoji VARCHAR(10) DEFAULT '📊',
    
    -- Auth
    password_hash VARCHAR(255),
    auth_provider VARCHAR(50),  -- 'apple', 'google', 'email'
    auth_provider_id VARCHAR(255),
    
    -- Subscription
    subscription_tier VARCHAR(20) DEFAULT 'free',
    subscription_expires_at TIMESTAMP,
    stripe_customer_id VARCHAR(255),
    
    -- Gamification
    level INTEGER DEFAULT 1,
    xp INTEGER DEFAULT 0,
    total_readings INTEGER DEFAULT 0,
    verified_readings INTEGER DEFAULT 0,
    verifications_performed INTEGER DEFAULT 0,
    streak_days INTEGER DEFAULT 0,
    last_reading_date DATE,
    trust_score INTEGER DEFAULT 50,
    
    -- Referrals
    referral_code VARCHAR(10) UNIQUE,
    referred_by UUID REFERENCES users(id),
    referral_count INTEGER DEFAULT 0,
    
    -- Location (for neighbor matching)
    location GEOGRAPHY(POINT, 4326),
    postal_code VARCHAR(20),
    country VARCHAR(2),
    
    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    last_active_at TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- User badges
CREATE TABLE user_badges (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    badge_id VARCHAR(50) NOT NULL,
    earned_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, badge_id)
);

-- Meters table
CREATE TABLE meters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    
    name VARCHAR(100) NOT NULL,
    meter_type VARCHAR(20) NOT NULL,  -- 'electric', 'gas', 'water', 'solar'
    utility_provider VARCHAR(100),
    account_number VARCHAR(100),
    
    -- Learned characteristics
    digit_count INTEGER DEFAULT 6,
    has_decimal_point BOOLEAN DEFAULT FALSE,
    decimal_places INTEGER DEFAULT 0,
    bounding_box JSONB,
    
    -- Calibration
    calibration_image_hash VARCHAR(64),
    sample_readings TEXT[],
    average_confidence REAL DEFAULT 0,
    
    -- Location
    location GEOGRAPHY(POINT, 4326),
    postal_code VARCHAR(20),
    country VARCHAR(2),
    
    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    last_read_at TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Readings table
CREATE TABLE readings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    meter_id UUID REFERENCES meters(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- The reading
    raw_value VARCHAR(50) NOT NULL,
    normalized_value VARCHAR(50) NOT NULL,
    numeric_value DECIMAL(15, 3),
    
    -- OCR metadata
    confidence REAL NOT NULL,
    all_candidates JSONB,
    processing_time_ms INTEGER,
    
    -- Image
    image_hash VARCHAR(64),
    image_url VARCHAR(500),
    image_brightness REAL,
    image_blur REAL,
    bounding_box JSONB,
    
    -- Device
    device_model VARCHAR(100),
    os_version VARCHAR(50),
    app_version VARCHAR(20),
    capture_method VARCHAR(20),  -- 'live', 'photo', 'gallery', 'meterpi'
    
    -- Location (at time of reading)
    location GEOGRAPHY(POINT, 4326),
    horizontal_accuracy REAL,
    
    -- Time
    timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
    timezone_offset INTEGER,
    
    -- Verification
    verification_status VARCHAR(20) DEFAULT 'pending',
    verification_score REAL,
    flagged_for_review BOOLEAN DEFAULT FALSE,
    flag_reason TEXT,
    
    -- Usage (computed)
    usage_since_last DECIMAL(15, 3),
    days_since_last REAL,
    
    -- Sync
    synced_at TIMESTAMP,
    meterpi_device_id VARCHAR(64)
);

-- Verification votes
CREATE TABLE verification_votes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reading_id UUID REFERENCES readings(id) ON DELETE CASCADE,
    verifier_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
    vote VARCHAR(20) NOT NULL,  -- 'correct', 'incorrect', 'unclear'
    suggested_value VARCHAR(50),
    verifier_trust_score INTEGER,
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- Campaigns
CREATE TABLE campaigns (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organizer_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
    name VARCHAR(200) NOT NULL,
    description TEXT,
    invite_code VARCHAR(10) UNIQUE,
    
    -- Location
    center_location GEOGRAPHY(POINT, 4326),
    radius_meters INTEGER,
    postal_codes TEXT[],
    
    -- Goals
    target_meter_count INTEGER,
    target_readings_per_meter INTEGER,
    meter_types TEXT[],
    reading_schedule VARCHAR(20),  -- 'daily', 'weekly', 'synchronized', 'continuous'
    
    -- Progress
    participant_count INTEGER DEFAULT 0,
    meters_registered INTEGER DEFAULT 0,
    total_readings INTEGER DEFAULT 0,
    verified_readings INTEGER DEFAULT 0,
    
    -- Timing
    start_date TIMESTAMP,
    end_date TIMESTAMP,
    
    -- Rewards
    xp_bonus INTEGER DEFAULT 0,
    completion_badge_id VARCHAR(50),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_public BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Campaign participants
CREATE TABLE campaign_participants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    campaign_id UUID REFERENCES campaigns(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    
    joined_at TIMESTAMP DEFAULT NOW(),
    readings_count INTEGER DEFAULT 0,
    last_reading_at TIMESTAMP,
    
    UNIQUE(campaign_id, user_id)
);

-- Campaign meters
CREATE TABLE campaign_meters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    campaign_id UUID REFERENCES campaigns(id) ON DELETE CASCADE,
    meter_id UUID REFERENCES meters(id) ON DELETE CASCADE,
    
    added_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(campaign_id, meter_id)
);

-- Referrals tracking
CREATE TABLE referrals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    referrer_id UUID REFERENCES users(id) ON DELETE SET NULL,
    referred_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
    referral_code VARCHAR(10),
    converted BOOLEAN DEFAULT FALSE,
    conversion_tier VARCHAR(20),
    conversion_date TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- API keys for enterprise
CREATE TABLE api_keys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    
    api_key VARCHAR(64) UNIQUE NOT NULL,
    api_secret_hash VARCHAR(255) NOT NULL,
    name VARCHAR(100),
    
    rate_limit INTEGER DEFAULT 60,  -- per minute
    request_count BIGINT DEFAULT 0,
    last_used_at TIMESTAMP,
    
    scopes TEXT[],  -- 'readings:read', 'readings:write', 'stats:read'
    
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Webhook subscriptions
CREATE TABLE webhooks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    
    url VARCHAR(500) NOT NULL,
    secret VARCHAR(64),
    
    events TEXT[],  -- 'reading.created', 'reading.verified', etc.
    filters JSONB,  -- region, meter_type filters
    
    last_triggered_at TIMESTAMP,
    failure_count INTEGER DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE
);

-- Analytics events
CREATE TABLE analytics_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
    event_type VARCHAR(50) NOT NULL,
    properties JSONB,
    
    timestamp TIMESTAMP DEFAULT NOW()
);

-- MeterPi devices
CREATE TABLE meterpi_devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    meter_id UUID REFERENCES meters(id) ON DELETE SET NULL,
    
    device_id VARCHAR(64) UNIQUE NOT NULL,
    name VARCHAR(100),
    
    firmware_version VARCHAR(20),
    last_seen_at TIMESTAMP,
    last_reading_at TIMESTAMP,
    
    config JSONB,
    
    created_at TIMESTAMP DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE
);

-- Indexes for performance
CREATE INDEX idx_readings_meter_id ON readings(meter_id);
CREATE INDEX idx_readings_timestamp ON readings(timestamp DESC);
CREATE INDEX idx_readings_verification_status ON readings(verification_status);
CREATE INDEX idx_readings_location ON readings USING GIST(location);

CREATE INDEX idx_meters_user_id ON meters(user_id);
CREATE INDEX idx_meters_location ON meters USING GIST(location);
CREATE INDEX idx_meters_postal_code ON meters(postal_code);

CREATE INDEX idx_users_referral_code ON users(referral_code);
CREATE INDEX idx_users_location ON users USING GIST(location);
CREATE INDEX idx_users_postal_code ON users(postal_code);

CREATE INDEX idx_campaigns_location ON campaigns USING GIST(center_location);
CREATE INDEX idx_campaigns_invite_code ON campaigns(invite_code);

CREATE INDEX idx_analytics_event_type ON analytics_events(event_type);
CREATE INDEX idx_analytics_timestamp ON analytics_events(timestamp DESC);

-- Functions

-- Update updated_at timestamp
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

-- View for neighbor stats (anonymized)
CREATE OR REPLACE VIEW neighbor_stats AS
SELECT 
    LEFT(m.postal_code, 3) as postal_prefix,
    m.meter_type,
    COUNT(DISTINCT m.id) as meter_count,
    COUNT(r.id) as reading_count,
    AVG(r.usage_since_last / NULLIF(r.days_since_last, 0)) as avg_daily_usage,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY r.usage_since_last / NULLIF(r.days_since_last, 0)) as median_daily_usage
FROM meters m
LEFT JOIN readings r ON r.meter_id = m.id
WHERE m.postal_code IS NOT NULL
GROUP BY LEFT(m.postal_code, 3), m.meter_type
HAVING COUNT(DISTINCT m.id) >= 5;  -- Privacy threshold
