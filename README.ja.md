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
.env.example または .env.pi-orchestrator.example
.pi/skills/node-master/SKILL.md
.pi/skills/node-observer/SKILL.md
.pi/skills/node-worker/SKILL.md
scripts/*
```

既存の `AGENTS.md` は上書きしません。既に存在する場合は `AGENTS.pi-orchestrator.md` として配置されるため、必要に応じて内容を統合してください。

## 起動

対象リポジトリを Zellij 内で開きます。

```bash
cd /path/to/target-repo
scripts/session-start
```

起動後、以下の pane が作られます。

- observer node
- master node

master node に作業を依頼すると、必要な分だけ worker node が動的に作成されます。worker は 1 つの bounded assignment を実行し、報告後に cleanup される前提です。

## よく使うコマンド

```bash
scripts/session-start
scripts/registry-list
scripts/worker-spawn <task_id> <assignment_id> [purpose] [cwd]
scripts/worker-dispatch <pane_id> <dispatch-file>
scripts/worker-kill <pane_id>
scripts/worker-cleanup
```

## 設定

通常 `.env` は不要です。必要な場合のみ `.env.example` をコピーして編集します。

```bash
cp .env.example .env
```

主な設定:

```bash
PI_CMD=pi
PI_WORKDIR="$PWD"
PI_ORCH_STATE_DIR=".orchestrator"
PI_WORKER_BOOT_WAIT=1
PI_WORKER_NAME_PREFIX=worker
```

`PI_ORCH_SESSION` は未設定の場合、Zellij の `$ZELLIJ_SESSION_NAME` から取得されます。

## Git 管理しないもの

インストーラは `.gitignore` に以下を追加します。

```gitignore
.orchestrator/
.env
```

`.orchestrator/` は pane registry などのローカル状態です。

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
  scripts/
```
