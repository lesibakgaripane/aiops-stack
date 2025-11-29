from fastapi import FastAPI, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List
import os
import secrets

# --------------------------------------------------
# FastAPI app
# --------------------------------------------------

app = FastAPI(
    title="AIOps UI Gateway",
    docs_url=None,
    redoc_url=None,
    openapi_url=None,
)

# --------------------------------------------------
# CORS
# --------------------------------------------------

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # tighten for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --------------------------------------------------
# Models
# --------------------------------------------------

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    username: str

class ServiceInfo(BaseModel):
    name: str
    port: int

class EcosystemStatus(BaseModel):
    services: List[ServiceInfo]

# --------------------------------------------------
# Routes
# --------------------------------------------------

@app.get("/health")
def health():
    return {"status": "ok", "service": "aiops-ui-gateway"}

@app.get("/status/ecosystem/status", response_model=EcosystemStatus)
def ecosystem_status():
    services = [
        {"name": "ui-gateway", "port": int(os.getenv("UI_GATEWAY_PORT", "8089"))},
        {"name": "ai_orchestrator", "port": int(os.getenv("AI_ORCH_PORT", "9088"))},
        {"name": "fastapi_heartbeat", "port": int(os.getenv("FASTAPI_HEARTBEAT_PORT", "8080"))},
        {"name": "aiops-rag-service", "port": int(os.getenv("AIOPS_RAG_PORT", "8000"))},
        {"name": "aiops-anomaly-service", "port": int(os.getenv("AIOPS_ANOMALY_PORT", "8100"))},
    ]
    return {"services": services}

@app.post("/api/auth/login", response_model=TokenResponse)
def login(username: str = Form(...), password: str = Form(...)):
    """
    POST /api/auth/login
    Content-Type: application/x-www-form-urlencoded
    body: username=admin&password=password (by default)
    """
    admin_user = os.getenv("AIOPS_UI_ADMIN_USER", "admin")
    admin_pass = os.getenv("AIOPS_UI_ADMIN_PASSWORD", "password")

    if username != admin_user or password != admin_pass:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    # Just generate a random token string – script only cares that it exists
    token = secrets.token_hex(32)

    return TokenResponse(
        access_token=token,
        token_type="bearer",
        username=username,
    )

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("UI_GATEWAY_PORT", "8089"))
    uvicorn.run("app:app", host="0.0.0.0", port=port)
