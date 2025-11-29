import os
from typing import Optional, Dict, Any

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from openai import OpenAI
from openai import RateLimitError, AuthenticationError, BadRequestError

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-5.1")
OPENAI_TIMEOUT = float(os.getenv("OPENAI_TIMEOUT", "25"))

if not OPENAI_API_KEY:
    raise RuntimeError("OPENAI_API_KEY is not set")

client = OpenAI(
    api_key=OPENAI_API_KEY,
    timeout=httpx.Timeout(OPENAI_TIMEOUT),
)

app = FastAPI(title="AIOps ChatGPT Bridge", version="1.2")

class ChatRequest(BaseModel):
    user_message: str = Field(..., min_length=1)
    conversation_id: Optional[str] = None
    context: Optional[str] = None
    system_prompt: Optional[str] = None

class ChatResponse(BaseModel):
    answer: str
    model: str
    usage: Optional[Dict[str, Any]] = None

@app.get("/health")
def health():
    return {"status": "ok", "model": OPENAI_MODEL}

def build_messages(system_prompt: Optional[str], user_message: str, context: Optional[str]):
    sys_msg = system_prompt or (
        "You are a helpful AIOps assistant for network operations. "
        "Be concise, technical, and actionable."
    )
    msgs = [{"role": "system", "content": sys_msg}]
    if context:
        msgs.append({"role": "system", "content": f"Context:\n{context}"})
    msgs.append({"role": "user", "content": user_message})
    return msgs

@app.post("/respond", response_model=ChatResponse)
def respond(req: ChatRequest):
    try:
        messages = build_messages(req.system_prompt, req.user_message, req.context)
        r = client.chat.completions.create(
            model=OPENAI_MODEL,
            messages=messages,
        )
        answer = r.choices[0].message.content or ""
        usage = getattr(r, "usage", None)
        usage_dict = usage.model_dump() if usage else None
        return ChatResponse(answer=answer, model=OPENAI_MODEL, usage=usage_dict)

    except RateLimitError as e:
        raise HTTPException(
            status_code=429,
            detail="OpenAI rate limit / quota hit. Check billing, project limits, or switch to gpt-5-mini."
        )
    except AuthenticationError:
        raise HTTPException(status_code=401, detail="Invalid/disabled OPENAI_API_KEY.")
    except BadRequestError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=502, detail=str(e))
