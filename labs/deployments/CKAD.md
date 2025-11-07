# CKAD Exam Preparation: Advanced Deployments

This document covers advanced Deployment topics required for the Certified Kubernetes Application Developer (CKAD) exam. Complete the [basic deployments lab](README.md) first before working through these exercises.

## Prerequisites

Before starting this lab, you should be familiar with:
- Creating basic Deployments
- Scaling applications
- Basic rolling updates and rollbacks
- Working with labels and selectors

## CKAD Deployment Topics Covered

- Deployment strategies (RollingUpdate vs Recreate)
- Rolling update configuration (maxSurge, maxUnavailable)
- Advanced rollout management (pause, resume, status, history)
- Resource requests and limits
- Health checks (readiness, liveness, startup probes)
- Multi-container patterns (init containers, sidecars)
- Advanced deployment patterns (canary, blue-green)
- Deployment annotations and change tracking
- Production best practices

## Deployment Strategies

Deployments support two strategies for replacing old Pods with new ones:

### 1. RollingUpdate (Default)

The RollingUpdate strategy gradually replaces old Pods with new ones, ensuring some Pods are always available during updates.

The spec includes explicit RollingUpdate configuration with `maxSurge` and `maxUnavailable` settings:

```bash
# Deploy with RollingUpdate strategy
kubectl apply -f labs/deployments/specs/ckad/strategy-rolling.yaml

# Watch the rollout
kubectl rollout status deployment/whoami-rolling

# Check deployment details
kubectl describe deployment whoami-rolling

# View pods being created/terminated during updates
kubectl get pods -l app=whoami --watch
```

The deployment creates 5 replicas with `maxSurge: 1` and `maxUnavailable: 0`, ensuring zero-downtime updates. During rollouts, Kubernetes:
1. Creates 1 new pod (maxSurge)
2. Waits for readiness probe to pass
3. Terminates 1 old pod
4. Repeats until all pods are updated

Test the rolling update:

```bash
# Update to new version
kubectl set image deployment/whoami-rolling app=sixeyed/whoami:21.04.01

# Watch the gradual rollout
kubectl get pods -l app=whoami -w

# Verify rollout succeeded
kubectl rollout status deployment/whoami-rolling
```

### 2. Recreate Strategy

The Recreate strategy terminates all existing Pods before creating new ones. This causes downtime but ensures old and new versions never run simultaneously.

```bash
# Deploy with Recreate strategy
kubectl apply -f labs/deployments/specs/ckad/strategy-recreate.yaml

# Verify deployment is running
kubectl get deployment whoami-recreate
kubectl get pods -l app=whoami-recreate

# Trigger an update to see Recreate behavior
kubectl set image deployment/whoami-recreate app=sixeyed/whoami:21.04.01

# Watch all pods terminate before new ones start (observe downtime)
kubectl get pods -l app=whoami-recreate --watch

# Check rollout status
kubectl rollout status deployment/whoami-recreate
```

During a Recreate update, you'll observe:
1. All existing pods terminate simultaneously
2. Brief period with **zero running pods** (downtime)
3. All new pods start together
4. Service unavailable until new pods are ready

📋 **CKAD Tip**: Know when to use each strategy. Recreate is useful when:
- Your app can't handle multiple versions running simultaneously
- You need to perform database migrations
- Resource constraints prevent running both versions

## Rolling Update Configuration

Control how rolling updates behave with `maxSurge` and `maxUnavailable`:

### MaxSurge and MaxUnavailable

Deploy the example with custom rolling update configuration:

```bash
# Deploy with explicit rolling update settings
kubectl apply -f labs/deployments/specs/ckad/rolling-update-config.yaml

# Check deployment strategy
kubectl describe deployment whoami-rolling-config | grep -A 5 Strategy

# Access the service
kubectl get service whoami-rolling-config
```

The spec demonstrates key configuration:

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # Max pods above desired count (number or %)
      maxUnavailable: 0  # Max pods unavailable during update (number or %)
```

Test different configurations:

- **maxSurge**: Maximum number (or %) of Pods created above the desired replica count during an update
- **maxUnavailable**: Maximum number (or %) of Pods that can be unavailable during an update

📋 **CKAD Exam Pattern**: You may need to configure a zero-downtime deployment where `maxUnavailable=0` and `maxSurge=1`.

Try different configurations:

```
# Update deployment with different rolling update parameters
kubectl patch deployment whoami -p '{"spec":{"strategy":{"rollingUpdate":{"maxSurge":"50%","maxUnavailable":"50%"}}}}'

# Compare rollout speed with conservative settings
kubectl patch deployment whoami -p '{"spec":{"strategy":{"rollingUpdate":{"maxSurge":1,"maxUnavailable":0}}}}'

# Trigger an update to see the difference
kubectl set image deployment/whoami app=sixeyed/whoami:21.04.01
```

## Advanced Rollout Management

### Recording Changes

Use `--record` flag (deprecated but still on exam) or annotations to track changes:

```
# Record the command in rollout history (deprecated but may appear on exam)
kubectl set image deployment/whoami app=sixeyed/whoami:21.04.01 --record

# Better approach: use kubernetes.io/change-cause annotation
kubectl annotate deployment/whoami kubernetes.io/change-cause="Updated to version 21.04.01"

# View rollout history with change causes
kubectl rollout history deployment/whoami
```

Best practice example for change tracking:

```bash
# Deploy initial version with annotation
kubectl apply -f labs/deployments/specs/ckad/rolling-update-config.yaml

