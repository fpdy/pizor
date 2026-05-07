# Pizor

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
/path/to/pizor/install.sh
```

Or install into an explicit target repository:

```bash
/path/to/pizor/install.sh /path/to/target-repo
```

Installed files include:

```text
AGENTS.md or AGENTS.pizor.md
.pi/.env.example
.pi/skills/node-master/SKILL.md
.pi/skills/node-observer/SKILL.md
.pi/skills/node-worker/SKILL.md
.pi/extensions/pizor/index.ts
.pi/assignments/*.md
.pi/scripts/*
```

Existing `AGENTS.md` files are never overwritten. If the target repository already has one, the installer writes `AGENTS.pizor.md` instead. Merge it manually if needed.

## Start

Open the target repository inside Zellij:

```bash
cd /path/to/target-repo
.pi/scripts/session-start
```


After installing or updating the project-local Pi extension, run `/reload` or restart Pi. You can then start the orchestrator from Pi with:

```text
/pizor-start
```

`/pizor-start` and `session-start` create a dedicated Zellij tab for the observer/master pair.

Polling-based observer loops are forbidden. Workers submit sidecar reports with `worker-report-submit`; that script updates the registry and sends `WORKER_REPORT_POINTER` messages to the current master and observer panes.

This creates:

- observer node
- master node

Give tasks to the master node. The master creates worker nodes only when needed. Each worker receives one bounded assignment, reports back, and is expected to be cleaned up afterward.

For substantial tasks, the master should dispatch safe parallel batches instead of running one worker at a time. For example, an implementation worker can run while read-only investigation/review workers inspect non-conflicting scope. Final tests/checks should be delegated to a verification worker rather than run directly by the master.

## Common commands

Pi slash command:

```text
/pizor-start
```

Shell scripts:

```bash
.pi/scripts/session-start
.pi/scripts/registry-list
.pi/scripts/registry-update status <pane-id> <status>
.pi/scripts/registry-update report <pane-id> <status> [cleanup-required] [report-captured]
.pi/scripts/worker-spawn <task_id> <assignment_id> [purpose] [cwd] [phase] [scope] [depends-on]
.pi/scripts/worker-dispatch <pane_id> <task_id> <assignment_id> <objective> [scope] [stop-condition] [do-not]
.pi/scripts/worker-report-submit <worker-pane> <task-id> <assignment-id> <status> <report-file>
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
PI_ORCH_STATE_DIR=".pizor"
PI_WORKER_NAME_PREFIX=worker
PI_MAX_PARALLEL_WORKERS=4
PI_MAX_PARALLEL_WRITERS=1
```

If `PI_ORCH_SESSION` is unset, scripts read it from Zellij's `$ZELLIJ_SESSION_NAME`.

## Ignored local state

The installer adds the following to `.gitignore`:

```gitignore
.pizor/
.env
.pi/.env
```

`.pizor/` stores local pane registry state and should not be committed.

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
/path/to/pizor/install.sh /path/to/target-repo
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
