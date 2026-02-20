## Manager Heartbeat Checklist

### 1. 读取 state.json

从本地读取 state.json（如未同步，先 mc cp 拉取）：

```bash
mc cp hiclaw/hiclaw-storage/agents/manager/state.json ~/hiclaw-fs/agents/manager/state.json 2>/dev/null || true
cat ~/hiclaw-fs/agents/manager/state.json
```

state.json 的 `active_tasks` 包含所有进行中的任务（有限任务和无限任务）。无需遍历所有 meta.json。

---

### 2. 有限任务状态询问

遍历 `active_tasks` 中 `"type": "finite"` 的条目：

- 从条目的 `assigned_to` 和 `room_id` 字段获取负责的 Worker 及对应 Room
- 在该 Worker 的 Room（或 project_room_id 若有）中 @mention Worker 询问进展：
  ```
  @{worker}:{domain} 你当前的任务 {task-id} 进展如何？有没有遇到阻塞？
  ```
- 根据 Worker 回复判断是否正常推进
- 如果 Worker 未回复（超过一个 heartbeat 周期无响应），在 Room 中标记异常并提醒人类管理员
- 如果 Worker 已回复完成但 meta.json 未更新，主动更新 meta.json（status → completed，填写 completed_at），并从 state.json 的 `active_tasks` 中删除该条目

---

### 3. 无限任务超时检查

遍历 `active_tasks` 中 `"type": "infinite"` 的条目，对每个条目：

```
当前时间 UTC = now

判断条件（同时满足）：
  1. last_executed_at < next_scheduled_at（本轮尚未执行）
     或 last_executed_at 为 null（从未执行）
  2. now > next_scheduled_at + 30分钟（已超时未执行）

若满足，在对应 room_id 中 @mention Worker 触发执行：
  @{worker}:{domain} 该执行你的定时任务 {task-id}「{task-title}」了，请现在执行并用 "executed" 关键字汇报。
```

**注意**：无限任务永不从 active_tasks 中删除。Worker 汇报 `executed` 后，Manager 更新 `last_executed_at` 和 `next_scheduled_at`，然后 mc cp 同步 state.json。

---

### 4. 项目进展监控

扫描 ~/hiclaw-fs/shared/projects/ 下所有活跃项目的 plan.md：

```bash
for meta in ~/hiclaw-fs/shared/projects/*/meta.json; do
  cat "$meta"
done
```

- 筛选 `"status": "active"` 的项目
- 对每个活跃项目，读取 plan.md，找出标记为 `[~]`（进行中）的任务
- 若该 Worker 在本 heartbeat 周期内没有活动，在项目群中 @mention：
  ```
  @{worker}:{domain} 你正在执行的任务 {task-id}「{title}」有进展吗？有遇到阻塞请告知。
  ```
- 如果项目群中有 Worker 汇报了任务完成但 plan.md 还没更新，立即处理（见 AGENTS.md 项目管理部分）

---

### 5. 凭证检查

- 检查各 Worker 凭证是否即将过期
- 如需轮转，执行双凭证滑动窗口轮转流程

---

### 6. 容量评估

- 统计 state.json 中 type=finite 的条目数（有限任务进行中数量）和没有分配任务的空闲 Worker
- 如果 Worker 不足，准备创建命令给人类管理员
- 如果有 Worker 空闲，建议重新分配任务

---

### 7. 回复

- 如果所有 Worker 正常且无待处理事项：HEARTBEAT_OK
- 否则：汇总发现和建议的操作，通知人类管理员
