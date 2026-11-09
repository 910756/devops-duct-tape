#!/usr/bin/env bash
# Shared helpers for devops-duct-tape.
# Philosophy: dry-run by default, act only with --apply, and log every patch as tech debt.

APPLY="${APPLY:-0}"
DEBT_FILE="${DUCTTAPE_DEBT_FILE:-./DEBT.md}"

log()  { printf '\033[1;34m[ducttape]\033[0m %s\n' "$*" >&2; }
ok()   { printf '\033[1;32m[ok]\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "'$1' is required but not installed"; }

# run CMD... : execute only when --apply was given, otherwise print what would happen.
run() {
  if [[ "$APPLY" == "1" ]]; then
    log "running: $*"
    "$@"
  else
    log "dry-run (add --apply to execute): $*"
  fi
}

# debt_log TITLE SEVERITY PERMANENT_FIX
# Appends a row to DEBT.md and, if DUCTTAPE_GH_ISSUE=1, opens a GitHub issue.
debt_log() {
  local title="$1" sev="$2" fix="$3" ts
  [[ "$APPLY" == "1" ]] || return 0
  ts="$(date -u +%Y-%m-%dT%H:%MZ)"
  if [[ ! -f "$DEBT_FILE" ]]; then
    {
      printf '# Tech debt log\n\n'
      printf 'Temporary patches applied by devops-duct-tape that still need a permanent fix.\n\n'
      printf '| When (UTC) | Severity | Patch applied | Permanent fix needed |\n'
      printf '|---|---|---|---|\n'
    } > "$DEBT_FILE"
  fi
  printf '| %s | %s | %s | %s |\n' "$ts" "$sev" "${title//|/\\|}" "${fix//|/\\|}" >> "$DEBT_FILE"
  ok "tech debt logged in $DEBT_FILE"
  if [[ "${DUCTTAPE_GH_ISSUE:-0}" == "1" ]]; then
    if command -v gh >/dev/null 2>&1; then
      gh issue create --title "[duct-tape] $title" \
        --body "Severity: $sev"$'\n\n'"Permanent fix needed: $fix" \
        --label tech-debt || warn "could not create GitHub issue (does the 'tech-debt' label exist?)"
    else
      warn "DUCTTAPE_GH_ISSUE=1 but the gh CLI is not installed"
    fi
  fi
}
