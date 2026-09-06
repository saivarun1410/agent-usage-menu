#!/bin/zsh
set -euo pipefail

agent_path="$HOME/Library/LaunchAgents/com.codexusagemenu.app.plist"
claude_capture_path="$HOME/.local/bin/claude-usage-capture"
if [[ -x "$claude_capture_path" ]]; then
  "$claude_capture_path" --remove-statusline
fi
launchctl bootout "gui/$(id -u)/com.codexusagemenu.app" 2>/dev/null || true
rm -f "$agent_path" "$HOME/.local/bin/codex-usage-menu" "$claude_capture_path" "$HOME/.local/bin/claude-usage-statusline"
echo "Agent Usage Menu has been removed."
