FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# FastAPI + Uvicorn + Scikit-learn + joblib for ML model support
RUN pip install --no-cache-dir fastapi "uvicorn[standard]" scikit-learn joblib numpy

COPY app /app

EXPOSE 8100

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8100"]
