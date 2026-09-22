# Pay&Save

**Pay Together. Save Together.**

Pay&Save is a mobile-first app for community savings circles (seettu / ROSCA) in Sri Lanka. It gives every member instant, verifiable proof that a contribution was recorded, gives organizers one shared record instead of a notebook, a spreadsheet and a chat thread, and lets community officers help resolve disputes with the circle's consent.

It is the build of the design researched and tested in IT3060 Human Computer Interaction (Group 64, Milestones 01 and 02).

> Status: Phase 0 foundations — Flutter app shell, NestJS API skeleton and FastAPI insights skeleton are running, with CI green.

## Technology stack

| Layer | Choice |
|---|---|
| Client (iOS, Android, Web) | Flutter (Dart), Riverpod, go_router, drift (offline store), gen-l10n (English, Sinhala, Tamil) |
| Core API | Node.js + NestJS (TypeScript), modular monolith, REST + WebSocket (Socket.IO) |
| Insights & documents service | Python + FastAPI (statement PDFs, consented community aggregates) |
| Primary database | PostgreSQL (Amazon RDS) with an append-only, hash-chained ledger |
| Cache / real-time / queues | Redis (ElastiCache) + Amazon SQS/SNS, EventBridge Scheduler for reminders |
| Authentication & authorization | Amazon Cognito (phone number + OTP, JWT) + per-circle RBAC in NestJS |
| Object storage / CDN | Amazon S3 + CloudFront (statements, circle cover images) |
| Hosting & delivery | AWS ECS Fargate, GitHub Actions CI/CD, CloudWatch + OpenTelemetry + Sentry |

## Design

Dark, photo-led interface with a deep forest-green accent, Montserrat headings and Poppins body text. Flutter theme: [`frontend/lib/core/theme/`](frontend/lib/core/theme/).

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

```bash
docker compose up -d              # Postgres 16 on 5432, Redis on 6379
psql postgresql://payandsave:payandsave@localhost:5432/payandsave \
     -f backend/db/migrations/0001_init.sql
```

Frontend (Flutter): `cd frontend && flutter pub get && flutter run -d chrome`

Backend (NestJS): `cd backend && npm ci && npm run start:dev`

Insights service (FastAPI): `cd insights-service && pip install -r requirements.txt && uvicorn app.main:app --reload`

## Branching and commits

- `main` is protected: pull requests only, one approving review, CI must pass.
- Branches: `feature/...`, `fix/...`, `docs/...`.
- Conventional Commits, e.g. `feat(ledger): append verification entries`.

## Team

Group 64 — IT23637146 Jayasekara J. M. S. H · IT23635098 Halovita H. U. D · IT23634862 Dilsara B. G. R · IT23641624 Ravishan R. K

## Licence

[MIT](LICENSE)
