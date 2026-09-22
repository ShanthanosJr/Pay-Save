-- Pay&Save — initial schema (PostgreSQL 16)
-- Money is always BIGINT minor units (LKR 5,000.00 = 500000).
-- ledger_entries is append-only and hash-chained per circle (FR-08, ADR-0002).

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------- enums ----------
CREATE TYPE language_code     AS ENUM ('en', 'si', 'ta');
CREATE TYPE circle_interval   AS ENUM ('weekly', 'fortnightly', 'monthly');
CREATE TYPE turn_rule         AS ENUM ('fixed', 'lottery', 'need_based');       -- one set of labels everywhere (U-03)
CREATE TYPE circle_status     AS ENUM ('draft', 'active', 'completed');
CREATE TYPE member_role       AS ENUM ('organizer', 'member');
CREATE TYPE cycle_status      AS ENUM ('open', 'closed');
CREATE TYPE payment_method    AS ENUM ('cash', 'bank_transfer', 'mobile_wallet');
CREATE TYPE ledger_entry_type AS ENUM (
  'contribution_recorded',   -- member (or organizer) records a payment
  'contribution_verified',   -- organizer confirms it
  'correction',              -- reverses/annotates an earlier entry; never edits it
  'payout',                  -- cycle closed, pot paid to recipient
  'member_added',
  'member_removed',
  'turn_order_set',          -- includes lottery draws
  'cycle_closed'
);

-- ---------- people ----------
CREATE TABLE users (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cognito_sub      TEXT UNIQUE NOT NULL,
  display_name     TEXT NOT NULL,
  phone_encrypted  BYTEA NOT NULL,          -- encrypted by the API with a KMS data key (NFR-01)
  phone_hash       TEXT UNIQUE NOT NULL,    -- HMAC for lookup/invites without decrypting
  language         language_code NOT NULL DEFAULT 'en',
  is_community_officer BOOLEAN NOT NULL DEFAULT false,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------- circles ----------
CREATE TABLE circles (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  public_code          TEXT UNIQUE NOT NULL,        -- pseudonymous, e.g. RC-021 (FR-10)
  name                 TEXT NOT NULL,
  contribution_minor   BIGINT NOT NULL CHECK (contribution_minor > 0),
  interval             circle_interval NOT NULL,
  turn_rule            turn_rule NOT NULL,
  planned_cycles       INT NOT NULL CHECK (planned_cycles BETWEEN 2 AND 60),
  status               circle_status NOT NULL DEFAULT 'draft',
  community_consent    BOOLEAN NOT NULL DEFAULT false,
  cover_image_key      TEXT,
  created_by           UUID NOT NULL REFERENCES users(id),
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE circle_members (
  circle_id        UUID NOT NULL REFERENCES circles(id),
  user_id          UUID NOT NULL REFERENCES users(id),
  role             member_role NOT NULL,
  payout_position  INT,                     -- null until turn order is set
  joined_cycle     INT NOT NULL DEFAULT 1,
  left_cycle       INT,                     -- FR-05: change recorded against a cycle
  PRIMARY KEY (circle_id, user_id),
  UNIQUE (circle_id, payout_position)
);

CREATE TABLE cycles (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  circle_id            UUID NOT NULL REFERENCES circles(id),
  number               INT NOT NULL CHECK (number > 0),
  due_date             DATE NOT NULL,
  payout_user_id       UUID REFERENCES users(id),
  status               cycle_status NOT NULL DEFAULT 'open',
  closed_at            TIMESTAMPTZ,
  UNIQUE (circle_id, number)
);

-- ---------- the ledger ----------
CREATE TABLE ledger_entries (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seq                BIGINT GENERATED ALWAYS AS IDENTITY,
  circle_id          UUID NOT NULL REFERENCES circles(id),
  cycle_id           UUID REFERENCES cycles(id),
  subject_user_id    UUID REFERENCES users(id),     -- whose money / membership
  actor_user_id      UUID NOT NULL REFERENCES users(id),
  entry_type         ledger_entry_type NOT NULL,
  amount_minor       BIGINT,                        -- null for non-money entries
  method             payment_method,
  receipt_reference  TEXT,                          -- member's bank/wallet reference, optional
  reference          TEXT NOT NULL,                 -- human reference, e.g. PS-1038
  target_entry_id    UUID REFERENCES ledger_entries(id), -- entry being verified or corrected
  note               TEXT,
  payload            JSONB NOT NULL DEFAULT '{}',   -- e.g. lottery seed, draw order
  client_entry_id    UUID NOT NULL,                 -- idempotency key from the device (NFR-03)
  device_created_at  TIMESTAMPTZ,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  prev_hash          TEXT NOT NULL,
  hash               TEXT NOT NULL,
  UNIQUE (circle_id, client_entry_id),
  CHECK (entry_type NOT IN ('correction','contribution_verified') OR target_entry_id IS NOT NULL),
  CHECK (amount_minor IS NULL OR amount_minor <> 0)
);
CREATE INDEX ON ledger_entries (circle_id, seq);
CREATE INDEX ON ledger_entries (cycle_id, subject_user_id);

-- Hash chain: each entry commits to the previous entry of the same circle.
CREATE FUNCTION ledger_chain() RETURNS trigger LANGUAGE plpgsql AS $$
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
      NEW.payload::text), 'sha256'), 'hex');
  RETURN NEW;
