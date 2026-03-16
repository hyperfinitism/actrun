# actrun: GitHub Actions をローカルで回す

GitHub Actions のワークフローをローカルで実行するツール actrun を作った。MoonBit で書いている。

## なぜ作ったか

CI が通るか確認するために毎回 push して GitHub Actions の結果を待つのは遅い。ローカルで回せれば、フィードバックループが圧倒的に速くなる。

既存の [act](https://github.com/nektos/act) はよくできているが、Docker 前提で macOS のネイティブ環境では使いにくい。自分のユースケースでは、ホストのツールチェーンをそのまま使って `run:` ステップを実行できればよかった。

## 基本的な使い方

```bash
# インストール不要で試せる
npx @mizchi/actrun .github/workflows/ci.yml

# curl でインストール
curl -fsSL https://raw.githubusercontent.com/mizchi/actrun/main/install.sh | sh

# Docker
docker run --rm -v "$PWD":/workspace -w /workspace ghcr.io/mizchi/actrun workflow run .github/workflows/ci.yml
```

実行するとこうなる。

```
$ actrun .github/workflows/ci.yml --trust
run_id=run-1
workflow=CI
state=completed
lint/step_1: success
lint/step_2: success
test/step_1: success
test/step_2: success
```

`--dry-run` で実行計画だけ確認できる。

```
$ actrun .github/workflows/ci.yml --dry-run
workflow=CI
mode=dry-run

job: lint
  lint/step_1: action (actions/checkout@v5) "Checkout"
  lint/step_2: run "Verify format" [bash]
job: test [needs: lint]
  test/step_1: action (actions/checkout@v5) "Checkout"
  test/step_2: run "Run tests" [bash]
```

`--dry-run --json` で構造化データとして取れるので、スクリプトとの連携もできる。

## ローカルで動かすための工夫

GitHub Actions はクラウドの Ubuntu ランナーで動く前提なので、ローカルでそのまま動かすと色々壊れる。actrun ではいくつかの仕組みでこれを解決している。

### actions/checkout をスキップする

ローカルでは既にリポジトリの中にいるので、checkout は不要。`actrun init` で設定ファイルを生成すると、ローカルにインストール済みのツールを検出して自動でスキップ設定を提案してくれる。

```bash
$ actrun init
Created actrun.toml
```

```toml
local_skip_actions = ["actions/checkout", "actions/setup-node"]
```

### ワークスペースモード

デフォルトの `local` モードはカレントディレクトリで実行する。安全に試したいなら `--worktree` か `--tmp` で隔離できる。

```bash
# git worktree で隔離実行
actrun ci.yml --worktree

# 一時ディレクトリにクローン
actrun ci.yml --tmp
```

### local モードの安全性

ローカル実行でうっかりファイルを消さないように、3 層の防御を入れている。

1. **確認プロンプト**: checkout などワークスペースを変更するステップがある場合、実行前に確認
2. **untracked ファイル保護**: `clean: true`（デフォルト）でも untracked ファイルは消さない
3. **.git 破壊防止**: symlink 攻撃やパス走査による `.git` 削除を防止

## ビルトインアクション

以下のアクションはネイティブにエミュレーションしている。外部依存なしで動く。

| アクション | 概要 |
|-----------|------|
| `actions/checkout` | git clone → ローカルコピー |
| `actions/upload-artifact` / `download-artifact` | `_build/actrun/artifacts/` に保存 |
| `actions/cache` | `_build/actrun/caches/` に保存 |
| `actions/setup-node` | shim 経由でホストの node を使用 |

## 対応している機能

- push トリガーのフィルタ（`branches`, `paths`）
- `strategy.matrix`（axes, include, exclude, fail-fast）
- `if` 条件（`success()`, `failure()`, `always()`）
- `needs` による依存と出力伝搬
- reusable workflows（`workflow_call`、ローカル・リモート）
- `container` / `services`（Docker networking）
- 式関数: `contains`, `startsWith`, `endsWith`, `fromJSON`, `toJSON`, `hashFiles`
- ファイルコマンド: `GITHUB_ENV`, `GITHUB_PATH`, `GITHUB_OUTPUT`, `GITHUB_STEP_SUMMARY`
- `continue-on-error`, `outcome` / `conclusion`

## Nix 連携

`flake.nix` や `shell.nix` を自動検出して `run:` ステップを nix 環境内で実行する。ローカルに Rust や Python が入ってなくても、nix がツールチェーンを提供してくれる。

```bash
# 自動検出（デフォルト）
actrun ci.yml

# 無効化
actrun ci.yml --no-nix

# アドホックにパッケージ指定
actrun ci.yml --nix-packages "python312 jq"
```

## 差分実行とリトライ

モノレポで便利な機能。

```bash
# 変更ファイルがパターンに一致するときだけ実行
actrun ci.yml --affected

# 失敗ジョブだけリトライ
actrun ci.yml --retry
```

`actrun.toml` でワークフローごとにパターンを定義する。

```toml
[affected."ci.yml"]
patterns = ["src/**", "package.json"]
```

## MoonBit で書いた理由

MoonBit は native と JS の両方にコンパイルできる。actrun は native バイナリとして高速に動くし、`npx @mizchi/actrun` で Node.js 環境からも実行できる。Docker イメージでは amd64 は native バイナリ、arm64 は JS バンドルを使い分けている。

パーサーや lowering（ワークフロー → 実行計画の変換）は純粋な計算で I/O に依存しない。プロセス実行だけをバックエンド別に切り替えている。

```
YAML → Parser(pure) → WorkflowSpec → Lowering(pure) → ExecutionPlan → Executor(I/O)
```

## インストール

```bash
# npx（インストール不要）
npx @mizchi/actrun .github/workflows/ci.yml

# curl
curl -fsSL https://raw.githubusercontent.com/mizchi/actrun/main/install.sh | sh

# npm
npm install -g @mizchi/actrun

# Docker
docker run --rm -v "$PWD":/workspace -w /workspace ghcr.io/mizchi/actrun workflow run .github/workflows/ci.yml
```

## リンク

- GitHub: https://github.com/mizchi/actrun
- npm: https://www.npmjs.com/package/@mizchi/actrun
