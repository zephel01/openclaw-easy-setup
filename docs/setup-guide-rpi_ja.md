# Raspberry Pi 4B / 5 セットアップガイド

## 前提条件

- Raspberry Pi 4 Model B または Raspberry Pi 5
- Raspberry Pi OS Bookworm（64-bit）
- microSD カード 32GB 以上（SSD 推奨）
- インターネット接続

## ハードウェア要件

### RAM 別の動作状況

OpenClaw は Node.js アプリケーション、Ollama はローカル LLM 推論エンジンです。両方を Docker コンテナで動かすため、RAM がボトルネックになります。

| RAM | OpenClaw 単体 | + Ollama (1B) | + Ollama (3B) | 判定 |
|-----|:------------:|:-------------:|:-------------:|------|
| 1GB | 不可 | 不可 | 不可 | **非対応** |
| 2GB | 起動は可能 | 厳しい | 不可 | **非推奨** — メモリ逼迫で不安定 |
| 4GB | 快適 | 動作する | 厳しい | **最低推奨** — Ollama は 1B モデル限定 |
| 8GB | 快適 | 快適 | 動作する | **推奨** — 3B モデルまで実用的 |

### メモリ配分の内訳

インストーラーは RAM に応じて Docker コンテナのメモリ制限と zram を自動設定します。以下はデフォルトの配分です。

**4GB RAM の場合:**

```
物理 RAM 4096 MB
├── OS + システム予約     ~500 MB  (カーネル, systemd, SSH 等)
├── zram 消費 (実RAM)     ~600 MB  (2GB の zram を ~30% の実RAM で圧縮保持)
├── OpenClaw コンテナ      768 MB  (Node.js + Gateway)
├── Ollama コンテナ       3072 MB  (LLM 推論 — zram 上にスワップアウト可)
└── バッファ               ~150 MB
    ──────────────────
    zram 実効メモリ:     ~6 GB+   (物理 4GB + zram 圧縮 2GB)
```

**8GB RAM の場合:**

```
物理 RAM 8192 MB
├── OS + システム予約     ~600 MB
├── zram 消費 (実RAM)    ~1200 MB  (4GB の zram を ~30% の実RAM で圧縮保持)
├── OpenClaw コンテナ     1536 MB
├── Ollama コンテナ       5120 MB  (Pi 4B) / 6144 MB (Pi 5)
└── バッファ               ~500 MB
    ──────────────────
    zram 実効メモリ:    ~12 GB+   (物理 8GB + zram 圧縮 4GB)
```

### Ollama モデルのメモリ消費

Ollama でモデルをロードすると、モデル全体がメモリ上に展開されます。RPi には GPU メモリ（VRAM）がないため、すべて通常の RAM（+ zram/swap）を使います。

| モデル | パラメータ数 | ロード時メモリ | 4GB で動くか | 8GB で動くか |
|-------|:----------:|:-----------:|:----------:|:----------:|
| llama3.2:1b | 1B | ~1.2 GB | 動く | 快適 |
| llama3.2:3b | 3B | ~2.5 GB | swap 頼み | 動く |
| llama3.1:8b | 8B | ~5.5 GB | 不可 | swap 頼み |
| gemma2:2b | 2B | ~1.8 GB | 動く | 快適 |
| phi3:mini | 3.8B | ~2.8 GB | swap 頼み | 動く |

「swap 頼み」は zram + ディスク swap を使って動作する状態で、応答速度が大幅に低下します（数十秒〜数分/応答）。実用的ではありませんが、テスト目的なら使えます。

### OpenClaw 単体（Ollama なし）で使う場合

Ollama を使わず、外部 API（Anthropic Claude、OpenAI GPT-4o、Groq など）だけで OpenClaw を動かす場合は、必要メモリが大幅に減ります。

```bash
./setup-rpi.sh --without-ollama
```

| RAM | 動作状況 | 備考 |
|-----|---------|------|
| 2GB | 起動する | メモリに余裕がなく不安定になりやすい。`--no-zram` でも可 |
| 4GB | 快適 | 推奨。OpenClaw + メッセージング統合で十分な余裕 |
| 8GB | 快適 | 余裕あり。将来的に Ollama 追加も可能 |

### ストレージ要件

