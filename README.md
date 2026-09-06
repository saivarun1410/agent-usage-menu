# Agent Usage Menu

See your Codex and Claude Code rate limits in the macOS menu bar.

When both providers have usage data, the menu bar shows `Codex 65% | Claude 80%`. Click it to open one popover with a tab for each provider. Codex is selected first; if you use only one provider, you see only that provider.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?logo=apple) ![npm](https://img.shields.io/npm/v/agent-usage-menu?logo=npm) ![Swift 6](https://img.shields.io/badge/Swift-6-orange?logo=swift)

## Preview

![Illustrative preview of the Agent Usage Menu with Codex and Claude Code tabs](assets/agent-usage-preview-v2.png)

*Illustrative preview. Your usage percentages and reset times come from your own signed-in accounts.*

## Requirements

- macOS 13 (Ventura) or later
- Node.js 18 or later
- Xcode Command Line Tools — run `xcode-select --install` if needed
- At least one signed-in provider:
  - Codex CLI: `codex login`
  - [Claude Code](https://code.claude.com/docs/en/overview)

Codex and Claude Code are independent. Install the utility once, then use either one or both.

## Install

### Fastest: one command

For Codex:

```zsh
npx --yes agent-usage-menu
```

For Codex and Claude Code:

```zsh
npx --yes agent-usage-menu install --claude
```

`npx` downloads the package, compiles the native app, starts it, and registers it to start automatically at login. The menu-bar item appears when the command finishes; you do not need to keep that Terminal window open.

### Global npm install

Use this if you want to keep the `agent-usage-menu` command available in your shell:

#### Codex only

```zsh
npm install -g agent-usage-menu
agent-usage-menu install
```

#### Codex and Claude Code

```zsh
npm install -g agent-usage-menu
agent-usage-menu install --claude
```

Both installation methods compile the native menu-bar app, start it, and register it to start automatically at every login. You do not need to leave a Terminal window open.

If you quit the app from its popover, start it again with:

```zsh
agent-usage-menu start
```

To remove it:

```zsh
agent-usage-menu uninstall
```

## How your usage is captured

| Provider | What the app reads | When it updates | What is saved locally |
| --- | --- | --- | --- |
| Codex | Your already signed-in Codex CLI’s local rate-limit response | Every minute, plus **Refresh now** | Nothing |
| Claude Code | The official Claude Code status-line rate-limit payload | After the first completed Claude response, then during session events / every minute | Latest percentages and reset times only |

The app never asks for your password, copies tokens, or sends account data to another service.

### Codex

The app starts the signed-in local `codex` CLI briefly, reads its current rate limits, then exits that helper. It does not scrape a web page or store Codex credentials.

### Claude Code

`--claude` adds a small local Claude Code status-line helper. Claude Code sends that helper its own session JSON; the helper records only the 5-hour and weekly percentages plus reset times for the menu app to display.

Start or resume a Claude Code session and receive one response to populate the Claude tab for the first time. Claude Code does not include monthly allowance data in this payload, so the app cannot display it.

If you sign out of Claude Code, the app clears its cached Claude usage and removes Claude from the menu until you sign in again.

### Existing Claude status line

Claude Code supports one status-line command. If you already have a custom one, the installer leaves it untouched. Add this after the line that reads its JSON input, before it prints its normal output:

```bash
printf '%s' "$input" | "$HOME/.local/bin/claude-usage-capture" >/dev/null 2>&1 || true
```

## Privacy

No analytics or tracking. Codex usage is read directly from your local signed-in CLI. For Claude Code, the only persisted record contains the latest rate-limit percentages and reset timestamps.

## Development

```zsh
swift test
swift run AgentUsageMenu
```

## License

[MIT](LICENSE)
