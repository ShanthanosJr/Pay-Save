-- Notifications inbox and reminders (FR-03), member removal (FR-05),
-- verified statements (FR-11) and the community tier (FR-10).

-- ---------- notifications ----------
-- `kind` + `payload` are rendered by the app in the reader's language;
-- no user-visible sentence is stored here.
CREATE TABLE IF NOT EXISTS notifications (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind        TEXT NOT NULL,
  circle_id   UUID REFERENCES circles(id) ON DELETE CASCADE,
  payload     JSONB NOT NULL DEFAULT '{}',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  read_at     TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS notifications_user_idx ON notifications (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS notifications_unread_idx ON notifications (user_id) WHERE read_at IS NULL;

-- ---------- reminders ----------
-- In-app reminders follow `enabled`; SMS and email only when listed here.
ALTER TABLE reminder_preferences
  ADD COLUMN IF NOT EXISTS channels   TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- One row per reminder actually sent, so a scheduler re-run never repeats it.
-- marker: days before the due date; -1 = overdue; -2 = organizer's nudge (per day).
CREATE TABLE IF NOT EXISTS reminder_deliveries (
  cycle_id  UUID NOT NULL REFERENCES cycles(id) ON DELETE CASCADE,
  user_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  marker    INT  NOT NULL,
  sent_on   DATE NOT NULL,
  sent_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (cycle_id, user_id, marker, sent_on)
);

-- ---------- member removal ----------
ALTER TABLE circle_members ADD COLUMN IF NOT EXISTS left_at TIMESTAMPTZ;

-- ---------- statements ----------
ALTER TABLE statements
  ADD COLUMN IF NOT EXISTS holder_name TEXT,
  ADD COLUMN IF NOT EXISTS head_seq    BIGINT,
  ADD COLUMN IF NOT EXISTS unit_minor  BIGINT,
  ADD COLUMN IF NOT EXISTS payload     JSONB NOT NULL DEFAULT '{}';
CREATE INDEX IF NOT EXISTS statements_owner_idx ON statements (user_id, circle_id, issued_at DESC);

-- Re-walks one circle's hash chain. Returns the seq of the first entry whose
-- link or hash does not match, or NULL when the chain is intact.
CREATE OR REPLACE FUNCTION ledger_chain_break(p_circle UUID, p_upto BIGINT DEFAULT NULL)
RETURNS BIGINT LANGUAGE plpgsql STABLE AS $$
DECLARE
  e ledger_entries%ROWTYPE;
  last_hash TEXT := repeat('0', 64);
  expected  TEXT;
BEGIN
  FOR e IN SELECT * FROM ledger_entries
           WHERE circle_id = p_circle AND (p_upto IS NULL OR seq <= p_upto)
           ORDER BY seq LOOP
    expected := encode(digest(concat_ws('|',
        e.prev_hash, e.id, e.circle_id, e.cycle_id, e.subject_user_id,
        e.actor_user_id, e.entry_type, e.amount_minor, e.method,
        e.reference, e.target_entry_id,
        to_char(e.created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
        e.payload::text,
        e.method_provider, e.receipt_reference), 'sha256'), 'hex');
    IF e.prev_hash <> last_hash OR e.hash <> expected THEN
      RETURN e.seq;
    END IF;
    last_hash := e.hash;
  END LOOP;
  RETURN NULL;
END $$;

-- ---------- community tier ----------
CREATE UNIQUE INDEX IF NOT EXISTS consents_one_active_idx
  ON consents (circle_id, user_id, scope, COALESCE(dispute_id, '00000000-0000-0000-0000-000000000000'::uuid))
  WHERE revoked_at IS NULL;

ALTER TABLE disputes
  ADD COLUMN IF NOT EXISTS category        TEXT NOT NULL DEFAULT 'other'
    CHECK (category IN ('payment_not_recorded', 'payment_rejected', 'payout_not_received', 'other')),
  ADD COLUMN IF NOT EXISTS resolved_at     TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS resolution_note TEXT CHECK (char_length(resolution_note) <= 500);
CREATE INDEX IF NOT EXISTS disputes_circle_idx ON disputes (circle_id, created_at DESC);
