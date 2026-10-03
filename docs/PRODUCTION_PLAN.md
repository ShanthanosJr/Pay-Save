# Pay&Save — Production Readiness Review & Master Plan (v2)

*Reviewed 1 October 2026 against: Milestone 01 report (Group 64), IT3060 Assignment 1 brief, `MASTER_PLAN.md` v1, the ADRs, the current codebase, and a survey of production ROSCA apps and Sri Lankan payment rails.*

---

## 1. Verdict: where the app actually stands

Pay&Save looks like a finished app but behaves like a prototype. Identity is real; **the product's reason to exist — a shared, verifiable record of who paid — is not built yet.**

| Area | State | Notes |
|---|---|---|
| Register (NIC, age, phone OTP, email, password) | **Real** | Encrypted PII, hashed lookups, lockout, refresh rotation |
| Login (phone *or* email + password) | **Real** | |
| Email verification by OTP | **Real** | |
| Forest UI, 3 languages, text size, accessibility basics | **Real** | 25 widget tests |
| Circles, members, invites | **Missing** | Home/Circle/History read `sample_circle.dart` |
| Ledger (record → verify → correct) | **Missing in API** | Schema + hash chain + append-only triggers exist in `0001_init.sql`, nothing writes to it |
| Turn order (fixed / lottery / need-based) | **Missing** | Commit–reveal designed, not built |
| Cycle close, payout, unpaid list | **Missing** | |
| Reminders, push, SMS | **Missing** | OTPs only print to the server log |
| Offline outbox (NFR-03) | **Missing** | drift is a dependency, unused |
| Statements & verify page (FR-11) | **Missing** | |
| Community tier & disputes (FR-10, US-7) | **Missing** | |
| Deploy, backups, monitoring | **Missing** | Local docker only |

Against the research: of 11 functional requirements, **0 are met end to end** (FR-01 needs a real recorded contribution). Of 7 non-functional requirements, NFR-01 (partly), NFR-05 and NFR-06 are met.

---

## 2. What production ROSCA apps teach us

| App (market) | What it does | Lesson for Pay&Save | Decision |
|---|---|---|---|
| **MoneyFellows** (Egypt, 8M+ users) | Platform-run circles of strangers; credit-scores users; early payout slots cost a fee (≈5% → 0%); many pay-in rails (cards, wallets, Fawry) | Strangers need underwriting and the platform carries default risk — that is a *licensed lender's* business | **Do not** run stranger circles or hold money. Borrow: clear slot/turn display, multi-rail payment recording, reliability signals |
| **Oraan** (Pakistan) | Verified participants, transparent transaction record, choose payout month, reminders, "Oraan score" | Reliability score + reminders reduce late payment | Build a **reliability record** (on-time %, from verified ledger only) shown to the member themself and, with consent, in statements |
| **Chamasoft** (Kenya) | Records contributions by cash/M-Pesa/cheque, auto-reconciliation, **automated fines**, member statements, SMS alert on every transaction | Organizers want rules applied automatically and every member alerted per transaction | Add **late-fee rules** (optional, organizer-set, recorded as ledger entries) and a **notification for every ledger entry about you** |
| **ChitBook** (India) | Supports fixed, auction/bid, committee chits; passbook per member; everything posts to a ledger | A passbook-per-member is the mental model people understand | History screen becomes a **passbook**; bid/auction turn order deferred (P2) |
| **Esusu** (US) | Reports only on-time payments to bureaus (positive-only) | Credit evidence must never punish; positive-only is the ethical default | Statement (FR-11) shows **verified, on-time history only**; never shares misses without the member's own action |

**Core insight:** every successful app either (a) holds the money under a licence, or (b) is a record-keeper for groups who already trust each other. ADR-0003 already chose (b). The plan doubles down on it and makes the record *stronger than a bank slip*.

---

## 3. Payments in Sri Lanka — what Pay&Save records

Pay&Save **records** payments; it never moves money (ADR-0003). Moving money requires CBSL authorisation under the Payment and Settlement Systems Act No. 28 of 2005; deposit-taking raises separate licensing questions. Get written legal advice before any feature that touches funds.

| Rail | Reality | How Pay&Save handles it |
|---|---|---|
| **Cash** | Still the most common in circles | Organizer can record "received cash" for a member → **member gets a confirm/deny prompt** (two-party confirmation, Appendix F Q11) |
| **Bank transfer (CEFTS, instant)** | Every bank app | Member records with the **bank reference**; optional **slip photo** as evidence; organizer verifies |
| **LANKAQR** | Interoperable QR across 20+ banks and ~30 apps | Organizer can store their LANKAQR payee string; member sees a **scan/copy** card; records with reference |
| **Mobile wallets** (eZ Cash, mCash, Genie, FriMi) | Common for small amounts | Method `mobile_wallet` + provider + transaction ID |
| **JustPay (pull from bank account)** | Requires a certified, licensed integration | **Out of scope** until a licensed partner exists (P3 research only) |

