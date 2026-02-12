-- Migration: Social Features (Training Partners & Leaderboards)
-- Phase 8B — Run in Supabase SQL Editor

-- Training partnerships (mutual consent required)
CREATE TABLE partnerships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    inviter_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    invitee_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending',  -- pending, active, declined, expired, ended
    challenge_type TEXT NOT NULL DEFAULT 'general',  -- general, strength, consistency, weight_loss
    duration_weeks INT,  -- NULL = ongoing
    started_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(inviter_id, invitee_id)
);

-- Invite codes (6-char alphanumeric)
CREATE TABLE invite_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,
    created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    max_uses INT DEFAULT 1,
    use_count INT DEFAULT 0,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS: basic policies (users see their own data)
ALTER TABLE partnerships ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own partnerships" ON partnerships FOR SELECT
    USING (auth.uid() = inviter_id OR auth.uid() = invitee_id);
CREATE POLICY "Users can insert as invitee" ON partnerships FOR INSERT
    WITH CHECK (auth.uid() = invitee_id);
CREATE POLICY "Users can update own partnerships" ON partnerships FOR UPDATE
    USING (auth.uid() = inviter_id OR auth.uid() = invitee_id);

ALTER TABLE invite_codes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own codes" ON invite_codes FOR SELECT
    USING (auth.uid() = created_by);
CREATE POLICY "Users can create codes" ON invite_codes FOR INSERT
    WITH CHECK (auth.uid() = created_by);

-- Indexes for partnership lookups
CREATE INDEX idx_partnerships_inviter ON partnerships(inviter_id, status);
CREATE INDEX idx_partnerships_invitee ON partnerships(invitee_id, status);
CREATE INDEX idx_invite_codes_code ON invite_codes(code);
