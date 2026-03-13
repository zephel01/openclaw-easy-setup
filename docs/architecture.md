# Architecture / アーキテクチャ

[← Back to top / トップに戻る](../README.md)

---

## System Overview / システム概要

```mermaid
graph TB
    subgraph "User Devices / ユーザーデバイス"
        WA[WhatsApp]
        TG[Telegram]
        SL[Slack]
        DS[Discord]
        CX[ClawX Desktop]
    end

    subgraph "Host Machine / ホストマシン"
        subgraph "Docker Network (172.28.0.0/16)"
            subgraph "openclaw container"
                GW[OpenClaw Gateway<br/>:18789]
                AG[AI Agent Engine]
                SK[Skill System]
            end

            subgraph "ollama container"
                OL[Ollama Server<br/>:11434]
                MD[LLM Models<br/>llama3.2, gemma2...]
            end
        end

        subgraph "Volumes"
            V1[(openclaw-data)]
            V2[(ollama-models)]
        end
    end

    subgraph "External APIs / 外部API"
        AN[Anthropic API]
        OA[OpenAI API]
    end

    WA & TG & SL & DS -->|Message| GW
    CX -->|JSON-RPC| GW
    GW --> AG
    AG --> SK
    AG -->|Local LLM| OL
    OL --> MD
    AG -->|API Call| AN
    AG -->|API Call| OA
    GW -.->|Config/Sessions| V1
    OL -.->|Model Storage| V2

    style GW fill:#4A90D9,color:#fff
    style OL fill:#6B8E23,color:#fff
    style CX fill:#E67E22,color:#fff
```

---

## Docker Container Architecture / コンテナ構成

```mermaid
graph LR
    subgraph "Host Ports (127.0.0.1 only)"
        P1[":18789"]
        P2[":11434"]
    end

    subgraph "openclaw container"
        direction TB
        TINI[tini PID 1]
        NODE[Node.js Runtime]
        OC[openclaw up]
        TINI --> NODE --> OC
    end

    subgraph "ollama container"
        direction TB
        OLSRV[Ollama Server]
        GPU["GPU / CPU<br/>Inference"]
        OLSRV --> GPU
    end

    subgraph "ollama-init (one-shot)"
        CURL[curl → pull model]
    end

    P1 -->|NAT| OC
    P2 -->|NAT| OLSRV
    OC -->|"http://ollama:11434"| OLSRV
    CURL -->|"http://ollama:11434/api/pull"| OLSRV

    style P1 fill:#D32F2F,color:#fff
    style P2 fill:#D32F2F,color:#fff
```

---

## Security Layers / セキュリティレイヤー

```mermaid
graph TB
    subgraph "Layer 1: Network / ネットワーク層"
        FW[OS Firewall]
        LB["127.0.0.1 Binding<br/>(No external access)"]
    end

    subgraph "Layer 2: Container / コンテナ層"
        NP["no-new-privileges"]
        RO["read_only filesystem"]
        CD["cap_drop: ALL"]
        NR["Non-root user"]
        RL["Resource limits<br/>Memory / CPU"]
    end

    subgraph "Layer 3: Application / アプリケーション層"
        TK["Token Authentication"]
        DM["DM Pairing Policy"]
        TD["Tool Deny List<br/>(exec, browser, cron)"]
        SB["Sandbox Isolation"]
    end

    subgraph "Layer 4: Credentials / 認証情報層"
        EF[".env (chmod 600)"]
        KC["OS Keychain (ClawX)"]
        GI[".gitignore"]
    end

    FW --> NP
    LB --> NP
    NP --> TK
    RO --> TK
    CD --> TK
    NR --> TK
    RL --> TK
    TK --> EF
    DM --> EF
    TD --> EF
    SB --> EF

    style FW fill:#C62828,color:#fff
    style NP fill:#E65100,color:#fff
    style TK fill:#1565C0,color:#fff
    style EF fill:#2E7D32,color:#fff
```

---

## Data Flow / データフロー

