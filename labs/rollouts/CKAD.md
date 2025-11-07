# Rollouts and Deployment Strategies for CKAD

This document extends the [basic rollouts lab](README.md) with CKAD exam-specific scenarios and deployment strategies.

## CKAD Exam Context

Deployment strategies and rollouts are **critical** for CKAD. You need to:
- Perform rolling updates to deployments
- Roll back failed deployments
- Understand rollout history and revisions
- Configure rollout strategies (maxSurge, maxUnavailable)
- Pause and resume rollouts
- Check rollout status
- Understand blue/green and canary deployment patterns

**Exam Weight**: 20% (Application Deployment domain)
**Time Target**: 4-6 minutes per rollout question

**Exam Tip:** Rolling updates are one of the most common deployment tasks. Practice until you can update, check status, and rollback in under 5 minutes.

## Understanding Deployment Rollouts

When you update a Deployment's Pod template, Kubernetes performs a rolling update:

1. Creates new ReplicaSet with updated Pod template
2. Scales up new ReplicaSet
3. Scales down old ReplicaSet
4. Repeats until all Pods are updated

### Key Rollout Commands

```bash
# Trigger a rollout by updating image
kubectl set image deployment/<name> <container>=<new-image>

# Check rollout status
kubectl rollout status deployment/<name>

# View rollout history
kubectl rollout history deployment/<name>

# Pause a rollout
kubectl rollout pause deployment/<name>

# Resume a paused rollout
kubectl rollout resume deployment/<name>

# Rollback to previous version
kubectl rollout undo deployment/<name>

# Rollback to specific revision
kubectl rollout undo deployment/<name> --to-revision=<number>

# Restart deployment (recreate pods)
kubectl rollout restart deployment/<name>
```

## Exercise 1: Basic Rolling Update

**Task**: Deploy an application, update it to a new version, and verify the rollout.

<details>
  <summary>Step-by-Step Solution</summary>

```bash
# Step 1: Create initial deployment
kubectl create deployment web --image=nginx:1.20 --replicas=3

# Verify deployment
kubectl get deployment web
kubectl get pods -l app=web

# Step 2: Update to new image version
kubectl set image deployment/web nginx=nginx:1.21

# Step 3: Watch the rollout
kubectl rollout status deployment/web

# Or watch pods update
kubectl get pods -l app=web -w

# Step 4: Verify new version
kubectl describe deployment web | grep Image
# Should show nginx:1.21

# Step 5: Check rollout history
kubectl rollout history deployment/web

# Shows:
# REVISION  CHANGE-CAUSE
# 1         <none>
# 2         <none>

# Step 6: Verify all pods updated
kubectl get pods -l app=web -o jsonpath='{.items[*].spec.containers[*].image}'
# All should show nginx:1.21
```

**Expected Outcome:**
- Old pods (nginx:1.20) gradually replaced
- New pods (nginx:1.21) created
- Zero downtime during update
- Rollout history shows 2 revisions

</details><br />

## Exercise 2: Rollback a Deployment

**Task**: Update a deployment to a broken image, then roll back to the working version.

<details>
  <summary>Step-by-Step Solution</summary>

```bash
# Step 1: Create deployment with working image
kubectl create deployment app --image=nginx:1.20 --replicas=3

# Step 2: Update to broken image
kubectl set image deployment/app nginx=nginx:broken-tag

# Step 3: Check rollout status
kubectl rollout status deployment/app
# May hang or show error

# Check pods
kubectl get pods -l app=app
# Shows ImagePullBackOff or ErrImagePull

# Step 4: Check history
kubectl rollout history deployment/app

# Shows:
# REVISION  CHANGE-CAUSE
# 1         <none>
# 2         <none>

# Step 5: Rollback to previous version
kubectl rollout undo deployment/app

# Step 6: Verify rollback
kubectl rollout status deployment/app
# Should show successful rollout

kubectl get pods -l app=app
# All pods running with nginx:1.20

# Step 7: Verify in history
kubectl rollout history deployment/app

# Shows:
# REVISION  CHANGE-CAUSE
# 2         <none>
# 3         <none>  (this is the rollback to revision 1)
```

