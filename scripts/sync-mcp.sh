#!/usr/bin/env bash
# sync-mcp.sh — extract MCP servers from ~/.claude.json into the dotfiles template
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec python3 "$SCRIPT_DIR/sync-mcp.py"
