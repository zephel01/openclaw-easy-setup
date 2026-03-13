#!/usr/bin/env bash
# =============================================================================
# openclaw-easy-setup — Configuration Consistency Tests
# =============================================================================
# 設定ファイル・スクリプト間の整合性を検証します。
# ドキュメントの内容チェックは対象外です。
#
# 検証項目:
#   1. 設定関連ファイルの存在
#   2. 旧形式 (config.yaml) の残存チェック
#   3. openclaw.json パス・形式の一貫性
#   4. デフォルト値の整合 (ポート / 認証 / deny ツール)
#   5. シェルスクリプトの heredoc ペア
#   6. entrypoint.sh のロジック検証
#   7. Docker Compose の構造・セキュリティ
#   8. シェルスクリプトの構文チェック
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
WARN=0

# ── Helpers ─────────────────────────────────────────────────────────────────
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m\n' "$*"; }

pass() { PASS=$((PASS + 1)); green "  ✓ $1"; }
fail() { FAIL=$((FAIL + 1)); red   "  ✗ $1"; }
warn() { WARN=$((WARN + 1)); yellow "  ⚠ $1"; }

section() { echo ""; bold "── $1 ──"; }

# =============================================================================
# 1. 設定関連ファイルの存在
# =============================================================================
section "1. Config files exist"

REQUIRED_FILES=(
    "Dockerfile"
    "docker-compose.yml"
    "entrypoint.sh"
    "setup.sh"
    "setup.ps1"
    "config.env"
    ".env.example"
    "config/openclaw/openclaw.json.example"
    "secrets/.gitignore"
    "secrets/README.md"
)

for f in "${REQUIRED_FILES[@]}"; do
    if [ -f "$PROJECT_ROOT/$f" ]; then
        pass "$f"
    else
        fail "$f is MISSING"
    fi
done

# =============================================================================
# 2. 旧形式 (config.yaml) の残存チェック
# =============================================================================
section "2. No stale config.yaml references"

STALE=$(grep -rn "config\.yaml" \
    --include="*.sh" --include="*.ps1" \
    --include="*.yml" --include="*.yaml" --include="*.json" \
    --include="*.example" --include="*.env" \
    "$PROJECT_ROOT" 2>/dev/null | grep -v "\.git/" | grep -v "test-config-consistency\.sh" || true)

if [ -z "$STALE" ]; then
    pass "No config.yaml references in config/script files"
else
    fail "Stale config.yaml references found:"
    echo "$STALE" | while read -r line; do
        echo "      $line"
    done
fi

# =============================================================================
# 3. openclaw.json パス・形式の一貫性
# =============================================================================
section "3. openclaw.json path and format consistency"

# Dockerfile
if grep -q '/defaults/openclaw.json' "$PROJECT_ROOT/Dockerfile"; then
    pass "Dockerfile: /defaults/openclaw.json path"
else
    fail "Dockerfile: missing /defaults/openclaw.json"
fi

# entrypoint.sh — default config path
if grep -q 'DEFAULT_CONFIG="/defaults/openclaw.json"' "$PROJECT_ROOT/entrypoint.sh"; then
    pass "entrypoint.sh: DEFAULT_CONFIG path"
else
    fail "entrypoint.sh: DEFAULT_CONFIG not pointing to openclaw.json"
fi

# entrypoint.sh — first-run check
if grep -q '! -f "$OC_DIR/openclaw.json"' "$PROJECT_ROOT/entrypoint.sh"; then
    pass "entrypoint.sh: first-run check uses openclaw.json"
else
    fail "entrypoint.sh: first-run check not using openclaw.json"
fi

# setup.sh
if grep -q 'cat > "$OC_DIR/openclaw.json"' "$PROJECT_ROOT/setup.sh"; then
    pass "setup.sh: generates openclaw.json"
else
    fail "setup.sh: not generating openclaw.json"
fi

# setup.ps1
if grep -q 'openclaw.json' "$PROJECT_ROOT/setup.ps1"; then
    pass "setup.ps1: references openclaw.json"
else
    fail "setup.ps1: not referencing openclaw.json"
fi

# Example file — JSON5 format (unquoted keys)
if grep -q 'gateway:' "$PROJECT_ROOT/config/openclaw/openclaw.json.example"; then
    pass "openclaw.json.example: JSON5 format (unquoted keys)"
