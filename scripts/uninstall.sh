#!/bin/zsh
set -euo pipefail

agent_path="$HOME/Library/LaunchAgents/com.codexusagemenu.app.plist"
launchctl bootout "gui/$(id -u)/com.codexusagemenu.app" 2>/dev/null || true
rm -f "$agent_path" "$HOME/.local/bin/codex-usage-menu"
echo "Codex Usage Menu has been removed."
