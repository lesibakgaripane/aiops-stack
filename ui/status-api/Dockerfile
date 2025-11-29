FROM python:3.11-slim
WORKDIR /app
RUN pip install --no-cache-dir fastapi uvicorn
COPY status_api.py /app/status_api.py
EXPOSE 8090
CMD ["uvicorn", "status_api:app", "--host", "0.0.0.0", "--port", "8090"]