| 用途 | 必要容量 |
|------|---------|
| OS (Raspberry Pi OS) | ~4 GB |
| Docker Engine | ~1 GB |
| OpenClaw Docker イメージ | ~500 MB |
| Ollama Docker イメージ | ~1.5 GB |
| Ollama モデル (1B) | ~1.3 GB |
| Ollama モデル (3B) | ~2.5 GB |
| **合計（1B モデルの場合）** | **~9 GB** |

microSD は 32GB 以上を推奨します。SSD（USB 3.0 接続）を使うと、Docker のビルドやモデルのロードが大幅に速くなります。

### RPi 4B vs 5 のパフォーマンス差

| 項目 | RPi 4B | RPi 5 |
|------|--------|-------|
| CPU | Cortex-A72 1.8GHz | Cortex-A76 2.4GHz |
| Ollama 推論速度 (1B) | ~5 tokens/sec | ~10 tokens/sec |
| Ollama 推論速度 (3B) | ~2 tokens/sec | ~5 tokens/sec |
| Docker ビルド（初回） | 10〜15 分 | 5〜10 分 |
| メモリ帯域 | LPDDR4 ~4 GB/s | LPDDR4X ~8.5 GB/s |

Ollama の推論速度はメモリ帯域に依存するため、Pi 5 は Pi 4B の約2倍の速度が出ます。

## クイックスタート

```bash
git clone https://github.com/zephel01/openclaw-easy-setup.git
cd openclaw-easy-setup

# 1. 設定
cp .env.example .env
# API キーを設定（Ollama のみなら不要）
echo "sk-ant-api03-xxxxx" > secrets/ANTHROPIC_API_KEY

# 2. インストール
chmod +x setup-rpi.sh
./setup-rpi.sh
```

約5〜10分で OpenClaw + Ollama が起動します。

## CLI オプション

```
./setup-rpi.sh [OPTIONS]

  --without-ollama    Ollama をスキップ
  --model MODEL       Ollama モデル指定（デフォルト: llama3.2:1b）
  --swap SIZE_MB      ディスクスワップサイズ（デフォルト: 2048 MB）
  --no-zram           zram を無効化してインストール
  --zram-on           zram を有効化（インストール後に切り替え）
  --zram-off          zram を無効化（インストール後に切り替え）
  --zram-algo ALGO    zram 圧縮アルゴリズム（デフォルト: RAM に応じて自動選択）
                      選択肢: zstd, lz4, lzo, lzo-rle
  --doctor            診断モード
  --uninstall         コンテナ削除
  --config FILE       設定ファイル指定
  -h, --help          ヘルプ表示
```

## RAM とモデルの推奨

| デバイス | RAM | 推奨モデル | コマンド |
|---------|-----|-----------|---------|
| Pi 4B   | 4GB | llama3.2:1b | `./setup-rpi.sh`（デフォルト） |
| Pi 4B   | 8GB | llama3.2:3b | `./setup-rpi.sh --model llama3.2:3b` |
| Pi 5    | 4GB | llama3.2:1b | `./setup-rpi.sh`（デフォルト） |
| Pi 5    | 8GB | llama3.2:3b | `./setup-rpi.sh --model llama3.2:3b` |

## zram（圧縮スワップ）

インストーラーは RAM に応じて zram を自動設定します。zram は RAM の一部を圧縮スワップとして使い、ディスクベースの swap より桁違いに高速で、SD カードの寿命も延ばせます。

### RAM 別のデフォルト設定

| RAM | zram サイズ | 圧縮アルゴ | ディスク swap | 実効メモリ |
|-----|-----------|-----------|-------------|-----------|
| 2GB | 1 GB | lz4 | 512 MB | ~3 GB+ |
| 4GB | 2 GB | lz4 | 1 GB | ~6 GB+ |
| 8GB | 4 GB | zstd | 2 GB | ~12 GB+ |

### 圧縮アルゴリズム比較

| アルゴリズム | 圧縮率 | 速度 | 推奨用途 |
|------------|-------|------|---------|
| zstd | 3〜4x | やや遅い | 8GB RAM（メモリ効率重視） |
| lz4 | 2〜3x | 最速 | 4GB RAM（レイテンシ重視） |
| lzo-rle | 2〜3x | 速い | バランス型（RPi OS デフォルト） |

### zram の状態確認

```bash
# スワップ一覧（zram の優先度が高い）
cat /proc/swaps

# 圧縮統計
cat /sys/block/zram0/mm_stat

# 詳細な診断
./setup-rpi.sh --doctor
```

