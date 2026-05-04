# Pi Zellij Orchestrator

Pi を Zellij pane 上で **observer / master / ephemeral worker** として動かすための、配布可能なマルチエージェント orchestration テンプレートです。

このリポジトリ自体はインストーラとテンプレートを持ち、任意の Git リポジトリへ必要ファイルを展開して利用します。

## 前提

対象環境に以下が必要です。

```bash
pi
zellij
jq
```

このシステムは **Zellij 内で実行する前提** です。`PI_ORCH_SESSION` は通常設定不要で、現在の `$ZELLIJ_SESSION_NAME` が使われます。

## インストール

利用したいリポジトリで、clone 済みのこのリポジトリから実行します。

```bash
/path/to/pi-zellij-orchestrator/install.sh
```

別ディレクトリにインストールする場合:

```bash
/path/to/pi-zellij-orchestrator/install.sh /path/to/target-repo
```

インストールされる主なファイル:

```text
AGENTS.md または AGENTS.pi-orchestrator.md
.pi/.env.example
.pi/skills/node-master/SKILL.md
.pi/skills/node-observer/SKILL.md
.pi/skills/node-worker/SKILL.md
.pi/assignments/*.md
.pi/scripts/*
```

既存の `AGENTS.md` は上書きしません。既に存在する場合は `AGENTS.pi-orchestrator.md` として配置されるため、必要に応じて内容を統合してください。

## 起動

対象リポジトリを Zellij 内で開きます。

```bash
cd /path/to/target-repo
.pi/scripts/session-start
```

ライフサイクル監視を自律化する場合は次を使います。

```bash
.pi/scripts/session-start --auto-observe
```

`--auto-observe` は observer pane に `observer-loop` を実行させます。これにより registry/pane の polling、worker report 検出、idle/長時間 worker 警告、master が verification を直接実行した場合の警告を observer が担います。

起動後、以下の pane が作られます。

- observer node
- master node

master node に作業を依頼すると、必要な分だけ worker node が動的に作成されます。worker は 1 つの bounded assignment を実行し、報告後に cleanup される前提です。

大きめの作業では、master は worker を 1 つずつ逐次実行するのではなく、安全な並列 batch を dispatch するべきです。例えば implementation worker と並行して、read-only の investigation/review worker が非競合 scope を確認できます。最終 test/check は master が直接実行せず、verification worker に委譲します。

## よく使うコマンド

```bash
.pi/scripts/session-start [--auto-observe]
.pi/scripts/registry-list
.pi/scripts/observer-loop [--once] [--interval seconds]
.pi/scripts/registry-update status <pane-id> <status>
.pi/scripts/registry-update report <pane-id> <status> [cleanup-required] [report-captured]
.pi/scripts/worker-spawn <task_id> <assignment_id> [purpose] [cwd] [phase] [scope] [depends-on]
.pi/scripts/worker-dispatch <pane_id> <task_id> <assignment_id> <objective> [scope] [stop-condition] [do-not]
.pi/scripts/worker-batch-start <task_id> <assignments.json>
.pi/scripts/worker-kill <pane_id>
.pi/scripts/worker-cleanup
```

## 設定

通常 `.pi/.env` は不要です。必要な場合のみ `.pi/.env.example` をコピーして `.pi/.env` として編集します。

```bash
cp .pi/.env.example .pi/.env
```

主な設定:

```bash
PI_CMD=pi
PI_WORKDIR="$PWD"
PI_ORCH_STATE_DIR=".orchestrator"
PI_WORKER_BOOT_WAIT=1
PI_WORKER_NAME_PREFIX=worker
PI_OBSERVER_POLL_INTERVAL=5
PI_WORKER_IDLE_WARN_SECONDS=120
PI_WORKER_LONG_RUNNING_SECONDS=300
PI_OBSERVER_NOTICE_COOLDOWN_SECONDS=60
PI_MAX_PARALLEL_WORKERS=4
PI_MAX_PARALLEL_WRITERS=1
```

`PI_ORCH_SESSION` は未設定の場合、Zellij の `$ZELLIJ_SESSION_NAME` から取得されます。

## Git 管理しないもの

インストーラは `.gitignore` に以下を追加します。

```gitignore
.orchestrator/
.env
```

`.orchestrator/` は pane registry などのローカル状態です。

## 並列 batch 例

assignment file を作成します。

```json
[
  {
    "assignment_id": "A1-impl",
    "objective": "src/foo.rs に限定した変更を実装する。",
    "scope": "src/foo.rs",
    "phase": "implementation",
    "access": "write"
  },
  {
    "assignment_id": "A2-review",
    "objective": "前 phase と周辺リスクを read-only で review する。",
    "scope": "src/foo.rs src/foo_tests.rs",
    "phase": "review",
    "access": "read"
  },
  {
    "assignment_id": "A3-verify",
    "objective": "focused test command を実行して結果を報告する。編集しない。",
    "scope": "cargo test foo",
    "phase": "verification",
    "access": "read"
  }
]
```

非競合 batch を dispatch します。

```bash
.pi/scripts/worker-batch-start task-123 assignments.json
```

この script は `PI_MAX_PARALLEL_WORKERS`, `PI_MAX_PARALLEL_WRITERS`, duplicate write-scope を検査します。

## 更新

このリポジトリを更新後、対象リポジトリで再度 installer を実行してください。

```bash
/path/to/pi-zellij-orchestrator/install.sh /path/to/target-repo
```

既存ファイルと内容が異なる場合は `.bak.<timestamp>` を作成してから更新します。ただし `AGENTS.md` は直接上書きしません。

## 開発者向け構成

```text
install.sh
README.md
templates/
  AGENTS.md
  .env.example
  .pi/skills/
  assignments/
  scripts/
```
