#!/usr/bin/env bash
# install.sh — bootstrap dotfiles on a new machine
# Usage: git clone <repo> ~/projects/dotfiles && cd ~/projects/dotfiles && ./install.sh

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
PLIST_LABEL="com.dotfiles.autosync"
PLIST_DEST="$HOME/Library/LaunchAgents/${PLIST_LABEL}.plist"

echo "==> Dotfiles dir: $DOTFILES_DIR"

# --- Install dependencies ---
if ! command -v brew &>/dev/null; then
    echo "==> Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

echo "==> Installing packages..."
brew install fish starship stow fswatch zoxide atuin eza fzf

# --- Set fish as default shell ---
FISH_PATH="$(which fish)"
if ! grep -qF "$FISH_PATH" /etc/shells; then
    echo "$FISH_PATH" | sudo tee -a /etc/shells
fi
if [ "$SHELL" != "$FISH_PATH" ]; then
    chsh -s "$FISH_PATH"
    echo "==> Default shell set to fish"
fi

# --- Install Fisher ---
fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher' 2>/dev/null || true

# --- Stow packages ---
echo "==> Linking dotfiles with stow..."

# Back up any existing non-symlink configs before stowing
backup_if_exists() {
    local target="$HOME/$1"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        echo "    Backing up $target -> ${target}.bak"
        mv "$target" "${target}.bak"
    fi
}

# Backup existing configs that would conflict
backup_if_exists ".config/fish/config.fish"
backup_if_exists ".config/ghostty/config"
backup_if_exists ".claude/settings.json"
backup_if_exists ".claude/commands"

cd "$DOTFILES_DIR"
stow -v --target="$HOME" fish
stow -v --target="$HOME" ghostty
stow -v --target="$HOME" claude
stow -v --target="$HOME" agents

# --- Recreate symlinks for agent skills in .claude/skills ---
echo "==> Linking agent skills into .claude/skills..."
mkdir -p "$HOME/.claude/skills"
for skill_dir in "$DOTFILES_DIR"/agents/.agents/skills/*/; do
    skill="$(basename "$skill_dir")"
    ln -sfn "$HOME/.agents/skills/$skill" "$HOME/.claude/skills/$skill"
done

# --- Install Claude Code plugins (reads dynamically from tracked configs) ---
MARKETPLACES_JSON="$DOTFILES_DIR/claude/.claude/plugins/known_marketplaces.json"
PLUGINS_JSON="$DOTFILES_DIR/claude/.claude/plugins/installed_plugins.json"

if command -v claude &>/dev/null && [ -f "$MARKETPLACES_JSON" ] && [ -f "$PLUGINS_JSON" ]; then
    echo "==> Installing Claude Code plugins..."
    # Parse each plugin from installed_plugins.json, look up its marketplace repo
    # Format: "plugin_name@marketplace_name" -> marketplace has repo info
    python3 -c "
import json, sys

with open('$PLUGINS_JSON') as f:
    plugins = json.load(f).get('plugins', {})
with open('$MARKETPLACES_JSON') as f:
    marketplaces = json.load(f)

for plugin_key in plugins:
    # plugin_key is like 'obsidian@obsidian-skills'
    parts = plugin_key.split('@')
    if len(parts) != 2:
        continue
    plugin_name, marketplace_name = parts
    mp = marketplaces.get(marketplace_name, {})
    source = mp.get('source', {})
    repo = source.get('repo', source.get('url', ''))
    if repo:
        # Strip git@ prefix and .git suffix for github repos
        repo = repo.replace('git@github.com:', '').replace('.git', '')
        print(f'{plugin_key} {repo}')
" | while read -r plugin_key repo; do
        echo "    Installing $plugin_key from $repo"
        claude /install-plugin "$plugin_key" --marketplace "$repo" 2>/dev/null || true
    done
    echo "    Plugins installed (settings.json already has them enabled)"
elif ! command -v claude &>/dev/null; then
    echo "==> Claude Code not found — install it, then re-run ./install.sh"
fi

# --- Install MCP servers ---
echo "==> Installing MCP servers..."
chmod +x "$DOTFILES_DIR/scripts/setup-mcp.sh"
"$DOTFILES_DIR/scripts/setup-mcp.sh"

# --- Setup secrets template ---
if [ ! -f "$HOME/.config/fish/conf.d/secrets.fish" ]; then
    echo "==> No secrets.fish found. Copy the template and fill in your keys:"
    echo "    cp ~/.config/fish/conf.d/secrets.fish.example ~/.config/fish/conf.d/secrets.fish"
fi

# --- Setup auto-sync ---
echo "==> Setting up auto-sync..."
chmod +x "$DOTFILES_DIR/scripts/dotfiles-sync.sh"

# Unload existing agent if any
launchctl bootout "gui/$(id -u)/$PLIST_LABEL" 2>/dev/null || true

cat > "$PLIST_DEST" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${DOTFILES_DIR}/scripts/dotfiles-sync.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${HOME}/.local/share/dotfiles-sync.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/.local/share/dotfiles-sync.log</string>
</dict>
</plist>
PLIST

launchctl bootstrap "gui/$(id -u)" "$PLIST_DEST"
echo "==> Auto-sync daemon started"

echo ""
echo "Done! Your dotfiles are linked and auto-syncing."
echo "Logs: ~/.local/share/dotfiles-sync.log"
echo ""
echo "Next steps:"
echo "  1. Add your secrets:  cp ~/.config/fish/conf.d/secrets.fish.example ~/.config/fish/conf.d/secrets.fish"
echo "  2. Add git remote:    cd ~/projects/dotfiles && git remote add origin <your-repo-url>"
echo "  3. Push:              git push -u origin main"
