CREATE TABLE IF NOT EXISTS user_sessions (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ,
    CONSTRAINT user_sessions_expiry_after_creation CHECK (expires_at > created_at)
);

CREATE INDEX IF NOT EXISTS user_sessions_active_by_user_idx
    ON user_sessions (user_id, expires_at DESC)
    WHERE revoked_at IS NULL;
