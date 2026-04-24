FROM python:3.11-slim

LABEL maintainer="HiClaw Team"
LABEL description="fastclaw - Lightweight Python AI Agent Worker for HiClaw"

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PIP_NO_CACHE_DIR=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy requirements and install Python dependencies
# In production, you would add a requirements.txt with actual dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt || echo "No requirements.txt, skipping"

# Copy fastclaw source code
COPY src/worker.py /app/worker.py
COPY scripts/fastclaw-entrypoint.sh /app/entrypoint.sh

# Make entrypoint executable
RUN chmod +x /app/entrypoint.sh

# Set working directory
WORKDIR /root/fastclaw-workspace

# Expose health check port (optional)
EXPOSE 8080

# Health check (optional, can be added later)
# HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
#     CMD python3 /app/healthcheck.py || exit 1

# Set entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]
