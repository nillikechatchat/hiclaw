FROM node:22-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production --ignore-scripts

# Copy source code
COPY src ./src
COPY scripts ./scripts

# Final stage
FROM node:22-alpine

WORKDIR /app

# Copy from builder
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/src ./src
COPY --from=builder /app/scripts ./scripts

# Make entrypoint executable
RUN chmod +x /app/scripts/nanoclaw-entrypoint.sh

# Set working directory
WORKDIR /root/nanoclaw-workspace

# Set entrypoint
ENTRYPOINT ["/app/scripts/nanoclaw-entrypoint.sh"]

# Container timeout (default 5 minutes, configurable via RUNTIME_CONFIG)
# ENV CONTAINER_TIMEOUT=300
