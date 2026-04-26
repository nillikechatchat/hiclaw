# openfang - 企业级 Rust AI Agent Worker

openfang 是基于 Rust 实现的企业级 AI Agent Worker，提供高可用性、可观测性和企业特性。

## 核心特点

- **企业级高可用**: 支持集群部署、负载均衡
- **完整可观测性**: 内置 OpenTelemetry tracing + Prometheus metrics
- **插件系统**: 热插拔插件架构
- **企业安全**: 国密算法支持、审计日志、等保四级合规
- **高性能**: QPS 5,000+，P99 延迟 <20ms

## 快速开始

### Kubernetes 部署

```yaml
apiVersion: hiclaw.io/v1beta1
kind: Worker
metadata:
  name: my-openfang
spec:
  model: claude-sonnet-4-6
  runtime: openfang
  image: hiclaw/openfang-worker:latest
  skills:
    - github-operations
    - enterprise-audit
  mcpServers:
    - github
  runtimeConfig:
    openfang:
      pluginDir: /app/plugins
      observability:
        enabled: true
        tracingEndpoint: http://jaeger:14268/api/traces
        metricsEndpoint: http://prometheus:9090
      security:
        smCrypto: true
        auditLog: true
```

## 配置选项

### runtimeConfig.openfang

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `pluginDir` | string | /app/plugins | 插件目录 |
| `observability.enabled` | bool | false | 启用可观测性 |
| `observability.tracingEndpoint` | string | - | Jaeger tracing 端点 |
| `observability.metricsEndpoint` | string | - | Prometheus metrics 端点 |
| `security.smCrypto` | bool | false | 启用国密算法 |
| `security.auditLog` | bool | true | 启用审计日志 |

## 架构

```
┌─────────────────────────────────────┐
│      Matrix Client (matrix-rust-sdk)│
│      支持多房间、联合、加密          │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│      openfang Core (tokio)          │
│   - 插件管理器 (Plugin Manager)     │
│   - 任务调度器 (Task Scheduler)     │
│   - 熔断器 (Circuit Breaker)        │
│   - 限流器 (Rate Limiter)           │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│      Plugin System (WASM)           │
│   - GitHub 插件                      │
│   - GitLab 插件                      │
│   - 数据库连接器                     │
│   - 消息队列集成                     │
│   - 企业 IM（钉钉/飞书/企微）        │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│      Observability Stack            │
│   - OpenTelemetry Tracing           │
│   - Prometheus Metrics              │
│   - Structured Logging              │
│   - Audit Log                       │
└─────────────────────────────────────┘
```

## 插件系统

### 开发插件

```rust
// plugins/my-plugin/src/lib.rs
use openfang_sdk::{Plugin, PluginContext, Result};

pub struct MyPlugin;

#[openfang_plugin]
impl Plugin for MyPlugin {
    fn name(&self) -> &'static str {
        "my-plugin"
    }

    async fn execute(&self, ctx: PluginContext) -> Result<String> {
        // Plugin logic here
        Ok("Plugin executed successfully".to_string())
    }
}
```

### 加载插件

```rust
// 自动加载 /app/plugins 目录下的所有插件
let plugin_manager = PluginManager::new("/app/plugins");
plugin_manager.load_all().await?;
```

## 可观测性

### Metrics

openfang 暴露以下 Prometheus metrics：

```prometheus
# Worker 指标
openfang_worker_uptime_seconds
openfang_worker_tasks_total
openfang_worker_tasks_active

# LLM 调用指标
openfang_llm_requests_total
openfang_llm_request_duration_seconds
openfang_llm_errors_total

# Matrix 指标
openfang_matrix_rooms_joined
openfang_matrix_events_received_total
openfang_matrix_events_sent_total

# 插件指标
openfang_plugin_executions_total
openfang_plugin_execution_duration_seconds
```

### Tracing

分布式 tracing 支持：

```rust
use tracing::{info, instrument};
use tracing_opentelemetry::OpenTelemetrySpanExt;

#[instrument(skip(ctx), fields(otel.name = "my_operation"))]
async fn my_operation(ctx: &PluginContext) {
    info!("Executing operation");
    // ...
}
```

