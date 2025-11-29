import os
from typing import List, Dict, Any
from fastapi import FastAPI, Body
from pydantic import BaseModel
import psycopg2
from psycopg2.extras import RealDictCursor
from pgvector.psycopg2 import register_vector
from fastembed import TextEmbedding

TOPK = int(os.environ.get("RAG_TOPK","5"))

PG = dict(
    host=os.environ.get("POSTGRES_HOST","ai_pgvector"),
    port=int(os.environ.get("POSTGRES_PORT","5432")),
    user=os.environ.get("POSTGRES_USER","aiops"),
    password=os.environ.get("POSTGRES_PASSWORD"),
    dbname=os.environ.get("POSTGRES_DB","aiops_rag"),
)

app = FastAPI(title="AIOps RAG Orchestrator", version="1.0")
_emb = None

def emb():
    global _emb
    if _emb is None:
        _emb = TextEmbedding(model_name="BAAI/bge-small-en-v1.5")
    return _emb

def connect():
    conn = psycopg2.connect(**PG)
    register_vector(conn)
    return conn

def search(conn, query: str, k: int) -> List[Dict[str,Any]]:
    # Build pgvector literal string and cast in SQL
    qvec = list(emb().embed([query]))[0]
    vec_str = "[" + ",".join(f"{float(x):.6f}" for x in qvec) + "]"
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("""
            WITH q AS (SELECT %s::vector AS v)
            SELECT doc_id, text, uri, meta,
                   1.0 - (embedding <=> q.v) AS score
            FROM chunks, q
            ORDER BY embedding <=> q.v
            LIMIT %s
        """, (vec_str, max(1, k)))
        rows = cur.fetchall()
    return [dict(r) for r in rows]

class QueryReq(BaseModel):
    q: str
    k: int = 5

@app.get("/health")
def health():
    return {"ok": True}

@app.post("/query")
def query(req: QueryReq):
    k = max(1, min(req.k, TOPK))
    conn = connect()
    try:
        hits = search(conn, req.q, k)
        return {"ok": True, "hits": hits}
    finally:
        conn.close()

class EvalItem(BaseModel):
    q: str
    expect_uris: List[str]

@app.post("/eval")
def eval(items: List[EvalItem] = Body(...)):
    conn = connect()
    try:
        total = len(items)
        found = 0
        details = []
        for it in items:
            hits = search(conn, it.q, TOPK)
            uri_list = [h["uri"] for h in hits]
            ok = any(u in uri_list for u in it.expect_uris)
            if ok: found += 1
            details.append({"q": it.q, "ok": ok, "uris": uri_list})
        acc = (found / total) if total else 0.0
        return {"ok": True, "n": total, "acc": acc, "details": details}
    finally:
        conn.close()
