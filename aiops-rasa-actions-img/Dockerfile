FROM rasa/rasa-sdk:3.6.0

USER root
RUN pip install --no-cache-dir requests httpx

# Drop back to non-root user that the base image uses
USER 1001
WORKDIR /app