# Update image and set change-cause annotation
kubectl set image deployment/whoami-rolling-config app=sixeyed/whoami:21.04.01
kubectl annotate deployment/whoami-rolling-config kubernetes.io/change-cause="Updated to version 21.04.01 for security patches"

# Make another update
kubectl set image deployment/whoami-rolling-config app=sixeyed/whoami:21.04.02
kubectl annotate deployment/whoami-rolling-config kubernetes.io/change-cause="Updated to version 21.04.02 with bug fixes" --overwrite

# View history with change causes
kubectl rollout history deployment/whoami-rolling-config

# Output shows your annotations:
# REVISION  CHANGE-CAUSE
# 1         Initial deployment with custom rolling update config
# 2         Updated to version 21.04.01 for security patches
# 3         Updated to version 21.04.02 with bug fixes
```

📋 **CKAD Exam Tip**: The `--record` flag is deprecated but may still appear on the exam. Prefer using `kubernetes.io/change-cause` annotation for production use.

### Rollout Status and History

Monitor and inspect deployment rollouts:

```
# Check rollout status (blocks until complete)
kubectl rollout status deployment/whoami

# View rollout history
kubectl rollout history deployment/whoami

# View specific revision details
kubectl rollout history deployment/whoami --revision=2

# Describe a deployment to see conditions
kubectl describe deployment whoami
```

### Pausing and Resuming Rollouts

Pause deployments to make multiple changes before rolling out:

```
# Pause the rollout
kubectl rollout pause deployment/whoami

# Make multiple changes without triggering rollouts
kubectl set image deployment/whoami app=sixeyed/whoami:new-version
kubectl set resources deployment/whoami -c=app --limits=cpu=200m,memory=512Mi

# Resume to apply all changes in one rollout
kubectl rollout resume deployment/whoami
```

📋 **CKAD Scenario**: Pause a deployment, make configuration changes, then resume - useful for batching multiple updates.

### Rolling Back

Multiple ways to rollback failed deployments:

```
# Rollback to previous revision
kubectl rollout undo deployment/whoami

# Rollback to specific revision
kubectl rollout undo deployment/whoami --to-revision=2

# Verify the rollback
kubectl rollout status deployment/whoami
kubectl rollout history deployment/whoami
```

Practice rollback with a broken deployment:

```bash
# Deploy working version
kubectl apply -f labs/deployments/specs/ckad/broken-deployment.yaml

# Verify it's working
kubectl get deployment whoami-broken
kubectl get pods -l app=whoami-broken

# Update to broken image (wrong tag)
kubectl set image deployment/whoami-broken app=sixeyed/whoami:broken-tag-999
kubectl annotate deployment/whoami-broken kubernetes.io/change-cause="Updated to broken version"

# Check rollout status - it will hang with ImagePullBackOff
kubectl rollout status deployment/whoami-broken --timeout=30s

# Inspect the failure
kubectl get pods -l app=whoami-broken
kubectl describe pod -l app=whoami-broken | grep -A 5 Events

# View rollout history
kubectl rollout history deployment/whoami-broken

# Rollback to previous working version
kubectl rollout undo deployment/whoami-broken

# Verify rollback succeeded
kubectl rollout status deployment/whoami-broken
kubectl get pods -l app=whoami-broken

# Check history - rollback creates new revision
kubectl rollout history deployment/whoami-broken

# Rollback to specific revision if needed
# kubectl rollout undo deployment/whoami-broken --to-revision=1

# Cleanup
kubectl delete -f labs/deployments/specs/ckad/broken-deployment.yaml
```

📋 **CKAD Pattern**: In the exam, you might need to quickly identify a failed rollout and rollback. Practice the sequence: `rollout status` → `describe pod` → `rollout undo` → `rollout status`.

## Resource Management

Deployments should specify resource requests and limits for production readiness:

Deploy example with resource requests and limits:

```bash
# Deploy with resources configured
kubectl apply -f labs/deployments/specs/ckad/resources.yaml

# Check resource settings
kubectl describe deployment whoami-resources | grep -A 10 "Limits\|Requests"

# View pod resource usage (requires metrics-server)
kubectl top pods -l app=whoami-resources
```

The spec includes both requests and limits:

```yaml
spec:
  template:
    spec:
      containers:
      - name: app
        image: sixeyed/whoami:21.04
        resources:
          requests:
            memory: "64Mi"    # Guaranteed minimum
            cpu: "100m"       # 0.1 CPU cores
          limits:
            memory: "128Mi"   # Maximum allowed
            cpu: "200m"       # 0.2 CPU cores
```

Update resources imperatively (useful in exam for speed):

```
# Set resource requests
kubectl set resources deployment/whoami -c=app --requests=cpu=100m,memory=64Mi

# Set resource limits
kubectl set resources deployment/whoami -c=app --limits=cpu=200m,memory=128Mi

# View resource settings
kubectl describe deployment whoami | grep -A 5 Limits
```

📋 **CKAD Critical**: Know the difference between requests (scheduler guarantee) and limits (enforcement boundary).

## Health Checks

Production deployments need health checks to ensure reliable updates:

### Readiness Probes

Readiness probes determine when a Pod is ready to accept traffic:

```bash
# Deploy with readiness probe
kubectl apply -f labs/deployments/specs/ckad/readiness-probe.yaml

