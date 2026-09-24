-- Self-hosted auth: phone-OTP registration, email/phone login (Cognito can replace later).

ALTER TABLE users ALTER COLUMN cognito_sub DROP NOT NULL;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS full_name          TEXT,
  ADD COLUMN IF NOT EXISTS age                INT CHECK (age BETWEEN 18 AND 120),
  ADD COLUMN IF NOT EXISTS nic_encrypted      BYTEA,
  ADD COLUMN IF NOT EXISTS nic_hash           TEXT UNIQUE,
  ADD COLUMN IF NOT EXISTS email              TEXT UNIQUE CHECK (email = lower(email)),
  ADD COLUMN IF NOT EXISTS email_verified_at  TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS phone_verified_at  TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS password_hash      TEXT,
  ADD COLUMN IF NOT EXISTS refresh_token_hash TEXT,
  ADD COLUMN IF NOT EXISTS failed_login_count INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS locked_until       TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_at         TIMESTAMPTZ NOT NULL DEFAULT now();

CREATE TABLE IF NOT EXISTS otp_challenges (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  purpose     TEXT NOT NULL CHECK (purpose IN ('phone_register', 'email_verify')),
  target_hash TEXT NOT NULL,
  user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
  code_hash   TEXT NOT NULL,
  expires_at  TIMESTAMPTZ NOT NULL,
  attempts    INT NOT NULL DEFAULT 0,
  consumed_at TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS otp_challenges_lookup_idx
  ON otp_challenges (purpose, target_hash, created_at DESC);
