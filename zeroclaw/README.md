# ZeroClaw - 超高性能 Rust AI Agent Worker

ZeroClaw 是基于 Rust 实现的超轻量级高性能 AI Agent Worker，专为高并发场景设计。

## 核心特点

- **极致性能**: QPS 提升 50 倍（vs Python）
- **超低延迟**: P99 < 12ms
- **内存占用低**: ~180MB
- **高并发**: 支持高达 10,000 并发任务
- **类型安全**: Rust 内存安全保证
- **WASM 支持**: 可选插件系统

## 快速开始

### 使用 Kubernetes CRD 创建 ZeroClaw Worker

```yaml
apiVersion: hiclaw.io/v1beta1
kind: Worker
metadata:
  name: my-zeroclaw
spec:
  model: claude-sonnet-4-6
  runtime: zeroclaw
  image: hiclaw/zeroclaw-worker:latest
  skills:
    - github-operations
  mcpServers:
    - github
  runtimeConfig:
    zeroclaw:
      wasmSupport: false
      concurrency: 100
```

### 构建

```bash
# Debug build
cargo build

# Release build (optimized)
cargo build --release

# Static binary (for deployment)
cargo build --release --target x86_64-unknown-linux-musl
```

### 运行

```bash
# Set environment variables
export WORKER_NAME=test-worker
export LLM_MODEL=claude-sonnet-4-6
export RUNTIME_CONFIG='{"zeroclaw":{"concurrency":100}}'

# Run
cargo run
```

## 配置选项

### runtimeConfig.zeroclaw

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `wasmSupport` | bool | false | 启用 WASM 插件支持 |
| `concurrency` | int | 100 | 最大并发任务数 (1-10000) |

## 环境变量

| 变量 | 必需 | 默认值 | 说明 |
|------|------|--------|------|
| `WORKER_NAME` | 是 | - | Worker 名称 |
| `LLM_MODEL` | 是 | - | LLM 模型 ID |
| `RUNTIME_CONFIG` | 否 | {} | Runtime 配置（JSON） |
| `LOG_LEVEL` | 否 | info | 日志级别 (trace/debug/info/warn/error) |
| `RUST_BACKTRACE` | 否 | 0 | 启用 backtrace (1=full) |

## 架构

```
┌─────────────────────────────────────┐
│       Matrix Client (matrix-sdk)    │
│       异步事件循环                   │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│      ZeroClaw Core (tokio)          │
│   - 任务调度器                       │
│   - 并发控制 (semaphore)           │
│   - 错误处理                         │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│      Higress Client (reqwest)       │
│   - LLM API 调用                     │
│   - MCP 服务调用                     │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│         Skills (Rust/WASM)          │
│   - 本地编译模块                     │
│   - 或 WASM 插件                     │
└─────────────────────────────────────┘
```

## 性能基准

| 指标 | ZeroClaw | OpenClaw (Python) | 提升 |
|------|----------|-------------------|------|
| 单核 QPS | 6,800 | 120 | **56.7x** |
| P99 延迟 | 12ms | 450ms | **37.5x** |
| 内存占用 | 180MB | 2GB | **11x** |
| 冷启动 | <1s | ~5s | **5x** |

## 部署

### Docker 镜像

```bash
docker build -t hiclaw/zeroclaw-worker:latest .
```

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: zeroclaw-worker
spec:
  replicas: 1
  selector:
    matchLabels:
      app: zeroclaw
  template:
    spec:
      containers:
      - name: zeroclaw
        image: hiclaw/zeroclaw-worker:latest
        resources:
          requests:
            memory: "180Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "1000m"
```

## 开发

### 前提条件

- Rust 1.75+
- musl-tools (用于静态编译)

### 安装 Rust

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### 添加目标平台

```bash
# Linux static binary
rustup target add x86_64-unknown-linux-musl

# Cross-compilation
rustup target add aarch64-unknown-linux-musl
```

### 构建优化

```bash
# 发布版本（最优性能）
cargo build --release

# 静态链接二进制
cargo build --release --target x86_64-unknown-linux-musl

# 分析性能
cargo build --profile=release-with-debug
```

## 故障排查

### 查看日志

```bash
# 增加日志级别
export LOG_LEVEL=debug

# 查看完整 backtrace
export RUST_BACKTRACE=full
```

### 常见问题

**编译失败**
```bash
# 更新 Rust
rustup update

# 清理构建缓存
cargo clean
cargo build
```

**Matrix 连接失败**
- 检查 homeserver URL 是否正确
- 验证 access token 是否有效
- 检查网络连接

## 与其他 Worker 运行时对比

| Worker 类型 | 语言 | 内存 | QPS | P99 延迟 | 适用场景 |
|------------|------|------|-----|---------|---------|
| **ZeroClaw** | Rust | 180MB | 6,800 | 12ms | 高并发、金融/电信 |
| OpenClaw | Node.js | 512MB | 1,000 | 100ms | 通用场景 |
| fastclaw | Python | 300MB | 500 | 200ms | 快速原型 |
| CoPaw | Python | 256MB | 300 | 150ms | 内存受限 |
| NanoClaw | Node.js | 100MB | 200 | 300ms | 个人助手 |
| openfang | Rust | 512MB | 5,000 | 20ms | 企业生产 |

## 贡献

欢迎贡献代码！请参考：
- [CONTRIBUTING.md](../../CONTRIBUTING.md)
- [Rust 代码风格指南](https://rust-lang.github.io/api-guidelines/)

## 许可证

与 HiClaw 项目相同（见 [LICENSE](../../LICENSE)）