# Watch pods become ready
kubectl get pods -l app=whoami-readiness --watch

# Check probe configuration
kubectl describe deployment whoami-readiness | grep -A 10 Readiness

# Test readiness: temporarily make pod unready by killing the app
kubectl exec -it <pod-name> -- killall whoami
# Pod becomes NotReady, removed from service endpoints

# Verify service only routes to ready pods
kubectl get endpoints whoami-readiness
```

Readiness probe configuration:

```yaml
spec:
  template:
    spec:
      containers:
      - name: app
        image: sixeyed/whoami:21.04
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5   # Wait before first probe
          periodSeconds: 5         # Check every 5 seconds
          failureThreshold: 3      # Mark unready after 3 failures
```

📋 **CKAD Key Concept**: Readiness probe failure removes Pod from Service endpoints but does NOT restart the container. This is different from liveness probes.

### Liveness Probes

Liveness probes determine when a container needs to be restarted:

```bash
# Deploy with liveness probe
kubectl apply -f labs/deployments/specs/ckad/liveness-probe.yaml

# Check probe configuration
kubectl describe deployment whoami-liveness | grep -A 10 Liveness

# Watch for restarts
kubectl get pods -l app=whoami-liveness -w

# Check restart count (should be 0 for healthy app)
kubectl get pods -l app=whoami-liveness

# View pod events showing liveness checks
kubectl describe pod <pod-name> | grep -A 10 Events
```

Liveness probe configuration:

```yaml
spec:
  template:
    spec:
      containers:
      - name: app
        image: sixeyed/whoami:21.04
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 15   # Wait 15s after container starts
          periodSeconds: 10         # Check every 10 seconds
          failureThreshold: 3       # Restart after 3 failures
```

📋 **CKAD Key Concept**: Liveness probe failure triggers container restart. Set `initialDelaySeconds` longer than app startup time to avoid restart loops.

### Startup Probes

Startup probes handle slow-starting containers:

```bash
# Deploy with startup probe
kubectl apply -f labs/deployments/specs/ckad/startup-probe.yaml

# Watch startup process
kubectl get pods -l app=whoami-startup --watch

# Check probe configuration
kubectl describe deployment whoami-startup | grep -A 10 "Startup\|Liveness"

# View pod events during startup
kubectl describe pod <pod-name> | grep -A 15 Events
```

Startup probe configuration:

```yaml
spec:
  template:
    spec:
      containers:
      - name: app
        image: sixeyed/whoami:21.04
        startupProbe:
          httpGet:
            path: /
            port: 80
          failureThreshold: 30   # 30 attempts
          periodSeconds: 10      # Every 10 seconds
          # = 300 seconds (5 minutes) maximum startup time
```

📋 **CKAD Key Concept**: Startup probes disable liveness and readiness checks until first success. Use for apps with long initialization (databases, legacy applications).

### Probe Types

All probe types support three check mechanisms:

```yaml
# HTTP GET probe
httpGet:
  path: /health
  port: 80
  httpHeaders:
  - name: Custom-Header
    value: Awesome

# TCP Socket probe
tcpSocket:
  port: 80

# Command execution probe
exec:
  command:
  - cat
  - /tmp/healthy
```

📋 **CKAD Quick Reference**:
- `initialDelaySeconds`: Wait before first probe
- `periodSeconds`: How often to probe
- `timeoutSeconds`: Probe timeout
- `successThreshold`: Consecutive successes to mark healthy
- `failureThreshold`: Consecutive failures to mark unhealthy

### Combining All Probe Types

Deploy an example with all three probe types working together:

```bash
# Deploy with all probe types
kubectl apply -f labs/deployments/specs/ckad/all-probes.yaml

# Watch the startup sequence
kubectl get pods -l app=whoami-all-probes --watch

# Check all probe configurations
kubectl describe deployment whoami-all-probes | grep -A 5 "Startup\|Readiness\|Liveness"

# Test the service
kubectl get service whoami-all-probes
curl localhost:30023

# View probe execution in pod events
kubectl describe pod <pod-name> | grep -A 20 Events
```

Execution order:
1. **Startup probe** runs first, other probes disabled
2. Once startup succeeds (or no startup probe defined):
3. **Readiness probe** determines traffic eligibility
4. **Liveness probe** monitors container health

```bash
# Cleanup
kubectl delete -f labs/deployments/specs/ckad/all-probes.yaml
```

📋 **CKAD Exam Tip**: You may need to add probes to an existing deployment. Use `kubectl edit` or `kubectl set` commands, or export YAML, modify, and reapply.

## Multi-Container Patterns

### Init Containers

Init containers run before app containers and must complete successfully:

```bash
# Deploy with init containers
kubectl apply -f labs/deployments/specs/ckad/init-containers.yaml

# Watch init containers run (Status: Init:0/2, Init:1/2, then Running)
kubectl get pods -l app=whoami-init --watch

# Check init container status
kubectl describe pod <pod-name> | grep -A 20 "Init Containers"

# View init container logs
kubectl logs <pod-name> -c wait-for-service
kubectl logs <pod-name> -c setup-config

# Verify main container can access init container output
kubectl exec <pod-name> -- cat /work-dir/init-info.txt

