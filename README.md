# Pay&Save

**Pay Together. Save Together.**

Pay&Save is a mobile-first app for community savings circles (seettu / ROSCA) in Sri Lanka. It gives every member instant, verifiable proof that a contribution was recorded, gives organizers one shared record instead of a notebook, a spreadsheet and a chat thread, and lets community officers help resolve disputes with the circle's consent.

It is the build of the design researched and tested in IT3060 Human Computer Interaction (Group 64, Milestones 01 and 02).

> Status: the member, organizer and community-officer flows are implemented end to end. Pay&Save **records** payments that members make to each other; it never holds or moves money.

## What it does

- **Circles**: create (amount, interval, fixed / lottery / need-based turn order), invite pals or share a join code, verifiable lottery draw, remove a member with a recorded reason.
- **Payments**: record a payment (cash, bank transfer, LANKAQR, mobile wallet) with who-to-pay details; the organizer verifies or rejects with a reason; close a cycle with the unpaid members named.
- **A ledger that cannot be edited**: append-only, SHA-256 hash-chained per circle; corrections are new entries.
- **Offline**: a payment recorded without signal is kept on the phone and sent once, with the same id, when the connection returns.
- **Reminders and notifications**: an inbox for every record about you; due-date reminders that are off until you turn them on, in the app and optionally by SMS or email; the organizer can remind an unpaid member.
- **Savings statement**: a PDF/CSV of verified payments with a verification code; anyone can check it at `/verify/<code>`, and a changed ledger makes the check fail.
- **Community tier**: officers see consented, anonymised totals for circles of five or more; dispute evidence only after everyone concerned agrees, with every view logged and notified.
- **Accounts**: phone verified by SMS code, email verified by emailed code, password reset by code, English / Sinhala / Tamil.

## Technology stack

### As built (what runs and is tested)

| Layer | Choice |
|---|---|
| Client (Android, iOS, Web) | Flutter (Dart), Riverpod, go_router, drift/SQLite (offline outbox), gen-l10n (English, Sinhala, Tamil) |
| Core API | Node.js + NestJS (TypeScript), modular monolith, REST |
| Database | PostgreSQL 16, append-only hash-chained ledger (triggers + pgcrypto), SQL migrations in `backend/db/migrations` |
| Authentication | Self-hosted: phone OTP at registration, phone/email + password, JWT access + rotating refresh tokens, per-circle role guards |
| Data protection | AES-256-GCM for phone, NIC and payout details; HMAC lookups; scrypt password hashes |
| SMS / email | Pluggable gateways: Notify.lk, Text.lk or Twilio for SMS; any SMTP relay for email |
| Scheduling | In-process hourly job (`@nestjs/schedule`) for reminders |
| Statements | PDF rendered in the API (pdfkit) |

### Deployment target (planned, not in this repository yet)

Managed PostgreSQL with point-in-time recovery, HTTPS in front of the API, object storage for statement files, error tracking and uptime alerts. Push notifications (FCM) and a separate insights service for community analytics are also planned; `insights-service/` is a skeleton today.

## Design

Forest-green interface with Inter Tight headings and Inter body text; Noto Sans Sinhala and Noto Sans Tamil are bundled so both scripts render the same on every phone. Flutter theme: [`frontend/lib/core/theme/`](frontend/lib/core/theme/).

## Repository structure

```
pay-and-save/
├── frontend/           Flutter app (iOS, Android, Web)
├── backend/            NestJS core API (modular monolith) + SQL migrations
├── insights-service/   FastAPI service (statements, community aggregates)
├── infra/              Infrastructure as code (AWS CDK or Terraform, later phase)
├── scripts/
├── .github/            CI workflow, PR template, Dependabot
└── docker-compose.yml  Local Postgres + Redis
```

## Getting started (local)

Prerequisites: Docker, Node.js 22+, Flutter (stable).

```bash
docker compose up -d                 # Postgres 16 on 5432
backend/db/apply.sh                  # applies every migration in order (safe to re-run)
cd backend && cp .env.example .env && npm ci && npm run start:dev
```

The API is at `http://localhost:3000` (`/health`). With the example `.env`, codes are printed to the server log and shown in the app as a test code.

```bash
cd frontend && flutter pub get && flutter run -d chrome
```

On an Android emulator `flutter run` reaches the API at `10.0.2.2` automatically. On a physical phone: `flutter run --dart-define=API_BASE_URL=http://<laptop-LAN-IP>:3000`. Release build: `flutter build apk --release --dart-define=API_BASE_URL=https://<api-host>`.

### Sending real SMS and email

Set these in `backend/.env` (every option is described in `.env.example`), then restart the API:

```bash
SMS_PROVIDER=textlk            # or notifylk, twilio
TEXTLK_API_TOKEN=...
SMS_SENDER_ID=...              # the sender id your gateway approved
EMAIL_PROVIDER=smtp
SMTP_HOST=... SMTP_PORT=587 SMTP_USER=... SMTP_PASS=...
EMAIL_FROM="Pay&Save <no-reply@yourdomain.lk>"
DEV_OTP_ECHO=false             # stop returning the code to the app
```

With `NODE_ENV=production` the API refuses to start unless a real SMS gateway, SMTP and an `https` `PUBLIC_BASE_URL` are configured.

### Community officers

The officer role is granted by an administrator, never from the app:

```sql
UPDATE users SET is_community_officer = true WHERE email = 'officer@example.lk';
```

### Tests

```bash
cd backend && npm test && npm run test:e2e     # e2e needs the local Postgres
cd frontend && flutter analyze && flutter test
```

## Branching and commits

- `main` is protected: pull requests only, one approving review, CI must pass.
- Branches: `feature/...`, `fix/...`, `docs/...`.
- Conventional Commits, e.g. `feat(ledger): append verification entries`.

## Team

Group 64 — IT23637146 Jayasekara J. M. S. H · IT23635098 Halovita H. U. D · IT23634862 Dilsara B. G. R · IT23641624 Ravishan R. K

## Licence

[MIT](LICENSE)
