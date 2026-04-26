# ============================================================
# HiClaw NanoClaw Worker Agent - Minimal Node.js Container
# ============================================================
# Ultra-lightweight AI agent worker (~500 lines) for
# resource-constrained environments. Uses Matrix + Higress.
#
# Build args:
#   HIGRESS_REGISTRY  - registry for mc image (default: cn-hangzhou)
# ============================================================

ARG HIGRESS_REGISTRY=higress-registry.cn-hangzhou.cr.aliyuncs.com

# ============ Stage 1: mc (MinIO Client) ============
FROM ${HIGRESS_REGISTRY}/higress/mc:20260216 AS mc

# ============ Stage 2: Build Node.js dependencies ============
FROM node:22-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production --ignore-scripts

# ============ Final Image ============
FROM node:22-alpine

WORKDIR /app

# mc (MinIO Client) - workers need mc for file sync
COPY --from=mc /usr/bin/mc /usr/local/bin/mc.bin

# Create mc wrapper script that works on Alpine (musl libc)
RUN printf '#!/bin/sh\nexec /usr/local/bin/mc.bin "$@"\n' > /usr/local/bin/mc \
    && chmod +x /usr/local/bin/mc

# Copy from builder
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/node_modules ./node_modules

# Copy source code and scripts
COPY src ./src
COPY scripts ./scripts

# Make entrypoint executable
RUN chmod +x /app/scripts/nanoclaw-entrypoint.sh

# Set working directory
WORKDIR /root/nanoclaw-workspace

# Set entrypoint
ENTRYPOINT ["/app/scripts/nanoclaw-entrypoint.sh"]
