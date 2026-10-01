-- M1: circle lifecycle (join codes, start, lottery commit–reveal), LankaQR, human references.

ALTER TABLE circles
  ADD COLUMN IF NOT EXISTS join_code            TEXT,
  ADD COLUMN IF NOT EXISTS first_due_date       DATE,
  ADD COLUMN IF NOT EXISTS started_at           TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS lottery_commitment   TEXT,   -- sha256(seed) hex, shown before the draw
  ADD COLUMN IF NOT EXISTS lottery_seed         TEXT,   -- secret until lottery_revealed_at is set
  ADD COLUMN IF NOT EXISTS lottery_committed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS lottery_revealed_at  TIMESTAMPTZ;
CREATE UNIQUE INDEX IF NOT EXISTS circles_join_code_key ON circles (join_code);

ALTER TABLE circle_members
  ADD COLUMN IF NOT EXISTS joined_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp();
CREATE INDEX IF NOT EXISTS circle_members_user_id_idx ON circle_members (user_id);

ALTER TYPE payment_method ADD VALUE IF NOT EXISTS 'lankaqr' BEFORE 'mobile_wallet';

ALTER TABLE ledger_entries ADD COLUMN IF NOT EXISTS method_provider TEXT;
CREATE INDEX IF NOT EXISTS ledger_entries_target_entry_id_idx ON ledger_entries (target_entry_id);
CREATE UNIQUE INDEX IF NOT EXISTS ledger_entries_reference_key ON ledger_entries (reference);
-- defence in depth behind the per-circle row lock
CREATE UNIQUE INDEX IF NOT EXISTS ledger_entries_one_verification_idx
  ON ledger_entries (target_entry_id) WHERE entry_type = 'contribution_verified';
CREATE UNIQUE INDEX IF NOT EXISTS ledger_entries_one_close_idx
  ON ledger_entries (cycle_id) WHERE entry_type = 'cycle_closed';
CREATE UNIQUE INDEX IF NOT EXISTS ledger_entries_one_payout_idx
  ON ledger_entries (cycle_id) WHERE entry_type = 'payout';

CREATE SEQUENCE IF NOT EXISTS ledger_reference_seq START 1001;   -- PS-1001, PS-1002, ...
CREATE SEQUENCE IF NOT EXISTS circle_public_code_seq START 101;  -- RC-101, RC-102, ...

-- Hash v2: fields of v1 in the same order, then method_provider, receipt_reference appended (concat_ws skips NULLs, so v1 rows still verify).
CREATE OR REPLACE FUNCTION ledger_chain() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  last_hash TEXT;
BEGIN
  -- serialise writers per circle so the chain cannot fork
  PERFORM pg_advisory_xact_lock(hashtextextended(NEW.circle_id::text, 0));

  SELECT hash INTO last_hash
    FROM ledger_entries WHERE circle_id = NEW.circle_id
    ORDER BY seq DESC LIMIT 1;

  NEW.created_at := clock_timestamp();
  NEW.prev_hash  := COALESCE(last_hash, repeat('0', 64));
  NEW.hash := encode(digest(concat_ws('|',
      NEW.prev_hash, NEW.id, NEW.circle_id, NEW.cycle_id, NEW.subject_user_id,
      NEW.actor_user_id, NEW.entry_type, NEW.amount_minor, NEW.method,
      NEW.reference, NEW.target_entry_id,
      to_char(NEW.created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
      NEW.payload::text,
      NEW.method_provider, NEW.receipt_reference), 'sha256'), 'hex');
  RETURN NEW;
END $$;
