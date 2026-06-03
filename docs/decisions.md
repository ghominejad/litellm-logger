# Decision Log

## 2026-06-03: Prepare for public release — shell-agnostic, data-driven model switching

Restructured the client-side configuration ahead of publishing to GitHub. API keys moved out of the per-model Fish files into a single root `.env` (the same file docker-compose reads), making it the one source of truth; `.gitignore` ignores only the anchored `/.env`, so the non-secret bundle files stay tracked. Each model bundle's `ANTHROPIC_*` variables now live in a plain `models/<name>/.env` (KEY=VALUE) rather than shell-specific config, so any shell — or a human — can read them. The `usemodel` switcher became fully data-driven: it discovers any `models/<name>/.env` by directory name (no hardcoded bundle names), derives the set of variables to reset from those files (a true unset, not empty values), and expands `${VAR}` references so a bundle can pull a secret from the root `.env` (e.g. the direct-DeepSeek auth token). The implementation moved into `lib/usemodel.*`, leaving `config.*` as thin entry points, and the switcher was ported to bash/zsh (`config.sh`) and PowerShell (`config.ps1`) alongside the original Fish. Added `README.md`, `LICENSE` (MIT), and `.env.example`. Logging was also made opt-in: the LiteLLM logging callback is commented out by default in each `models/*/config.yaml` (the headline use is model switching, not log gathering), so enabling it is a one-line uncomment plus a proxy restart — no Python or env-var toggle. The three per-provider server configs were also consolidated into a single root `litellm-config.yaml` that serves all proxied models at once: the proxy no longer needs its mounted config swapped per provider (the client `.env` bundles already select the model name), and the logging toggle lives in one place.

## 2026-05-07: Content-addressed tools registry in logs

The available-tools list was being embedded in every per-call log, dominating file sizes and grep noise. Switched to content-addressed storage: each unique tools payload is now written once to `/app/logs/tools/<sha256>.json`, and per-call logs reference it via a `tools_hash` field. The hash is computed over the canonicalized (sorted-keys, compact) JSON so equivalent payloads always collide.

## 2026-05-06: Support Logging via LiteLLM

Our local development environment uses Claude Code on macOS with the Fish shell. We needed a system to:
1. Log all prompts and responses between Claude Code and the LLM providers locally.
2. Dynamically switch between different AI models (OpenAI GPT, DeepSeek, and native Anthropic) without restarting VSCode or the terminal session.
3. Take advantage of Claude Code's native prompt caching when using third-party models like DeepSeek.



## 2026-05-05: Basic support for OpenAI Models using LiteLLM