### zram のオン/オフ切り替え

インストール後でも zram を即座に有効化・無効化できます。

```bash
# zram を無効化（即座にスワップ解除 + 再起動時も無効）
./setup-rpi.sh --zram-off

# zram を再度有効化（RAM に応じて自動設定 + 再起動時も有効）
./setup-rpi.sh --zram-on

# アルゴリズムを変更して有効化（一度 off → on）
./setup-rpi.sh --zram-off
./setup-rpi.sh --zram-on --zram-algo lz4
```

`--zram-off` は以下を行います:

- アクティブな zram デバイスを swapoff して解放
- systemd サービス（`zram-openclaw.service`）を無効化
- `vm.swappiness` をデフォルト（60）に戻す

`--zram-on` は以下を行います:

- RAM に応じたサイズとアルゴリズムで zram を作成・有効化
- systemd サービスを有効化（再起動後も自動で有効）
- `vm.swappiness` を zram 最適値に設定

## アカウント権限とセキュリティ設定

インストーラーは、RPi を個人・家庭内 LAN で使う想定で、以下の権限設定を自動的に行います。

### root 実行の防止

`sudo ./setup-rpi.sh` のように root で実行するとスクリプトは即座に停止します。理由は以下の通りです。

- 生成されるファイル（`.env`、`docker-compose.rpi.yml` など）が root 所有になり、一般ユーザーから操作できなくなる
- docker グループの所属判定が正しく動作しなくなる
- コンテナ内のボリュームマウントで権限の不整合が起きる

スクリプト内部で `sudo` が必要な操作（Docker インストール、systemd 登録など）は、個別に `sudo` を呼び出します。

```bash
# 正しい実行方法
./setup-rpi.sh

# これはエラーになる
sudo ./setup-rpi.sh
```

### Docker グループの自動設定

Docker デーモンは Unix ソケット（`/var/run/docker.sock`）経由で通信します。このソケットは `root:docker` が所有しているため、一般ユーザーが `docker` コマンドを使うには `docker` グループへの所属が必要です。

インストーラーは以下を自動で行います。

- `docker` グループが存在しない場合は Docker インストール時に作成される
- 実行ユーザーを `docker` グループに追加（`sudo usermod -aG docker $USER`）
- グループ追加後、`sg docker` でセッションを即座に切り替えてスクリプトを再実行（ログアウト不要）
- 既に docker グループに追加済みだがセッションに未反映のケースも検出し、自動で `sg docker` を試行

```bash
# 手動で確認する場合
groups                        # 現在のセッションのグループ一覧
grep docker /etc/group        # docker グループのメンバー確認
docker ps                     # 権限テスト（エラーなら未反映）
```

### ファイル・ディレクトリの権限

| 対象 | パーミッション | 理由 |
|------|-------------|------|
| `.env` | `600`（所有者のみ読み書き） | API キーや認証トークンを含むため、他ユーザーから読めないようにする |
| `secrets/` | `700`（所有者のみアクセス） | API キーファイルを格納するディレクトリ。ディレクトリ自体にアクセス制限をかける |
| `secrets/*`（鍵ファイル） | `600` | 個別のシークレットファイルも所有者のみ読み書き |

これらの権限はインストーラー実行時に自動で設定されます。もし過去に `sudo` で実行して `.env` が root 所有になっていた場合も、自動的に現在のユーザーに所有権を修正します。

### systemd サービスの実行ユーザー

起動時の自動スタート用に登録される systemd サービスは、インストーラーを実行したユーザーで動作します。

```ini
# /etc/systemd/system/openclaw.service（抜粋）
[Service]
User=pi          # ← インストーラー実行時の $USER が設定される
WorkingDirectory=/home/pi/openclaw-easy-setup
```

これにより Docker コンテナもそのユーザーの docker グループ権限で起動し、root で動作することはありません。

### doctor による権限診断

`./setup-rpi.sh --doctor` を実行すると、以下の権限チェックが行われます。

- 実行ユーザーが root でないか
- `docker` グループに所属しているか（セッション反映済みか）
- `secrets/` ディレクトリのパーミッション（`700` であるか）
- `secrets/` 内の鍵ファイルのパーミッション（すべて `600` であるか）
- `.env` の所有者（root でないか）とパーミッション（`600` であるか）

