#!/usr/bin/env bash
# Diagnose CrashLoopBackOff pods and optionally roll back the owning deployment.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"

NS="default"; DEPLOY=""; ROLLBACK=0; LINES=30

usage() {
  cat <<'EOF'
Usage: ducttape k8s-crashloop [-n NAMESPACE] [-d DEPLOYMENT] [--rollback] [--apply]

  -n, --namespace   Namespace to inspect (default: default)
  -d, --deployment  Deployment to roll back (required with --rollback)
      --rollback    Roll the deployment back to its previous revision
      --lines N     Log lines to show per pod (default: 30)
      --apply       Actually perform the rollback (otherwise dry run)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace) NS="$2"; shift 2 ;;
    -d|--deployment) DEPLOY="$2"; shift 2 ;;
    --rollback) ROLLBACK=1; shift ;;
    --lines) LINES="$2"; shift 2 ;;
    --apply) APPLY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage; die "unknown option: $1" ;;
  esac
done

need kubectl

log "looking for CrashLoopBackOff pods in namespace '$NS'"
PODS=()
while IFS= read -r p; do [[ -n "$p" ]] && PODS+=("$p"); done \
  < <(kubectl get pods -n "$NS" --no-headers 2>/dev/null | awk '$3=="CrashLoopBackOff"{print $1}')

if [[ ${#PODS[@]} -eq 0 ]]; then
  ok "no crashlooping pods in '$NS'"
else
  for pod in "${PODS[@]}"; do
    warn "pod $pod is in CrashLoopBackOff"
    printf '\n--- last %s log lines from the crashed container (%s) ---\n' "$LINES" "$pod"
    kubectl logs "$pod" -n "$NS" --previous --tail="$LINES" --all-containers 2>&1 || true
    printf '\n--- recent events for %s ---\n' "$pod"
    kubectl get events -n "$NS" --field-selector "involvedObject.name=$pod" \
      --sort-by=.lastTimestamp 2>/dev/null | tail -n 10 || true
    printf '\n--- exit reason ---\n'
    kubectl get pod "$pod" -n "$NS" \
      -o jsonpath='{range .status.containerStatuses[*]}{.name}: {.lastState.terminated.reason} (exit {.lastState.terminated.exitCode}){"\n"}{end}' || true
    echo
  done
fi

if [[ "$ROLLBACK" == "1" ]]; then
  [[ -n "$DEPLOY" ]] || die "--rollback needs -d DEPLOYMENT"
  log "rollout history for deployment/$DEPLOY:"
  kubectl rollout history "deployment/$DEPLOY" -n "$NS" || die "deployment/$DEPLOY not found in '$NS'"
  run kubectl rollout undo "deployment/$DEPLOY" -n "$NS"
  if [[ "$APPLY" == "1" ]]; then
    kubectl rollout status "deployment/$DEPLOY" -n "$NS" --timeout=180s && ok "rollback of $DEPLOY is healthy"
    debt_log "Rolled back deployment/$DEPLOY in $NS after CrashLoopBackOff" "HIGH" \
      "Find the root cause in the failing release (logs above), fix it, add a readiness probe and a pre-deploy smoke test, then redeploy"
  fi
fi