```mermaid
sequenceDiagram
    participant U as User
    participant MP as Messaging Platform<br/>(Telegram, Slack...)
    participant GW as OpenClaw Gateway
    participant AG as Agent Engine
    participant OL as Ollama (Local)
    participant API as External API<br/>(Anthropic/OpenAI)

    U->>MP: Send message
    MP->>GW: Webhook / Polling
    GW->>GW: Auth check (token)
    GW->>GW: DM policy check

    alt Local LLM (Ollama)
        GW->>AG: Route to agent
        AG->>OL: POST /api/generate
        OL-->>AG: LLM response
    else External API
        GW->>AG: Route to agent
        AG->>API: API request
        API-->>AG: API response
    end

    AG->>AG: Execute tools/skills
    AG-->>GW: Agent response
    GW-->>MP: Send reply
    MP-->>U: Display response
```

---

## ClawX Architecture / ClawX アーキテクチャ

```mermaid
graph TB
    subgraph "ClawX Desktop App (Electron)"
        subgraph "Main Process"
            KC[Keychain Manager<br/>AES-256-GCM]
            IPC[IPC Handler]
            GWP[Gateway Process<br/>Manager]
        end

        subgraph "Renderer Process (React)"
            UI[Chat Interface]
            CH[Channel Manager]
            MK[Skill Marketplace]
            SCH[Cron Scheduler]
        end
    end

    subgraph "OpenClaw Gateway"
        RPC[JSON-RPC Server]
    end

    UI --> IPC
    CH --> IPC
    MK --> IPC
    SCH --> IPC
    IPC --> KC
    IPC <-->|"WebSocket → HTTP → IPC<br/>(fallback chain)"| RPC
    GWP -->|Start/Stop| RPC

    style KC fill:#4CAF50,color:#fff
    style RPC fill:#4A90D9,color:#fff
    style UI fill:#E67E22,color:#fff
```

---

## File Structure / ファイル構成

```mermaid
graph TD
    ROOT["openclaw-easy-setup/"]
    README["README.md"]
    SETUP_SH["setup.sh<br/>(macOS/Linux)"]
    SETUP_PS["setup.ps1<br/>(Windows)"]
    DC["docker-compose.yml"]
    DF["Dockerfile"]
    ENV[".env.example → .env"]
    CFG["config.env"]
    DOCS["docs/"]
    D_SETUP["setup-guide_ja/en.md"]
    D_SEC["security_ja/en.md"]
    D_DOCK["docker-guide_ja/en.md"]
    D_TRBL["troubleshooting_ja/en.md"]
    D_ARCH["architecture.md"]

    ROOT --> README
    ROOT --> SETUP_SH
    ROOT --> SETUP_PS
    ROOT --> DC
    ROOT --> DF
    ROOT --> ENV
    ROOT --> CFG
    ROOT --> DOCS
    DOCS --> D_SETUP
    DOCS --> D_SEC
    DOCS --> D_DOCK
    DOCS --> D_TRBL
    DOCS --> D_ARCH

    style ROOT fill:#37474F,color:#fff
    style DOCS fill:#5D4037,color:#fff
```

---

## Cross-Platform Path Strategy / クロスプラットフォームのパス戦略

### Why all paths look like Linux / なぜすべてのパスが Linux 形式なのか

This project uses Linux-style paths (`/home/openclaw/.openclaw`) in Dockerfile, entrypoint.sh, and docker-compose.yml. This is intentional — **Docker containers always run Linux internally**, regardless of the host OS.

このプロジェクトでは Dockerfile、entrypoint.sh、docker-compose.yml で Linux 形式のパス（`/home/openclaw/.openclaw`）を使っています。これは意図的なものです — **Docker コンテナの内部は常に Linux** であり、ホスト OS に関係ありません。

```mermaid
graph TB
    subgraph "macOS Host"
        DD1[Docker Desktop for Mac]
        VM1["Linux VM (HyperKit / Virtualization.framework)"]
        DD1 --> VM1
        VM1 --> C1["Container<br/>/home/openclaw/.openclaw"]
    end

    subgraph "Windows Host"
        DD2[Docker Desktop for Windows]
        VM2["WSL2 / Hyper-V (Linux kernel)"]
        DD2 --> VM2
        VM2 --> C2["Container<br/>/home/openclaw/.openclaw"]
    end

    subgraph "Linux Host"
        DE[Docker Engine]
        DE --> C3["Container<br/>/home/openclaw/.openclaw"]
    end

    style C1 fill:#4A90D9,color:#fff
    style C2 fill:#4A90D9,color:#fff
    style C3 fill:#4A90D9,color:#fff
```

