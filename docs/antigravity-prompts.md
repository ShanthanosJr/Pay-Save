# Build prompts for Antigravity (or any AI IDE)

Paste one prompt at a time, in order. Before each, make sure the agent has `AGENTS.md` loaded as a workspace rule. After each prompt: run the app on a real phone, read the diff against `AGENTS.md`, run tests, then commit on a feature branch and open a PR.

---

## Phase 0 — Foundations

> Read AGENTS.md, docs/MASTER_PLAN.md and docs/design-system.md.
> 1. In `frontend/`, create a Flutter project around the existing `lib/core/` files (org `lk.payandsave`, platforms android, ios, web). Add riverpod, go_router, drift, dio, google_fonts, intl, uuid, flutter_localizations. Bundle Noto Sans Sinhala and Noto Sans Tamil as asset fonts with those family names.
> 2. Set up gen-l10n with `app_en.arb`, `app_si.arb`, `app_ta.arb`. Add a test that fails if any key is missing from si or ta.
> 3. Build the Welcome screen exactly as design-system §4.1: full-bleed photo from `assets/images/welcome.jpg` with the photo overlay gradient, PAY&SAVE wordmark, "Pay Together. Save Together.", the three language chips (switching locale live), pager dots and `PsGradientButton` "Get started".
> 4. Build a placeholder Member Home using the §4.2 layout with hard-coded sample data (Friends Seettu, cycle 3 of 5, LKR 5,000, due 20 Sep) and a labelled `NavigationBar`.
> 5. In `backend/`, scaffold a NestJS app with a `/health` endpoint, ESLint, Jest. In `insights-service/`, scaffold FastAPI with `/health` and pytest.
> Stop when all three apps start and CI passes.

## Phase 1 — Identity

> Implement phone-number sign-in with Amazon Cognito (SMS OTP). Flutter: Phone login and OTP screens from the Milestone 02 prototype in the new skin. NestJS: JWT verification against Cognito JWKS, a `users` module (create on first login, phone stored encrypted + HMAC hash as in the migration), a `CircleRoleGuard` that reads `circle_members`. For local development add a `DEV_AUTH=true` mode that accepts OTP `000000`, which must refuse to start when `NODE_ENV=production`. Add the "Your data" screen (NFR-01) reachable from login and profile. Tests: unauthenticated → 401, wrong circle → 403.

## Phase 2 — Circles

> Build the organizer flow: Create circle (3 steps: details incl. turn rule chosen once; invite members by phone; turn order). Lottery uses commit–reveal (MASTER_PLAN §5.4) with a Draw order button that shows the commitment, then the result; arrows hidden for lottery. All membership and turn-order changes go through `LedgerService.append()`. Add the Turn Order timeline screen for members. Integration test = Milestone 02 task T8.

## Phase 3 — Ledger and contributions

> Implement `LedgerService.append()` on top of `backend/db/migrations/0001_init.sql`. Endpoints: record contribution (method cash / bank transfer / mobile wallet, optional receipt reference, `client_entry_id`), verify (organizer), correct (organizer, with note). Emit Socket.IO `contribution.verified` to the member. Flutter: Record payment, Payment recorded (with record-safety block), Verified record (with record history, and a correction shown beneath the original). Tests: UPDATE on ledger fails; duplicate `client_entry_id` returns the original entry; hash chain verifies.

## Phase 4 — Offline

> Add a drift database with an outbox table. Recording while offline stores the entry with its `client_entry_id` and shows the Saved offline screen ("Saved on this phone · not yet confirmed · do not pay again"). A sync service retries with backoff when connectivity returns. The home hero card follows the state machine in MASTER_PLAN §5.2 and design-system §4.2, and Pay now is disabled once any entry exists for the cycle (U-01). Test: record in airplane mode, reconnect, exactly one server entry.

## Phase 5 — Cycles, reminders, notifications

> Organizer home and Cycle details (paid / unpaid / collected from `v_cycle_totals`, Send reminder per unpaid member). Close cycle reads the same data, lists unpaid members by name and requires ticking "Close with N unpaid" (U-02); closing appends `payout` and `cycle_closed` entries. Reminders: preferences default OFF with 3 days suggested but unticked (U-06); EventBridge Scheduler one-off schedules per due date; push via FCM. Notifications screen. Test: Close Cycle totals always equal Cycle Details totals.

## Phase 6 — History and statement

> Payment history with cycle/type filters, My savings with arithmetic rows, Export statement. Statement rendering happens in insights-service (WeasyPrint PDF + CSV) triggered via SQS, stored in S3, delivered by signed URL. Include chain head hash and a verification code; add a public `/verify/{code}` page that shows only the totals printed on the statement. Test: altering any ledger row in a test database makes verification fail.

## Phase 7 — Community tier

> Community officer role (Cognito group). Screens: Community home, Circle list, Group health (from `v_community_circle_health` only), Dispute requests, Consent check, Dispute evidence, Privacy & access. Evidence endpoint returns only the dispute's `entry_ids` after consent, writes `dispute_access_log` and notifies the affected member. Copy states the consent exception and labels the three steps (U-05). Test: no officer endpoint ever returns a member name or phone number.

## Phase 8 — Hardening

> Accessibility audit (contrast, 200% text, screen readers), native-speaker review of si/ta strings, responsive organizer layout for web ≥ 1024 px, backups (RDS PITR, cross-region snapshot, S3 Object Lock ledger export), deploy to ECS Fargate via GitHub Actions, and turn Milestone 02 tasks T1–T10 into Flutter `integration_test` scripts.