# Cleanup
kubectl delete -f labs/deployments/specs/ckad/init-containers.yaml
```

Init container configuration:

```yaml
spec:
  template:
    spec:
      initContainers:
      - name: wait-for-service
        image: busybox:1.36
        command: ['sh', '-c', 'echo Waiting... && sleep 5']
      - name: setup-config
        image: busybox:1.36
        command: ['sh', '-c', 'echo "Config data" > /work-dir/config.txt']
        volumeMounts:
        - name: workdir
          mountPath: /work-dir
      containers:
      - name: app
        image: sixeyed/whoami:21.04
        volumeMounts:
        - name: workdir
          mountPath: /work-dir
      volumes:
      - name: workdir
        emptyDir: {}
```

Common init container use cases:
- Wait for dependencies (databases, services)
- Clone git repositories
- Populate volumes with data
- Set permissions on volumes

### Sidecar Containers

Sidecars run alongside the main container throughout the Pod lifecycle:

```bash
# Deploy with sidecar container
kubectl apply -f labs/deployments/specs/ckad/sidecar.yaml

# Check both containers are running
kubectl get pods -l app=whoami-sidecar

# View logs from main container
kubectl logs <pod-name> -c app

# View logs from sidecar container
kubectl logs <pod-name> -c log-shipper
kubectl logs <pod-name> -c log-shipper -f  # Follow logs

# Exec into sidecar to verify shared volume
kubectl exec <pod-name> -c log-shipper -- ls -la /logs

# Cleanup
kubectl delete -f labs/deployments/specs/ckad/sidecar.yaml
```

Sidecar pattern configuration:

```yaml
spec:
  template:
    spec:
      containers:
      - name: app
        image: sixeyed/whoami:21.04
        volumeMounts:
        - name: logs
          mountPath: /logs
      - name: log-shipper
        image: busybox:1.36
        command: ['sh', '-c', 'tail -f /logs/*.log']
        volumeMounts:
        - name: logs
          mountPath: /logs
      volumes:
      - name: logs
        emptyDir: {}
```

📋 **CKAD Pattern**: All containers in a Pod share the same network namespace (can communicate via localhost) and can share volumes.

Common sidecar patterns:
- Log shipping and aggregation
- Metrics collection
- Service mesh proxies
- Configuration synchronization

### Combining Init Containers and Sidecars

Real-world pattern combining both multi-container types:

```bash
# Deploy complex multi-container setup
kubectl apply -f labs/deployments/specs/ckad/init-sidecar-combined.yaml

# Watch init containers complete first
kubectl get pods -l app=whoami-multi --watch

# Check init container logs
kubectl logs <pod-name> -c check-dependencies
kubectl logs <pod-name> -c setup-data

# Check all running containers (main + sidecars)
kubectl get pods <pod-name> -o jsonpath='{.spec.containers[*].name}'

# View logs from each container
kubectl logs <pod-name> -c app
kubectl logs <pod-name> -c monitor
kubectl logs <pod-name> -c log-aggregator

# Verify shared data from init container
kubectl exec <pod-name> -c app -- cat /shared-data/startup.txt

# Describe pod to see full multi-container architecture
kubectl describe pod <pod-name>

# Cleanup
kubectl delete -f labs/deployments/specs/ckad/init-sidecar-combined.yaml
```

This pattern demonstrates:
- **2 init containers** that run sequentially before app starts
- **3 main containers** that run concurrently:
  - Main application
  - Monitoring sidecar
  - Log aggregation sidecar
- **Shared volume** for communication between all containers

📋 **CKAD Pattern**: You may need to add a sidecar to an existing deployment for logging/monitoring. Use `kubectl edit` or export, modify, and reapply the YAML.

## Advanced Deployment Patterns

### Canary Deployments

Canary deployments run a small percentage of traffic on the new version:

```bash
# Deploy main version with 3 replicas
kubectl apply -f labs/deployments/specs/ckad/canary/whoami-main.yaml

# Deploy canary with 1 replica (25% traffic split)
kubectl apply -f labs/deployments/specs/ckad/canary/whoami-canary.yaml

# Deploy service that routes to both
kubectl apply -f labs/deployments/specs/ckad/canary/service.yaml

# Verify both deployments running
kubectl get deployments -l app=whoami-canary
kubectl get pods -l app=whoami-canary --show-labels

# Test traffic distribution (run multiple times)
for i in {1..10}; do curl -s localhost:30024 | grep -i version; done

# Monitor canary logs specifically
kubectl logs -l version=canary --tail=20 -f

# Monitor main logs
kubectl logs -l version=main --tail=20 -f

# Check service endpoints (should include all 4 pods)
kubectl get endpoints whoami-canary

# If canary is healthy, gradually increase canary traffic
kubectl scale deployment/whoami-canary --replicas=2  # Now 40% canary
kubectl scale deployment/whoami-canary --replicas=3  # Now 50% canary

# Complete cutover: scale main to 0, canary to desired count
kubectl scale deployment/whoami-main --replicas=0
kubectl scale deployment/whoami-canary --replicas=4

# Rollback if issues detected
kubectl scale deployment/whoami-main --replicas=3
kubectl scale deployment/whoami-canary --replicas=0

# Cleanup
kubectl delete -f labs/deployments/specs/ckad/canary/
```

Canary strategy:
1. Deploy main version with most replicas (75%)
2. Deploy canary version with few replicas (25%)
3. Both use same Service selector label
4. Traffic splits proportionally by replica count
5. Monitor canary metrics/logs/errors
6. Gradually scale up canary, scale down main
7. Rollback by reversing the scaling

📋 **CKAD Tip**: Canary deployments require careful label management. The Service selector must match both deployments, but each deployment needs unique labels for individual targeting.

### Blue-Green Deployments (Advanced)

Production-grade blue-green deployment with instant cutover:

```bash
# Deploy blue environment (current production)
kubectl apply -f labs/deployments/specs/ckad/blue-green/whoami-blue.yaml

