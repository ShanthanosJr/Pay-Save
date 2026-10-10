-- Password reset by one-time code (sent to the account's phone or email).

ALTER TABLE otp_challenges DROP CONSTRAINT IF EXISTS otp_challenges_purpose_check;
ALTER TABLE otp_challenges ADD CONSTRAINT otp_challenges_purpose_check
  CHECK (purpose IN ('phone_register', 'email_verify', 'password_reset'));

ALTER TABLE users ADD COLUMN IF NOT EXISTS password_changed_at TIMESTAMPTZ;
