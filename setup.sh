#!/usr/bin/env bash
# =============================================================================
# openclaw-easy-setup — setup.sh
# Docker-first, security-focused installer for OpenClaw + Ollama (+ optional ClawX)
# Supports: macOS (Intel/Apple Silicon), Ubuntu/Debian Linux
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colours & helpers ────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()   { printf "${GREEN}[✓]${NC} %s\n" "$*"; }
warn()  { printf "${YELLOW}[!]${NC} %s\n" "$*"; }
err()   { printf "${RED}[✗]${NC} %s\n" "$*" >&2; }
info()  { printf "${CYAN}[i]${NC} %s\n" "$*"; }
die()   { err "$*"; exit 1; }

LOG_FILE="${SCRIPT_DIR}/setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# ── Default configuration ────────────────────────────────────────────────────
OPENCLAW_INSTALL_METHOD=docker   # Docker is now the default
OPENCLAW_GATEWAY_BIND=loopback
OPENCLAW_GATEWAY_PORT=18789
OPENCLAW_AUTH_MODE=token
OPENCLAW_AUTH_TOKEN=
OPENCLAW_DM_POLICY=pairing
OPENCLAW_REQUIRE_MENTION=true
OPENCLAW_DENY_TOOLS=exec,browser,cron
AI_PROVIDER=
ANTHROPIC_API_KEY=
OPENAI_API_KEY=
OLLAMA_BASE_URL=http://127.0.0.1:11434
OLLAMA_DEFAULT_MODEL=llama3.2
INSTALL_CLAWX=false
CLAWX_VERSION=
INSTALL_OLLAMA=true              # Ollama enabled by default with Docker
HTTP_PROXY=
HTTPS_PROXY=
VERBOSE=false
NODE_MAJOR_VERSION=22

# ── Parse arguments ──────────────────────────────────────────────────────────
CONFIG_FILE="${SCRIPT_DIR}/config.env"

usage() {
    cat <<'USAGE'
Usage: ./setup.sh [OPTIONS]

Docker-first installer for OpenClaw + Ollama (local LLM).

Options:
  --with-clawx          Also install ClawX desktop GUI
  --without-ollama      Skip Ollama (local LLM) installation
  --native              Install OpenClaw natively (without Docker)
  --config FILE         Path to config.env (default: ./config.env)
  --uninstall           Remove Docker containers and volumes
  --doctor              Run diagnostics only
  --verbose             Enable verbose output
  -h, --help            Show this help

Examples:
  ./setup.sh                          # Docker: OpenClaw + Ollama
  ./setup.sh --with-clawx             # Docker + ClawX desktop app
  ./setup.sh --native                 # Install without Docker
  ./setup.sh --doctor                 # Check system health
USAGE
    exit 0
}

RUN_MODE="install"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --with-clawx)     INSTALL_CLAWX=true; shift ;;
        --without-ollama) INSTALL_OLLAMA=false; shift ;;
        --native)         OPENCLAW_INSTALL_METHOD=script; shift ;;
        --config)         CONFIG_FILE="$2"; shift 2 ;;
        --uninstall)      RUN_MODE="uninstall"; shift ;;
        --doctor)         RUN_MODE="doctor"; shift ;;
        --verbose)        VERBOSE=true; shift ;;
        -h|--help)        usage ;;
        *)                die "Unknown option: $1. Use --help for usage." ;;
    esac
done

# ── Load configuration ───────────────────────────────────────────────────────
if [[ -f "$CONFIG_FILE" ]]; then
    info "Loading configuration from $CONFIG_FILE"
    set -a; source "$CONFIG_FILE"; set +a
fi

