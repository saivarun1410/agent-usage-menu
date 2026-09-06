# Agent Usage Menu

A tiny native macOS menu-bar app that keeps your Codex and Claude Code usage visible. Choose either provider or both: when both are available, their lowest remaining quotas appear together in the menu bar (`Codex 84% · Claude 77%`).

It uses the Codex CLI and Claude Code already signed in on your Mac; it does not ask for, transmit, or save credentials.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?logo=apple) ![Swift 6](https://img.shields.io/badge/Swift-6-orange?logo=swift)

## Preview

### Codex

![Illustrative preview of the Codex usage popover](assets/menu-preview.png)

### Claude Code

![Illustrative preview of the Claude Code usage popover](assets/claude-code-preview.png)

*Illustrative previews of the native menu-bar interface. Your available quota windows, percentages, and reset times will reflect your own account.*

## Requirements

- macOS 13 (Ventura) or later
- Xcode Command Line Tools (`xcode-select --install`)
- Codex CLI installed and signed in (`codex login`) to monitor Codex
- [Claude Code](https://code.claude.com/docs/en/overview) installed and signed in to monitor Claude Code

Codex and Claude Code are independently optional: install the utility once and use whichever provider(s) you have.

## Install

```zsh
git clone https://github.com/saivarun1410/agent-usage-menu.git
cd agent-usage-menu
./scripts/install.sh
```

To add Claude Code support at install time, use:

```zsh
./scripts/install.sh --claude
```

The installer compiles the app, adds it to your user LaunchAgents, and starts it. You only need to install it once: macOS starts it automatically after every future login and keeps it running quietly in the menu bar. You do not need to keep a terminal open or run a command again.

Choosing **Quit Agent Usage Menu** from the menu stops monitoring until you launch the app again or log in next time. To remove it permanently:

```zsh
./scripts/uninstall.sh
```

## How it works

### Codex

Every 60 seconds, the app starts the locally installed `codex app-server --stdio`, initializes a local JSON-RPC session, and reads `account/rateLimits/read`. It displays the returned rate-limit windows and then closes that helper process. **Refresh now** is only a manual fallback; no terminal command or user action is needed for normal updates.

This uses a local Codex app-server capability rather than scraping a web page. It is read-only, and it never reads, copies, or persists your Codex authentication files. Codex does not currently document this protocol as a public stable API, so a future Codex update may require an update to this utility.

### Claude Code

Claude Code publishes 5-hour and 7-day rate-limit data through its official [status-line JSON payload](https://code.claude.com/docs/en/statusline). With `--claude`, this utility installs a small local status-line command that saves only those percentages and reset timestamps; the menu app reads that local record each minute. Claude Code updates the record while a Claude session is active, so the popover shows when it was last captured.

Claude Code allows one `statusLine` command. To protect custom setups, the installer never replaces an existing one. If you already use a custom status line, it leaves it intact and prints an integration note. Adapt that command to forward its JSON input to `~/.local/bin/claude-usage-capture` before it produces its usual output. The capture helper accepts the official JSON on standard input and writes its own short status line to standard output.

The Claude Code payload contains the 5-hour and 7-day windows; a monthly account allowance is not included, so it is not displayed here.

## Development

```zsh
swift test
swift run CodexUsageMenu
```

## Privacy

No analytics, network client, account token, or tracking is included. The Codex CLI itself contacts OpenAI to retrieve your current account quota, exactly as it does when its usage status is shown. For Claude Code, the only locally persisted information is the latest two rate-limit percentages and reset timestamps supplied by its status-line payload.

## License

[MIT](LICENSE)
