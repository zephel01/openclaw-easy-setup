# Setup Guide (English)

[日本語版](setup-guide_ja.md) | [← Back to top](../README.md)

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Docker Setup (Recommended)](#docker-setup-recommended)
3. [About Docker Paths](#about-docker-paths)
4. [Native Setup](#native-setup)
5. [Windows Setup](#windows-setup)
6. [Installing ClawX](#installing-clawx)
7. [Initial Configuration](#initial-configuration)
8. [config.env Reference](#configenv-reference)
9. [AI Provider Configuration](#ai-provider-configuration)
10. [Updating](#updating)

---

## Prerequisites

### For Docker Setup

| Item | Requirement |
|------|-------------|
| OS | macOS 11+, Ubuntu 20.04+, Windows 10+ (WSL2) |
| Docker | Docker Desktop or Docker Engine 20+ |
| Docker Compose | v2 (bundled with Docker Desktop) |
| RAM | Minimum 4GB / Recommended 8GB+ |
| Disk | 5GB+ free space |
| Network | Internet required for initial setup |

### For Native Setup

In addition to the above:

| Item | Requirement |
|------|-------------|
| Node.js | v22 or higher |
| npm | v9+ (bundled with Node.js) |
| git | Latest version recommended |

### Hardware Guidelines

Memory requirements vary by Ollama model:

| Model Size | Required RAM | Recommended GPU VRAM |
|-----------|-------------|---------------------|
| 2B (llama3.2) | 4GB | Not needed |
| 7B (llama3.2:7b, codellama) | 8GB | 4GB |
| 13B | 16GB | 8GB |
| 70B | 64GB | 40GB+ |

> Models run on CPU when no GPU is available, but inference will be slower.

---

## Docker Setup (Recommended)

### Step 1: Clone the Repository

```bash
git clone https://github.com/zephel01/openclaw-easy-setup.git
cd openclaw-easy-setup
```

### Step 2: Configure Environment Variables and API Keys

```bash
cp .env.example .env
```

#### API Keys (secrets/ directory recommended)

Store API keys and tokens as individual files in the `secrets/` directory.
This prevents exposure via `docker inspect` or environment variable leaks.

```bash
# Anthropic Claude
echo "sk-ant-api03-xxxxx" > secrets/ANTHROPIC_API_KEY

# OpenAI
echo "sk-xxxxx" > secrets/OPENAI_API_KEY

# Ollama only (no API key needed)
# → Skip the above steps
```

> **Note**: You can also set API keys in `.env`, but `secrets/` is more secure.
> See `secrets/README.md` for details.

#### Other Environment Variables (.env)

Edit `.env` with your settings:

```env
# === Optional ===
OPENCLAW_AUTH_TOKEN=
OLLAMA_DEFAULT_MODEL=llama3.2
TZ=Asia/Tokyo
```

### Step 3: Run the Setup Script

```bash
chmod +x setup.sh
./setup.sh
```

The script automatically:

1. Verifies Docker installation (guides you if missing)
2. Validates `.env` and auto-generates auth token
3. Builds the security-hardened Docker image
4. Starts OpenClaw + Ollama containers
5. Pulls the default Ollama model
6. Runs health checks

### Step 4: Verify

```bash
docker compose ps
curl -s http://127.0.0.1:18789/health
curl -s http://127.0.0.1:11434/api/tags
./setup.sh --doctor
```

---

## About Docker Paths

Paths in Dockerfile and entrypoint.sh (e.g., `/home/openclaw/.openclaw`) are **internal to the Docker container**. Since containers always run Linux internally, these paths work correctly regardless of whether your host is macOS, Windows, or Linux.

```
macOS host     → Docker Desktop → Linux container → /home/openclaw/.openclaw ✓
Windows host   → Docker Desktop → Linux container → /home/openclaw/.openclaw ✓
Linux host     → Docker Engine  → Linux container → /home/openclaw/.openclaw ✓
```

Docker volumes (`openclaw-data`, `ollama-models`) abstract away host filesystem differences — you never need to know the host-side storage paths.

> See [Architecture docs](architecture.md#cross-platform-path-strategy--クロスプラットフォームのパス戦略) for details.

---

## Native Setup

To install directly on the host without Docker:

```bash
./setup.sh --native
```

This mode performs:

1. Node.js v22 installation (via fnm or NodeSource)
2. OpenClaw official installer execution
3. Ollama installation + default model download
4. Security-hardened config in `~/.openclaw/`
5. File permission enforcement (700/600)
6. Auth token auto-generation

### Native Mode Data Paths

In native mode, data is stored at `$HOME/.openclaw/`. The `$HOME` variable expands correctly on each OS:

| OS | `$HOME` expands to | Data path |
|----|-------------------|-----------|
| macOS | `/Users/<username>` | `/Users/<username>/.openclaw/` |
| Ubuntu/Debian | `/home/<username>` | `/home/<username>/.openclaw/` |
| Windows (WSL2) | `/home/<username>` | `/home/<username>/.openclaw/` (inside WSL2) |

### Without Ollama

```bash
./setup.sh --native --without-ollama
```

---

## Windows Setup

On Windows, OpenClaw runs via WSL2. ClawX runs natively.

### Prerequisites

- Windows 10 version 2004+ or Windows 11
- Administrator privileges

### Steps

```powershell
# Open PowerShell as Administrator
.\setup.ps1
```

The script automatically:

1. Enables WSL2 (if not configured)
2. Installs Ubuntu WSL2 distribution
3. Installs Node.js and OpenClaw inside WSL2
4. Applies security configuration

### Options

```powershell
.\setup.ps1 -WithClawX
.\setup.ps1 -WithOllama
.\setup.ps1 -WithDocker
.\setup.ps1 -Doctor
.\setup.ps1 -ConfigFile .\my-config.env
```

---

## Installing ClawX

ClawX is a desktop GUI for OpenClaw. It lets you manage AI agents without command-line knowledge.

### Via Setup Script

```bash
# macOS / Linux
./setup.sh --with-clawx

# Windows
.\setup.ps1 -WithClawX
```

### Manual Installation

Download from [ClawX Releases](https://github.com/ValueCell-ai/ClawX/releases):

| OS | File |
|---|---|
| macOS (Apple Silicon) | `ClawX-*-mac-arm64.dmg` |
| macOS (Intel) | `ClawX-*-mac-x64.dmg` |
| Windows | `ClawX-*-win-x64.exe` |
| Linux (x64) | `ClawX-*-linux-x86_64.AppImage` |

### macOS First Launch

If you see "cannot verify the developer":

```
System Settings → Privacy & Security → Click "Open Anyway"
```

### Linux AppImage

```bash
chmod +x ClawX-*.AppImage
# Ubuntu 22.04: sudo apt install libfuse2
# Ubuntu 24.04: sudo apt install libfuse2t64
```

---

## Initial Configuration

### OpenClaw Dashboard

```bash
# Native
openclaw dashboard

# Docker — open in browser
# http://127.0.0.1:18789
```

### Messaging Platform Integration

OpenClaw integrates with: WhatsApp, Telegram, Slack, Discord, Microsoft Teams, LINE, and WeChat. See the official docs at https://openclaw.ai/docs for platform-specific setup.

---

## config.env Reference

| Key | Default | Description |
|-----|---------|-------------|
| `NODE_MAJOR_VERSION` | `22` | Node.js major version |
| `OPENCLAW_INSTALL_METHOD` | `script` | Install method: `script`, `npm`, `docker` |
| `OPENCLAW_VERSION` | (empty=latest) | Pin specific version |
| `OPENCLAW_GATEWAY_BIND` | `loopback` | Bind address |
| `OPENCLAW_GATEWAY_PORT` | `18789` | Gateway port |
| `OPENCLAW_AUTH_MODE` | `token` | Auth: `token` or `none` |
| `OPENCLAW_AUTH_TOKEN` | (auto) | Auth token |
| `OPENCLAW_DM_POLICY` | `pairing` | DM policy: `pairing` or `open` |
| `OPENCLAW_REQUIRE_MENTION` | `true` | Require @mention in groups |
| `OPENCLAW_DENY_TOOLS` | `exec,browser,cron` | Denied tools (comma-separated) |
| `AI_PROVIDER` | (empty) | Provider: `anthropic`, `openai`, `ollama` |
| `INSTALL_CLAWX` | `false` | Install ClawX |
| `VERBOSE` | `false` | Verbose logging |

---

## AI Provider Configuration

### Anthropic Claude

1. Get API key from [Anthropic Console](https://console.anthropic.com/)
2. `echo "sk-ant-api03-xxxxx" > secrets/ANTHROPIC_API_KEY`

### OpenAI

1. Get API key from [OpenAI Platform](https://platform.openai.com/)
2. `echo "sk-xxxxx" > secrets/OPENAI_API_KEY`

### Ollama (Local LLM)

No API key needed. With Docker, the Ollama container starts automatically.

Pull additional models:

```bash
# Docker
docker compose exec ollama ollama pull gemma2
docker compose exec ollama ollama pull codellama

# Native
ollama pull gemma2
```

### Proxy Configuration

For corporate proxy environments, add to `.env`:

```env
HTTP_PROXY=http://proxy.example.com:8080
HTTPS_PROXY=http://proxy.example.com:8080
```

---

## Updating

### Docker

```bash
docker compose pull
docker compose up -d --build
docker compose exec ollama ollama pull llama3.2
```

### Native

```bash
npm update -g openclaw
# macOS: brew upgrade ollama
# Linux: curl -fsSL https://ollama.com/install.sh | sh
```

### ClawX

ClawX has built-in auto-update. For manual updates, download from the [Releases page](https://github.com/ValueCell-ai/ClawX/releases).

---

Next → [Security Design](security_en.md) | [Docker Operations](docker-guide_en.md)