```bash
./setup-rpi.sh --doctor
# 出力例:
# [✓] Running as: pi (uid=1000)
# [✓] Docker group: pi is a member
# [✓] secrets/ permissions: 700 (OK), owner: pi
# [✓] secrets/ files: all 600 (OK)
# [✓] .env permissions: 600 (OK)
```

## インストーラーの動作

1. アカウント権限チェック（root 防止、sudo 確認、secrets/.env 権限修正）
2. Raspberry Pi のハードウェア検出（モデル、CPU、RAM、ストレージ）
3. Docker グループのセッション反映チェック
4. zram（圧縮スワップ）の設定 — RAM に応じてサイズとアルゴリズムを自動選択
5. ディスクスワップ領域の設定（zram の補完として低優先度で動作）
6. Docker Engine のインストール（ユーザーを docker グループに追加）
7. `.env` ファイルの生成（トークン自動発行、パーミッション `600`）
8. RPi 最適化された `docker-compose.rpi.yml` の自動生成
9. Docker コンテナのビルド・起動
10. systemd サービスの登録（openclaw + zram、起動時の自動スタート）

### 再実行時の設定ファイル保護

`setup-rpi.sh` を再実行すると、以下のファイルについて上書き保護が働きます。

| ファイル | 再実行時の動作 |
|---------|--------------|
| `.env` | 既存ファイルがあればスキップ（一切変更しない） |
| `docker-compose.rpi.yml` | 既存ファイルがあれば選択肢を表示: 上書き（バックアップ作成）/ スキップ / diff 表示 |
| `openclaw.service` | 同上 |

上書きを選んだ場合、元のファイルは `<ファイル名>.bak.<日時>` として自動保存されます（例: `docker-compose.rpi.yml.bak.20260313-1430`）。手動で編集したカスタム設定が失われる心配はありません。

```bash
# 例: 再実行時の表示
# [!] docker-compose.rpi.yml already exists.
#
#   1) Overwrite (backup current → docker-compose.rpi.yml.bak.20260313-1430)
#   2) Skip (keep existing file)
#   3) Show diff after generating new version
#
# Choice [1/2/3] (default: 1):
```

## Web UI への接続経路

OpenClaw のポートはセキュリティのため `127.0.0.1`（ローカルホスト）にバインドされています。RPi 上のプロセスからしかアクセスできないため、PC やスマホのブラウザから Web UI に接続するには何らかのトンネル経路が必要です。

```
┌──────────────────────────────────────────────────────────────┐
│  RPi 5 (host)                                                │
│                                                              │
│  ┌────────────┐    ┌────────────┐                           │
│  │  OpenClaw   │    │   Ollama   │                           │
│  │  :18789     │    │   :11434   │                           │
│  └──────┬─────┘    └──────┬─────┘                           │
│         │                  │                                  │
│         ▼                  ▼                                  │
│    127.0.0.1:18789   127.0.0.1:11434   ← ホスト側バインド    │
│         │                                                    │
│         ▼                                                    │
│  ┌──────────────────────────────────────┐                   │
│  │  トンネル（以下のいずれか）            │                   │
│  │  • SSH ポートフォワード               │                   │
│  │  • Tailscale                         │                   │
│  │  • Cloudflare Tunnel + Access        │                   │
│  └──────────────┬───────────────────────┘                   │
│                  │                                            │
└──────────────────┼────────────────────────────────────────────┘
                   │
                   ▼
            PC / スマホのブラウザ
            http://localhost:18789  (SSH の場合)
            http://rpi.tailnet:18789 (Tailscale の場合)
            https://openclaw.example.com (Cloudflare の場合)
```

### 方法 1: SSH ポートフォワード（最もシンプル）

追加ソフト不要。SSH さえあればすぐに使えます。`127.0.0.1` バインドのままなのでセキュリティ設定を変更する必要がありません。

PC 側から以下を実行します。

```bash
# 基本形: PC の localhost:18789 → RPi の localhost:18789
ssh -L 18789:127.0.0.1:18789 pi@raspberrypi.local

# Ollama API も転送する場合
ssh -L 18789:127.0.0.1:18789 -L 11434:127.0.0.1:11434 pi@raspberrypi.local

# バックグラウンドで実行（シェルを開かない）
ssh -fN -L 18789:127.0.0.1:18789 pi@raspberrypi.local
```

接続後、PC のブラウザで `http://localhost:18789` を開きます。

