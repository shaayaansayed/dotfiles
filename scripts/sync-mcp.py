#!/usr/bin/env python3
"""Extract MCP servers from ~/.claude.json into a dotfiles-safe template.
Replaces known secret values with ${ENV_VAR} references."""

import json
import os
import re
import sys

CLAUDE_JSON = os.path.expanduser("~/.claude.json")
DOTFILES_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MCP_FILE = os.path.join(DOTFILES_DIR, "claude", "mcp-servers.json")

if not os.path.exists(CLAUDE_JSON):
    sys.exit(0)

with open(CLAUDE_JSON) as f:
    data = json.load(f)

servers = data.get("mcpServers", {})
if not servers:
    sys.exit(0)

# Build a map of secret values -> env var placeholders from secrets.fish
secrets_map = {}
secrets_file = os.path.expanduser("~/.config/fish/conf.d/secrets.fish")
if os.path.exists(secrets_file):
    with open(secrets_file) as f:
        for line in f:
            line = line.strip()
            if line.startswith("#") or not line:
                continue
            m = re.match(r'set\s+-gx\s+(\w+)\s+["\']?([^"\']+)["\']?', line)
            if m:
                key, val = m.group(1), m.group(2)
                if len(val) > 8:
                    secrets_map[val] = "${" + key + "}"


def scrub(obj):
    """Recursively replace secret values with env var references."""
    if isinstance(obj, str):
        for secret_val, placeholder in secrets_map.items():
            obj = obj.replace(secret_val, placeholder)
        return obj
    elif isinstance(obj, dict):
        return {k: scrub(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [scrub(v) for v in obj]
    return obj


# Remove local-only servers (localhost/127.0.0.1) — machine-specific
portable = {}
for name, config in servers.items():
    url = config.get("url", "")
    if "127.0.0.1" in url or "localhost" in url:
        continue
    portable[name] = config

scrubbed = scrub(portable)

with open(MCP_FILE, "w") as f:
    json.dump(scrubbed, f, indent=2)
    f.write("\n")

print(f"Synced {len(portable)} MCP servers to mcp-servers.json")
