# Investigation Worker Assignment Template

Use this for bounded read-only research before or during implementation.

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
- Store full report through .pi/scripts/worker-report-submit when available.
- Do not paste full WORKER_REPORT content into chat; use worker-report-submit so only WORKER_REPORT_POINTER is delivered.

Objective:
Investigate <specific hypothesis/question> and report confirmed facts. Do not edit files.

Scope:
Read-only. Inspect: <files/directories/commands>. Stay within the hypothesis.

Stop condition:
Stop when the hypothesis is confirmed/refuted, relevant files/tests are identified, or you become blocked.

Do not:
Do not modify files. Do not commit. Do not implement fixes. Do not broaden into unrelated investigation.

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

After finishing, submit the sidecar report; worker-report-submit sends the pointer to master/observer only.
[/MASTER_DISPATCH]
