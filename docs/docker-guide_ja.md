# Docker 運用ガイド

[English version](docker-guide_en.md) | [← トップに戻る](../README.md)

---

## 目次

1. [コンテナ構成](#コンテナ構成)
2. [基本操作](#基本操作)
3. [Ollama モデル管理](#ollama-モデル管理)
4. [ログとモニタリング](#ログとモニタリング)
5. [バックアップとリストア](#バックアップとリストア)
6. [GPU サポート](#gpu-サポート)
7. [スケーリングとチューニング](#スケーリングとチューニング)
8. [ネットワーク構成](#ネットワーク構成)

---

## コンテナ構成

### サービス一覧

| サービス | イメージ | ポート | 役割 |
|---------|---------|-------|------|
| `openclaw` | カスタムビルド | 127.0.0.1:18789 | AI エージェント Gateway |
| `ollama` | ollama/ollama:latest | 127.0.0.1:11434 | ローカル LLM 推論 |
| `ollama-init` | curlimages/curl | なし | モデル自動ダウンロード (初回のみ) |

### ボリューム

| ボリューム | コンテナ内パス | 内容 |
|-----------|--------------|------|
| `openclaw-data` | `/home/openclaw/.openclaw` | 設定、セッション、チャンネルデータ |
| `ollama-models` | `/root/.ollama` | ダウンロード済みLLMモデル |

> **パスについて:** 上記のパスは **Docker コンテナ内部**（Linux）のパスです。コンテナは常に Linux で動作するため、macOS や Windows のホストでもこのパスがそのまま使われます。ホスト側の実際の保存先は Docker が自動管理する名前付きボリュームであり、OS による違いを意識する必要はありません。

| ホスト OS | ボリュームの実体 |
|----------|----------------|
| Linux | `/var/lib/docker/volumes/<name>/_data` |
| macOS | Docker Desktop の Linux VM 内（ユーザーから透過的） |
| Windows | WSL2 の Linux ファイルシステム内（ユーザーから透過的） |

---

## 基本操作

### 起動・停止

```bash
# 起動（バックグラウンド）
docker compose up -d

# 停止
docker compose down

# 再起動
docker compose restart

# 特定サービスの再起動
docker compose restart openclaw
docker compose restart ollama
```

### 状態確認

```bash
# コンテナの状態
docker compose ps

# ヘルスチェック状態
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

# リソース使用量
docker stats openclaw ollama
```

### 設定変更後の反映

```bash
# .env や secrets/ を変更した場合
docker compose up -d    # 変更が検出されたコンテナだけ再作成

# docker-compose.yml を変更した場合
docker compose up -d --force-recreate

# Dockerfile を変更した場合
docker compose up -d --build
```

---

## Ollama モデル管理

### モデルのダウンロード

```bash
# 基本コマンド
docker compose exec ollama ollama pull <model-name>

# 人気モデル
docker compose exec ollama ollama pull llama3.2        # 2B, 軽量
docker compose exec ollama ollama pull llama3.2:7b     # 7B, バランス
docker compose exec ollama ollama pull gemma2          # 9B, Google製
docker compose exec ollama ollama pull codellama       # 7B, コード特化
docker compose exec ollama ollama pull mistral         # 7B, 高速
docker compose exec ollama ollama pull phi3            # 3.8B, Microsoft製
docker compose exec ollama ollama pull llava           # 7B, 画像理解
```

### モデルの確認

```bash
# インストール済みモデル一覧
docker compose exec ollama ollama list

# API 経由で確認
curl -s http://127.0.0.1:11434/api/tags | python3 -m json.tool
```

### モデルのテスト

```bash
# インタラクティブチャット
docker compose exec -it ollama ollama run llama3.2

# API 経由でテスト
curl -s http://127.0.0.1:11434/api/generate \
  -d '{"model": "llama3.2", "prompt": "Hello!", "stream": false}' | python3 -m json.tool
```

### モデルの削除

```bash
# 特定モデルの削除
docker compose exec ollama ollama rm <model-name>

# 全モデルの削除（ボリュームごと削除）
docker compose down
docker volume rm openclaw-easy-setup_ollama-models
```

### モデルサイズの目安

| モデル | ダウンロードサイズ | ディスク使用量 |
|-------|------------------|--------------|
| llama3.2 (2B) | ~1.3 GB | ~1.3 GB |
| llama3.2:7b | ~4.7 GB | ~4.7 GB |
| gemma2 | ~5.4 GB | ~5.4 GB |
| codellama | ~3.8 GB | ~3.8 GB |
| mistral | ~4.1 GB | ~4.1 GB |

---

## ログとモニタリング

### ログの確認

```bash
# 全サービスのログ（リアルタイム）
docker compose logs -f

# 特定サービスのログ
docker compose logs -f openclaw
docker compose logs -f ollama

# 直近100行のログ
docker compose logs --tail 100 openclaw

# タイムスタンプ付き
docker compose logs -f --timestamps openclaw
```

### ログのエクスポート

```bash
# ファイルに保存
docker compose logs openclaw > openclaw.log 2>&1
docker compose logs ollama > ollama.log 2>&1
```

### ヘルスチェック

```bash
# OpenClaw Gateway
curl -sf http://127.0.0.1:18789/health && echo "OK" || echo "FAIL"

# Ollama
curl -sf http://127.0.0.1:11434/api/tags && echo "OK" || echo "FAIL"

# 診断コマンド
./setup.sh --doctor
```

### リソースモニタリング

```bash
# リアルタイムリソース使用量
docker stats openclaw ollama

# ディスク使用量
docker system df
docker volume ls

# Ollama モデルの合計サイズ
docker compose exec ollama du -sh /root/.ollama/models/
```

---

## バックアップとリストア

### 設定のバックアップ

```bash
# .env、secrets/、docker-compose.yml のバックアップ
cp .env .env.backup.$(date +%Y%m%d)
cp -r secrets/ secrets.backup.$(date +%Y%m%d)/
cp docker-compose.yml docker-compose.yml.backup.$(date +%Y%m%d)
```

### OpenClaw データのバックアップ

```bash
# ボリュームの内容をバックアップ
docker run --rm \
  -v openclaw-easy-setup_openclaw-data:/data \
  -v $(pwd)/backup:/backup \
  alpine tar czf /backup/openclaw-data-$(date +%Y%m%d).tar.gz -C /data .
```

### リストア

```bash
# ボリュームにリストア
docker run --rm \
  -v openclaw-easy-setup_openclaw-data:/data \
  -v $(pwd)/backup:/backup \
  alpine sh -c "rm -rf /data/* && tar xzf /backup/openclaw-data-YYYYMMDD.tar.gz -C /data"
```

### Ollama モデルのバックアップ

モデルはサイズが大きいため、バックアップよりも再ダウンロードを推奨します：

```bash
# インストール済みモデルのリストを保存
docker compose exec ollama ollama list > ollama-models-list.txt

# リストアは各モデルを再 pull
while read model _; do
  docker compose exec ollama ollama pull "$model"
done < ollama-models-list.txt
```

---

## GPU サポート

### NVIDIA GPU

#### 前提条件

```bash
# NVIDIA ドライバーの確認
nvidia-smi

# NVIDIA Container Toolkit のインストール (Ubuntu/Debian)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker
```

#### docker-compose.yml の変更

`ollama` サービスのコメントを解除：

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

再起動：
```bash
docker compose up -d
```

確認：
```bash
docker compose exec ollama nvidia-smi
```

### Apple Silicon (M1/M2/M3/M4)

Docker Desktop for Mac は現在 GPU パススルーをサポートしていません。
Apple Silicon で GPU を活用するには、Ollama をネイティブにインストールしてください：

```bash
brew install ollama
ollama serve
```

---

## スケーリングとチューニング

### Ollama のパフォーマンスチューニング

`.env` で以下を調整：

```env
# 並列リクエスト数
OLLAMA_NUM_PARALLEL=2

# メモリに保持するモデル数
OLLAMA_MAX_LOADED_MODELS=2
```

### OpenClaw のリソース調整

`docker-compose.yml` のリソース制限を環境に合わせて変更：

```yaml
openclaw:
  deploy:
    resources:
      limits:
        memory: 4G     # デフォルト: 2G
        cpus: "4.0"    # デフォルト: 2.0

ollama:
  deploy:
    resources:
      limits:
        memory: 16G    # 大きなモデル用
        cpus: "8.0"
```

### ヘルスチェックの調整

起動が遅い環境では `start_period` を延長：

```yaml
healthcheck:
  start_period: 120s  # デフォルト: 30s (openclaw) / 60s (ollama)
```

---

## ネットワーク構成

### デフォルト構成

```
Host (127.0.0.1)
├── :18789 → openclaw container
└── :11434 → ollama container

openclaw-net (172.28.0.0/16)
├── openclaw → ollama:11434 (internal)
└── ollama
```

### リバースプロキシ構成（外部公開時）

> セキュリティ上、必ず TLS を使用してください。

nginx の設定例：

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
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

---

次のステップ → [トラブルシューティング](troubleshooting_ja.md) | [セキュリティ設計](security_ja.md)
