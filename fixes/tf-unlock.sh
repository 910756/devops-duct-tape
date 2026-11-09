#!/usr/bin/env bash
# Find and release a stale Terraform state lock.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"

DIR="."; LOCK_ID=""

usage() {
  cat <<'EOF'
Usage: ducttape tf-unlock [-C DIR] [--lock-id ID] [--apply]

  -C, --dir      Terraform working directory (default: current directory)
      --lock-id  Lock ID to release (detected automatically if omitted)
      --apply    Actually release the lock (otherwise dry run)

Only release a lock when you are sure no other plan/apply is still running.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -C|--dir) DIR="$2"; shift 2 ;;
    --lock-id) LOCK_ID="$2"; shift 2 ;;
    --apply) APPLY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage; die "unknown option: $1" ;;
  esac
done

need terraform
[[ -d "$DIR" ]] || die "directory not found: $DIR"

if [[ -z "$LOCK_ID" ]]; then
  log "probing for a state lock in $DIR (read-only plan, 5s lock timeout)"
  OUT="$(terraform -chdir="$DIR" plan -input=false -lock-timeout=5s -refresh=false 2>&1 || true)"
  if ! grep -q "Error acquiring the state lock" <<<"$OUT"; then
    ok "no stale lock detected, state is free"
    exit 0
  fi
  LOCK_ID="$(awk '/^[[:space:]]*ID:/{print $2; exit}' <<<"$OUT")"
  [[ -n "$LOCK_ID" ]] || die "state is locked but the lock ID could not be parsed; pass --lock-id"
  printf '\n--- lock info ---\n'
  awk '/Lock Info:/{f=1} f&&NF{print} /Created:/{if(f) exit}' <<<"$OUT"
  echo
fi

warn "releasing lock $LOCK_ID. Make sure no pipeline or teammate is mid-apply."
run terraform -chdir="$DIR" force-unlock -force "$LOCK_ID"
if [[ "$APPLY" == "1" ]]; then
  ok "lock $LOCK_ID released"
  debt_log "Force-unlocked Terraform state ($DIR, lock $LOCK_ID)" "MEDIUM" \
    "Find why the run died while holding the lock (killed CI job, timeout), add pipeline concurrency limits and run Terraform from one place only"
fi
