# Exercise 1: Basic Node Affinity

## Requirements

Create a deployment that:
1. Must run on Linux nodes
2. Prefers nodes with `disktype=ssd` label
3. Has 3 replicas

## Expected Outcome

- All 3 pods running on Linux nodes
- If SSD nodes exist, pods prefer those nodes
- If no SSD nodes, pods still run on regular nodes

## Solution

Apply the `deployment.yaml` file in this directory.

## Verification

```bash
# Deploy
kubectl apply -f deployment.yaml

# Check pods are running
kubectl get pods -l app=node-affinity-demo -o wide

# Verify node affinity
kubectl get deployment node-affinity-demo -o yaml | grep -A 20 affinity
```

## Cleanup

```bash
kubectl delete -f deployment.yaml
```
