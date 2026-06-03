# Implementation of `usemodel` for fish. Not meant to be sourced directly —
# source ../config.fish, which loads this. See that file for usage.

# Load a KEY=VALUE file (.env style) into the shell as exported vars.
# Skips comments/blanks, strips surrounding double-quotes, and expands
# ${VAR} references from the environment (matching how bash/zsh source files).
function _litellm_loadenv --argument-names envfile
    test -f $envfile; or return
    for line in (cat $envfile)
        string match -qr '^\s*(#|$)' -- $line; and continue
        string match -q '*=*' -- $line; or continue
        set -l kv (string split -m1 '=' -- $line)
        set -l key (string trim -- $kv[1])
        set -l val (string trim -- $kv[2] | string trim --chars='"')
        while set -l m (string match -r '\$\{(\w+)\}' -- $val)
            set -l name $m[2]
            set -l rep ""
            set -q $name; and set rep $$name
            set val (string replace -- $m[1] $rep $val)
        end
        set -gx $key $val
    end
end

# Repo root is the parent of this lib/ directory.
set -g _litellm_dir (dirname (dirname (status --current-filename)))

# Load API keys from the root .env (the same file docker-compose reads),
# so there's a single source of truth and no keys are hardcoded anywhere.
_litellm_loadenv $_litellm_dir/.env

# Collect every variable name declared by any bundle, so `usemodel` can reset
# exactly those — the bundle .env files are the single source of truth, with
# no hardcoded list to keep in sync.
set -g _litellm_vars
for envfile in $_litellm_dir/models/*/.env
    test -f $envfile; or continue
    for line in (cat $envfile)
        string match -qr '^\s*(#|$)' -- $line; and continue
        string match -q '*=*' -- $line; or continue
        set -l key (string trim -- (string split -m1 '=' -- $line)[1])
        contains -- $key $_litellm_vars; or set -a _litellm_vars $key
    end
end

function usemodel
    set -l model $argv[1]

    # Reset every var any bundle could set, so each switch starts from a clean
    # slate (this is also exactly what `default` does — back to native Anthropic).
    set -q _litellm_vars[1]; and set -e $_litellm_vars

    switch $model
        case default ''
            return 0
        case '*'
            set -l envfile $_litellm_dir/models/$model/.env
            if not test -f $envfile
                set -l avail default
                for d in $_litellm_dir/models/*/.env
                    set -a avail (basename (dirname $d))
                end
                echo "Unknown model: $model. Available: "(string join ', ' $avail) >&2
                return 1
            end
            _litellm_loadenv $envfile
    end

    # A bundle that references a secret (e.g. ANTHROPIC_AUTH_TOKEN=${DEEPSEEK_API_KEY})
    # ends up empty if that key isn't in .env — flag it instead of failing silently.
    if test -z "$ANTHROPIC_AUTH_TOKEN"
        echo "Warning: bundle '$model' has an empty ANTHROPIC_AUTH_TOKEN — is its key set in .env (see .env.example)?" >&2
    end
end
