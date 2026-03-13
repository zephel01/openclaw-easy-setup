# =============================================================================
# openclaw-easy-setup — Security-hardened OpenClaw Dockerfile
# Multi-stage build for minimal attack surface
# =============================================================================

# ── Stage 1: Build ───────────────────────────────────────────────────────────
# Use full node image (not -slim) — includes git, python3, make, g++ etc.
# needed for native modules (sharp) and git-based npm dependencies.
FROM node:22 AS builder

WORKDIR /build

# Install OpenClaw (133MB+ with native deps like sharp)
# --unsafe-perm allows postinstall scripts to run as root in Docker
RUN npm install -g openclaw --unsafe-perm

# Prune cache
RUN npm cache clean --force && \
    rm -rf /tmp/* /var/tmp/*

# ── Stage 2: Runtime ─────────────────────────────────────────────────────────
FROM node:22-slim AS runtime

# Security: Add non-root user
RUN groupadd -r openclaw && \
    useradd -r -g openclaw -m -d /home/openclaw -s /bin/bash openclaw

# Minimal runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        tini \
        jq \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy OpenClaw from builder
COPY --from=builder /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=builder /usr/local/bin /usr/local/bin

# ── Default config (stored OUTSIDE the volume mount path) ─────────────────
# This config is copied into the volume on first run by entrypoint.sh.
# It lives at /defaults/ so it survives the empty volume mount over ~/.openclaw.
RUN mkdir -p /defaults
RUN cat > /defaults/openclaw.json <<'EOF'
{
  "gateway": {
    "mode": "local",
    "bind": "lan",
    "port": 18789
  },
  "tools": {
    "deny": ["exec", "browser", "cron"]
  }
}
EOF

# ── Prepare directories ──────────────────────────────────────────────────
# Data dir (will be overlaid by Docker volume — entrypoint handles init)
RUN mkdir -p /home/openclaw/.openclaw \
             /home/openclaw/.cache \
             /home/openclaw/.npm \
             /home/openclaw/.config && \
    chown -R openclaw:openclaw /home/openclaw /defaults

# Configuration overlay directory
RUN mkdir -p /etc/openclaw && \
    chown openclaw:openclaw /etc/openclaw

# Copy entrypoint script
COPY --chown=openclaw:openclaw entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Security: Remove unnecessary binaries
RUN rm -f /usr/bin/apt* /usr/bin/dpkg* 2>/dev/null || true

# Use non-root user
USER openclaw
WORKDIR /home/openclaw

EXPOSE 18789

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -sf http://localhost:18789/health || exit 1

# Use tini as init system
ENTRYPOINT ["tini", "--"]
CMD ["entrypoint.sh"]
