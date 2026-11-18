# Codex Notch

[简体中文](README.zh-CN.md) · English

A native macOS notch dashboard for Codex. See the current session's status, remaining usage limit, reset time, context usage, and cumulative tokens without switching away from your work.

> An unofficial community project. It is not affiliated with or endorsed by OpenAI.

![Compact island using sample data](docs/images/notch-compact.png)

![Codex Notch expanded, using sample data](docs/images/notch-expanded-en.png)

*These images are rendered from the app with sample demo data. Normal mode reads your local Codex session.*

## What it does

- Shows the newest active Codex session in a compact island. Hover to expand; click the compact island to pin it open. Click **×** to close it.
- Displays the remaining quota and its reset time when Codex provides them, plus context usage and cumulative session tokens. The quota indicator changes color when the used percentage reaches 70% and 90%.
- Highlights running, waiting, completed, and failed states. The **Open Codex** button returns to Codex without performing an approval.
- Attaches to the screen's top edge on displays without a physical notch. A crowded menu bar can overlap the simulated island.
- Uses English or Simplified Chinese according to the system language and respects Reduce Motion.

## Requirements and installation

- macOS 14 or later, with Codex already installed and used at least once.
- Xcode Command Line Tools and Swift for building from source.

```bash
git clone https://github.com/github-bian/codex-notch.git
cd codex-notch
./scripts/install.sh
open "$HOME/Applications/CodexNotch.app"
```

The installer replaces an existing `~/Applications/CodexNotch.app`. The local build uses an ad-hoc signature and is not notarized; macOS may show a security warning.

## Usage and data

Normal mode reads local rollout files under `~/.codex/sessions`. It follows the file most recently written, checks for updates every second, and searches for a newer session approximately every five seconds. When several sessions are active, the most recently written file is not necessarily the session currently in the foreground.

The app shows one quota window reported by Codex. Its duration is taken from the data, so it may be five hours, seven days, or another duration. Quota and context sections are hidden when their data is unavailable. Total tokens are cumulative for the session, not just the current turn. The elapsed time is shown when a start time is available; an old inactive session is not treated as live.

The menu bar icon offers **Open Codex**, **Copy hook config**, **Reveal data folder**, and **Quit**. The app does not claim to jump to a particular session.

### Optional: event notifications

Polling works without configuration. To forward supported Codex notifications, copy the hook configuration from the menu bar and add it to `~/.codex/config.toml`, for example:

```toml
notify = ["/Users/<you>/Applications/CodexNotch.app/Contents/MacOS/codexnotch-hook"]
```

Restart Codex after changing its configuration. `notify` support varies by Codex version; in particular, an approval-waiting state requires an actual supported approval event to reach the hook. Codex Notch does not approve commands.

## Demo and diagnostics

```bash
.build/debug/CodexNotch --demo   # Explicitly simulated data, marked DEMO
.build/debug/CodexNotch --probe  # Display geometry and data locations
```

Build the debug executable with `swift build --disable-sandbox` first. The demo is isolated from live session and hook data. The probe prints local paths; review its output before sharing it.

## Privacy and limits

- Rollouts are read locally. The app does not read `~/.codex/auth.json`, upload data, or make network requests. Opening `codex://` asks macOS to open Codex.
- New hook events persist only the event type, thread and turn IDs, and working directory; prompt and response bodies are not saved. Older versions wrote the raw notification to `~/Library/Application Support/CodexNotch/events.jsonl`; upgrading does not delete that file.
- Startup examines a bounded recent portion of the latest rollout. Very long turns may not have their original start time in that portion, in which case elapsed time cannot be recovered reliably.
- Physical-notch geometry, multiple displays, focus behavior, and VoiceOver still require validation on the relevant hardware. `--probe` can help inspect screen geometry.

## Development

```bash
./scripts/test.sh        # Build and run the executable test suite
./scripts/build-app.sh   # Build build/CodexNotch.app
```

Pure parsing, formatting, and geometry live in `Sources/CodexNotchCore`; the native panel and UI live in `Sources/CodexNotch`. The optional hook is a separate executable.

## License

[MIT](LICENSE). The notch interaction is inspired by community projects including BoringNotch, AgentNotch, and Code Island.
