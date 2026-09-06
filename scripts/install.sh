#!/bin/zsh
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
binary_dir="$HOME/.local/bin"
agent_dir="$HOME/Library/LaunchAgents"
binary_path="$binary_dir/codex-usage-menu"
claude_capture_path="$binary_dir/claude-usage-capture"
claude_statusline_path="$binary_dir/claude-usage-statusline"
agent_path="$agent_dir/com.codexusagemenu.app.plist"
enable_claude=false

if [[ $# -gt 0 ]]; then
  if [[ "$1" == "--claude" && $# -eq 1 ]]; then
    enable_claude=true
  else
    echo "Usage: ./scripts/install.sh [--claude]" >&2
    exit 64
  fi
fi

swift build --package-path "$project_dir" -c release
install -d "$binary_dir" "$agent_dir"
install -m 755 "$project_dir/.build/release/CodexUsageMenu" "$binary_path"
install -m 755 "$project_dir/.build/release/ClaudeUsageCapture" "$claude_capture_path"
install -m 755 "$project_dir/scripts/claude-usage-statusline" "$claude_statusline_path"
install -m 644 "$project_dir/launchd/com.codexusagemenu.app.plist" "$agent_path"

if [[ "$enable_claude" == true ]]; then
  if "$claude_capture_path" --install-statusline; then
    claude_enabled=true
  else
    claude_enabled=false
    echo "Claude Code capture was installed, but its existing statusLine was left unchanged." >&2
    echo "See the README for manual integration with a custom status line." >&2
  fi
fi

launchctl bootout "gui/$(id -u)/com.codexusagemenu.app" 2>/dev/null || true
sleep 1
launchctl bootstrap "gui/$(id -u)" "$agent_path"
if [[ "${claude_enabled:-false}" == true ]]; then
  echo "Installed. Codex and Claude Code usage will appear in the menu bar."
elif [[ "$enable_claude" == true ]]; then
  echo "Installed. Codex usage is now in the menu bar; Claude Code capture awaits status-line integration."
else
  echo "Installed. Codex usage is now in the menu bar. Run ./scripts/install.sh --claude to add Claude Code usage."
fi
