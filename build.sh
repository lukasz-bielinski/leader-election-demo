#!/bin/bash
# Leader Election Demo - portable kubectl script
set -euo pipefail

NAMESPACE="leader-election-go"
LEASE_NAME="${LEASE_NAME:-my-custom-lease}"

case "${1:-help}" in
  deploy)
    echo "Deploying..."
    kubectl apply -f manifests.yaml
    kubectl rollout status deployment/leader-election-go -n "$NAMESPACE" --timeout=120s
    ;;
  
  status)
    echo "=== Lease ==="
    kubectl get lease "$LEASE_NAME" -n "$NAMESPACE" -o wide 2>/dev/null || echo "No lease yet"
    echo ""
    echo "=== Pods ==="
    kubectl get pods -n "$NAMESPACE" -l app=leader-election-go
    echo ""
    echo "=== Pending files ==="
    POD=$(kubectl get pods -n "$NAMESPACE" -l app=leader-election-go -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    kubectl exec -n "$NAMESPACE" "$POD" -- ls -la /data/pending 2>/dev/null || echo "No pending files"
    echo ""
    echo "=== Done files ==="
    kubectl exec -n "$NAMESPACE" "$POD" -- ls -la /data/done 2>/dev/null || echo "No done files"
    ;;
  
  watch)
    watch -n2 "kubectl get lease $LEASE_NAME -n $NAMESPACE -o wide 2>/dev/null; echo; kubectl get pods -n $NAMESPACE -l app=leader-election-go"
    ;;
  
  logs)
    kubectl logs -n "$NAMESPACE" -l app=leader-election-go -f --prefix
    ;;
  
  failover)
    LEADER=$(kubectl get lease "$LEASE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.holderIdentity}' 2>/dev/null)
    if [[ -n "$LEADER" ]]; then
      echo "Killing leader: $LEADER"
      kubectl delete pod -n "$NAMESPACE" "$LEADER" --force --grace-period=0
    else
      echo "No leader found"
    fi
    ;;
  
  generate)
    COUNT=${2:-5}
    POD=$(kubectl get pods -n "$NAMESPACE" -l app=leader-election-go -o jsonpath='{.items[0].metadata.name}')
    echo "Generating $COUNT test files..."
    for i in $(seq 1 $COUNT); do
      FILE="task-$(date +%s)-$i.txt"
      kubectl exec -n "$NAMESPACE" "$POD" -- sh -c "echo 'Task $i - $(date)' > /data/pending/$FILE"
      echo "  Created: $FILE"
      sleep 0.5
    done
    echo "Done! Watch logs to see leader processing files."
    ;;
  
  show)
    POD=$(kubectl get pods -n "$NAMESPACE" -l app=leader-election-go -o jsonpath='{.items[0].metadata.name}')
    echo "=== Processed files ==="
    for f in $(kubectl exec -n "$NAMESPACE" "$POD" -- ls /data/done 2>/dev/null); do
      echo "--- $f ---"
      kubectl exec -n "$NAMESPACE" "$POD" -- cat "/data/done/$f"
      echo ""
    done
    ;;
  
  cleanup)
    kubectl delete namespace "$NAMESPACE" --ignore-not-found
    ;;
  
  *)
    cat <<EOF
Usage: $0 <command>

Commands:
  deploy    - Deploy to cluster
  status    - Show lease, pods, and files
  watch     - Live watch of lease and pods
  logs      - Follow logs from all pods
  failover  - Kill current leader
  generate  - Create test files (default: 5)
  show      - Show processed files content
  cleanup   - Remove everything

Demo flow:
  1. ./build.sh deploy
  2. ./build.sh logs        # Watch in terminal 1
  3. ./build.sh generate 10 # Add files in terminal 2
  4. ./build.sh failover    # Kill leader, see failover
  5. ./build.sh show        # See who processed files
EOF
    ;;
esac
