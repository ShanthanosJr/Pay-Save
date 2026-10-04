-- Pals: a mutual connection that starts as a request and needs the other
-- member's acceptance (like LinkedIn connections). Following stays one-way.

CREATE TABLE IF NOT EXISTS pal_requests (
  from_user   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  to_user     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- Ignored requests are kept (not deleted) so the sender still sees
  -- "Pending" and cannot re-send until the cooldown has passed.
  ignored_at  TIMESTAMPTZ,
  PRIMARY KEY (from_user, to_user),
  CHECK (from_user <> to_user)
);
CREATE INDEX IF NOT EXISTS pal_requests_to_idx ON pal_requests (to_user) WHERE ignored_at IS NULL;

-- One row per pair: (user_low, user_high) is the ordered pair.
CREATE TABLE IF NOT EXISTS pals (
  user_low   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_high  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  since      TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_low, user_high),
  CHECK (user_low < user_high)
);
CREATE INDEX IF NOT EXISTS pals_high_idx ON pals (user_high);
