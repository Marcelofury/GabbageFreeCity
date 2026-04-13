-- Migration: add admin support and collector-management safety updates

ALTER TABLE users
    ADD COLUMN is_admin BOOLEAN DEFAULT false;

-- Allow admin as a user_type value.
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_user_type_check;
ALTER TABLE users DROP CONSTRAINT IF EXISTS valid_user_type;

ALTER TABLE users
    ADD CONSTRAINT users_user_type_check
    CHECK (user_type IN ('resident', 'collector', 'admin'));

-- Keep location rule flexible enough for admin accounts.
ALTER TABLE users
    ADD CONSTRAINT valid_user_type
    CHECK (
        (user_type = 'resident' AND home_location IS NOT NULL)
        OR (user_type = 'collector')
        OR (user_type = 'admin')
    );

CREATE INDEX idx_users_is_admin ON users(is_admin);
