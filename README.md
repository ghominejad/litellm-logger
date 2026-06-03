# litellm-logger

A small, self-hosted [LiteLLM](https://github.com/BerriAI/litellm) proxy that sits between your LLM client (e.g. Claude Code) and providers like Anthropic, DeepSeek, and OpenAI — and can record everything it relays to local JSON. It lets you:

1. **Switch the model** your client talks to without changing the client — point your app at `http://localhost:4000` once, then route to DeepSeek, GPT, or Anthropic behind the scenes.
2. **Log every request/response** to local JSON files for a full record of your conversations. Logging is **on by default** — comment out one line in `litellm-config.yaml` to turn it off (see [Logs](#logs)).

When logging is on, it **de-duplicates the large `tools` payload** across logs using a content-addressed registry — each unique tool schema is stored once and re-versioned only when it changes, so files stay small and greppable.

## Usage at a glance

**1. Start the proxy** — add your keys and bring it up:

```bash
cp .env.example .env      # then fill in your provider API keys
docker compose up -d      # proxy now listening on http://localhost:4000
```

**2a. Any app** — point its API base URL at the proxy:

```text
http://localhost:4000
```

**2b. Claude Code** — point your shell at the proxy, then pick a model:

```bash
source ~/litellm-logger/config.sh   # or config.fish / config.ps1 for your shell
usemodel litellm-deepseek           # route Claude Code → proxy → DeepSeek
usemodel default                    # ← switch back to normal Anthropic, anytime
```

`usemodel` sets the `ANTHROPIC_*` variables Claude Code reads **when it launches**, so start a fresh `claude` after switching. `usemodel default` clears those variables, returning Claude Code to its built-in Anthropic defaults.

That's it — calls now flow through the proxy and land in `./logs`. Details below.

## How it works

```
┌─────────────┐      http://localhost:4000      ┌──────────────┐      ┌───────────┐
│ Claude Code │ ──────────────────────────────▶ │ LiteLLM proxy │ ───▶ │ DeepSeek  │
│ (or any app)│                                  │  + logger     │      │ OpenAI    │
└─────────────┘                                  └──────────────┘      │ Anthropic │
                                                        │              └───────────┘
                                                        ▼
                                                  ./logs/[YYMMDD-HH]/*.json
                                                  ./Logs/Tools/*.json
```

There are **two sides** that are easy to confuse:

| | What it is | Lives in | Needs |
|---|---|---|---|
| **Server** | the logging proxy | `docker-compose.yml`, `custom_logger.py`, `litellm-config.yaml` | your **API keys** (via `.env`) |
| **Client** | pointing your app *at* the proxy | env vars / `config.fish`, `config.sh` + `models/*/.env` | `ANTHROPIC_BASE_URL=http://localhost:4000` |

Your API keys live in a single root `.env`. The proxy reads it (via docker-compose); the client side only needs the proxy URL and a dummy token — **except** the optional direct-DeepSeek bundle, which bypasses the proxy and therefore reads your real `DEEPSEEK_API_KEY` from that same `.env`.

## Project structure

```text
.env                     # your API keys (git-ignored; copy from .env.example)
docker-compose.yml       # runs the LiteLLM proxy + logger
litellm-config.yaml      # server: all model routing + the logging toggle (one file)
custom_logger.py         # the logging callback (writes ./logs when enabled)

config.fish/.sh/.ps1     # entry points you source — pick the one for your shell
lib/usemodel.fish/.sh/.ps1 # implementation behind `usemodel` (plumbing)

models/<name>/.env       # client: ANTHROPIC_* vars `usemodel <name>` loads

logs/                    # per-call JSON logs + tools/ registry (git-ignored)
```

The two things you actually touch day to day are the `usemodel` command and the `models/*/.env` bundle files. The `config.*` files are thin wrappers; the real logic lives in `lib/`.

## Quickstart

### 1. Configure the server

```bash
cp .env.example .env
# edit .env and fill in your provider API keys
```

```bash
docker compose up -d
```

The proxy is now listening on `http://localhost:4000`. Logs appear under `./logs/`.

### 2. Point your client at the proxy

Pick whichever fits your setup — they all do the same thing.

**Option A — set it directly in your app.** If your tool has a setting for the API base URL, just point it at `http://localhost:4000`. No shell config needed.

**Option B — environment variables (Claude Code).** Claude Code reads these env vars; set them in your shell however you like:

| Variable | Example value | Purpose |
|---|---|---|
| `ANTHROPIC_BASE_URL` | `http://localhost:4000` | send traffic to the proxy |
| `ANTHROPIC_AUTH_TOKEN` | `dummy-token` | required by the client; the proxy ignores it |
| `ANTHROPIC_MODEL` | `deepseek-v4-pro` | default model |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | `deepseek-v4-pro` | "opus" tier → this model |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | `deepseek-v4-pro` | "sonnet" tier → this model |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | `deepseek-v4-flash` | "haiku" tier → this model |
| `CLAUDE_CODE_SUBAGENT_MODEL` | `deepseek-v4-flash` | model used for subagents |

bash/zsh:
```bash
export ANTHROPIC_BASE_URL=http://localhost:4000
export ANTHROPIC_AUTH_TOKEN=dummy-token
export ANTHROPIC_MODEL=deepseek-v4-pro
# ...etc
```

**Option C — the `usemodel` helper.** This repo ships a `usemodel` function that flips between preset model bundles in one command. There's a version for each shell — source the one for yours:

```fish
# fish — in ~/.config/fish/config.fish
source $HOME/litellm-logger/config.fish    # defines `usemodel`, loads keys from .env
```

```bash
# bash/zsh — in ~/.bashrc or ~/.zshrc
source $HOME/litellm-logger/config.sh      # defines `usemodel`, loads keys from .env
```

```powershell
# PowerShell — in your $PROFILE (run `$PROFILE` to find it)
. "$HOME/litellm-logger/config.ps1"        # defines `usemodel`, loads keys from .env
```

Sourcing alone sets nothing — you pick the model:

```sh
usemodel litellm-gpt           # route to GPT via the proxy
usemodel litellm-deepseek      # route to DeepSeek via the proxy
usemodel deepseek              # direct to DeepSeek, bypassing the proxy (NOT logged)
usemodel default               # reset to native Anthropic
```

Each bundle's variables live in plain `models/<bundle>/.env` files, so any shell can read them. **Don't want the helper at all?** Load a bundle directly:

```bash
set -a; source models/litellm-gpt/.env; set +a
```

(Only the `default` reset and the direct-`deepseek` key injection need the `usemodel` wrapper.)

> **Windows:** use `config.ps1` for native PowerShell. If you run Claude Code under **WSL**, use `config.sh` instead — it works there unchanged.

## Configuration

### Adding or changing models

Models live on two sides:

- **Server** — all proxied models are defined in one file, `litellm-config.yaml` (the LiteLLM `model_list`). Each entry maps a name you call (e.g. `deepseek-v4-pro`) to a provider, base URL, and key. The proxy serves them all at once, so add a model by adding an entry here — no swapping configs per provider.
- **Client** — each `models/<name>/.env` bundle points Claude Code's tiers (`ANTHROPIC_*`) at one of those model names. `usemodel <name>` loads it.

**To add a client bundle, just create the folder — no code changes.** `usemodel` discovers any `models/<name>/.env` by directory name, so dropping `models/my-bundle/.env` makes `usemodel my-bundle` work immediately (in fish, bash, and zsh). `usemodel` with an unknown name lists what's available.

A bundle can reference a secret from the root `.env` with `${VAR}` — the direct-`deepseek` bundle does this for its auth token:

```sh
ANTHROPIC_AUTH_TOKEN=${DEEPSEEK_API_KEY}
```

The reference is expanded when the bundle loads. If the referenced key isn't set, `usemodel` warns rather than silently sending an empty token.

The server config is mounted in `docker-compose.yml`:

```yaml
volumes:
  - ./litellm-config.yaml:/app/config.yaml
```

> Note: the `deepseek` bundle talks to DeepSeek directly and **skips the proxy, so those calls are not logged**. Use a `litellm-*` bundle if you want everything captured.

### Logs

Logging is **on by default** — every call the proxy relays is written to `./logs`. To disable it, comment out the callback line in `litellm-config.yaml`, then restart the proxy (`docker compose up -d`):

```yaml
litellm_settings:
  callbacks: custom_logger.proxy_logger   # comment out to stop writing logs to ./logs
```

Calls are written to `./logs`:

- Per-call logs: `logs/YYMMDD-HH/<time>_<call_id>.json` — `messages`, `system`, `response`, `model`, `tool_choice`, and a `tools_hash`.
- Tools registry: `logs/tools/<sha256>.json` — each unique tools payload, stored once and referenced by hash. See [docs/decisions.md](docs/decisions.md) for the rationale.

## Security

- **Never commit API keys.** They go in the root `.env`, which is git-ignored. `.env.example` is the committed template.
- `.gitignore` ignores the root `.env` via an anchored `/.env` rule. The non-secret bundle files at `models/*/.env` are **meant to be committed** — don't loosen that rule to a bare `.env`, or those get ignored too.
- The `ANTHROPIC_AUTH_TOKEN` for the proxy bundles is a dummy — the proxy authenticates to providers using the keys in `.env`, not that token. Only the direct-`deepseek` bundle uses your real key client-side.

## License

MIT
