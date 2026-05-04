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
.pi/scripts/*
```

Existing `AGENTS.md` files are never overwritten. If the target repository already has one, the installer writes `AGENTS.pi-orchestrator.md` instead. Merge it manually if needed.

## Start

Open the target repository inside Zellij:

```bash
cd /path/to/target-repo
.pi/scripts/session-start
```

This creates:

- observer node
- master node

Give tasks to the master node. The master creates worker nodes only when needed. Each worker receives one bounded assignment, reports back, and is expected to be cleaned up afterward.

## Common commands

```bash
.pi/scripts/session-start
.pi/scripts/registry-list
.pi/scripts/worker-spawn <task_id> <assignment_id> [purpose] [cwd]
.pi/scripts/worker-dispatch <pane_id> <dispatch-file>
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
```

If `PI_ORCH_SESSION` is unset, scripts read it from Zellij's `$ZELLIJ_SESSION_NAME`.

## Ignored local state

The installer adds the following to `.gitignore`:

```gitignore
.orchestrator/
.env
```

`.orchestrator/` stores local pane registry state and should not be committed.

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
  scripts/
```
