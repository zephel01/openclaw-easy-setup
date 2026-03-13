#!/usr/bin/env bash
# =============================================================================
# openclaw-easy-setup — setup-rpi.sh
# Raspberry Pi 5 専用インストーラー
# Docker-first, security-focused installer for OpenClaw + Ollama on RPi 5
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

LOG_FILE="${SCRIPT_DIR}/setup-rpi.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# ── Config file protection helper ──────────────────────────────────────────────
# 既存の設定ファイルを上書きから保護する。
# 戻り値: 0 = 書き込みOK, 1 = スキップ
safe_overwrite_check() {
    local target_file="$1"
    local label="${2:-$(basename "$target_file")}"

    if [[ ! -f "$target_file" ]]; then
        return 0  # ファイルが存在しない — 新規作成OK
    fi

    # 自動生成ファイルかユーザー編集済みか判定
    # Auto-generated ヘッダーがあり、内容が変わっていなければ安全に上書き可能
    local backup_file="${target_file}.bak.$(date +%Y%m%d-%H%M%S)"

    warn "${label} already exists."
    echo ""
    echo "  1) Overwrite (backup current → ${backup_file##*/})"
    echo "  2) Skip (keep existing file)"
    echo "  3) Show diff after generating new version"
    echo ""
    read -rp "Choice [1/2/3] (default: 1): " choice
    choice="${choice:-1}"

    case "$choice" in
        1)
            cp "$target_file" "$backup_file"
            log "Backup created: ${backup_file##*/}"
            return 0
            ;;
        2)
            info "Skipping ${label} — keeping existing file"
            return 1
            ;;
        3)
            # 一旦 .new に書き出して diff を表示、ユーザーに選ばせる
            # 呼び出し元で .new ファイルを生成 → diff → 上書き or スキップ
            cp "$target_file" "$backup_file"
            log "Backup created: ${backup_file##*/}"
            # DIFF_MODE フラグを立てて呼び出し元に通知
            export _SAFE_OVERWRITE_SHOW_DIFF=true
            return 0
            ;;
        *)
            cp "$target_file" "$backup_file"
            log "Backup created: ${backup_file##*/}"
            return 0
            ;;
    esac
}

# ── Default configuration ────────────────────────────────────────────────────
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
OLLAMA_DEFAULT_MODEL=llama3.2:1b
INSTALL_OLLAMA=true
SWAP_SIZE_MB=2048
USE_ZRAM=true
ZRAM_FRACTION=      # auto: determined by RAM size
ZRAM_ALGORITHM=zstd
VERBOSE=false

# ── Parse arguments ──────────────────────────────────────────────────────────
CONFIG_FILE="${SCRIPT_DIR}/config.env"

usage() {
    cat <<'USAGE'
Usage: ./setup-rpi.sh [OPTIONS]

Raspberry Pi 4B/5 インストーラー for OpenClaw + Ollama.

Options:
  --without-ollama      Skip Ollama (local LLM) installation
  --model MODEL         Ollama model to pull (default: llama3.2:1b)
  --swap SIZE_MB        Swap size in MB (default: 2048)
  --no-zram             Disable zram during install
  --zram-on             Enable and activate zram (post-install)
  --zram-off            Disable and deactivate zram (post-install)
  --zram-algo ALGO      zram compression algorithm (default: zstd)
                        Options: zstd, lz4, lzo, lzo-rle
  --config FILE         Path to config.env (default: ./config.env)
  --uninstall           Remove Docker containers and volumes
  --doctor              Run RPi diagnostics only
  --verbose             Enable verbose output
  -h, --help            Show this help

Examples:
  ./setup-rpi.sh                           # Full install: OpenClaw + Ollama
  ./setup-rpi.sh --model llama3.2:3b       # Use 3B parameter model
  ./setup-rpi.sh --without-ollama          # Skip local LLM
  ./setup-rpi.sh --doctor                  # Check RPi health
  ./setup-rpi.sh --swap 4096              # Set 4GB swap for larger models
  ./setup-rpi.sh --no-zram                 # Disk swap only (no zram)
  ./setup-rpi.sh --zram-on                 # Enable zram after install
  ./setup-rpi.sh --zram-off                # Disable zram
USAGE
    exit 0
}

RUN_MODE="install"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --without-ollama) INSTALL_OLLAMA=false; shift ;;
        --model)          OLLAMA_DEFAULT_MODEL="$2"; shift 2 ;;
        --swap)           SWAP_SIZE_MB="$2"; shift 2 ;;
        --no-zram)        USE_ZRAM=false; shift ;;
        --zram-on)        RUN_MODE="zram-on"; shift ;;
        --zram-off)       RUN_MODE="zram-off"; shift ;;
        --zram-algo)      ZRAM_ALGORITHM="$2"; shift 2 ;;
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

# =============================================================================
# PERMISSION & ACCOUNT CHECKS
# =============================================================================

check_permissions() {
    # ── root 実行を防止 ─────────────────────────────────────────────────────
    # root で実行すると、生成されるファイル(.env, docker-compose.rpi.yml 等)が
    # root 所有になり、一般ユーザーから操作できなくなる。
    # また docker グループの判定も正しく動かない。
    if [[ "$EUID" -eq 0 ]]; then
        err "This script should NOT be run as root."
        err ""
        err "  Bad:  sudo ./setup-rpi.sh"
        err "  Good: ./setup-rpi.sh"
        err ""
        err "The script will use 'sudo' internally when elevated privileges are needed."
        err "Running as root can break file ownership and docker group detection."
        die "Please re-run as a normal user."
    fi

    # ── sudo が利用可能か確認 ────────────────────────────────────────────────
    if ! command -v sudo &>/dev/null; then
        die "sudo is required but not installed. Run: su -c 'apt-get install sudo'"
    fi

    # sudo パスワードなしで実行可能か事前チェック（RPi OS デフォルトは NOPASSWD）
    if ! sudo -n true 2>/dev/null; then
        info "sudo may require a password during installation."
    fi

    # ── secrets/ ディレクトリの権限設定 ──────────────────────────────────────
    local secrets_dir="${SCRIPT_DIR}/secrets"
    if [[ -d "$secrets_dir" ]]; then
        local secrets_perms
        secrets_perms=$(stat -c "%a" "$secrets_dir" 2>/dev/null)
        if [[ "$secrets_perms" != "700" ]]; then
            chmod 700 "$secrets_dir"
            log "secrets/ permissions set to 700 (was: $secrets_perms)"
        else
            log "secrets/ permissions: 700 (OK)"
        fi

        # secrets 内のファイルも 600 に設定
        find "$secrets_dir" -type f ! -name "README.md" ! -name ".gitignore" -exec chmod 600 {} \; 2>/dev/null
    fi

    # ── .env が存在する場合、所有者と権限を確認 ─────────────────────────────
    local env_file="${SCRIPT_DIR}/.env"
    if [[ -f "$env_file" ]]; then
        local env_owner env_perms
        env_owner=$(stat -c "%U" "$env_file" 2>/dev/null)
        env_perms=$(stat -c "%a" "$env_file" 2>/dev/null)

        if [[ "$env_owner" == "root" ]]; then
            warn ".env is owned by root (likely from a previous sudo run)."
            warn "Fixing ownership to $USER..."
            sudo chown "$USER:$USER" "$env_file"
        fi

        if [[ "$env_perms" != "600" ]]; then
            chmod 600 "$env_file"
            log ".env permissions fixed: $env_perms → 600"
        fi
    fi

    log "Permission checks passed"
}