**Key Learning:** Rollback creates a new revision that's a copy of the target revision.

</details><br />

## Rollout Strategy Configuration

Control how rollouts happen with `maxSurge` and `maxUnavailable`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2          # Max pods above desired count
      maxUnavailable: 1    # Max pods below desired count
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.20
```

### Understanding maxSurge and maxUnavailable

| Config | maxSurge | maxUnavailable | Behavior |
|--------|----------|----------------|----------|
| **Fast** | 100% | 0 | Create all new pods first, then remove old |
| **Balanced** | 25% | 25% | Gradual replacement (default) |
| **Slow/Safe** | 1 | 0 | Update one pod at a time |
| **Recreate** | N/A | 100% | Delete all, then create new (downtime!) |

### CKAD Scenarios

**Fast Rollout** (when you have spare capacity):
```yaml
maxSurge: 100%
maxUnavailable: 0
```
Creates all new pods immediately, then removes old pods.

**Slow/Safe Rollout** (for critical apps):
```yaml
maxSurge: 1
maxUnavailable: 0
```
Updates one pod at a time, ensures availability.

**Resource-Constrained** (limited cluster capacity):
```yaml
maxSurge: 0
maxUnavailable: 1
```
Terminates old pod first, then creates replacement.

## Exercise 3: Configure Rollout Strategy

**Task**: Create a deployment with a custom rollout strategy that updates 2 pods at a time.

<details>
  <summary>Step-by-Step Solution</summary>

```bash
# Step 1: Create deployment YAML with custom strategy
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: custom-rollout
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2
      maxUnavailable: 0
  selector:
    matchLabels:
      app: custom
  template:
    metadata:
      labels:
        app: custom
    spec:
      containers:
      - name: nginx
        image: nginx:1.20
EOF

# Step 2: Wait for deployment to be ready
kubectl rollout status deployment/custom-rollout

# Step 3: Update image and watch rollout
kubectl set image deployment/custom-rollout nginx=nginx:1.21

# In another terminal, watch pods
kubectl get pods -l app=custom -w

# Observe: Max 12 pods (10 desired + 2 surge), never below 10

# Step 4: Check final state
kubectl get deployment custom-rollout
kubectl get pods -l app=custom

# Cleanup
kubectl delete deployment custom-rollout
```

**Expected Behavior:**
- During rollout, up to 12 pods exist (10 + maxSurge=2)
- Never fewer than 10 pods running (maxUnavailable=0)
- Rollout happens in waves of 2 new pods

</details><br />

## Rollout History and Change Tracking

### Recording Changes

Use `--record` (deprecated but useful for learning) or annotations to track changes:

```bash
# Method 1: Using kubectl set image (automatic)
kubectl set image deployment/web nginx=nginx:1.21

# Method 2: Edit deployment
kubectl edit deployment web

# Method 3: Apply with annotation
kubectl annotate deployment web kubernetes.io/change-cause="Update to nginx 1.21"
kubectl set image deployment/web nginx=nginx:1.21
```

### Viewing History

```bash
# Basic history
kubectl rollout history deployment/web

# Detailed history for specific revision
kubectl rollout history deployment/web --revision=2

# Shows full deployment spec for that revision
```

### Rolling Back to Specific Revision

```bash
# List revisions
kubectl rollout history deployment/web

# Rollback to revision 3
kubectl rollout undo deployment/web --to-revision=3

# Verify
kubectl rollout history deployment/web
```

## Exercise 4: Rollout History Management

**Task**: Deploy an app, update it twice, then roll back to the first version.

<details>
  <summary>Step-by-Step Solution</summary>

```bash
# Step 1: Create initial deployment
kubectl create deployment history-demo --image=nginx:1.19 --replicas=3

# Annotate to track change
kubectl annotate deployment history-demo kubernetes.io/change-cause="Initial deployment with nginx:1.19"

# Step 2: First update
kubectl set image deployment/history-demo nginx=nginx:1.20
kubectl annotate deployment history-demo kubernetes.io/change-cause="Update to nginx:1.20"