Payment methods stored: `cash`, `bank_transfer`, `lankaqr`, `mobile_wallet` (+ `provider` text), each with optional `receipt_reference` and optional evidence photo.

---

## 4. Trust, privacy and compliance (production blockers)

| Requirement | Why | Plan |
|---|---|---|
| **PDPA No. 9 of 2022** | Controller duties: lawful basis, DPO, breach notification, DPIAs, cross-border limits | Privacy notice + consent record at signup; **data export and account deletion** (with ledger retention: member identity is pseudonymised, entries kept); DPO contact; DPIA document; hosting region decision recorded in an ADR |
| Real OTP delivery | Codes only reach the server log today | SMS gateway behind the existing `OtpSender` (Text.lk / Notify.lk class providers ≈ LKR 0.6–1 per SMS); SES for email |
| NIC ↔ age consistency | Age is self-declared | **Derive birth year from the NIC** (both formats encode it) and reject mismatches — cheap anti-fraud |
| App lock | Shared family phones (research: low digital confidence) | Biometric / 4–6 digit PIN on app open and before sensitive actions |
| "Notify me when my info is viewed" | Appendix F Q12 | Access log for organizer views of member detail + community officer views (already designed for disputes) |
| Devices & sessions | One refresh token per user today | Per-device sessions list, sign out other devices |
| Abuse limits | Throttling exists | Per-account limits on invites/joins; organizer cannot remove a member who has an unverified/verified contribution in an open cycle without a recorded reason |

---

## 5. Gap analysis → prioritised backlog

**P0 = cannot call it a seettu app without it. P1 = needed before real users. P2 = differentiators. P3 = research only.**

