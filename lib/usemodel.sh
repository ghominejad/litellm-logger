# Implementation of `usemodel` for bash/zsh. Not meant to be sourced directly —
# source ../config.sh, which loads this. See that file for usage.

# Resolve this file's directory (bash or zsh), then the repo root above lib/.
if [ -n "${BASH_SOURCE:-}" ]; then
    _litellm_lib="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [ -n "${ZSH_VERSION:-}" ]; then
    _litellm_lib="$(cd "$(dirname "${(%):-%x}")" && pwd)"
else
    _litellm_lib="$(cd "$(dirname "$0")" && pwd)"
fi
_litellm_dir="$(cd "$_litellm_lib/.." && pwd)"

# Load a KEY=VALUE (.env style) file, exporting every assignment.
# Sourcing expands ${VAR} references the same way the fish loader does manually.
_litellm_loadenv() {
    [ -f "$1" ] || return 0
    set -a
    . "$1"
    set +a
}

# Load API keys from the root .env (the same file docker-compose reads),
# so there's a single source of truth and no keys are hardcoded anywhere.
_litellm_loadenv "$_litellm_dir/.env"

# Collect every variable name declared by any bundle, so `usemodel` can reset
# exactly those — the bundle .env files are the single source of truth, with no
# hardcoded list. Stored as an array so `"${arr[@]}"` splits correctly in both
# bash and zsh (zsh doesn't word-split unquoted scalars).
_litellm_vars=()
for envfile in "$_litellm_dir"/models/*/.env; do
    [ -f "$envfile" ] || continue
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in ''|\#*) continue ;; esac
        case "$line" in *=*) ;; *) continue ;; esac
        key="${line%%=*}"
        key="${key#"${key%%[![:space:]]*}"}"   # ltrim
        key="${key%"${key##*[![:space:]]}"}"   # rtrim
        case " ${_litellm_vars[*]} " in *" $key "*) ;; *) _litellm_vars+=("$key") ;; esac
    done < "$envfile"
done

usemodel() {
    model="$1"

    # Reset every var any bundle could set, so each switch starts from a clean
    # slate (this is also exactly what `default` does — back to native Anthropic).
    [ ${#_litellm_vars[@]} -gt 0 ] && unset "${_litellm_vars[@]}"

    case "$model" in
        default|"")
            return 0 ;;
        *)
            envfile="$_litellm_dir/models/$model/.env"
            if [ ! -f "$envfile" ]; then
                avail="default"
                for d in "$_litellm_dir"/models/*/.env; do
                    [ -f "$d" ] || continue
                    avail="$avail, $(basename "$(dirname "$d")")"
                done
                echo "Unknown model: $model. Available: $avail" >&2
                return 1
            fi
            _litellm_loadenv "$envfile" ;;
    esac

    # A bundle that references a secret (e.g. ANTHROPIC_AUTH_TOKEN=${DEEPSEEK_API_KEY})
    # ends up empty if that key isn't in .env — flag it instead of failing silently.
    if [ -z "${ANTHROPIC_AUTH_TOKEN:-}" ]; then
        echo "Warning: bundle '$model' has an empty ANTHROPIC_AUTH_TOKEN — is its key set in .env (see .env.example)?" >&2
    fi
}
