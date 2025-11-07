# Exercise 2: Pod Anti-Affinity for HA

## Requirements

Create a deployment that:
1. Runs 5 replicas
2. Each replica must run on a different node
3. If fewer than 5 nodes, some pods should stay pending

## Expected Outcome

- Each pod runs on a different node
- If cluster has fewer than 5 nodes, excess pods remain Pending
- This ensures high availability by spreading replicas

## Solution

Apply the `deployment.yaml` file in this directory.

## Verification

```bash
# Deploy
kubectl apply -f deployment.yaml

# Check pods distribution across nodes
kubectl get pods -l app=anti-affinity-demo -o wide

# Count how many nodes have pods
kubectl get pods -l app=anti-affinity-demo -o wide | awk '{print $7}' | tail -n +2 | sort | uniq -c

# Check if any pods are pending (if fewer than 5 nodes)
kubectl get pods -l app=anti-affinity-demo
```

## Cleanup

```bash
kubectl delete -f deployment.yaml
```
