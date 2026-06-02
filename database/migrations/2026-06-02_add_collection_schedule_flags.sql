-- Add schedule flags for collection proof
ALTER TABLE collection_logs
    ADD COLUMN IF NOT EXISTS scheduled_days TEXT,
    ADD COLUMN IF NOT EXISTS out_of_schedule BOOLEAN DEFAULT false;
