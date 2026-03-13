<p align="center">
  <h1 align="center">openclaw-easy-setup</h1>
  <p align="center">
    OpenClaw + Ollama を Docker でワンコマンドセットアップ<br>
    <em>One-command Docker setup for OpenClaw + Ollama</em>
  </p>
</p>

<p align="center">
  <a href="docs/setup-guide_ja.md">日本語ガイド</a> ·
  <a href="docs/setup-guide_en.md">English Guide</a> ·
  <a href="docs/security_ja.md">セキュリティ</a> ·
  <a href="docs/architecture.md">Architecture</a>
</p>

---

## What is this?

OpenClaw のセットアップを簡単にするツールキットです。
A toolkit that simplifies OpenClaw setup with security-hardened defaults.

| Component | Role |
|-----------|------|
| **[OpenClaw](https://github.com/openclaw/openclaw)** | Self-hosted AI assistant platform (WhatsApp, Telegram, Slack, Discord…) |
| **[Ollama](https://ollama.com)** | Local LLM inference — no API key needed |
| **[ClawX](https://github.com/ValueCell-ai/ClawX)** | Desktop GUI for OpenClaw (optional) |

## Quick Start

```bash
git clone https://github.com/zephel01/openclaw-easy-setup.git
cd openclaw-easy-setup

# 1. Configure
cp .env.example .env
# Set API keys in secrets/ (recommended) or leave empty for Ollama-only
echo "sk-ant-api03-xxxxx" > secrets/ANTHROPIC_API_KEY

# 2. Run
chmod +x setup.sh
./setup.sh                  # OpenClaw + Ollama (Docker)
./setup.sh --with-clawx     # + ClawX desktop app
```

Windows の場合 / On Windows:
```powershell
.\setup.ps1                 # WSL2 + Docker
.\setup.ps1 -WithClawX      # + ClawX
```

> 3分ほどで OpenClaw + Ollama が起動します。
> OpenClaw + Ollama will be running in about 3 minutes.

## CLI Options

```
./setup.sh [OPTIONS]

  --with-clawx        Install ClawX desktop GUI
  --without-ollama    Skip Ollama
  --native            Install without Docker
  --doctor            Run diagnostics
  --uninstall         Remove containers
  --config FILE       Custom config file
  -h, --help          Show help
```

## After Setup

```bash
docker compose ps                              # Status
docker compose logs -f                         # Logs
docker compose exec ollama ollama pull llama3.2 # Pull model
docker compose exec ollama ollama run llama3.2  # Chat
```

## Security Defaults

このセットアップはセキュリティを最優先に設計されています。
詳細は [docs/security_ja.md](docs/security_ja.md) を参照してください。

- Ports bound to `127.0.0.1` only — never exposed externally
- Container: `no-new-privileges`, `read_only`, `cap_drop: ALL`
- Token authentication enforced
- Dangerous tools (`exec`, `browser`, `cron`) denied by default
- `.env` file permissions set to `600`

## Documentation

| Document | 日本語 | English |
|----------|--------|---------|
| Setup Guide | [docs/setup-guide_ja.md](docs/setup-guide_ja.md) | [docs/setup-guide_en.md](docs/setup-guide_en.md) |
| Security | [docs/security_ja.md](docs/security_ja.md) | [docs/security_en.md](docs/security_en.md) |
| Docker Guide | [docs/docker-guide_ja.md](docs/docker-guide_ja.md) | [docs/docker-guide_en.md](docs/docker-guide_en.md) |
| Providers | [docs/providers_ja.md](docs/providers_ja.md) | [docs/providers_en.md](docs/providers_en.md) |
| Troubleshooting | [docs/troubleshooting_ja.md](docs/troubleshooting_ja.md) | [docs/troubleshooting_en.md](docs/troubleshooting_en.md) |
| Architecture | [docs/architecture.md](docs/architecture.md) | — |

## File Structure

```
openclaw-easy-setup/
├── README.md               ← You are here
├── setup.sh                # Setup script (macOS/Linux)
├── setup.ps1               # Setup script (Windows)
├── docker-compose.yml      # Docker stack definition
├── Dockerfile              # Security-hardened OpenClaw image
├── .env.example            # Environment template
├── config.env              # Script-level configuration
├── config/openclaw/        # OpenClaw config overlay
└── docs/
    ├── architecture.md     # System architecture (Mermaid diagrams)
    ├── setup-guide_ja.md   # Detailed setup guide (JP)
    ├── setup-guide_en.md   # Detailed setup guide (EN)
    ├── security_ja.md      # Security design (JP)
    ├── security_en.md      # Security design (EN)
    ├── docker-guide_ja.md  # Docker operations (JP)
    ├── docker-guide_en.md  # Docker operations (EN)
    ├── providers_ja.md     # Provider & env var reference (JP)
    ├── providers_en.md     # Provider & env var reference (EN)
    ├── troubleshooting_ja.md
    └── troubleshooting_en.md
```

## License

MIT — See [LICENSE](LICENSE) for details.
OpenClaw and ClawX follow their respective repository licenses.
