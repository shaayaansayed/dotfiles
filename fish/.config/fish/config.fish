# paths
fish_add_path /opt/homebrew/bin /opt/homebrew/sbin
fish_add_path /Users/ssayed/.local/bin
fish_add_path /Users/ssayed/.opencode/bin
fish_add_path $HOME/.bun/bin
fish_add_path $HOME/google-cloud-sdk/bin

# disable fish greeting
set fish_greeting

# environment
set -gx PYTHONDONTWRITEBYTECODE true
set -gx BUN_INSTALL "$HOME/.bun"

# tool init (guarded)
if type -q starship
    starship init fish | source
end

if type -q atuin
    atuin init fish | source
end

if type -q zoxide
    zoxide init fish --cmd cd | source
end

# prevent idle sleep (lid close still sleeps)
if not pgrep -qx caffeinate
    caffeinate -d &
    disown
end