# ── Docker グループ再ログイン検出 ────────────────────────────────────────────
# docker グループに追加済みだが、セッションにまだ反映されていないケースを検出
check_docker_group_session() {
    # docker がインストールされていなければスキップ
    command -v docker &>/dev/null || return 0

    # /etc/group に docker グループがあり、ユーザーが含まれているか
    if grep -q "^docker:.*\b${USER}\b" /etc/group 2>/dev/null; then
        # セッション上の groups に docker が含まれているか
        if ! groups 2>/dev/null | grep -qw docker; then
            warn "User '$USER' is in the docker group, but the current session"
            warn "doesn't reflect this yet."
            echo ""
            info "Fix options:"
            echo "  1. Log out and log back in (recommended)"
            echo "  2. Run: newgrp docker && ./setup-rpi.sh"
            echo "  3. Reboot: sudo reboot"
            echo ""
            read -rp "Try 'newgrp docker' now? [Y/n] " try_newgrp
            if [[ ! "$try_newgrp" =~ ^[Nn] ]]; then
                info "Launching new shell with docker group..."
                exec sg docker -c "$0 $*"
            else
                die "Please log out/in and re-run this script."
            fi
        fi
    fi
}

# =============================================================================
# RASPBERRY PI DETECTION & VALIDATION
# =============================================================================

detect_rpi() {
    local model=""
    local mem_total_kb
    local mem_total_mb

    # Check architecture
    local arch
    arch="$(uname -m)"
    if [[ "$arch" != "aarch64" && "$arch" != "arm64" ]]; then
        die "This script is for Raspberry Pi 5 (arm64). Detected: $arch"
    fi

    # Detect Pi model
    if [[ -f /proc/device-tree/model ]]; then
        model="$(tr -d '\0' < /proc/device-tree/model)"
    elif [[ -f /sys/firmware/devicetree/base/model ]]; then
        model="$(tr -d '\0' < /sys/firmware/devicetree/base/model)"
    fi

    if [[ -z "$model" ]]; then
        warn "Could not detect Raspberry Pi model. Proceeding anyway..."
    elif [[ "$model" == *"Raspberry Pi 5"* ]]; then
        log "Detected: $model"
    elif [[ "$model" == *"Raspberry Pi 4"* ]]; then
        log "Detected: $model"
        info "RPi 4B mode — resource limits will be adjusted accordingly."
    else
        warn "Detected: $model"
        warn "This script is optimized for Raspberry Pi 4B / 5."
        read -rp "Continue anyway? [y/N] " confirm
        [[ "$confirm" =~ ^[Yy] ]] || exit 0
    fi

    # Check RAM
    mem_total_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    mem_total_mb=$((mem_total_kb / 1024))
    log "RAM: ${mem_total_mb} MB"

    if (( mem_total_mb < 4000 )); then
        warn "4GB RAM detected. Ollama may struggle with larger models."
        warn "Recommended: Use --model llama3.2:1b or consider Pi 5 8GB."
    elif (( mem_total_mb >= 8000 )); then
        log "8GB RAM — suitable for models up to ~3B parameters"
    fi

    # Check OS
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        log "OS: $PRETTY_NAME"
        if [[ "$VERSION_CODENAME" != "bookworm" ]]; then
            warn "Raspberry Pi OS Bookworm recommended. Detected: $VERSION_CODENAME"
        fi
    fi

    # Check storage
    local root_avail_mb
    root_avail_mb=$(df -BM / | tail -1 | awk '{print $4}' | tr -d 'M')
    log "Available storage: ${root_avail_mb} MB"

    if (( root_avail_mb < 8000 )); then
        warn "Less than 8GB storage available. Docker images + Ollama models need space."
        warn "Consider using a larger SD card or external SSD."
    fi

    # Check if running 64-bit kernel
    if [[ "$(getconf LONG_BIT)" != "64" ]]; then
        die "64-bit kernel required. Run: sudo raspi-config → Advanced → Kernel → 64-bit"
    fi
    log "Kernel: 64-bit ($(uname -r))"
}

# =============================================================================
# SWAP MANAGEMENT
# =============================================================================

setup_swap() {
    local current_swap_mb
    current_swap_mb=$(free -m | awk '/^Swap:/ {print $2}')

    if (( current_swap_mb >= SWAP_SIZE_MB )); then
        log "Swap: ${current_swap_mb} MB (sufficient)"
        return 0
    fi

    info "Configuring swap to ${SWAP_SIZE_MB} MB (current: ${current_swap_mb} MB)..."

    # Use dphys-swapfile (standard on Raspberry Pi OS)
    if [[ -f /etc/dphys-swapfile ]]; then
        sudo sed -i "s/^CONF_SWAPSIZE=.*/CONF_SWAPSIZE=${SWAP_SIZE_MB}/" /etc/dphys-swapfile
        sudo dphys-swapfile setup
        sudo dphys-swapfile swapon
        log "Swap configured: ${SWAP_SIZE_MB} MB"
    else
        # Fallback: create swapfile manually
        if [[ ! -f /swapfile.openclaw ]]; then
            sudo fallocate -l "${SWAP_SIZE_MB}M" /swapfile.openclaw
            sudo chmod 600 /swapfile.openclaw
            sudo mkswap /swapfile.openclaw
        fi
        sudo swapon /swapfile.openclaw 2>/dev/null || true
        # Add to fstab if not present
        if ! grep -q "swapfile.openclaw" /etc/fstab; then
            echo "/swapfile.openclaw none swap sw 0 0" | sudo tee -a /etc/fstab >/dev/null
        fi
        log "Swap file created: ${SWAP_SIZE_MB} MB"
    fi
}

