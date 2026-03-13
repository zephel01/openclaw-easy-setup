# プロバイダー・環境変数リファレンス

[English version](providers_en.md) | [← トップに戻る](../README.md)

---

## 目次

1. [AI / LLM プロバイダー](#ai--llm-プロバイダー)
2. [メッセージングプラットフォーム](#メッセージングプラットフォーム)
3. [Web 検索プロバイダー](#web-検索プロバイダー)
4. [ブラウザ自動化・メディア](#ブラウザ自動化メディア)
5. [OpenClaw システム変数](#openclaw-システム変数)
6. [.env の設定例](#env-の設定例)

---

## AI / LLM プロバイダー

### 主要プロバイダー

| プロバイダー | 環境変数 | アダプター | 備考 |
|---|---|---|---|
| **Anthropic Claude** | `ANTHROPIC_API_KEY` | `anthropic-messages` | Claude 3.5 / Opus / Sonnet / Haiku |
| **OpenAI** | `OPENAI_API_KEY` | `openai-completions` | GPT-4o, GPT-4, o1 等 |
| **Google Gemini** | `GOOGLE_API_KEY` or `GEMINI_API_KEY` | `google-generative-ai` | Gemini Pro / Flash / Ultra |
| **Groq** | `GROQ_API_KEY` | ネイティブ | 超高速推論 |
| **MiniMax** | `MINIMAX_API_KEY` | `anthropic-messages` | ベースURL: `https://api.minimax.io/anthropic` |

### アジア圏プロバイダー

| プロバイダー | 環境変数 | アダプター | ベースURL |
|---|---|---|---|
| **Moonshot (Kimi)** | `MOONSHOT_API_KEY` or `KIMI_API_KEY` | `openai-completions` | `https://api.moonshot.ai/v1` |
| **Qwen (通义千问)** | `QWEN_API_KEY` | ネイティブ | Alibaba Cloud |
| **Qianfan (千帆)** | `QIANFAN_API_KEY` | ネイティブ | Baidu |
| **GLM (智谱)** | `GLM_API_KEY` | ネイティブ | Zhipu AI |
| **Z.AI** | `ZAI_API_KEY` | `openai-completions` | `https://api.z.ai/api/coding/paas/v4` |
| **Xiaomi MiMo** | `MIMO_API_KEY` | ネイティブ | Xiaomi |

### ゲートウェイ・集約プロバイダー

| プロバイダー | 環境変数 | 説明 |
|---|---|---|
| **OpenRouter** | `OPENROUTER_API_KEY` | 100+ モデルのゲートウェイ。Llama, Mistral, Claude 等 |
| **Together** | `TOGETHER_API_KEY` | オープンソースモデルのホスティング |
| **Hugging Face** | `HUGGINGFACE_API_KEY` | オープンソースモデルの推論 API |
| **Cerebras** | `CEREBRAS_API_KEY` | 高速推論（ベースURL: `https://api.cerebras.ai/v1`） |

### 特殊プロバイダー

| プロバイダー | 環境変数 | 説明 |
|---|---|---|
| **Synthetic** | `SYNTHETIC_API_KEY` | `anthropic-messages` アダプター。URL: `https://api.synthetic.new/anthropic` |
| **Venice AI** | `VENICE_API_KEY` | プライバシー重視の推論 |
| **Perplexity Sonar** | `PERPLEXITY_API_KEY` | 検索統合型 AI |
| **OpenCode Zen** | `OPENCODE_API_KEY` | コーディング特化 |

### クラウド・セルフホスト

| プロバイダー | 環境変数 | 備考 |
|---|---|---|
| **Amazon Bedrock** | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` | AWS 認証情報を使用 |
| **Ollama** | 不要 | ローカル実行。`baseUrl: http://localhost:11434` |
| **vLLM** | 不要 | セルフホスト。エンドポイント URL を設定 |
| **LM Studio** | 不要 | ローカル実行。`openai-responses` アダプター |

---

## メッセージングプラットフォーム

### 環境変数で設定可能

| プラットフォーム | 環境変数 | 備考 |
|---|---|---|
| **Slack** | `SLACK_BOT_TOKEN` (`xoxb-...`), `SLACK_APP_TOKEN` (`xapp-...`) | Bot Token + App-Level Token |
| **Discord** | `DISCORD_BOT_TOKEN` | Bot Token |
| **Telegram** | `TELEGRAM_BOT_TOKEN` | BotFather から取得 |
| **LINE** | `LINE_CHANNEL_ACCESS_TOKEN`, `LINE_CHANNEL_SECRET` | LINE Developers Console |
| **Matrix** | `MATRIX_HOMESERVER`, `MATRIX_ACCESS_TOKEN`, `MATRIX_USER_ID`, `MATRIX_PASSWORD` | Homeserver URL + 認証 |
| **Mattermost** | `MATTERMOST_BOT_TOKEN`, `MATTERMOST_URL` | Bot Token + サーバー URL |
| **Feishu (飞书)** | `FEISHU_APP_ID`, `FEISHU_APP_SECRET` | App ID + Secret |
| **Twitch** | `OPENCLAW_TWITCH_ACCESS_TOKEN` | OAuth Token (`oauth:` prefix) |
| **Zalo** | `ZALO_BOT_TOKEN` | Bot Token |
| **Nostr** | `NOSTR_PRIVATE_KEY` | nsec / hex 形式 |
| **IRC** | `IRC_HOST`, `IRC_PORT`, `IRC_TLS`, `IRC_NICK`, `IRC_PASSWORD`, `IRC_CHANNELS` | 複数変数で設定 |

### 設定ファイル (openclaw.json) で設定

以下のプラットフォームは環境変数ではなく、`~/.openclaw/openclaw.json` で設定します：

| プラットフォーム | 認証方式 | 備考 |
|---|---|---|
| **WhatsApp** | QR コードスキャン + CLI | `~/.openclaw/credentials/whatsapp/` に保存 |
| **Signal** | `signal-cli` 経由 | Gateway ホストに signal-cli が必要 |
| **iMessage** | `imsg` CLI | macOS のみ |
| **Google Chat** | OAuth | Google Workspace 連携 |
| **Microsoft Teams** | OAuth | Azure AD 連携 |
| **BlueBubbles** | `serverUrl`, `password` | 設定ファイルのみ |
| **Nextcloud Talk** | URL + 認証情報 | 設定ファイルのみ |
| **Synology Chat** | Token ベース | 設定ファイルのみ |

---

## Web 検索プロバイダー

OpenClaw のエージェントが Web 検索を行う際に使用するプロバイダーです。
環境変数が設定されていると自動的に検出・有効化されます。

| プロバイダー | 環境変数 | 備考 |
|---|---|---|
| **Brave Search** | `BRAVE_API_KEY` | 自動検出。プライバシー重視 |
| **Perplexity** | `PERPLEXITY_API_KEY` | 自動検出。AI 搭載検索 |
| **Google Gemini** | `GEMINI_API_KEY` | LLM キーと兼用可 |
| **Grok (X.AI)** | `XAI_API_KEY` | X/Twitter 統合 |
| **Kimi** | `KIMI_API_KEY` or `MOONSHOT_API_KEY` | 代替検索プロバイダー |

---

## ブラウザ自動化・メディア

### ブラウザ自動化

| サービス | 環境変数 | 備考 |
|---|---|---|
| **Browserless** | `BROWSERLESS_API_KEY` | CDP URL パラメータ経由 |
| **Browserbase** | `BROWSERBASE_API_KEY` | WSS 接続 |

### Web コンテンツ抽出

| サービス | 環境変数 | 備考 |
|---|---|---|
| **Firecrawl** | `FIRECRAWL_API_KEY` | 複雑なサイト用フォールバック |
| **Readability** | 不要 | ビルトイン（プライマリ） |

### 音声・メディア

| サービス | 環境変数 | 備考 |
|---|---|---|
| **ElevenLabs TTS** | `ELEVENLABS_API_KEY` or `XI_API_KEY` | テキスト読み上げ |
| **Deepgram** | `DEEPGRAM_API_KEY` | 音声認識 |

---

## OpenClaw システム変数

### Gateway 設定

| 変数 | 説明 | デフォルト |
|---|---|---|
| `OPENCLAW_GATEWAY_TOKEN` | Gateway 認証トークン | 自動生成 |
| `OPENCLAW_GATEWAY_PASSWORD` | Gateway HTTP Basic 認証パスワード | なし |
| `OPENCLAW_HOME` | ホームディレクトリのオーバーライド | `~/.openclaw` |
| `OPENCLAW_STATE_DIR` | 可変状態の保存先 | `$OPENCLAW_HOME` |
| `OPENCLAW_CONFIG_PATH` | 設定ファイルのパス | `$OPENCLAW_HOME/openclaw.json` |

### Telegram ネットワーク設定（オプション）

| 変数 | 説明 |
|---|---|
| `OPENCLAW_TELEGRAM_DISABLE_AUTO_SELECT_FAMILY` | ネットワークファミリー自動選択を無効化 (`1`) |
| `OPENCLAW_TELEGRAM_ENABLE_AUTO_SELECT_FAMILY` | ネットワークファミリー自動選択を有効化 (`1`) |
| `OPENCLAW_TELEGRAM_DNS_RESULT_ORDER` | DNS 順序（例: `ipv4first`） |

---

## .env の設定例

### 最小構成（Ollama のみ）

```env
# APIキー不要 — Ollamaがローカルで動作
OLLAMA_DEFAULT_MODEL=llama3.2
OPENCLAW_AUTH_MODE=token
TZ=Asia/Tokyo
```

### Anthropic + Ollama

```bash
# secrets/ に API キーを配置
echo "sk-ant-api03-xxxxxxxxxxxxx" > secrets/ANTHROPIC_API_KEY
```

```env
# .env
OLLAMA_DEFAULT_MODEL=llama3.2
OPENCLAW_AUTH_MODE=token
TZ=Asia/Tokyo
```

### マルチプロバイダー構成

```bash
# secrets/ に API キーを配置
echo "sk-ant-api03-xxxxxxxxxxxxx" > secrets/ANTHROPIC_API_KEY
echo "sk-xxxxxxxxxxxxx"          > secrets/OPENAI_API_KEY
echo "AIzaSy-xxxxxxxxxxxxx"      > secrets/GEMINI_API_KEY
echo "gsk_xxxxxxxxxxxxx"         > secrets/GROQ_API_KEY
echo "123456:ABCdef-xxxxxxxxxxxxx" > secrets/TELEGRAM_BOT_TOKEN
echo "xoxb-xxxxxxxxxxxxx"        > secrets/SLACK_BOT_TOKEN
echo "xapp-xxxxxxxxxxxxx"        > secrets/SLACK_APP_TOKEN
echo "xxxxxxxxxxxxx"             > secrets/DISCORD_BOT_TOKEN
echo "BSA-xxxxxxxxxxxxx"         > secrets/BRAVE_API_KEY
```

```env
# .env — 秘密情報以外の設定のみ
# --- Security ---
OPENCLAW_AUTH_MODE=token
OPENCLAW_AUTH_TOKEN=
OPENCLAW_DENY_TOOLS=exec,browser,cron

# --- Ollama ---
OLLAMA_DEFAULT_MODEL=llama3.2
OLLAMA_NUM_PARALLEL=2

TZ=Asia/Tokyo
```

### 企業環境（プロキシ + Bedrock）

```bash
# secrets/ に AWS 認証情報を配置
echo "AKIA-xxxxxxxxxxxxx" > secrets/AWS_ACCESS_KEY_ID
echo "xxxxxxxxxxxxx"      > secrets/AWS_SECRET_ACCESS_KEY
```

```env
# .env
# --- AWS Bedrock ---
AWS_REGION=ap-northeast-1

# --- Proxy ---
HTTP_PROXY=http://proxy.corp.example.com:8080
HTTPS_PROXY=http://proxy.corp.example.com:8080
NO_PROXY=localhost,127.0.0.1,ollama

# --- Security ---
OPENCLAW_AUTH_MODE=token
OPENCLAW_DENY_TOOLS=exec,browser,cron

TZ=Asia/Tokyo
```

---

## Docker 環境での .env の仕組み

`docker-compose.yml` の `env_file: .env` により、`.env` に記載された変数がコンテナに渡されます。また、`secrets/` ディレクトリに配置した API キーは `entrypoint.sh` が起動時に環境変数として読み込みます。

```
secrets/ のファイル（API キー推奨）
  ↓ entrypoint.sh が起動時に export
.env のすべての変数
  ↓ env_file で自動パススルー
OpenClaw コンテナ
  ↑ environment: で一部だけ上書き
  │  OPENCLAW_GATEWAY_BIND (Docker内部用に 0.0.0.0)
  │  OLLAMA_BASE_URL (Docker内部DNS: http://ollama:11434)
```

> **注意**: `secrets/` と `.env` に同名の変数がある場合、`secrets/` が優先されます。

Moonshot や Cerebras などの `*_BASE_URL` 変数は `.env` に書けば、**そのままコンテナ内の OpenClaw に渡ります**。API キーは `secrets/` ディレクトリに配置することを推奨します。

### 唯一の例外: OLLAMA_BASE_URL

`OLLAMA_BASE_URL` だけは `docker-compose.yml` で `http://ollama:11434`（Docker 内部ネットワーク）に強制上書きされます。Docker 環境では Ollama コンテナに内部 DNS でアクセスするためです。ネイティブインストールの場合はこの制約はありません。

### Base URL が必須のプロバイダー

以下のプロバイダーは API キーだけでなく Base URL の設定も必要です。
**両方を設定しないとプロバイダーが動作しません。** 片方だけの場合、コンテナ起動時に WARNING が表示されます。

| プロバイダー | API キー変数 | Base URL 変数 | 値 |
|---|---|---|---|
| MiniMax | `MINIMAX_API_KEY` | `MINIMAX_BASE_URL` | `https://api.minimax.io/anthropic` |
| Moonshot / Kimi | `MOONSHOT_API_KEY` | `MOONSHOT_BASE_URL` | `https://api.moonshot.ai/v1` |
| Z.AI | `ZAI_API_KEY` | `ZAI_BASE_URL` | `https://api.z.ai/api/coding/paas/v4` |
| Cerebras | `CEREBRAS_API_KEY` | `CEREBRAS_BASE_URL` | `https://api.cerebras.ai/v1` |
| Synthetic | `SYNTHETIC_API_KEY` | `SYNTHETIC_BASE_URL` | `https://api.synthetic.new/anthropic` |
| GLM / Zhipu | `GLM_API_KEY` | `GLM_BASE_URL` | `https://open.bigmodel.cn/api/paas/v4` |
| Qwen | `QWEN_API_KEY` | `QWEN_BASE_URL` | `https://dashscope.aliyuncs.com/compatible-mode/v1` |
| Together | `TOGETHER_API_KEY` | `TOGETHER_BASE_URL` | `https://api.together.xyz/v1` |

#### 設定方法（secrets/ + .env の分け方）

API キーは秘密情報なので `secrets/` に、Base URL は公開情報なので `.env` に配置します。

```bash
# 例: Z.AI を使う場合

# 1. API キー → secrets/ に配置
echo "your-zai-api-key" > secrets/ZAI_API_KEY

# 2. Base URL → .env に追記（またはコメント解除）
# .env に以下を追加:
ZAI_BASE_URL=https://api.z.ai/api/coding/paas/v4
```

> `.env.example` にすべてのプロバイダーの Base URL がコメント付きで記載されています。コメントを外すだけで使えます。

> **起動時チェック**: `entrypoint.sh` が API キーと Base URL のペアを検証し、片方だけの場合は WARNING を出力します。

---

## 設定の優先順位

OpenClaw は以下の順序で環境変数を読み込みます（上が優先）：

1. `secrets/` ディレクトリのファイル（`entrypoint.sh` が起動時に export）
2. `docker-compose.yml` の `environment:` セクション（Docker 固有の上書き）
3. `.env` ファイル（`env_file:` 経由）
4. プロセスの環境変数
5. 設定ファイル (`openclaw.json`) のブロック

設定ファイル内でテンプレート構文 `"${VARIABLE_NAME}"` を使って `.env` の値を参照できます。

---

## 注意事項

- **マルチアカウント**: 環境変数はデフォルトアカウントにのみ適用されます。複数アカウントの設定には `~/.openclaw/openclaw.json` を使用してください。
- **認証プロファイル**: APIキーと OAuth トークンの両方をサポートし、フォールバックとローテーション機能があります。認証プロファイルは `~/.openclaw/agents/<agentId>/agent/auth-profiles.json` に保存されます。
- **公式ドキュメント**: 最新のプロバイダー情報は https://docs.openclaw.ai/gateway/configuration-reference を参照してください。

---

[← セットアップガイド](setup-guide_ja.md) | [セキュリティ設計](security_ja.md) | [← トップに戻る](../README.md)