else
    fail "openclaw.json.example: not using JSON5 format"
fi

# Dockerfile default config — JSON5 format
if grep -q 'gateway:' "$PROJECT_ROOT/Dockerfile"; then
    pass "Dockerfile: default config uses JSON5 format"
else
    fail "Dockerfile: default config not in JSON5 format"
fi

# =============================================================================
# 4. デフォルト値の整合
# =============================================================================
section "4. Default values alignment"

# 4a. Port 18789
DEFAULT_PORT=18789
for f in "config.env" "docker-compose.yml" "config/openclaw/openclaw.json.example" "Dockerfile"; do
    if grep -q "$DEFAULT_PORT" "$PROJECT_ROOT/$f" 2>/dev/null; then
        pass "$f: port $DEFAULT_PORT"
    else
        fail "$f: port $DEFAULT_PORT missing"
    fi
done

# 4b. Auth mode "token"
for f in "config.env" "setup.sh" "setup.ps1" "config/openclaw/openclaw.json.example"; do
    if grep -q "token" "$PROJECT_ROOT/$f" 2>/dev/null; then
        pass "$f: auth mode 'token'"
    else
        fail "$f: auth mode 'token' missing"
    fi
done

# 4c. Deny tools (exec, browser, cron)
for f in "setup.sh" "setup.ps1" ".env.example" "Dockerfile" "config/openclaw/openclaw.json.example"; do
    if grep -q "exec.*browser.*cron\|exec,browser,cron" "$PROJECT_ROOT/$f" 2>/dev/null; then
        pass "$f: deny tools [exec, browser, cron]"
    else
        fail "$f: deny tools mismatch"
    fi
done

# 4d. Docker Compose — localhost bind (security)
if grep -q '127.0.0.1:18789:18789' "$PROJECT_ROOT/docker-compose.yml"; then
    pass "docker-compose.yml: binds to 127.0.0.1 (localhost only)"
else
    fail "docker-compose.yml: NOT binding to 127.0.0.1 — security risk!"
fi

# =============================================================================
# 5. Heredoc ペアの整合
# =============================================================================
section "5. Heredoc pair matching"

for script in "setup.sh" "entrypoint.sh"; do
    filepath="$PROJECT_ROOT/$script"
    [ -f "$filepath" ] || continue

    for delim in JSON5 EOF BASH; do
        openers=$(grep -c "<<['-]*${delim}" "$filepath" 2>/dev/null || true)
        closers=$(grep -c "^[[:space:]]*${delim}$" "$filepath" 2>/dev/null || true)
        if [ "$openers" -eq "$closers" ]; then
            if [ "$openers" -gt 0 ]; then
                pass "$script: heredoc $delim — $openers open, $closers close"
            fi
        else
            fail "$script: heredoc $delim MISMATCH — $openers open, $closers close"
        fi
    done
done

# =============================================================================
# 6. entrypoint.sh ロジック検証
# =============================================================================
section "6. entrypoint.sh logic"

ENTRYPOINT="$PROJECT_ROOT/entrypoint.sh"

# shebang
if head -1 "$ENTRYPOINT" | grep -q '^#!/'; then
    pass "entrypoint.sh: shebang present"
else
    fail "entrypoint.sh: missing shebang"
fi

# set -e
if grep -q 'set -e' "$ENTRYPOINT"; then
    pass "entrypoint.sh: set -e (fail-fast)"
else
    warn "entrypoint.sh: no set -e — errors may be silently ignored"
fi

# config overlay
if grep -q '/etc/openclaw' "$ENTRYPOINT"; then
    pass "entrypoint.sh: config overlay (/etc/openclaw)"
else
    fail "entrypoint.sh: missing config overlay logic"
fi

# exec handoff
if grep -q 'exec.*"$@"' "$ENTRYPOINT" || grep -q 'exec tini' "$ENTRYPOINT"; then
    pass "entrypoint.sh: exec handoff to main process"
else
    warn "entrypoint.sh: no exec handoff found"
fi

# secrets loading
if grep -q '/run/secrets' "$ENTRYPOINT"; then
    pass "entrypoint.sh: secrets loading from /run/secrets"
else
    fail "entrypoint.sh: missing secrets loading logic"
fi