# =============================================================================
# ZRAM SETUP (compressed RAM swap — recommended for RPi)
# =============================================================================
# zram は RAM の一部を圧縮スワップとして使用する。
# ディスクベースの swap より桁違いに高速で、SD カードの寿命も延ばせる。
#
# RAM ごとの推奨設定:
#   4GB → zram 2GB (50%) + disk swap 1GB  — 実効 ~5GB
#   8GB → zram 4GB (50%) + disk swap 2GB  — 実効 ~12GB
#
# 圧縮アルゴリズム比較:
#   zstd   — 高圧縮率 (3〜4x)、やや CPU 負荷高い。8GB モデル推奨。
#   lz4    — 超低レイテンシ、圧縮率 (2〜3x) はやや低い。4GB モデル推奨。
#   lzo-rle — バランス型。Raspberry Pi OS のデフォルト。
#   lzo    — lzo-rle のレガシー版。
# =============================================================================

setup_zram() {
    if [[ "$USE_ZRAM" != "true" ]]; then
        info "zram: disabled (--no-zram)"
        return 0
    fi

    # Check kernel module
    if ! modinfo zram &>/dev/null 2>&1; then
        warn "zram kernel module not available. Skipping zram setup."
        return 0
    fi

    local mem_total_kb mem_total_mb
    mem_total_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    mem_total_mb=$((mem_total_kb / 1024))

    # ── Determine zram size & algorithm based on RAM ─────────────────────────
    local zram_size_mb zram_algo

    if (( mem_total_mb >= 8000 )); then
        # 8GB: zram 4GB (50%), zstd for best compression
        zram_size_mb=4096
        zram_algo="${ZRAM_ALGORITHM:-zstd}"
        # Reduce disk swap — zram handles most pressure
        SWAP_SIZE_MB=$((SWAP_SIZE_MB > 2048 ? SWAP_SIZE_MB : 2048))
    elif (( mem_total_mb >= 4000 )); then
        # 4GB: zram 2GB (50%), lz4 for lowest latency
        zram_size_mb=2048
        zram_algo="${ZRAM_ALGORITHM:-lz4}"
        SWAP_SIZE_MB=$((SWAP_SIZE_MB > 1024 ? SWAP_SIZE_MB : 1024))
    else
        # 2GB or less: zram 1GB (50%), lz4 to save CPU
        zram_size_mb=1024
        zram_algo="${ZRAM_ALGORITHM:-lz4}"
        SWAP_SIZE_MB=$((SWAP_SIZE_MB > 512 ? SWAP_SIZE_MB : 512))
    fi

    # Override size if user specified fraction
    if [[ -n "$ZRAM_FRACTION" ]]; then
        zram_size_mb=$(awk "BEGIN { printf \"%d\", ${mem_total_mb} * ${ZRAM_FRACTION} }")
        info "zram: using custom fraction ${ZRAM_FRACTION} → ${zram_size_mb} MB"
    fi

    # Validate algorithm
    case "$zram_algo" in
        zstd|lz4|lzo|lzo-rle) ;;
        *) warn "Unknown zram algorithm '$zram_algo', falling back to zstd"; zram_algo="zstd" ;;
    esac

    # ── Check if zram is already active ──────────────────────────────────────
    if [[ -e /dev/zram0 ]] && swapon --show=NAME,SIZE | grep -q "zram"; then
        local current_zram_mb
        current_zram_mb=$(swapon --show=NAME,SIZE --bytes | awk '/zram/ {sum+=$2} END {printf "%d", sum/1048576}')
        log "zram: already active (${current_zram_mb} MB)"

        if (( current_zram_mb >= zram_size_mb - 100 )); then
            log "zram: size sufficient, skipping reconfiguration"
            return 0
        fi

        info "zram: reconfiguring from ${current_zram_mb} MB to ${zram_size_mb} MB..."
        # Deactivate existing zram devices
        for dev in /dev/zram*; do
            [[ -b "$dev" ]] || continue
            sudo swapoff "$dev" 2>/dev/null || true
        done
        sudo modprobe -r zram 2>/dev/null || true
    fi

    # ── Create and activate zram device ──────────────────────────────────────
    info "zram: setting up ${zram_size_mb} MB with ${zram_algo} compression..."

    # Load module with 1 device
    sudo modprobe zram num_devices=1

    # Wait for device
    local retries=0
    while [[ ! -e /dev/zram0 ]] && (( retries < 10 )); do
        sleep 0.5
        ((retries++))
    done

    if [[ ! -e /dev/zram0 ]]; then
        warn "zram: /dev/zram0 did not appear. Skipping."
        return 0
    fi

    # Set compression algorithm
    echo "$zram_algo" | sudo tee /sys/block/zram0/comp_algorithm >/dev/null 2>&1 || {
        warn "zram: algorithm '$zram_algo' not supported by kernel, trying lzo-rle..."
        zram_algo="lzo-rle"
        echo "$zram_algo" | sudo tee /sys/block/zram0/comp_algorithm >/dev/null 2>&1 || true
    }

    # Set disk size
    echo "$((zram_size_mb * 1024 * 1024))" | sudo tee /sys/block/zram0/disksize >/dev/null

    # Format and enable
    sudo mkswap /dev/zram0 >/dev/null
    sudo swapon -p 100 /dev/zram0  # priority 100 — used before disk swap

    log "zram: activated ${zram_size_mb} MB (algo: ${zram_algo}, priority: 100)"

    # ── Persist across reboots via systemd ───────────────────────────────────
    local zram_service="/etc/systemd/system/zram-openclaw.service"

    sudo tee "$zram_service" >/dev/null <<ZRAM_UNIT