# Wait for rollout
kubectl rollout status deployment/history-demo

# Step 3: Second update
kubectl set image deployment/history-demo nginx=nginx:1.21
kubectl annotate deployment history-demo kubernetes.io/change-cause="Update to nginx:1.21"

# Wait for rollout
kubectl rollout status deployment/history-demo

# Step 4: Check history
kubectl rollout history deployment/history-demo

# Shows:
# REVISION  CHANGE-CAUSE
# 1         Initial deployment with nginx:1.19
# 2         Update to nginx:1.20
# 3         Update to nginx:1.21

# Step 5: View specific revision details
kubectl rollout history deployment/history-demo --revision=1

# Step 6: Rollback to first version
kubectl rollout undo deployment/history-demo --to-revision=1

# Step 7: Verify rollback
kubectl describe deployment history-demo | grep Image
# Shows: nginx:1.19

kubectl rollout history deployment/history-demo
# New revision 4 created (copy of revision 1)

# Cleanup
kubectl delete deployment history-demo
```

</details><br />

## Pausing and Resuming Rollouts

Pause a rollout to make multiple changes before continuing:

```bash
# Pause rollout
kubectl rollout pause deployment/web

# Make multiple changes
kubectl set image deployment/web nginx=nginx:1.21
kubectl set resources deployment/web -c nginx --limits=cpu=200m,memory=256Mi

# Resume rollout (all changes applied together)
kubectl rollout resume deployment/web
```

**Use Case:** When you need to update multiple fields (image, resources, env vars) and want one atomic rollout instead of multiple sequential rollouts.

## Exercise 5: Pause and Resume

**Task**: Pause a deployment, make multiple changes, then resume and verify one rollout occurs.

<details>
  <summary>Step-by-Step Solution</summary>

```bash
# Step 1: Create deployment
kubectl create deployment pause-demo --image=nginx:1.20 --replicas=3

# Step 2: Check initial history
kubectl rollout history deployment/pause-demo
# Shows revision 1

# Step 3: Pause the deployment
kubectl rollout pause deployment/pause-demo

# Step 4: Make multiple changes
kubectl set image deployment/pause-demo nginx=nginx:1.21
kubectl set env deployment/pause-demo APP_VERSION=2.0
kubectl scale deployment pause-demo --replicas=5

# Step 5: Verify no rollout happened yet
kubectl rollout history deployment/pause-demo
# Still shows only revision 1

kubectl get pods -l app=pause-demo
# Still 3 pods with old image

# Step 6: Resume rollout
kubectl rollout resume deployment/pause-demo

# Step 7: Watch single rollout with all changes
kubectl rollout status deployment/pause-demo

# Step 8: Verify all changes applied
kubectl get deployment pause-demo
# Shows 5 replicas

kubectl describe deployment pause-demo | grep -E "Image|Environment"
# Shows nginx:1.21 and APP_VERSION=2.0

# Step 9: Check history
kubectl rollout history deployment/pause-demo
# Now shows revision 2 (one rollout for all changes)

# Cleanup
kubectl delete deployment pause-demo
```

**Key Learning:** Pausing allows batching multiple changes into a single rollout.

</details><br />

## Blue/Green Deployment Pattern

Blue/green deployment runs two complete environments and switches traffic between them.

### Implementation with Services

```yaml
# Blue deployment (current version)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: blue
  template:
    metadata:
      labels:
        app: myapp
        version: blue
    spec:
      containers:
      - name: app
        image: myapp:1.0
---
# Green deployment (new version)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: green
  template:
    metadata:
      labels:
        app: myapp
        version: green
    spec:
      containers:
      - name: app
        image: myapp:2.0
---
# Service initially points to blue
apiVersion: v1
kind: Service
metadata:
  name: app-service
spec:
  selector:
    app: myapp
    version: blue  # Change to 'green' to switch
  ports:
  - port: 80
    targetPort: 8080
```

### Switching Traffic

```bash
# Deploy both versions
kubectl apply -f blue-deployment.yaml
kubectl apply -f green-deployment.yaml

