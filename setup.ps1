#Requires -Version 5.1
<#
.SYNOPSIS
    openclaw-easy-setup — Windows PowerShell installer
.DESCRIPTION
    Silent, security-focused installer for OpenClaw (+ optional ClawX, Docker, Ollama)
    Requires Windows 10+ with WSL2 for OpenClaw gateway.
    ClawX runs natively on Windows.
.PARAMETER WithClawX
    Also install ClawX desktop GUI
.PARAMETER WithDocker
    Also install/configure Docker Desktop
.PARAMETER WithOllama
    Also install Ollama for local LLM inference
.PARAMETER ConfigFile
    Path to config.env (default: .\config.env)
.PARAMETER Doctor
    Run diagnostics only
.PARAMETER Uninstall
    Uninstall OpenClaw and ClawX
.EXAMPLE
    .\setup.ps1
    .\setup.ps1 -WithClawX -WithOllama
    .\setup.ps1 -ConfigFile .\my-config.env -WithDocker
#>

[CmdletBinding()]
param(
    [switch]$WithClawX,
    [switch]$WithDocker,
    [switch]$WithOllama,
    [string]$ConfigFile = "config.env",
    [switch]$Doctor,
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"  # Faster downloads

# ── Logging ──────────────────────────────────────────────────────────────────
$LogFile = "setup.log"

function Write-Log   { param($Msg) $ts = Get-Date -Format "HH:mm:ss"; "[$ts] $Msg" | Tee-Object -FilePath $LogFile -Append | Write-Host -ForegroundColor Green }
function Write-Warn  { param($Msg) $ts = Get-Date -Format "HH:mm:ss"; "[$ts] WARN: $Msg" | Tee-Object -FilePath $LogFile -Append | Write-Host -ForegroundColor Yellow }
function Write-Err   { param($Msg) $ts = Get-Date -Format "HH:mm:ss"; "[$ts] ERROR: $Msg" | Tee-Object -FilePath $LogFile -Append | Write-Host -ForegroundColor Red }
function Write-Info  { param($Msg) $ts = Get-Date -Format "HH:mm:ss"; "[$ts] $Msg" | Tee-Object -FilePath $LogFile -Append | Write-Host -ForegroundColor Cyan }

# ── Configuration defaults ───────────────────────────────────────────────────
$Config = @{
    NODE_MAJOR_VERSION       = 22
    OPENCLAW_INSTALL_METHOD  = "script"
    OPENCLAW_VERSION         = ""
    OPENCLAW_GATEWAY_BIND    = "loopback"
    OPENCLAW_GATEWAY_PORT    = 18789
    OPENCLAW_AUTH_MODE       = "token"
    OPENCLAW_AUTH_TOKEN      = ""
    OPENCLAW_DM_POLICY       = "pairing"
    OPENCLAW_REQUIRE_MENTION = "true"
    OPENCLAW_DENY_TOOLS      = "exec,browser,cron"
    AI_PROVIDER              = ""
    ANTHROPIC_API_KEY        = ""
    OPENAI_API_KEY           = ""
    OLLAMA_BASE_URL          = "http://127.0.0.1:11434"
    INSTALL_CLAWX            = "false"
    INSTALL_DOCKER           = "false"
    INSTALL_OLLAMA           = "false"
    CLAWX_VERSION            = ""
    HTTP_PROXY               = ""
    HTTPS_PROXY              = ""
    VERBOSE                  = "false"
}

# ── Load config.env ──────────────────────────────────────────────────────────
function Import-ConfigEnv {
    param([string]$Path)
    if (Test-Path $Path) {
        Write-Info "Loading configuration from $Path"
        Get-Content $Path | ForEach-Object {
            $line = $_.Trim()
            if ($line -and -not $line.StartsWith('#')) {
                $parts = $line -split '=', 2
                if ($parts.Count -eq 2) {
                    $key = $parts[0].Trim()
                    $val = $parts[1].Trim()
                    if ($Config.ContainsKey($key)) {
                        $Config[$key] = $val
                    }
                }
            }
        }
    }
}

Import-ConfigEnv -Path $ConfigFile

# Override from CLI flags
if ($WithClawX)  { $Config.INSTALL_CLAWX  = "true" }
if ($WithDocker) { $Config.INSTALL_DOCKER = "true" }
if ($WithOllama) { $Config.INSTALL_OLLAMA = "true" }

# ── WSL2 check ───────────────────────────────────────────────────────────────
function Test-WSL2 {
    try {
        $wslOutput = wsl --list --verbose 2>&1
        if ($wslOutput -match "WSL 2") {
            return $true
        }
    } catch {}
    return $false
}

function Install-WSL2 {
    Write-Info "Enabling WSL2..."
    try {
        wsl --install --no-distribution 2>&1 | Out-Null
        Write-Log "WSL2 enabled. A restart may be required."
    } catch {
        Write-Err "Failed to enable WSL2. Run 'wsl --install' manually as Administrator."
        throw
    }

    # Install Ubuntu
    Write-Info "Installing Ubuntu for WSL2..."
    try {
        wsl --install -d Ubuntu 2>&1 | Out-Null
        Write-Log "Ubuntu WSL2 distribution installed"
    } catch {
        Write-Warn "Ubuntu WSL2 installation may require a restart and manual completion."
    }
}

# ── Node.js (Windows native — for ClawX build; WSL2 uses its own) ───────────
function Install-NodeWindows {
    $nodePath = Get-Command node -ErrorAction SilentlyContinue
    if ($nodePath) {
        $ver = (node -v) -replace 'v', '' -split '\.' | Select-Object -First 1
        if ([int]$ver -ge $Config.NODE_MAJOR_VERSION) {
            Write-Log "Node.js v$(node -v) already installed"
            return
        }
    }

    Write-Info "Installing Node.js v$($Config.NODE_MAJOR_VERSION) via winget..."
    try {
        winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements --silent 2>&1 | Out-Null
        Write-Log "Node.js installed via winget"
    } catch {
        Write-Warn "winget install failed. Downloading from nodejs.org..."
        $url = "https://nodejs.org/dist/latest-v$($Config.NODE_MAJOR_VERSION).x/node-v$($Config.NODE_MAJOR_VERSION).0.0-x64.msi"
        $msi = Join-Path $env:TEMP "node-setup.msi"
        Invoke-WebRequest -Uri $url -OutFile $msi
        Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /qn" -Wait -NoNewWindow
        Remove-Item $msi -ErrorAction SilentlyContinue
        Write-Log "Node.js installed via MSI"
    }
}

# ── OpenClaw in WSL2 ─────────────────────────────────────────────────────────
function Install-OpenClawWSL {
    Write-Info "Installing OpenClaw inside WSL2..."

    $wslScript = @"
#!/bin/bash
set -e

# Install Node.js if needed
if ! command -v node &>/dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_$($Config.NODE_MAJOR_VERSION).x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# Install OpenClaw
curl -fsSL https://openclaw.ai/install.sh | bash

# Security hardening
OC_DIR="\$HOME/.openclaw"
mkdir -p "\$OC_DIR"

cat > "\$OC_DIR/openclaw.json" <<'JSON5'
{
  // Auto-generated by openclaw-easy-setup
  gateway: {
    bind: "$($Config.OPENCLAW_GATEWAY_BIND)",
    port: $($Config.OPENCLAW_GATEWAY_PORT),
    auth: {
      mode: "$($Config.OPENCLAW_AUTH_MODE)",
    },
  },
  messaging: {
    dmPolicy: "$($Config.OPENCLAW_DM_POLICY)",
    requireMention: $($Config.OPENCLAW_REQUIRE_MENTION),
  },
  tools: {
    deny: ["exec", "browser", "cron"],
  },
  security: {
    sandboxInheritEnv: false,
  },
}
JSON5

chmod 700 "\$OC_DIR"
chmod 600 "\$OC_DIR/openclaw.json"

# Store API keys
ENV_FILE="\$OC_DIR/.env"
> "\$ENV_FILE"
$( if ($Config.ANTHROPIC_API_KEY) { "echo 'ANTHROPIC_API_KEY=$($Config.ANTHROPIC_API_KEY)' >> \`"\$ENV_FILE\`"" } )
$( if ($Config.OPENAI_API_KEY) { "echo 'OPENAI_API_KEY=$($Config.OPENAI_API_KEY)' >> \`"\$ENV_FILE\`"" } )
chmod 600 "\$ENV_FILE"

# Generate auth token
if [ "$($Config.OPENCLAW_AUTH_MODE)" = "token" ]; then
    TOKEN=\$(openssl rand -hex 32)
    # Inject token into JSON5 config using Node.js one-liner
    node -e "
      const fs = require('fs');
      const p = '\$OC_DIR/openclaw.json';
      let c = fs.readFileSync(p, 'utf8');
      c = c.replace(/mode: \"token\",/, 'mode: \"token\",\n      token: \"\$TOKEN\",');
      fs.writeFileSync(p, c);
    "
fi

echo "OpenClaw installation complete"
openclaw doctor 2>/dev/null || true
"@

    $tempScript = Join-Path $env:TEMP "openclaw-wsl-setup.sh"
    $wslScript | Out-File -FilePath $tempScript -Encoding utf8 -Force
    $wslPath = wsl wslpath -u ($tempScript -replace '\\', '/')
    wsl bash $wslPath
    Remove-Item $tempScript -ErrorAction SilentlyContinue

    Write-Log "OpenClaw installed in WSL2"
}

# ── Ollama ───────────────────────────────────────────────────────────────────
function Install-Ollama {
    if ($Config.INSTALL_OLLAMA -ne "true") {
        Write-Info "Skipping Ollama installation"
        return
    }

    $ollamaPath = Get-Command ollama -ErrorAction SilentlyContinue
    if ($ollamaPath) {
        Write-Log "Ollama already installed: $(ollama --version 2>&1)"
        return
    }

    Write-Info "Installing Ollama..."
    try {
        winget install Ollama.Ollama --accept-source-agreements --accept-package-agreements --silent 2>&1 | Out-Null
        Write-Log "Ollama installed via winget"
    } catch {
        Write-Info "Downloading Ollama installer..."
        $installer = Join-Path $env:TEMP "OllamaSetup.exe"
        Invoke-WebRequest -Uri "https://ollama.com/download/OllamaSetup.exe" -OutFile $installer
        Start-Process -FilePath $installer -ArgumentList "/SILENT" -Wait -NoNewWindow
        Remove-Item $installer -ErrorAction SilentlyContinue
        Write-Log "Ollama installed"
    }

    # Pull a default model
    Write-Info "Pulling default model (llama3.2)..."
    try {
        $env:PATH = "$env:LOCALAPPDATA\Programs\Ollama;$env:PATH"
        & ollama pull llama3.2 2>&1 | Out-Null
        Write-Log "Default model (llama3.2) pulled"
    } catch {
        Write-Warn "Could not pull default model. Run 'ollama pull llama3.2' manually after restart."
    }
}

# ── Docker Desktop ───────────────────────────────────────────────────────────
function Install-Docker {
    if ($Config.INSTALL_DOCKER -ne "true") {
        Write-Info "Skipping Docker installation"
        return
    }

    $dockerPath = Get-Command docker -ErrorAction SilentlyContinue
    if ($dockerPath) {
        Write-Log "Docker already installed: $(docker --version 2>&1)"
        return
    }

    Write-Info "Installing Docker Desktop..."
    try {
        winget install Docker.DockerDesktop --accept-source-agreements --accept-package-agreements --silent 2>&1 | Out-Null
        Write-Log "Docker Desktop installed via winget"
        Write-Warn "Docker Desktop requires a restart and manual first launch."
    } catch {
        Write-Err "Docker Desktop installation failed. Download from https://www.docker.com/products/docker-desktop/"
    }
}

# ── ClawX ────────────────────────────────────────────────────────────────────
function Install-ClawX {
    if ($Config.INSTALL_CLAWX -ne "true") {
        Write-Info "Skipping ClawX installation"
        return
    }

    Write-Info "Installing ClawX..."

    $releasesUrl = "https://api.github.com/repos/ValueCell-ai/ClawX/releases/latest"
    try {
        $release = Invoke-RestMethod -Uri $releasesUrl -Headers @{ "User-Agent" = "openclaw-easy-setup" }
    } catch {
        Write-Warn "Could not fetch ClawX releases. Visit: https://github.com/ValueCell-ai/ClawX/releases"
        return
    }

    $asset = $release.assets | Where-Object { $_.name -match "win-x64\.exe$" } | Select-Object -First 1
    if (-not $asset) {
        Write-Warn "No Windows installer found in latest ClawX release."
        return
    }

    $installer = Join-Path $env:TEMP $asset.name
    Write-Info "Downloading $($asset.name) ($([math]::Round($asset.size / 1MB, 1)) MB)..."
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $installer

    Write-Info "Running ClawX installer..."
    Start-Process -FilePath $installer -ArgumentList "/S" -Wait -NoNewWindow
    Remove-Item $installer -ErrorAction SilentlyContinue

    Write-Log "ClawX installed"
}

# ── Doctor ───────────────────────────────────────────────────────────────────
function Invoke-Doctor {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  openclaw-easy-setup - Diagnostics"       -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""

    $issues = 0

    # WSL2
    if (Test-WSL2) { Write-Log "WSL2: Available" }
    else { Write-Err "WSL2: Not available"; $issues++ }

    # Node.js (Windows)
    $node = Get-Command node -ErrorAction SilentlyContinue
    if ($node) { Write-Log "Node.js (Windows): $(node -v)" }
    else { Write-Warn "Node.js (Windows): Not found (needed only for ClawX dev)" }

    # Node.js (WSL2)
    try {
        $wslNode = wsl node -v 2>&1
        Write-Log "Node.js (WSL2): $wslNode"
    } catch {
        Write-Err "Node.js (WSL2): Not found"; $issues++
    }

    # OpenClaw (WSL2)
    try {
        $wslOC = wsl openclaw --version 2>&1
        Write-Log "OpenClaw (WSL2): $wslOC"
    } catch {
        Write-Err "OpenClaw (WSL2): Not found"; $issues++
    }

    # Docker
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if ($docker) { Write-Log "Docker: $(docker --version 2>&1)" }
    else { Write-Info "Docker: Not installed (optional)" }

    # Ollama
    $ollama = Get-Command ollama -ErrorAction SilentlyContinue
    if ($ollama) { Write-Log "Ollama: $(ollama --version 2>&1)" }
    else { Write-Info "Ollama: Not installed (optional)" }

    # ClawX
    $clawx = Get-Command ClawX -ErrorAction SilentlyContinue
    if ($clawx -or (Test-Path "$env:LOCALAPPDATA\Programs\ClawX\ClawX.exe")) {
        Write-Log "ClawX: Installed"
    } else {
        Write-Info "ClawX: Not installed (optional)"
    }

    Write-Host ""
    if ($issues -eq 0) { Write-Log "All checks passed!" }
    else { Write-Warn "$issues issue(s) found." }
}

# ── Main ─────────────────────────────────────────────────────────────────────
function Main {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "  openclaw-easy-setup v1.0.0 (Windows)"            -ForegroundColor Cyan
    Write-Host "  Security-focused silent installer"               -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ""

    if ($Doctor) {
        Invoke-Doctor
        return
    }

    if ($Uninstall) {
        Write-Warn "Uninstall: Removing OpenClaw from WSL2..."
        wsl bash -c "npm uninstall -g openclaw 2>/dev/null; rm -rf ~/.openclaw" 2>&1 | Out-Null
        Write-Log "OpenClaw removed from WSL2"
        return
    }

    # Check admin for WSL install
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Warn "Some features (WSL2 install, Docker) may require Administrator privileges."
    }

    # Step 1: WSL2
    if (-not (Test-WSL2)) {
        Write-Info "WSL2 not detected. Setting up..."
        Install-WSL2
    } else {
        Write-Log "WSL2 available"
    }

    # Step 2: Node.js (native Windows — for tools/ClawX)
    Install-NodeWindows

    # Step 3: OpenClaw in WSL2
    Install-OpenClawWSL

    # Step 4: Optional components
    Install-Docker
    Install-Ollama
    Install-ClawX

    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Green
    Write-Host "  Installation complete!                          " -ForegroundColor Green
    Write-Host "==================================================" -ForegroundColor Green
    Write-Host ""
    Write-Info "Next steps:"
    Write-Host "  1. Restart your terminal"
    Write-Host "  2. Verify:  wsl openclaw doctor"
    Write-Host "  3. Start:   wsl openclaw up"
    Write-Host "  4. Open:    wsl openclaw dashboard"
    if ($Config.INSTALL_CLAWX -eq "true") {
        Write-Host "  5. Launch ClawX from Start menu"
    }
    if ($Config.INSTALL_OLLAMA -eq "true") {
        Write-Host ""
        Write-Host "  Ollama: ollama serve  (then: ollama pull llama3.2)"
    }
    Write-Host ""
    Write-Info "Security: Gateway=$($Config.OPENCLAW_GATEWAY_BIND), Auth=$($Config.OPENCLAW_AUTH_MODE)"
    Write-Log "Setup log saved to: $LogFile"
}

Main
