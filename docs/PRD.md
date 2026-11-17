# Codex Notch 落地需求文档（PRD）

| 项 | 内容 |
| --- | --- |
| 版本 | v1.0（草案，待评审） |
| 日期 | 2026-11-17 |
| 对应仓库 | `github-bian/codex-notch`（本地：`/Users/tiiny123/Desktop/03-项目/project/codex-notch`） |
| 当前代码版本 | `0.1.0` 骨架，commit `4f8ebf8` |
| 关联文档 | [docs/codex-data.md](codex-data.md)（实测数据字段与复验方法） |
| 状态图例 | ✅ 已实现并验证　🟡 已实现未验证 / 部分　⬜ 未开始 |

> 本文是**决策与验收的依据**，不是功能宣传。所有“已验证”都指在本机（macOS 26.3、Apple Silicon、外接显示器）实际跑通；
> 所有“未验证”都写明缺什么条件。改动需求时先改本文，再改代码。

---

## 1. 背景与定位

### 1.1 问题

Codex 在后台跑任务时，用户需要反复切窗口或看终端才能回答三个问题：

1. 额度还剩多少？下一次重置是几点？
2. 当前这一轮在跑什么？跑多久了？
3. 这轮烧了多少 token？上下文还剩多少？

这三个问题都“一眼就能答”，但都需要切走当前工作。macOS 的刘海是一块**零占位、常驻可见、不打断焦点**的区域，正适合承载这种“瞄一眼”的信息。

### 1.2 现有资产

