#!/usr/bin/env bash
# dotfiles-sync.sh — watches the dotfiles repo for changes and auto-commits/pushes.
# Run via launchd (see install.sh) or manually: ./scripts/dotfiles-sync.sh

set -euo pipefail

DOTFILES_DIR="$HOME/projects/dotfiles"
LOCK_FILE="/tmp/dotfiles-sync.lock"
LOG_FILE="$HOME/.local/share/dotfiles-sync.log"

mkdir -p "$(dirname "$LOG_FILE")"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

cleanup() { rm -f "$LOCK_FILE"; }
trap cleanup EXIT

# Debounce: wait a moment after the last change to batch related edits
commit_changes() {
    # Acquire lock
    if [ -f "$LOCK_FILE" ]; then
        return
    fi
    touch "$LOCK_FILE"

    cd "$DOTFILES_DIR"

    # Stage all changes
    /opt/homebrew/bin/git add -A

    # Check if there's anything to commit
    if /opt/homebrew/bin/git diff-index --quiet HEAD 2>/dev/null; then
        rm -f "$LOCK_FILE"
        return
    fi

    # Safety: abort if a secret-looking string is staged
    if /opt/homebrew/bin/git diff --cached --unified=0 | grep -qiE '(sk-|api[_-]?key|secret|password|token).*=.*[A-Za-z0-9]{20}'; then
        log "WARNING: possible secret detected in staged changes — skipping commit"
        /opt/homebrew/bin/git reset HEAD
        rm -f "$LOCK_FILE"
        return
    fi

    /opt/homebrew/bin/git commit -m "auto: $(date '+%Y-%m-%d %H:%M:%S')"
    log "Committed changes"

    # Push if remote exists
    if /opt/homebrew/bin/git remote get-url origin &>/dev/null; then
        /opt/homebrew/bin/git push origin main 2>>"$LOG_FILE" && log "Pushed to origin" || log "Push failed"
    fi

    rm -f "$LOCK_FILE"
}

SYNC_MCP="$DOTFILES_DIR/scripts/sync-mcp.sh"

log "Starting dotfiles watcher on $DOTFILES_DIR"

# Watch ~/.claude.json for MCP changes — run sync-mcp.sh, then commit
/opt/homebrew/bin/fswatch -0 \
    --latency 5 \
    "$HOME/.claude.json" | while read -d "" event; do
    log "Detected change in ~/.claude.json — syncing MCP servers"
    "$SYNC_MCP" >> "$LOG_FILE" 2>&1 || log "sync-mcp.sh failed"
    commit_changes
done &

# Watch the dotfiles repo itself for config changes
/opt/homebrew/bin/fswatch -0 --recursive \
    --latency 5 \
    --exclude '\.git/' \
    --exclude '\.swp$' \
    --exclude '~$' \
    --exclude '\.DS_Store' \
    "$DOTFILES_DIR" | while read -d "" event; do
    commit_changes
done
