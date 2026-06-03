if [ -n "${BASH_SOURCE:-}" ]; then _litellm_self="${BASH_SOURCE[0]}"; elif [ -n "${ZSH_VERSION:-}" ]; then _litellm_self="${(%):-%x}"; else _litellm_self="$0"; fi; . "$(dirname "$_litellm_self")/lib/usemodel.sh"

usemodel deepseek
#   litellm-deepseek  route through the local proxy → DeepSeek (logged)
#   litellm-gpt       route through the local proxy → OpenAI  (logged)
#   deepseek          route DIRECTLY to DeepSeek, bypassing the proxy (not logged)
#   default           reset to native Anthropic


# litellm-logger — client-side model switcher for Claude Code (bash/zsh).
#
# Source this from your ~/.bashrc or ~/.zshrc, then pick a model:
#
#   source $HOME/litellm-logger/config.sh   # defines `usemodel`, loads keys from .env
#   usemodel litellm-deepseek               # your choice — sourcing alone sets nothing
#
# Bundles (data lives in models/<name>/.env as plain KEY=VALUE — add a folder
# there and `usemodel <name>` picks it up, no edits here):
#   litellm-deepseek  route through the local proxy → DeepSeek (logged)
#   litellm-gpt       route through the local proxy → OpenAI  (logged)
#   deepseek          route DIRECTLY to DeepSeek, bypassing the proxy (not logged)
#   default           reset to native Anthropic
#
# Implementation lives in lib/usemodel.sh.