# ── OS detection ─────────────────────────────────────────────────────────────
detect_os() {
    local uname_s
    uname_s="$(uname -s)"
    case "$uname_s" in
        Darwin) OS="macos" ;;
        Linux)
            if [[ -f /etc/os-release ]]; then
                . /etc/os-release
                case "$ID" in
                    ubuntu|debian|pop|linuxmint|elementary) OS="debian" ;;
                    *) OS="linux-other"; warn "Untested distribution: $ID" ;;
                esac
            else
                OS="linux-other"
            fi
            ;;
        *) die "Unsupported OS: $uname_s. Use WSL2 on Windows (see setup.ps1)." ;;
    esac

    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64|amd64) ARCH="x64" ;;
        arm64|aarch64) ARCH="arm64" ;;
        *) die "Unsupported architecture: $ARCH" ;;
    esac

    log "Detected: $OS ($ARCH)"
}

# ══════════════════════════════════════════════════════════════════════════════
# DOCKER-BASED INSTALLATION (Primary method)
# ══════════════════════════════════════════════════════════════════════════════

install_docker_engine() {
    if command -v docker &>/dev/null; then
        log "Docker $(docker --version 2>/dev/null | head -1)"
        # Check docker compose
        if docker compose version &>/dev/null; then
            log "Docker Compose $(docker compose version --short 2>/dev/null)"
        elif command -v docker-compose &>/dev/null; then
            log "docker-compose (legacy) detected"
        else
            die "Docker Compose not found. Install Docker Desktop or docker-compose-plugin."
        fi
        return 0
    fi

    info "Docker not found. Installing..."

    case "$OS" in
        macos)
            if command -v brew &>/dev/null; then
                info "Installing Docker Desktop via Homebrew..."
                brew install --cask docker
                log "Docker Desktop installed. Please launch it from Applications."
                warn "After launching Docker Desktop, re-run this script."
                exit 0
            else
                die "Install Docker Desktop from https://www.docker.com/products/docker-desktop/ then re-run."
            fi
            ;;
        debian)
            info "Installing Docker Engine via official repository..."
            sudo apt-get update -qq
            sudo apt-get install -y -qq ca-certificates curl gnupg

            sudo install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg \
                | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
            sudo chmod a+r /etc/apt/keyrings/docker.gpg

            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") \
                $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
                | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

            sudo apt-get update -qq
            sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

            # Add current user to docker group
            sudo usermod -aG docker "$USER" 2>/dev/null || true
            log "Docker Engine installed"
            warn "You may need to log out and back in for group membership to take effect."
            ;;
        *)
            die "Auto-install not supported for $OS. Install Docker manually."
            ;;
    esac
}

setup_env_file() {
    local env_file="${SCRIPT_DIR}/.env"

    if [[ -f "$env_file" ]]; then
        info ".env file already exists — preserving existing configuration"
        return 0
    fi

    info "Creating .env file..."
    cp "${SCRIPT_DIR}/.env.example" "$env_file"

    # Fill in values from config.env or CLI
    if [[ -n "$ANTHROPIC_API_KEY" ]]; then
        sed -i.bak "s|^ANTHROPIC_API_KEY=.*|ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}|" "$env_file" 2>/dev/null || \
        sed -i '' "s|^ANTHROPIC_API_KEY=.*|ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}|" "$env_file"
    fi
    if [[ -n "$OPENAI_API_KEY" ]]; then
        sed -i.bak "s|^OPENAI_API_KEY=.*|OPENAI_API_KEY=${OPENAI_API_KEY}|" "$env_file" 2>/dev/null || \
        sed -i '' "s|^OPENAI_API_KEY=.*|OPENAI_API_KEY=${OPENAI_API_KEY}|" "$env_file"
    fi

    # Generate auth token if not set
    if [[ -z "$OPENCLAW_AUTH_TOKEN" ]]; then
        OPENCLAW_AUTH_TOKEN="$(openssl rand -hex 32 2>/dev/null || head -c 64 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    fi
    sed -i.bak "s|^OPENCLAW_AUTH_TOKEN=.*|OPENCLAW_AUTH_TOKEN=${OPENCLAW_AUTH_TOKEN}|" "$env_file" 2>/dev/null || \
    sed -i '' "s|^OPENCLAW_AUTH_TOKEN=.*|OPENCLAW_AUTH_TOKEN=${OPENCLAW_AUTH_TOKEN}|" "$env_file"

    sed -i.bak "s|^OPENCLAW_AUTH_MODE=.*|OPENCLAW_AUTH_MODE=${OPENCLAW_AUTH_MODE}|" "$env_file" 2>/dev/null || \
    sed -i '' "s|^OPENCLAW_AUTH_MODE=.*|OPENCLAW_AUTH_MODE=${OPENCLAW_AUTH_MODE}|" "$env_file"

    rm -f "${env_file}.bak"

    # Secure file permissions
    chmod 600 "$env_file"
    log ".env created with secure permissions (600)"
    info "Auth token: ${OPENCLAW_AUTH_TOKEN:0:8}...${OPENCLAW_AUTH_TOKEN: -8}"
}

