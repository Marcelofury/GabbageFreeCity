-- Migration: move report pricing to sack-based model (UGX 500 per sack)

ALTER TABLE garbage_reports
    ADD COLUMN IF NOT EXISTS sack_count INTEGER NOT NULL DEFAULT 1;

ALTER TABLE garbage_reports
    DROP CONSTRAINT IF EXISTS garbage_reports_sack_count_check;

ALTER TABLE garbage_reports
    ADD CONSTRAINT garbage_reports_sack_count_check
    CHECK (sack_count >= 1);

-- Backfill sack_count based on old estimated_volume values for existing records.
UPDATE garbage_reports
SET sack_count = CASE
    WHEN LOWER(COALESCE(estimated_volume, '')) = 'small' THEN 1
    WHEN LOWER(COALESCE(estimated_volume, '')) = 'medium' THEN 2
    WHEN LOWER(COALESCE(estimated_volume, '')) = 'large' THEN 3
    ELSE 1
END
WHERE sack_count IS NULL OR sack_count < 1;

-- Recompute amount from sack count using UGX 500 per sack.
UPDATE garbage_reports
SET payment_amount = sack_count * 500
WHERE payment_required = true;

-- Keep a readable label in estimated_volume for backward compatibility.
UPDATE garbage_reports
SET estimated_volume = CONCAT(sack_count, ' sack', CASE WHEN sack_count = 1 THEN '' ELSE 's' END);