### Path mapping by OS and install mode / OS・インストール方式別のパス対応表

| Component | Path | Scope | Notes |
|-----------|------|-------|-------|
| `Dockerfile` | `/home/openclaw/.openclaw` | Container only | Always Linux — works on all host OSes |
| `entrypoint.sh` | `/home/openclaw/.openclaw` | Container only | Runs inside Linux container |
| `docker-compose.yml` volumes | `openclaw-data` → `/home/openclaw/.openclaw` | Container only | Docker manages host-side storage |
| `setup.sh --native` | `$HOME/.openclaw` | Host machine | Expands correctly on macOS and Linux |
| `setup.ps1` (Windows) | WSL2 internal: `$HOME/.openclaw` | WSL2 (Linux) | OpenClaw runs inside WSL2 |
| ClawX (Desktop) | OS-native paths | Host machine | Electron manages its own config location |

| コンポーネント | パス | スコープ | 備考 |
|-------------|------|---------|------|
| `Dockerfile` | `/home/openclaw/.openclaw` | コンテナ内部のみ | 常に Linux — 全ホスト OS で動作 |
| `entrypoint.sh` | `/home/openclaw/.openclaw` | コンテナ内部のみ | Linux コンテナ内で実行される |
| `docker-compose.yml` ボリューム | `openclaw-data` → `/home/openclaw/.openclaw` | コンテナ内部のみ | Docker がホスト側のストレージを管理 |
| `setup.sh --native` | `$HOME/.openclaw` | ホストマシン | macOS・Linux で正しく展開される |
| `setup.ps1`（Windows） | WSL2 内部: `$HOME/.openclaw` | WSL2（Linux） | OpenClaw は WSL2 内で動作 |
| ClawX（デスクトップ） | OS ネイティブパス | ホストマシン | Electron が独自の設定パスを管理 |

### How Docker volumes abstract host paths / Docker ボリュームによるパス抽象化

When you use **named volumes** (e.g., `openclaw-data`), Docker manages the actual storage location on the host automatically:

**名前付きボリューム**（例: `openclaw-data`）を使う場合、Docker がホスト上の実際の保存場所を自動管理します：

| Host OS | Actual volume storage location |
|---------|-------------------------------|
| Linux | `/var/lib/docker/volumes/openclaw-easy-setup_openclaw-data/_data` |
| macOS | Inside Docker Desktop's Linux VM (transparent to user) |
| Windows | Inside WSL2's Linux filesystem (transparent to user) |

Users never need to know these host paths — Docker handles everything. The `docker volume` commands work identically on all platforms.

ユーザーがホスト側のパスを知る必要はありません。Docker がすべて処理します。`docker volume` コマンドは全プラットフォームで同じように動作します。

---

## Port Map / ポートマップ

| Port | Service | Bound To | Protocol | Purpose |
|------|---------|----------|----------|---------|
| 18789 | OpenClaw Gateway | 127.0.0.1 | HTTP/WS | AI agent API, dashboard |
| 11434 | Ollama | 127.0.0.1 | HTTP | LLM inference API |

---

## Volume Map / ボリュームマップ

| Volume | Container Path | Purpose |
|--------|---------------|---------|
| `openclaw-data` | `/home/openclaw/.openclaw` | Config, sessions, channels |
| `ollama-models` | `/root/.ollama` | Downloaded LLM model weights |
| `./config/openclaw` (bind) | `/etc/openclaw` (read-only) | Host config overlay |

---

## Technology Stack / 技術スタック

| Layer | Technology |
|-------|-----------|
| Container | Docker, Docker Compose |
| Runtime | Node.js 22, tini |
| AI Gateway | OpenClaw |
| Local LLM | Ollama |
| Desktop GUI | ClawX (Electron + React) |
| Credential Storage | OS Keychain (macOS Keychain, Windows Credential Manager, libsecret) |
| Encryption | AES-256-GCM |
| Init System | tini (PID 1) |
