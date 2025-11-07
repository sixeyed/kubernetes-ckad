# Exercise 5: Troubleshoot Pending Pods

## Requirements

Given a broken deployment with pods in pending state:
1. Identify why pods aren't scheduling
2. Fix the affinity rules
3. Verify pods start running

## Scenario

A deployment has been created with overly restrictive affinity rules. Your job is to:
1. Deploy the broken configuration
2. Diagnose the problem
3. Fix it to make pods run

## Solution Steps

### Step 1: Deploy the broken configuration
```bash
kubectl apply -f broken-deployment.yaml
```

### Step 2: Identify the problem
```bash
# Check pod status
kubectl get pods -l app=troubleshoot-demo

# Look at events
kubectl describe pod -l app=troubleshoot-demo

# Check node labels
kubectl get nodes --show-labels
```

### Step 3: Fix the issue

Apply the fixed deployment:
```bash
kubectl apply -f fixed-deployment.yaml
```

Or manually fix by:
```bash
# Option 1: Add the required label to a node
kubectl label node <node-name> disktype=ultra-fast

# Option 2: Edit the deployment to use existing labels
kubectl edit deployment troubleshoot-demo
# Change the affinity rule to use a label that exists
```

## Verification

```bash
# Check all pods are running
kubectl get pods -l app=troubleshoot-demo

# Verify they're on appropriate nodes
kubectl get pods -l app=troubleshoot-demo -o wide
```

## Cleanup

```bash
kubectl delete -f fixed-deployment.yaml
# Or
kubectl delete deployment troubleshoot-demo
```
