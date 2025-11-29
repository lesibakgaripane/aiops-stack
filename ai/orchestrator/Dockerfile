FROM python:3.11-slim
ENV PIP_DEFAULT_TIMEOUT=120
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir fastapi uvicorn[standard] psycopg2-binary \
    pydantic==2.* orjson python-dotenv pgvector fastembed openai tiktoken
WORKDIR /app
COPY app.py /app/app.py
CMD ["uvicorn","app:app","--host","0.0.0.0","--port","8088"]
