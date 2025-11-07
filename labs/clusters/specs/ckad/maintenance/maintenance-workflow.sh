#!/bin/bash

# Node Maintenance Workflow - CKAD Practice
# Demonstrates cordon, drain, and uncordon operations

echo "=== Node Maintenance Workflow Demo ==="
echo ""

# Get first worker node
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
echo "Target node: $NODE_NAME"
echo ""

# Deploy test application
echo "=== 1. Deploying Test Application ==="
kubectl create deployment test-app --image=nginx:alpine --replicas=3
kubectl wait --for=condition=available --timeout=60s deployment/test-app
kubectl get pods -o wide -l app=test-app
echo ""

# Show current node status
echo "=== 2. Current Node Status ==="
kubectl get nodes
echo ""

# Cordon the node
echo "=== 3. Cordoning Node (prevent new Pods) ==="
kubectl cordon $NODE_NAME
echo "Node $NODE_NAME is now cordoned"
kubectl get nodes
echo ""

# Try to schedule new Pods
echo "=== 4. Testing Scheduling After Cordon ==="
echo "Scaling up deployment..."
kubectl scale deployment test-app --replicas=5
sleep 3
echo "Pod distribution:"
kubectl get pods -o wide -l app=test-app
echo "Notice: New Pods won't schedule on cordoned node"
echo ""

# Check what's running on the node
echo "=== 5. Checking Pods on Target Node ==="
kubectl get pods -o wide --all-namespaces --field-selector spec.nodeName=$NODE_NAME
echo ""

# Drain the node
echo "=== 6. Draining Node (evict all Pods) ==="
echo "Running: kubectl drain $NODE_NAME --ignore-daemonsets --delete-emptydir-data"
kubectl drain $NODE_NAME --ignore-daemonsets --delete-emptydir-data
echo ""

# Verify Pods moved
echo "=== 7. Verifying Pods Rescheduled ==="
echo "Pods on drained node (should only show DaemonSets):"
kubectl get pods -o wide --all-namespaces --field-selector spec.nodeName=$NODE_NAME
echo ""
echo "All test-app Pods (should be on other nodes):"
kubectl get pods -o wide -l app=test-app
echo ""

# Simulate maintenance
echo "=== 8. Simulating Maintenance ==="
echo "Performing maintenance on node..."
sleep 5
echo "Maintenance complete!"
echo ""

# Uncordon the node
echo "=== 9. Uncordoning Node (re-enable scheduling) ==="
kubectl uncordon $NODE_NAME
echo "Node $NODE_NAME is now schedulable again"
kubectl get nodes
echo ""

# Rebalance (optional)
echo "=== 10. Optional: Rebalancing Pods ==="
echo "Pods don't automatically move back. To rebalance:"
echo "kubectl rollout restart deployment/test-app"
read -p "Restart deployment to rebalance? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
  kubectl rollout restart deployment/test-app
  kubectl rollout status deployment/test-app
  echo "Rebalanced pod distribution:"
  kubectl get pods -o wide -l app=test-app
fi
echo ""

# Cleanup
echo "=== 11. Cleanup ==="
kubectl delete deployment test-app
echo ""
echo "Workflow complete!"
echo ""
echo "Summary of commands:"
echo "  kubectl cordon <node>              # Prevent new Pods"
echo "  kubectl drain <node> --ignore-daemonsets  # Evict Pods"
echo "  kubectl uncordon <node>            # Re-enable scheduling"
