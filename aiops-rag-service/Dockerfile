FROM python:3.11-slim

# Workdir inside the container
WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# System deps for building Python wheels etc.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        git \
        curl \
    && rm -rf /var/lib/apt/lists/*

# Copy our app code into the image
COPY app /app

# Python deps for RAG service
# NOTE: This pip runs ONLY inside the container image, NOT on your host OS.
RUN pip install --no-cache-dir --upgrade pip \
 && pip install --no-cache-dir \
      "farm-haystack[inference]==1.24.0" \
      "sentence-transformers==2.2.2" \
      "huggingface_hub==0.25.2" \
      "uvicorn[standard]" \
      "fastapi"

# Expose internal port
EXPOSE 8000

# Start FastAPI RAG service
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
