FROM python:3.11-slim

ENV PIP_DEFAULT_TIMEOUT=120

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir psycopg2-binary pgvector sqlalchemy pydantic==2.* \
    orjson python-dotenv markdown-it-py langchain-text-splitters fastembed

WORKDIR /app
COPY ingest.py /app/ingest.py
