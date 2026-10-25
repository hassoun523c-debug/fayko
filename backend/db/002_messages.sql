CREATE TABLE IF NOT EXISTS conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    direct_key TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS conversation_members (
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (conversation_id, user_id)
);

CREATE INDEX IF NOT EXISTS conversation_members_by_user_idx
    ON conversation_members (user_id, joined_at DESC);

CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL,
    sender_id UUID NOT NULL,
    body VARCHAR(4000) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    edited_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT messages_body_length CHECK (char_length(body) BETWEEN 1 AND 4000),
    CONSTRAINT messages_sender_membership_fk
      FOREIGN KEY (conversation_id, sender_id)
      REFERENCES conversation_members (conversation_id, user_id)
      ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS messages_conversation_cursor_idx
    ON messages (conversation_id, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS messages_sender_cursor_idx
    ON messages (sender_id, created_at DESC, id DESC);