SSH トンネルを常時維持したい場合は `autossh` が便利です。

```bash
# RPi 側にインストール（逆方向トンネルの場合）
sudo apt-get install autossh

# PC 側にインストール（通常方向の場合）
# macOS: brew install autossh
# Ubuntu: sudo apt-get install autossh

# 切断時に自動再接続
autossh -M 0 -f -N -L 18789:127.0.0.1:18789 pi@raspberrypi.local
```

**利点**: 追加設定なし、暗号化済み、RPi のポート設定を変更しない
**欠点**: SSH セッションが切れると接続できなくなる（autossh で対処可能）、PC ごとにトンネルが必要

### 方法 2: Tailscale（家庭内 + 外出先からのアクセス）

Tailscale は WireGuard ベースのメッシュ VPN で、RPi と PC/スマホを同じ仮想ネットワークに接続します。外出先からも安全にアクセスでき、NAT やファイアウォールの穴あけが不要です。

```bash
# RPi に Tailscale をインストール
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# 認証 URL が表示されるのでブラウザで開いてログイン
```

Tailscale 経由でアクセスするには、OpenClaw が Tailscale インターフェースでリッスンする必要があります。方法は2つあります。

**方法 A: SSH トンネルとの併用（ポート設定変更なし）**

Tailscale で RPi に SSH 接続し、そこからポートフォワードします。

```bash
# Tailscale の RPi ホスト名で SSH トンネル
ssh -L 18789:127.0.0.1:18789 pi@raspberrypi  # Tailscale の MagicDNS 名
```

**方法 B: Tailscale の serve 機能を使う（推奨）**

Tailscale Funnel / Serve で `127.0.0.1:18789` を Tailscale ネットワークに公開します。ポートバインドの変更は不要です。

```bash
# Tailscale serve で内部ポートを公開（Tailscale ネットワーク内のみ）
sudo tailscale serve --bg 18789

# 確認
tailscale serve status
```

PC/スマホ側（Tailscale クライアントインストール済み）のブラウザから `http://raspberrypi:18789` でアクセスできます。

```bash
# 外部からもアクセスしたい場合は Funnel を使う（HTTPS 自動付与）
sudo tailscale funnel 18789
# → https://raspberrypi.tailnet-xxxx.ts.net/ でアクセス可能
```

**利点**: 外出先からもアクセス可能、NAT 不要、WireGuard による暗号化、RPi のポート設定変更不要（serve 使用時）
**欠点**: Tailscale アカウントが必要（無料枠あり）、全デバイスに Tailscale クライアントが必要

### 方法 3: Cloudflare Tunnel + Access（外部公開 + 認証）

Cloudflare Tunnel（旧 Argo Tunnel）は RPi からの outbound 接続のみで HTTPS を公開します。ポート開放や固定 IP が不要で、Cloudflare Access と組み合わせることで認証（メール OTP、GitHub OAuth など）を追加できます。

```bash
# cloudflared をインストール
curl -fsSL https://pkg.cloudflare.com/cloudflared-ascii.repo | sudo tee /etc/apt/sources.list.d/cloudflared.list
sudo apt-get update && sudo apt-get install -y cloudflared

# Cloudflare アカウントで認証
cloudflared tunnel login

# トンネルを作成
cloudflared tunnel create openclaw

# 設定ファイルを作成
cat > ~/.cloudflared/config.yml <<'EOF'
tunnel: openclaw
credentials-file: /home/pi/.cloudflared/<tunnel-id>.json

ingress:
  - hostname: openclaw.example.com
    service: http://127.0.0.1:18789
  - service: http_status:404
EOF

# DNS レコードを設定（Cloudflare 管理のドメインが必要）
cloudflared tunnel route dns openclaw openclaw.example.com

# トンネルを起動
cloudflared tunnel run openclaw
```

systemd でサービス化して常時稼働させます。

```bash
sudo cloudflared service install
sudo systemctl enable cloudflared
sudo systemctl start cloudflared
```

Cloudflare Access でアクセス制御を追加する場合は、Cloudflare Zero Trust ダッシュボードで以下を設定します。

- Application を作成（Self-hosted、ドメイン: `openclaw.example.com`）
- Policy でアクセスを許可するメールアドレスや認証方法を指定
- アクセス時にメール OTP や GitHub OAuth で認証される

