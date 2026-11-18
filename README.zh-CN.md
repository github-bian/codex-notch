# Codex Notch

简体中文 · [English](README.md)

一个原生 macOS Codex 刘海仪表盘。无需切换窗口，就能查看当前会话状态、剩余额度、重置时间、上下文占用和累计 Token。

> 本项目为非官方社区项目，与 OpenAI 没有隶属或背书关系。

![Codex Notch 收起状态，使用模拟数据](docs/images/notch-compact.png)

![Codex Notch 展开状态，使用模拟数据](docs/images/notch-expanded.png)

*图片由应用界面渲染，数值为演示数据。正常模式读取本机 Codex 会话。*

## 功能

- 收起态显示最近活动的 Codex 会话。悬停展开，点击收起态可钉住；点击 **×** 收起。
- Codex 提供额度时显示剩余百分比和重置时间，并显示上下文占用和会话累计 Token。额度已用达到 70% 和 90% 时改变颜色。
- 区分运行、等待、完成和失败状态。**打开 Codex** 只负责打开 Codex，不会替用户审批命令。
- 没有物理刘海时，灵动岛仍贴合屏幕顶边；菜单栏图标较多时，模拟岛可能与它们重叠。
- 根据系统语言显示简体中文或英文，并遵循系统的减少动态效果设置。

## 环境与安装

- macOS 14 或更新版本，已安装并至少使用过一次 Codex。
- 从源码构建需要 Xcode Command Line Tools 和 Swift。

```bash
git clone https://github.com/github-bian/codex-notch.git
cd codex-notch
./scripts/install.sh
open "$HOME/Applications/CodexNotch.app"
```

安装脚本会替换已有的 `~/Applications/CodexNotch.app`。本地构建使用临时签名、尚未公证，macOS 可能显示安全提示。

## 使用与数据口径

正常模式读取 `~/.codex/sessions` 下的本地会话文件：每秒检查增量，约每 5 秒查找最近写入的会话。多个会话同时运行时，最近写入的会话不一定是当前前台会话。

应用展示 Codex 返回的一个额度窗口，窗口长度由数据决定，可能是 5 小时、7 天或其他时长。额度或上下文数据缺失时，相应区域会隐藏。Token 是**整个会话的累计值**，不是当前回合单独消耗的数量。可取得开始时间时显示运行时长；长期未更新的会话不会一直显示运行中。

菜单栏图标提供**打开 Codex、复制 hook 配置、显示数据文件夹和退出**。当前版本打开 Codex，但不保证跳转到特定会话。

### 可选：配置事件通知

不配置也能通过轮询使用。若要转发 Codex 支持的通知，可从菜单栏复制 hook 配置，加入 `~/.codex/config.toml`，例如：

```toml
notify = ["/Users/<you>/Applications/CodexNotch.app/Contents/MacOS/codexnotch-hook"]
```

修改配置后重启 Codex。不同 Codex 版本提供的 `notify` 事件可能不同；尤其是等待审批状态，需要对应的审批事件实际到达 hook。Codex Notch 不会替用户批准命令。

## 演示与诊断

```bash
.build/debug/CodexNotch --demo   # 明确标记 DEMO 的模拟数据
.build/debug/CodexNotch --probe  # 显示屏幕几何和数据位置
```

先用 `swift build --disable-sandbox` 构建调试版本。演示模式不接入真实会话或 hook 数据。`--probe` 会输出本地路径，分享前请自行检查。

## 隐私与已知限制

- 会话文件只在本机读取；不读取 `~/.codex/auth.json`、不上传数据、不主动联网。打开 `codex://` 会交给 macOS 启动 Codex。
- 新写入的 hook 事件只包含事件类型、会话与回合 ID、工作目录，不保存提示词和回答正文。旧版本曾把原始通知写入 `~/Library/Application Support/CodexNotch/events.jsonl`；升级不会删除该文件。
- 启动时只扫描最新会话末尾的有限数据。特别长的回合可能无法恢复原始开始时间，因此无法可靠显示运行时长。
- 物理刘海、多显示器、键盘焦点和 VoiceOver 仍需在对应设备上验证；可用 `--probe` 查看屏幕几何。

## 开发

```bash
./scripts/test.sh        # 构建并运行可执行测试
./scripts/build-app.sh   # 构建 build/CodexNotch.app
```

解析、格式化和几何逻辑位于 `Sources/CodexNotchCore`，原生窗口与界面位于 `Sources/CodexNotch`，可选 hook 是独立可执行文件。

## 许可证

[MIT](LICENSE)。刘海交互参考了 BoringNotch、AgentNotch、Code Island 等社区项目。
