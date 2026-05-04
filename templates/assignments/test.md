# Verification Worker Assignment Template

Use this for test/check/lint verification work. This assignment is read-only.

[MASTER_DISPATCH]
from_pane: 1
to_pane: <worker_pane_id>
role: worker
message_type: assignment
task_id: <task_id>
assignment_id: <assignment_id>
status: assigned

Objective:
Run the requested verification commands and report results. Do not edit files.

Scope:
Allowed commands: <commands>. Allowed directories: <directories>. Files modified: none.

Stop condition:
Stop when all verification commands finish, or immediately when a command fails and the failure is captured.

Do not:
Do not modify files. Do not commit. Do not attempt fixes. Do not broaden into implementation.

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
