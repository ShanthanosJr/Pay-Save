# insights-service — FastAPI

Replaces FitFlow's AI microservice. Two jobs:

1. **Statements (FR-11):** consume `statement.requested` from SQS, render PDF (WeasyPrint) and CSV with the arithmetic, chain head hash and verification code, store in S3.
2. **Community aggregates (FR-10):** read-only access to `v_community_circle_health` on a read replica. Never queries tables with member identities.

Optional service: if time is short, move statement rendering into NestJS and remove this folder (ADR-0001).
