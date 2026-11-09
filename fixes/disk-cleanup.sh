#!/usr/bin/env bash
# Free disk space on a CI runner or Docker host.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"

KEEP_HOURS=72; JOURNAL_DAYS=7

usage() {
  cat <<'EOF'
Usage: ducttape disk-cleanup [--keep-hours H] [--journal-days D] [--apply]

  --keep-hours H    Keep Docker images/containers used in the last H hours (default: 72)
  --journal-days D  Keep systemd journal logs from the last D days (default: 7)
  --apply           Actually delete (otherwise dry run)

Cleans: unused Docker images, stopped containers, build cache, old journal logs,
package-manager caches. Never touches application data or volumes.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep-hours) KEEP_HOURS="$2"; shift 2 ;;
    --journal-days) JOURNAL_DAYS="$2"; shift 2 ;;
    --apply) APPLY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage; die "unknown option: $1" ;;
  esac
done

usage_pct() { df -P / | awk 'NR==2{gsub("%","",$5); print $5}'; }

BEFORE="$(usage_pct)"
log "root filesystem is ${BEFORE}% full"
df -h / >&2

if command -v docker >/dev/null 2>&1; then
  log "docker disk usage:"; docker system df >&2 || true
  run docker container prune -f --filter "until=${KEEP_HOURS}h"
  run docker image prune -af --filter "until=${KEEP_HOURS}h"
  run docker builder prune -af --filter "until=${KEEP_HOURS}h"
else
  log "docker not found, skipping"
fi

if command -v journalctl >/dev/null 2>&1; then
  run journalctl --vacuum-time="${JOURNAL_DAYS}d"
fi

if command -v apt-get >/dev/null 2>&1; then run apt-get clean; fi
if command -v yum >/dev/null 2>&1; then run yum clean all; fi

if [[ "$APPLY" == "1" ]]; then
  AFTER="$(usage_pct)"
  ok "disk usage ${BEFORE}% -> ${AFTER}%"
  debt_log "Disk cleanup on $(hostname) (${BEFORE}% -> ${AFTER}%)" "MEDIUM" \
    "Add a disk-usage alert at 80%, schedule docker/image pruning on runners, and set log rotation limits"
fi
