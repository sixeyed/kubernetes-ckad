# Exercise 4: Zone Spreading

## Requirements

Create a deployment that:
1. Must stay in region `us-west`
2. Prefers spreading across zones
3. Has 6 replicas

## Expected Outcome

- All pods run in us-west region
- Pods spread across multiple zones if available
- If no zone labels exist, pods still run (preferred, not required)

## Note

In a local cluster without region/zone labels, you can simulate this by:
```bash
# Add labels to your nodes
kubectl label node <node1> topology.kubernetes.io/region=us-west
kubectl label node <node1> topology.kubernetes.io/zone=us-west-1a
kubectl label node <node2> topology.kubernetes.io/region=us-west
kubectl label node <node2> topology.kubernetes.io/zone=us-west-1b
```

## Solution

Apply the `deployment.yaml` file in this directory.

## Verification

```bash
# Deploy
kubectl apply -f deployment.yaml

# Check pods and their node placement
kubectl get pods -l app=zone-spread-demo -o wide

# Check node labels
kubectl get nodes -L topology.kubernetes.io/region,topology.kubernetes.io/zone

# Verify distribution
kubectl get pods -l app=zone-spread-demo -o wide | awk '{print $7}' | tail -n +2 | sort | uniq -c
```

## Cleanup

```bash
kubectl delete -f deployment.yaml

# If you added labels, remove them
kubectl label node <node> topology.kubernetes.io/region-
kubectl label node <node> topology.kubernetes.io/zone-
```
