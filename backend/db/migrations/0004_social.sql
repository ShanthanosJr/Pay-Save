-- Public profile, profile photo, follows, blocks and 1:1 chat.
-- Phone, email, NIC and age never leave the owner's own /users/me response.

CREATE EXTENSION IF NOT EXISTS pg_trgm;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS username          TEXT UNIQUE CHECK (username ~ '^[a-z0-9._]{3,30}$'),
  ADD COLUMN IF NOT EXISTS bio               TEXT CHECK (char_length(bio) <= 160),
  ADD COLUMN IF NOT EXISTS city              TEXT CHECK (char_length(city) <= 60),
  ADD COLUMN IF NOT EXISTS avatar_updated_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS users_full_name_trgm_idx ON users USING gin (lower(full_name) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS users_username_trgm_idx  ON users USING gin (username gin_trgm_ops);

-- Kept out of the users row so profile reads never drag image bytes along.
-- Swap for S3 (MASTER_PLAN storage) behind AvatarStorage without touching callers.
CREATE TABLE IF NOT EXISTS user_avatars (
  user_id      UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  content_type TEXT NOT NULL CHECK (content_type IN ('image/jpeg', 'image/png', 'image/webp')),
  data         BYTEA NOT NULL CHECK (octet_length(data) <= 2097152),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_follows (
  follower_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  followee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (follower_id, followee_id),
  CHECK (follower_id <> followee_id)
);
CREATE INDEX IF NOT EXISTS user_follows_followee_idx ON user_follows (followee_id);

CREATE TABLE IF NOT EXISTS user_blocks (
  blocker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id),
  CHECK (blocker_id <> blocked_id)
);
CREATE INDEX IF NOT EXISTS user_blocks_blocked_idx ON user_blocks (blocked_id);

-- One conversation per pair: (user_low, user_high) is the ordered pair.
CREATE TABLE IF NOT EXISTS conversations (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_low        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_high       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_message_at TIMESTAMPTZ,
  UNIQUE (user_low, user_high),
  CHECK (user_low < user_high)
);

CREATE TABLE IF NOT EXISTS conversation_members (
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  last_read_seq   BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (conversation_id, user_id)
);
CREATE INDEX IF NOT EXISTS conversation_members_user_idx ON conversation_members (user_id);

CREATE TABLE IF NOT EXISTS messages (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seq               BIGINT GENERATED ALWAYS AS IDENTITY UNIQUE,
  conversation_id   UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  client_message_id UUID NOT NULL,               -- device-generated; retries reuse it
  body              TEXT NOT NULL CHECK (char_length(body) BETWEEN 1 AND 2000),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (sender_id, client_message_id)
);
CREATE INDEX IF NOT EXISTS messages_conversation_seq_idx ON messages (conversation_id, seq DESC);
