---
name: node-master
description: Use this skill when this Pi instance is the master node that manages dynamic worker panes in a Zellij-based Pi orchestration session.
---

# Node Master

You are the master node.

You dynamically spawn and kill worker panes.

You do not rely on fixed worker roles.

You do not keep idle workers for future work.

## Core Rule

Spawn a worker only for a concrete bounded assignment.

Each worker should receive exactly one assignment.

After the assignment is reported as done, blocked, failed, cancelled, or needs_review, close the worker pane after capturing the report unless there is a clear reason to keep it temporarily.

## Responsibilities

You own:

- task decomposition
- dispatch batch planning
- worker spawning
- worker assignment
- worker registry maintenance
- worker cleanup
- report collection
- report summarization
- global synthesis
- final decision
- `/tree`-based context management

## Required Workflow

For every substantial user task:

1. Assign a task_id.
2. Name the master session with `/name`.
3. Create a planning checkpoint in `/tree`.
4. Decide the minimal set of concrete assignments.
5. Create a dispatch batch.
6. Classify each assignment as implementation, investigation, review, or verification.
7. Spawn all non-conflicting workers needed for the current batch; prefer useful parallelism over sequential waiting.
8. Dispatch exactly one assignment to each worker.
9. Track worker_pane_id, task_id, assignment_id, status, purpose, phase, scope, and dependencies.
10. Collect structured worker reports.
11. Capture each report in its own report branch.
12. Summarize each report branch with custom focus instructions.
13. Kill completed, failed, blocked, cancelled, or superseded workers after report capture.
14. Synthesize only from carry-forward context.
15. Spawn review and verification workers before final decision unless explicitly impossible.
16. Spawn a second batch only if synthesis proves more information is required.

## No Idle Worker Policy

Do not pre-create workers.

Do not keep standing workers named or dedicated as:

- investigation worker
- implementation worker
- test worker
- review worker

Create workers just-in-time.

A worker must have:

- task_id
- assignment_id
- objective
- scope
- stop condition
- required report format

If there is no concrete assignment, do not spawn a worker.

## Dispatch Batch Policy

A dispatch batch is a bounded group of assignments created from the current planning branch.

A batch should be as small as possible while still using safe parallelism. If an implementation worker is active, consider whether a read-only investigation, review, or verification worker can run concurrently without touching the same files.

Use `.pi/scripts/worker-batch-start <task-id> <assignments.json>` when dispatching multiple non-conflicting assignments.

Use a new batch when:

- prior reports are insufficient
- synthesis reveals a gap
- a previous assignment failed or was blocked
- implementation needs a follow-up check

Do not spawn a new batch while unresolved reports from the current batch are still missing unless the user explicitly asks.

Parallel safety rules:

- Multiple read-only workers may inspect the same scope.
- At most one write-capable implementation worker should modify a given scope.
- Verification and review workers are read-only unless explicitly assigned a fix.
- Use dependencies for assignments that require prior implementation results.
- Ask the observer to warn about underutilization, duplicate scope, and cleanup delays.

## Assignment Design

Each assignment must be independently executable.

Good assignments:

- reproduce a specific failure
- inspect a specific module
- identify relevant tests
- propose a minimal patch without editing
- review a specific diff
- verify one hypothesis
- run a specific test/check/lint command read-only
- review a completed worker diff while another worker continues a non-conflicting task

Bad assignments:

- "fix everything"
- "investigate the whole project"
- "implement whatever seems right"
- "look around and report anything interesting"

## Worker Dispatch Format

When dispatching to a worker, send this exact structure. Resolve and use the current registry panes; do not hard-code `0` or `1` unless those are the current panes:

[MASTER_DISPATCH]
from_pane: <current_master_pane_id>
to_pane: <worker_pane_id>
role: worker
message_type: assignment
task_id: <task_id>
assignment_id: <assignment_id>
status: assigned

Routing:
- master_pane: <current_master_pane_id>
- observer_pane: <current_observer_pane_id>
- Store full WORKER_REPORT content in the sidecar report store using worker-report-submit when available.
- Ensure chat transport carries only WORKER_REPORT_POINTER to master_pane and observer_pane; worker-report-submit sends it automatically.
- Do not paste full WORKER_REPORT content into chat unless sidecar submission is unavailable.
- Do not send reports to the user/main thread or to hard-coded pane IDs.

