-- Idempotent migration for existing databases
-- Adds notifications support without recreating core tables.

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(150) NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(30) NOT NULL DEFAULT 'system' CHECK (
        type IN ('payment', 'assignment', 'report', 'collection', 'system')
    ),
    is_read BOOLEAN DEFAULT false,
    data JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    read_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_notifications_user
    ON notifications(user_id);

CREATE INDEX IF NOT EXISTS idx_notifications_user_created
    ON notifications(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_unread
    ON notifications(user_id, is_read);