docker_compose_up() {
    info "Starting Docker containers..."
    cd "$SCRIPT_DIR"

    # Build and start
    docker compose build --quiet 2>/dev/null || docker-compose build --quiet

    if [[ "$INSTALL_OLLAMA" == "true" ]]; then
        docker compose up -d 2>/dev/null || docker-compose up -d
        log "All services started (OpenClaw + Ollama)"
    else
        # Start only openclaw, skip ollama
        docker compose up -d openclaw 2>/dev/null || docker-compose up -d openclaw
        log "OpenClaw started (without Ollama)"
    fi

    # Wait for health check
    info "Waiting for services to become healthy..."
    local retries=0
    while (( retries < 30 )); do
        if docker compose ps 2>/dev/null | grep -q "healthy"; then
            break
        fi
        sleep 2
        ((retries++))
    done

    # Show status
    echo ""
    docker compose ps 2>/dev/null || docker-compose ps
    echo ""
}

# ══════════════════════════════════════════════════════════════════════════════
# NATIVE INSTALLATION (Alternative method)
# ══════════════════════════════════════════════════════════════════════════════

install_node() {
    if command -v node &>/dev/null; then
        local current_version
        current_version="$(node -v | sed 's/v//' | cut -d. -f1)"
        if (( current_version >= NODE_MAJOR_VERSION )); then
            log "Node.js v$(node -v | sed 's/v//') (>= $NODE_MAJOR_VERSION)"
            return 0
        fi
    fi

    info "Installing Node.js v${NODE_MAJOR_VERSION}..."
    case "$OS" in
        macos)
            if ! command -v fnm &>/dev/null; then
                curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
                export PATH="$HOME/.local/share/fnm:$PATH"
                eval "$(fnm env)"
            fi
            fnm install "$NODE_MAJOR_VERSION" --lts
            fnm use "$NODE_MAJOR_VERSION"
            fnm default "$NODE_MAJOR_VERSION"
            ;;
        debian)
            sudo mkdir -p /etc/apt/keyrings
            curl -fsSL "https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key" \
                | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg 2>/dev/null
            echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR_VERSION}.x nodistro main" \
                | sudo tee /etc/apt/sources.list.d/nodesource.list >/dev/null
            sudo apt-get update -qq && sudo apt-get install -y -qq nodejs
            ;;
    esac
    log "Node.js v$(node -v | sed 's/v//') installed"
}

install_openclaw_native() {
    info "Installing OpenClaw (native)..."
    curl -fsSL https://openclaw.ai/install.sh | bash
    log "OpenClaw installed"
}

