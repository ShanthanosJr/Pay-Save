# Pay&Save — Master Build Plan

*Pay Together. Save Together.*

This document turns the Milestone 01 research and the Milestone 02 prototype and test results into a buildable product plan. Every feature below traces back to a requirement (FR/NFR), a usability issue (U-xx) or a traceability gap from Milestone 02 §11. If a feature cannot be traced, it does not belong in version 1.

---

## 1. What the research says the product must be

Milestone 01 found that seettu circles rarely fail because money goes missing. They fail because **nothing in the circle holds evidence**. Fourteen of fifteen experienced respondents had lived through a breakdown, ten kept a handwritten notebook, and the most requested feature (8 of 15) was instant confirmation that a payment was recorded.

The number that should drive every engineering decision is this one: people rated confidence in their own flawed manual records at **3.33 / 5** but willingness to trust an app at only **2.73 / 5**. So Pay&Save cannot just *claim* to be trustworthy. It has to be built so that trust can be *checked*:

1. **Records are append-only.** Nothing is ever edited or deleted. A correction is a new entry that points to the one it corrects (FR-08).
2. **Every total shows its arithmetic.** "3 confirmed × LKR 5,000 = LKR 15,000", never a bare number (NFR-07).
3. **Every role is told what it can and cannot see**, and the database enforces the same boundary (NFR-02).
4. **Records are tamper-evident.** Each ledger entry carries a hash of the previous one, so any silent change breaks the chain and is detectable. An exported statement carries the chain head and a verification code a bank officer can check (FR-11).

### 1.1 Scope decision: Pay&Save records money, it does not move money

"Pay now" means *record a payment you made* by cash, bank transfer or mobile wallet, which the organizer then verifies. Pay&Save never holds or transfers funds. This keeps version 1 buildable by a student team and avoids the licensing that a payment service would need under Sri Lankan payment regulation (the Central Bank oversees payment services; confirm the specifics before ever adding real money movement). It also matches the research: the need was *verification*, not automation.

---

## 2. Requirements → features

### 2.1 Functional requirements

| ID | Requirement (short) | How Pay&Save implements it | Phase |
|---|---|---|---|
| FR-01 | Dated confirmation after each contribution | Member records payment → `contribution_recorded` ledger entry with reference (e.g. `PS-1038`), timestamp, cycle, amount, method. Organizer verifies → `contribution_verified` entry. Confirmation screen shows both states. | 3 |
| FR-02 | Full personal history any time | History screen reads the member's own ledger entries; filters by cycle and type; works offline from the local cache. | 6 |
| FR-03 | Configurable reminders | Per-member reminder preferences; EventBridge Scheduler creates one-off schedules per cycle due date; push (FCM) with SMS fallback. **Defaults start unticked** (U-06). | 5 |
| FR-04 | Create circle with amount, interval, turn rule | Three-step wizard. Rule asked **once**, same three labels everywhere: Fixed order, Lottery, Need-based (U-03). Lottery uses a verifiable draw (§5.4). | 2 |
| FR-05 | Add/remove members, recorded against the cycle | `member_added` / `member_removed` ledger entries; membership rows carry `joined_cycle` and `left_cycle`. Invitations by phone number with an invite link. | 2 |
| FR-06 | Current and upcoming turn order visible to all | Payout timeline (Completed / Current / Next / Your turn). Reachable from home in one tap (NFR-05). | 2 |
| FR-07 | Automatic payout calculation | Computed from **verified** ledger entries only, shown with its arithmetic. Close Cycle reads the same query as Cycle Details (U-02). | 5 |
| FR-08 | Timestamped, non-editable log; corrections as new entries | Database trigger blocks UPDATE/DELETE on `ledger_entries`; `correction` entries reference `corrects_entry_id`; hash chain per circle. Includes one worked correction in the UI (M02 §11.1 gap). | 3 |
| FR-09 | Overdue flags and per-cycle unpaid list | Derived view `v_cycle_member_status`; organizer dashboard shows paid / unpaid / collected with a "Send reminder" action per unpaid member. | 5 |
| FR-10 | Consented, anonymised community view | Circle-level consent record; pseudonymous circle codes (`RC-021`); aggregates only, with a minimum circle size; dispute evidence gated by consent (§5.6). | 7 |
| FR-11 | Exportable verified savings statement | Insights service renders a PDF/CSV with the arithmetic, the chain head hash and a verification code; a public verify page confirms the statement is genuine without revealing anything else. | 6 |