# Service points to blue (v1.0)
kubectl apply -f service-blue.yaml

# Test green deployment separately
kubectl port-forward deployment/app-green 8080:8080

# Switch traffic to green
kubectl patch service app-service -p '{"spec":{"selector":{"version":"green"}}}'

# Instant switch, no gradual rollout
# Rollback is instant too
kubectl patch service app-service -p '{"spec":{"selector":{"version":"blue"}}}'
```

## Exercise 6: Blue/Green Deployment

**Task**: Implement a blue/green deployment and switch traffic between versions.

<details>
  <summary>Complete Solution</summary>

```bash
# Step 1: Create blue deployment (v1)
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-blue
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
      version: blue
  template:
    metadata:
      labels:
        app: web
        version: blue
    spec:
      containers:
      - name: nginx
        image: nginx:1.20
        ports:
        - containerPort: 80
EOF

# Step 2: Create service pointing to blue
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  selector:
    app: web
    version: blue
  ports:
  - port: 80
    targetPort: 80
  type: NodePort
EOF

# Step 3: Test blue deployment
kubectl get svc web-service
curl <cluster-ip>:80  # or kubectl port-forward

# Step 4: Create green deployment (v2)
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-green
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
      version: green
  template:
    metadata:
      labels:
        app: web
        version: green
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
EOF

# Step 5: Verify both deployments running
kubectl get deployments -l app=web
kubectl get pods -l app=web --show-labels

# Step 6: Switch traffic to green
kubectl patch service web-service -p '{"spec":{"selector":{"version":"green"}}}'

# Step 7: Verify traffic switched
kubectl describe service web-service | grep Selector
# Shows: version=green

# Step 8: Test new version
curl <cluster-ip>:80

# Step 9: Rollback to blue (instant)
kubectl patch service web-service -p '{"spec":{"selector":{"version":"blue"}}}'

# Step 10: Cleanup old version
kubectl delete deployment web-blue

# Cleanup
kubectl delete deployment web-green
kubectl delete service web-service
```

**Advantages:**
- Instant switch between versions
- Instant rollback
- Easy testing of new version before switching

**Disadvantages:**
- Requires 2x resources
- Database migrations can be complex

</details><br />

## Canary Deployment Pattern

Canary deployment rolls out to a small subset of users first, then gradually to everyone.

### Implementation

```yaml
# Main deployment (90% of traffic)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-stable
spec:
  replicas: 9
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
        version: stable
    spec:
      containers:
      - name: app
        image: myapp:1.0
---
# Canary deployment (10% of traffic)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
        version: canary
    spec:
      containers:
      - name: app
        image: myapp:2.0
---
# Service balances across both
apiVersion: v1
kind: Service
metadata:
  name: app-service
spec:
  selector:
    app: myapp  # Matches both stable and canary
  ports:
  - port: 80
```

### Gradual Rollout

```bash
# Start: 10% canary
# stable: 9 replicas
# canary: 1 replica

# Increase to 50% canary
kubectl scale deployment app-stable --replicas=5
kubectl scale deployment app-canary --replicas=5

# Full canary (100%)
kubectl scale deployment app-stable --replicas=0
kubectl scale deployment app-canary --replicas=10

# Promote canary to stable
kubectl set image deployment/app-stable app=myapp:2.0
kubectl scale deployment app-stable --replicas=10
kubectl delete deployment app-canary
```

## Common CKAD Rollout Scenarios

### Scenario 1: Update Failed - Rollback

**Question**: "Deployment 'web' was updated but pods are crashing. Roll back to the previous working version."

**Solution**:
```bash
kubectl rollout undo deployment/web
kubectl rollout status deployment/web
```

### Scenario 2: Update Multiple Fields Atomically

**Question**: "Update the deployment 'app' to use image v2.0 and increase replicas to 5 in a single rollout."

**Solution**:
```bash
kubectl rollout pause deployment/app
kubectl set image deployment/app app=app:v2.0
kubectl scale deployment app --replicas=5
kubectl rollout resume deployment/app
```

### Scenario 3: Slow Rollout for Critical App

**Question**: "Configure deployment 'database' to update one pod at a time with zero downtime."

**Solution**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  # ... rest of spec
```

