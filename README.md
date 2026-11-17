# Codex Notch

**把 MacBook 的刘海变成 Codex 的实时仪表盘。** 一眼看到：额度还剩多少、下一次重置是几点、当前任务在跑什么、这轮烧了多少 token、上下文占了多少。

> 状态：`0.1.0` 骨架。可编译、可运行，真实数据管线已在本机验证；**刘海实机（内置屏）几何尚未验证**——见[已知限制](#已知限制)。

非官方社区项目，与 OpenAI 没有隶属、授权或背书关系。

---

## 它长什么样

- **收起态**：信息挂在刘海两翼。左翼 = 状态点 + 任务/项目名，右翼 = 额度百分比 + token 数。没有任务时完全隐藏（零像素）。
- **展开态**：悬停（或点击钉住）展开一张卡：额度进度条 + 重置倒计时、上下文占用条、总 token、打开 Codex。
- **状态色**：运行 = 橙，等待审批 = 青，完成 = 绿，失败 = 红。
- **无刘海屏**：自动降级为菜单栏下方的悬浮胶囊，不遮挡应用菜单。

## 数据从哪来

两条通道，互为主备：

| 通道 | 来源 | 用途 |
| --- | --- | --- |
| 被动 | `~/.codex/sessions/**/rollout-*.jsonl` | 当前轮状态、token、上下文、额度（只 tail 最新文件，从末尾 64KB 开始） |
| 主动 | Codex `notify` → `codexnotch-hook` → `~/Library/Application Support/CodexNotch/events.jsonl` | 回合开始/结束/等待审批，毫秒级到达 |

被动通道零配置就能工作；主动通道让"完成"和"等待审批"不再靠猜。字段结构见 [docs/codex-data.md](docs/codex-data.md)。

## 安装

要求：macOS 14+，已安装并登录 Codex；从源码构建需要 Xcode Command Line Tools。

```bash
git clone https://github.com/github-bian/codex-notch.git
cd codex-notch
./scripts/install.sh
```

装到 `~/Applications/CodexNotch.app`（ad-hoc 签名）。然后在 `~/.codex/config.toml` 加一行：

```toml
notify = ["/Users/<you>/Applications/CodexNotch.app/Contents/MacOS/codexnotch-hook"]
```

重启 Codex 后生效。也可以从菜单栏图标点「Copy hook config」直接复制这一行。

## 使用

- 鼠标移到刘海：展开；移开：收起
- 点击收起态：钉住展开；点标题栏右侧 `×`：收起并取消钉住
- `Open`：打开 Codex（`codex://`）
- 菜单栏图标：复制 hook 配置 / 打开数据目录 / 退出

调试参数：

```bash
CodexNotch --probe   # 打印每块屏的刘海宽度、菜单栏高度、窗框位置，然后退出
CodexNotch --demo    # 假数据循环，用来看几何和动效
```

## 已知限制

- **多会话只显示最近写入的 rollout**：同时跑多个 Codex 任务时，岛面跟随最后写入的那个文件。
- **等待审批依赖 hook**：rollout 里没有稳定的审批事件；不配 `notify` 时只有"运行/完成/失败"。
- **刘海几何未在实机验证**：本项目的开发环境是外接显示器（无刘海），走的是降级胶囊路径。用 `--probe` 可以在你的机器上立刻核对数值。
- **ad-hoc 签名、未公证**：首次打开可能被 Gatekeeper 拦，需在「系统设置 → 隐私与安全性」放行。分发版本应改用 Developer ID + notarize。
- **只读本地文件，不联网**：除打开 `codex://` 外没有任何网络请求；不读取 `~/.codex/auth.json`。

## 路线图

- [ ] 内置屏实机验证 + 截图
- [ ] 5 小时 / 每周两个额度窗口同时展示
- [ ] 多会话列表（按 `task_started` 分组）
- [ ] 声音与 HUD 式提示
- [ ] 点击 approve / deny（需要先解决写回与误触问题）
- [ ] Developer ID 签名 + notarize + Homebrew cask
- [ ] 菜单栏模式（合盖外接屏时替代刘海）

## 开发

```bash
./scripts/test.sh        # 构建 + 运行检查（XCTest 在纯 CLT 环境下不可用）
./scripts/build-app.sh   # 只打包 .app
swift build --disable-sandbox
```

结构：

```
Sources/CodexNotchCore/      纯逻辑：几何、快照模型、rollout / hook 解析、路径
Sources/CodexNotch/          AppKit 外壳：NSPanel、悬停、SwiftUI 视图、watchdog
Sources/CodexNotchHook/      Codex notify 调用的转发器
Sources/CodexNotchCoreTests/ 可执行检查套件（56 项）
```

设计上刻意把"读数据"和"画界面"分开：`Core` 不 import AppKit，所有解析都能用 fixture 测。`NSPanel` 是不抢焦点的 `.nonactivatingPanel`，层级在状态栏之上、所有空间可见。

隐私：hook 只把 Codex 给的 JSON 原样落到本地文件；项目不上传、不打日志内容、不读凭证。

## 致谢

刘海面板的交互模式受 [BoringNotch](https://github.com/TheBoredTeam/boring.notch)、[AgentNotch](https://github.com/mattBonfanti/AgentNotch)、[Code Island](https://github.com/) 等社区项目启发；本项目没有复用它们的代码（BoringNotch 为 GPL-3.0）。额度读取思路延续了同作者的 [codex-touchbar-usage](https://github.com/github-bian/codex-touchbar-usage)。

## License

[MIT](LICENSE)
