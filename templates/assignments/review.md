# Review Worker Assignment Template

Use this for read-only review of a diff, plan, or completed worker output.

[MASTER_DISPATCH]
from_pane: 1
to_pane: <worker_pane_id>
role: worker
message_type: assignment
task_id: <task_id>
assignment_id: <assignment_id>
status: assigned

Objective:
Review <diff/plan/report> for correctness, regressions, scope creep, missing tests, and orchestration policy violations. Do not edit files.

Scope:
Read-only. Inspect: <files/commands>. Compare against: <requirements>.

Stop condition:
Stop when you can produce a concrete review report with pass/fail findings and recommended next action.

Do not:
Do not modify files. Do not commit. Do not implement fixes. Do not coordinate with other workers unless instructed.

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
[/MASTER_DISPATCH]