install_ollama_native() {
    if [[ "$INSTALL_OLLAMA" != "true" ]]; then return 0; fi

    if command -v ollama &>/dev/null; then
        log "Ollama already installed: $(ollama --version 2>&1)"
        return 0
    fi

    info "Installing Ollama..."
    case "$OS" in
        macos)
            if command -v brew &>/dev/null; then
                brew install ollama
            else
                curl -fsSL https://ollama.com/install.sh | sh
            fi
            ;;
        debian|linux-other)
            curl -fsSL https://ollama.com/install.sh | sh
            ;;
    esac
    log "Ollama installed"

    info "Pulling default model: $OLLAMA_DEFAULT_MODEL..."
    ollama pull "$OLLAMA_DEFAULT_MODEL" 2>/dev/null || \
        warn "Could not pull model. Run: ollama pull $OLLAMA_DEFAULT_MODEL"
}

harden_native() {
    info "Applying security hardening..."
    local OC_DIR="$HOME/.openclaw"
    mkdir -p "$OC_DIR"

    # .env with API keys
    local ENV_FILE="$OC_DIR/.env"
    {
        echo "# Auto-generated by openclaw-easy-setup — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        [[ -n "$ANTHROPIC_API_KEY" ]] && echo "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY"
        [[ -n "$OPENAI_API_KEY" ]] && echo "OPENAI_API_KEY=$OPENAI_API_KEY"
        echo "OLLAMA_BASE_URL=$OLLAMA_BASE_URL"
    } > "$ENV_FILE"
    chmod 600 "$ENV_FILE"

    # openclaw.json (JSON5 format — OpenClaw native config)
    [[ -z "$OPENCLAW_AUTH_TOKEN" ]] && OPENCLAW_AUTH_TOKEN="$(openssl rand -hex 32)"
    local DENY_TOOLS_JSON
    DENY_TOOLS_JSON=$(IFS=','; for tool in $OPENCLAW_DENY_TOOLS; do printf '"%s", ' "$tool"; done | sed 's/, $//')
    cat > "$OC_DIR/openclaw.json" <<JSON5
{
  // Auto-generated by openclaw-easy-setup
  gateway: {
    bind: "${OPENCLAW_GATEWAY_BIND}",
    port: ${OPENCLAW_GATEWAY_PORT},
    auth: {
      mode: "${OPENCLAW_AUTH_MODE}",
      token: "${OPENCLAW_AUTH_TOKEN}",
    },
  },
  messaging: {
    dmPolicy: "${OPENCLAW_DM_POLICY}",
    requireMention: ${OPENCLAW_REQUIRE_MENTION},
  },
  tools: {
    deny: [${DENY_TOOLS_JSON}],
  },
  security: {
    sandboxInheritEnv: false,
  },
}
JSON5
    chmod 600 "$OC_DIR/openclaw.json"
    chmod 700 "$OC_DIR"
    log "Security config applied (permissions: 700/600)"
}

# ══════════════════════════════════════════════════════════════════════════════
# ClawX INSTALLATION (Optional, always native)
# ══════════════════════════════════════════════════════════════════════════════

