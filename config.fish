source (dirname (status --current-filename))/lib/usemodel.fish

usemodel litellm-deepseek
#   litellm-deepseek  route through the local proxy → DeepSeek (logged)
#   litellm-gpt       route through the local proxy → OpenAI  (logged)
#   deepseek          route DIRECTLY to DeepSeek, bypassing the proxy (not logged)
#   default           reset to native Anthropic


# litellm-logger — client-side model switcher for Claude Code (fish).
#
# Source this from your ~/.config/fish/config.fish, then pick a model:
#
#   source $HOME/litellm-logger/config.fish   # defines `usemodel`, loads keys from .env
#
# Bundles (data lives in models/<name>/.env as plain KEY=VALUE — add a folder
# there and `usemodel <name>` picks it up, no edits here):
#   litellm-deepseek  route through the local proxy → DeepSeek (logged)
#   litellm-gpt       route through the local proxy → OpenAI  (logged)
#   deepseek          route DIRECTLY to DeepSeek, bypassing the proxy (not logged)
#   default           reset to native Anthropic
#
# Implementation lives in lib/usemodel.fish.


# Default model selected on source. Change it, or comment this line out to source
# without touching the shell (then call `usemodel <name>` yourself).
