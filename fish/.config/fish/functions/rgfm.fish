function rgfm
    set -l search_term $argv[1]
    set -l search_dir $argv[2]

    if test -z "$search_term" -o -z "$search_dir"
        echo "Usage: rgfm <search_term> <directory>"
        return 1
    end

    rg --files-with-matches "$search_term" "$search_dir" 2>/dev/null
end