install_clawx() {
    if [[ "$INSTALL_CLAWX" != "true" ]]; then
        info "Skipping ClawX (use --with-clawx to enable)"
        return 0
    fi

    info "Installing ClawX desktop app..."
    local release_info
    release_info=$(curl -fsSL "https://api.github.com/repos/ValueCell-ai/ClawX/releases/latest" 2>/dev/null) || {
        warn "Could not fetch ClawX releases. Visit: https://github.com/ValueCell-ai/ClawX/releases"
        return 1
    }

    local download_url="" filename=""
    case "${OS}-${ARCH}" in
        macos-arm64)
            download_url=$(echo "$release_info" | grep -o '"browser_download_url":\s*"[^"]*mac-arm64\.dmg"' | head -1 | cut -d'"' -f4)
            filename="ClawX-mac-arm64.dmg" ;;
        macos-x64)
            download_url=$(echo "$release_info" | grep -o '"browser_download_url":\s*"[^"]*mac-x64\.dmg"' | head -1 | cut -d'"' -f4)
            filename="ClawX-mac-x64.dmg" ;;
        debian-x64|linux-other-x64)
            download_url=$(echo "$release_info" | grep -o '"browser_download_url":\s*"[^"]*\.AppImage"' | head -1 | cut -d'"' -f4)
            filename="ClawX.AppImage" ;;
    esac

    if [[ -z "$download_url" ]]; then
        warn "No ClawX binary for ${OS}-${ARCH}. Visit: https://github.com/ValueCell-ai/ClawX/releases"
        return 1
    fi

    local tmpfile="${TMPDIR:-/tmp}/${filename}"
    curl -fsSL -o "$tmpfile" "$download_url"

    case "$filename" in
        *.dmg)
            local mp
            mp=$(hdiutil attach "$tmpfile" -nobrowse -quiet | tail -1 | awk '{print $3}')
            cp -R "${mp}/ClawX.app" /Applications/ 2>/dev/null && log "ClawX → /Applications/"
            hdiutil detach "$mp" -quiet 2>/dev/null || true ;;
        *.AppImage)
            mkdir -p "$HOME/.local/bin"
            mv "$tmpfile" "$HOME/.local/bin/ClawX.AppImage"
            chmod +x "$HOME/.local/bin/ClawX.AppImage"
            [[ "$OS" == "debian" ]] && sudo apt-get install -y -qq libfuse2 2>/dev/null || true
            log "ClawX → ~/.local/bin/ClawX.AppImage" ;;
    esac
    rm -f "$tmpfile"
}

# ══════════════════════════════════════════════════════════════════════════════
# DOCTOR / DIAGNOSTICS
# ══════════════════════════════════════════════════════════════════════════════

