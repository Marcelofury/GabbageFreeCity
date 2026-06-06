-- Migration: add subscriptions + rename sack_count to package_count
-- Date: 2026-05-27

-- =============================================
-- Subscription plans
-- =============================================
CREATE TABLE IF NOT EXISTS subscription_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(80) NOT NULL,
    weekly_collections INTEGER NOT NULL CHECK (weekly_collections >= 1),
    monthly_collections INTEGER NOT NULL CHECK (monthly_collections >= 1),
    monthly_price_ugx DECIMAL(10, 2) NOT NULL CHECK (monthly_price_ugx >= 0),
    prepay_months INTEGER NOT NULL DEFAULT 3 CHECK (prepay_months >= 1),
    prepay_price_ugx DECIMAL(10, 2) NOT NULL CHECK (prepay_price_ugx >= 0),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_subscription_plans_active
    ON subscription_plans(is_active);

-- =============================================
-- Subscriptions
-- =============================================
CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    resident_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES subscription_plans(id),
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (
        status IN ('pending', 'active', 'expired', 'cancelled')
    ),
    start_date TIMESTAMP WITH TIME ZONE,
    end_date TIMESTAMP WITH TIME ZONE,
    total_collections INTEGER NOT NULL DEFAULT 0 CHECK (total_collections >= 0),
    remaining_collections INTEGER NOT NULL DEFAULT 0 CHECK (remaining_collections >= 0),
    last_collection_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_subscriptions_resident
    ON subscriptions(resident_id);

CREATE INDEX IF NOT EXISTS idx_subscriptions_status
    ON subscriptions(status);

CREATE INDEX IF NOT EXISTS idx_subscriptions_end_date
    ON subscriptions(end_date);

-- =============================================
-- Garbage reports: rename sack_count to package_count
-- =============================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'garbage_reports'
          AND column_name = 'sack_count'
    ) THEN
        ALTER TABLE garbage_reports RENAME COLUMN sack_count TO package_count;
    END IF;
END
$$;

ALTER TABLE garbage_reports
    ALTER COLUMN package_count SET DEFAULT 1;

ALTER TABLE garbage_reports
    DROP CONSTRAINT IF EXISTS garbage_reports_sack_count_check;

ALTER TABLE garbage_reports
    DROP CONSTRAINT IF EXISTS garbage_reports_package_count_check;

ALTER TABLE garbage_reports
    ADD CONSTRAINT garbage_reports_package_count_check
    CHECK (package_count >= 1);

ALTER TABLE garbage_reports
    ADD COLUMN IF NOT EXISTS subscription_id UUID REFERENCES subscriptions(id);

UPDATE garbage_reports
SET estimated_volume = CONCAT(package_count, ' package', CASE WHEN package_count = 1 THEN '' ELSE 's' END)
WHERE package_count IS NOT NULL;

-- =============================================
-- Payments: allow subscription payments
-- =============================================
ALTER TABLE payments
    ALTER COLUMN report_id DROP NOT NULL;

ALTER TABLE payments
    ADD COLUMN IF NOT EXISTS subscription_id UUID REFERENCES subscriptions(id);

ALTER TABLE payments
    ADD COLUMN IF NOT EXISTS payment_purpose VARCHAR(20) DEFAULT 'report';

ALTER TABLE payments
    DROP CONSTRAINT IF EXISTS payments_payment_purpose_check;

ALTER TABLE payments
    ADD CONSTRAINT payments_payment_purpose_check
    CHECK (payment_purpose IN ('report', 'subscription'));

ALTER TABLE payments
    DROP CONSTRAINT IF EXISTS payments_report_or_subscription_check;

ALTER TABLE payments
    ADD CONSTRAINT payments_report_or_subscription_check
    CHECK (report_id IS NOT NULL OR subscription_id IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_payments_subscription
    ON payments(subscription_id);

-- =============================================
-- Updated apply_marzpay_callback function to support subscriptions
-- =============================================
CREATE OR REPLACE FUNCTION apply_marzpay_callback(
    p_transaction_ref TEXT,
    p_provider_reference TEXT,
    p_provider_status TEXT,
    p_payload JSONB
)
RETURNS TABLE (
    payment_id UUID,
    report_id UUID,
    previous_payment_status VARCHAR,
    new_payment_status VARCHAR,
    previous_order_status VARCHAR,
    new_order_status VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_payment payments%ROWTYPE;
    v_old_order_status VARCHAR(20);
    v_new_order_status VARCHAR(20);
    v_new_payment_status VARCHAR(20);
BEGIN
    SELECT *
    INTO v_payment
    FROM payments
    WHERE transaction_ref = p_transaction_ref OR flw_ref = p_transaction_ref
    LIMIT 1
    FOR UPDATE;

    IF v_payment.id IS NULL THEN
        RETURN;
    END IF;

    v_new_order_status := CASE LOWER(COALESCE(p_provider_status, 'pending'))
        WHEN 'successful' THEN 'completed'
        WHEN 'completed' THEN 'completed'
        WHEN 'failed' THEN 'failed'
        WHEN 'cancelled' THEN 'failed'
        WHEN 'processing' THEN 'pending'
        ELSE 'pending'
    END;

    v_new_payment_status := CASE v_new_order_status
        WHEN 'completed' THEN 'successful'
        WHEN 'failed' THEN 'failed'
        ELSE 'pending'
    END;

    UPDATE payments
    SET
        provider_reference = COALESCE(p_provider_reference, provider_reference),
        transaction_id = COALESCE(p_provider_reference, transaction_id),
        payment_status = v_new_payment_status,
        webhook_response = p_payload,
        completed_at = CASE WHEN v_new_payment_status = 'successful' THEN NOW() ELSE completed_at END,
        updated_at = NOW()
    WHERE id = v_payment.id;

    IF v_payment.report_id IS NOT NULL THEN
        SELECT payment_status
        INTO v_old_order_status
        FROM garbage_reports
        WHERE id = v_payment.report_id
        FOR UPDATE;

        UPDATE garbage_reports
        SET
            payment_status = v_new_order_status,
            updated_at = NOW()
        WHERE id = v_payment.report_id;
    ELSE
        v_old_order_status := NULL;
    END IF;

    RETURN QUERY
    SELECT
        v_payment.id,
        v_payment.report_id,
        v_payment.payment_status,
        v_new_payment_status,
        COALESCE(v_old_order_status, 'pending'),
        v_new_order_status;
END;
$$;

-- =============================================
-- Seed subscription plans (idempotent)
-- =============================================
INSERT INTO subscription_plans (
    name,
    weekly_collections,
    monthly_collections,
    monthly_price_ugx,
    prepay_months,
    prepay_price_ugx,
    is_active
)
SELECT * FROM (
    VALUES
        ('1x weekly package collection', 1, 4, 30000, 3, 90000, true),
        ('2x weekly package collection', 2, 8, 60000, 3, 180000, true)
) AS v(name, weekly_collections, monthly_collections, monthly_price_ugx, prepay_months, prepay_price_ugx, is_active)
WHERE NOT EXISTS (
    SELECT 1 FROM subscription_plans
    WHERE weekly_collections = v.weekly_collections
      AND monthly_collections = v.monthly_collections
      AND prepay_months = v.prepay_months
);
