-- =====================================================
-- Garbage Free City (GFC) - Supabase Database Schema
-- Smart Waste Management System for Kampala (KCCA)
-- =====================================================

-- Enable PostGIS extension for geographic data
CREATE EXTENSION IF NOT EXISTS postgis;

-- =====================================================
-- USERS TABLE
-- Stores both residents and waste collectors
-- =====================================================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone_number VARCHAR(15) UNIQUE NOT NULL, -- Uganda format: +256XXXXXXXXX
    full_name VARCHAR(100) NOT NULL,
    user_type VARCHAR(20) NOT NULL CHECK (user_type IN ('resident', 'collector')),
    email VARCHAR(100),
    
    -- Location data using PostGIS geography type
    -- Geography type uses WGS84 (GPS coordinates) by default
    home_location GEOGRAPHY(Point, 4326), -- For residents
    current_location GEOGRAPHY(Point, 4326), -- For collectors (updates in real-time)
    
    -- Additional fields
    area VARCHAR(100), -- e.g., Nakawa, Kawempe, Rubaga, etc.
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Index for faster location queries
    CONSTRAINT valid_user_type CHECK (
        (user_type = 'resident' AND home_location IS NOT NULL) OR
        (user_type = 'collector')
    )
);

-- Create spatial index for faster geographic queries
CREATE INDEX idx_users_home_location ON users USING GIST(home_location);
CREATE INDEX idx_users_current_location ON users USING GIST(current_location);
CREATE INDEX idx_users_phone ON users(phone_number);
CREATE INDEX idx_users_type ON users(user_type);

-- =====================================================
-- GARBAGE_REPORTS TABLE
-- Stores garbage pile-up reports from residents
-- =====================================================
CREATE TABLE garbage_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    resident_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Location using PostGIS geography
    location GEOGRAPHY(Point, 4326) NOT NULL,
    address_description TEXT, -- e.g., "Near Nakawa Market, behind MTN office"
    
    -- Report details
    garbage_type VARCHAR(50) DEFAULT 'mixed', -- mixed, plastic, organic, etc.
    estimated_volume VARCHAR(20), -- small, medium, large
    photo_url TEXT, -- Optional photo evidence
    description TEXT,
    
    -- Status tracking
    status VARCHAR(20) DEFAULT 'pending' CHECK (
        status IN ('pending', 'assigned', 'in_progress', 'completed', 'cancelled')
    ),
    assigned_collector_id UUID REFERENCES users(id),
    
    -- Payment tracking
    payment_required BOOLEAN DEFAULT true,
    payment_amount DECIMAL(10, 2) DEFAULT 5000.00, -- Default UGX 5,000
    
    -- Timestamps
    reported_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    assigned_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create spatial index for location-based queries
CREATE INDEX idx_garbage_reports_location ON garbage_reports USING GIST(location);
CREATE INDEX idx_garbage_reports_status ON garbage_reports(status);
CREATE INDEX idx_garbage_reports_resident ON garbage_reports(resident_id);
CREATE INDEX idx_garbage_reports_collector ON garbage_reports(assigned_collector_id);

-- =====================================================
-- PAYMENTS TABLE
-- Tracks Mobile Money payments via Flutterwave
-- =====================================================
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id UUID NOT NULL REFERENCES garbage_reports(id) ON DELETE CASCADE,
    resident_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Flutterwave transaction details
    transaction_id VARCHAR(100) UNIQUE, -- Flutterwave transaction ID
    flw_ref VARCHAR(100) UNIQUE, -- Flutterwave reference
    
    -- Payment details
    amount DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'UGX',
    payment_method VARCHAR(50) DEFAULT 'mobile_money', -- mobile_money, card
    phone_number VARCHAR(15), -- Mobile Money number
    
    -- Status tracking
    payment_status VARCHAR(20) DEFAULT 'pending' CHECK (
        payment_status IN ('pending', 'processing', 'successful', 'failed', 'cancelled')
    ),
    
    -- Webhook data
    webhook_response JSONB, -- Store full Flutterwave webhook payload
    failure_reason TEXT,
    
    -- Timestamps
    initiated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_payments_report ON payments(report_id);
CREATE INDEX idx_payments_resident ON payments(resident_id);
CREATE INDEX idx_payments_status ON payments(payment_status);
CREATE INDEX idx_payments_transaction_id ON payments(transaction_id);
CREATE INDEX idx_payments_flw_ref ON payments(flw_ref);