### 2.2 Non-functional requirements

| ID | Requirement | Implementation | Phase |
|---|---|---|---|
| NFR-01 | Encryption + plain statement of what is stored | TLS 1.2+ everywhere; RDS and S3 encryption with KMS; phone numbers additionally encrypted at column level. **"Your data" screen** reachable from login and profile stating what is stored, where, and who can see it (M02 §11.1 gap). | 1, 8 |
| NFR-02 | Role-based access | Roles are **per circle** (a person can organize one circle and be a member of another). NestJS guards + Postgres row-level security as a second line. Community officer is a global Cognito group. | 1, 7 |
| NFR-03 | Offline record + automatic sync, no lost entries | drift (SQLite) outbox on device; each entry has a client-generated UUID (`client_entry_id`) with a unique constraint server-side, so a retried sync can never create a double payment. | 4 |
| NFR-04 | Recoverable ledger backup | RDS automated backups with point-in-time recovery + daily snapshot copied to a second region; nightly ledger export to S3 with Object Lock. Record-safety block on the confirmation screen says so. | 3, 8 |
| NFR-05 | Payment status + turn order within two taps | Home hero card shows status; "Turn order" chip is one tap away. Checked by an automated widget test. | 3 |
| NFR-06 | Low digital confidence; Sinhala, Tamil, English | gen-l10n with complete `si`, `ta`, `en` ARB files (**every** screen, not just the welcome screen — U-04); Noto Sans Sinhala / Noto Sans Tamil fallbacks; 48 dp minimum targets; labelled bottom navigation; no jargon. | 0, 8 |
| NFR-07 | Every calculation inspectable | API returns totals **with** their components (`{count, unit_minor, total_minor, entry_ids}`); UI has a shared `ArithmeticRow` widget; tapping it lists the entries. | 3, 5 |

### 2.3 Usability issues from Milestone 02 testing (fix in the build, not later)

| Issue | Fix built into the app |
|---|---|
| U-01 (High) Dashboard still showed DUE / Pay now after paying | Hero card is driven by a state machine (§5.2): `due → pending_sync → recorded → verified`. Pay now is disabled once any entry exists for the cycle. Sync notice sits inside the hero card, not at the foot of the screen. |
| U-02 (High) Close Cycle showed 5/5 and LKR 25,000 while Cycle Details showed 3/5 | One server query feeds both screens. Closing with unpaid members requires naming them and ticking "Close with 2 unpaid". |
| U-03 (Medium) Turn rule asked twice under different names; lottery showed no draw | Rule chosen once in step 1. Choosing Lottery shows a **Draw order** button and the drawn result; manual arrows are hidden. |
| U-04 (Medium) Sinhala/Tamil option changed nothing | Full translation from Phase 0 onwards; a CI check fails if any ARB key is missing in `si` or `ta`. |
| U-05 (Medium) "You cannot see individual histories" contradicted the dispute evidence screen | Copy states the consent exception; the three permission steps are labelled: dispute raised → circle consents → relevant evidence only. |
| U-06 (Low) Reminder boxes were pre-ticked | All reminders start off; "3 days before" is suggested but not selected. |

### 2.4 Gaps from Milestone 02 §11.1

Payment method selection and optional receipt reference on the record screen (cash / bank transfer / mobile wallet, carried through to the verified record); a worked correction example; the NFR-01 data panel; a responsive organizer layout at desktop width (Flutter web) for reconciling large circles.