# Deploy green environment (new version)
kubectl apply -f labs/deployments/specs/ckad/blue-green/whoami-green.yaml

# Verify both environments are ready
kubectl get deployments -l app=whoami-bg
kubectl get pods -l app=whoami-bg --show-labels

# Service initially points to blue
kubectl apply -f labs/deployments/specs/ckad/blue-green/service-blue.yaml

# Test blue version
curl localhost:30025
# Should see ENVIRONMENT=BLUE, VERSION=1.0

# Verify only blue pods in service endpoints
kubectl get endpoints whoami-bg
kubectl describe service whoami-bg

# Switch to green (instant cutover)
kubectl apply -f labs/deployments/specs/ckad/blue-green/service-green.yaml

# Test green version immediately
curl localhost:30025
# Should see ENVIRONMENT=GREEN, VERSION=2.0

# Verify only green pods in service endpoints
kubectl get endpoints whoami-bg

# Quick rollback to blue if issues detected
kubectl apply -f labs/deployments/specs/ckad/blue-green/service-blue.yaml
curl localhost:30025  # Back to blue

# After green is validated, can delete blue deployment
kubectl delete deployment whoami-blue

# Cleanup
kubectl delete -f labs/deployments/specs/ckad/blue-green/
```

Blue-green strategy:
1. Run two complete environments (blue and green)
2. Both have production-grade configs (replicas, health checks, resources)
3. Service selector determines active environment
4. Instant cutover by changing Service selector
5. Zero downtime (both environments always ready)
6. Instant rollback capability
7. Higher resource cost (running duplicate environments)

📋 **CKAD Tip**: Blue-green requires careful label management. Practice changing Service selectors quickly.

## Production Best Practices

### Complete Production-Ready Deployment

Deploy a fully production-ready application with all best practices:

```bash
# Deploy production-ready application
kubectl apply -f labs/deployments/specs/ckad/production-ready.yaml

# Verify deployment in production-demo namespace
kubectl get all -n production-demo

# Check deployment has all production features
kubectl describe deployment webapp -n production-demo

# Test the service
kubectl get service webapp -n production-demo
curl localhost:30021

# Verify resource limits are set
kubectl describe pod -n production-demo -l app=webapp | grep -A 5 "Limits\|Requests"

# Check all three probe types configured
kubectl describe pod -n production-demo -l app=webapp | grep -A 3 "Startup\|Readiness\|Liveness"

# Test rolling update
kubectl set image deployment/webapp -n production-demo webapp=sixeyed/whoami:latest
kubectl annotate deployment/webapp -n production-demo kubernetes.io/change-cause="Updated to latest version" --overwrite

# Watch zero-downtime rollout
kubectl rollout status deployment/webapp -n production-demo
kubectl get pods -n production-demo -w

# View rollout history
kubectl rollout history deployment/webapp -n production-demo

# Cleanup
kubectl delete namespace production-demo
```

The production-ready spec includes:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  namespace: production-demo
  annotations:
    kubernetes.io/change-cause: "Initial production deployment v1.0.0"
spec:
  replicas: 3                    # HA with multiple replicas
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1                # Zero-downtime updates
      maxUnavailable: 1
  template:
    spec:
      containers:
      - name: webapp
        image: sixeyed/whoami:latest
        resources:
          requests:                # Guaranteed resources
            cpu: 100m
            memory: 128Mi
          limits:                  # Resource boundaries
            cpu: 500m
            memory: 256Mi
        startupProbe:              # Handles slow startup
        readinessProbe:            # Controls traffic routing
        livenessProbe:             # Detects failures
        securityContext:           # Security hardening
          runAsNonRoot: true
```

### Deployment Checklist for CKAD

Ensure your deployments include:

- [ ] Appropriate replica count for HA (minimum 2)
- [ ] Resource requests and limits
- [ ] Readiness probe configured
- [ ] Liveness probe configured
- [ ] Appropriate rolling update strategy
- [ ] Meaningful labels for selection
- [ ] Change-cause annotations
- [ ] Container port explicitly named
- [ ] Image version pinned (not :latest)
- [ ] Proper selector matching template labels

## CKAD Lab Exercises

### Exercise 1: Zero-Downtime Deployment

Create a deployment that guarantees zero downtime during updates.

```bash
# Deploy starting configuration
kubectl apply -f labs/deployments/specs/ckad/exercises/zero-downtime-start.yaml

# Verify deployment is running with 3 replicas
kubectl get deployment webapp-zero-downtime
kubectl get pods -l app=webapp-zero-downtime

# Check the service
kubectl get service webapp-zero-downtime

# Update to new version with zero downtime
kubectl set image deployment/webapp-zero-downtime app=sixeyed/whoami:21.04.01

# In another terminal, continuously test availability (no errors should occur)
while true; do curl -s http://localhost:8080 > /dev/null && echo "OK" || echo "FAILED"; sleep 0.5; done

# Watch the rolling update (maxUnavailable: 0 ensures all pods stay available)
kubectl get pods -l app=webapp-zero-downtime --watch

# Verify rollout succeeded
kubectl rollout status deployment/webapp-zero-downtime

# Check that readiness probe prevented traffic to non-ready pods
kubectl describe deployment webapp-zero-downtime

# Cleanup
kubectl delete -f labs/deployments/specs/ckad/exercises/zero-downtime-start.yaml
```