END $$;

CREATE TRIGGER ledger_chain_bi BEFORE INSERT ON ledger_entries
  FOR EACH ROW EXECUTE FUNCTION ledger_chain();

-- Append-only: no edits, no deletes, ever.
CREATE FUNCTION ledger_forbid_change() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'ledger_entries is append-only; record a correction entry instead';
END $$;

CREATE TRIGGER ledger_no_update BEFORE UPDATE ON ledger_entries
  FOR EACH ROW EXECUTE FUNCTION ledger_forbid_change();
CREATE TRIGGER ledger_no_delete BEFORE DELETE ON ledger_entries
  FOR EACH ROW EXECUTE FUNCTION ledger_forbid_change();
CREATE TRIGGER ledger_no_truncate BEFORE TRUNCATE ON ledger_entries
  FOR EACH STATEMENT EXECUTE FUNCTION ledger_forbid_change();

-- ---------- derived status (single source for dashboard, cycle details, close cycle: U-01, U-02) ----------
CREATE VIEW v_cycle_member_status AS
WITH contrib AS (
  SELECT e.cycle_id, e.subject_user_id, e.id, e.amount_minor, e.reference, e.created_at
  FROM ledger_entries e
  WHERE e.entry_type = 'contribution_recorded'
    AND NOT EXISTS (SELECT 1 FROM ledger_entries c
                    WHERE c.entry_type = 'correction' AND c.target_entry_id = e.id)
),
verified AS (
  SELECT v.target_entry_id AS contribution_id, max(v.created_at) AS verified_at
  FROM ledger_entries v WHERE v.entry_type = 'contribution_verified'
  GROUP BY v.target_entry_id
)
SELECT cy.circle_id, cy.id AS cycle_id, cy.number AS cycle_number, cm.user_id,
       c.id AS contribution_id, c.reference, c.amount_minor,
       c.created_at AS recorded_at, v.verified_at,
       CASE
         WHEN v.verified_at IS NOT NULL THEN 'verified'
         WHEN c.id IS NOT NULL          THEN 'recorded'
         WHEN cy.due_date < current_date THEN 'overdue'
         ELSE 'due'
       END AS status
FROM cycles cy
JOIN circle_members cm ON cm.circle_id = cy.circle_id
     AND cm.role IN ('member', 'organizer')
     AND cm.joined_cycle <= cy.number
     AND (cm.left_cycle IS NULL OR cm.left_cycle > cy.number)
LEFT JOIN contrib  c ON c.cycle_id = cy.id AND c.subject_user_id = cm.user_id
LEFT JOIN verified v ON v.contribution_id = c.id;

