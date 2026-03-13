# Troubleshooting

[日本語版](troubleshooting_ja.md) | [← Back to top](../README.md)

---

## Diagnostic Command

Always start with:

```bash
./setup.sh --doctor
```

This checks Docker, OpenClaw, Ollama, ports, and file permissions in one run.

---

## Setup Issues

### Permission Denied

```bash
chmod +x setup.sh
./setup.sh
```

### Docker Not Found

**macOS:** `brew install --cask docker` then launch Docker Desktop.
**Ubuntu/Debian:** `curl -fsSL https://get.docker.com | sh && sudo usermod -aG docker $USER` then re-login.

### Docker Compose Not Found

Requires Docker Compose V2. Update Docker Desktop, or on Linux:
```bash
sudo apt-get install docker-compose-plugin
```

---

## Container Issues

### Container Won't Start

```bash
docker compose ps
docker compose logs openclaw
docker compose logs ollama
```

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Exited (1)` | Config error | Check logs for details |
| `Exited (137)` | Out of memory | Increase memory limits in docker-compose.yml |
| `Exited (126)` | Permission error | Check Dockerfile USER settings |

### Port Already in Use

```bash
lsof -i :18789    # Find the process
lsof -i :11434
```

Kill the conflicting process or change ports in `docker-compose.yml`.

### Health Check Failing

```bash
docker inspect --format='{{json .State.Health}}' openclaw | python3 -m json.tool
```

Check API keys in `secrets/` (or `.env`), network connectivity, or increase `start_period` for slow environments.

### Build Failures

```bash
docker compose build --no-cache
docker system df           # Check disk space
docker system prune -f     # Clean up
```

---

## Ollama Issues

### Can't Download Models

```bash
docker compose exec ollama curl -sf https://ollama.com && echo "OK" || echo "FAIL"
```

For proxy environments, add to `docker-compose.yml` ollama service:
```yaml
environment:
  - HTTP_PROXY=http://proxy.example.com:8080
  - HTTPS_PROXY=http://proxy.example.com:8080
```

### Slow Inference

- Use a smaller model (llama3.2 2B)
- Enable GPU ([GPU Support](docker-guide_en.md#gpu-support))
- Reduce `OLLAMA_NUM_PARALLEL` to `1`
- Reduce `OLLAMA_MAX_LOADED_MODELS` to `1`

### Model Not Recognized

```bash
docker compose exec ollama ollama pull llama3.2
docker compose restart ollama
```

---

## Network Issues

### OpenClaw Can't Connect to Ollama

```bash
docker compose exec openclaw curl -sf http://ollama:11434/api/tags && echo "OK"
```

Fix: `docker compose down && docker compose up -d`

### Can't Access Gateway from Host

```bash
curl -sf http://127.0.0.1:18789/health
docker compose ps --format "table {{.Name}}\t{{.Ports}}"
```

---

## ClawX Issues

### macOS: "Cannot verify developer"

System Settings → Privacy & Security → Click "Open Anyway"

Or: `xattr -cr /Applications/ClawX.app`

### Linux AppImage Won't Start

```bash
chmod +x ClawX.AppImage
# Ubuntu 22.04: sudo apt install libfuse2
# Ubuntu 24.04: sudo apt install libfuse2t64
sudo apt install libgtk-3-0t64 libnotify4t64 libxss1t64
```

### ClawX Can't Connect to OpenClaw

- Verify gateway is running: `docker compose ps`
- Check gateway URL in ClawX settings: `http://127.0.0.1:18789`

---

## Windows (WSL2) Issues

### WSL2 Won't Enable

Run PowerShell as Administrator: `wsl --install`

### WSL2 Network Issues

```powershell
wsl --shutdown
wsl
```

### WSL2 Memory

Create `%USERPROFILE%\.wslconfig`:
```ini
[wsl2]
memory=4GB
processors=2
```

---

## Reading Logs

### OpenClaw Patterns

| Pattern | Meaning |
|---------|---------|
| `Gateway started on :18789` | Normal startup |
| `Connection refused` | Can't reach external service |
| `ENOMEM` | Out of memory |

### Ollama Patterns

| Pattern | Meaning |
|---------|---------|
| `Listening on :11434` | Normal startup |
| `loading model` / `model loaded` | Model loading |
| `out of memory` | GPU/RAM insufficient |
| `model not found` | Model not installed |

---

## Full Reset

```bash
docker compose down -v                  # Remove containers + volumes
docker compose down -v --rmi all        # Also remove images
docker system prune -af --volumes       # Full clean
cp .env.example .env                    # Recreate config
# echo "your-key" > secrets/ANTHROPIC_API_KEY
./setup.sh                              # Re-setup
```

---

If issues persist, run `./setup.sh --doctor` and include the output when filing an Issue.

[← Security](security_en.md) | [Docker Guide](docker-guide_en.md) | [← Back to top](../README.md)
