-- Phase 10: APNs Push Infrastructure
-- Creates device_tokens table for storing APNs device tokens per user.

CREATE TABLE IF NOT EXISTS device_tokens (
    id          UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id     UUID        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    device_token TEXT       NOT NULL,
    platform    TEXT        NOT NULL DEFAULT 'ios',
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Unique constraint so upsert on (user_id, device_token) works cleanly
CREATE UNIQUE INDEX IF NOT EXISTS idx_device_tokens_user_token
    ON device_tokens (user_id, device_token);

-- Row Level Security — users can only manage their own tokens.
-- Backend push sending uses the service_role key (bypasses RLS), so
-- the policy only needs to guard user-facing CRUD.
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own device tokens"
    ON device_tokens
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
