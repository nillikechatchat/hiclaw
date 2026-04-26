# fastclaw - 轻量级 Python AI Agent Worker

fastclaw 是 HiClaw 平台的轻量级 Python AI Agent Worker 运行时，专为快速原型开发和 Python 生态集成而设计。

## 核心特点

- **轻量级**: 仅 ~300MB 内存占用
- **Python 原生**: 基于 Python 3.11，易于集成 Python 生态
- **快速启动**: 冷启动时间 <5 秒
- **易于定制**: 简洁的代码结构，便于扩展
- **完全兼容**: 支持 HiClaw 平台的 Matrix 通信、MinIO 文件同步、Higress 网关

## 快速开始

### 使用 Kubernetes CRD 创建 fastclaw Worker

```yaml
apiVersion: hiclaw.io/v1beta1
kind: Worker
metadata:
  name: my-fastclaw
spec:
  model: claude-sonnet-4-6
  runtime: fastclaw
  image: hiclaw/fastclaw-worker:latest
  skills:
    - github-operations
    - git-delegation
  mcpServers:
    - github
  runtimeConfig:
    fastclaw:
      pythonVersion: "3.11"
      sdk: "claude"
```

### 应用配置

```bash
# 使用 hiclaw CLI 创建
hiclaw apply -f my-fastclaw.yaml

# 或直接使用 kubectl
kubectl apply -f my-fastclaw.yaml
```

## 配置选项

### runtimeConfig.fastclaw

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `pythonVersion` | string | "3.11" | Python 版本，支持 "3.11" 或 "3.12" |
| `sdk` | string | "claude" | LLM SDK 选择，支持 "claude" 或 "openai" |

## 环境变量

fastclaw Worker 支持以下环境变量：

| 变量 | 必需 | 默认值 | 说明 |
|------|------|--------|------|
| `WORKER_NAME` | 是 | - | Worker 名称 |
| `LLM_MODEL` | 是 | - | LLM 模型 ID |
| `RUNTIME_CONFIG` | 否 | {} | Runtime 配置（JSON 字符串） |
| `HICLAW_WORKSPACE_DIR` | 否 | /root/fastclaw-workspace | 工作空间目录 |
| `MINIO_FS_DIR` | 否 | /root/hiclaw-fs | MinIO 文件系统目录 |
| `LOG_LEVEL` | 否 | INFO | 日志级别 |

## 本地开发

### 构建 Docker 镜像

```bash
docker build -t hiclaw/fastclaw-worker:latest .
```

### 本地运行测试

```bash
# 设置环境变量
export WORKER_NAME=test-worker
export LLM_MODEL=claude-sonnet-4-6
export RUNTIME_CONFIG='{"fastclaw":{"sdk":"claude"}}'

# 运行容器
docker run --rm -it \
  -e WORKER_NAME=test-worker \
  -e LLM_MODEL=claude-sonnet-4-6 \
  hiclaw/fastclaw-worker:latest
```

## 技能开发

fastclaw 使用与 OpenClaw 相同的技能系统。在 `skills/` 目录下创建技能：

```
skills/
└── my-custom-skill/
    ├── SKILL.md          # 技能说明文档
    └── my_skill.py       # Python 实现
```

### SKILL.md 示例

```markdown
# my-custom-skill

使用此技能来执行自定义任务。

## 命令

```bash
python3 /app/skills/my-custom-skill/my_skill.py <arguments>
```

## 示例

```python
# Python 代码示例
```
```

## 与 Higress 集成

fastclaw 通过 Higress 网关访问 LLM 和 MCP 服务：

1. **LLM 访问**: 使用 Consumer Token 认证，通过 Higress 代理调用 LLM API
2. **MCP 服务**: 通过 Higress 访问 MCP Servers（如 GitHub、文件系统等）

## 性能指标

| 指标 | 值 |
|------|-----|
| 内存占用 | ~300MB |
| 冷启动时间 | <5 秒 |
| 消息延迟 (P50) | ~100ms |
| 消息延迟 (P99) | ~500ms |

## 与其他 Worker 运行时对比

| Worker 类型 | 语言 | 内存 | 适用场景 |
|------------|------|------|---------|
| **fastclaw** | Python | 300MB | 快速原型、Python 生态 |
| OpenClaw | Node.js | 512MB | 通用场景、完整功能 |
| CoPaw | Python | 256MB | 内存受限场景 |
| ZeroClaw | Rust | 180MB | 高并发、高性能 |
| NanoClaw | Node.js | 100MB | 极简个人助手 |
| openfang | Rust | 512MB | 企业级生产环境 |

## 故障排查

### 查看日志

```bash
kubectl logs -f worker/my-fastclaw
```

### 健康检查

```bash
kubectl exec -it worker/my-fastclaw -- curl localhost:8080/healthz
```

### 常见问题

**Worker 无法启动**
- 检查环境变量是否正确设置
- 确保 MinIO 文件系统可访问
- 查看日志了解详细错误

**无法连接 Matrix**
- 检查 openclaw.json 配置是否正确
- 验证 Tuwunel 服务器是否运行
- 检查网络连接

## 贡献

欢迎贡献代码！请参考：
- 项目根目录的 [CONTRIBUTING.md](../../CONTRIBUTING.md)
- HiClaw 架构文档 [docs/architecture.md](../../docs/architecture.md)

## 许可证

与 HiClaw 项目相同（见 [LICENSE](../../LICENSE)）
