#!/usr/bin/env bash
set -euo pipefail

input=$(cat)

export PATH="/home/raykao/.local/bin:$PATH"
export BEADS_DIR="/home/raykao/.copilot-bridge/workspaces/geordi/.beads"
export BEADS_ACTOR="geordi"

HANDOFF_FILE="/home/raykao/.copilot-bridge/workspaces/geordi/.handoff-state.md"

if command -v bd &>/dev/null; then
  HANDOFF=$(bd memories session-handoff 2>/dev/null || true)
  if [ -n "$HANDOFF" ]; then
    {
      echo "# Session Handoff State"
      echo ""
      echo "Written by sessionEnd hook at $(date -u +%Y-%m-%dT%H:%M:%S)Z"
      echo ""
      echo "## Latest Handoff Memories"
      echo ""
      echo "$HANDOFF"
    } > "$HANDOFF_FILE"
  fi
fi

if command -v bd &>/dev/null; then
  bd backup export-git >/dev/null 2>&1 || true
fi

echo '{}'