Key configuration for zero downtime:
- `maxSurge: 1` - Create new pod before terminating old ones
- `maxUnavailable: 0` - Never allow pods to be unavailable
- `readinessProbe` - Only route traffic to ready pods

### Exercise 2: Failed Deployment Recovery

Practice identifying and recovering from failed deployments.

This exercise uses the broken-deployment.yaml created earlier in the rollback section. Follow the complete walkthrough:

```bash
# Deploy working version
kubectl apply -f labs/deployments/specs/ckad/broken-deployment.yaml

# Verify initial deployment works
kubectl get pods -l app=whoami-broken
kubectl rollout status deployment/whoami-broken

# Simulate production issue: update to non-existent image
kubectl set image deployment/whoami-broken app=sixeyed/whoami:non-existent-tag

# Observe the failure
kubectl rollout status deployment/whoami-broken --timeout=30s

# Identify the problem
kubectl get pods -l app=whoami-broken
# You'll see: ImagePullBackOff or ErrImagePull

kubectl describe pod -l app=whoami-broken | tail -20
# Events show: Failed to pull image

# Check deployment status
kubectl get deployment whoami-broken
# READY shows 3/3 old pods still running (RollingUpdate protected us!)

# View rollout history
kubectl rollout history deployment/whoami-broken

# Perform rollback
kubectl rollout undo deployment/whoami-broken

# Verify recovery
kubectl rollout status deployment/whoami-broken
kubectl get pods -l app=whoami-broken
# All pods should be Running again

# Cleanup
kubectl delete -f labs/deployments/specs/ckad/broken-deployment.yaml
```

📋 **CKAD Exam Skill**: Practice identifying failure types quickly:
- **ImagePullBackOff**: Wrong image name/tag or registry auth issue
- **CrashLoopBackOff**: Container starts but exits immediately
- **Pending**: Resource constraints or scheduling issues
- **Not Ready**: Failing readiness probes

### Exercise 3: Canary Release

Implement and manage a complete canary deployment.

This exercise uses the canary specs created earlier. Follow the complete workflow:

```bash
# Deploy both environments
kubectl apply -f labs/deployments/specs/ckad/canary/

# Verify both deployments
kubectl get deployments -l app=whoami-canary
# whoami-main: 3/3 replicas
# whoami-canary: 1/1 replicas

kubectl get pods -l app=whoami-canary --show-labels
# Should see 4 total pods with different version labels

# Test traffic distribution (approximately 75% main, 25% canary)
for i in {1..20}; do
  curl -s localhost:30024 | grep DEPLOYMENT
done | sort | uniq -c

# Monitor canary specifically
kubectl logs -l version=canary -f &

# If canary looks good, increase its traffic share
kubectl scale deployment/whoami-canary --replicas=2  # Now 40% canary (2/5)

# Test again
for i in {1..20}; do
  curl -s localhost:30024 | grep DEPLOYMENT
done | sort | uniq -c

# Continue gradual rollout
kubectl scale deployment/whoami-canary --replicas=3  # 50% canary
kubectl scale deployment/whoami-main --replicas=2    # 50% main

# Complete cutover
kubectl scale deployment/whoami-main --replicas=0
kubectl scale deployment/whoami-canary --replicas=4

# Verify only canary running
kubectl get pods -l app=whoami-canary

# Simulate problem detection and rollback
kubectl scale deployment/whoami-main --replicas=3
kubectl scale deployment/whoami-canary --replicas=1

# Cleanup
kubectl delete -f labs/deployments/specs/ckad/canary/
```

📋 **CKAD Canary Pattern**: Remember the formula for traffic percentage:
- Canary %=  (canary replicas) / (total replicas) × 100

### Exercise 4: Multi-Container Pattern

Create and manage a complex multi-container deployment.

This exercise uses the init-sidecar-combined.yaml spec:

```bash
# Deploy multi-container pattern
kubectl apply -f labs/deployments/specs/ckad/init-sidecar-combined.yaml

# Watch init containers run before main containers
kubectl get pods -l app=whoami-multi --watch
# Status progresses: Init:0/2 → Init:1/2 → Running

# Once running, check all containers
POD=$(kubectl get pod -l app=whoami-multi -o jsonpath='{.items[0].metadata.name}')

# View init container logs
kubectl logs $POD -c check-dependencies
kubectl logs $POD -c setup-data

# View main container logs
kubectl logs $POD -c app
kubectl logs $POD -c monitor -f
kubectl logs $POD -c log-aggregator

# Verify shared data from init container
kubectl exec $POD -c app -- cat /shared-data/startup.txt
kubectl exec $POD -c app -- cat /shared-data/status.txt

# Check resource usage across all containers
kubectl top pod $POD --containers

# Describe to see full architecture
kubectl describe pod $POD

# Test the application
kubectl get service whoami-multi
curl http://localhost:8080  # If service is LoadBalancer/NodePort

# Cleanup
kubectl delete -f labs/deployments/specs/ckad/init-sidecar-combined.yaml
```

Key multi-container concepts:
- **Init containers**: Run sequentially, must complete successfully
- **Main containers**: Run concurrently, share network and volumes
- **Container lifecycle**: Init → Main containers → Termination
- **Shared volumes**: Use `emptyDir` for inter-container communication

