#!/usr/bin/env bash
# Re-run a flaky command with exponential backoff, and log it as debt if it needed retries.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"

ATTEMPTS=3; DELAY=5

usage() {
  cat <<'EOF'
Usage: ducttape retry [--attempts N] [--delay S] -- COMMAND [ARGS...]

  --attempts N  Maximum attempts (default: 3)
  --delay S     First wait in seconds, doubled after each failure (default: 5)

Example (in a CI step):
  ducttape retry --attempts 4 -- npm ci
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --attempts) ATTEMPTS="$2"; shift 2 ;;
    --delay) DELAY="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    *) break ;;
  esac
done

[[ $# -gt 0 ]] || { usage; die "no command given"; }

n=1; wait_s="$DELAY"
until "$@"; do
  if (( n >= ATTEMPTS )); then
    die "command failed after $n attempts: $*"
  fi
  warn "attempt $n/$ATTEMPTS failed, retrying in ${wait_s}s: $*"
  sleep "$wait_s"
  n=$((n + 1)); wait_s=$((wait_s * 2))
done

if (( n > 1 )); then
  ok "succeeded on attempt $n"
  APPLY=1 debt_log "Flaky command needed $n attempts: $*" "LOW" \
    "Find out why it is flaky (network, rate limits, race condition) and fix it, or cache the dependency, instead of relying on retries"
else
  ok "succeeded first time"
fi