[Unit]
Description=OpenClaw zram compressed swap
After=local-fs.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c '\
    modprobe zram num_devices=1 && \
    echo ${zram_algo} > /sys/block/zram0/comp_algorithm && \
    echo $((zram_size_mb * 1024 * 1024)) > /sys/block/zram0/disksize && \
    mkswap /dev/zram0 && \
    swapon -p 100 /dev/zram0'
ExecStop=/bin/bash -c '\
    swapoff /dev/zram0 2>/dev/null; \
    modprobe -r zram 2>/dev/null; \
    true'

[Install]
WantedBy=multi-user.target
ZRAM_UNIT

    sudo systemctl daemon-reload
    sudo systemctl enable zram-openclaw.service >/dev/null 2>&1
    log "zram: systemd service installed (auto-start on boot)"

    # ── Optimize vm.swappiness for zram ──────────────────────────────────────
    local current_swappiness
    current_swappiness=$(cat /proc/sys/vm/swappiness)
    local target_swappiness=150  # kernel 5.8+ supports >100 for zram preference

    # Check kernel version for zram-aware swappiness
    local kernel_major kernel_minor
    kernel_major=$(uname -r | cut -d. -f1)
    kernel_minor=$(uname -r | cut -d. -f2)

    if (( kernel_major > 5 || (kernel_major == 5 && kernel_minor >= 8) )); then
        target_swappiness=150
    else
        target_swappiness=80
    fi

    if (( current_swappiness != target_swappiness )); then
        sudo sysctl -w vm.swappiness="$target_swappiness" >/dev/null
        # Persist
        if ! grep -q "vm.swappiness" /etc/sysctl.d/99-openclaw-zram.conf 2>/dev/null; then
            echo "vm.swappiness=${target_swappiness}" | sudo tee /etc/sysctl.d/99-openclaw-zram.conf >/dev/null
        fi
        log "vm.swappiness: ${current_swappiness} → ${target_swappiness} (zram-optimized)"
    fi

    # ── Summary ──────────────────────────────────────────────────────────────
    local effective_mb=$((mem_total_mb + zram_size_mb))
    info "Memory layout:"
    echo "  Physical RAM:  ${mem_total_mb} MB"
    echo "  zram (compr.): ${zram_size_mb} MB  [${zram_algo}, ~${zram_size_mb}×0.3 actual RAM used]"
    echo "  Disk swap:     ${SWAP_SIZE_MB} MB  [fallback, lower priority]"
    echo "  Effective:     ~${effective_mb} MB+ (with compression benefit)"
}

# =============================================================================
# ZRAM ON/OFF (post-install toggle)
# =============================================================================

run_zram_on() {
    info "Enabling zram..."

    # すでにアクティブなら状態を表示して終了
    if [[ -e /dev/zram0 ]] && swapon --show=NAME | grep -q "zram"; then
        local current_mb
        current_mb=$(swapon --show=NAME,SIZE --bytes | awk '/zram/ {sum+=$2} END {printf "%d", sum/1048576}')
        local current_algo
        current_algo=$(cat /sys/block/zram0/comp_algorithm 2>/dev/null | grep -o '\[.*\]' | tr -d '[]')
        log "zram is already active: ${current_mb} MB (algo: ${current_algo:-unknown})"
        info "To reconfigure, run --zram-off first, then --zram-on --zram-algo <algo>"
        return 0
    fi

    # setup_zram を呼び出して有効化（RAM に応じた自動設定）
    USE_ZRAM=true
    setup_zram

    # systemd サービスが有効か確認
    if systemctl is-enabled zram-openclaw.service &>/dev/null; then
        log "zram systemd service: enabled (will start on boot)"
    else
        info "zram systemd service was not enabled. Enabling..."
        sudo systemctl enable zram-openclaw.service >/dev/null 2>&1
        log "zram systemd service: enabled"
    fi

    log "zram enabled successfully"
    info "Verify: cat /proc/swaps"
}

run_zram_off() {
    info "Disabling zram..."

    # zram デバイスが存在する場合は無効化
    local was_active=false
    if [[ -e /dev/zram0 ]] && swapon --show=NAME | grep -q "zram"; then
        local current_mb
        current_mb=$(swapon --show=NAME,SIZE --bytes | awk '/zram/ {sum+=$2} END {printf "%d", sum/1048576}')
        info "Deactivating zram (${current_mb} MB)..."

        for dev in /dev/zram*; do
            [[ -b "$dev" ]] || continue
            sudo swapoff "$dev" 2>/dev/null || true
        done
        sudo modprobe -r zram 2>/dev/null || true
        was_active=true
        log "zram device deactivated"
    else
        info "zram is not currently active"
    fi

    # systemd サービスを無効化
    if systemctl is-enabled zram-openclaw.service &>/dev/null; then
        sudo systemctl stop zram-openclaw.service 2>/dev/null || true
        sudo systemctl disable zram-openclaw.service >/dev/null 2>&1
        log "zram systemd service: disabled (will not start on boot)"
    fi

    # vm.swappiness を元に戻す
    if [[ -f /etc/sysctl.d/99-openclaw-zram.conf ]]; then
        sudo rm -f /etc/sysctl.d/99-openclaw-zram.conf
        sudo sysctl -w vm.swappiness=60 >/dev/null
        log "vm.swappiness: reset to 60 (default)"
    fi

    if [[ "$was_active" == "true" ]]; then
        log "zram disabled successfully"
        echo ""
        info "Note: Disk swap is still available as fallback."
        info "  Current swap: $(free -m | awk '/^Swap:/ {print $2}') MB"
        info "  Re-enable:    ./setup-rpi.sh --zram-on"
    else
        log "zram is now fully disabled"
    fi
}

# =============================================================================
# DOCKER INSTALLATION (Raspberry Pi specific)
# =============================================================================