-- Totals with their arithmetic (NFR-07, FR-07)
CREATE VIEW v_cycle_totals AS
SELECT s.circle_id, s.cycle_id, s.cycle_number,
       count(*)                                          AS members_due,
       count(*) FILTER (WHERE s.status = 'verified')     AS verified_count,
       count(*) FILTER (WHERE s.status = 'recorded')     AS awaiting_verification,
       count(*) FILTER (WHERE s.status IN ('due','overdue')) AS unpaid_count,
       ci.contribution_minor                             AS unit_minor,
       COALESCE(sum(s.amount_minor) FILTER (WHERE s.status = 'verified'), 0) AS verified_total_minor
FROM v_cycle_member_status s
JOIN circles ci ON ci.id = s.circle_id
GROUP BY s.circle_id, s.cycle_id, s.cycle_number, ci.contribution_minor;

-- ---------- reminders (FR-03; defaults OFF, U-06) ----------
CREATE TABLE reminder_preferences (
  circle_id    UUID NOT NULL REFERENCES circles(id),
  user_id      UUID NOT NULL REFERENCES users(id),
  days_before  INT[] NOT NULL DEFAULT '{}',
  enabled      BOOLEAN NOT NULL DEFAULT false,
  PRIMARY KEY (circle_id, user_id)
);

-- ---------- lottery (commit–reveal) ----------
CREATE TABLE lottery_draws (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  circle_id     UUID NOT NULL REFERENCES circles(id),
  commitment    TEXT NOT NULL,         -- sha256(seed), shown to members before reveal
  seed          TEXT,                  -- revealed afterwards
  committed_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  revealed_at   TIMESTAMPTZ
);

-- ---------- community tier (FR-10, NFR-02) ----------
CREATE TABLE consents (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  circle_id    UUID NOT NULL REFERENCES circles(id),
  user_id      UUID NOT NULL REFERENCES users(id),
  scope        TEXT NOT NULL CHECK (scope IN ('community_aggregates', 'dispute_evidence')),
  dispute_id   UUID,
  granted_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  revoked_at   TIMESTAMPTZ
);

CREATE TABLE disputes (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  circle_id       UUID NOT NULL REFERENCES circles(id),
  raised_by       UUID NOT NULL REFERENCES users(id),
  officer_id      UUID REFERENCES users(id),
  entry_ids       UUID[] NOT NULL,     -- the ONLY entries the officer may see
  status          TEXT NOT NULL DEFAULT 'awaiting_consent'
                  CHECK (status IN ('awaiting_consent', 'consented', 'resolved', 'declined')),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE dispute_access_log (    -- every officer view is logged and the member notified
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  dispute_id  UUID NOT NULL REFERENCES disputes(id),
  officer_id  UUID NOT NULL REFERENCES users(id),
  viewed_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Aggregates only, consented circles only, minimum size 5, no names.
CREATE VIEW v_community_circle_health AS
SELECT ci.public_code,
       count(DISTINCT cm.user_id) AS members,
       round(100.0 * sum(t.verified_count) / NULLIF(sum(t.members_due), 0)) AS on_time_rate_pct,
       count(DISTINCT t.cycle_id) AS cycles_run
FROM circles ci
JOIN circle_members cm ON cm.circle_id = ci.id AND cm.left_cycle IS NULL
LEFT JOIN v_cycle_totals t ON t.circle_id = ci.id
WHERE ci.community_consent
GROUP BY ci.id, ci.public_code
HAVING count(DISTINCT cm.user_id) >= 5;

-- ---------- statements (FR-11) ----------
CREATE TABLE statements (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id            UUID NOT NULL REFERENCES users(id),
  circle_id          UUID NOT NULL REFERENCES circles(id),
  verification_code  TEXT UNIQUE NOT NULL,
  chain_head_hash    TEXT NOT NULL,
  verified_count     INT NOT NULL,
  total_minor        BIGINT NOT NULL,
  s3_key             TEXT,
  issued_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