📋 **CKAD Exam Tip**: Know how to view logs and exec into specific containers using `-c <container-name>`.

### Exercise 5: Production Deployment

Build a production-ready deployment imperatively using CKAD exam techniques.

```bash
# Create deployment using imperative command (fast for exams)
kubectl create deployment prod-app \
  --image=sixeyed/whoami:21.04 \
  --replicas=3 \
  --dry-run=client -o yaml > prod-app.yaml

# Edit the generated YAML to add production features
# Open with: kubectl create deployment ... --dry-run=client -o yaml | kubectl apply -f -
# Or: export KUBE_EDITOR=nano; kubectl edit deployment prod-app

# Add resource limits (imperative)
kubectl set resources deployment/prod-app \
  --limits=cpu=200m,memory=256Mi \
  --requests=cpu=100m,memory=128Mi

# Configure rolling update strategy
kubectl patch deployment prod-app -p '{
  "spec": {
    "strategy": {
      "type": "RollingUpdate",
      "rollingUpdate": {
        "maxSurge": 1,
        "maxUnavailable": 0
      }
    }
  }
}'

# For probes, you'll need to edit the deployment
kubectl edit deployment prod-app
# Add under containers:
#   readinessProbe:
#     httpGet:
#       path: /
#       port: 80
#     initialDelaySeconds: 5
#     periodSeconds: 5
#   livenessProbe:
#     httpGet:
#       path: /
#       port: 80
#     initialDelaySeconds: 15
#     periodSeconds: 10

# Add annotations
kubectl annotate deployment prod-app \
  kubernetes.io/change-cause="Production deployment v1.0"

# Expose with service
kubectl expose deployment prod-app --port=80 --type=LoadBalancer

# Verify all production requirements
kubectl describe deployment prod-app

# Test rolling update
kubectl set image deployment/prod-app whoami=sixeyed/whoami:21.04.01
kubectl rollout status deployment/prod-app

# Cleanup
kubectl delete deployment prod-app
kubectl delete service prod-app
```

📋 **CKAD Exam Strategy**: Start with imperative commands for speed, then use `kubectl edit` or `kubectl patch` to add complex configurations like probes.

## Quick Command Reference for CKAD

Common imperative commands for exam speed:

```bash
# Create deployment
kubectl create deployment whoami --image=sixeyed/whoami:21.04 --replicas=3

# Update image
kubectl set image deployment/whoami app=sixeyed/whoami:21.04.01

# Scale deployment
kubectl scale deployment/whoami --replicas=5

# Set resources
kubectl set resources deployment/whoami -c=app --requests=cpu=100m,memory=64Mi --limits=cpu=200m,memory=128Mi

# Expose deployment
kubectl expose deployment whoami --port=80 --target-port=80 --type=LoadBalancer

# Rollout commands
kubectl rollout status deployment/whoami
kubectl rollout history deployment/whoami
kubectl rollout undo deployment/whoami
kubectl rollout pause deployment/whoami
kubectl rollout resume deployment/whoami
kubectl rollout restart deployment/whoami

# Get YAML for modification
kubectl get deployment whoami -o yaml > deployment.yaml

# Patch deployment (for quick changes)
kubectl patch deployment whoami -p '{"spec":{"replicas":5}}'

# Edit in-place (exam tip: set KUBE_EDITOR=nano or vim)
kubectl edit deployment whoami
```

## Common CKAD Exam Scenarios

### Scenario 1: Update Application Version
"Update the deployment 'webapp' to use image version 2.0 with zero downtime"

```bash
kubectl set image deployment/webapp app=webapp:2.0
kubectl rollout status deployment/webapp
```

### Scenario 2: Fix Failed Deployment
"The deployment 'api' is failing to roll out. Rollback to the previous version"

```bash
kubectl rollout status deployment/api
kubectl rollout history deployment/api
kubectl rollout undo deployment/api
```

### Scenario 3: Scale Application
"Scale the deployment 'frontend' to 5 replicas"

```bash
kubectl scale deployment/frontend --replicas=5
```

### Scenario 4: Add Resource Limits
"Add resource limits to deployment 'backend': CPU 200m, Memory 512Mi"

```bash
kubectl set resources deployment/backend -c=backend --limits=cpu=200m,memory=512Mi
```

### Scenario 5: Configure Rolling Update
"Configure deployment 'app' to update one pod at a time with no downtime"

```bash
kubectl patch deployment app -p '{"spec":{"strategy":{"rollingUpdate":{"maxSurge":1,"maxUnavailable":0}}}}'
```

### Scenario 6: Add Probes to Existing Deployment
"Add readiness and liveness probes to the existing deployment 'webapp'"

```bash
# Method 1: Edit in place (fastest in exam)
kubectl edit deployment webapp
# Add probes under containers section

# Method 2: Patch with JSON
kubectl patch deployment webapp --type=json -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/readinessProbe",
    "value": {
      "httpGet": {"path": "/", "port": 80},
      "initialDelaySeconds": 5,
      "periodSeconds": 5
    }
  },
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/livenessProbe",
    "value": {
      "httpGet": {"path": "/", "port": 80},
      "initialDelaySeconds": 15,
      "periodSeconds": 10
    }
  }
]'
```

### Scenario 7: Change Deployment Strategy
"Update deployment 'api' to use Recreate strategy instead of RollingUpdate"

