from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(
    title="AIOps Orchestrator",
    docs_url=None,
    redoc_url=None,
    openapi_url=None,
)

class QueryPayload(BaseModel):
    message: str

@app.get("/health")
def health() -> dict:
    return {"status": "ok", "service": "ai-orchestrator"}

@app.post("/query")
def query(payload: QueryPayload) -> dict:
    """
    Minimal AIOps brain stub.
    """
    msg = (payload.message or "").strip()
    if not msg:
        return {"reply": "Hi, I did not receive any message to analyse."}

    return {
        "reply": f"AIOps brain stub: I received -> {msg}"
    }
