# TODO

現在の目標は、`action_runner` を「ローカルで GitHub Actions workflow を再現し、標準 actions を一通り扱え、`gh` 互換の CLI で制御できる runner」に持っていくこと。

優先順位は次の 3 本柱で切る。

1. GitHub 標準 actions の互換率を上げる
2. 同じ workflow を `worktree` / `/tmp` / `docker` で安定して実行できるようにする
3. 実行・観測・artifact/cache 操作を `gh` 互換の CLI で制御できるようにする

## ゴール

- [ ] 主要な GitHub 標準 actions を local で再現できる
- [ ] 同じ workflow が `worktree` / `/tmp` / `docker` の各 substrate で同じ結果を返す
- [ ] run / logs / artifacts / cache を `gh` 互換の subcommand で扱える
- [ ] README に書いた対応範囲が docs/upstream/live compat で裏付けられている

## 設計方針

- [ ] 仕様の正本は GitHub Docs に置く
- [ ] parser / expression の補助 fixture は `actions/languageservices`
- [ ] runtime 挙動の補助 fixture は `nektos/act`
- [ ] unsupported は黙って無視せず、明示 reject
- [ ] 新機能は `upstream source 付き Red -> Green -> Refactor`
- [ ] feature claim は docs-based compat または live compat で裏付ける

## Source of Truth

- Workflow syntax: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax
- Contexts: https://docs.github.com/en/actions/reference/workflows-and-actions/contexts
- Expressions: https://docs.github.com/en/actions/reference/workflows-and-actions/expressions
- Workflow commands: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands
- `actions/languageservices`: https://github.com/actions/languageservices
- `workflow-parser/testdata/reader`: https://github.com/actions/languageservices/tree/main/workflow-parser/testdata/reader
- `expressions/testdata`: https://github.com/actions/languageservices/tree/main/expressions/testdata
- `nektos/act` runner testdata: https://github.com/nektos/act/tree/master/pkg/runner/testdata

## 現在地

- [x] docs / languageservices / act fixture の compat 基盤
- [x] GitHub-hosted live compat (`gha-compat-live`, `gha-compat-compare`)
- [x] `checkout`, `artifact`, `cache`, `setup-node`, reusable workflow, job `container`, `services` の最小対応
- [x] local / remote action lifecycle と matrix / `if` / file commands の主要 slice
- [x] Wasm backend contract / adapter と backend capability model

## P0: 実行基盤を固める

「どこで実行するか」を先に固定する。ここが曖昧だと actions 互換も CLI もぶれる。

- [x] run record の永続化
  - [x] `_build/action_runner/runs/<run-id>/run.json` の最小保存
  - [x] `_build/action_runner/runs/<run-id>/` の layout を固定
  - [x] `run.json` / step 状態 / task 状態 / exit code / task log path を保存
  - [x] step log / summary を保存
  - [x] job 状態 / artifact index / cache index を保存
  - [x] `timestamps` を保存
- [ ] workspace substrate の明確化
  - [x] `--workspace-mode` contract (`local`, `repo=tmp` の default)
  - [x] `--workspace-mode local` (in-place 実行、デフォルト)
  - [x] `--workspace-mode worktree` (`git worktree add` で隔離)
  - [x] `--workspace-mode tmp` (`git clone` で隔離)
  - [ ] `--workspace-mode docker`
  - [x] 各 mode の cleanup / isolation policy を固定
  - [x] secret を含みうる `_build/action_runner/file_commands` / `runner_temp` が run 後に cleanup されることを確認する security test
  - [x] step script / `.npmrc` / file command file が world-readable にならないことを確認する security test
- [x] local injection point を CLI flag に昇格
  - [x] `--run-root`
  - [x] `--artifact-root`
  - [x] `--cache-root`
  - [x] `--github-action-cache-root`
  - [x] `--registry-root`
  - [x] `--wasm-action-root`
- [x] substrate parity E2E
  - [x] 同一 workflow を `local` / `worktree` / `tmp` で流す共通 scenario 群
  - [x] artifact / cache / summary / logs が substrate を跨いで一致することを確認
  - [x] repo mode / `--event` / `head_commit` fallback も substrate matrix に入れる

## P1: `gh` 互換 CLI を作る

今の positional CLI を product にする段階。最終的には local runner を `gh` ライクに操作できるようにする。

- [x] command family の導入
  - [x] `action_runner workflow list`
  - [x] `action_runner workflow run <workflow>`
  - [x] `action_runner run list`
  - [x] `action_runner run view <run-id>`
  - [x] `action_runner run watch <run-id>`
  - [x] `action_runner run logs <run-id>`
  - [x] `action_runner run download <run-id>`
  - [x] `action_runner artifact list <run-id>`
  - [x] `action_runner artifact download <run-id>`
  - [x] `action_runner cache list`
  - [x] `action_runner cache prune`
- [x] 現行 CLI との互換レイヤ
  - [x] 既存の `action_runner <workflow.yml> ...` を `workflow run` に寄せる（deprecation warning 追加）
  - [x] repo mode / event mode / substrate mode を subcommand に整理する
- [x] CLI 出力 contract
  - [x] `--json` を全 read command に追加
  - [x] run state / artifact metadata / cache metadata の JSON schema を固定（schema 検証テスト追加）
  - [x] non-zero exit code と run state の対応を固定
- [x] CLI black-box
  - [x] run store を前提にした `view/watch/logs/download` E2E
  - [x] run store / `run logs` / `run view` が secret を mask して表示・保存することを確認する security test
  - [x] `gh run` / `gh workflow` の naming に寄せた usage docs

