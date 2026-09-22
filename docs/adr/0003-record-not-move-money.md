# ADR-0003: Pay&Save records payments; it does not move money

**Status:** accepted

**Context.** The research need is verification of payments already made by cash, bank transfer or mobile wallet. Holding or transferring funds would bring payment-service regulation, security obligations and costs outside a student project.

**Decision.** "Pay now" records a payment with its method and optional receipt reference; the organizer verifies it. No payment gateway integration in version 1.

**Consequences.** Simpler, safer build. Verification depends on the organizer, which the ledger makes visible and accountable. Real money movement could be revisited later only after regulatory advice.