---

## 3. Stack carried over from FitFlow, and what changes

The FitFlow lab stack is a good fit, but it was designed for AI workouts and health data. Here is each layer, honestly assessed for a savings-record product.

| Layer | FitFlow | Pay&Save | Why |
|---|---|---|---|
| Client | Flutter + native modules for HealthKit / Health Connect / widgets | **Flutter**, native module only for a home-screen "next due date" widget (later) | One codebase for Android (most of the audience), iOS and the organizer's web view. No health APIs needed. |
| State / routing | — | Riverpod, go_router | Testable, predictable state for the payment state machine. |
| Offline | — | **drift** (SQLite) with an outbox | NFR-03 is a hard requirement; drift gives typed queries and migrations. |
| Core API | NestJS modular monolith, REST + Socket.IO | **Same** | Modules map cleanly to domains; Socket.IO pushes "payment verified" to the member live. |
| AI microservice | Python + FastAPI for workout plans | **Renamed `insights-service`**, still FastAPI | There is no genuine AI need in version 1. The Python service earns its place by rendering signed statements (WeasyPrint) and computing consented community aggregates with pandas. Late-payment risk scoring can come later. If time is short, drop this service and render PDFs in NestJS; nothing else depends on it. |
| Database | PostgreSQL + pgvector | **PostgreSQL 16**, pgvector dropped, **pgcrypto** added | No embeddings needed. pgcrypto computes the ledger hash chain inside the database. |
| Cache / queues | Redis + SQS/SNS | Redis + SQS/SNS + **EventBridge Scheduler** | Scheduler creates exact-time one-off reminder jobs per due date without a cron loop. |
| Auth | Cognito user pools, MFA, JWT + RBAC | Cognito **phone number sign-in with SMS OTP** + per-circle RBAC | Matches the prototype's phone login. Check current Cognito pricing and SMS delivery to Sri Lankan numbers before launch; a local SMS gateway can be plugged in through a Cognito custom SMS sender if needed. |
| Storage / CDN | S3 + CloudFront | Same | Statements (private, signed URLs) and circle cover photos. |
| Hosting / CI | ECS Fargate, GitHub Actions, CloudWatch, OTel, Sentry | Same | Develop entirely on `docker compose` locally; deploy only when a demo needs a public URL, using the smallest instance sizes to control cost. |

ADRs: [`adr/0001-reuse-fitflow-stack.md`](adr/0001-reuse-fitflow-stack.md), [`adr/0002-append-only-ledger.md`](adr/0002-append-only-ledger.md), [`adr/0003-record-not-move-money.md`](adr/0003-record-not-move-money.md).

---

## 4. Architecture

```
 Flutter app (Android / iOS / Web)
   │  drift local DB + outbox  ── offline records
   │
   ├── HTTPS (JWT from Cognito) ──►  API (NestJS on ECS Fargate)
   └── WebSocket (Socket.IO)   ◄──   │
                                     ├── modules: auth · users · circles · memberships
                                     │            cycles · ledger · payouts · turn-order
                                     │            reminders · notifications · consent
                                     │            disputes · statements · audit
                                     ├──► PostgreSQL (RDS)  append-only ledger, RLS
                                     ├──► Redis             sessions, rate limits, socket adapter
                                     ├──► SQS               jobs → insights-service
                                     ├──► EventBridge Scheduler → reminder Lambda/worker → SNS / FCM
                                     └──► S3 (+CloudFront)  statements, images

 insights-service (FastAPI on Fargate)
   ├── consumes SQS: render statement PDF/CSV → S3
   └── computes consented community aggregates (read replica, views only)

 Cognito  phone OTP → JWT  (global group: community_officer)
 Observability: OpenTelemetry → CloudWatch, Sentry on client and API
```

### 4.1 NestJS module boundaries

