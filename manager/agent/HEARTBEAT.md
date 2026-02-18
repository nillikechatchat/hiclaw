## Manager Heartbeat Checklist

### 1. 任务状态扫描与 Worker 问询

扫描 ~/hiclaw-fs/shared/tasks/ 下所有任务目录的 meta.json：

```bash
for meta in ~/hiclaw-fs/shared/tasks/*/meta.json; do
  cat "$meta"
done
```

- 筛选 `"status": "assigned"` 的任务（进行中、尚未完成）
- 从 meta.json 的 `assigned_to` 和 `room_id` 字段获取负责的 Worker 及对应 Room
- 对这些 Worker：
  - 在该 Worker 的 Room 中询问："你当前的任务进展如何？有没有遇到阻塞？"
  - （人类管理员在 Room 中全程可见，可随时补充指令或纠正）
  - 根据 Worker 回复判断是否正常推进
- 如果 Worker 未回复（超过一个 heartbeat 周期无响应），在 Room 中标记异常并提醒人类管理员
- 如果 Worker 已回复完成但 meta.json 未更新，主动更新 meta.json：status → completed，填写 completed_at

### 2. 凭证检查
- 检查各 Worker 凭证是否即将过期
- 如需轮转，执行双凭证滑动窗口轮转流程

### 3. 容量评估
- 统计 `"status": "assigned"` 的任务数量（进行中）和没有分配任务的空闲 Worker
- 如果 Worker 不足，准备创建命令给人类管理员
- 如果有 Worker 空闲，建议重新分配任务

### 4. 回复
- 如果所有 Worker 正常且无待处理事项：HEARTBEAT_OK
- 否则：汇总发现和建议的操作，通知人类管理员
