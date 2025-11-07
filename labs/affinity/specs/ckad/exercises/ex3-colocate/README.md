# Exercise 3: Co-locate with Cache

## Requirements

Given:
- A redis cache deployment with label `app=cache`

Create an application deployment that:
- Runs on the same nodes as redis pods
- Has 3 replicas

## Expected Outcome

- Application pods run on same nodes as cache pods
- Improves performance by keeping app near its cache
- If cache pods don't exist, app pods remain Pending

## Solution

Apply the files in this directory in order:
1. First deploy the cache (`cache.yaml`)
2. Then deploy the application (`application.yaml`)

## Verification

```bash
# Deploy cache first
kubectl apply -f cache.yaml

# Wait for cache pods to be running
kubectl get pods -l app=cache -o wide

# Deploy application
kubectl apply -f application.yaml

# Verify app pods are co-located with cache pods
kubectl get pods -l app=colocate-demo -o wide
kubectl get pods -l app=cache -o wide

# They should be on the same nodes
```

## Cleanup

```bash
kubectl delete -f application.yaml
kubectl delete -f cache.yaml
```
