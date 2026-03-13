#!/bin/sh
# =============================================================================
# openclaw-easy-setup — Container entrypoint
# Handles first-run initialization and config persistence
# =============================================================================
set -e

OC_DIR="/home/openclaw/.openclaw"
DEFAULT_CONFIG="/defaults/openclaw.json"

# ── First-run: populate empty volume with default config ──────────────────
if [ ! -f "$OC_DIR/openclaw.json" ]; then
    echo "[entrypoint] First run detected — copying default config..."
    if [ -f "$DEFAULT_CONFIG" ]; then
        cp "$DEFAULT_CONFIG" "$OC_DIR/openclaw.json"
        echo "[entrypoint] Default openclaw.json installed"
    else
        echo "[entrypoint] WARNING: No default config found at $DEFAULT_CONFIG"
    fi
fi

# ── Overlay: merge host config if mounted ─────────────────────────────────
if [ -d "/etc/openclaw" ] && [ "$(ls -A /etc/openclaw 2>/dev/null)" ]; then
    echo "[entrypoint] Applying config overlay from /etc/openclaw/..."
    cp -f /etc/openclaw/* "$OC_DIR/" 2>/dev/null || true
fi

# ── Load secrets from /run/secrets/ into environment ──────────────────
# API keys are stored as individual files in secrets/ on the host,
# mounted read-only at /run/secrets/. This keeps them out of
# `docker inspect` and the compose config.
# File name = variable name, file content = value.
# Secrets override any same-named variable from env_file (.env).
SECRETS_DIR="/run/secrets"
if [ -d "$SECRETS_DIR" ]; then
    SECRET_COUNT=0
    for secret_file in "$SECRETS_DIR"/*; do
        [ -f "$secret_file" ] || continue
        secret_name="$(basename "$secret_file")"
        # Skip dotfiles and README
        case "$secret_name" in
            .*|README*) continue ;;
        esac
        # Read value, strip trailing newline
        secret_value="$(cat "$secret_file" | tr -d '\n\r')"
        if [ -n "$secret_value" ]; then
            export "$secret_name=$secret_value"
            SECRET_COUNT=$((SECRET_COUNT + 1))
        fi
    done
    if [ "$SECRET_COUNT" -gt 0 ]; then
        echo "[entrypoint] Loaded $SECRET_COUNT secret(s) from $SECRETS_DIR"
    fi
fi

# ── Validate: API key + Base URL pairs ────────────────────────────────────
# Some providers require BOTH an API key and a custom Base URL.
# Warn at startup if only one of the pair is set.
PAIR_WARN=0
check_pair() {
    key_var="$1"; url_var="$2"; provider="$3"
    key_val="$(eval echo "\${$key_var:-}")"
    url_val="$(eval echo "\${$url_var:-}")"
    if [ -n "$key_val" ] && [ -z "$url_val" ]; then
        echo "[entrypoint] WARNING: $provider — $key_var is set but $url_var is missing"
        PAIR_WARN=$((PAIR_WARN + 1))
    elif [ -z "$key_val" ] && [ -n "$url_val" ]; then
        echo "[entrypoint] WARNING: $provider — $url_var is set but $key_var is missing"
        PAIR_WARN=$((PAIR_WARN + 1))
    fi
}

check_pair "ZAI_API_KEY"       "ZAI_BASE_URL"       "Z.AI"
check_pair "MOONSHOT_API_KEY"  "MOONSHOT_BASE_URL"   "Moonshot/Kimi"
check_pair "MINIMAX_API_KEY"   "MINIMAX_BASE_URL"    "MiniMax"
check_pair "CEREBRAS_API_KEY"  "CEREBRAS_BASE_URL"   "Cerebras"
check_pair "SYNTHETIC_API_KEY" "SYNTHETIC_BASE_URL"  "Synthetic"
check_pair "GLM_API_KEY"       "GLM_BASE_URL"        "GLM/Zhipu"
check_pair "QWEN_API_KEY"      "QWEN_BASE_URL"       "Qwen"
check_pair "TOGETHER_API_KEY"  "TOGETHER_BASE_URL"   "Together"

if [ "$PAIR_WARN" -gt 0 ]; then
    echo "[entrypoint] $PAIR_WARN provider(s) may be misconfigured. See docs/providers for required Base URLs."
fi

# ── Ensure persistent subdirectories exist in volume ──────────────────────
# All of these live inside the openclaw-data volume and survive restarts.
mkdir -p "$OC_DIR/sessions" \
         "$OC_DIR/channels" \
         "$OC_DIR/credentials" \
         "$OC_DIR/agents" \
         "$OC_DIR/memory" \
         "$OC_DIR/logs" \
         "$OC_DIR/data"

# Ephemeral dirs (tmpfs — recreated each start, that's fine)
mkdir -p "/home/openclaw/.cache" \
         "/home/openclaw/.npm" \
         "/home/openclaw/.config"

echo "[entrypoint] Persistent data: $OC_DIR"
echo "[entrypoint]   sessions/  channels/  credentials/  agents/  memory/  logs/"

# ── Set gateway token from environment variable if provided ────────────────
# Do this BEFORE starting the gateway so the token is available at startup
if [ -n "${OPENCLAW_AUTH_TOKEN:-}" ]; then
    echo "[entrypoint] Setting gateway.auth.token from OPENCLAW_AUTH_TOKEN..."
    # Use jq to safely update JSON
    if command -v jq >/dev/null 2>&1; then
        # Check if token is already set correctly
        current_token="$(jq -r '.gateway.auth.token // empty' "$OC_DIR/openclaw.json" 2>/dev/null)"
        if [ "$current_token" != "$OPENCLAW_AUTH_TOKEN" ]; then
            jq ".gateway.auth.token = \"$OPENCLAW_AUTH_TOKEN\"" "$OC_DIR/openclaw.json" > "$OC_DIR/openclaw.json.tmp" && \
            mv "$OC_DIR/openclaw.json.tmp" "$OC_DIR/openclaw.json"
            echo "[entrypoint] Token updated successfully"
        else
            echo "[entrypoint] Token already set correctly"
        fi
    else
        echo "[entrypoint] WARNING: jq not found, token may not be set correctly"
    fi
fi

echo "[entrypoint] Starting OpenClaw..."

# ── Start gateway ─────────────────────────────────────────────────────────
exec openclaw gateway