-- =====================================================
-- COLLECTION_LOGS TABLE
-- Tracks actual collection activities with QR code scans
-- =====================================================
CREATE TABLE collection_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id UUID NOT NULL REFERENCES garbage_reports(id) ON DELETE CASCADE,
    collector_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Collection verification
    qr_code_scanned BOOLEAN DEFAULT false,
    qr_scan_timestamp TIMESTAMP WITH TIME ZONE,
    
    -- Collection location (where collector actually was)
    collection_location GEOGRAPHY(Point, 4326),
    
    -- Distance verification (between reported and actual collection location)
    distance_from_report DECIMAL(10, 2), -- in meters
    
    -- Collection details
    actual_volume VARCHAR(20),
    notes TEXT,
    photo_url TEXT, -- Photo after collection
    
    -- Timestamps
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_collection_logs_report ON collection_logs(report_id);
CREATE INDEX idx_collection_logs_collector ON collection_logs(collector_id);
CREATE INDEX idx_collection_logs_location ON collection_logs USING GIST(collection_location);

-- =====================================================
-- USEFUL POSTGIS FUNCTIONS FOR THE APPLICATION
-- =====================================================

-- Function to find the nearest available collector to a report
-- Usage: SELECT * FROM find_nearest_collector('report_uuid');
CREATE OR REPLACE FUNCTION find_nearest_collector(report_uuid UUID)
RETURNS TABLE (
    collector_id UUID,
    collector_name VARCHAR,
    collector_phone VARCHAR,
    distance_meters DECIMAL,
    current_lat DECIMAL,
    current_lng DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.full_name,
        u.phone_number,
        ST_Distance(u.current_location, gr.location)::DECIMAL as distance,
        ST_Y(u.current_location::geometry)::DECIMAL as lat,
        ST_X(u.current_location::geometry)::DECIMAL as lng
    FROM users u
    CROSS JOIN garbage_reports gr
    WHERE gr.id = report_uuid
        AND u.user_type = 'collector'
        AND u.is_active = true
        AND u.current_location IS NOT NULL
    ORDER BY ST_Distance(u.current_location, gr.location) ASC
    LIMIT 5;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate distance between two points
-- Usage: SELECT calculate_distance('POINT(lng1 lat1)', 'POINT(lng2 lat2)');
CREATE OR REPLACE FUNCTION calculate_distance(loc1 GEOGRAPHY, loc2 GEOGRAPHY)
RETURNS DECIMAL AS $$
BEGIN
    RETURN ST_Distance(loc1, loc2)::DECIMAL;
END;
$$ LANGUAGE plpgsql;

-- Function to update timestamp automatically
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply auto-update triggers to all tables
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_garbage_reports_updated_at BEFORE UPDATE ON garbage_reports
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_payments_updated_at BEFORE UPDATE ON payments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_collection_logs_updated_at BEFORE UPDATE ON collection_logs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- SAMPLE DATA FOR TESTING (KAMPALA LOCATIONS)
-- =====================================================

-- Insert sample resident (Nakawa area)
-- Coordinates: 0.3476° N, 32.6169° E (Nakawa)
INSERT INTO users (phone_number, full_name, user_type, home_location, area)
VALUES (
    '+256700123456',
    'John Mukasa',
    'resident',
    ST_GeogFromText('POINT(32.6169 0.3476)'),
    'Nakawa'
);

-- Insert sample collector (Mobile, starts at Kampala Central)
-- Coordinates: 0.3163° N, 32.5822° E (City Centre)
INSERT INTO users (phone_number, full_name, user_type, current_location, area)
VALUES (
    '+256700654321',
    'Sarah Nakato',
    'collector',
    ST_GeogFromText('POINT(32.5822 0.3163)'),
    'Central Division'
);

-- =====================================================
-- NOTES FOR DEVELOPERS
-- =====================================================
/*
1. COORDINATE FORMAT: PostGIS uses (longitude, latitude) not (lat, lng)
   - Uganda is around: 0.3476° N, 32.6169° E
   - Format: POINT(32.6169 0.3476) = POINT(lng lat)

2. DISTANCE CALCULATIONS:
   - ST_Distance() returns meters by default for geography type
   - For kilometers: ST_Distance(loc1, loc2) / 1000

3. CREATING POINTS FROM APP:
   - From Flutter/Node: ST_GeogFromText('POINT(lng lat)')
   - Or use ST_MakePoint(lng, lat)::geography

4. QUERYING NEARBY REPORTS:
   - Find reports within 5km of a collector:
     WHERE ST_DWithin(collector_location, report_location, 5000)

5. MOBILE MONEY IN UGANDA:
   - MTN Mobile Money: Most popular
   - Airtel Money: Second
   - Flutterwave supports both via their API

6. SMS NOTIFICATIONS:
   - Africa's Talking supports UGX payments
   - Use shortcodes for KCCA branding
*/