Or imperatively:
```bash
kubectl patch deployment database -p '{"spec":{"strategy":{"rollingUpdate":{"maxSurge":1,"maxUnavailable":0}}}}'
```

### Scenario 4: Check Rollout Progress

**Question**: "A rollout is in progress for 'web'. Check its status and wait for completion."

**Solution**:
```bash
kubectl rollout status deployment/web

# Or with timeout
kubectl rollout status deployment/web --timeout=5m
```

## Quick Command Reference

```bash
# Update image (triggers rollout)
kubectl set image deployment/<name> <container>=<image>

# Check status
kubectl rollout status deployment/<name>

# View history
kubectl rollout history deployment/<name>
kubectl rollout history deployment/<name> --revision=<N>

# Rollback
kubectl rollout undo deployment/<name>
kubectl rollout undo deployment/<name> --to-revision=<N>

# Pause/Resume
kubectl rollout pause deployment/<name>
kubectl rollout resume deployment/<name>

# Restart (recreate pods)
kubectl rollout restart deployment/<name>

# Watch pods during rollout
kubectl get pods -l <selector> -w

# Check rollout in deployment
kubectl describe deployment <name> | grep -A10 RollingUpdate
```

## Troubleshooting Rollouts

### Rollout Stuck

```bash
# Check rollout status
kubectl rollout status deployment/app

# Check pod status
kubectl get pods -l app=app

# Check events
kubectl describe deployment app

# Common causes:
# - Image pull errors
# - Insufficient resources
# - Failed readiness probes
# - PVC issues
```

### Rollback Not Working

```bash
# Verify revision exists
kubectl rollout history deployment/app

# Check specific revision
kubectl rollout history deployment/app --revision=2

# Force rollback
kubectl rollout undo deployment/app --to-revision=1
```

## Exam Tips

1. **Practice speed**: Update, check status, rollback in < 5 minutes
2. **Use shortcuts**: `kubectl set image` faster than editing YAML
3. **Know the difference**: pause vs undo vs restart
4. **Remember history**: rollout undo creates new revision
5. **Check status**: Always verify rollout completed successfully
6. **Understand strategies**: maxSurge/maxUnavailable combinations
7. **Use -w flag**: Watch pods during rollout to see progress
8. **Test before exam**: Practice all three deployment strategies
9. **Read events**: `kubectl describe deployment` shows rollout issues
10. **Remember annotations**: Track changes with kubernetes.io/change-cause

## Study Checklist

- [ ] Perform rolling update with kubectl set image
- [ ] Check rollout status and history
- [ ] Rollback to previous version
- [ ] Rollback to specific revision
- [ ] Configure maxSurge and maxUnavailable
- [ ] Pause and resume rollouts
- [ ] Batch multiple changes with pause/resume
- [ ] Implement blue/green deployment
- [ ] Implement canary deployment
- [ ] Troubleshoot failed rollouts
- [ ] Understand rollout strategies
- [ ] Use rollout restart to recreate pods
- [ ] Track changes with annotations

## Summary

Rollouts and deployment strategies are crucial for CKAD. Master these skills:

✅ **Core Commands:**
- `kubectl set image` - Update image
- `kubectl rollout status` - Check progress
- `kubectl rollout history` - View revisions
- `kubectl rollout undo` - Rollback
- `kubectl rollout pause/resume` - Batch changes

✅ **Strategies:**
- **Rolling Update**: Default, zero downtime
- **Blue/Green**: Instant switch, 2x resources
- **Canary**: Gradual rollout, test with subset

✅ **Configuration:**
- maxSurge: Extra pods during rollout
- maxUnavailable: Pods below desired during rollout

🎯 **Exam weight**: 20% (Application Deployment)
⏱️ **Time target**: 4-6 minutes per question
📊 **Difficulty**: Medium (requires practice)

Practice until rollout operations are automatic!
