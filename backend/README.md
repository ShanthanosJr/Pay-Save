# Backend — NestJS core API (modular monolith)

Scaffolded in Phase 0 (`npx @nestjs/cli new . --package-manager npm --strict`).

Modules: `auth`, `users`, `circles`, `memberships`, `cycles`, `ledger`, `payouts`, `turn-order`, `reminders`, `notifications`, `consent`, `disputes`, `statements`, `audit`.

Database: plain SQL migrations in `db/migrations/` (applied in order). The ledger rules in `AGENTS.md` apply; only `LedgerService.append()` writes ledger rows. The app's database role must have `INSERT, SELECT` on `ledger_entries` and nothing else.

Local: `docker compose up -d` at repo root, then apply `db/migrations/0001_init.sql`.
