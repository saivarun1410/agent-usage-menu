#!/bin/zsh
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
binary_dir="$HOME/.local/bin"
agent_dir="$HOME/Library/LaunchAgents"
binary_path="$binary_dir/codex-usage-menu"
agent_path="$agent_dir/com.codexusagemenu.app.plist"

swift build --package-path "$project_dir" -c release
install -d "$binary_dir" "$agent_dir"
install -m 755 "$project_dir/.build/release/CodexUsageMenu" "$binary_path"
install -m 644 "$project_dir/launchd/com.codexusagemenu.app.plist" "$agent_path"

launchctl bootout "gui/$(id -u)/com.codexusagemenu.app" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$agent_path"
echo "Installed. Codex usage is now in the menu bar."