run_doctor() {
    echo ""
    echo "══════════════════════════════════════════"
    echo "  openclaw-easy-setup — Diagnostics"
    echo "══════════════════════════════════════════"
    echo ""

    local issues=0

    # Docker
    if command -v docker &>/dev/null; then
        log "Docker: $(docker --version 2>/dev/null | head -1)"
        if docker compose version &>/dev/null; then
            log "Docker Compose: $(docker compose version --short 2>/dev/null)"
        fi
        # Container status
        cd "$SCRIPT_DIR"
        if [[ -f docker-compose.yml ]]; then
            echo ""
            info "Container status:"
            docker compose ps 2>/dev/null || true
            echo ""
        fi
    else
        warn "Docker: not installed"
    fi

    # Native OpenClaw
    if command -v openclaw &>/dev/null; then
        log "OpenClaw (native): $(openclaw --version 2>/dev/null || echo 'installed')"
    fi

    # Ollama
    if command -v ollama &>/dev/null; then
        log "Ollama (native): $(ollama --version 2>&1 | head -1)"
    fi
    # Check Ollama in Docker
    if docker ps 2>/dev/null | grep -q ollama; then
        log "Ollama (Docker): running"
        local models
        models=$(curl -sf http://127.0.0.1:11434/api/tags 2>/dev/null | grep -o '"name":"[^"]*"' | head -5 || true)
        if [[ -n "$models" ]]; then
            info "Loaded models: $models"
        fi
    fi

    # Port checks
    if curl -sf "http://127.0.0.1:${OPENCLAW_GATEWAY_PORT}/health" &>/dev/null; then
        log "Gateway port $OPENCLAW_GATEWAY_PORT: responding"
    else
        warn "Gateway port $OPENCLAW_GATEWAY_PORT: not responding"
        ((issues++))
    fi

    if curl -sf "http://127.0.0.1:11434/api/tags" &>/dev/null; then
        log "Ollama port 11434: responding"
    else
        warn "Ollama port 11434: not responding"
    fi

    # Security checks
    local env_file="${SCRIPT_DIR}/.env"
    if [[ -f "$env_file" ]]; then
        local perms
        perms=$(stat -f "%Lp" "$env_file" 2>/dev/null || stat -c "%a" "$env_file" 2>/dev/null)
        if [[ "$perms" == "600" ]]; then
            log ".env permissions: $perms (OK)"
        else
            warn ".env permissions: $perms (should be 600)"; ((issues++))
        fi
    fi

    # ClawX
    if [[ -d "/Applications/ClawX.app" ]] || [[ -f "$HOME/.local/bin/ClawX.AppImage" ]]; then
        log "ClawX: installed"
    else
        info "ClawX: not installed (optional)"
    fi

    echo ""
    if (( issues == 0 )); then
        log "All checks passed!"
    else
        warn "$issues issue(s) found."
    fi
    return 0
}

# ══════════════════════════════════════════════════════════════════════════════
# UNINSTALL
# ══════════════════════════════════════════════════════════════════════════════

run_uninstall() {
    warn "This will stop and remove Docker containers."
    read -rp "Continue? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy] ]] || { info "Cancelled."; exit 0; }

    cd "$SCRIPT_DIR"
    docker compose down 2>/dev/null || docker-compose down 2>/dev/null || true
    log "Containers stopped and removed"

    read -rp "Also remove Docker volumes (data will be lost)? [y/N] " confirm_vol
    if [[ "$confirm_vol" =~ ^[Yy] ]]; then
        docker compose down -v 2>/dev/null || docker-compose down -v 2>/dev/null || true
        log "Volumes removed"
    fi

    log "Uninstall complete"
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════

main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║  openclaw-easy-setup v1.0.0                         ║"
    echo "║  Docker-first, security-focused installer           ║"
    echo "║  OpenClaw + Ollama (local LLM) + optional ClawX     ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""

    detect_os

    case "$RUN_MODE" in
        doctor)    run_doctor; exit $? ;;
        uninstall) run_uninstall; exit 0 ;;
    esac

    # Prerequisite: curl
    command -v curl &>/dev/null || die "curl is required."

    if [[ "$OPENCLAW_INSTALL_METHOD" == "docker" ]]; then
        info "Installation method: Docker (recommended)"
        echo ""
        install_docker_engine
        setup_env_file
        docker_compose_up
    else
        info "Installation method: Native"
        echo ""
        install_node
        install_openclaw_native
        install_ollama_native
        harden_native
    fi

    # ClawX (always native)
    install_clawx

    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║  Installation complete!                                 ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""

    if [[ "$OPENCLAW_INSTALL_METHOD" == "docker" ]]; then
        info "Quick reference:"
        echo "  Status:    docker compose ps"
        echo "  Logs:      docker compose logs -f"
        echo "  Stop:      docker compose down"
        echo "  Restart:   docker compose restart"
        echo ""
        echo "  Ollama models:"
        echo "    List:    curl http://127.0.0.1:11434/api/tags"
        echo "    Pull:    docker compose exec ollama ollama pull <model>"
        echo "    Chat:    docker compose exec ollama ollama run llama3.2"
        echo ""
        echo "  Gateway:   http://127.0.0.1:${OPENCLAW_GATEWAY_PORT}"
        echo ""
        info "Security:"
        echo "  - Ports bound to 127.0.0.1 only"
        echo "  - Auth mode: $OPENCLAW_AUTH_MODE"
        echo "  - Container: no-new-privileges, read-only, cap_drop ALL"
        echo "  - Dangerous tools denied: $OPENCLAW_DENY_TOOLS"
    else
        info "Quick reference:"
        echo "  Start:     openclaw up"
        echo "  Status:    openclaw status"
        echo "  Dashboard: openclaw dashboard"
        echo "  Doctor:    openclaw doctor"
    fi

    if [[ "$INSTALL_CLAWX" == "true" ]]; then
        echo ""
        echo "  ClawX: Launch from Applications / ~/.local/bin/ClawX.AppImage"
    fi

    echo ""
    log "Setup log: $LOG_FILE"
    info "Run './setup.sh --doctor' to verify installation."
}

main