install_docker_rpi() {
    if command -v docker &>/dev/null; then
        log "Docker $(docker --version 2>/dev/null | head -1)"
        if docker compose version &>/dev/null; then
            log "Docker Compose $(docker compose version --short 2>/dev/null)"
        else
            die "Docker Compose not found. Install: sudo apt-get install docker-compose-plugin"
        fi

        # Ensure current user is in docker group
        if ! groups | grep -qw docker; then
            warn "User '$USER' not in docker group. Adding..."
            sudo usermod -aG docker "$USER"
            info "Restarting script with docker group active..."
            exec sg docker -c "$0 $*"
        fi
        return 0
    fi

    info "Docker not found. Installing for Raspberry Pi..."

    # Update system
    sudo apt-get update -qq
    sudo apt-get install -y -qq ca-certificates curl gnupg lsb-release

    # Add Docker GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg \
        | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Add Docker repository (use debian for Raspberry Pi OS)
    local codename
    codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
    echo \
        "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
        ${codename} stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

    # Install Docker
    sudo apt-get update -qq
    sudo apt-get install -y -qq \
        docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin

    # Add user to docker group
    sudo usermod -aG docker "$USER"

    # Enable and start Docker
    sudo systemctl enable docker
    sudo systemctl start docker

    log "Docker installed successfully"
    info "Restarting script with docker group active..."
    exec sg docker -c "$0 $*"
}

# =============================================================================
# ENVIRONMENT & DOCKER COMPOSE SETUP
# =============================================================================

setup_env_file() {
    local env_file="${SCRIPT_DIR}/.env"

    if [[ -f "$env_file" ]]; then
        info ".env file already exists — preserving existing configuration"
        return 0
    fi

    info "Creating .env file..."
    cp "${SCRIPT_DIR}/.env.example" "$env_file"

    # Fill in values
    if [[ -n "$ANTHROPIC_API_KEY" ]]; then
        sed -i "s|^ANTHROPIC_API_KEY=.*|ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}|" "$env_file"
    fi
    if [[ -n "$OPENAI_API_KEY" ]]; then
        sed -i "s|^OPENAI_API_KEY=.*|OPENAI_API_KEY=${OPENAI_API_KEY}|" "$env_file"
    fi

    # Generate auth token
    if [[ -z "$OPENCLAW_AUTH_TOKEN" ]]; then
        OPENCLAW_AUTH_TOKEN="$(openssl rand -hex 32 2>/dev/null || head -c 64 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    fi
    sed -i "s|^OPENCLAW_AUTH_TOKEN=.*|OPENCLAW_AUTH_TOKEN=${OPENCLAW_AUTH_TOKEN}|" "$env_file"
    sed -i "s|^OPENCLAW_AUTH_MODE=.*|OPENCLAW_AUTH_MODE=${OPENCLAW_AUTH_MODE}|" "$env_file"

    # Set RPi-optimized Ollama settings
    sed -i "s|^OLLAMA_DEFAULT_MODEL=.*|OLLAMA_DEFAULT_MODEL=${OLLAMA_DEFAULT_MODEL}|" "$env_file"

    # Secure permissions
    chmod 600 "$env_file"
    log ".env created with secure permissions (600)"
    info "Auth token: ${OPENCLAW_AUTH_TOKEN:0:8}...${OPENCLAW_AUTH_TOKEN: -8}"
}

create_rpi_compose_override() {
    local override_file="${SCRIPT_DIR}/docker-compose.rpi.yml"

    info "Creating Raspberry Pi optimized docker-compose override..."

    # ── 既存ファイル保護 ───────────────────────────────────────────────────
    _SAFE_OVERWRITE_SHOW_DIFF=false
    if ! safe_overwrite_check "$override_file" "docker-compose.rpi.yml"; then
        return 0  # ユーザーがスキップを選択
    fi

    local mem_total_kb
    mem_total_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local mem_total_mb=$((mem_total_kb / 1024))

    # Detect Pi generation for CPU allocation
    local pi_model_name=""
    if [[ -f /proc/device-tree/model ]]; then
        pi_model_name="$(tr -d '\0' < /proc/device-tree/model)"
    fi
    local is_pi4=false
    [[ "$pi_model_name" == *"Raspberry Pi 4"* ]] && is_pi4=true

    # Determine resource limits based on available RAM and Pi model
    # RPi 4B: Cortex-A72 4-core 1.8GHz — less headroom than Pi 5's Cortex-A76
    # RPi 5:  Cortex-A76 4-core 2.4GHz
    local openclaw_mem_limit="1G"
    local ollama_mem_limit="4G"
    local ollama_cpus="3.0"
    local node_max_old_space=768

    if (( mem_total_mb >= 8000 )); then
        openclaw_mem_limit="1536M"
        ollama_mem_limit="6G"
        ollama_cpus="3.0"
        node_max_old_space=1024
    elif (( mem_total_mb >= 4000 )); then
        openclaw_mem_limit="768M"
        ollama_mem_limit="3G"
        ollama_cpus="2.0"
        node_max_old_space=512
    elif (( mem_total_mb >= 2000 )); then
        openclaw_mem_limit="384M"
        ollama_mem_limit="1536M"
        ollama_cpus="2.0"
        node_max_old_space=256
    else
        openclaw_mem_limit="256M"
        ollama_mem_limit="1G"
        ollama_cpus="2.0"
        node_max_old_space=192
    fi

    # RPi 4B: further limit CPU to leave headroom for system
    if [[ "$is_pi4" == "true" ]]; then
        ollama_cpus="2.0"
        [[ "$ollama_mem_limit" == "6G" ]] && ollama_mem_limit="5G"
    fi

    cat > "$override_file" <<YAML
# =============================================================================
# openclaw-easy-setup — Raspberry Pi override
# Auto-generated by setup-rpi.sh
# Resource limits optimized for ${pi_model_name:-RPi} (${mem_total_mb} MB RAM)
# =============================================================================

services:
  openclaw:
    deploy:
      resources:
        limits:
          memory: ${openclaw_mem_limit}
          cpus: "1.0"
        reservations:
          memory: 256M
    environment:
      # RPi-optimized Node.js settings
      NODE_OPTIONS: "--max-old-space-size=${node_max_old_space}"
      TZ: "\${TZ:-Asia/Tokyo}"

  ollama:
    deploy:
      resources:
        limits:
          memory: ${ollama_mem_limit}
          cpus: "${ollama_cpus}"
    environment:
      - OLLAMA_HOST=0.0.0.0
      - OLLAMA_NUM_PARALLEL=\${OLLAMA_NUM_PARALLEL:-1}
      - OLLAMA_MAX_LOADED_MODELS=\${OLLAMA_MAX_LOADED_MODELS:-1}
      # RPi optimization: reduce context size for memory savings
      - OLLAMA_MAX_QUEUE=2

  ollama-init:
    entrypoint: >
      sh -c '
        echo "Pulling RPi-optimized model: \${OLLAMA_DEFAULT_MODEL:-${OLLAMA_DEFAULT_MODEL}}..."
        curl -sf http://ollama:11434/api/pull -d "{\"name\":\"\${OLLAMA_DEFAULT_MODEL:-${OLLAMA_DEFAULT_MODEL}}\"}" || true
        echo "Model pull complete."
      '
YAML

    # ── diff 表示モード: ユーザーが "3) Show diff" を選んだ場合 ─────────────
    if [[ "$_SAFE_OVERWRITE_SHOW_DIFF" == "true" ]]; then
        local backup_file
        backup_file=$(ls -t "${override_file}.bak."* 2>/dev/null | head -1)
        if [[ -n "$backup_file" ]]; then
            echo ""
            info "Changes from existing → new:"
            diff --color=auto -u "$backup_file" "$override_file" || true
            echo ""
            read -rp "Keep new version? [Y/n] " keep_new
            if [[ "$keep_new" =~ ^[Nn] ]]; then
                mv "$backup_file" "$override_file"
                info "Restored previous version"
                return 0
            fi
        fi
        _SAFE_OVERWRITE_SHOW_DIFF=false
    fi

    log "RPi override created: docker-compose.rpi.yml"
    log "  OpenClaw memory: ${openclaw_mem_limit}, Ollama memory: ${ollama_mem_limit}"
}

