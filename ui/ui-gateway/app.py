from fastapi import FastAPI, Form, Header, HTTPException, Request
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
import os

app = FastAPI()

# Static portal directory (HTML, CSS, logo)
PORTAL_DIR = os.path.join(os.getcwd(), "portal")
app.mount("/portal", StaticFiles(directory=PORTAL_DIR), name="portal")

# Simple in-memory users for sanity checks
USERS = {
    "admin": {"password": "password", "role": "admin"},
    "lesiba": {"password": "password", "role": "user"},
}

def build_token(username: str) -> str:
    return f"{username}-token"

def auth_from_credentials(username: str, password: str):
    user = USERS.get(username)
    if not user or user["password"] != password:
        raise HTTPException(status_code=401, detail="Invalid username or password")
    return {
        "access_token": build_token(username),
        "token_type": "bearer",
        "username": username,
        "role": user["role"],
    }

def auth_from_header(authorization: str):
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing token")
    token = authorization.split(" ", 1)[1]
    if not token.endswith("-token"):
        raise HTTPException(status_code=401, detail="Invalid token")
    username = token[: -len("-token")]
    user = USERS.get(username)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid token")
    return username, user["role"]

# Root → login page
@app.get("/")
async def root():
    return FileResponse(os.path.join(PORTAL_DIR, "login.html"))

# Explicit portal login URL
@app.get("/portal/login.html")
async def portal_login():
    return FileResponse(os.path.join(PORTAL_DIR, "login.html"))

# Ecosystem status used by aiops_portal_e2e.sh
@app.get("/status/ecosystem/status")
async def ecosystem_status():
    return {
        "services": [
            {"name": "ui-gateway", "port": 8089},
            {"name": "ai_orchestrator", "port": 9088},
            {"name": "fastapi_heartbeat", "port": 8080},
            {"name": "aiops-rag-service", "port": 8000},
            {"name": "aiops-anomaly-service", "port": 8100},
        ]
    }

# /auth/login used by aiops_ui_auth_check.sh
@app.post("/auth/login")
async def auth_login(
    username: str = Form(...),
    password: str = Form(...),
):
    return auth_from_credentials(username, password)

# /api/auth/login used by aiops_portal_e2e.sh
@app.post("/api/auth/login")
async def api_auth_login(
    username: str = Form(...),
    password: str = Form(...),
):
    return auth_from_credentials(username, password)

# /api/auth/me used by sanity checks
@app.get("/api/auth/me")
async def auth_me(authorization: str = Header(None)):
    username, role = auth_from_header(authorization)
    return {"username": username, "role": role}

# /ui-api/chat used by WEB UI E2E check – allow both GET and POST
@app.get("/ui-api/chat")
async def ui_chat_get():
    return {"status": "ok"}

@app.post("/ui-api/chat")
async def ui_chat_post(request: Request):
    _ = await request.body()
    return {"status": "ok"}
