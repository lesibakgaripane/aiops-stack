import os
from typing import Any, Dict, List, Optional

from fastapi import FastAPI
from pydantic import BaseModel

from haystack.document_stores import InMemoryDocumentStore
from haystack.nodes import EmbeddingRetriever
from haystack import Document
from haystack.pipelines import DocumentSearchPipeline


KB_PATH = os.getenv("KB_PATH", "/app/kb")
EMBED_MODEL = os.getenv(
    "EMBED_MODEL",
    "sentence-transformers/all-MiniLM-L6-v2",
)

# --- Haystack components ------------------------------------------------------

# MiniLM has 384-dimensional embeddings
document_store = InMemoryDocumentStore(embedding_dim=384)

retriever = EmbeddingRetriever(
    document_store=document_store,
    embedding_model=EMBED_MODEL,
    use_gpu=False,
)

search_pipeline = DocumentSearchPipeline(retriever)


def load_kb_from_disk() -> Dict[str, Any]:
    """
    Load all text files from KB_PATH into Haystack document store.
    For now: simple whole-file documents (no splitting).
    """
    docs: List[Document] = []

    if not os.path.isdir(KB_PATH):
        return {"documents": 0, "kb_path": KB_PATH, "note": "KB path does not exist"}

    for root, _, files in os.walk(KB_PATH):
        for fname in files:
            full_path = os.path.join(root, fname)
            try:
                with open(full_path, "r", encoding="utf-8", errors="ignore") as f:
                    text = f.read().strip()
                if not text:
                    continue
                docs.append(
                    Document(
                        content=text,
                        meta={"source": full_path},
                    )
                )
            except Exception as e:
                # Skip problematic files but continue
                print(f"[KB-LOAD] Failed to read {full_path}: {e}")

    # Replace existing docs
    document_store.delete_documents()
    if docs:
        document_store.write_documents(docs)
        document_store.update_embeddings(retriever)

    return {
        "documents": document_store.get_document_count(),
        "kb_path": KB_PATH,
    }


# --- FastAPI models -----------------------------------------------------------

class QueryRequest(BaseModel):
    question: str
    context: Optional[Dict[str, Any]] = None


class ReindexResponse(BaseModel):
    documents: int
    kb_path: str


class QueryResponse(BaseModel):
    answer: str
    debug: Dict[str, Any]


# --- FastAPI app --------------------------------------------------------------

app = FastAPI(title="AIOps RAG Service (Haystack)")


@app.on_event("startup")
def on_startup():
    print("[RAG] Loading KB into Haystack...")
    info = load_kb_from_disk()
    print(f"[RAG] KB loaded: {info}")


@app.get("/health")
def health():
    return {
        "status": "ok",
        "service": "aiops-rag-service-haystack",
        "documents": document_store.get_document_count(),
        "kb_path": KB_PATH,
    }


@app.post("/reindex_local_kb", response_model=ReindexResponse)
def reindex_local_kb():
    info = load_kb_from_disk()
    return ReindexResponse(documents=info["documents"], kb_path=info["kb_path"])


@app.post("/query", response_model=QueryResponse)
def query(req: QueryRequest):
    """
    RAG-style query over the KB using Haystack retriever.
    Same shape as before so aiops-ml-gateway + Rasa do not need changes.
    """
    result = search_pipeline.run(
        query=req.question,
        params={"Retriever": {"top_k": 3}},
    )
    docs: List[Document] = result.get("documents", [])

    matches: List[Dict[str, Any]] = []
    answer_lines: List[str] = []

    if not docs:
        answer_lines.append(
            f"[Haystack RAG] No relevant context found in AIOps KB for: '{req.question}'."
        )
    else:
        answer_lines.append(
            f"[Haystack RAG] Based on the AIOps KB, here is some relevant context for your question: '{req.question}'."
        )
        for d in docs:
            src = os.path.basename(d.meta.get("source", "unknown"))
            score = getattr(d, "score", None)
            snippet = (d.content or "").strip().replace("\n", " ")
            snippet = snippet[:400]

            if score is not None:
                answer_lines.append(
                    f"- From {src} (score={score:.3f}): {snippet}"
                )
            else:
                answer_lines.append(
                    f"- From {src}: {snippet}"
                )

            matches.append(
                {
                    "source": d.meta.get("source", "unknown"),
                    "score": score,
                    "content": d.content,
                }
            )

    if req.context:
        answer_lines.append(f"\n(Context: {req.context})")

    answer = "\n".join(answer_lines)

    debug: Dict[str, Any] = {
        "question": req.question,
        "context": req.context,
        "matches": matches,
    }
    return QueryResponse(answer=answer, debug=debug)
