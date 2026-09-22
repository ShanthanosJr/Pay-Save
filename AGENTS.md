# Rules for AI coding agents (Antigravity, Claude Code, Copilot, etc.)

Read `docs/MASTER_PLAN.md` and `docs/design-system.md` before writing code. These rules are non-negotiable; a PR that breaks one is rejected.

## Money and the ledger
1. Money is `BIGINT` / `int` **minor units** everywhere (LKR 5,000 = 500000). No `double`, no `float`, no `numeric` arithmetic in Dart or JS.
2. `ledger_entries` is **append-only**. Never write `UPDATE` or `DELETE` against it, never add an ORM `save()` that could update it. Fixes are `correction` entries with `target_entry_id`.
3. Only `LedgerService.append()` in the NestJS `ledger` module inserts ledger rows.
4. Every contribution carries a device-generated `client_entry_id` (UUID v4). Sync retries must reuse it.
5. Pay&Save **records** payments; it never moves money. Do not add payment gateway code.

## Totals and status
6. Every total returned by the API includes its parts: `{ count, unitMinor, totalMinor, entryIds }`. The UI shows them with `PsArithmeticRow`.
7. Contribution status comes only from `v_cycle_member_status` (server) and the local outbox (`pending_sync`). Never compute status separately on a screen.
8. When a contribution exists for the current cycle, **Pay now is disabled**.

## Access
9. Every API route declares its required circle role with a guard. Community officers never receive member names, phone numbers or individual entries except the `entry_ids` of a consented dispute, and every such read writes `dispute_access_log`.

## UI
10. Use only tokens from `frontend/lib/core/theme/`. No hard-coded colours, fonts or radii.
11. Every user-visible string goes through `AppLocalizations` with keys in **all three** ARB files (`en`, `si`, `ta`). Use `TODO(translate)` in si/ta only if a native speaker has not reviewed it yet, never an empty value.
12. Touch targets ≥ 48 dp. Status = icon + word, never colour alone. Bottom navigation shows labels.
13. Screen layouts follow the Milestone 02 prototype flows; only the visual skin follows the reference design.

## Process
14. One phase at a time (`docs/antigravity-prompts.md`). Small commits, Conventional Commit messages.
15. Write tests with the feature. Never commit secrets; use `.env.example`.
