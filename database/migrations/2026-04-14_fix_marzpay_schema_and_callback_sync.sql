-- Migration: fix MarzPay schema drift and callback sync reliability
-- Safe to run multiple times.

ALTER TABLE payments
    ADD COLUMN IF NOT EXISTS transaction_ref VARCHAR(120);

ALTER TABLE payments
    ADD COLUMN IF NOT EXISTS provider_reference VARCHAR(120);

CREATE UNIQUE INDEX IF NOT EXISTS idx_payments_transaction_ref_unique
    ON payments(transaction_ref);

CREATE INDEX IF NOT EXISTS idx_payments_provider_reference
    ON payments(provider_reference);

ALTER TABLE garbage_reports
    ADD COLUMN IF NOT EXISTS payment_status VARCHAR(20) DEFAULT 'pending';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'garbage_reports_payment_status_check'
    ) THEN
        ALTER TABLE garbage_reports
            ADD CONSTRAINT garbage_reports_payment_status_check
            CHECK (payment_status IN ('pending', 'processing', 'completed', 'failed', 'cancelled'));
    END IF;
END
$$;

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

    SELECT payment_status
    INTO v_old_order_status
    FROM garbage_reports
    WHERE id = v_payment.report_id
    FOR UPDATE;

    UPDATE payments
    SET
        provider_reference = COALESCE(p_provider_reference, provider_reference),
        transaction_id = COALESCE(p_provider_reference, transaction_id),
        payment_status = v_new_payment_status,
        webhook_response = p_payload,
        completed_at = CASE WHEN v_new_payment_status = 'successful' THEN NOW() ELSE completed_at END,
        updated_at = NOW()
    WHERE id = v_payment.id;

    UPDATE garbage_reports
    SET
        payment_status = v_new_order_status,
        updated_at = NOW()
    WHERE id = v_payment.report_id;

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