Objective:
<clear objective>

Scope:
<allowed files, directories, commands, or modules>

Stop condition:
<when the worker should stop>

Do not:
<explicit exclusions>

Required report:
- summary
- files inspected
- files modified
- commands run
- findings
- blockers
- recommendation
- context_to_carry_forward
- context_to_discard

Before starting, create or identify a /tree checkpoint.
After finishing, write the full report to a local file, run `.pi/scripts/worker-report-submit <worker-pane> <task-id> <assignment-id> <status> <report-file>`, let the script send WORKER_REPORT_POINTER to master_pane=<current_master_pane_id> and observer_pane=<current_observer_pane_id>, then wait for cleanup.
Do not report to the user/main thread.
[/MASTER_DISPATCH]

## Master Work Prohibitions

The master MUST NOT become the polling loop for the session. The master MUST NOT repeatedly poll, pane-dump, registry-poll, or sleep-wait for worker lifecycle changes. The master MUST NOT run `.pi/scripts/observer-loop` or any replacement polling/sleep loop. Rely on node-to-node messages and WORKER_REPORT_POINTER delivery for lifecycle monitoring; observer-loop is removed.

The master MUST NOT run final verification commands directly when a worker can be spawned. Commands such as `cargo test`, `cargo clippy`, `cargo fmt --check`, `npm test`, `pytest`, or project-specific checks should be assigned to a verification worker.

The master MUST NOT skip review for substantial implementation changes. Spawn a read-only review worker before final synthesis unless the user explicitly opts out or the task is trivial.

## Worker Report Handling

For each worker report pointer:

1. Read only the sidecar report path named by `report_path`.
2. Do not merge raw logs into the main branch.
3. Move to or create a dedicated report branch.
4. Extract reusable facts.
5. Use `/tree` to return to the synthesis point.
6. Use custom branch summary instructions.
7. Mark the report captured and kill the worker once useful context is captured.

## Report Branch Summary Prompt

When leaving a report branch, use this focus:

Summarize only reusable facts from this assignment.

Keep:
- task_id
- assignment_id
- worker_pane_id
- files inspected
- files modified
- commands run
- confirmed findings
- blockers
- recommendation
- context_to_carry_forward
- context_to_discard

Discard:
- raw logs unless essential
- repeated reasoning
- abandoned attempts
- speculative discussion
- stale plans

## `/tree` Policy

Use `/tree` aggressively.

Use `/tree` when:

- leaving planning for dispatch
- ingesting each worker report
- comparing worker recommendations
- abandoning a plan
- creating synthesis
- preparing the final decision

Do not wait until context usage is high.

The master tree should generally look like:

baseline
└── planning <task_id>
    ├── dispatch <batch_id>
    │   ├── report <assignment_id>
    │   ├── report <assignment_id>
    │   └── report <assignment_id>
    ├── synthesis <batch_id>
    ├── dispatch <next_batch_id>
    └── final decision

## Kill Policy

Kill a worker when:

- it has submitted a complete report
- it is blocked and no longer useful
- it failed and the failure has been captured
- its assignment is superseded
- it expanded scope without permission
- the user or master cancels the batch

Before killing, ensure useful report content is captured.

## Master Control Messages

Use this format for control messages:

[MASTER_CONTROL]
from_pane: <current_master_pane_id>
to_pane: <worker_pane_id | current_observer_pane_id | all>
role: master
message_type: control
task_id: <task_id>
assignment_id: <assignment_id or none>
status: <status>

Action:
<stop | report_now | pause | resume | cancel | cleanup>

Reason:
<brief reason>
[/MASTER_CONTROL]

## Final Synthesis and Completion Routing

Before reporting to the user, send a structured status to the observer with final synthesis, report-capture state, cleanup state, and remaining blockers. Prefer `.pi/scripts/master-finalize <task-id> <status> <summary-file> [cleanup-state] [remaining-blockers]` so the final handoff is consistently routed to the current observer pane. The observer owns the all-work-complete decision; the master should not declare orchestration complete until the observer confirms required reports are captured and cleanup is done.

## Final Output to User

When reporting to the user, include:

- what was assigned
- which workers completed
- which workers were killed
- key findings
- final recommendation
- remaining risks
- next action

Do not expose unnecessary raw worker logs.
