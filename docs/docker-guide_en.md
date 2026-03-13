# Docker Operations Guide

[日本語版](docker-guide_ja.md) | [← Back to top](../README.md)

---

## Table of Contents

1. [Container Architecture](#container-architecture)
2. [Basic Operations](#basic-operations)
3. [Ollama Model Management](#ollama-model-management)
4. [Logging and Monitoring](#logging-and-monitoring)
5. [Backup and Restore](#backup-and-restore)
6. [GPU Support](#gpu-support)
7. [Scaling and Tuning](#scaling-and-tuning)
8. [Network Configuration](#network-configuration)

---

## Container Architecture

### Services

| Service | Image | Port | Role |
|---------|-------|------|------|
| `openclaw` | Custom build | 127.0.0.1:18789 | AI Agent Gateway |
| `ollama` | ollama/ollama:latest | 127.0.0.1:11434 | Local LLM inference |
| `ollama-init` | curlimages/curl | None | Auto-pull default model (first run) |

### Volumes

| Volume | Container Path | Contents |
|--------|---------------|----------|
| `openclaw-data` | `/home/openclaw/.openclaw` | Config, sessions, channel data |
| `ollama-models` | `/root/.ollama` | Downloaded LLM models |

> **About paths:** These paths are **inside the Docker container** (Linux). Containers always run Linux internally, so these paths work identically whether your host is macOS, Windows, or Linux. The actual host-side storage is managed automatically by Docker named volumes — no need to worry about OS-specific differences.

| Host OS | Where volumes are stored |
|---------|------------------------|
| Linux | `/var/lib/docker/volumes/<name>/_data` |
| macOS | Inside Docker Desktop's Linux VM (transparent to user) |
| Windows | Inside WSL2's Linux filesystem (transparent to user) |

---

## Basic Operations

### Start / Stop

```bash
docker compose up -d              # Start (background)
docker compose down               # Stop
docker compose restart             # Restart all
docker compose restart openclaw    # Restart specific service
```

### Status

```bash
docker compose ps
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
docker stats openclaw ollama
```

### Applying Configuration Changes

```bash
docker compose up -d                   # After .env changes
docker compose up -d --force-recreate  # After docker-compose.yml changes
docker compose up -d --build           # After Dockerfile changes
```

---

## Ollama Model Management

### Pull Models

```bash
docker compose exec ollama ollama pull llama3.2        # 2B, lightweight
docker compose exec ollama ollama pull llama3.2:7b     # 7B, balanced
docker compose exec ollama ollama pull gemma2          # 9B, Google
docker compose exec ollama ollama pull codellama       # 7B, code-focused
docker compose exec ollama ollama pull mistral         # 7B, fast
docker compose exec ollama ollama pull phi3            # 3.8B, Microsoft
docker compose exec ollama ollama pull llava           # 7B, vision
```

### List / Test / Remove

```bash
# List installed models
docker compose exec ollama ollama list
curl -s http://127.0.0.1:11434/api/tags | python3 -m json.tool

# Interactive chat
docker compose exec -it ollama ollama run llama3.2

# API test
curl -s http://127.0.0.1:11434/api/generate \
  -d '{"model": "llama3.2", "prompt": "Hello!", "stream": false}'

# Remove
docker compose exec ollama ollama rm <model-name>
```

### Model Size Reference

| Model | Download | Disk |
|-------|----------|------|
| llama3.2 (2B) | ~1.3 GB | ~1.3 GB |
| llama3.2:7b | ~4.7 GB | ~4.7 GB |
| gemma2 | ~5.4 GB | ~5.4 GB |
| codellama | ~3.8 GB | ~3.8 GB |

---

## Logging and Monitoring

```bash
docker compose logs -f                    # All services, real-time
docker compose logs -f openclaw           # OpenClaw only
docker compose logs --tail 100 openclaw   # Last 100 lines
docker compose logs -f --timestamps       # With timestamps
docker compose logs openclaw > openclaw.log 2>&1  # Export
```

### Health Checks

```bash
curl -sf http://127.0.0.1:18789/health && echo "OK" || echo "FAIL"
curl -sf http://127.0.0.1:11434/api/tags && echo "OK" || echo "FAIL"
./setup.sh --doctor
```

### Resource Monitoring

```bash
docker stats openclaw ollama
docker system df
docker compose exec ollama du -sh /root/.ollama/models/
```

---

## Backup and Restore

### Backup

```bash
# Config backup (.env, secrets/, docker-compose.yml)
cp .env .env.backup.$(date +%Y%m%d)
cp -r secrets/ secrets.backup.$(date +%Y%m%d)/

# Volume backup
docker run --rm \
  -v openclaw-easy-setup_openclaw-data:/data \
  -v $(pwd)/backup:/backup \
  alpine tar czf /backup/openclaw-data-$(date +%Y%m%d).tar.gz -C /data .
```

### Restore

```bash
docker run --rm \
  -v openclaw-easy-setup_openclaw-data:/data \
  -v $(pwd)/backup:/backup \
  alpine sh -c "rm -rf /data/* && tar xzf /backup/openclaw-data-YYYYMMDD.tar.gz -C /data"
```

### Ollama Models

Models are large — re-downloading is recommended over backup:

```bash
# Save model list
docker compose exec ollama ollama list > ollama-models-list.txt

# Re-pull from list
while read model _; do docker compose exec ollama ollama pull "$model"; done < ollama-models-list.txt
```

---

## GPU Support

### NVIDIA GPU

```bash
# Verify driver
nvidia-smi

# Install NVIDIA Container Toolkit (Ubuntu/Debian)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker
```

Uncomment GPU section in `docker-compose.yml`:

```yaml
ollama:
  deploy:
    resources:
      reservations:
        devices:
          - driver: nvidia
            count: all
            capabilities: [gpu]
```

```bash
docker compose up -d
docker compose exec ollama nvidia-smi
```

### Apple Silicon

Docker Desktop for Mac does not support GPU passthrough. For GPU acceleration on Apple Silicon, install Ollama natively:

```bash
brew install ollama
ollama serve
```

---

## Scaling and Tuning

### Ollama Performance

In `.env`:

```env
OLLAMA_NUM_PARALLEL=2        # Parallel requests
OLLAMA_MAX_LOADED_MODELS=2   # Models kept in memory
```

### Resource Adjustments

```yaml
# docker-compose.yml
openclaw:
  deploy:
    resources:
      limits:
        memory: 4G
        cpus: "4.0"

ollama:
  deploy:
    resources:
      limits:
        memory: 16G    # For larger models
        cpus: "8.0"
```

### Slow Startup

Extend `start_period` for slow environments:

```yaml
healthcheck:
  start_period: 120s
```

---

## Network Configuration

### Default

```
Host (127.0.0.1)
├── :18789 → openclaw
└── :11434 → ollama

openclaw-net (172.28.0.0/16) — internal bridge
```

### Reverse Proxy (For External Access)

Always use TLS. Example nginx config:

```nginx
server {
    listen 443 ssl;
    server_name openclaw.example.com;

    ssl_certificate     /etc/ssl/certs/openclaw.crt;
    ssl_certificate_key /etc/ssl/private/openclaw.key;

    location / {
        proxy_pass http://127.0.0.1:18789;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

---

Next → [Troubleshooting](troubleshooting_en.md) | [Security Design](security_en.md)
