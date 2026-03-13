# Provider & Environment Variable Reference

[日本語版](providers_ja.md) | [← Back to top](../README.md)

---

## Table of Contents

1. [AI / LLM Providers](#ai--llm-providers)
2. [Messaging Platforms](#messaging-platforms)
3. [Web Search Providers](#web-search-providers)
4. [Browser Automation & Media](#browser-automation--media)
5. [OpenClaw System Variables](#openclaw-system-variables)
6. [.env Configuration Examples](#env-configuration-examples)

---

## AI / LLM Providers

### Major Providers

| Provider | Environment Variable | Adapter | Notes |
|---|---|---|---|
| **Anthropic Claude** | `ANTHROPIC_API_KEY` | `anthropic-messages` | Claude 3.5 / Opus / Sonnet / Haiku |
| **OpenAI** | `OPENAI_API_KEY` | `openai-completions` | GPT-4o, GPT-4, o1, etc. |
| **Google Gemini** | `GOOGLE_API_KEY` or `GEMINI_API_KEY` | `google-generative-ai` | Gemini Pro / Flash / Ultra |
| **Groq** | `GROQ_API_KEY` | Native | Ultra-fast inference |
| **MiniMax** | `MINIMAX_API_KEY` | `anthropic-messages` | Base URL: `https://api.minimax.io/anthropic` |

### Regional Providers (Asia)

| Provider | Environment Variable | Adapter | Base URL |
|---|---|---|---|
| **Moonshot (Kimi)** | `MOONSHOT_API_KEY` or `KIMI_API_KEY` | `openai-completions` | `https://api.moonshot.ai/v1` |
| **Qwen** | `QWEN_API_KEY` | Native | Alibaba Cloud |
| **Qianfan** | `QIANFAN_API_KEY` | Native | Baidu |
| **GLM** | `GLM_API_KEY` | Native | Zhipu AI |
| **Z.AI** | `ZAI_API_KEY` | `openai-completions` | `https://api.z.ai/api/coding/paas/v4` |
| **Xiaomi MiMo** | `MIMO_API_KEY` | Native | Xiaomi |

### Gateway / Aggregator Providers

| Provider | Environment Variable | Description |
|---|---|---|
| **OpenRouter** | `OPENROUTER_API_KEY` | Gateway to 100+ models (Llama, Mistral, Claude, etc.) |
| **Together** | `TOGETHER_API_KEY` | Open-source model hosting |
| **Hugging Face** | `HUGGINGFACE_API_KEY` | Open-source model inference API |
| **Cerebras** | `CEREBRAS_API_KEY` | Fast inference (Base URL: `https://api.cerebras.ai/v1`) |

### Specialized Providers

| Provider | Environment Variable | Description |
|---|---|---|
| **Synthetic** | `SYNTHETIC_API_KEY` | `anthropic-messages` adapter. URL: `https://api.synthetic.new/anthropic` |
| **Venice AI** | `VENICE_API_KEY` | Privacy-focused inference |
| **Perplexity Sonar** | `PERPLEXITY_API_KEY` | Search-integrated AI |
| **OpenCode Zen** | `OPENCODE_API_KEY` | Code-specialized |

### Cloud & Self-Hosted

| Provider | Environment Variable | Notes |
|---|---|---|
| **Amazon Bedrock** | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` | Uses AWS credentials |
| **Ollama** | None required | Local. `baseUrl: http://localhost:11434` |
| **vLLM** | None required | Self-hosted endpoint |
| **LM Studio** | None required | Local. `openai-responses` adapter |

---

## Messaging Platforms

### Configurable via Environment Variables

| Platform | Environment Variable(s) | Notes |
|---|---|---|
| **Slack** | `SLACK_BOT_TOKEN` (`xoxb-...`), `SLACK_APP_TOKEN` (`xapp-...`) | Bot + App-Level Token |
| **Discord** | `DISCORD_BOT_TOKEN` | Bot Token |
| **Telegram** | `TELEGRAM_BOT_TOKEN` | From BotFather |
| **LINE** | `LINE_CHANNEL_ACCESS_TOKEN`, `LINE_CHANNEL_SECRET` | LINE Developers Console |
| **Matrix** | `MATRIX_HOMESERVER`, `MATRIX_ACCESS_TOKEN`, `MATRIX_USER_ID`, `MATRIX_PASSWORD` | Homeserver URL + auth |
| **Mattermost** | `MATTERMOST_BOT_TOKEN`, `MATTERMOST_URL` | Bot Token + server URL |
| **Feishu** | `FEISHU_APP_ID`, `FEISHU_APP_SECRET` | App ID + Secret |
| **Twitch** | `OPENCLAW_TWITCH_ACCESS_TOKEN` | OAuth Token (`oauth:` prefix) |
| **Zalo** | `ZALO_BOT_TOKEN` | Bot Token |
| **Nostr** | `NOSTR_PRIVATE_KEY` | nsec or hex format |
| **IRC** | `IRC_HOST`, `IRC_PORT`, `IRC_TLS`, `IRC_NICK`, `IRC_PASSWORD`, `IRC_CHANNELS` | Multiple variables |

### Config File Only (openclaw.json)

| Platform | Auth Method | Notes |
|---|---|---|
| **WhatsApp** | QR code scan + CLI | Stored in `~/.openclaw/credentials/whatsapp/` |
| **Signal** | via `signal-cli` | Requires signal-cli on gateway host |
| **iMessage** | via `imsg` CLI | macOS only |
| **Google Chat** | OAuth | Google Workspace integration |
| **Microsoft Teams** | OAuth | Azure AD integration |
| **BlueBubbles** | `serverUrl`, `password` | Config file only |
| **Nextcloud Talk** | URL + credentials | Config file only |
| **Synology Chat** | Token-based | Config file only |

---

## Web Search Providers

Auto-detected when the environment variable is set.

| Provider | Environment Variable | Notes |
|---|---|---|
| **Brave Search** | `BRAVE_API_KEY` | Privacy-focused |
| **Perplexity** | `PERPLEXITY_API_KEY` | AI-powered search |
| **Google Gemini** | `GEMINI_API_KEY` | Shared with LLM key |
| **Grok (X.AI)** | `XAI_API_KEY` | X/Twitter integration |
| **Kimi** | `KIMI_API_KEY` or `MOONSHOT_API_KEY` | Alternative search |

---

## Browser Automation & Media

### Browser Automation

| Service | Environment Variable | Notes |
|---|---|---|
| **Browserless** | `BROWSERLESS_API_KEY` | Via CDP URL parameter |
| **Browserbase** | `BROWSERBASE_API_KEY` | Via WSS connection |

### Web Content Extraction

| Service | Environment Variable | Notes |
|---|---|---|
| **Firecrawl** | `FIRECRAWL_API_KEY` | Fallback for complex sites |
| **Readability** | None required | Built-in (primary) |

### Audio & Media

| Service | Environment Variable | Notes |
|---|---|---|
| **ElevenLabs TTS** | `ELEVENLABS_API_KEY` or `XI_API_KEY` | Text-to-speech |
| **Deepgram** | `DEEPGRAM_API_KEY` | Speech-to-text |

---

## OpenClaw System Variables

### Gateway Configuration

| Variable | Description | Default |
|---|---|---|
| `OPENCLAW_GATEWAY_TOKEN` | Gateway auth token | Auto-generated |
| `OPENCLAW_GATEWAY_PASSWORD` | Gateway HTTP Basic auth | None |
| `OPENCLAW_HOME` | Home directory override | `~/.openclaw` |
| `OPENCLAW_STATE_DIR` | Mutable state location | `$OPENCLAW_HOME` |
| `OPENCLAW_CONFIG_PATH` | Config file path | `$OPENCLAW_HOME/openclaw.json` |

### Telegram Network (Optional)

| Variable | Description |
|---|---|
| `OPENCLAW_TELEGRAM_DISABLE_AUTO_SELECT_FAMILY` | Disable network family auto-select (`1`) |
| `OPENCLAW_TELEGRAM_ENABLE_AUTO_SELECT_FAMILY` | Enable network family auto-select (`1`) |
| `OPENCLAW_TELEGRAM_DNS_RESULT_ORDER` | DNS ordering (e.g., `ipv4first`) |

---

## .env Configuration Examples

### Minimal (Ollama only)

```env
OLLAMA_DEFAULT_MODEL=llama3.2
OPENCLAW_AUTH_MODE=token
TZ=Asia/Tokyo
```

### Anthropic + Ollama

```bash
# Store API key in secrets/
echo "sk-ant-api03-xxxxxxxxxxxxx" > secrets/ANTHROPIC_API_KEY
```

```env
# .env
OLLAMA_DEFAULT_MODEL=llama3.2
OPENCLAW_AUTH_MODE=token
TZ=Asia/Tokyo
```

### Multi-Provider

```bash
# Store API keys and tokens in secrets/
echo "sk-ant-api03-xxxxxxxxxxxxx" > secrets/ANTHROPIC_API_KEY
echo "sk-xxxxxxxxxxxxx"          > secrets/OPENAI_API_KEY
echo "AIzaSy-xxxxxxxxxxxxx"      > secrets/GEMINI_API_KEY
echo "gsk_xxxxxxxxxxxxx"         > secrets/GROQ_API_KEY
echo "123456:ABCdef-xxxxxxxxxxxxx" > secrets/TELEGRAM_BOT_TOKEN
echo "xoxb-xxxxxxxxxxxxx"        > secrets/SLACK_BOT_TOKEN
echo "xapp-xxxxxxxxxxxxx"        > secrets/SLACK_APP_TOKEN
echo "xxxxxxxxxxxxx"             > secrets/DISCORD_BOT_TOKEN
echo "BSA-xxxxxxxxxxxxx"         > secrets/BRAVE_API_KEY
```

```env
# .env — non-secret configuration only
# --- Security ---
OPENCLAW_AUTH_MODE=token
OPENCLAW_AUTH_TOKEN=
OPENCLAW_DENY_TOOLS=exec,browser,cron

# --- Ollama ---
OLLAMA_DEFAULT_MODEL=llama3.2
OLLAMA_NUM_PARALLEL=2

TZ=Asia/Tokyo
```

### Enterprise (Proxy + Bedrock)

```bash
# Store AWS credentials in secrets/
echo "AKIA-xxxxxxxxxxxxx" > secrets/AWS_ACCESS_KEY_ID
echo "xxxxxxxxxxxxx"      > secrets/AWS_SECRET_ACCESS_KEY
```

```env
# .env
# --- AWS Bedrock ---
AWS_REGION=ap-northeast-1

# --- Proxy ---
HTTP_PROXY=http://proxy.corp.example.com:8080
HTTPS_PROXY=http://proxy.corp.example.com:8080
NO_PROXY=localhost,127.0.0.1,ollama

# --- Security ---
OPENCLAW_AUTH_MODE=token
OPENCLAW_DENY_TOOLS=exec,browser,cron

TZ=Asia/Tokyo
```

---

## How .env Works in Docker

The `env_file: .env` directive in `docker-compose.yml` passes variables from `.env` into the container. API keys placed in `secrets/` are loaded by `entrypoint.sh` at startup.

```
secrets/ files (recommended for API keys)
  ↓ entrypoint.sh exports at startup
All .env variables
  ↓ env_file (automatic pass-through)
OpenClaw container
  ↑ environment: overrides only a few Docker-specific values
  │  OPENCLAW_GATEWAY_BIND (0.0.0.0 inside container)
  │  OLLAMA_BASE_URL (Docker internal DNS: http://ollama:11434)
```

> **Note**: If the same variable exists in both `secrets/` and `.env`, `secrets/` takes priority.

Any `*_BASE_URL` variable set in `.env` (e.g., `MOONSHOT_BASE_URL`, `CEREBRAS_BASE_URL`) is **passed directly to OpenClaw** inside the container. API keys should be placed in the `secrets/` directory for better security.

### Exception: OLLAMA_BASE_URL

`OLLAMA_BASE_URL` is force-overridden to `http://ollama:11434` (Docker internal network) in `docker-compose.yml`. This is because the Ollama container is accessed via Docker's internal DNS. This override does not apply in native installations.

### Providers That Require a Base URL

These providers need both an API key AND a Base URL.
**Both must be set for the provider to work.** If only one is configured, a WARNING is shown at container startup.

| Provider | API Key Variable | Base URL Variable | Value |
|---|---|---|---|
| MiniMax | `MINIMAX_API_KEY` | `MINIMAX_BASE_URL` | `https://api.minimax.io/anthropic` |
| Moonshot / Kimi | `MOONSHOT_API_KEY` | `MOONSHOT_BASE_URL` | `https://api.moonshot.ai/v1` |
| Z.AI | `ZAI_API_KEY` | `ZAI_BASE_URL` | `https://api.z.ai/api/coding/paas/v4` |
| Cerebras | `CEREBRAS_API_KEY` | `CEREBRAS_BASE_URL` | `https://api.cerebras.ai/v1` |
| Synthetic | `SYNTHETIC_API_KEY` | `SYNTHETIC_BASE_URL` | `https://api.synthetic.new/anthropic` |
| GLM / Zhipu | `GLM_API_KEY` | `GLM_BASE_URL` | `https://open.bigmodel.cn/api/paas/v4` |
| Qwen | `QWEN_API_KEY` | `QWEN_BASE_URL` | `https://dashscope.aliyuncs.com/compatible-mode/v1` |
| Together | `TOGETHER_API_KEY` | `TOGETHER_BASE_URL` | `https://api.together.xyz/v1` |

#### How to configure (secrets/ + .env split)

API keys are secrets — store them in `secrets/`. Base URLs are public configuration — set them in `.env`.

```bash
# Example: Using Z.AI

# 1. API key → secrets/
echo "your-zai-api-key" > secrets/ZAI_API_KEY

# 2. Base URL → .env (uncomment or add)
ZAI_BASE_URL=https://api.z.ai/api/coding/paas/v4
```

> All Base URLs are pre-filled in `.env.example` as comments. Just uncomment the ones you need.

> **Startup check**: `entrypoint.sh` validates API key / Base URL pairs and shows a WARNING if only one side is configured.

---

## Configuration Precedence

OpenClaw reads environment variables in this order (highest priority first):

1. `secrets/` directory files (`entrypoint.sh` exports at startup)
2. `docker-compose.yml` `environment:` section (Docker-specific overrides)
3. `.env` file (via `env_file:`)
4. Process environment variables
5. Config file (`openclaw.json`) blocks

Use template syntax `"${VARIABLE_NAME}"` in config files to reference `.env` values.

---

## Notes

- **Multi-account**: Environment variables apply to the default account only. Use `~/.openclaw/openclaw.json` for multiple accounts.
- **Auth profiles**: Support both API key and OAuth token authentication with fallback and rotation. Stored in `~/.openclaw/agents/<agentId>/agent/auth-profiles.json`.
- **Official docs**: For the latest provider information, see https://docs.openclaw.ai/gateway/configuration-reference

---

[← Setup Guide](setup-guide_en.md) | [Security](security_en.md) | [← Back to top](../README.md)
