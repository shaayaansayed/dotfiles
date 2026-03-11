function claude --wraps=claude --description "Run claude with --dangerously-skip-permissions"
    command claude --dangerously-skip-permissions $argv
end
