from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Any, Dict, Optional
import httpx
import os


# Internal URLs (Docker network)
RAG_URL = "http://aiops-rag-service:8000/query"
ANOMALY_URL = "http://aiops-anomaly-service:8100/score"

app = FastAPI(title="AIOps ML Gateway")

class RAGQuery(BaseModel):
    question: str
    context: Optional[Dict[str, Any]] = None

class AnomalyScoreRequest(BaseModel):
    device: str
    metric: str = "cpu_usage"
    alert_id: Optional[str] = None
    time_window: str = "15m"
    value: Optional[float] = None  # numeric metric value (e.g., CPU %)


@app.get("/health")
async def health():
    return {"status": "ok", "service": "aiops-ml-gateway"}


@app.post("/ai/rag/query")
async def rag_query(payload: RAGQuery):
    """Proxy to the RAG brain (aiops-rag-service)."""
    async with httpx.AsyncClient(timeout=30.0) as client:
        try:
            resp = await client.post(RAG_URL, json=payload.dict())
            resp.raise_for_status()
            return resp.json()
        except httpx.HTTPError as e:
            detail = getattr(e.response, "text", str(e))
            raise HTTPException(status_code=502, detail=f"RAG service error: {detail}")


@app.post("/ai/anomaly/score")
async def anomaly_score(payload: AnomalyScoreRequest):
    """Proxy to the anomaly brain (aiops-anomaly-service)."""
    async with httpx.AsyncClient(timeout=30.0) as client:
        try:
            # Forward ALL fields, including 'value'
            resp = await client.post(ANOMALY_URL, json=payload.dict())
            resp.raise_for_status()
            return resp.json()
        except httpx.HTTPError as e:
            detail = getattr(e.response, "text", str(e))
            raise HTTPException(status_code=502, detail=f"Anomaly service error: {detail}")

# --- ChatGPT Bridge Proxy (auto-added) ---
CHATGPT_BRIDGE_URL = os.getenv("CHATGPT_BRIDGE_URL", "http://aiops-chatgpt-bridge:9100/respond")
CHATGPT_TIMEOUT = float(os.getenv("OPENAI_TIMEOUT", "25"))

@app.post("/ai/chatgpt")
async def chatgpt_proxy(req: dict):
    """
    Proxy requests to ChatGPT bridge.
    Input: {message/user_message, context?, conversation_id?, system_prompt?}
    """
    user_msg = req.get("message") or req.get("user_message")
    if not user_msg:
        return {"error": "message is required"}

    payload = {
        "user_message": user_msg,
        "conversation_id": req.get("conversation_id"),
        "context": req.get("context"),
        "system_prompt": req.get("system_prompt"),
    }

    try:
        async with httpx.AsyncClient(timeout=CHATGPT_TIMEOUT) as c:
            r = await c.post(CHATGPT_BRIDGE_URL, json=payload)
            # don’t raise_for_status; pass through errors cleanly
            if r.status_code >= 400:
                return {"error": r.text, "status_code": r.status_code}
            return r.json()
    except httpx.RequestError as e:
        return {"error": f"Bridge unreachable: {str(e)}", "status_code": 502}