Each module owns its tables and exposes a service; other modules call the service, never the tables. The **ledger module is the only writer to `ledger_entries`**. Everything that changes money state (recording, verifying, correcting, member changes, payouts) goes through `LedgerService.append()`.

---

## 5. Core domain design

### 5.1 Data model

Full SQL: [`backend/db/migrations/0001_init.sql`](../backend/db/migrations/0001_init.sql). Key tables:

- `users` — Cognito subject, display name, preferred language, encrypted phone.
- `circles` — name, contribution amount (minor units), interval, turn rule, public code (`RC-021`), status.
- `circle_members` — user, role (`organizer` | `member`), payout position, joined/left cycle.
- `cycles` — number, due date, payout recipient, status (`open` | `closed`).
- `ledger_entries` — **append-only**. Type, amount, method, reference, `client_entry_id` (idempotency), `corrects_entry_id`, `prev_hash`, `hash`.
- `consents`, `disputes`, `dispute_access_log` — tertiary tier.
- `reminder_preferences`, `statements`, `lottery_draws`.

Money is always stored as `BIGINT` minor units (cents). LKR 5,000 is `500000`. Never floating point.

### 5.2 Contribution state machine (fixes U-01)

```
             record (online)                 organizer verifies
   due ──────────────────────► recorded ─────────────────────────► verified
    │                              │
    │ record (offline)             │ organizer rejects (correction entry)
    ▼                              ▼
 pending_sync ── sync ok ──► recorded       rejected ──► due (member can record again)
```

The dashboard hero card, Pay now button, notifications and the history screen all read the same derived status. `pending_sync` exists only on the device and is shown as "Saved on this phone · not yet confirmed · do not pay again".

### 5.3 Ledger integrity

A `BEFORE INSERT` trigger takes a per-circle advisory lock, reads the previous entry's hash, and sets `hash = sha256(prev_hash || canonical fields)`. A second trigger rejects any `UPDATE` or `DELETE`. The app's database role has no `UPDATE`/`DELETE` grant on the table either. A nightly job re-walks each chain and alerts on a mismatch.

### 5.4 Verifiable lottery (U-03)

Commit–reveal: when the organizer taps **Draw order**, the server generates a random seed, stores and shows `sha256(seed)` to all members first, then reveals the seed and the order derived from it deterministically. Any member can re-run the derivation. The draw is recorded as a ledger entry.

### 5.5 Offline sync (NFR-03)

Every locally recorded contribution gets a UUID at creation. The outbox retries with exponential backoff when connectivity returns. The server's unique constraint on `(circle_id, client_entry_id)` makes retries idempotent: a duplicate returns the original entry instead of creating a second one. The server timestamp is authoritative; the device timestamp is kept as `device_created_at` for audit.

### 5.6 Community tier and consent (FR-10, NFR-02, U-05)

- A circle opts in to community support by an organizer action **plus** member acknowledgement.
- Officers see only pseudonymous circle codes and aggregate rates, and only for circles with at least 5 members.
- A dispute unlocks evidence only when: dispute raised → affected members and organizer consent → officer sees *only the entries named in the dispute*. Every view is logged in `dispute_access_log` and the affected member is notified (tertiary interview Q12).

### 5.7 Verified statement (FR-11)

Statement = member's verified entries + arithmetic + chain head hash + issue timestamp + short verification code. The verify page (`/verify/{code}`) confirms authenticity and shows only the totals printed on the statement.

---

## 6. Screens (from the Milestone 02 prototype, in the new visual style)

The information architecture was validated in low- and high-fidelity testing, so keep the flows and change only the visual skin. See [`design-system.md`](design-system.md) for how each screen maps onto the reference design.

