# トラブルシューティング

[English version](troubleshooting_en.md) | [← トップに戻る](../README.md)

---

## 診断コマンド

まず最初に診断を実行してください：

```bash
./setup.sh --doctor
```

これにより Docker、OpenClaw、Ollama、ポート、ファイル権限の状態を一括チェックできます。

---

## セットアップ時の問題

### setup.sh の権限エラー

```
bash: ./setup.sh: Permission denied
```

**解決策:**
```bash
chmod +x setup.sh
./setup.sh
```

### Docker が見つからない

```
[✗] Docker not found. Installing...
```

**macOS:**
```bash
# Homebrew でインストール
brew install --cask docker
# Docker Desktop を起動
open -a Docker
# 起動後に再実行
./setup.sh
```

**Ubuntu/Debian:**
```bash
# 手動インストール
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# ログアウト → ログイン後に再実行
```

### Docker Compose が見つからない

```
docker: 'compose' is not a docker command.
```

**解決策:**
Docker Compose V2 が必要です。Docker Desktop を最新版に更新するか：

```bash
# プラグインとして追加インストール (Linux)
sudo apt-get install docker-compose-plugin
```

---

## Docker コンテナの問題

### コンテナが起動しない

```bash
# 状態確認
docker compose ps

# ログで原因を確認
docker compose logs openclaw
docker compose logs ollama
```

**よくある原因:**

| 症状 | 原因 | 解決策 |
|------|------|--------|
| `Exited (1)` | 設定エラー | `docker compose logs` でエラー詳細を確認 |
| `Exited (137)` | メモリ不足 (OOM) | `docker-compose.yml` のメモリ制限を引き上げ |
| `Exited (126)` | 権限エラー | Dockerfile の USER 設定を確認 |

### ポートが使用中

```
Error: Bind for 127.0.0.1:18789 failed: port is already allocated
```

**解決策:**
```bash
# 使用中のプロセスを確認
lsof -i :18789
# macOS
lsof -i :11434

# Linux
ss -tlnp | grep -E "18789|11434"

# 別ポートに変更する場合は .env を編集
# docker-compose.yml のポートマッピングも変更
```

### コンテナのヘルスチェックが失敗する

```bash
# ヘルスチェックの詳細を確認
docker inspect --format='{{json .State.Health}}' openclaw | python3 -m json.tool
```

**OpenClaw:**
- `secrets/` ディレクトリの API キーファイルを確認（または `.env` の設定）
- ネットワーク接続を確認（プロキシ環境の場合）

**Ollama:**
- メモリが十分か確認: `docker stats ollama`
- 起動に時間がかかる場合は `start_period` を延長

### ビルドが失敗する

```bash
# キャッシュなしでリビルド
docker compose build --no-cache

# Docker のディスク使用量を確認
docker system df

# 不要なイメージを削除
docker system prune -f
```

---

## Ollama の問題

### モデルがダウンロードできない

```bash
# コンテナからネットワーク接続を確認
docker compose exec ollama curl -sf https://ollama.com && echo "OK" || echo "FAIL"
```

**プロキシ環境の場合:**

`docker-compose.yml` の ollama サービスに環境変数を追加：

```yaml
ollama:
  environment:
    - HTTP_PROXY=http://proxy.example.com:8080
    - HTTPS_PROXY=http://proxy.example.com:8080
    - NO_PROXY=localhost,127.0.0.1,ollama
```

### モデルの実行が遅い

| 確認項目 | コマンド |
|---------|---------|
| メモリ使用量 | `docker stats ollama` |
| GPU 利用状況 | `docker compose exec ollama nvidia-smi` |
| モデルサイズ | `docker compose exec ollama ollama list` |

**改善策:**
- より小さいモデルを使用（llama3.2 2B など）
- GPU を有効化（[GPU サポート](docker-guide_ja.md#gpu-サポート)参照）
- `OLLAMA_NUM_PARALLEL` を `1` に下げる
- `OLLAMA_MAX_LOADED_MODELS` を `1` に下げる

### Ollama がモデルを認識しない

```bash
# モデルの再ダウンロード
docker compose exec ollama ollama pull llama3.2

# Ollama を再起動
docker compose restart ollama
```

---

## ネットワークの問題

### OpenClaw から Ollama に接続できない

```bash
# コンテナ間の接続を確認
docker compose exec openclaw curl -sf http://ollama:11434/api/tags && echo "OK"
```

**解決策:**
- 両方のコンテナが同じネットワーク (`openclaw-net`) にあることを確認
- `docker compose down && docker compose up -d` で再起動

### ホストから Gateway にアクセスできない

```bash
# ポートが開いているか確認
curl -sf http://127.0.0.1:18789/health

# Docker のポートマッピングを確認
docker compose ps --format "table {{.Name}}\t{{.Ports}}"
```

---

## ClawX の問題

### macOS で開けない

「開発元を確認できないため開けません」というエラー：

```
システム設定 → プライバシーとセキュリティ → 「このまま開く」をクリック
```

または：
```bash
xattr -cr /Applications/ClawX.app
```

### Linux AppImage が起動しない

```bash
# 実行権限を付与
chmod +x ClawX.AppImage

# libfuse が必要
# Ubuntu 22.04
sudo apt install libfuse2

# Ubuntu 24.04
sudo apt install libfuse2t64

# GTK 関連の依存関係
sudo apt install libgtk-3-0t64 libnotify4t64 libxss1t64
```

### ClawX が OpenClaw に接続できない

- OpenClaw Gateway が起動していることを確認：`docker compose ps`
- ポート 18789 でリッスンしていることを確認
- ClawX の設定でゲートウェイ URL が `http://127.0.0.1:18789` になっていることを確認

---

## Windows (WSL2) の問題

### WSL2 が有効にならない

管理者権限で PowerShell を実行：
```powershell
wsl --install
# 再起動が必要な場合があります
```

### WSL2 内のネットワーク問題

```powershell
# WSL2 のネットワークをリセット
wsl --shutdown
# 再起動
wsl
```

### WSL2 のメモリ使用量

WSL2 はデフォルトでホストメモリの50%を使用します。制限するには `%USERPROFILE%\.wslconfig` を作成：

```ini
[wsl2]
memory=4GB
processors=2
```

---

## ログの読み方

### OpenClaw のログパターン

| パターン | 意味 |
|---------|------|
| `Gateway started on :18789` | 正常起動 |
| `Auth token verified` | 認証成功 |
| `Connection refused` | 外部サービスに接続できない |
| `ENOMEM` / `heap out of memory` | メモリ不足 |
| `EACCES` / `Permission denied` | 権限エラー |

### Ollama のログパターン

| パターン | 意味 |
|---------|------|
| `Listening on :11434` | 正常起動 |
| `loading model` | モデルをメモリに読み込み中 |
| `model loaded` | モデル準備完了 |
| `out of memory` | GPU/RAM 不足 |
| `model not found` | モデルがインストールされていない |

---

## 完全リセット

すべてを初期状態に戻す場合：

```bash
# コンテナとボリュームをすべて削除
docker compose down -v

# Docker イメージも削除
docker compose down -v --rmi all

# キャッシュも含めて完全クリーン
docker system prune -af --volumes

# .env を再作成、secrets/ に API キーを再配置
cp .env.example .env
# echo "your-key" > secrets/ANTHROPIC_API_KEY
./setup.sh
```

---

まだ解決しない場合は `./setup.sh --doctor` の出力を添えて Issue を作成してください。

[← セキュリティ設計](security_ja.md) | [Docker 運用ガイド](docker-guide_ja.md) | [← トップに戻る](../README.md)
