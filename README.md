# Codex Usage Menu

A tiny native macOS menu-bar app that keeps your current Codex usage visible. It uses the Codex CLI already signed in on your Mac; it does not ask for, transmit, or save your credentials.

The menu-bar label shows the lowest remaining quota (`Codex 84%`). Click it to see every available usage window, reset times, plan, reset credits, and a manual refresh control.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?logo=apple) ![Swift 6](https://img.shields.io/badge/Swift-6-orange?logo=swift)

## Preview

![Illustrative preview of the Codex Usage Menu popover](assets/menu-preview.png)

*Illustrative preview of the native menu-bar interface. Your available quota windows, percentages, and reset times will reflect your own account.*

## Requirements

- macOS 13 (Ventura) or later
- Xcode Command Line Tools (`xcode-select --install`)
- Codex CLI installed and signed in (`codex login`)

## Install

```zsh
git clone https://github.com/saivarun1410/codex-usage-menu.git
cd codex-usage-menu
./scripts/install.sh
```

The installer compiles the app, adds it to your user LaunchAgents, and starts it. You only need to install it once: macOS starts it automatically after every future login and keeps it running quietly in the menu bar. You do not need to keep a terminal open or run a command again.

Choosing **Quit Codex Usage Menu** from the menu stops monitoring until you launch the app again or log in next time. To remove it permanently:

```zsh
./scripts/uninstall.sh
```

## How it works

Every 60 seconds, the app starts the locally installed `codex app-server --stdio`, initializes a local JSON-RPC session, and reads `account/rateLimits/read`. It displays the returned rate-limit windows and then closes that helper process. **Refresh now** is only a manual fallback; no terminal command or user action is needed for normal updates.

This uses a local Codex app-server capability rather than scraping a web page. It is read-only, and it never reads, copies, or persists your Codex authentication files. Codex does not currently document this protocol as a public stable API, so a future Codex update may require an update to this utility.

## Development

```zsh
swift test
swift run CodexUsageMenu
```

## Privacy

No analytics, network client, account token, or tracking is included. The Codex CLI itself contacts OpenAI to retrieve your current account quota, exactly as it does when its usage status is shown.

## License

[MIT](LICENSE)
