FROM rust:1.80-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    musl-tools \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

RUN rustup target add x86_64-unknown-linux-musl

WORKDIR /app

COPY Cargo.toml Cargo.lock* ./

RUN mkdir src && echo "fn main() {}" > src/main.rs

RUN cargo build --release --target x86_64-unknown-linux-musl 2>&1 | grep -v "Compiling\|Finished" || true

RUN rm -rf src

COPY src ./src

RUN cargo build --release --target x86_64-unknown-linux-musl

FROM alpine:3.19

RUN apk add --no-cache ca-certificates curl && \
    curl -sL https://dl.min.io/client/mc/release/linux-amd64/mc -o /usr/local/bin/mc && \
    chmod +x /usr/local/bin/mc

COPY --from=builder /app/target/x86_64-unknown-linux-musl/release/zeroclaw /usr/local/bin/zeroclaw

WORKDIR /root/zeroclaw-workspace

ENTRYPOINT ["zeroclaw"]
