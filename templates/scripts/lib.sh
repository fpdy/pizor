#!/usr/bin/env bash
set -euo pipefail

ORCH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "$ORCH_ROOT/.env" ]; then
  # shellcheck disable=SC1091
  source "$ORCH_ROOT/.env"
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
: "${PI_ORCH_STATE_DIR:=.orchestrator}"
: "${PI_WORKER_BOOT_WAIT:=1}"
: "${PI_WORKER_NAME_PREFIX:=worker}"

ORCH_STATE_DIR="$ORCH_ROOT/$PI_ORCH_STATE_DIR"
REGISTRY_FILE="$ORCH_STATE_DIR/registry.tsv"

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

init_registry() {
  if [ ! -f "$REGISTRY_FILE" ]; then
    printf 'role\tpane_id\ttask_id\tassignment_id\tstatus\tpurpose\tupdated_at\n' > "$REGISTRY_FILE"
  fi
}

registry_add() {
  local role="$1"
  local pane_id="$2"
  local task_id="${3:-}"
  local assignment_id="${4:-}"
  local status="${5:-unknown}"
  local purpose="${6:-}"

  init_registry

  awk -F '\t' -v OFS='\t' -v pane="$pane_id" 'NR==1 || $2 != pane { print }' "$REGISTRY_FILE" > "$REGISTRY_FILE.tmp"
  mv "$REGISTRY_FILE.tmp" "$REGISTRY_FILE"

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$role" "$pane_id" "$task_id" "$assignment_id" "$status" "$purpose" "$(now_iso)" \
    >> "$REGISTRY_FILE"
}

registry_update_status() {
  local pane_id="$1"
  local status="$2"

  init_registry

  awk -F '\t' -v OFS='\t' -v pane="$pane_id" -v status="$status" -v ts="$(now_iso)" '
    NR == 1 { print; next }
    $2 == pane { $5 = status; $7 = ts }
    { print }
  ' "$REGISTRY_FILE" > "$REGISTRY_FILE.tmp"

  mv "$REGISTRY_FILE.tmp" "$REGISTRY_FILE"
}

registry_get_role_pane() {
  local role="$1"

  init_registry

  awk -F '\t' -v role="$role" 'NR > 1 && $1 == role { print $2; exit }' "$REGISTRY_FILE"
}

die() {
  echo "error: $*" >&2
  exit 1
}