# =============================================================================
# DOCKER COMPOSE UP (with RPi override)
# =============================================================================

docker_compose_up_rpi() {
    info "Starting Docker containers (RPi optimized)..."
    cd "$SCRIPT_DIR"

    local compose_cmd="docker compose -f docker-compose.yml -f docker-compose.rpi.yml"

    # Build (may take a while on RPi)
    info "Building OpenClaw image (this may take 5-10 minutes on first run)..."
    $compose_cmd build 2>&1 | tail -5

    if [[ "$INSTALL_OLLAMA" == "true" ]]; then
        $compose_cmd up -d
        log "All services started (OpenClaw + Ollama)"
    else
        $compose_cmd up -d openclaw
        log "OpenClaw started (without Ollama)"
    fi

    # Wait for health check
    info "Waiting for services to become healthy (RPi may take longer)..."
    local retries=0
    while (( retries < 60 )); do
        if docker compose ps 2>/dev/null | grep -q "healthy"; then
            break
        fi
        sleep 3
        ((retries++))
    done

    echo ""
    $compose_cmd ps
    echo ""
}

# =============================================================================
# SYSTEMD SERVICE (auto-start on boot)
# =============================================================================

setup_systemd_service() {
    info "Setting up systemd service for auto-start on boot..."

    local service_file="/etc/systemd/system/openclaw.service"

    # ── 既存ファイル保護 ───────────────────────────────────────────────────
    if [[ -f "$service_file" ]]; then
        _SAFE_OVERWRITE_SHOW_DIFF=false
        if ! safe_overwrite_check "$service_file" "openclaw.service"; then
            log "Systemd service: keeping existing configuration"
            # サービスが有効か確認だけ行う
            if ! systemctl is-enabled openclaw.service &>/dev/null; then
                sudo systemctl daemon-reload
                sudo systemctl enable openclaw.service
                log "Systemd service: re-enabled"
            fi
            return 0
        fi
    fi

    sudo tee "$service_file" >/dev/null <<UNIT
[Unit]
Description=OpenClaw + Ollama (Docker Compose)
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${SCRIPT_DIR}
ExecStart=/usr/bin/docker compose -f docker-compose.yml -f docker-compose.rpi.yml up -d
ExecStop=/usr/bin/docker compose -f docker-compose.yml -f docker-compose.rpi.yml down
TimeoutStartSec=300
User=${USER}

[Install]
WantedBy=multi-user.target
UNIT

    sudo systemctl daemon-reload
    sudo systemctl enable openclaw.service
    log "Systemd service installed: openclaw.service"
    info "OpenClaw will auto-start on boot"
    info "  Control: sudo systemctl {start|stop|restart|status} openclaw"
}

# =============================================================================
# DOCTOR / DIAGNOSTICS (RPi specific)
# =============================================================================

