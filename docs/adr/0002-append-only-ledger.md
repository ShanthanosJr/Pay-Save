# ADR-0002: Append-only, hash-chained ledger in PostgreSQL

**Status:** accepted

**Context.** Milestone 01: willingness to trust an app (2.73/5) is below confidence in manual records (3.33/5), and disputes arise because no one can prove what was recorded. FR-08 requires non-editable records with corrections as new entries.

**Decision.** All money and membership events are rows in `ledger_entries`. Triggers block UPDATE, DELETE and TRUNCATE. A BEFORE INSERT trigger, under a per-circle advisory lock, sets `hash = sha256(prev_hash | fields)`. Status and totals are derived by views, never stored.

**Consequences.** Every state is reconstructable and tampering is detectable; statements can carry a chain head hash. Writes per circle are serialised (fine for circles of up to ~50 members). Schema changes to the ledger need care because historical hashes must still verify.
