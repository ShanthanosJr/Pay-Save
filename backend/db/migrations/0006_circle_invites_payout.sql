-- Circle membership by invitation (organizer's pals only) and members'
-- payout details: how each member wants to receive money.
-- Pay&Save only shows these details; it never moves money (ADR-0003).

-- Who members pay each cycle:
--   direct_to_recipient: every member pays this cycle's turn recipient
--   via_organizer:       members pay the organizer, who hands over the pot
DO $$ BEGIN
  CREATE TYPE collection_mode AS ENUM ('direct_to_recipient', 'via_organizer');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

ALTER TABLE circles
  ADD COLUMN IF NOT EXISTS collection_mode collection_mode NOT NULL DEFAULT 'direct_to_recipient';

-- ---------- invitations ----------
CREATE TABLE IF NOT EXISTS circle_invitations (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  circle_id    UUID NOT NULL REFERENCES circles(id) ON DELETE CASCADE,
  invitee_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  invited_by   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status       TEXT NOT NULL DEFAULT 'pending'
               CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled')),
  message      TEXT CHECK (char_length(message) <= 200),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  responded_at TIMESTAMPTZ,
  CHECK (invitee_id <> invited_by)
);
CREATE UNIQUE INDEX IF NOT EXISTS circle_invitations_one_pending
  ON circle_invitations (circle_id, invitee_id) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS circle_invitations_invitee_idx
  ON circle_invitations (invitee_id) WHERE status = 'pending';

-- ---------- payout methods ----------
-- One row per way a member can be paid. The sensitive part (account or
-- wallet number, QR payload, holder name) is AES-GCM encrypted as one JSON
-- blob; `summary` is a safe, already-masked line such as "BOC · ••••4821".
CREATE TABLE IF NOT EXISTS payout_methods (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind              TEXT NOT NULL CHECK (kind IN ('bank_transfer', 'mobile_wallet', 'lankaqr', 'cash')),
  summary           TEXT NOT NULL CHECK (char_length(summary) <= 120),
  details_encrypted BYTEA NOT NULL,
  is_default        BOOLEAN NOT NULL DEFAULT false,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  archived_at       TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS payout_methods_user_idx ON payout_methods (user_id) WHERE archived_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS payout_methods_one_default
  ON payout_methods (user_id) WHERE is_default AND archived_at IS NULL;

-- Which of a member's methods each circle may see; one is preferred.
CREATE TABLE IF NOT EXISTS circle_payout_shares (
  circle_id  UUID NOT NULL REFERENCES circles(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  method_id  UUID NOT NULL REFERENCES payout_methods(id) ON DELETE CASCADE,
  preferred  BOOLEAN NOT NULL DEFAULT false,
  shared_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (circle_id, method_id)
);
CREATE INDEX IF NOT EXISTS circle_payout_shares_member_idx ON circle_payout_shares (circle_id, user_id);

-- Every time full details are shown to someone other than their owner.
CREATE TABLE IF NOT EXISTS payout_detail_access_log (
  id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  circle_id  UUID NOT NULL REFERENCES circles(id) ON DELETE CASCADE,
  viewer_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  owner_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  cycle_id   UUID REFERENCES cycles(id) ON DELETE CASCADE,
  viewed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS payout_detail_access_owner_idx ON payout_detail_access_log (owner_id, viewed_at DESC);
