#!/bin/bash

# Taints and Tolerations Examples - CKAD Practice
# This script demonstrates various taint operations

echo "=== Current Node Taints ==="
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

echo ""
echo "=== Adding NoSchedule Taint ==="
# Taint prevents new Pods from being scheduled (existing Pods unaffected)
kubectl taint node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') dedicated=gpu:NoSchedule
echo "Tainted node with dedicated=gpu:NoSchedule"

echo ""
echo "=== Adding PreferNoSchedule Taint ==="
# Soft constraint - scheduler tries to avoid but not required
if [ $(kubectl get nodes --no-headers | wc -l) -gt 1 ]; then
  kubectl taint node $(kubectl get nodes -o jsonpath='{.items[1].metadata.name}') workload=batch:PreferNoSchedule
  echo "Tainted node with workload=batch:PreferNoSchedule"
fi

echo ""
echo "=== View Updated Taints ==="
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

echo ""
echo "=== Deploy Pod without Toleration ==="
kubectl run no-toleration --image=nginx --restart=Never
sleep 2
kubectl get pod no-toleration
echo "Check if Pod is Pending due to taints"

echo ""
echo "=== Deploy Pod with Matching Toleration ==="
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: with-toleration
spec:
  tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "gpu"
    effect: "NoSchedule"
  containers:
  - name: nginx
    image: nginx
EOF

sleep 2
kubectl get pods -o wide

echo ""
echo "=== Testing NoExecute Taint (evicts existing Pods) ==="
echo "First, let's deploy a Pod on all nodes"
kubectl run test-eviction --image=nginx --restart=Never
sleep 3

echo "Now applying NoExecute taint..."
kubectl taint node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') maintenance=true:NoExecute
echo "The test-eviction Pod should be evicted from the tainted node"

sleep 2
kubectl get pod test-eviction

echo ""
echo "=== Removing Taints ==="
echo "Remove taint with minus sign at the end"
kubectl taint node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') dedicated=gpu:NoSchedule-
kubectl taint node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') maintenance=true:NoExecute-

if [ $(kubectl get nodes --no-headers | wc -l) -gt 1 ]; then
  kubectl taint node $(kubectl get nodes -o jsonpath='{.items[1].metadata.name}') workload=batch:PreferNoSchedule-
fi

echo ""
echo "=== Final Node Taints ==="
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

echo ""
echo "=== Cleanup Test Pods ==="
kubectl delete pod no-toleration with-toleration test-eviction --ignore-not-found=true

echo ""
echo "Script complete!"
echo "Remember: Taints repel Pods unless they have matching tolerations"
