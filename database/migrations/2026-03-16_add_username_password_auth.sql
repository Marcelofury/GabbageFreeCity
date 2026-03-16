-- Migration: add username/password auth support for existing databases

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS username VARCHAR(50);

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS password_hash TEXT;

-- Backfill deterministic unique usernames for existing rows
UPDATE users
SET username = CONCAT('user_', SUBSTRING(id::text, 1, 8))
WHERE username IS NULL OR TRIM(username) = '';

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_username_unique
    ON users(username);
