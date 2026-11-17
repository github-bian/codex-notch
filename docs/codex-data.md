# Codex 本地数据：实测字段

本文记录的是**在一台真实机器上验证过的**结构（2026-11，Codex CLI + 桌面版），
以及重新核对的方法。Codex 的内部格式会变，改解析器前先按文末步骤复验。

## 1. 会话 rollout

路径：`~/.codex/sessions/<YYYY>/<MM>/<DD>/rollout-<ISO8601>-<uuid>.jsonl`
（`CODEX_HOME` 会覆盖根目录；归档会话在 `archived_sessions/`，不参与实时读取。）

每行一个 JSON 对象，事件在 `payload.type`。

### `token_count`

```json
{
  "timestamp": "...",
  "type": "event_msg",
  "payload": {
    "type": "token_count",
    "info": {
      "total_token_usage": { "input_tokens": 0, "cached_input_tokens": 0,
                             "cache_write_input_tokens": 0, "output_tokens": 0,
                             "reasoning_output_tokens": 0, "total_tokens": 0 },
      "last_token_usage": { "...": "同上" },
      "last_usage_includes_reasoning": true,
      "model_context_window": 258400
    },
    "rate_limits": {
      "limit_id": "codex",
      "plan_type": "prolite",
      "primary": { "used_percent": 65.0, "window_minutes": 10080, "resets_at": 1763... },
      "secondary": null,
      "credits": { "has_credits": true, "unlimited": false, "balance": "0" }
    }
  }
}
```

约定：

- `info.total_token_usage.total_tokens` 是**会话累计**，不是本轮。
- 上下文占用取 `info.last_token_usage.input_tokens`（已含缓存命中部分，**不要再加**
  `cached_input_tokens`），分母是 `info.model_context_window`。
- `rate_limits.primary.window_minutes` 可能是 `300`（5 小时）或 `10080`（7 天），
  取决于账号与时间点；`secondary` 可能为 `null`。
- `rate_limits` 在部分版本/平台上会整体为 `null`（[openai/codex#14880](https://github.com/openai/codex/issues/14880)）。
  解析器因此把额度当作可缺失字段，UI 在缺失时只显示 token 与上下文。

### 生命周期

- `payload.type == "task_started"`：`turn_id`、`started_at`（epoch 秒）、`model_context_window`
- `payload.type == "task_complete"`：`turn_id`、`duration_ms`、`started_at`、`completed_at`
- `payload.type == "turn_aborted"`：本轮中止
- `payload.type == "thread_settings_applied"`：工作目录在
  `payload.thread_settings.cwd`（**不在** payload 根上）

## 2. `notify` 回调

`~/.codex/config.toml`：

```toml
notify = ["/path/to/codexnotch-hook"]
```

Codex 会以命令 + 参数的形式调用，payload 是 JSON（形如 `agent-turn-complete`，
带 `thread-id`、`turn-id`、`cwd`、`input-messages`）。部分版本把 payload 放 stdin，
所以 `codexnotch-hook` 同时接受 argv 与 stdin。

TUI 侧还有 `[tui] notifications = ["agent-turn-complete", "approval-requested"]`
这类过滤配置；审批请求走它才能实时到达。

## 3. 复验方法（只看结构，不看内容）

```bash
# 找最新 rollout
ls -t ~/.codex/sessions/*/*/*/rollout-*.jsonl | head -1

# 只打印事件类型分布与字段名，不打印正文
python3 - <<'PY'
import json, collections, os, glob
path = max(glob.glob(os.path.expanduser('~/.codex/sessions/**/rollout-*.jsonl'), recursive=True),
           key=os.path.getmtime)
counts, shapes = collections.Counter(), {}
for line in open(path, encoding='utf-8', errors='replace'):
    try: obj = json.loads(line)
    except Exception: continue
    p = obj.get('payload') or {}
    t = p.get('type')
    if not isinstance(t, str): continue
    counts[t] += 1
    shapes.setdefault(t, sorted(p.keys()))
print(dict(counts))
for k, v in shapes.items(): print(k, v)
PY
```

修改解析器时，把新结构补进 `Sources/CodexNotchCore/RolloutParser.swift` 的检查用例
（`Sources/CodexNotchCoreTests/main.swift`），不要只改代码。

## 4. 红线

- **不读** `~/.codex/auth.json` 的内容（凭证）。
- **不记录** 会话正文、提示词、回答。
- 只读、只在本机、不联网。
