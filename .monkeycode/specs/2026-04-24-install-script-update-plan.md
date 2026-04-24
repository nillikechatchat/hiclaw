# 一键安装脚本更新计划

需要更新的文件：
- `/workspace/install/hiclaw-install.sh`
- `/workspace/install/hiclaw-install.ps1` (Windows PowerShell)

## 需要更新的内容

### 1. 新增 Runtime 选项

在当前 `step_runtime()` 函数中，将选项从 2 个扩展到 6 个：

```bash
# 当前代码 (约 1860 行)
echo "  1) OpenClaw（Node.js 容器，~500MB 内存）"
echo "  2) CoPaw（Python 容器，~150MB 内存）"

# 更新为
echo "  1) OpenClaw（Node.js 容器，~500MB 内存）"
echo "  2) CoPaw（Python 容器，~150MB 内存）"
echo "  3) fastclaw（Python 轻量级，~300MB 内存，快速原型）"
echo "  4) ZeroClaw（Rust 高性能，~180MB 内存，QPS 6800+）"
echo "  5) NanoClaw（Node.js 极简，~100MB 内存，~500 行代码）"
echo "  6) openfang（Rust 企业级，~512MB 内存，插件系统）"
```

### 2. 更新环境变量

在文件顶部注释中添加：
```bash
#   HICLAW_DEFAULT_WORKER_RUNTIME  Default worker runtime (openclaw|copaw|fastclaw|zeroclaw|nanoclaw|openfang)
```

### 3. 更新镜像选择逻辑

在 `step_install_images()` 函数中 (约 2000 行)：

```bash
step_install_images() {
    case "${HICLAW_DEFAULT_WORKER_RUNTIME}" in
        copaw)
            WORKER_IMAGE="${HICLAW_REGISTRY}/higress/hiclaw-copaw-worker:${HICLAW_VERSION}"
            ;;
        fastclaw)
            WORKER_IMAGE="${HICLAW_REGISTRY}/higress/hiclaw-fastclaw-worker:${HICLAW_VERSION}"
            ;;
        zeroclaw)
            WORKER_IMAGE="${HICLAW_REGISTRY}/higress/hiclaw-zeroclaw-worker:${HICLAW_VERSION}"
            ;;
        nanoclaw)
            WORKER_IMAGE="${HICLAW_REGISTRY}/higress/hiclaw-nanoclaw-worker:${HICLAW_VERSION}"
            ;;
        openfang)
            WORKER_IMAGE="${HICLAW_REGISTRY}/higress/hiclaw-openfang-worker:${HICLAW_VERSION}"
            ;;
        *)
            WORKER_IMAGE="${HICLAW_REGISTRY}/higress/hiclaw-worker:${HICLAW_VERSION}"  # openclaw
            ;;
    esac
}
```

### 4. 更新消息提示

在 `msg()` 函数中添加新 runtime 的翻译：

```bash
"worker_runtime.fastclaw.zh") text="fastclaw（Python 轻量级，~300MB 内存，快速原型）" ;;
"worker_runtime.fastclaw.en") text="fastclaw (Python lightweight, ~300MB RAM, fast prototyping)" ;;
"worker_runtime.zeroclaw.zh") text="ZeroClaw（Rust 高性能，~180MB 内存，QPS 6800+）" ;;
"worker_runtime.zeroclaw.en") text="ZeroClaw (Rust high-performance, ~180MB RAM, QPS 6800+)" ;;
"worker_runtime.nanoclaw.zh") text="NanoClaw（Node.js 极简，~100MB 内存）" ;;
"worker_runtime.nanoclaw.en") text="NanoClaw (Node.js minimal, ~100MB RAM)" ;;
"worker_runtime.openfang.zh") text="openfang（Rust 企业级，~512MB 内存，插件系统）" ;;
"worker_runtime.openfang.en") text="openfang (Rust enterprise, ~512MB RAM, plugin system)" ;;
```

### 5. 更新 Windows PowerShell 脚本

同步更新 `hiclaw-install.ps1` 中的对应部分。

## 实施建议

**注意**：这些修改应该在单独的 Pull Request 中进行，因为：
1. 不影响核心功能（现有 openclaw/copaw 仍然可用）
2. 需要先发布新的 Docker 镜像
3. 方便回滚和测试

## 临时方案

在脚本更新之前，用户可以通过环境变量手动指定新 runtime：

```bash
# 使用 fastclaw
HICLAW_DEFAULT_WORKER_RUNTIME=fastclaw ./hiclaw-install.sh

# 使用 ZeroClaw
HICLAW_DEFAULT_WORKER_RUNTIME=zeroclaw ./hiclaw-install.sh

# 使用 NanoClaw
HICLAW_DEFAULT_WORKER_RUNTIME=nanoclaw ./hiclaw-install.sh

# 使用 openfang
HICLAW_DEFAULT_WORKER_RUNTIME=openfang ./hiclaw-install.sh
```

然后手动指定镜像：
```bash
export HICLAW_INSTALL_WORKER_IMAGE=hiclaw/fastclaw-worker:latest
# 或其他 runtime 的镜像
```
