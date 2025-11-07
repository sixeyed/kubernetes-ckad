#!/bin/bash

# Node Labeling Script - CKAD Practice
# This script demonstrates various node labeling operations

echo "=== Current Node Labels ==="
kubectl get nodes --show-labels

echo ""
echo "=== Adding Environment Labels ==="
# Label first node as production
kubectl label node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') environment=production

# Label second node as staging (if exists)
if [ $(kubectl get nodes --no-headers | wc -l) -gt 1 ]; then
  kubectl label node $(kubectl get nodes -o jsonpath='{.items[1].metadata.name}') environment=staging
fi

echo ""
echo "=== Adding Hardware Characteristic Labels ==="
# Label nodes with disk types
kubectl label node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') disk=ssd

if [ $(kubectl get nodes --no-headers | wc -l) -gt 1 ]; then
  kubectl label node $(kubectl get nodes -o jsonpath='{.items[1].metadata.name}') disk=hdd
fi

echo ""
echo "=== Adding Workload Type Labels ==="
# Label nodes for specific workload types
kubectl label node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') workload=compute-intensive

if [ $(kubectl get nodes --no-headers | wc -l) -gt 1 ]; then
  kubectl label node $(kubectl get nodes -o jsonpath='{.items[1].metadata.name}') workload=memory-intensive
fi

echo ""
echo "=== Updated Node Labels ==="
kubectl get nodes --show-labels

echo ""
echo "=== Query Nodes by Label Selector ==="
echo "Production nodes:"
kubectl get nodes -l environment=production

echo ""
echo "SSD nodes:"
kubectl get nodes -l disk=ssd

echo ""
echo "=== View Specific Labels Only ==="
kubectl get nodes -o custom-columns=NAME:.metadata.name,ENVIRONMENT:.metadata.labels.environment,DISK:.metadata.labels.disk,WORKLOAD:.metadata.labels.workload

echo ""
echo "=== Updating a Label (requires --overwrite) ==="
kubectl label node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') environment=development --overwrite
kubectl get nodes -l environment=development

echo ""
echo "=== Removing a Label ==="
kubectl label node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') workload-
kubectl get nodes --show-labels

echo ""
echo "Script complete. Check node labels with: kubectl get nodes --show-labels"
