#!/usr/bin/env bash
# setup-mcp.sh — install MCP servers from mcp-servers.json
# Reads env vars for secrets (set them in secrets.fish first)
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MCP_FILE="$DOTFILES_DIR/claude/mcp-servers.json"

if ! command -v claude &>/dev/null; then
    echo "Claude Code not installed — skipping MCP setup"
    exit 0
fi

if [ ! -f "$MCP_FILE" ]; then
    echo "No mcp-servers.json found"
    exit 1
fi

echo "==> Installing MCP servers..."

# Substitute env vars in the template and parse
RESOLVED=$(envsubst < "$MCP_FILE")

echo "$RESOLVED" | python3 -c "
import json, sys, subprocess

servers = json.load(sys.stdin)
for name, config in servers.items():
    server_type = config.get('type', 'http')
    url = config.get('url', '')

    # Skip if env vars weren't resolved
    if '\${' in url:
        print(f'  SKIP {name} — unresolved env vars in URL (set secrets first)')
        continue

    cmd = ['claude', 'mcp', 'add', name, '--transport', server_type, url]

    # Add headers if present
    headers = config.get('headers', {})
    for key, val in headers.items():
        if '\${' in val:
            print(f'  SKIP {name} — unresolved env var in header {key}')
            continue
        cmd.extend(['--header', f'{key}: {val}'])

    print(f'  Adding {name} ({server_type}: {url[:60]}...)')
    subprocess.run(cmd, capture_output=True)

print('Done.')
"