run_doctor_rpi() {
    echo ""
    echo "══════════════════════════════════════════"
    echo "  openclaw-easy-setup — RPi Diagnostics"
    echo "══════════════════════════════════════════"
    echo ""

    local issues=0

    # Pi model
    if [[ -f /proc/device-tree/model ]]; then
        log "Model: $(tr -d '\0' < /proc/device-tree/model)"
    fi

    # Architecture
    log "Architecture: $(uname -m) ($(getconf LONG_BIT)-bit)"

    # Kernel
    log "Kernel: $(uname -r)"

    # OS
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        log "OS: $PRETTY_NAME"
    fi

    # CPU temperature
    if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
        local temp_raw temp_c
        temp_raw=$(cat /sys/class/thermal/thermal_zone0/temp)
        temp_c=$((temp_raw / 1000))
        if (( temp_c > 80 )); then
            warn "CPU Temperature: ${temp_c}°C (HIGH — consider adding cooling)"
            ((issues++))
        elif (( temp_c > 70 )); then
            warn "CPU Temperature: ${temp_c}°C (warm)"
        else
            log "CPU Temperature: ${temp_c}°C"
        fi
    fi

    # CPU throttling
    if command -v vcgencmd &>/dev/null; then
        local throttled
        throttled=$(vcgencmd get_throttled 2>/dev/null | cut -d= -f2)
        if [[ "$throttled" == "0x0" ]]; then
            log "Throttling: none detected"
        else
            warn "Throttling detected: $throttled (power/thermal issue)"
            ((issues++))
        fi
    fi

    # RAM
    local mem_total_mb mem_avail_mb
    mem_total_mb=$(($(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024))
    mem_avail_mb=$(($(grep MemAvailable /proc/meminfo | awk '{print $2}') / 1024))
    log "RAM: ${mem_avail_mb} MB available / ${mem_total_mb} MB total"
    if (( mem_avail_mb < 1000 )); then
        warn "Low available memory. Consider stopping other services."
        ((issues++))
    fi

    # Swap
    local swap_total_mb
    swap_total_mb=$(free -m | awk '/^Swap:/ {print $2}')
    if (( swap_total_mb < 1024 )); then
        warn "Swap (total): ${swap_total_mb} MB (recommend >= 2048 MB for Ollama)"
        ((issues++))
    else
        log "Swap (total): ${swap_total_mb} MB"
    fi

    # zram
    if [[ -e /dev/zram0 ]] && swapon --show=NAME,SIZE | grep -q "zram"; then
        local zram_size_mb zram_algo_current
        zram_size_mb=$(swapon --show=NAME,SIZE --bytes | awk '/zram/ {sum+=$2} END {printf "%d", sum/1048576}')
        zram_algo_current=$(cat /sys/block/zram0/comp_algorithm 2>/dev/null | grep -o '\[.*\]' | tr -d '[]')
        log "zram: ${zram_size_mb} MB (algo: ${zram_algo_current:-unknown})"

        # Show compression stats if available
        if [[ -f /sys/block/zram0/mm_stat ]]; then
            local mm_stat orig_size compr_size
            mm_stat=$(cat /sys/block/zram0/mm_stat)
            orig_size=$(echo "$mm_stat" | awk '{printf "%d", $1/1048576}')
            compr_size=$(echo "$mm_stat" | awk '{printf "%d", $2/1048576}')
            if (( orig_size > 0 )); then
                local ratio
                ratio=$(awk "BEGIN { printf \"%.1f\", ${orig_size} / ${compr_size} }" 2>/dev/null || echo "N/A")
                log "  Compression: ${orig_size} MB → ${compr_size} MB (${ratio}x ratio)"
            fi
        fi
    else
        info "zram: not active"
    fi

    # vm.swappiness
    local swappiness
    swappiness=$(cat /proc/sys/vm/swappiness)
    if (( swappiness >= 100 )); then
        log "vm.swappiness: ${swappiness} (zram-optimized)"
    elif (( swappiness >= 60 )); then
        log "vm.swappiness: ${swappiness}"
    else
        warn "vm.swappiness: ${swappiness} (consider increasing for zram)"
    fi

    # zram systemd service
    if systemctl is-enabled zram-openclaw.service &>/dev/null; then
        log "zram service: enabled"
    fi

    # Storage
    local root_used_pct root_avail_mb
    root_used_pct=$(df / | tail -1 | awk '{print $5}' | tr -d '%')
    root_avail_mb=$(df -BM / | tail -1 | awk '{print $4}' | tr -d 'M')
    if (( root_used_pct > 90 )); then
        warn "Storage: ${root_avail_mb} MB available (${root_used_pct}% used — LOW)"
        ((issues++))
    else
        log "Storage: ${root_avail_mb} MB available (${root_used_pct}% used)"
    fi

    # Docker
    echo ""
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
        ((issues++))
    fi

    # Port checks
    if curl -sf "http://127.0.0.1:${OPENCLAW_GATEWAY_PORT}/health" &>/dev/null; then
        log "Gateway port ${OPENCLAW_GATEWAY_PORT}: responding"
    else
        warn "Gateway port ${OPENCLAW_GATEWAY_PORT}: not responding"
        ((issues++))
    fi

    if curl -sf "http://127.0.0.1:11434/api/tags" &>/dev/null; then
        log "Ollama port 11434: responding"
        local models
        models=$(curl -sf http://127.0.0.1:11434/api/tags 2>/dev/null \
            | grep -o '"name":"[^"]*"' | sed 's/"name":"//;s/"//' | head -5 || true)
        if [[ -n "$models" ]]; then
            info "Loaded models: $models"
        fi
    else
        warn "Ollama port 11434: not responding"
    fi

    # Security & permission checks
    echo ""
    info "Permission & security checks:"

    # Running user
    if [[ "$EUID" -eq 0 ]]; then
        warn "Running as root (not recommended)"
        ((issues++))
    else
        log "Running as: $USER (uid=$EUID)"
    fi

    # Docker group membership
    if groups 2>/dev/null | grep -qw docker; then
        log "Docker group: $USER is a member"
    elif grep -q "^docker:.*\b${USER}\b" /etc/group 2>/dev/null; then
        warn "Docker group: $USER is added but session not refreshed (re-login needed)"
        ((issues++))
    else
        warn "Docker group: $USER is NOT a member"
        ((issues++))
    fi

    # secrets/ directory
    local secrets_dir="${SCRIPT_DIR}/secrets"
    if [[ -d "$secrets_dir" ]]; then
        local secrets_perms secrets_owner
        secrets_perms=$(stat -c "%a" "$secrets_dir" 2>/dev/null)
        secrets_owner=$(stat -c "%U" "$secrets_dir" 2>/dev/null)
        if [[ "$secrets_perms" == "700" ]]; then
            log "secrets/ permissions: $secrets_perms (OK), owner: $secrets_owner"
        else
            warn "secrets/ permissions: $secrets_perms (should be 700)"
            ((issues++))
        fi

        # Check individual secret files
        local bad_secret_perms=0
        while IFS= read -r -d '' secret_file; do
            local fp
            fp=$(stat -c "%a" "$secret_file" 2>/dev/null)
            if [[ "$fp" != "600" ]]; then
                ((bad_secret_perms++))
            fi
        done < <(find "$secrets_dir" -type f ! -name "README.md" ! -name ".gitignore" -print0 2>/dev/null)
        if (( bad_secret_perms > 0 )); then
            warn "secrets/: ${bad_secret_perms} file(s) with wrong permissions (should be 600)"
            ((issues++))
        elif [[ $(find "$secrets_dir" -type f ! -name "README.md" ! -name ".gitignore" 2>/dev/null | wc -l) -gt 0 ]]; then
            log "secrets/ files: all 600 (OK)"
        fi
    fi

    # .env file
    local env_file="${SCRIPT_DIR}/.env"
    if [[ -f "$env_file" ]]; then
        local perms env_owner
        perms=$(stat -c "%a" "$env_file" 2>/dev/null)
        env_owner=$(stat -c "%U" "$env_file" 2>/dev/null)

        if [[ "$env_owner" == "root" ]]; then
            warn ".env owner: root (should be $USER — likely from sudo run)"
            ((issues++))
        fi

        if [[ "$perms" == "600" ]]; then
            log ".env permissions: $perms (OK)"
        else
            warn ".env permissions: $perms (should be 600)"
            ((issues++))
        fi
    fi

    # Systemd service
    if systemctl is-enabled openclaw.service &>/dev/null; then
        log "Systemd service: enabled"
        local svc_status
        svc_status=$(systemctl is-active openclaw.service 2>/dev/null || echo "inactive")
        log "  Status: $svc_status"
    else
        info "Systemd service: not configured (optional)"
    fi

    echo ""
    if (( issues == 0 )); then
        log "All checks passed!"
    else
        warn "${issues} issue(s) found."
    fi
    return 0
}

# =============================================================================
# UNINSTALL
# =============================================================================

run_uninstall() {
    warn "This will stop and remove Docker containers."
    read -rp "Continue? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy] ]] || { info "Cancelled."; exit 0; }

    cd "$SCRIPT_DIR"

    # Stop and remove containers
    if [[ -f docker-compose.rpi.yml ]]; then
        docker compose -f docker-compose.yml -f docker-compose.rpi.yml down 2>/dev/null || true
    else
        docker compose down 2>/dev/null || true
    fi
    log "Containers stopped and removed"

    read -rp "Also remove Docker volumes (data will be lost)? [y/N] " confirm_vol
    if [[ "$confirm_vol" =~ ^[Yy] ]]; then
        if [[ -f docker-compose.rpi.yml ]]; then
            docker compose -f docker-compose.yml -f docker-compose.rpi.yml down -v 2>/dev/null || true
        else
            docker compose down -v 2>/dev/null || true
        fi
        log "Volumes removed"
    fi

    read -rp "Remove systemd services? [y/N] " confirm_svc
    if [[ "$confirm_svc" =~ ^[Yy] ]]; then
        sudo systemctl stop openclaw.service 2>/dev/null || true
        sudo systemctl disable openclaw.service 2>/dev/null || true
        sudo rm -f /etc/systemd/system/openclaw.service
        # zram service
        sudo systemctl stop zram-openclaw.service 2>/dev/null || true
        sudo systemctl disable zram-openclaw.service 2>/dev/null || true
        sudo rm -f /etc/systemd/system/zram-openclaw.service
        sudo rm -f /etc/sysctl.d/99-openclaw-zram.conf
        sudo systemctl daemon-reload
        log "Systemd services removed (openclaw + zram)"
    fi

    # Deactivate zram
    if [[ -e /dev/zram0 ]] && swapon --show=NAME | grep -q "zram"; then
        sudo swapoff /dev/zram0 2>/dev/null || true
        sudo modprobe -r zram 2>/dev/null || true
        log "zram deactivated"
    fi

    log "Uninstall complete"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║  openclaw-easy-setup v1.1.0 — Raspberry Pi 4B/5    ║"
    echo "║  Docker-first, security-focused installer           ║"
    echo "║  OpenClaw + Ollama (local LLM) + zram              ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""

    # Permission checks (root 防止, secrets 権限, .env 所有者)
    check_permissions

    detect_rpi

    case "$RUN_MODE" in
        doctor)    run_doctor_rpi; exit $? ;;
        uninstall) run_uninstall; exit 0 ;;
        zram-on)   run_zram_on; exit 0 ;;
        zram-off)  run_zram_off; exit 0 ;;
    esac

    # Docker グループのセッション反映チェック
    check_docker_group_session

    # Prerequisites
    command -v curl &>/dev/null || {
        info "Installing curl..."
        sudo apt-get update -qq && sudo apt-get install -y -qq curl
    }

    echo ""
    info "=== Step 1/6: zram (compressed swap) ==="
    setup_zram

    echo ""
    info "=== Step 2/6: Disk swap configuration ==="
    setup_swap

    echo ""
    info "=== Step 3/6: Docker installation ==="
    install_docker_rpi

    echo ""
    info "=== Step 4/6: Environment setup ==="
    setup_env_file
    create_rpi_compose_override

    echo ""
    info "=== Step 5/6: Starting services ==="
    docker_compose_up_rpi

    echo ""
    info "=== Step 6/6: Boot service setup ==="
    read -rp "Enable auto-start on boot? [Y/n] " enable_boot
    if [[ ! "$enable_boot" =~ ^[Nn] ]]; then
        setup_systemd_service
    fi

    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║  Installation complete!                                 ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""

    info "Quick reference:"
    echo "  Status:    docker compose ps"
    echo "  Logs:      docker compose logs -f"
    echo "  Stop:      docker compose down"
    echo "  Restart:   docker compose restart"
    echo ""
    echo "  Ollama models:"
    echo "    List:    curl http://127.0.0.1:11434/api/tags"
    echo "    Pull:    docker compose exec ollama ollama pull <model>"
    echo "    Chat:    docker compose exec ollama ollama run ${OLLAMA_DEFAULT_MODEL}"
    echo ""
    echo "  Gateway:   http://127.0.0.1:${OPENCLAW_GATEWAY_PORT}"
    echo ""
    info "Security:"
    echo "  - Ports bound to 127.0.0.1 only"
    echo "  - Auth mode: $OPENCLAW_AUTH_MODE"
    echo "  - Container: no-new-privileges, read-only, cap_drop ALL"
    echo "  - Dangerous tools denied: $OPENCLAW_DENY_TOOLS"
    echo ""
    info "RPi tips:"
    echo "  - Monitor temperature: vcgencmd measure_temp"
    echo "  - Check throttling:    vcgencmd get_throttled"
    echo "  - zram status:         cat /proc/swaps"
    echo "  - zram stats:          cat /sys/block/zram0/mm_stat"
    echo "  - Diagnostics:         ./setup-rpi.sh --doctor"
    echo "  - Default model: ${OLLAMA_DEFAULT_MODEL} (optimized for RPi)"

    if [[ "$OLLAMA_DEFAULT_MODEL" == *":1b"* ]]; then
        echo ""
        info "Upgrade model (if you have 8GB RAM):"
        echo "  docker compose exec ollama ollama pull llama3.2:3b"
    fi

    echo ""
    log "Setup log: $LOG_FILE"
    info "Run './setup-rpi.sh --doctor' to verify installation."
}

main