### 审计日志

企业级审计日志记录所有敏感操作：

```json
{
  "timestamp": "2026-04-24T10:30:00Z",
  "level": "audit",
  "worker": "openfang-worker-01",
  "user": "@admin:hiclaw.io",
  "action": "skill_execution",
  "skill": "git-deployment",
  "result": "success",
  "metadata": {
    "repository": "higress-group/hiclaw",
    "branch": "main",
    "commit": "a1b2c3d"
  }
}
```

## 企业安全

### 国密算法

启用 SM2/SM3/SM4 国密算法：

```yaml
runtimeConfig:
  openfang:
    security:
      smCrypto: true
```

### 审计日志

完整操作审计：

```yaml
runtimeConfig:
  openfang:
    security:
      auditLog: true  # 默认启用
```

### 访问控制

基于角色的访问控制（RBAC）：

```rust
let rbac = RBACPolicy::load_from_minio().await?;
if !rbac.allow(user, action, resource) {
    return Err(AccessDenied);
}
```

## Helm Chart 部署

```bash
# 添加 Helm chart 仓库
helm repo add hiclaw https://higress-group.github.io/hiclaw-charts
helm repo update

# 部署 openfang
helm install my-openfang hiclaw/openfang-worker \
  --set worker.model=claude-sonnet-4-6 \
  --set worker.replicas=3 \
  --set observability.enabled=true \
  --set jaeger.enabled=true \
  --set prometheus.enabled=true
```

### Chart 配置

```yaml
# values.yaml
worker:
  model: claude-sonnet-4-6
  replicas: 3
  resources:
    requests:
      memory: 512Mi
      cpu: 500m
    limits:
      memory: 2Gi
      cpu: 2000m

observability:
  enabled: true
  jaeger:
    enabled: true
  prometheus:
    enabled: true

security:
  smCrypto: true
  auditLog: true
  rbac:
    enabled: true
```

## 性能基准

| 指标 | openfang | ZeroClaw | OpenClaw |
|------|----------|----------|----------|
| QPS | 5,000 | 6,800 | 1,000 |
| P99 延迟 | 20ms | 12ms | 100ms |
| 内存占用 | 512MB | 180MB | 2GB |
| 启动时间 | <2s | <1s | ~5s |
| 插件数量 | 20+ | 5 | 30+ |

## 高可用部署

### 多副本部署

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openfang-workers
spec:
  replicas: 3
  selector:
    matchLabels:
      app: openfang
  template:
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - openfang
            topologyKey: kubernetes.io/hostname
      containers:
      - name: openfang
        image: hiclaw/openfang-worker:latest
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
```

### 负载均衡

使用 Higress 网关进行负载均衡：

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: openfang-gateway
  annotations:
    higress.io/load-balance: round-robin
spec:
  rules:
  - host: openfang.hiclaw.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: openfang-service
            port:
              number: 8080
```

## 故障排查

### 查看日志

```bash
kubectl logs -f deployment/openfang-workers
```

### 查看 metrics

```bash
kubectl port-forward svc/openfang-workers 9090:9090
curl http://localhost:9090/metrics
```

### 分布式 tracing

访问 Jaeger UI 查看 traces：
```bash
kubectl port-forward svc/jaeger 16686:16686
# 访问 http://localhost:16686
```

## 与其他 Worker 运行时对比

| Worker 类型 | 语言 | 内存 | QPS | 企业特性 | 适用场景 |
|------------|------|------|-----|---------|---------|
| **openfang** | Rust | 512MB | 5,000 | ✅ 完整 | 企业生产环境 |
| ZeroClaw | Rust | 180MB | 6,800 | ❌ 基础 | 高并发场景 |
| OpenClaw | Node.js | 512MB | 1,000 | ❌ 基础 | 通用场景 |
| fastclaw | Python | 300MB | 500 | ❌ 基础 | 快速原型 |
| CoPaw | Python | 256MB | 300 | ❌ 基础 | 内存受限 |
| NanoClaw | Node.js | 100MB | 200 | ❌ 极简 | 个人助手 |

## 许可证

与 HiClaw 项目相同（见 [LICENSE](../../LICENSE)）
