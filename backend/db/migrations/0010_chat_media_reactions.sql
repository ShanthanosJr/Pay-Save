-- Richer chat: photos and videos, emoji reactions, delete-for-everyone,
-- starred messages, and per-person pin / favourite / clear for a chat.

ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_body_check;
ALTER TABLE messages ADD CONSTRAINT messages_body_check CHECK (char_length(body) <= 2000);
ALTER TABLE messages
  ADD COLUMN IF NOT EXISTS kind TEXT NOT NULL DEFAULT 'text' CHECK (kind IN ('text', 'image', 'video')),
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- Postgres for now, like profile photos; object storage later.
CREATE TABLE IF NOT EXISTS chat_attachments (
  message_id   UUID PRIMARY KEY REFERENCES messages(id) ON DELETE CASCADE,
  content_type TEXT NOT NULL,
  size         INT  NOT NULL CHECK (size > 0),
  data         BYTEA NOT NULL
);

CREATE TABLE IF NOT EXISTS message_reactions (
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  emoji      TEXT NOT NULL CHECK (char_length(emoji) <= 16),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, user_id)
);

CREATE TABLE IF NOT EXISTS message_stars (
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  starred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, user_id)
);

-- Each person organises their own inbox; nothing here is visible to the other.
ALTER TABLE conversation_members
  ADD COLUMN IF NOT EXISTS pinned_at   TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS favourite   BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS cleared_seq BIGINT  NOT NULL DEFAULT 0;   -- "delete chat" hides everything up to here, for me only
