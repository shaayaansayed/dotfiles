# dotfiles

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/) and auto-synced via fswatch + launchd.

## What's included

| Package   | What it manages                                                        |
|-----------|------------------------------------------------------------------------|
| `fish`    | Fish shell config, abbreviations, functions, completions, theme        |
| `ghostty` | Ghostty terminal config                                                |
| `claude`  | Claude Code settings, plugins, custom commands, and skills             |
| `agents`  | Agent skills (symlinked into `~/.claude/skills/`)                      |

## Quick start

```bash
git clone git@github.com:<you>/dotfiles.git ~/projects/dotfiles
cd ~/projects/dotfiles
./install.sh
```

The install script will:

1. Install Homebrew (if missing) and packages: fish, starship, stow, fswatch, zoxide, atuin, eza, fzf
2. Set fish as the default shell and install Fisher
3. Symlink all configs into place with stow
4. Link agent skills into `~/.claude/skills/`
5. Install Claude Code plugins dynamically from tracked config
6. Install MCP servers from `claude/mcp-servers.json` (secrets resolved from env vars)
7. Start the auto-sync daemon (fswatch + launchd)

## Auto-sync

A background daemon watches this repo for changes. Since stow creates symlinks, editing `~/.config/fish/config.fish` edits the file in the repo directly. On any change:

1. fswatch detects it (5s debounce)
2. Changes are staged and checked for accidental secrets
3. Auto-committed with timestamp
4. Pushed to origin (if remote is set)

Logs: `~/.local/share/dotfiles-sync.log`

### Managing the daemon

```bash
# Stop
launchctl bootout gui/$(id -u)/com.dotfiles.autosync

# Start
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.dotfiles.autosync.plist
```

## Plugins and skills

Nothing is hardcoded in `install.sh`. Everything is read dynamically from the repo:

- **Claude Code plugins** — `install.sh` reads `installed_plugins.json` and `known_marketplaces.json` to determine what to install. When you add or remove a plugin via Claude Code, these files update automatically (they're symlinked) and the auto-sync daemon commits the change.
- **Agent skills** — `install.sh` enumerates `agents/.agents/skills/*/` and symlinks each one into `~/.claude/skills/`. Drop a new skill folder in and it gets picked up.
- **Claude skills** — managed directly by stow from `claude/.claude/skills/`.
- **MCP servers** — defined in `claude/mcp-servers.json` as a template. API keys are referenced as `${EXA_API_KEY}`, `${CONTEXT7_API_KEY}`, etc. and resolved from your environment at install time. To add a new MCP server, either edit `mcp-servers.json` directly or run `claude mcp add` and then update the template.

## Secrets

API keys live in `~/.config/fish/conf.d/secrets.fish` which is gitignored. On a new machine:

```bash
cp ~/.config/fish/conf.d/secrets.fish.example ~/.config/fish/conf.d/secrets.fish
# Then fill in your keys
```

## Structure

```
dotfiles/
├── fish/           # ~/.config/fish/
├── ghostty/        # ~/.config/ghostty/
├── claude/         # ~/.claude/ (settings, commands, skills, plugins)
├── agents/         # ~/.agents/skills/ (symlinked into ~/.claude/skills/)
├── scripts/        # Auto-sync watcher + MCP setup
└── install.sh      # Bootstrap script
```

## Adding a new config

```bash
# Example: track starship config
mkdir -p starship/.config
cp ~/.config/starship.toml starship/.config/
cd ~/projects/dotfiles
stow -v --target="$HOME" --adopt starship
```