### P0 — the shared record (FR-01, 02, 04, 05, 06, 07, 08, 09)
1. Create circle (amount, interval, turn rule chosen once, first due date, member count).
2. **Join by invite code / link**; organizer sees joiners; ledger `member_added`.
3. Start circle → cycles + due dates generated; turn order set (fixed: organizer arranges; lottery: **commit → reveal**; need-based: organizer orders with a recorded reason).
4. **Record contribution** (member; organizer on member's behalf for cash) — method, reference, `client_entry_id` idempotency.
5. **Verify / reject** (organizer) — reject is a `correction` entry; status returns to *due*.
6. Totals always with parts `{count, unitMinor, totalMinor, entryIds}`.
7. Cycle detail: paid / awaiting / unpaid per member from `v_cycle_member_status` only.
8. **Close cycle** (organizer) — shows unpaid by name, requires "close with N unpaid"; appends `payout` + `cycle_closed`.
9. Passbook history from the ledger; Home, Circle and History on real data.
10. Multiple circles + circle switcher; per-circle roles.

### P1 — production trust
11. Recipient **confirms payout received** (`payout_confirmed`) — closes the loop that causes most "default after payout" disputes.
12. Two-party confirmation for organizer-recorded cash.
13. Evidence photo upload (S3, private, signed URLs).
14. Notifications inbox + FCM push for every entry about you; SMS fallback for due/overdue.
15. Reminders (defaults OFF, U-06) via a scheduler.
16. Offline outbox with drift (NFR-03) — "Saved on this phone · not yet confirmed · do not pay again".
17. Real SMS/email OTP delivery; app lock; session list.
18. PDPA: privacy notice, consent record, export, deletion.
19. Statement PDF + public verify page (FR-11) with chain-head hash.
20. Deploy: staging + prod, migrations in CI, backups/PITR, Sentry, uptime alerts.

### P2 — differentiators
21. Late-fee rules (optional) as ledger entries.
22. Turn swap requests (member ↔ member, organizer approves, recorded).
23. Member reliability record (private by default; can be included in statement).
24. Community tier: consented aggregates + dispute evidence with access log (FR-10, US-7).
25. Organizer desktop/web console for large circles; CSV export.
26. Bid/auction turn order (chit-fund style).

### P3 — research
27. Licensed payment partner (JustPay / LANKAQR merchant) — legal first.
28. Formal lender acceptance of statements (pilot with a cooperative / microfinance institution).

---

## 6. Roadmap

| Milestone | Scope (backlog #) | Done when |
|---|---|---|
| **M1 · Circles & ledger core** | 1–10 | Two phones: organizer creates, member joins by code, member records, organizer verifies, both see the same totals; rejecting creates a correction; UPDATE on `ledger_entries` fails in a test |
| **M2 · Close the loop** | 11–13 | Payout confirmed by recipient; cash two-party flow; slip photo attached and viewable only by circle |
| **M3 · Never miss a payment** | 14–15 | Due-in-3-days reminder and verification push arrive on a real device; SMS fallback |
| **M4 · Works without signal** | 16 | Airplane-mode record → reconnect → exactly one server entry |
| **M5 · Real identity & privacy** | 17–18 | Real SMS OTP; app lock; export + delete my data |
| **M6 · Proof for a bank** | 19, 23 | Statement PDF verifies on the public page; tampering breaks verification |
| **M7 · Community tier** | 24 | Officer sees consented aggregates only; dispute evidence logged and member notified |
| **M8 · Ship** | 20, 25 | Staging + prod on AWS, backups tested, Play Store internal track |

---

## 7. M1 build specification (in progress)

### Data (migration `0003_circles.sql`)
- `circles`: `join_code` (8 chars, unique, unambiguous alphabet), `first_due_date`, `started_at`, `lottery_commitment`, `lottery_seed`.
- `payment_method` enum gains `lankaqr`; `ledger_entries` gains `method_provider TEXT`.
- `ledger_reference_seq` → human references `PS-1001…`.

### API (all JSON; money in minor units; errors `{statusCode, code, message}`)
| Method & path | Role | Purpose |
|---|---|---|
| `POST /circles` | any user | Create (creator = organizer) |
| `GET /circles` | any user | My circles with my current-cycle status |
| `GET /circles/:id` | member | Detail: members, turn order, cycles, current cycle statuses + totals |
| `POST /circles/join` | any user | Join a draft circle by code |
| `POST /circles/:id/lottery/commit` | organizer | Store seed, publish `sha256(seed)` |
| `POST /circles/:id/start` | organizer | Fix order (or reveal lottery), create cycles |
| `POST /circles/:id/contributions` | member / organizer | Record (idempotent on `clientEntryId`) |
| `POST /circles/:id/contributions/:entryId/verify` | organizer | Verify |
| `POST /circles/:id/contributions/:entryId/reject` | organizer | Correction with reason |
| `GET /circles/:id/verify-queue` | organizer | Recorded, not yet verified |
| `POST /circles/:id/cycles/:n/close` | organizer | Payout + close; requires unpaid acknowledgement |
| `GET /circles/:id/ledger?scope=mine\|all` | member (all = organizer) | Passbook |

### App
Circle switcher in header · Create circle (3 steps) · Join with code · Organizer start & turn order (fixed arrange / lottery draw) · Home, Circle, History on live data · Record payment sheet (4 methods + reference) · Organizer verification queue with verify/reject · Close cycle with unpaid acknowledgement.

---

### Sources
- MoneyFellows model and fees: [500 Global](https://500.co/content/egypt-s-money-fellows-uses-an-old-school-lending-tool-to-drive-fintech-innovation), [Money Fellows guide](https://moneyfellows.com/en-us/3elmelgeib-home/your-complete-guide-to-money-fellows-app/), [API Evangelist profile](https://github.com/api-evangelist/mfellows)
- Oraan: [Google Play listing](https://play.google.com/store/apps/details?id=com.oraan.android&hl=en)
- Chamasoft: [What is Chamasoft](https://help.chamasoft.com/what-is-chamasoft/), [App Store](https://apps.apple.com/us/app/chamasoft/id1489712788)
- ChitBook: [chitbook.app](https://www.chitbook.app/)
- Esusu positive-only reporting: [Invitation Homes / Esusu](https://www.invitationhomes.com/credit-reporting)
- Sri Lanka rails: [LankaPay](https://www.lankapay.net/en), [LANKAQR – LankaClear](https://www.lankaclear.com/products-and-services/lankaqr/), [Lightspark – instant payments Sri Lanka](https://www.lightspark.com/knowledge/instant-payments-sri-lanka), [Wise – cash or card in Sri Lanka](https://wise.com/gb/blog/cash-or-card-in-sri-lanka)
- Regulation: [Payment and Settlement Systems Act No. 28 of 2005](https://www.icta.lk/icta-assets/uploads/2016/03/PaymentandSettlementSystemActNo.28of2005.pdf), [CBSL payments & settlements](https://www.cbsl.gov.lk/en/financial-system/financial-infrastructure/payments-and-settlements-systems), [PDPA No. 9 of 2022](https://www.parliament.lk/uploads/acts/gbills/english/6242.pdf), [DLA Piper – Sri Lanka](https://www.dlapiperdataprotection.com/index.html?t=law&c=LK)
- SMS gateways: [Notify.lk pricing](https://www.notify.lk/pricing/), [Text.lk](https://text.lk/)