| Group | Screens |
|---|---|
| Shared | Welcome (language first), Phone login, OTP, Circle & role switcher, Your data (NFR-01) |
| Member | Home, My circle, Record payment, Payment recorded, Saved offline, History, Verified record, Turn order, My savings, Reminders, Notifications, Export statement |
| Organizer | Organizer home, Create circle (3 steps), Invite members, Turn order setup + draw, Cycle details, Verify payments, Close cycle |
| Community | Community home, Circle list, Group health, Dispute requests, Consent check, Dispute evidence, Privacy & access |

"Select your role" from the prototype becomes a **circle and role switcher** in the header, because roles are per circle in the real system.

---

## 7. Build phases

Each phase ends with a demo on a real phone and a merged PR. Rough effort assumes four people part-time; adjust to your real deadline.

| Phase | Goal | Delivers | Done when |
|---|---|---|---|
| 0 · Foundations (wk 1) | Everyone can run everything | Flutter shell with theme, fonts, l10n (en/si/ta), go_router; NestJS skeleton; FastAPI skeleton; docker compose; CI green | App opens on a phone in all three languages; CI passes |
| 1 · Identity (wk 2) | Sign in by phone | Cognito phone OTP, `users`, JWT guard, circle-role guard, Your data screen | A test user logs in on device; unauthenticated calls return 401 |
| 2 · Circles (wk 3) | Organizer can set up a circle | Create circle wizard, invites, membership, turn order, lottery draw | T8 from M02 passes end-to-end |
| 3 · Ledger (wk 4) | Record and verify a payment | Append-only ledger, record → verify flow, confirmation screen, verified record, correction example, live update over Socket.IO | T3 and T4 pass; UPDATE on ledger fails in a test |
| 4 · Offline (wk 5) | Record with no signal | drift outbox, sync, pending state, dashboard state machine | Airplane-mode test: record, reconnect, exactly one entry on server |
| 5 · Cycles (wk 6) | Close cycles and remind | Cycle details, unpaid list, close cycle with acknowledgement, reminders, notifications | T6 and T9 pass; Close Cycle totals equal Cycle Details totals |
| 6 · History & export (wk 7) | Proof for a bank | History, savings summary, statement PDF/CSV, verify page | T7 passes; tampering with a row breaks verification |
| 7 · Community (wk 8) | Consented oversight | Consent, aggregates, disputes, evidence gate, access log | T10 passes; officer API cannot return a member name |
| 8 · Hardening (wk 9–10) | Ready to show | Accessibility pass, translation review by native speakers, organizer desktop layout, backups, deploy to AWS, re-run usability test | M02 tasks T1–T10 re-run with 5+ participants |

---

## 8. Testing

- **Unit:** ledger arithmetic, state machine transitions, lottery derivation (deterministic from seed), hash chain.
- **Database:** tests that UPDATE/DELETE on `ledger_entries` fail; RLS tests per role.
- **API integration:** NestJS + Testcontainers Postgres.
- **Flutter:** widget tests for each screen state; a golden test for the hero card in all four states; a test that status and turn order are reachable within two taps (NFR-05).
- **Usability tasks as E2E tests:** Milestone 02 tasks T1–T10 become `integration_test` scripts, so every regression against the tested design is caught automatically.
- **Accessibility:** contrast checked against WCAG 2.1 AA, text scaling to 200%, TalkBack/VoiceOver labels on every control.

---

## 9. Security checklist

TLS only; JWT verified against Cognito JWKS; per-circle authorization on every route; RLS as defence in depth; rate limiting on OTP and record endpoints; no secrets in the repo (GitHub secrets + AWS Secrets Manager); phone numbers encrypted at column level; S3 statements private with short-lived signed URLs; audit log for every community view; Dependabot and CodeQL enabled.

---

## 10. Working with an AI IDE (Antigravity)

Use [`antigravity-prompts.md`](antigravity-prompts.md) one phase at a time, in order. [`../AGENTS.md`](../AGENTS.md) holds the non-negotiable rules (append-only ledger, minor-unit money, translations for every string, design tokens only). Review every generated diff against those rules before merging; an agent will happily write an `UPDATE ledger_entries` if you let it.
