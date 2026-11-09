#!/usr/bin/env bash
# Check TLS certificates and flag the ones that expire soon. Read-only.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"

WARN_DAYS=21; PORT=443; DOMAINS=()

usage() {
  cat <<'EOF'
Usage: ducttape cert-expiry [--days N] [--port P] DOMAIN [DOMAIN...]

  --days N   Warn if a cert expires within N days (default: 21)
  --port P   TLS port (default: 443)

Exits 1 if any certificate is expiring or unreachable, so it works in CI and cron.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --days) WARN_DAYS="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) usage; die "unknown option: $1" ;;
    *) DOMAINS+=("$1"); shift ;;
  esac
done

[[ ${#DOMAINS[@]} -gt 0 ]] || { usage; die "give at least one domain"; }
need openssl

FAIL=0
for d in "${DOMAINS[@]}"; do
  CERT="$(openssl s_client -servername "$d" -connect "$d:$PORT" </dev/null 2>/dev/null \
          | openssl x509 2>/dev/null || true)"
  if [[ -z "$CERT" ]]; then
    warn "$d: could not fetch a certificate"; FAIL=1; continue
  fi
  END="$(openssl x509 -noout -enddate <<<"$CERT" | cut -d= -f2)"
  if openssl x509 -noout -checkend $((WARN_DAYS * 86400)) <<<"$CERT" >/dev/null; then
    ok "$d: valid until $END"
  else
    warn "$d: EXPIRES WITHIN $WARN_DAYS DAYS ($END)"; FAIL=1
  fi
done

exit "$FAIL"
