# セットアップガイド（日本語）

[English version](setup-guide_en.md) | [← トップに戻る](../README.md)

---

## 目次

1. [前提条件](#前提条件)
2. [Docker セットアップ（推奨）](#docker-セットアップ推奨)
3. [Docker 環境のパスについて](#docker-環境のパスについて)
4. [ネイティブセットアップ](#ネイティブセットアップ)
5. [Windows セットアップ](#windows-セットアップ)
6. [ClawX のインストール](#clawx-のインストール)
7. [初期設定ウィザード](#初期設定ウィザード)
8. [config.env リファレンス](#configenv-リファレンス)
9. [AIプロバイダーの設定](#aiプロバイダーの設定)
10. [アップデート手順](#アップデート手順)

---

## 前提条件

### Docker セットアップの場合

| 項目 | 要件 |
|------|------|
| OS | macOS 11+, Ubuntu 20.04+, Windows 10+ (WSL2) |
| Docker | Docker Desktop または Docker Engine 20+ |
| Docker Compose | v2（Docker Desktop に同梱） |
| RAM | 最低 4GB / 推奨 8GB以上 |
| ディスク | 5GB以上の空き容量 |
| ネットワーク | 初回のみインターネット接続が必要 |

### ネイティブセットアップの場合

上記に加えて：

| 項目 | 要件 |
|------|------|
| Node.js | v22 以上 |
| npm | v9 以上（Node.js に同梱） |
| git | 最新版推奨 |

### ハードウェアガイドライン

Ollama で使用するモデルに応じてメモリ要件が変わります：

| モデルサイズ | 必要RAM | 推奨GPU VRAM |
|-------------|---------|-------------|
| 2B (llama3.2) | 4GB | 不要 |
| 7B (llama3.2:7b, codellama) | 8GB | 4GB |
| 13B | 16GB | 8GB |
| 70B | 64GB | 40GB+ |

> GPU が無い場合でも CPU で動作しますが、推論速度が低下します。

---

## Docker セットアップ（推奨）

### Step 1: リポジトリのクローン

```bash
git clone https://github.com/zephel01/openclaw-easy-setup.git
cd openclaw-easy-setup
```

### Step 2: 環境変数と API キーの設定

```bash
cp .env.example .env
```

#### API キーの設定（secrets/ ディレクトリを推奨）

API キーやトークンは `secrets/` ディレクトリに個別ファイルとして配置します。
これにより `docker inspect` や環境変数経由での漏洩リスクを低減できます。

```bash
# Anthropic Claude
echo "sk-ant-api03-xxxxx" > secrets/ANTHROPIC_API_KEY

# OpenAI
echo "sk-xxxxx" > secrets/OPENAI_API_KEY

# Ollama のみ利用する場合（APIキー不要）
# → 上記の手順をスキップしてください
```

> **注意**: `.env` に直接 API キーを書いても動作しますが、セキュリティ上
> `secrets/` を使う方が安全です。詳しくは `secrets/README.md` を参照してください。

#### その他の環境変数（.env）

`.env` を開いて必要な値を設定します：

```env
# === オプション ===

# 認証トークン（空の場合は自動生成）
OPENCLAW_AUTH_TOKEN=

# デフォルトの Ollama モデル
OLLAMA_DEFAULT_MODEL=llama3.2

# タイムゾーン
TZ=Asia/Tokyo
```

### Step 3: セットアップスクリプトの実行

```bash
chmod +x setup.sh
./setup.sh
```

スクリプトが以下を自動で行います：

1. Docker のインストール確認（未インストール時はガイド表示）
2. `.env` ファイルの検証と認証トークンの自動生成
3. Docker イメージのビルド（セキュリティ強化版）
4. OpenClaw + Ollama コンテナの起動
5. Ollama のデフォルトモデルの自動ダウンロード
6. ヘルスチェック

### Step 4: 動作確認

```bash
# コンテナの状態確認
docker compose ps

# OpenClaw gateway の確認
curl -s http://127.0.0.1:18789/health

# Ollama の確認
curl -s http://127.0.0.1:11434/api/tags

# 診断コマンド
./setup.sh --doctor
```

---

## Docker 環境のパスについて

Dockerfile や entrypoint.sh に記載されているパス（`/home/openclaw/.openclaw` など）は **Docker コンテナ内部のパス**です。コンテナの内部は常に Linux であるため、macOS や Windows から利用しても問題ありません。

```
macOS ホスト     → Docker Desktop → Linux コンテナ → /home/openclaw/.openclaw ✓
Windows ホスト   → Docker Desktop → Linux コンテナ → /home/openclaw/.openclaw ✓
Linux ホスト     → Docker Engine  → Linux コンテナ → /home/openclaw/.openclaw ✓
```

Docker ボリューム（`openclaw-data`, `ollama-models`）はホスト OS のファイルシステムを Docker が自動管理するため、ユーザーがホスト側のパスを意識する必要はありません。

> 詳しくは [アーキテクチャドキュメント](architecture.md#cross-platform-path-strategy--クロスプラットフォームのパス戦略) を参照してください。

---

## ネイティブセットアップ

Docker を使わずにホストマシンに直接インストールする場合：

```bash
./setup.sh --native
```

このモードでは以下が行われます：

1. Node.js v22 のインストール（fnm 経由 / NodeSource 経由）
2. OpenClaw の公式インストーラー実行
3. Ollama のインストール + デフォルトモデルのダウンロード
4. `~/.openclaw/` にセキュリティ強化設定を配置
5. ファイル権限の設定（700/600）
6. 認証トークンの自動生成

### ネイティブモードのデータパス

ネイティブモードでは `$HOME/.openclaw/` にデータが保存されます。`$HOME` は各 OS で適切に展開されます：

| OS | `$HOME` の展開先 | データパス |
|----|-----------------|-----------|
| macOS | `/Users/<username>` | `/Users/<username>/.openclaw/` |
| Ubuntu/Debian | `/home/<username>` | `/home/<username>/.openclaw/` |
| Windows (WSL2) | `/home/<username>` | `/home/<username>/.openclaw/`（WSL2 内） |

### Ollama なしでインストール

```bash
./setup.sh --native --without-ollama
```

---

## Windows セットアップ

Windows では WSL2 経由で OpenClaw を実行します。ClawX はネイティブ Windows で動作します。

### 前提条件

- Windows 10 バージョン 2004 以降 または Windows 11
- 管理者権限

### 手順

```powershell
# PowerShell を管理者として開く
.\setup.ps1
```

スクリプトが以下を自動で行います：

1. WSL2 の有効化（未設定の場合）
2. Ubuntu WSL2 ディストリビューションのインストール
3. WSL2 内に Node.js と OpenClaw をインストール
4. セキュリティ設定の適用

### オプション

```powershell
.\setup.ps1 -WithClawX      # ClawX デスクトップアプリも追加
.\setup.ps1 -WithOllama      # Ollama もインストール
.\setup.ps1 -WithDocker      # Docker Desktop もインストール
.\setup.ps1 -Doctor          # 診断チェック
.\setup.ps1 -ConfigFile .\my-config.env  # カスタム設定ファイル
```

---

## ClawX のインストール

ClawX は OpenClaw のデスクトップ GUI です。コマンドライン操作なしで AI エージェントを管理できます。

### セットアップスクリプトで一括インストール

```bash
# macOS / Linux
./setup.sh --with-clawx

# Windows
.\setup.ps1 -WithClawX
```

### 手動インストール

[ClawX Releases](https://github.com/ValueCell-ai/ClawX/releases) からダウンロード：

| OS | ファイル |
|---|---|
| macOS (Apple Silicon) | `ClawX-*-mac-arm64.dmg` |
| macOS (Intel) | `ClawX-*-mac-x64.dmg` |
| Windows | `ClawX-*-win-x64.exe` |
| Linux (x64) | `ClawX-*-linux-x86_64.AppImage` |

### macOS の初回起動

macOS では「開発元を確認できないため開けません」という警告が表示される場合があります：

```
システム設定 → プライバシーとセキュリティ → 「このまま開く」をクリック
```

### Linux AppImage の権限設定

```bash
chmod +x ClawX-*.AppImage

# Ubuntu 22.04
sudo apt install libfuse2

# Ubuntu 24.04
sudo apt install libfuse2t64
```

### ClawX 初期設定ウィザード

初回起動時にウィザードが表示されます：

1. **言語/地域の選択** — 日本語を選択
2. **AIプロバイダーの認証** — APIキーを入力（OpenClaw の設定が引き継がれます）
3. **スキルバンドルの選択** — 必要なスキルを選択
4. **接続確認** — 設定のテスト

---

## 初期設定ウィザード

setup.sh 実行後、OpenClaw 自体の初期設定が必要な場合があります。

### OpenClaw ダッシュボード

```bash
# ネイティブの場合
openclaw dashboard

# Docker の場合
# ブラウザで http://127.0.0.1:18789 にアクセス
```

### メッセージングプラットフォームの接続

OpenClaw は以下のプラットフォームと連携できます：

- WhatsApp
- Telegram
- Slack
- Discord
- Microsoft Teams
- LINE
- WeChat

各プラットフォームの接続方法は OpenClaw 公式ドキュメントを参照してください：
https://openclaw.ai/docs

---

## config.env リファレンス

`config.env` はセットアップスクリプトの動作を制御する設定ファイルです。

| キー | デフォルト値 | 説明 |
|------|-------------|------|
| `NODE_MAJOR_VERSION` | `22` | Node.js のメジャーバージョン |
| `OPENCLAW_INSTALL_METHOD` | `script` | インストール方法: `script`, `npm`, `docker` |
| `OPENCLAW_VERSION` | (空=最新) | 固定バージョン |
| `OPENCLAW_GATEWAY_BIND` | `loopback` | バインドアドレス |
| `OPENCLAW_GATEWAY_PORT` | `18789` | ゲートウェイポート |
| `OPENCLAW_AUTH_MODE` | `token` | 認証モード: `token`, `none` |
| `OPENCLAW_AUTH_TOKEN` | (自動生成) | 認証トークン |
| `OPENCLAW_DM_POLICY` | `pairing` | DM ポリシー: `pairing`, `open` |
| `OPENCLAW_REQUIRE_MENTION` | `true` | グループで @mention を必須にする |
| `OPENCLAW_DENY_TOOLS` | `exec,browser,cron` | 拒否するツール（カンマ区切り） |
| `AI_PROVIDER` | (空) | プロバイダー: `anthropic`, `openai`, `ollama` |
| `INSTALL_CLAWX` | `false` | ClawX をインストールするか |
| `VERBOSE` | `false` | 詳細ログを出力 |

---

## AIプロバイダーの設定

### Anthropic Claude

1. [Anthropic Console](https://console.anthropic.com/) でAPIキーを取得
2. `echo "sk-ant-api03-xxxxx" > secrets/ANTHROPIC_API_KEY`

### OpenAI

1. [OpenAI Platform](https://platform.openai.com/) でAPIキーを取得
2. `echo "sk-xxxxx" > secrets/OPENAI_API_KEY`

### Ollama（ローカルLLM）

APIキーは不要です。Docker の場合は自動で Ollama コンテナが起動します。

追加モデルのダウンロード：

```bash
# Docker の場合
docker compose exec ollama ollama pull gemma2
docker compose exec ollama ollama pull codellama
docker compose exec ollama ollama pull mistral

# ネイティブの場合
ollama pull gemma2
```

### プロキシ環境

企業内プロキシ環境の場合は `.env` に以下を追加：

```env
HTTP_PROXY=http://proxy.example.com:8080
HTTPS_PROXY=http://proxy.example.com:8080
```

---

## アップデート手順

### Docker 環境

```bash
# 最新イメージを取得して再起動
docker compose pull
docker compose up -d --build

# Ollama モデルを最新版に更新
docker compose exec ollama ollama pull llama3.2
```

### ネイティブ環境

```bash
# OpenClaw の更新
npm update -g openclaw

# Ollama の更新
# macOS
brew upgrade ollama

# Linux
curl -fsSL https://ollama.com/install.sh | sh
```

### ClawX の更新

ClawX にはアプリ内の自動アップデート機能があります。
手動で更新する場合は [Releases ページ](https://github.com/ValueCell-ai/ClawX/releases) から最新版をダウンロードしてください。

---

次のステップ → [セキュリティ設計](security_ja.md) | [Docker 運用ガイド](docker-guide_ja.md)
