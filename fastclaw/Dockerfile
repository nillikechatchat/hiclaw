FROM python:3.11-slim

LABEL maintainer="HiClaw Team"
LABEL description="fastclaw - Lightweight Python AI Agent Worker for HiClaw"

ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PIP_NO_CACHE_DIR=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1

# Install system dependencies including mc (MinIO Client)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install mc (MinIO Client)
RUN curl -fsSL https://dl.min.io/client/mc/release/linux-amd64/mc \
    -o /usr/local/bin/mc && \
    chmod +x /usr/local/bin/mc

WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy fastclaw source code
COPY src/worker.py /app/worker.py
COPY scripts/fastclaw-entrypoint.sh /app/entrypoint.sh

# Make entrypoint executable
RUN chmod +x /app/entrypoint.sh

# Create hiclaw-fs directory structure
RUN mkdir -p /root/hiclaw-fs /root/fastclaw-workspace

WORKDIR /root/fastclaw-workspace

ENTRYPOINT ["/app/entrypoint.sh"]
