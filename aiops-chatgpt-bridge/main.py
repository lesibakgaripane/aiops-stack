from fastapi import FastAPI
from fastapi.responses import JSONResponse

app = FastAPI(title="aiops-chatgpt-bridge-minimal")

@app.get("/health")
def health():
    return {"status": "ok", "model": "gpt-5.1"}

# Optional echo endpoint so ML-GW can hit something if needed
@app.post("/echo")
async def echo(payload: dict):
    return JSONResponse(content={"ok": True, "payload": payload})