作者已有 [codex-touchbar-usage](https://github.com/github-bian/codex-touchbar-usage)：把额度、重置倒计时、最近对话放到 Touch Bar。它验证了两件事：

- Codex 的本地数据足以支撑这类展示；
- 原生 Swift UI + 本地只读数据这条路可行。

但它有三个结构性限制：Touch Bar 只存在于 2016–2021 款 MacBook Pro；状态靠本地事件“推测”；安装包临时签名、未公证。

### 1.3 定位（一句话）

**Codex 专属的刘海仪表盘**：只看 Codex，只答上面三个问题，外加“一键回到 Codex”。

### 1.4 竞品与差异

| 项目 | 定位 | 对本项目的含义 |
| --- | --- | --- |
| [BoringNotch](https://github.com/TheBoredTeam/boring.notch)（8.4k，GPL-3.0） | 通用刘海工具（媒体、文件架、日历） | 不抄代码（GPL 传染），只借鉴交互 |
| [Atoll](https://github.com/)（1.7k，开源） | 通用刘海工具 | 同上 |
| [AgentNotch](https://github.com/mattBonfanti/AgentNotch) | Claude Code / Codex / OpenCode 的通用 agent 状态 | **最直接竞品**；不做“又一个 agent 状态灯” |
| [notch-island-tools](https://github.com/ChenSiWu/notch-island-tools) | 赛道索引 | 冷启动时提交收录 |

**差异点（必须体现在产品里）**：

1. **数据深度**：token 累计、上下文占用、额度双窗口、重置时刻——不是“一个状态点”。
2. **事件驱动**：用 Codex `notify` 拿到真实回合事件，而不是纯轮询猜测。
3. **Codex 原生**：直接落到 `codex://` 会话，不做通用抽象。

---

## 2. 目标与非目标

### 2.1 v1 目标

| 编号 | 目标 | 衡量方式 |
| --- | --- | --- |
| G1 | 用户不切窗口即可判断“要不要现在去处理 Codex” | 3 秒内读出：在跑/等待/完成/失败 + 额度 |
| G2 | 静止时不产生任何视觉噪音 | 无任务时岛面占用 0 像素（透明） |
| G3 | 常驻开销可忽略 | CPU < 1%（空闲）、内存 < 60 MB、无网络请求 |
| G4 | 零配置可用 | 不配 hook 也能显示状态与 token |
| G5 | 可被他人复现构建 | `git clone` + 一个脚本 → 可运行 `.app` |

### 2.2 非目标（v1 明确不做）

- ❌ 不做多 agent（Claude Code / OpenCode / Cursor）——只做 Codex。
- ❌ 不做通用刘海工具（媒体控制、文件架、日历、电池）。
- ❌ 不修改 Codex 行为、不代理请求、不注入提示词。
- ❌ 不做云同步、账号体系、用量上报。
- ❌ 不做 App Store 上架（需要读 `~/.codex`，与沙盒模型冲突）。
- ❌ 不在 v1 做“自动替用户批准命令”之外的自动化决策。

### 2.3 成功指标（开源项目口径）

不追 stars。看三个信号：

- 安装后 7 天仍在运行的比例（可选匿名本地统计，默认关闭）；
- 因“数据解析失效”产生的 issue 占比 < 20%；
- 从 clone 到看到岛面的步骤数 ≤ 3。

---

## 3. 用户与场景

**Persona**：每天用 Codex CLI/桌面版写代码、常驻 macOS、外接显示器或内置刘海屏、关心额度与上下文。

| 编号 | 场景 | 期望行为 |
| --- | --- | --- |
| S1 | 发出指令后切去写别的 | 刘海出现“运行中”与项目名，不抢焦点 |
| S2 | 想知道还能用多久 | 右翼显示额度百分比；悬停显示重置倒计时 |
| S3 | Codex 在等审批 | 状态变青、卡片显示“等待审批”，可选桌面通知 |
| S4 | 任务完成 | 变绿 8 秒后自动消失；点击可回到会话 |
| S5 | 任务失败 | 变红 15 秒，卡片显示错误摘要 |
| S6 | 合盖接外接屏 / 无刘海 Mac | 降级为菜单栏下方悬浮胶囊，不遮挡应用菜单 |
| S7 | 同时跑多个会话 | v1 跟随最近写入的会话；v2 提供多会话列表 |
| S8 | 额度快用完 | 百分比变橙（≥70%）/ 变红（≥90%） |

---

## 4. 产品需求

### 4.1 信息架构

```
刘海两翼（收起态）      展开卡（悬停 / 钉住）        菜单栏图标
├─ 左翼：状态点 + 标题    ├─ 头部：状态点 + 标题 + Open  ├─ Open Codex
├─ 右翼：额度% + token    ├─ 额度条 + 重置倒计时         ├─ Copy hook config
                         ├─ 上下文条                  ├─ Reveal data folder
                         ├─ 总计 token + 计时          └─ Quit
                         └─ 底部提示
```

### 4.2 状态机

| 状态 | 语义 | 进入条件 | 呈现 | 退出 |
| --- | --- | --- | --- | --- |
| `idle` | 没有活动任务 | 初始 / 中止 / 完成后超时 | 收起翼隐藏（全透明） | 任意新事件 |
| `running` | 正在执行 | `task_started` / `agent-turn-start` / 首次 `token_count` | 橙色点 + 标题 | 完成 / 失败 / 中止 |
| `waiting` | 等待人处理 | `approval-requested` | 青色点 + “等待审批” | 回合继续 / 完成 |
| `done` | 正常结束 | `task_complete` / `agent-turn-complete` | 绿色点 | 8 秒后回 `idle` |
| `error` | 失败 | `error` / `agent-error` / 连续解析失败 | 红色点 + 摘要 | 15 秒后回 `idle` |

**规则**

- R-4.2.1：`done` / `error` 的自动消失计时在“钉住”或“展开中”时暂停，收起后重新计时。
- R-4.2.2：新回合开始必须取消未触发的消失计时。
- R-4.2.3：`idle` 时收起翼不渲染；但悬停仍可展开（用于查看额度）。
- R-4.2.4：状态只由事件驱动，不根据文件时间戳“猜”。

### 4.3 收起态（FR-C）

| 编号 | 需求 | 优先级 | 状态 |
| --- | --- | --- | --- |
| FR-C1 | 有刘海时，信息挂在刘海两侧（两翼各 96pt），中间留给刘海，不遮挡 | P0 | 🟡 未实机验证 |
| FR-C2 | 左翼 = 状态点（6pt）+ 标题（项目名/会话名），超长省略 | P0 | ✅ |
| FR-C3 | 右翼 = 额度百分比（保留整数）+ token 数（紧凑格式） | P0 | ✅ |
| FR-C4 | 无任务时完全隐藏（0 像素） | P0 | ✅ |
| FR-C5 | 额度用尽风险：≥70% 橙色，≥90% 红色 | P1 | ✅ |
| FR-C6 | 完成后短暂显示绿色 ✓，再隐藏 | P0 | ✅ |
| FR-C7 | token 格式：<1k 原样；<100k 一位小数（12.3k）；≥100k 取整（128k）；≥1M（2.5M） | P1 | ✅ |
| FR-C8 | 刘海高度 = 菜单栏高度（`safeAreaInsets.top`），下限 24pt | P0 | 🟡 |

### 4.4 展开态（FR-E）

| 编号 | 需求 | 优先级 | 状态 |
| --- | --- | --- | --- |
| FR-E1 | 尺寸 420×236（可随屏宽收缩，最小 320，屏幕边距 ≥ 8pt） | P0 | ✅ |
| FR-E2 | 面板顶部对齐屏幕顶边，水平居中 | P0 | ✅ |
| FR-E3 | 额度区：使用率进度条 + 剩余百分比 + 窗口类型 + 重置倒计时 | P0 | ✅ |
| FR-E4 | 上下文区：已用/窗口（如 `42k / 258k`）+ 进度条 | P0 | ✅ |
| FR-E5 | **双额度窗口**：5 小时窗口与每周窗口同时展示（v1.1） | P1 | ⬜ |
| FR-E6 | 总量区：本会话累计 token + 运行时长 | P0 | ✅ |
| FR-E7 | 操作区：Open（`codex://`）+ 关闭（×） | P0 | ✅ |
| FR-E8 | 多会话列表：展开时按优先级列出多个会话，点击切换（v1.2） | P1 | ⬜ |
| FR-E9 | 空数据降级：没有额度就不渲染额度区，不留空行 | P0 | ✅ |
| FR-E10 | 底部提示说明交互（可随本地化） | P2 | ✅ |

### 4.5 交互（FR-I）

| 编号 | 需求 | 参数 | 状态 |
| --- | --- | --- | --- |
| FR-I1 | 鼠标进入岛面（含 3pt 容差）→ 短暂延迟后展开 | 180ms | ✅ |
| FR-I2 | 鼠标离开 → 延迟收起（钉住时不收） | 320ms | ✅ |
| FR-I3 | 点击收起翼 → 钉住展开；再次点击 → 取消钉住 | — | ✅ |
| FR-I4 | 点击卡片背景不收起（避免误触），只有 × 收起 | — | ✅ |
| FR-I5 | 岛面永不抢键盘焦点（点它不能导致编辑器失焦） | 硬性 | 🟡 代码已保证，未实机验证 |
| FR-I6 | 展开/收起有动效（spring），Reduce Motion 时退化为淡入淡出 | — | 🟡 动效有，Reduce Motion ⬜ |
| FR-I7 | 外接屏降级：面板在菜单栏下方 6pt，避免遮挡应用菜单 | — | ✅ |
| FR-I8 | 拖动/调整宽度（自定义岛面位置与宽度） | — | ⬜（v2，需持久化） |

### 4.6 动作（FR-A）

| 编号 | 需求 | 实现方式 | 状态 |
| --- | --- | --- | --- |
| FR-A1 | Open：打开 Codex | `NSWorkspace.open("codex://")` | ✅ |
| FR-A2 | Copy hook config：把 `notify = [...]` 复制到剪贴板 | NSPasteboard | ✅ |
| FR-A3 | Reveal data folder / Quit | 菜单项 | ✅ |
| FR-A4 | 点击卡片跳转到对应会话 | `codex://threads/<id>` | ⬜ 需 thread-id 绑定（见 Q1） |
| FR-A5 | **审批操作**：在岛上允许 / 拒绝 Codex 命令审批 | 需 app-server JSON-RPC（见 Q2） | ⬜ 高风险，需技术验证 |
| FR-A6 | 新建会话 / 切换会话 | 待定 | ⬜ |
| FR-A7 | 所有“会改变状态”的动作必须有确认或可撤销 | 产品红线 | ⬜ |

> A5 是本项目最大的功能风险：Codex 的审批语义属于安全边界，误点代价高。
> **在完成 Q2 技术验证并获得明确的写回协议之前，不实现 A5。**

### 4.7 多显示器与无刘海（FR-D）

| 编号 | 需求 | 状态 |
| --- | --- | --- |
| FR-D1 | 自动识别有刘海的屏幕：`safeAreaInsets.top > 0` 且左右翼宽度可算 | ✅ |
| FR-D2 | 刘海宽度 = 屏宽 − 左翼宽 − 右翼宽，理由：合理性校验（≥60pt、≤80% 屏宽），否则视为无刘海 | ✅ |
| FR-D3 | 无刘海时降级为 210×26 悬浮胶囊，位于菜单栏下方 | 🟡 代码已实现，本机即此路径 |
| FR-D4 | 多屏时只在一块屏显示（优先有刘海的屏，其次主屏） | ✅（单屏环境未验证多屏） |
| FR-D5 | 屏幕参数变化（插拔、分辨率、合盖）后重新定位 | ✅ |
| FR-D6 | 用户可指定显示器 | ⬜（v2） |

### 4.8 菜单栏与设置（FR-M）

| 编号 | 需求 | 状态 |
| --- | --- | --- |
| FR-M1 | 菜单栏常驻图标：Open / Copy hook / Reveal / Quit | ✅ |
| FR-M2 | 设置窗口：皮肤、音效、显示器、开关 | ⬜（v2） |
| FR-M3 | 首次启动引导：检测是否已配置 hook，一键复制 | ⬜（v1.1） |
| FR-M4 | 开机自启（SMAppService） | ⬜ |

### 4.9 调试能力（FR-DBG）

| 编号 | 需求 | 状态 |
| --- | --- | --- |
| FR-DBG1 | `--probe`：打印每块屏的刘海宽度、菜单栏高度、紧凑/展开窗框，然后退出 | ✅ |
| FR-DBG2 | `--demo`：假数据循环，用于调几何与动效 | ✅ |
| FR-DBG3 | `--self-test`：无界面跑解析与几何检查 | ✅（独立 runner） |
| FR-DBG4 | 日志：只在显式开启时写文件，默认不落盘内容 | ⬜ |

### 4.10 文案与本地化（FR-L）

| 编号 | 需求 | 状态 |
| --- | --- | --- |
| FR-L1 | 所有面向用户的文案集中管理，禁止散落硬编码 | ⬜ 当前为英文字面量 |
| FR-L2 | 中/英至少两套，跟随系统语言 | ⬜ |
| FR-L3 | 数字格式随 locale（token 千分位、时间） | ⬜ |

---

## 5. 数据需求

### 5.1 数据源矩阵

| 数据 | 来源 | 频率 | 可靠性 | 缺失时 |
| --- | --- | --- | --- | --- |
| 回合开始/结束 | rollout `task_started` / `task_complete` | 事件 | 高 | 用 hook 补 |
| 回合开始/结束（低延迟） | Codex `notify` → `events.jsonl` | 事件 | 中（需配置） | 退化为 rollout 轮询 |
| 累计 token | `token_count.info.total_token_usage.total_tokens` | 每轮多次 | 高 | 不显示 token |
| 上下文占用 | `token_count.info.last_token_usage.input_tokens` | 每轮多次 | 高 | 不显示上下文条 |
| 上下文窗口 | `info.model_context_window` | 每轮多次 | 高 | 不显示分母 |
| 额度使用率 | `rate_limits.primary.used_percent` | 每轮多次 | **中**（可能为 null） | 不显示额度 |
| 重置时刻 | `rate_limits.primary.resets_at`（epoch 秒） | 每轮多次 | 中 | 不显示倒计时 |
| 计划类型 | `rate_limits.plan_type` | 每轮多次 | 中 | 不显示 |
| 工作目录 | `thread_settings_applied.thread_settings.cwd` | 会话开始 | 高 | 不显示项目名 |
| 会话 ID | rollout 文件名 / hook `thread-id` | — | 高 | 无法跳转 |

### 5.2 已实测 schema

见 [docs/codex-data.md](codex-data.md)。核心字段（2026-11 实测）：

```json
{
  "payload": {
    "type": "token_count",
    "info": {
      "total_token_usage": { "total_tokens": 5418645 },
      "last_token_usage": { "input_tokens": 156281 },
      "model_context_window": 258400
    },
    "rate_limits": {
      "plan_type": "prolite",
      "primary": { "used_percent": 65.0, "window_minutes": 10080, "resets_at": 1763... }
    }
  }
}
```

**注意**

- `input_tokens` 已含缓存命中，**不能**再加 `cached_input_tokens`。
- `window_minutes` 实测出现 `10080`（7 天）与 `300`（5 小时）两种；UI 文案必须按分钟数动态生成（`7d / 5h / 45m`），不能硬编码“5h”。
- `rate_limits` 在部分版本/平台整体为 `null`（[openai/codex#14880](https://github.com/openai/codex/issues/14880)），必须按可缺失处理。
- 新版可能把 rollout 压成 `.jsonl.zst`，读取层需在 v1.1 支持（见 Q4）。

### 5.3 缺失与降级规则

| 缺失项 | 行为 |
| --- | --- |
| 没有 `~/.codex/sessions` | 岛面保持 `idle`，菜单栏给出一次性提示 |
| 最新 rollout 解析失败 | 保留上一帧快照，不清空；连续 3 次失败 → `error` 状态附“数据不可读” |
| 没有额度字段 | 只显示 token 与上下文；不显示占位符 |
| 没有 hook | 只走轮询；完成状态延迟 ≤ 1s（可接受） |
| 多个 rollout 同时更新 | 跟随最后修改者；v1.2 改为多会话列表 |

### 5.4 数据新鲜度

- 轮询：1s 一次，只读增量（字节偏移）。
- 重新定位最新文件：每 30s 一次。
- 快照超过 10 分钟无更新且状态为 `running` → 保留显示（可能长任务），但内部标记“可能已失联”。
- 超过 30 分钟无更新 → 视为 `idle`，避免幽灵任务。

---

## 6. 技术需求

### 6.1 进程与窗口模型

- **单进程**：一个 `.app`，两个可执行（主程序 + hook 转发器），不引入 Electron、不引入后台 daemon。
- **窗口**：`NSPanel`，配置如下（逐条是硬性要求）：

| 属性 | 值 | 原因 |
| --- | --- | --- |
| `styleMask` | `.borderless` + `.nonactivatingPanel` | 不抢焦点 |
| `canBecomeKey` / `canBecomeMain` | `false` | 点击不夺焦 |
| `level` | `statusWindow + 2` | 盖住菜单栏，位于弹窗之下 |
| `collectionBehavior` | `.canJoinAllSpaces`, `.fullScreenAuxiliary`, `.stationary`, `.ignoresCycle` | 全空间可见、不进 Cmd-Tab |
| `isOpaque` / `backgroundColor` | `false` / `.clear` | 透明圆角 |
| `hasShadow` | `false` | 阴影由 SwiftUI 画 |
| `hidesOnDeactivate` | `false` | 失焦不消失 |
| `acceptsMouseMovedEvents` | `true` | 悬停 |

- **激活策略**：`NSApplication.shared.setActivationPolicy(.accessory)`（无 Dock 图标）。

### 6.2 模块划分

```
Sources/
├─ CodexNotchCore/            # 纯逻辑，不 import AppKit，全部可测
│  ├─ NotchMetrics.swift      # 几何：刘海宽度、紧凑/展开窗框、命中框
│  ├─ Island.swift            # 快照模型、额度、格式化
│  ├─ RolloutParser.swift     # JSONL 单行 → 信号
│  ├─ SessionLocator.swift    # 定位最新 rollout
│  ├─ HookPayload.swift       # notify payload → 事件
│  └─ AppPaths.swift          # 路径、事件文件追加
├─ CodexNotch/                # AppKit/SwiftUI 外壳
│  ├─ main.swift              # 参数解析、NSApplication
│  ├─ AppDelegate.swift       # 装配、菜单栏
│  ├─ NotchPanel.swift        # NSPanel 配置
│  ├─ NotchController.swift   # 定位、悬停、点击
│  ├─ IslandViewModel.swift   # 唯一可变状态
│  ├─ RolloutWatcher.swift    # 被动通道（1s 轮询增量）
│  ├─ EventInbox.swift        # 主动通道（DispatchSource 文件事件）
│  ├─ Views/IslandView.swift  # 收起翼 + 展开卡
│  ├─ DemoDriver.swift        # --demo
│  └─ Probe.swift             # --probe
├─ CodexNotchHook/            # notify 转发器（argv 或 stdin → events.jsonl）
└─ CodexNotchCoreTests/       # 可执行检查套件（56 项）
```

**依赖方向**：`CodexNotchCore` ← `CodexNotch` / `CodexNotchHook`；Core 不得反向依赖 UI。

### 6.3 几何算法

**刘海宽度**

```
notchWidth = screen.width − auxTopLeft.width − auxTopRight.width
有效条件：notchWidth ≥ 60 且 notchWidth ≤ screen.width × 0.8
否则判定为“无刘海”
```

**展开窗框**

```
width  = min(420, max(320, screen.width − 80))
height = 236
x = clamp(screen.midX − width/2, screen.minX + 8, screen.maxX − width − 8)
y = screen.maxY − height        // Cocoa 坐标，原点左下
```

**收起窗框（有刘海）**

```
width  = notchWidth + 96 × 2
height = menuBarHeight（= safeAreaInsets.top，下限 24）
```

**收起窗框（无刘海）**

```
width  = 210, height = 26
y = screen.maxY − menuBarHeight − 6 − height
```

**参数表**

| 常量 | 值 | 位置 |
| --- | --- | --- |
| 两翼宽度 | 96 | `NotchGeometry.compactWingWidth` |
| 展开宽/高 | 420 / 236 | `expandedWidth/Height` |
| 无刘海胶囊 | 210 × 26 | `simulatedPillWidth/Height` |
| 最小刘海宽 | 60 | `minimumNotchWidth` |
| 命中容差 | 3pt | `NotchController` |
| 展开延迟 | 180ms | `expandDelay` |
| 收起延迟 | 320ms | `collapseDelay` |
| 完成停留 | 8s | `IslandViewModel.scheduleHide` |
| 失败停留 | 15s | 同上 |

### 6.4 被动通道实现约束

| 约束 | 值/做法 | 原因 |
| --- | --- | --- |
| 读法 | 从文件末尾 64KB 开始，按字节偏移增量读 | 大文件（实测单会话 >1MB）不能全量 |
| 轮询 | 1s | 平衡延迟与开销 |
| 重新定位 | 30s | 会话切换 |
| 半行处理 | 保留 `pending` 缓冲，下一次拼接 | 写入未完成时不能解析 |
| 起始定位 | 丢弃第一行（可能从行中间开始） | 避免半行 JSON |
| 截断/替换 | 大小回退 → 偏移归零 | 文件被重建 |
| 解码 | 容错 UTF-8（`String(decoding:)`） | 避免非法字节导致中断 |
| 事件过滤 | 只回传认识的信号 | 未知事件无害 |

### 6.5 主动通道协议

- 文件：`~/Library/Application Support/CodexNotch/events.jsonl`（可用 `CODEX_NOTCH_HOME` 覆盖）
- 写入方：`codexnotch-hook`（每次一行 JSON，追加写）
- 读取方：`EventInbox`（`DispatchSource` 监听 `.write/.extend/.delete/.rename`）
- 可靠语义：**至少一次**（重复事件必须幂等）
- 文件被删除/轮转：200ms 后重建监听，偏移归零
- hook 失败：**必须 exit 0**，绝不阻断 Codex 回合

**支持的事件类型**

| `type` | 映射 |
| --- | --- |
| `agent-turn-start` / `turn-start` / `turn_started` / `task_started` | running |
| `agent-turn-complete` / `turn-complete` / `turn_completed` / `task_complete` | done |
| `approval-requested` / `agent-approval-requested` | waiting |
| `agent-error` / `error` / `task_failed` | error |
| `notice` | 只更新附注 |

**字段容错**：同时接受 `thread-id`、`thread_id`、`threadId` 三种写法。

### 6.6 状态推导规则（唯一真源）

1. 事件（hook）优先于轮询；同秒冲突以先到者为准，后续事件覆盖。
2. `token_count` 只更新数值；若当前为 `idle`，隐含进入 `running`。
3. `task_started` 一定重置 `startedAt`。
4. `done/error` 的自动隐藏只在“未钉住且未展开”时执行。
5. 解析失败不清空快照（避免闪烁）。

### 6.7 错误处理与恢复

| 故障 | 处理 | 用户可见 |
| --- | --- | --- |
| `~/.codex/sessions` 不存在 | 保持 idle，30s 后重试 | 菜单栏一次性提示 |
| hook 文件不可写 | hook 静默退出 0 | 无（被动通道仍工作） |
| 事件文件损坏（半行） | 跳过该行 | 无 |
| 屏幕参数变化 | 重新计算并移动窗口 | 无 |
| 系统睡眠唤醒 | 重新定位文件与屏幕 | 无 |
| 进程崩溃 | 无（不常驻 daemon） | 重启后恢复 |

### 6.8 性能预算

| 指标 | 预算 | 测量方法 |
| --- | --- | --- |
| 空闲 CPU | < 0.5% | Activity Monitor 5 分钟均值 |
| 事件期 CPU | < 2%（峰值 < 1s） | 同上 |
| 内存 | < 60 MB | `footprint` |
| 单次轮询耗时 | < 2 ms | `os_signpost`（待加） |
| 磁盘写入 | 仅 hook 追加（每回合 1–3 行） | — |
| 网络 | 0 次 | 代码审查 |

### 6.9 可测试性

- 纯逻辑全部可测，不依赖屏幕。
- 测试框架：**可执行 runner**（CLT 无 XCTest），退出码即结果。
- 必备用例：几何 16 项、格式化 12 项、rollout 解析 20 项、hook 解析 6 项、文件定位 3 项（当前 56 项）。
- 新增解析规则必须附 fixture 用例（真实结构、脱敏数值）。

---

## 7. 非功能需求

| 编号 | 需求 | 验收 |
| --- | --- | --- |
| NFR-1 | 不抢焦点：点击岛面后，原来的前台应用仍接收键盘 | 手动：在编辑器中打字，点岛，继续打字 |
| NFR-2 | 全屏应用、多个桌面下可见 | 手动：Safari 全屏 + Mission Control 切桌面 |
| NFR-3 | 睡眠/唤醒、插拔显示器后位置正确 | `--probe` 对比 |
| NFR-4 | 支持 Reduce Motion（关闭弹簧动画） | 系统设置开关后目视 |
| NFR-5 | VoiceOver 可读出状态与额度 | Accessibility Inspector |
| NFR-6 | 中英双语 | 切换系统语言 |
| NFR-7 | Apple Silicon + Intel（universal） | `lipo -info` |
| NFR-8 | macOS 14+ 可运行 | 最低版本声明 + CI |

---

## 8. 安全与隐私（硬性红线）

### 8.1 数据流

```
~/.codex/sessions/**.jsonl ──只读──▶ 内存快照 ──▶ SwiftUI
~/.codex/config.toml（用户配置的 notify）──▶ codexnotch-hook ──追加──▶ events.jsonl ──▶ 内存
                                                                    （本机，不上传）
```

### 8.2 红线（任何 PR 不得违反）

| 编号 | 规则 |
| --- | --- |
| SEC-1 | **不读取** `~/.codex/auth.json`（凭证） |
| SEC-2 | 不记录、不落盘会话正文、提示词、回答、工具输出 |
| SEC-3 | 不发起任何网络请求（除 `NSWorkspace.open("codex://")`） |
| SEC-4 | 不修改 `~/.codex/config.toml`，hook 配置由用户手动添加或复制 |
| SEC-5 | 删除/归档等破坏性动作必须有确认（v1 不提供） |
| SEC-6 | 崩溃日志不得包含会话内容 |

### 8.3 威胁模型

| 威胁 | 缓解 |
| --- | --- |
| 恶意程序伪造 `events.jsonl` 让岛面显示错误状态 | 只影响展示，不触发动作；审批类动作必须二次校验来源（v2） |
| 事件文件被无限追加撑爆磁盘 | v1.1 加大小上限与轮转（如 > 1MB 截断） |
| 权限提示误点导致命令被执行 | v1 不实现审批动作 |

---

## 9. 开源工程与分发（DIST）

| 编号 | 需求 | 状态 |
| --- | --- | --- |
| DIST-1 | MIT License，保留版权声明 | ✅ |
| DIST-2 | README：是什么、安装、hook 配置、隐私、限制、路线图 | ✅ |
| DIST-3 | `docs/` 记录实测数据格式与复验方法 | ✅ |
| DIST-4 | 构建脚本一键产出 `.app`（ad-hoc 签名） | ✅ |
| DIST-5 | CI：构建 + 检查 + 打包（macOS runner） | ✅ |
| DIST-6 | Developer ID 签名 + notarize + stapling | ⬜（需要 $99 账号） |
| DIST-7 | Release 产物：universal zip + `.sha256` + 变更说明 | ⬜ |
| DIST-8 | Homebrew Cask | ⬜ |
| DIST-9 | 首次启动 Gatekeeper 绕过说明（未公证时） | ⬜ |
| DIST-10 | Issue 模板（bug / 数据解析失效） + CONTRIBUTING | ⬜ |
| DIST-11 | 隐私声明：仅本地读取、不联网 | ✅（README） |
| DIST-12 | 版本号与 CHANGELOG | ⬜ |

**安装路径约定**：`~/Applications/CodexNotch.app`（免 sudo）。

**命名**：仓库 `codex-notch`，产品名 `Codex Notch`，Bundle ID `io.github.github-bian.CodexNotch`。
`Codex` 为 OpenAI 商标，需保留“非官方、无隶属关系”声明（已写入 README）。

---

## 10. 里程碑与验收

### M0 — 骨架（✅ 已完成，commit `4f8ebf8`）

交付：窗口、几何、双通道数据、状态机、56 项检查、构建脚本、CI、文档。

验收（实测）：

- [x] `swift build --disable-sandbox` 通过
- [x] `./scripts/test.sh` → 56/56
- [x] `.app` 打包 + ad-hoc 签名成功
- [x] `--probe` 输出真实屏幕数据
- [x] 真实 rollout 解析：token、上下文、额度、项目目录
- [ ] 刘海实机目视（缺硬件条件）

### M1 — 真机刘海验证（P0，0.5 天）

- [ ] `--probe` 输出的刘海宽度与肉眼/截图一致（14" 与 16" 各一台）
- [ ] 两翼文字不压到刘海，不压到菜单栏图标
- [ ] 点击岛面后编辑器仍可输入（NFR-1）
- [ ] 全屏应用与多桌面可见（NFR-2）
- [ ] 悬停展开 ≤ 300ms，离开收起 ≤ 500ms
- [ ] 无残影、无频闪

### M2 — 动作与跳转（P0，1–2 天）

- [ ] Q1 完成：hook `thread-id` ↔ rollout 会话绑定
- [ ] 点击卡片打开对应会话（FR-A4）
- [ ] 复制 hook 配置 + 首次引导（FR-M3）
- [ ] 审批动作（FR-A5）**仅在 Q2 通过后**进入排期

### M3 — 数据完整（P1，2–3 天）

- [ ] 双额度窗口（5h + 每周）同时展示
- [ ] 多会话列表与切换
- [ ] 会话成本估算（按模型单价，标注“估算”）
- [ ] 数据不可读的显式降级（不是静默空白）

### M4 — 分发（P0，1 天）

- [ ] Developer ID 签名 + notarize + stapling
- [ ] universal 包 + sha256 + Release notes
- [ ] Homebrew Cask
- [ ] README 截图（真实刘海）

### M5 — 打磨（P2）

- [ ] 中英双语
- [ ] Reduce Motion / VoiceOver
- [ ] 设置窗口（皮肤、音效、显示器）
- [ ] 开机自启
- [ ] 事件文件轮转与上限

---

## 11. 风险登记册

| 编号 | 风险 | 概率 | 影响 | 缓解 | 触发信号 |
| --- | --- | --- | --- | --- | --- |
| R1 | Codex 内部 JSONL 格式变更 | 高 | 高 | 解析层容错 + fixture 测试 + 版本探测 | issue：数据不再更新 |
| R2 | `rate_limits` 长期为 null | 中 | 中 | 按可缺失设计；v2 接 app-server | UI 无额度 |
| R3 | 审批写回协议不可得 | 中 | 高（功能砍掉） | 先做 Q2 验证；不通过则不实现 A5 | — |
| R4 | 多会话无法区分 | 中 | 中 | thread-id ↔ 文件名绑定；否则只跟随最新 | 用户反馈显示错会话 |
| R5 | 刘海几何在不同机型不一致 | 中 | 中 | 公式化 + `--probe` 自查 | 两翼偏移 |
| R6 | Gatekeeper 拦截导致放弃安装 | 高 | 高 | M4 公证；未公证时给清晰指引 | 下载后打不开 |
| R7 | 与菜单栏图标冲突（刘海两侧空间有限） | 中 | 中 | 仅占刘海正上方 + 96pt | 遮挡图标 |
| R8 | 新版 rollout 使用 zstd | 中 | 中 | 读取层检测 `.jsonl.zst` 并解压（v1.1） | 找不到 jsonl |
| R9 | 竞品（AgentNotch）先覆盖 Codex 深度数据 | 中 | 中 | 用 token/额度/跳转做差异 | — |
| R10 | 商标/命名争议 | 低 | 低 | 保留非官方声明；可改名 | — |

---

## 12. 开放问题（需验证后才能开工）

| 编号 | 问题 | 验证方法 | 阻塞谁 |
| --- | --- | --- | --- |
| Q1 | hook 的 `thread-id` 能否对应到 rollout 文件（文件名含 session uuid）？ | 配置 hook 跑一轮，比对 payload 与最新文件名 | FR-A4 |
| Q2 | Codex app-server 的 JSON-RPC 是否支持审批应答？ | 读 app-server 协议/抓包 `codex app-server` | FR-A5 |
| Q3 | `primary` / `secondary` 与「5h / 每周」的稳定对应关系？ | 连续观察 3 天不同用量下的字段 | FR-E5 |
| Q4 | 新版是否产出 `.jsonl.zst`？何时启用？ | 在较新 CLI 上观察目录 | 读取层 |
| Q5 | 多会话时“当前会话”如何判定？thread-id 最新？窗口焦点？ | 并发跑两个会话观察 | FR-E8 |
| Q6 | 14"/16" 刘海实际宽度与安全区高度 | 真机 `--probe` | M1 |
| Q7 | 合盖 + 外接屏时是否显示（此时无物理刘海） | 真机测试 | FR-D3 |
| Q8 | 点击刘海正上方是否会被系统当作菜单栏点击吞掉 | 真机测试 | FR-I3 |

---

## 13. 现状差距分析

| 需求 | 状态 | 位置 | 缺口 |
| --- | --- | --- | --- |
| FR-C1 两翼贴合刘海 | 🟡 | `NotchGeometry.compactFrame` | 未真机验证 |
| FR-C2/C3 左右翼内容 | ✅ | `Views/IslandView.swift` | — |
| FR-C4 idle 零像素 | ✅ | `IslandView` / `ViewModel` | — |
| FR-C5 额度变色 | ✅ | `quotaColor` | 阈值需产品确认 |
| FR-C7 token 格式 | ✅ | `IslandFormatter.tokens` | — |
| FR-E1..E4,E6,E7,E9 | ✅ | `ExpandedView` | — |
| FR-E5 双窗口 | ⬜ | — | 需 Q3 |
| FR-E8 多会话 | ⬜ | — | 需 Q5 |
| FR-I1..I4 | ✅ | `NotchController` | 手感未目视 |
| FR-I5 不抢焦点 | 🟡 | `NotchPanel` | 未真机验证 |
| FR-I6 Reduce Motion | 🟡 | `IslandView` | 未接系统设置 |
| FR-D1..D5 | ✅/🟡 | `NotchController` | 多屏未测 |
| FR-M1 菜单栏 | ✅ | `AppDelegate` | — |
| FR-M2..M4 | ⬜ | — | — |
| FR-A1..A3 | ✅ | `NotchController` / `AppDelegate` | — |
| FR-A4 跳转会话 | ⬜ | — | Q1 |
| FR-A5 审批 | ⬜ | — | Q2（高风险） |
| FR-L1..L3 本地化 | ⬜ | — | 文案硬编码 |
| NFR-1..8 | 🟡 | — | 仅编译级验证 |
| SEC-1..6 | ✅ | 代码审查 | 需一次正式审计 |
| DIST-6..10 | ⬜ | — | 需账号/发布流程 |

---

## 14. 附录

### A. 实测环境

| 项 | 值 |
| --- | --- |
| macOS | 26.3（25D125） |
| Swift | 6.2.3（CLT，无完整 Xcode） |
| 架构 | arm64 |
| 显示器 | BenQ PD2500Q 2048×1152（**无刘海**） |
| Codex | 本地有 603 个 rollout，最大单文件 > 1 MB |
| 额度实测 | `65%`，`window_minutes = 10080`（7 天），`plan_type = prolite`，`resets_at = 2026-11-22` |

> 关键结论：**CLT 环境下 `swift build` 需要 `--disable-sandbox`，且没有 XCTest**；
> 因此测试是可执行 runner，而不是 `swift test`。

### B. 常用命令

```bash
./scripts/test.sh          # 构建 + 56 项检查
./scripts/build-app.sh     # 产出 build/CodexNotch.app（ad-hoc 签名）
./scripts/install.sh       # 装到 ~/Applications 并打印 hook 配置

.build/debug/CodexNotch --probe   # 打印屏幕几何
.build/debug/CodexNotch --demo    # 假数据演示
```

### C. 关键常量速查

| 常量 | 值 |
| --- | --- |
| 两翼宽 | 96 |
| 展开 420×236 | — |
| 无刘海胶囊 210×26 | — |
| 命中容差 3 | — |
| 展开/收起延迟 180ms / 320ms | — |
| 完成/失败停留 8s / 15s | — |
| 轮询 1s / 重扫 30s / 尾窗 64KB | — |
| 自动隐藏上限 30 分钟无更新 | — |

### D. 术语

| 术语 | 含义 |
| --- | --- |
| 岛面 / island | 刘海上的整块 UI |
| 翼 / wing | 收起态刘海左右两侧的内容区 |
| 收起态 / compact | 只显示两翼 |
| 展开态 / expanded | 420×236 的卡片 |
| 被控端 / —— | 本项目不涉及 device-link，勿混淆 |
| rollout | Codex 的会话事件日志（JSONL） |
| hook | Codex `notify` 配置调用的外部命令 |

### E. 参考资料

- [Codex 本地会话结构实测](codex-data.md)
- [openai/codex#14880 — rate_limits 为 null](https://github.com/openai/codex/issues/14880)
- [BoringNotch（GPL-3.0，仅借鉴交互）](https://github.com/TheBoredTeam/boring.notch)
- [AgentNotch](https://github.com/mattBonfanti/AgentNotch)
- [notch-island-tools 索引](https://github.com/ChenSiWu/notch-island-tools)
- [codex-touchbar-usage（同作者前作）](https://github.com/github-bian/codex-touchbar-usage)

---

## 15. 变更记录

| 版本 | 日期 | 内容 |
| --- | --- | --- |
| v1.0 | 2026-11-17 | 首版：决策定稿（只做 Codex / 只读+操作 / 独立仓库）、M0 验收、实测数据、风险与开放问题 |
