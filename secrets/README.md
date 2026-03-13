# secrets/

API キーなどの秘密情報を個別ファイルとして配置するディレクトリです。

## 使い方

ファイル名を環境変数名にして、中身にキーの値だけを書きます。

```bash
echo "sk-ant-api03-xxxxx" > secrets/ANTHROPIC_API_KEY
echo "sk-xxxxx" > secrets/OPENAI_API_KEY
```

`docker compose up` すると、entrypoint が `/run/secrets/` 内のファイルを読み込み、
環境変数として OpenClaw に渡します。

## なぜ .env に書かないのか

`.env` に API キーを書くと、以下のリスクがあります。

- `docker inspect` でコンテナの環境変数として丸見えになる
- `.env` を誤って git に commit すると全キーが漏洩する
- AI エージェントが `env` コマンドを実行できた場合に取得される

`secrets/` ディレクトリに分離することで、これらのリスクを低減できます。

## 対応している変数名

`secrets/` に置けるファイル名の例:

- `ANTHROPIC_API_KEY`
- `OPENAI_API_KEY`
- `GOOGLE_API_KEY`
- `GROQ_API_KEY`
- `LINE_CHANNEL_ACCESS_TOKEN`
- `LINE_CHANNEL_SECRET`
- `TELEGRAM_BOT_TOKEN`
- `SLACK_BOT_TOKEN`
- その他、`.env.example` に記載されている `*_API_KEY` / `*_TOKEN` / `*_SECRET` 変数すべて

## 注意

- このディレクトリ内のファイルは `.gitignore` で git から除外されています
- ファイルの末尾に改行が入っても自動的に除去されます
- `.env` に同じ変数を書いた場合、`secrets/` のファイルが優先されます
