# Pi Zellij Orchestrator

A distributable multi-agent orchestration template for running Pi across Zellij panes as an **observer**, **master**, and ephemeral **workers**.

This repository contains an installer and templates. Install it into any Git repository where you want to use the orchestration system.

日本語版: [README.ja.md](README.ja.md)

## Requirements

The target environment needs:

```bash
pi
zellij
jq
```

This system is designed to be run **from inside Zellij**. `PI_ORCH_SESSION` usually does not need to be configured manually; scripts use the current `$ZELLIJ_SESSION_NAME`.

## Install

From the repository where you want to use the orchestrator, run the installer from a cloned copy of this repository:

```bash
/path/to/pi-zellij-orchestrator/install.sh
```

Or install into an explicit target repository:

```bash
/path/to/pi-zellij-orchestrator/install.sh /path/to/target-repo
```

Installed files include:

```text
AGENTS.md or AGENTS.pi-orchestrator.md
.pi/.env.example
.pi/skills/node-master/SKILL.md
.pi/skills/node-observer/SKILL.md
.pi/skills/node-worker/SKILL.md
.pi/assignments/*.md
.pi/scripts/*
```

Existing `AGENTS.md` files are never overwritten. If the target repository already has one, the installer writes `AGENTS.pi-orchestrator.md` instead. Merge it manually if needed.

## Start

Open the target repository inside Zellij:

```bash
cd /path/to/target-repo
.pi/scripts/session-start
```

For autonomous lifecycle monitoring, start with:

```bash
.pi/scripts/session-start --auto-observe
```

`--auto-observe` asks the observer pane to run `observer-loop`, which polls the registry/panes, detects worker reports, warns about idle or long-running workers, and warns when the master starts doing verification work directly.

This creates:

- observer node
- master node

Give tasks to the master node. The master creates worker nodes only when needed. Each worker receives one bounded assignment, reports back, and is expected to be cleaned up afterward.

For substantial tasks, the master should dispatch safe parallel batches instead of running one worker at a time. For example, an implementation worker can run while read-only investigation/review workers inspect non-conflicting scope. Final tests/checks should be delegated to a verification worker rather than run directly by the master.

## Common commands

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

## Configuration

Usually no `.pi/.env` file is required. If needed, copy and edit the example:

```bash
cp .pi/.env.example .pi/.env
```

Common settings:

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

If `PI_ORCH_SESSION` is unset, scripts read it from Zellij's `$ZELLIJ_SESSION_NAME`.

## Ignored local state

The installer adds the following to `.gitignore`:

```gitignore
.orchestrator/
.env
```

`.orchestrator/` stores local pane registry state and should not be committed.

## Parallel batch example

Create an assignment file:

```json
[
  {
    "assignment_id": "A1-impl",
    "objective": "Implement the bounded change in src/foo.rs.",
    "scope": "src/foo.rs",
    "phase": "implementation",
    "access": "write"
  },
  {
    "assignment_id": "A2-review",
    "objective": "Review the previous phase and inspect adjacent risk areas without editing.",
    "scope": "src/foo.rs src/foo_tests.rs",
    "phase": "review",
    "access": "read"
  },
  {
    "assignment_id": "A3-verify",
    "objective": "Run the focused test command and report results without editing.",
    "scope": "cargo test foo",
    "phase": "verification",
    "access": "read"
  }
]
```

Then dispatch the non-conflicting batch:

```bash
.pi/scripts/worker-batch-start task-123 assignments.json
```

The script enforces `PI_MAX_PARALLEL_WORKERS`, `PI_MAX_PARALLEL_WRITERS`, and duplicate write-scope checks.

## Updating

After updating this repository, run the installer again in the target repository:

```bash
/path/to/pi-zellij-orchestrator/install.sh /path/to/target-repo
```

If an existing installed file differs, the installer creates a `.bak.<timestamp>` backup before replacing it. `AGENTS.md` is still not overwritten directly.

## Repository layout

```text
install.sh
README.md
README.ja.md
templates/
  AGENTS.md
  .env.example
  .pi/skills/
  assignments/
  scripts/
```
