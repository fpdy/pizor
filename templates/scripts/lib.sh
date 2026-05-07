#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_ORCH_HOME="$(cd "$SCRIPT_DIR/.." && pwd)"
ORCH_ROOT="$(cd "$PI_ORCH_HOME/.." && pwd)"

if [ -f "$PI_ORCH_HOME/.env" ]; then
  # shellcheck disable=SC1091
  source "$PI_ORCH_HOME/.env"
fi

if [ -z "${PI_ORCH_SESSION:-}" ]; then
  if [ -z "${ZELLIJ_SESSION_NAME:-}" ]; then
    echo "error: PI_ORCH_SESSION is unset and ZELLIJ_SESSION_NAME is unavailable; run these scripts from inside Zellij" >&2
    exit 1
  fi
  PI_ORCH_SESSION="$ZELLIJ_SESSION_NAME"
fi

: "${PI_CMD:=pi}"
: "${ZELLIJ_SEND_KEYS_PLUGIN:=$HOME/.config/zellij/plugins/zellij-send-keys.wasm}"
: "${PI_WORKDIR:=$ORCH_ROOT}"
: "${PI_ORCH_STATE_DIR:=.pizor}"
: "${PI_WORKER_NAME_PREFIX:=worker}"
: "${PI_MAX_PARALLEL_WORKERS:=4}"
: "${PI_MAX_PARALLEL_WRITERS:=1}"
: "${PI_REPORT_DIR:=reports}"

ORCH_STATE_DIR="$ORCH_ROOT/$PI_ORCH_STATE_DIR"
REGISTRY_FILE="$ORCH_STATE_DIR/registry.tsv"
REPORT_DIR="$ORCH_STATE_DIR/$PI_REPORT_DIR"

mkdir -p "$ORCH_STATE_DIR"

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "missing required command: $cmd" >&2
    exit 1
  fi
}

require_base_tools() {
  require_cmd zellij
  require_cmd jq
}

