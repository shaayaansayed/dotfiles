#!/usr/bin/env bash
# sync.sh — pull latest dotfiles and apply changes on an already-set-up machine
# Usage: cd ~/projects/dotfiles && ./sync.sh
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DOTFILES_DIR"

echo "==> Pulling latest..."
git pull --ff-only origin main

echo "==> Re-stowing packages..."
for pkg in fish ghostty claude agents; do
    stow -v --target="$HOME" --adopt "$pkg" 2>&1 | grep -E "LINK|MV" || true
done

echo "==> Syncing agent skill symlinks..."
mkdir -p "$HOME/.claude/skills"
for skill_dir in "$DOTFILES_DIR"/agents/.agents/skills/*/; do
    skill="$(basename "$skill_dir")"
    ln -sfn "$HOME/.agents/skills/$skill" "$HOME/.claude/skills/$skill"
done

echo "==> Installing MCP servers..."
"$DOTFILES_DIR/scripts/setup-mcp.sh"

echo "==> Installing plugins..."
MARKETPLACES_JSON="$DOTFILES_DIR/claude/.claude/plugins/known_marketplaces.json"
PLUGINS_JSON="$DOTFILES_DIR/claude/.claude/plugins/installed_plugins.json"
if command -v claude &>/dev/null && [ -f "$MARKETPLACES_JSON" ] && [ -f "$PLUGINS_JSON" ]; then
    python3 -c "
import json, subprocess
with open('$PLUGINS_JSON') as f:
    plugins = json.load(f).get('plugins', {})
with open('$MARKETPLACES_JSON') as f:
    marketplaces = json.load(f)
for plugin_key in plugins:
    parts = plugin_key.split('@')
    if len(parts) != 2: continue
    mp = marketplaces.get(parts[1], {})
    source = mp.get('source', {})
    repo = source.get('repo', source.get('url', ''))
    if repo:
        repo = repo.replace('git@github.com:', '').replace('.git', '')
        print(f'  {plugin_key} from {repo}')
        subprocess.run(['claude', '/install-plugin', plugin_key, '--marketplace', repo], capture_output=True)
" || true
fi

echo "Done."
