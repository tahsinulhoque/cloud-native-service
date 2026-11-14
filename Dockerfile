
# ==================================
# Stage 1: Builder
# ==================================
FROM python:3.14.3-slim-bookworm AS builder

WORKDIR /build

COPY requirements.txt .

RUN pip install --no-cache-dir \
    --prefix=/install \
    -r requirements.txt


# ==================================
# Stage 2: Production Runtime
# ==================================
FROM python:3.14.3-slim-bookworm AS runtime

LABEL org.opencontainers.image.title="Cloud Native Service" \
      org.opencontainers.image.description="Production-ready FastAPI service" \
      org.opencontainers.image.version="1.0.0"

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8000 \
    LOG_LEVEL=INFO \
    ENVIRONMENT=production \
    APP_VERSION=1.0.0

WORKDIR /app

# Create non-root user
RUN groupadd --system app && \
    useradd --system --gid app --no-create-home app

# Install dependencies from builder
COPY --from=builder /install /usr/local

# Copy application
COPY --chown=app:app app/ ./app/

# Run as non-root
USER app

EXPOSE 8000

# Healthcheck
HEALTHCHECK --interval=30s \
            --timeout=3s \
            --start-period=10s \
            --retries=3 \
    CMD python -c "import os,urllib.request; urllib.request.urlopen('http://127.0.0.1:' + os.getenv('PORT','8000') + '/health', timeout=2)" || exit 1

# Graceful shutdown
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
