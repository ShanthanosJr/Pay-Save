"""insights-service — Phase 0 skeleton.

Future jobs (see README.md / docs/MASTER_PLAN.md section 4): render
verified-savings-statement PDFs/CSVs from SQS and serve consented,
anonymised community aggregates. For now this only exposes /health.
"""

from fastapi import FastAPI

app = FastAPI(title="insights-service")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
