FROM rust:1.75-slim AS builder

# Install musl tools for static compilation
RUN apt-get update && apt-get install -y --no-install-recommends \
    musl-tools \
    libssl-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy manifests
COPY Cargo.toml Cargo.lock* ./

# Create dummy source files to cache dependencies
RUN mkdir src && echo "fn main() {}" > src/main.rs

# Build dependencies (this step is cached as long as dependencies don't change)
RUN cargo build --release --target x86_64-unknown-linux-musl 2>&1 | grep -v "Compiling\|Finished" || true

# Remove dummy binary
RUN rm -rf src

# Copy actual source code
COPY src ./src

# Build the actual binary
RUN cargo build --release --target x86_64-unknown-linux-musl

# Final stage: minimal runtime
FROM scratch

# Copy the binary from builder
COPY --from=builder /app/target/x86_64-unknown-linux-musl/release/zeroclaw /zeroclaw

# Copy CA certificates for HTTPS
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Set working directory
WORKDIR /root/zeroclaw-workspace

# Set entrypoint
ENTRYPOINT ["/zeroclaw"]

# Health check (optional)
# HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
#     CMD zeroclaw --health || exit 1
