CREATE TABLE IF NOT EXISTS user_blocks (
    blocker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (blocker_id, blocked_id),
    CONSTRAINT user_blocks_no_self CHECK (blocker_id <> blocked_id)
);

CREATE INDEX IF NOT EXISTS user_blocks_by_blocked_idx
    ON user_blocks (blocked_id, blocker_id);

CREATE TABLE IF NOT EXISTS content_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_type VARCHAR(16) NOT NULL CHECK (target_type IN ('user', 'post', 'comment', 'message')),
    target_id UUID NOT NULL,
    reason VARCHAR(32) NOT NULL CHECK (reason IN ('spam', 'harassment', 'hate_or_discrimination', 'sexual_content', 'violence', 'scam_or_fraud', 'impersonation', 'other')),
    details VARCHAR(1000) NOT NULL DEFAULT '',
    status VARCHAR(16) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewing', 'actioned', 'dismissed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT content_reports_details_length CHECK (char_length(details) <= 1000),
    CONSTRAINT content_reports_unique_reporter_target UNIQUE (reporter_id, target_type, target_id)
);

CREATE INDEX IF NOT EXISTS content_reports_review_queue_idx
    ON content_reports (status, created_at ASC);
