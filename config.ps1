. (Join-Path $PSScriptRoot 'lib/usemodel.ps1')

usemodel deepseek

#   litellm-deepseek  route through the local proxy → DeepSeek (logged)
#   litellm-gpt       route through the local proxy → OpenAI  (logged)
#   deepseek          route DIRECTLY to DeepSeek, bypassing the proxy (not logged)
#   default           reset to native Anthropic


# litellm-logger — client-side model switcher for Claude Code (PowerShell).
#
# Dot-source this from your PowerShell $PROFILE, then pick a model:
#
#   . "$HOME/litellm-logger/config.ps1"   # defines `usemodel`, loads keys from .env
#   usemodel litellm-deepseek             # your choice — sourcing alone sets nothing
#
# (Run `$PROFILE` to find your profile path; create the file if it doesn't exist.)
#
# Bundles (data lives in models/<name>/.env as plain KEY=VALUE — add a folder
# there and `usemodel <name>` picks it up, no edits here):
#   litellm-deepseek  route through the local proxy → DeepSeek (logged)
#   litellm-gpt       route through the local proxy → OpenAI  (logged)
#   deepseek          route DIRECTLY to DeepSeek, bypassing the proxy (not logged)
#   default           reset to native Anthropic
#
# Implementation lives in lib/usemodel.ps1.

