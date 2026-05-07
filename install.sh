#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
usage: install.sh [target-repo]

Installs Pizor templates into a target repository.
If target-repo is omitted, the current directory is used.
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="${PI_PIZOR_TEMPLATE_DIR:-$SCRIPT_DIR/templates}"
TARGET_DIR="$(cd "${1:-$PWD}" && pwd)"
STAMP="$(date +%Y%m%d%H%M%S)"

if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "error: templates directory not found: $TEMPLATE_DIR" >&2
  echo "Run this installer from a cloned pizor repository." >&2
  exit 1
fi

if [ ! -d "$TARGET_DIR/.git" ] && ! git -C "$TARGET_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "error: target does not look like a git repository: $TARGET_DIR" >&2
  exit 1
fi

install_file() {
  local src="$1"
  local dest="$2"
  local mode="$3"

  mkdir -p "$(dirname "$dest")"

  if [ -f "$dest" ] && ! cmp -s "$src" "$dest"; then
    cp "$dest" "$dest.bak.$STAMP"
    echo "backup: ${dest#$TARGET_DIR/}.bak.$STAMP"
  fi

  install -m "$mode" "$src" "$dest"
  echo "installed: ${dest#$TARGET_DIR/}"
}

# AGENTS.md is special: never overwrite a repository's existing instruction file.
if [ -f "$TARGET_DIR/AGENTS.md" ]; then
  install_file "$TEMPLATE_DIR/AGENTS.md" "$TARGET_DIR/AGENTS.pizor.md" 0644
  echo "note: existing AGENTS.md kept; merge AGENTS.pizor.md manually if needed"
else
  install_file "$TEMPLATE_DIR/AGENTS.md" "$TARGET_DIR/AGENTS.md" 0644
fi

# Environment example lives under .pi to avoid clobbering project files.
install_file "$TEMPLATE_DIR/.env.example" "$TARGET_DIR/.pi/.env.example" 0644

# Skills.
while IFS= read -r -d '' src; do
  rel="${src#$TEMPLATE_DIR/}"
  install_file "$src" "$TARGET_DIR/$rel" 0644
done < <(find "$TEMPLATE_DIR/.pi" -type f -print0 | sort -z)

# Scripts.
while IFS= read -r -d '' src; do
  rel="${src#$TEMPLATE_DIR/scripts/}"
  install_file "$src" "$TARGET_DIR/.pi/scripts/$rel" 0755
done < <(find "$TEMPLATE_DIR/scripts" -type f -print0 | sort -z)

# Assignment templates.
if [ -d "$TEMPLATE_DIR/assignments" ]; then
  while IFS= read -r -d '' src; do
    rel="${src#$TEMPLATE_DIR/assignments/}"
    install_file "$src" "$TARGET_DIR/.pi/assignments/$rel" 0644
  done < <(find "$TEMPLATE_DIR/assignments" -type f -print0 | sort -z)
fi

# Local state should not be committed.
GITIGNORE="$TARGET_DIR/.gitignore"
touch "$GITIGNORE"
if ! grep -qxF '# pizor' "$GITIGNORE"; then
  cat >> "$GITIGNORE" <<'EOF'

# pizor
.pizor/
.env
.pi/.env
EOF
  echo "updated: .gitignore"
else
  updated_gitignore=false
  for pattern in '.pizor/' '.env' '.pi/.env'; do
    if ! grep -qxF "$pattern" "$GITIGNORE"; then
      printf '%s\n' "$pattern" >> "$GITIGNORE"
      updated_gitignore=true
    fi
  done
  if [ "$updated_gitignore" = "true" ]; then
    echo "updated: .gitignore"
  fi
fi

cat <<EOF

Done.

Start from inside Zellij:
  .pi/scripts/session-start

Or reload Pi extensions and use:
  /pizor-start

Inspect registry:
  .pi/scripts/registry-list
EOF