```bash
kubectl patch deployment api -p '{"spec":{"strategy":{"type":"Recreate"}}}'
# Verify
kubectl describe deployment api | grep Strategy
```

### Scenario 8: Update Multiple Configurations
"For deployment 'backend': set 5 replicas, update image to v2.0, add resource limits"

```bash
# Can do all at once with kubectl edit, or separately:
kubectl scale deployment backend --replicas=5
kubectl set image deployment/backend backend=backend:v2.0
kubectl set resources deployment/backend -c=backend --limits=cpu=500m,memory=512Mi
```

### Scenario 9: Pause and Resume Deployment
"Pause deployment 'frontend', update image and resources, then resume"

```bash
kubectl rollout pause deployment/frontend
kubectl set image deployment/frontend app=newimage:v2
kubectl set resources deployment/frontend -c=app --requests=cpu=200m
kubectl rollout resume deployment/frontend
```

### Scenario 10: Check Deployment Progress
"Monitor deployment 'app' rollout and show revision history"

```bash
kubectl rollout status deployment/app
kubectl rollout history deployment/app
kubectl rollout history deployment/app --revision=3
```

## Troubleshooting Deployments

Common issues and debugging steps:

```bash
# Check deployment status
kubectl get deployments
kubectl describe deployment <name>

# Check replica sets
kubectl get replicasets
kubectl describe rs <name>

# Check pod status
kubectl get pods -l app=<label>
kubectl describe pod <name>
kubectl logs <pod-name>

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check rollout issues
kubectl rollout status deployment/<name>
kubectl rollout history deployment/<name>

# Force new rollout (if stuck)
kubectl rollout restart deployment/<name>
```

### Troubleshooting Exercise

Practice diagnosing common deployment failures:

```bash
# Scenario 1: CrashLoopBackOff
kubectl apply -f labs/deployments/specs/ckad/exercises/troubleshooting-crashloop.yaml

# Diagnose the problem
kubectl get pods -l app=troubleshoot-crashloop
# STATUS: CrashLoopBackOff

kubectl logs <pod-name>
# Shows container exit logs

kubectl describe pod <pod-name>
# Events show: Back-off restarting failed container

# The container exits with error code 1 immediately
# Fix: Update command to run properly
kubectl delete -f labs/deployments/specs/ckad/exercises/troubleshooting-crashloop.yaml

# Scenario 2: ImagePullBackOff
kubectl apply -f labs/deployments/specs/ckad/exercises/troubleshooting-imagepull.yaml

# Diagnose
kubectl get pods -l app=troubleshoot-imagepull
# STATUS: ImagePullBackOff or ErrImagePull

kubectl describe pod <pod-name> | grep -A 5 Events
# Events show: Failed to pull image "sixeyed/whoami:does-not-exist-999"
# Error: manifest unknown or image not found

# Fix: Correct the image tag
kubectl set image deployment/troubleshoot-imagepull app=sixeyed/whoami:21.04
kubectl rollout status deployment/troubleshoot-imagepull

kubectl delete -f labs/deployments/specs/ckad/exercises/troubleshooting-imagepull.yaml

# Scenario 3: Failing Readiness Probe
kubectl apply -f labs/deployments/specs/ckad/exercises/troubleshooting-readiness.yaml

# Diagnose
kubectl get pods -l app=troubleshoot-readiness
# STATUS: Running but NOT READY (0/1)

kubectl describe pod <pod-name> | grep -A 10 "Readiness\|Events"
# Readiness probe failed: connection refused on port 8080
# App runs on port 80, probe checks 8080

# Fix: Update probe to correct port
kubectl edit deployment troubleshoot-readiness
# Change readinessProbe port from 8080 to 80

kubectl get pods -l app=troubleshoot-readiness
# Now shows READY (1/1)

kubectl delete -f labs/deployments/specs/ckad/exercises/troubleshooting-readiness.yaml
```

Common troubleshooting commands:

```bash
# Pod status
kubectl get pods
kubectl describe pod <pod-name>
kubectl logs <pod-name>
kubectl logs <pod-name> --previous  # Previous container instance

# Deployment status
kubectl get deployment <name>
kubectl describe deployment <name>
kubectl rollout status deployment/<name>

# Events
kubectl get events --sort-by=.metadata.creationTimestamp
kubectl get events --field-selector involvedObject.name=<pod-name>

# Resource issues
kubectl top nodes
kubectl top pods
kubectl describe nodes
```

## Study Tips for CKAD

1. **Practice imperative commands** - They're faster in the exam
2. **Use kubectl explain** - `kubectl explain deployment.spec.strategy`
3. **Generate YAML templates** - `kubectl create deployment --dry-run=client -o yaml`
4. **Know the shortcuts** - `deploy`, `rs`, `po`, `svc`
5. **Practice typing** - Speed matters in the exam
6. **Bookmark the docs** - You can use https://kubernetes.io/docs during exam
7. **Use kubectl cheat sheet** - Allowed during exam

## Additional Resources

- [Kubernetes Deployments Documentation](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Rolling Update Strategy](https://kubernetes.io/docs/tutorials/kubernetes-basics/update/update-intro/)
- [Configure Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/)

## Cleanup

```bash
kubectl delete deployment,svc -l kubernetes.courselabs.co=deployments-ckad
```

---

> Return to [basic deployments lab](README.md) | Check [solution examples](solution-ckad.md)
