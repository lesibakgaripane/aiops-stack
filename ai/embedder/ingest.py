import os, json, hashlib
from pathlib import Path
from typing import List, Tuple
import psycopg2
from psycopg2.extras import execute_values
from pgvector.psycopg2 import register_vector
from fastembed import TextEmbedding
from langchain_text_splitters import RecursiveCharacterTextSplitter

PG = dict(
    host=os.environ.get("POSTGRES_HOST","ai_pgvector"),
    port=int(os.environ.get("POSTGRES_PORT","5432")),
    user=os.environ.get("POSTGRES_USER","aiops"),
    password=os.environ.get("POSTGRES_PASSWORD"),
    dbname=os.environ.get("POSTGRES_DB","aiops_rag"),
)

MODEL_ID = os.environ.get("EMBEDDING_MODEL","BAAI/bge-small-en-v1.5")
INGEST_ROOT = Path("/ingest")

def md5(s: str) -> str:
    return hashlib.md5(s.encode("utf-8")).hexdigest()

def connect():
    conn = psycopg2.connect(**PG)
    register_vector(conn)  # pgvector adapter
    return conn

def init_schema(cur):
    cur.execute("""
    CREATE EXTENSION IF NOT EXISTS vector;

    CREATE TABLE IF NOT EXISTS documents(
      id bigserial PRIMARY KEY,
      doc_id text UNIQUE,
      source text,
      uri text,
      meta jsonb,
      created_at timestamptz default now()
    );

    CREATE TABLE IF NOT EXISTS chunks(
      id bigserial PRIMARY KEY,
      doc_id text,
      chunk_id text UNIQUE,
      text text,
      embedding vector(384),
      uri text,
      meta jsonb
    );

    -- In case table existed without unique, add it:
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'chunks'::regclass
          AND conname = 'chunks_chunk_id_key'
      ) THEN
        ALTER TABLE chunks ADD CONSTRAINT chunks_chunk_id_key UNIQUE(chunk_id);
      END IF;
    END$$;

    CREATE INDEX IF NOT EXISTS idx_chunks_vec
      ON chunks USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
    """)

def load_files() -> List[Tuple[str,str,str]]:
    files = []
    for sub in ["runbooks","grafana_json","fastapi_schemas","onos_logs"]:
        base = INGEST_ROOT / sub
        if not base.exists(): continue
        for p in sorted(base.rglob("*")):
            if p.is_file():
                try:
                    files.append((sub, f"{sub}/{p.name}", p.read_text(errors="ignore")))
                except Exception:
                    continue
    return files

def main():
    emb = TextEmbedding(model_name=MODEL_ID)
    splitter = RecursiveCharacterTextSplitter(
        chunk_size=2000, chunk_overlap=300,
        separators=["\n\n","```","###","##","\n","."," "]
    )

    conn = connect()
    cur  = conn.cursor()
    init_schema(cur)
    conn.commit()

    files = load_files()
    print(f"[INGEST] Found {len(files)} files")

    for source, uri, raw in files:
        doc_id = md5(uri + str(len(raw)))
        cur.execute(
            "INSERT INTO documents(doc_id,source,uri,meta) VALUES (%s,%s,%s,'{}') "
            "ON CONFLICT (doc_id) DO NOTHING",
            (doc_id, source, uri)
        )

        chunks = splitter.split_text(raw)
        if not chunks:
            print(f"[INGEST] {uri}: 0 chunks")
            continue

        vecs = list(emb.embed(chunks))
        rows = []
        for i, (ch, vec) in enumerate(zip(chunks, vecs)):
            vec_py = [float(x) for x in vec]  # cast to plain floats
            chunk_id = f"{doc_id}_{i:04d}"
            meta = json.dumps({"source": source})
            rows.append((doc_id, chunk_id, ch, vec_py, uri, meta))

        execute_values(
            cur,
            "INSERT INTO chunks(doc_id,chunk_id,text,embedding,uri,meta) "
            "VALUES %s ON CONFLICT (chunk_id) DO NOTHING",
            rows
        )
        conn.commit()
        print(f"[INGEST] {uri}: {len(chunks)} chunks")

    cur.close()
    conn.close()
    print("[INGEST] complete")

if __name__ == "__main__":
    main()
