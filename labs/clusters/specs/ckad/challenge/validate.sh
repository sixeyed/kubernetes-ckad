#!/bin/bash

# Challenge Validation Script
# Verifies all requirements are met

echo "=== CKAD Cluster Challenge Validation ==="
echo ""

PASS=0
FAIL=0

check_pass() {
  echo "✅ $1"
  ((PASS++))
}

check_fail() {
  echo "❌ $1"
  ((FAIL++))
}

# Check 1: Database on SSD nodes
echo "Checking database tier..."
DB_NODES=$(kubectl get pods -l tier=database -o jsonpath='{.items[*].spec.nodeName}')
if [ -n "$DB_NODES" ]; then
  SSD_OK=true
  for node in $DB_NODES; do
    DISK=$(kubectl get node $node -o jsonpath='{.metadata.labels.disk}')
    if [ "$DISK" != "ssd" ]; then
      SSD_OK=false
    fi
  done
  if [ "$SSD_OK" = true ]; then
    check_pass "Database Pods on SSD nodes"
  else
    check_fail "Database Pods not all on SSD nodes"
  fi
else
  check_fail "No database Pods found"
fi

# Check 2: Database Pods spread across nodes
DB_COUNT=$(kubectl get pods -l tier=database -o jsonpath='{.items[*].spec.nodeName}' | tr ' ' '\n' | sort -u | wc -l)
DB_REPLICAS=$(kubectl get pods -l tier=database --field-selector=status.phase=Running | grep -c database)
if [ "$DB_COUNT" -eq "$DB_REPLICAS" ] && [ "$DB_COUNT" -gt 0 ]; then
  check_pass "Database Pods spread across different nodes"
else
  check_fail "Database Pods not properly spread"
fi

# Check 3: Cache Pods running
CACHE_COUNT=$(kubectl get pods -l tier=cache --field-selector=status.phase=Running | grep -c cache)
if [ "$CACHE_COUNT" -eq 3 ]; then
  check_pass "Cache tier has 3 running Pods"
else
  check_fail "Cache tier does not have 3 running Pods (found $CACHE_COUNT)"
fi

# Check 4: App Pods running
APP_COUNT=$(kubectl get pods -l tier=app --field-selector=status.phase=Running | grep -c application)
if [ "$APP_COUNT" -eq 5 ]; then
  check_pass "Application tier has 5 running Pods"
else
  check_fail "Application tier does not have 5 running Pods (found $APP_COUNT)"
fi

# Check 5: Monitoring on all nodes
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
MON_COUNT=$(kubectl get pods -l app=monitoring --field-selector=status.phase=Running | grep -c monitoring)
if [ "$MON_COUNT" -eq "$NODE_COUNT" ]; then
  check_pass "Monitoring DaemonSet on all $NODE_COUNT nodes"
else
  check_fail "Monitoring not on all nodes (expected $NODE_COUNT, found $MON_COUNT)"
fi

# Check 6: PodDisruptionBudgets created
PDB_COUNT=$(kubectl get pdb | grep -c pdb)
if [ "$PDB_COUNT" -ge 3 ]; then
  check_pass "PodDisruptionBudgets created"
else
  check_fail "Missing PodDisruptionBudgets (found $PDB_COUNT, expected 3)"
fi

# Check 7: All services exist
SERVICES=("database" "cache" "application")
ALL_SVC_OK=true
for svc in "${SERVICES[@]}"; do
  if ! kubectl get service $svc &>/dev/null; then
    ALL_SVC_OK=false
  fi
done
if [ "$ALL_SVC_OK" = true ]; then
  check_pass "All services created"
else
  check_fail "Some services missing"
fi

# Summary
echo ""
echo "=== Validation Summary ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo "🎉 Challenge completed successfully!"
  exit 0
else
  echo "❌ Some requirements not met. Review the failures above."
  exit 1
fi