bounded_sleep_seconds() {
  local raw="${1:-}"
  local default_value="${2:-2}"
  local max_value="${3:-10}"

  if ! [[ "$default_value" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    default_value=2
  fi
  if ! [[ "$max_value" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    max_value=10
  fi
  if ! [[ "$raw" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    printf '%s\n' "$default_value"
    return
  fi

  awk -v value="$raw" -v max="$max_value" 'BEGIN {
    if (value > max) value = max
    printf "%g\n", value
  }'
}

worker_startup_prompt_delay_seconds() {
  bounded_sleep_seconds "${PI_WORKER_STARTUP_PROMPT_DELAY_SECONDS:-}" 2 "${PI_WORKER_STARTUP_PROMPT_DELAY_MAX_SECONDS:-10}"
}

json_string() {
  jq -Rn --arg s "$1" '$s'
}

pane_numeric_id() {
  local pane_id="$1"
  pane_id="${pane_id#terminal_}"
  pane_id="${pane_id#pane_}"
  printf '%s\n' "$pane_id"
}

now_iso() {
  date -Iseconds
}

registry_header() {
  printf 'role\tpane_id\ttask_id\tassignment_id\tstatus\tpurpose\tphase\tscope\tdepends_on\tspawned_at\tlast_seen_at\treport_captured\tcleanup_required\tupdated_at\n'
}

init_registry() {
  if [ ! -f "$REGISTRY_FILE" ]; then
    registry_header > "$REGISTRY_FILE"
  fi

  # Migrate the original 7-column registry in-place. Keep this lightweight so
  # upgraded installations do not lose active pane state.
  local first_line
  first_line="$(head -n 1 "$REGISTRY_FILE")"
  if [ "$first_line" = $'role\tpane_id\ttask_id\tassignment_id\tstatus\tpurpose\tupdated_at' ]; then
    local tmp="$REGISTRY_FILE.tmp"
    registry_header > "$tmp"
    awk -F '\t' -v OFS='\t' 'NR > 1 {
      updated_at=$7
      print $1,$2,$3,$4,$5,$6,"","","",updated_at,updated_at,"no","no",updated_at
    }' "$REGISTRY_FILE" >> "$tmp"
    mv "$tmp" "$REGISTRY_FILE"
  fi
}

registry_add() {
  local role="$1"
  local pane_id="$2"
  local task_id="${3:-}"
  local assignment_id="${4:-}"
  local status="${5:-unknown}"
  local purpose="${6:-}"
  local phase="${7:-}"
  local scope="${8:-}"
  local depends_on="${9:-}"
  local ts
  ts="$(now_iso)"

  init_registry

  awk -F '\t' -v OFS='\t' -v pane="$pane_id" 'NR==1 || $2 != pane { print }' "$REGISTRY_FILE" > "$REGISTRY_FILE.tmp"
  mv "$REGISTRY_FILE.tmp" "$REGISTRY_FILE"

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$role" "$pane_id" "$task_id" "$assignment_id" "$status" "$purpose" \
    "$phase" "$scope" "$depends_on" "$ts" "$ts" "no" "no" "$ts" \
    >> "$REGISTRY_FILE"
}

registry_update_status() {
  local pane_id="$1"
  local status="$2"
  local ts
  ts="$(now_iso)"

  init_registry

  awk -F '\t' -v OFS='\t' -v pane="$pane_id" -v status="$status" -v ts="$ts" '
    NR == 1 { print; next }
    $2 == pane { $5 = status; $11 = ts; $14 = ts }
    { print }
  ' "$REGISTRY_FILE" > "$REGISTRY_FILE.tmp"

  mv "$REGISTRY_FILE.tmp" "$REGISTRY_FILE"
}

registry_update_worker_report() {
  local pane_id="$1"
  local status="$2"
  local cleanup_required="${3:-yes}"
  local report_captured="${4:-no}"
  local ts
  ts="$(now_iso)"

  init_registry

  awk -F '\t' -v OFS='\t' -v pane="$pane_id" -v status="$status" -v cleanup="$cleanup_required" -v captured="$report_captured" -v ts="$ts" '
    NR == 1 { print; next }
    $2 == pane { $5 = status; $11 = ts; $12 = captured; $13 = cleanup; $14 = ts }
    { print }
  ' "$REGISTRY_FILE" > "$REGISTRY_FILE.tmp"

  mv "$REGISTRY_FILE.tmp" "$REGISTRY_FILE"
}

registry_mark_report_captured() {
  local pane_id="$1"
  local ts
  ts="$(now_iso)"

  init_registry

  awk -F '\t' -v OFS='\t' -v pane="$pane_id" -v ts="$ts" '
    NR == 1 { print; next }
    $2 == pane { $12 = "yes"; $13 = "no"; $14 = ts }
    { print }
  ' "$REGISTRY_FILE" > "$REGISTRY_FILE.tmp"

  mv "$REGISTRY_FILE.tmp" "$REGISTRY_FILE"
}

registry_get_role_pane() {
  local role="$1"

  init_registry

  # Prefer the newest non-closed pane for this role. The registry is append-like
  # across orchestration sessions, so returning the first historical role entry
  # can route messages to stale panes or the user/main thread.
  awk -F '\t' -v role="$role" '
    NR > 1 && $1 == role && $5 != "closed" && $5 != "closing" { pane = $2 }
    END { if (pane != "") print pane }
  ' "$REGISTRY_FILE"
}

report_path_for() {
  local task_id="$1"
  local assignment_id="$2"
  local pane_id="$3"
  printf '%s/%s/%s.%s.md\n' "$REPORT_DIR" "$task_id" "$assignment_id" "$pane_id"
}

report_pointer_for() {
  local task_id="$1"
  local assignment_id="$2"
  local pane_id="$3"
  local report_path
  report_path="$(report_path_for "$task_id" "$assignment_id" "$pane_id")"
  printf '%s\n' "${report_path#$ORCH_ROOT/}"
}

find_report_pointer() {
  local task_id="$1"
  local assignment_id="$2"
  local pane_id="$3"
  local report_path
  report_path="$(report_path_for "$task_id" "$assignment_id" "$pane_id")"
  [ -f "$report_path" ] && printf '%s\n' "${report_path#$ORCH_ROOT/}"
}

die() {
  echo "error: $*" >&2
  exit 1
}