# API key + Base URL pair validation
if grep -q 'check_pair' "$ENTRYPOINT"; then
    pass "entrypoint.sh: API key / Base URL pair validation"
else
    fail "entrypoint.sh: missing API key / Base URL pair validation"
fi

# Verify all Base URL-required providers have check_pair entries
BASE_URL_PROVIDERS="ZAI MOONSHOT MINIMAX CEREBRAS SYNTHETIC GLM QWEN TOGETHER"
MISSING_PAIRS=""
for provider in $BASE_URL_PROVIDERS; do
    if ! grep -q "check_pair.*${provider}_API_KEY.*${provider}_BASE_URL" "$ENTRYPOINT"; then
        MISSING_PAIRS="$MISSING_PAIRS $provider"
    fi
done
if [ -z "$MISSING_PAIRS" ]; then
    pass "entrypoint.sh: all Base URL providers have check_pair"
else
    fail "entrypoint.sh: missing check_pair for:$MISSING_PAIRS"
fi

# Verify .env.example has matching Base URL entries for providers
ENV_EXAMPLE="$PROJECT_ROOT/.env.example"
MISSING_ENV=""
for provider in $BASE_URL_PROVIDERS; do
    if ! grep -q "${provider}_BASE_URL" "$ENV_EXAMPLE"; then
        MISSING_ENV="$MISSING_ENV $provider"
    fi
done
if [ -z "$MISSING_ENV" ]; then
    pass ".env.example: all Base URL providers documented"
else
    fail ".env.example: missing Base URL for:$MISSING_ENV"
fi

# =============================================================================
# 7. Docker Compose 構造・セキュリティ
# =============================================================================
section "7. Docker Compose structure"

COMPOSE="$PROJECT_ROOT/docker-compose.yml"

# Services
for svc in "openclaw:" "ollama:" "ollama-init:"; do
    if grep -q "$svc" "$COMPOSE"; then
        pass "service $svc"
    else
        fail "service $svc missing"
    fi
done

# Named volumes
for vol in "openclaw-data:" "ollama-models:"; do
    if grep -q "$vol" "$COMPOSE"; then
        pass "volume $vol"
    else
        fail "volume $vol missing"
    fi
done

# Secrets mount
if grep -q '/run/secrets' "$COMPOSE"; then
    pass "secrets: /run/secrets mount"
else
    fail "secrets: /run/secrets mount missing"
fi

# Network
if grep -q "openclaw-net:" "$COMPOSE"; then
    pass "network openclaw-net"
else
    fail "network openclaw-net missing"
fi

# Security hardening
if grep -q "no-new-privileges" "$COMPOSE"; then
    pass "security: no-new-privileges"
else
    warn "security: no-new-privileges not set"
fi

if grep -q "read_only: true" "$COMPOSE"; then
    pass "security: read-only filesystem"
else
    warn "security: read-only filesystem not set"
fi

if grep -q "healthcheck:" "$COMPOSE"; then
    pass "healthcheck defined"
else
    warn "healthcheck not defined"
fi

# env_file references .env
if grep -q "\.env" "$COMPOSE"; then
    pass "env_file: .env referenced"
else
    warn "env_file: .env not referenced"
fi

# =============================================================================
# 8. シェルスクリプト構文チェック
# =============================================================================
section "8. Shell script syntax"

for script in "setup.sh" "entrypoint.sh"; do
    filepath="$PROJECT_ROOT/$script"
    [ -f "$filepath" ] || continue

    if bash -n "$filepath" 2>/dev/null; then
        pass "$script: syntax OK"
    else
        fail "$script: syntax ERROR"
    fi

    if [ -x "$filepath" ]; then
        pass "$script: executable"
    else
        warn "$script: not executable (run: chmod +x $script)"
    fi
done

# =============================================================================
# Summary
# =============================================================================
echo ""
bold "═══════════════════════════════════════════════════"
bold "  Test Results"
bold "═══════════════════════════════════════════════════"
green "  Passed:   $PASS"
if [ "$WARN" -gt 0 ]; then
    yellow "  Warnings: $WARN"
fi
if [ "$FAIL" -gt 0 ]; then
    red "  Failed:   $FAIL"
fi
echo ""

if [ "$FAIL" -gt 0 ]; then
    red "  RESULT: FAIL"
    exit 1
else
    green "  RESULT: ALL TESTS PASSED"
    exit 0
fi
