# ADR-0001: Reuse the FitFlow stack with targeted changes

**Status:** accepted

**Context.** The team built the FitFlow architecture in Lab 05 and knows it. Pay&Save needs Android, iOS and a web view for organizers, offline recording, phone-number login and strong auditability. It does not need AI features or vector search.

**Decision.** Keep Flutter, NestJS modular monolith, PostgreSQL, Redis, SQS/SNS, Cognito, S3/CloudFront, ECS Fargate and GitHub Actions. Drop pgvector; add pgcrypto and drift. Repurpose the FastAPI AI service as `insights-service` for statement rendering and consented aggregates, and treat it as optional.

**Consequences.** Low learning cost and one codebase for the client. The Python service adds operational weight; if schedule slips, PDF rendering moves into NestJS and the service is removed without affecting anything else.