**利点**: HTTPS 自動付与、ポート開放不要、Cloudflare Access で強力な認証、RPi のポート設定変更不要
**欠点**: Cloudflare アカウント + ドメインが必要、設定がやや多い

### 接続方法の比較

| 項目 | SSH トンネル | Tailscale | Cloudflare Tunnel |
|------|------------|-----------|-------------------|
| 難易度 | 低（SSH のみ） | 中 | 中〜高 |
| 外出先アクセス | SSH 可能なら可 | 可 | 可 |
| 追加アカウント | 不要 | Tailscale | Cloudflare + ドメイン |
| 暗号化 | SSH | WireGuard | TLS (HTTPS) |
| 認証 | SSH 鍵 | Tailscale ACL | Cloudflare Access |
| RPi のポート設定変更 | 不要 | 不要 | 不要 |
| 常時接続の維持 | autossh 必要 | 自動 | 自動 |
| RPi の負荷 | 最小 | 小 | 小 |

個人利用で家庭内のみなら SSH トンネル、外出先からも使いたいなら Tailscale、独自ドメインで公開したいなら Cloudflare Tunnel がそれぞれ適しています。いずれの方法でも `127.0.0.1` バインドのままで動作するため、セキュリティ設定を変更する必要はありません。

## 運用コマンド

```bash
# ステータス確認
docker compose ps

# ログ確認
docker compose logs -f

# 停止・再起動
docker compose down
docker compose restart

# モデルの追加
docker compose exec ollama ollama pull llama3.2:3b
docker compose exec ollama ollama run llama3.2:3b

# 診断
./setup-rpi.sh --doctor
```

## systemd サービス

インストール時に2つのサービスが登録されます。

```bash
# OpenClaw サービス
sudo systemctl status openclaw      # ステータス
sudo systemctl restart openclaw     # 再起動
sudo systemctl stop openclaw        # 停止
sudo systemctl disable openclaw     # 自動起動無効化

# zram サービス
sudo systemctl status zram-openclaw   # ステータス
sudo systemctl disable zram-openclaw  # zram 自動起動無効化
```

## パフォーマンス Tips

- SSD（USB 3.0 接続）の使用を強く推奨 — microSD より Docker ビルド・モデルロードが大幅に速い
- ヒートシンク＋ファンによる冷却で安定動作（特に Pi 4B はスロットリングが起きやすい）
- `vcgencmd measure_temp` で CPU 温度を監視（80°C 以上なら冷却対策が必要）
- `vcgencmd get_throttled` でスロットリングを確認（`0x0` 以外なら電源/冷却の問題）
- zram により実効メモリが増加し、Ollama の安定性が向上（詳細は「zram」セクション参照）
- RPi 4B/5 のパフォーマンス比較は「ハードウェア要件」セクションを参照

## トラブルシューティング

### Docker コマンドが permission denied

`docker ps` などで "permission denied" が出る場合、docker グループへの追加がセッションに反映されていません。

```bash
# 1. グループに追加されているか確認
grep docker /etc/group
# docker:x:999:pi  ← ユーザー名が含まれていれば追加済み

# 2. セッションに反映されているか確認
groups
# pi adm ... docker  ← "docker" が表示されていなければ未反映

# 3. 反映する（いずれかの方法）
newgrp docker          # 現在のシェルでグループを切り替え
# または
sudo reboot            # 確実だが再起動が必要
```

もし `grep docker /etc/group` にユーザー名が含まれていない場合は、手動で追加してください。

```bash
sudo usermod -aG docker $USER
newgrp docker
```

### Ollama がメモリ不足で停止

zram が有効な場合、まずディスクスワップを増やしてみてください:

```bash
./setup-rpi.sh --swap 4096
# または小さいモデルに切り替え
docker compose exec ollama ollama pull llama3.2:1b
```

### zram が有効にならない

カーネルモジュールの確認:

```bash
modinfo zram           # モジュールが存在するか確認
sudo modprobe zram     # 手動でロード
./setup-rpi.sh --doctor  # 診断で詳細確認
```

### ビルドが遅い

初回の Docker ビルドは ARM64 上で Node.js ネイティブモジュールをコンパイルするため、RPi 4B で 10〜15分、RPi 5 で 5〜10分かかります。2回目以降はキャッシュが効きます。

### CPU 温度が高い

```bash
vcgencmd measure_temp
# 80°C 以上なら冷却対策が必要（特に RPi 4B）
```
