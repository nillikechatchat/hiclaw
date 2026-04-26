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

# Final stage: minimal runtime with shell support
FROM alpine:3.19

# Install ca-certificates and minio client (mc)
RUN apk add --no-cache ca-certificates curl && \
    curl -sL https://dl.min.io/client/mc/release/linux-amd64/mc -o /usr/local/bin/mc && \
    chmod +x /usr/local/bin/mc

# Copy the binary from builder
COPY --from=builder /app/target/x86_64-unknown-linux-musl/release/zeroclaw /usr/local/bin/zeroclaw

# Set working directory
WORKDIR /root/zeroclaw-workspace

# Set entrypoint
ENTRYPOINT ["zeroclaw"]