## P2: GitHub 標準 actions を広げる

方針は 2 段階。

1. deterministic に再現したいものは builtin / emulator にする
2. builtin にしない official action は remote `node` action として通し、smoke/live compat で保証する

### P2-A: builtin 優先 actions

- [ ] `actions/checkout`
  - [x] `lfs`
  - [x] `persist-credentials: false`
  - [x] `fetch-tags`
  - [x] `show-progress`
  - [x] `set-safe-directory`
  - [ ] token / ssh-key / ssh-known-hosts の policy 決定
- [ ] `actions/upload-artifact` / `actions/download-artifact`
  - [x] `pattern` (download-artifact の glob フィルタ)
  - [ ] `artifact-ids` (ローカル runner では ID 体系なし — unsupported)
  - [x] `retention-days` (ローカルでは no-op、静かに無視)
  - [x] `compression-level` (ローカルでは no-op、静かに無視)
  - [x] `include-hidden-files`
- [ ] `actions/cache`
  - [x] `enableCrossOsArchive` (ローカルでは no-op)
  - [ ] cache version semantics
  - [x] path list normalization (`~` 展開、trim)
  - [x] failure/cancel 時の post-save edge case (always() + cancel 時は post 不実行で正しく動作)
- [ ] `actions/setup-node`
  - [x] `node-version-file` (`.nvmrc`, `.node-version`, `.tool-versions`, `package.json`)
  - [ ] `check-latest` (ローカルではシステム node を使うため低優先度)
  - [x] package-manager-cache auto detection (`npm` / `yarn` / `pnpm`)
  - [x] `always-auth` / `scope` / `.npmrc` nuance
- [x] `actions/github-script`
  - [x] remote official node action 扱いに決定（builtin 化しない）
  - [ ] local E2E と live compat を付ける

### P2-B: official actions の実行保証

- [x] official node action coverage policy を決める
  - [x] builtin: checkout, upload/download-artifact, cache, setup-node
  - [x] remote fetch + node 実行: github-script, setup-python/go/java/dotnet/ruby
- [ ] smoke/live compat を張る official actions
  - [x] `actions/setup-python` (live compat workflow 追加)
  - [x] `actions/setup-go` (live compat workflow 追加)
  - [x] `actions/setup-java` (live compat workflow 追加)
  - [x] `actions/setup-dotnet` (live compat workflow 追加)
  - [x] `ruby/setup-ruby` (live compat workflow 追加)
  - [x] `actions/github-script` (live compat workflow 追加)

## P3: workflow/runtime 互換を締める

- [ ] reusable workflow の広い互換対応
  - [x] caller matrix + reusable outputs の live compat (workflow 追加)
  - [ ] nested reusable workflow の docs/live compat matrix
  - [x] remote reusable workflow + `secrets: inherit` の main branch live compat (既存)
- [ ] container / services の hardening
  - [ ] builtin action coverage matrix を container job で揃える
  - [x] service `volumes` / `options` / `credentials` semantics (既存実装で対応済)
  - [x] service log capture と run store 保存 (`docker logs` を cleanup 時に取得)
  - [x] `docker login` credential が argv / stderr / run store に平文で出ないことを確認する security test (`--password-stdin` + mask_secrets)
- [ ] shell / host 差分
  - [ ] `pwsh` 実行環境差分 (pwsh がシステムにある場合のみ動作)
  - [x] shell template compatibility の fixture 拡張 (bash/sh/custom template E2E)

## P4: registry / backend を product にする

- [ ] custom registry action の remote fetch / protocol 解決
- [x] registry cache layout / versioning / auth policy
  - [x] GitHub actions: `_build/action_runner/github_actions/{owner}/{repo}/{version}/`
  - [x] Custom registry: `_build/action_runner/registry_actions/{scheme}/{name}/{version}/`
  - [x] 環境変数 override: `ACTION_RUNNER_GITHUB_ACTION_CACHE_ROOT`, `ACTION_RUNNER_ACTION_REGISTRY_ROOT`
- [x] Wasm backend の広い互換対応
  - [x] env / input / output contract (file commands 経由: GITHUB_ENV/OUTPUT/STATE)
  - [x] pre/post lifecycle policy (wasm は manifest なし・単一 entrypoint モデル。pre/post は将来 action.yml 対応時に拡張)
  - [x] artifact / cache integration (host 側の builtin action でカバー)
- [x] backend selection policy を CLI / config から制御可能にする
  - [x] 自動選択: action ref の型で backend 決定 (builtin/node/docker/wasm)
  - [x] 環境変数 override: `ACTION_RUNNER_WASM_BIN`, `ACTION_RUNNER_DOCKER_BIN`, `ACTION_RUNNER_NODE_BIN`, `ACTION_RUNNER_GIT_BIN`

## P5: 互換性運用を固定する

- [ ] README の feature claim と docs-based compat の対応表を作る
- [ ] fixture metadata から support matrix を自動生成する
- [ ] 新機能テンプレートを用意する
  - [ ] source URL
  - [ ] Red fixture
  - [ ] Green 実装
  - [ ] live compat の有無
- [x] release checklist
  - [x] local `just release-check` (fmt + info + check + test + e2e)
  - [ ] main branch live compat
  - [ ] CLI contract diff

## 完了条件

- [x] `gh` 互換 CLI で local run / logs / artifacts / cache を操作できる
- [x] 主要 workflow が `local` / `worktree` / `tmp` で同じ結果になる
- [x] GitHub 標準 actions の優先セットに docs/E2E/live compat が揃う
- [ ] README に書いた対応範囲が compat test で裏付けられている
