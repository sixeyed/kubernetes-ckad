# Productionizing - CKAD Requirements

This document covers the CKAD (Certified Kubernetes Application Developer) exam requirements for production-ready applications, building on the basics covered in [README.md](README.md).

## CKAD Exam Requirements

The CKAD exam expects you to understand and implement:
- Liveness, readiness, and startup probes (HTTP, TCP, exec)
- Resource requests and limits (CPU and memory)
- Horizontal Pod Autoscaling (HPA) based on CPU/memory
- Security contexts (Pod and container level)
- Service accounts and RBAC basics
- Quality of Service (QoS) classes
- Resource quotas and limit ranges
- Pod disruption budgets
- Pod priority and preemption
- Graceful termination and lifecycle hooks

## Health Probes

Health probes are critical for production workloads to ensure applications are healthy and ready to serve traffic.

### Probe Types

Kubernetes supports three types of health checks:

1. **Liveness Probe** - Determines if container should be restarted
2. **Readiness Probe** - Determines if Pod should receive traffic
3. **Startup Probe** - Allows slow-starting containers extra time before liveness checks begin

### Probe Mechanisms

Each probe type can use three different mechanisms:

#### HTTP GET Probe

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: http-probe
spec:
  containers:
  - name: app
    image: myapp:latest
    ports:
    - containerPort: 8080
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
        httpHeaders:
        - name: Custom-Header
          value: Awesome
      initialDelaySeconds: 3
      periodSeconds: 10
      timeoutSeconds: 1
      successThreshold: 1
      failureThreshold: 3
```

#### TCP Socket Probe

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: tcp-probe
spec:
  containers:
  - name: database
    image: postgres:14
    ports:
    - containerPort: 5432
    readinessProbe:
      tcpSocket:
        port: 5432
      initialDelaySeconds: 5
      periodSeconds: 10
```

#### Exec Command Probe

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: exec-probe
spec:
  containers:
  - name: app
    image: myapp:latest
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 5
      periodSeconds: 5
```

### Probe Configuration Parameters

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 15   # Wait before first check
  periodSeconds: 10         # How often to check
  timeoutSeconds: 1         # Request timeout
  successThreshold: 1       # Consecutive successes to be considered healthy
  failureThreshold: 3       # Consecutive failures before action taken
```

### Readiness Probe

Removes Pod from Service endpoints when unhealthy (doesn't restart):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: web
        image: nginx:alpine
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
          failureThreshold: 3
```

**Behavior:**
- Probe fails → Pod removed from Service endpoints
- Probe succeeds → Pod added back to Service endpoints
- Container continues running

### Liveness Probe

Restarts container when unhealthy:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: web
        image: nginx:alpine
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /healthz
            port: 80
          initialDelaySeconds: 15
          periodSeconds: 20
          failureThreshold: 3
```

**Behavior:**
- Probe fails → Container restarted
- Restart count increments
- Subject to backoff delay (10s, 20s, 40s, ... up to 5 minutes)

### Startup Probe

Allows slow-starting containers more time:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: slow-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: slow-app
  template:
    metadata:
      labels:
        app: slow-app
    spec:
      containers:
      - name: app
        image: slow-starting-app:latest
        ports:
        - containerPort: 8080
        startupProbe:
          httpGet:
            path: /startup
            port: 8080
          initialDelaySeconds: 0
          periodSeconds: 10
          failureThreshold: 30  # 30 * 10 = 300 seconds (5 minutes) max
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          periodSeconds: 10
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          periodSeconds: 5
```

**Behavior:**
- Startup probe runs first
- Liveness and readiness probes disabled until startup succeeds
- If startup fails within window → container restarted

**Example: Startup Probe Preventing Premature Liveness Failures**

📋 Deploy the startup probe demo to see how it prevents liveness probe failures during slow startup.

```bash
# Deploy the slow-starting application
kubectl apply -f labs/productionizing/specs/ckad/startup-probe-demo.yaml

# Watch the pod starting up
kubectl get pods -l app=slow-start -w
```

The app takes 45 seconds to start. Without a startup probe, the liveness probe would check immediately and fail, causing a restart loop. With the startup probe:

```bash
# Check probe status
kubectl describe pod -l app=slow-start | grep -A 10 Probes

# View events showing startup probe in action
kubectl get events --field-selector involvedObject.name=slow-start-app --sort-by='.lastTimestamp'
```

**Expected behavior:**
- Startup probe checks every 5 seconds for up to 90 seconds (18 failures allowed)
- After 45 seconds, `/tmp/ready` file is created and startup succeeds
- Only then does the liveness probe begin checking
- Container starts successfully without premature restarts

**Cleanup:**

```bash
kubectl delete -f labs/productionizing/specs/ckad/startup-probe-demo.yaml
```

### Combined Probe Strategy

Best practice for production applications:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: production-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: production-app
  template:
    metadata:
      labels:
        app: production-app
    spec:
      containers:
      - name: app
        image: myapp:v1.0
        ports:
        - containerPort: 8080

        # Startup: Allow up to 2 minutes for initialization
        startupProbe:
          httpGet:
            path: /startup
            port: 8080
          periodSeconds: 10
          failureThreshold: 12  # 12 * 10 = 120 seconds

        # Readiness: Check every 5 seconds if ready for traffic
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          periodSeconds: 5
          failureThreshold: 3
          successThreshold: 1

        # Liveness: Check every 10 seconds if alive (less aggressive)
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          periodSeconds: 10
          failureThreshold: 3
          timeoutSeconds: 5
```

**Probe Configuration Decision Matrix**

Choose probe settings based on application characteristics:

| App Type | Startup Time | Startup Probe | Liveness Probe | Readiness Probe |
|----------|--------------|---------------|----------------|-----------------|
| **Fast startup** (< 5s) | Quick | Not needed | `initialDelaySeconds: 5`<br>`periodSeconds: 10`<br>`failureThreshold: 3` | `initialDelaySeconds: 3`<br>`periodSeconds: 5`<br>`failureThreshold: 3` |
| **Medium startup** (5-30s) | Moderate | `periodSeconds: 5`<br>`failureThreshold: 6` (30s) | `periodSeconds: 10`<br>`failureThreshold: 3` | `periodSeconds: 5`<br>`failureThreshold: 3` |
| **Slow startup** (> 30s) | Slow | `periodSeconds: 10`<br>`failureThreshold: 12` (2 min) | `periodSeconds: 15`<br>`failureThreshold: 3` | `periodSeconds: 10`<br>`failureThreshold: 3` |
| **Database** | Variable | `periodSeconds: 10`<br>`failureThreshold: 30` (5 min) | TCP socket<br>`periodSeconds: 10` | TCP socket<br>`periodSeconds: 5` |
| **Batch job** | N/A | Not needed | Exec command<br>`periodSeconds: 30` | Not needed |

**General Guidelines:**
- **Readiness**: Check more frequently (5-10s) to quickly route traffic when ready
- **Liveness**: Check less frequently (10-20s) to avoid false positives
- **Startup**: Allow 2-3x the expected startup time for safety
- **Failure Threshold**: Use 3 for most apps (allows transient failures)

📋 Create a Deployment with all three probe types configured appropriately for a web application.

<details>
  <summary>Not sure how?</summary>

**Solution:**

```bash
# Create a deployment with all three probe types
kubectl apply -f labs/productionizing/specs/ckad/exercise1-health-checks.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=webapp-probes --timeout=120s

# Verify all probes are configured
kubectl describe deployment webapp-probes | grep -A 20 Probes

# Check pod status shows all probes passing
kubectl get pods -l app=webapp-probes

# View probe configuration for a specific pod
PODNAME=$(kubectl get pod -l app=webapp-probes -o jsonpath='{.items[0].metadata.name}')
kubectl get pod $PODNAME -o jsonpath='{.spec.containers[0].startupProbe}' | jq .
kubectl get pod $PODNAME -o jsonpath='{.spec.containers[0].readinessProbe}' | jq .
kubectl get pod $PODNAME -o jsonpath='{.spec.containers[0].livenessProbe}' | jq .

# Test the Service endpoints (should show all 3 pods)
kubectl get endpoints webapp-probes

# Simulate probe failure by deleting a pod - watch it restart gracefully
kubectl delete pod $PODNAME
kubectl get pods -l app=webapp-probes -w
```

**Verification:**
- Startup probe allows 60 seconds for initialization (6 failures × 10s)
- Readiness probe checks every 5 seconds (removes from Service if failing)
- Liveness probe checks every 10 seconds (restarts container if failing)
- All probes use HTTP GET to verify the application is serving traffic

**Cleanup:**

```bash
kubectl delete -f labs/productionizing/specs/ckad/exercise1-health-checks.yaml
```

</details><br/>

## Resource Requests and Limits

Resource management is critical for cluster stability and application performance.

### CPU and Memory Resources

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: resource-demo
spec:
  containers:
  - name: app
    image: myapp:latest
    resources:
      requests:
        memory: "128Mi"    # Guaranteed minimum
        cpu: "250m"        # 0.25 cores
      limits:
        memory: "256Mi"    # Maximum allowed
        cpu: "500m"        # 0.5 cores
```

**Units:**
- CPU: `1000m` = 1 core, `500m` = 0.5 cores, `100m` = 0.1 cores
- Memory: `Mi` (mebibytes), `Gi` (gibibytes), `M` (megabytes), `G` (gigabytes)

### Quality of Service (QoS) Classes

Kubernetes assigns QoS classes based on resource configuration:

#### Guaranteed (Highest Priority)

```yaml
# requests = limits for all containers
resources:
  requests:
    memory: "256Mi"
    cpu: "500m"
  limits:
    memory: "256Mi"
    cpu: "500m"
```

- Highest priority
- Last to be evicted
- Best for critical workloads

#### Burstable (Medium Priority)

```yaml
# At least one container has requests or limits (not all equal)
resources:
  requests:
    memory: "128Mi"
    cpu: "250m"
  limits:
    memory: "256Mi"
    cpu: "500m"
```

- Medium priority
- Can use more than requested if available
- Good for most applications

#### BestEffort (Lowest Priority)

```yaml
# No requests or limits set
resources: {}
```

- Lowest priority
- First to be evicted under pressure
- Only for non-critical workloads

**QoS Class Eviction Order Under Resource Pressure**

When a node runs out of resources, Kubernetes evicts Pods in this order:

1. **BestEffort** - Evicted first
2. **Burstable** - Evicted second (using more than requested)
3. **Burstable** - (within requests)
4. **Guaranteed** - Evicted last (only when critical)

📋 Deploy all three QoS classes and verify their assignment:

```bash
# Deploy all three QoS class examples
kubectl apply -f labs/productionizing/specs/ckad/qos-guaranteed.yaml
kubectl apply -f labs/productionizing/specs/ckad/qos-burstable.yaml
kubectl apply -f labs/productionizing/specs/ckad/qos-besteffort.yaml

# Check QoS class assignment
kubectl get pod qos-guaranteed -o jsonpath='{.status.qosClass}'   # Output: Guaranteed
kubectl get pod qos-burstable -o jsonpath='{.status.qosClass}'    # Output: Burstable
kubectl get pod qos-besteffort -o jsonpath='{.status.qosClass}'   # Output: BestEffort

# View all pods with their QoS classes
kubectl get pods -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass,CPU-REQUEST:.spec.containers[0].resources.requests.cpu,CPU-LIMIT:.spec.containers[0].resources.limits.cpu

# Check detailed resource configuration
kubectl describe pod qos-guaranteed | grep -A 10 "Limits\|Requests"
```

**Expected Output:**
- `qos-guaranteed`: QoS Class = **Guaranteed** (requests = limits)
- `qos-burstable`: QoS Class = **Burstable** (requests < limits)
- `qos-besteffort`: QoS Class = **BestEffort** (no resources specified)

**Cleanup:**

```bash
kubectl delete pod qos-guaranteed qos-burstable qos-besteffort
```

### Checking QoS Class

```bash
kubectl get pod mypod -o jsonpath='{.status.qosClass}'
```

📋 Create three Pods with different QoS classes and verify their classification.

<details>
  <summary>Not sure how?</summary>

**Solution:**

```bash
# Deploy all three QoS class deployments
kubectl apply -f labs/productionizing/specs/ckad/exercise2-qos-stress.yaml

# Wait for all pods to be running
kubectl wait --for=condition=ready pod -l kubernetes.courselabs.co=productionizing --timeout=60s

# Verify QoS class for each deployment
echo "=== Guaranteed App ==="
kubectl get pods -l app=guaranteed-app -o jsonpath='{.items[0].status.qosClass}'
echo ""

echo "=== Burstable App ==="
kubectl get pods -l app=burstable-app -o jsonpath='{.items[0].status.qosClass}'
echo ""

echo "=== BestEffort App ==="
kubectl get pods -l app=besteffort-app -o jsonpath='{.items[0].status.qosClass}'
echo ""

# View resource allocation
kubectl get pods -o custom-columns=\
NAME:.metadata.name,\
QOS:.status.qosClass,\
CPU-REQ:.spec.containers[0].resources.requests.cpu,\
CPU-LIM:.spec.containers[0].resources.limits.cpu,\
MEM-REQ:.spec.containers[0].resources.requests.memory,\
MEM-LIM:.spec.containers[0].resources.limits.memory

# Create memory pressure to observe eviction behavior (optional - may affect cluster)
# kubectl apply -f labs/productionizing/specs/ckad/exercise2-qos-stress.yaml
# Watch which pods get evicted first (BestEffort → Burstable → Guaranteed)
# kubectl get pods -w
```

**Expected QoS Classes:**
- `guaranteed-app` pods: **Guaranteed** (requests = limits for both CPU and memory)
- `burstable-app` pods: **Burstable** (requests < limits)
- `besteffort-app` pods: **BestEffort** (no resources specified)

**Under memory pressure:**
1. BestEffort pods evicted first
2. Burstable pods evicted next (those exceeding requests)
3. Guaranteed pods evicted only in extreme cases

**Cleanup:**

```bash
kubectl delete -f labs/productionizing/specs/ckad/exercise2-qos-stress.yaml
```

</details><br/>

### Resource Behavior

**Memory:**
- Exceeding memory limit → Pod OOMKilled (Out of Memory)
- Cannot be compressed or throttled

**CPU:**
- Exceeding CPU limit → Throttled (not killed)
- Can be compressed
- Performance degrades but Pod continues

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: stress-test
spec:
  containers:
  - name: stress
    image: polinux/stress
    command: ["stress"]
    args:
    - "--vm"
    - "1"
    - "--vm-bytes"
    - "150M"  # Try to allocate 150Mi
    - "--vm-hang"
    - "1"
    resources:
      requests:
        memory: "100Mi"
      limits:
        memory: "128Mi"  # Will be OOMKilled
```

**Hands-On: OOMKilled vs CPU Throttling**

📋 Deploy pods that demonstrate the difference between memory and CPU limit enforcement:

```bash
# Deploy both memory and CPU limit demos
kubectl apply -f labs/productionizing/specs/ckad/memory-limit-demo.yaml

# Watch the OOM pod - it will be killed when exceeding memory limit
kubectl get pods -l kubernetes.courselabs.co=productionizing -w
```

**Memory Limit (OOMKilled):**

```bash
# Check the OOM demo pod status
kubectl get pod oom-demo

# View the termination reason (OOMKilled)
kubectl describe pod oom-demo | grep -A 5 "Last State"

# See the exit code (137 = killed by SIGKILL)
kubectl get pod oom-demo -o jsonpath='{.status.containerStatuses[0].lastState.terminated}'
```

**Expected output:**
```
Reason: OOMKilled
Exit Code: 137
```

**CPU Limit (Throttled, Not Killed):**

```bash
# Check the CPU throttle demo pod - it stays running
kubectl get pod cpu-throttle-demo

# Pod continues running despite CPU pressure
kubectl describe pod cpu-throttle-demo | grep -A 5 State

# Check CPU throttling metrics (if metrics server available)
kubectl top pod cpu-throttle-demo
```

**Expected behavior:**
```
NAME                 CPU    MEMORY
cpu-throttle-demo    500m   8Mi
```

The pod stays running but CPU usage is capped at 500m (0.5 cores).

**Key Differences:**

| Resource | Exceeds Limit | Action | Pod Status |
|----------|---------------|--------|------------|
| **Memory** | Yes | **OOMKilled** | Terminated & Restarted |
| **CPU** | Yes | **Throttled** | Continues Running |

**Cleanup:**

```bash
kubectl delete -f labs/productionizing/specs/ckad/memory-limit-demo.yaml
```

## Horizontal Pod Autoscaling (HPA)

Automatically scale replicas based on metrics.

### CPU-Based Autoscaling

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70  # Target 70% of requested CPU
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 15
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      - type: Pods
        value: 4
        periodSeconds: 15
      selectPolicy: Max
```

**Prerequisites:**
- Metrics Server must be installed
- Pods must have resource requests defined
- Target resource must be a Deployment, ReplicaSet, or StatefulSet

### Memory-Based Autoscaling

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: memory-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: memory-intensive-app
  minReplicas: 2
  maxReplicas: 8
  metrics:
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80  # Target 80% of requested memory
```

### Multiple Metrics

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: multi-metric-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  # CPU metric
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  # Memory metric
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  # Custom metric (requires custom metrics API)
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: "1000"
```

> When multiple metrics are specified, HPA calculates desired replicas for each metric and uses the highest value.

### Legacy v1 API

```yaml
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: simple-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 1
  maxReplicas: 5
  targetCPUUtilizationPercentage: 50
```

### HPA Behavior Configuration

Control scale-up and scale-down rates:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: controlled-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # Wait 5 minutes before scaling down
      policies:
      - type: Pods
        value: 1
        periodSeconds: 60  # Max 1 pod per minute
      - type: Percent
        value: 10
        periodSeconds: 60  # Max 10% per minute
      selectPolicy: Min  # Use most conservative policy
    scaleUp:
      stabilizationWindowSeconds: 0  # Scale up immediately
      policies:
      - type: Pods
        value: 2
        periodSeconds: 30  # Max 2 pods per 30 seconds
      - type: Percent
        value: 50
        periodSeconds: 30  # Max 50% per 30 seconds
      selectPolicy: Max  # Use most aggressive policy
```

**HPA Behavior During Load Spike**

📋 See HPA in action with the exercise3 load testing example:

```bash
# Deploy application with HPA
kubectl apply -f labs/productionizing/specs/ckad/exercise3-hpa-load.yaml

# Check initial state - should have 2 replicas
kubectl get hpa scalable-app-hpa
kubectl get deployment scalable-app

# Monitor HPA status (wait ~1 minute for metrics to populate)
kubectl get hpa scalable-app-hpa -w
```

**Initial state:**
```
NAME               REFERENCE                TARGETS   MINPODS   MAXPODS   REPLICAS
scalable-app-hpa   Deployment/scalable-app  0%/70%    2         10        2
```

**Generate load:**

```bash
# The load-generator pod continuously requests the service
kubectl logs -f load-generator

# Watch scaling occur
kubectl get pods -l app=scalable-app -w
```

**Observed behavior:**

1. **Load increases** → CPU utilization rises above 70%
2. **HPA scales up** → Adds replicas (up to 100% increase per 15s)
3. **Load distributes** → CPU per pod decreases
4. **Steady state** → Maintains target utilization
5. **Load stops** → After 5 minutes (stabilizationWindow), scales down gradually

**View scaling events:**

```bash
kubectl describe hpa scalable-app-hpa | grep -A 10 Events
```

**Expected events:**
```
Normal  SuccessfulRescale  HorizontalPodAutoscaler  New size: 4; reason: cpu resource utilization above target
Normal  SuccessfulRescale  HorizontalPodAutoscaler  New size: 6; reason: cpu resource utilization above target
```

**Cleanup:**

```bash
kubectl delete -f labs/productionizing/specs/ckad/exercise3-hpa-load.yaml
```

### Installing Metrics Server

```bash
# Check if metrics server is available
kubectl top nodes

# Install if not available
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# For development clusters (Docker Desktop, minikube), may need insecure TLS:
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
```

📋 Create an HPA that scales a Deployment between 3 and 10 replicas based on 60% CPU utilization.

<details>
  <summary>Not sure how?</summary>

**Solution:**

```bash
# Deploy the complete HPA exercise with load generator
kubectl apply -f labs/productionizing/specs/ckad/exercise3-hpa-load.yaml

# Wait for initial deployment
kubectl wait --for=condition=ready pod -l app=scalable-app --timeout=120s

# Check HPA status (wait ~1 minute for metrics)
kubectl get hpa scalable-app-hpa

# Verify resource requests are set (required for HPA)
kubectl describe deployment scalable-app | grep -A 5 "Limits\|Requests"

# Start the load generator (already defined in the YAML)
kubectl logs -f load-generator

# In another terminal, watch HPA scaling decisions
kubectl get hpa scalable-app-hpa -w

# Watch pods scaling up
kubectl get pods -l app=scalable-app -w

# View HPA metrics and conditions
kubectl describe hpa scalable-app-hpa

# Check current CPU utilization
kubectl top pods -l app=scalable-app
```

**Expected scaling behavior:**

1. **Initial**: 2 replicas, low CPU usage
2. **Load starts**: CPU rises above 70% target
3. **Scale up**: HPA increases to 4, 6, 8, or 10 replicas (max)
4. **Stop load**: Delete load-generator pod
   ```bash
   kubectl delete pod load-generator
   ```
5. **Scale down**: After 5 minutes, gradually reduces to 2 replicas (min)

**Verification checklist:**
- ✓ HPA shows current/target CPU utilization
- ✓ Deployment scales between minReplicas (2) and maxReplicas (10)
- ✓ Resource requests defined (200m CPU)
- ✓ Scaling events visible in `kubectl describe hpa`

**Troubleshooting:**

If HPA shows `<unknown>/70%`:
```bash
# Check metrics server
kubectl top nodes

# If not available, install metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

**Cleanup:**

```bash
kubectl delete -f labs/productionizing/specs/ckad/exercise3-hpa-load.yaml
```

</details><br/>

### HPA Troubleshooting

```bash
# Check HPA status
kubectl get hpa
kubectl describe hpa web-app-hpa

# Check metrics
kubectl top pods
kubectl top nodes

# View HPA events
kubectl get events --field-selector involvedObject.kind=HorizontalPodAutoscaler

# Common issues:
# - "missing request for cpu" - Pod spec needs resources.requests.cpu
# - "unable to get metrics" - Metrics server not installed or not working
# - "failed to get cpu utilization" - Pod not ready or just started
```

**Common HPA Issues and Resolutions**

**Issue 1: HPA shows `<unknown>/70%` for metrics**

```bash
# Symptom
kubectl get hpa
# NAME     REFERENCE          TARGETS         MINPODS   MAXPODS   REPLICAS
# my-hpa   Deployment/my-app  <unknown>/70%   1         5         1

# Root cause: Metrics server not available or pods not ready
# Resolution:
kubectl top nodes  # Verify metrics server works
kubectl get pods   # Ensure pods are Running and Ready

# If metrics server missing:
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

**Issue 2: "missing request for cpu" error**

```bash
# Check HPA status
kubectl describe hpa my-hpa
# Error: missing request for cpu

# Root cause: Pod spec doesn't define resources.requests.cpu
# Resolution: Add resource requests to your deployment
kubectl patch deployment my-app -p '{"spec":{"template":{"spec":{"containers":[{"name":"app","resources":{"requests":{"cpu":"200m"}}}]}}}}'
```

**Issue 3: HPA not scaling up despite high CPU**

```bash
# Check current replicas vs max
kubectl get hpa
# Verify not at maxReplicas

# Check if PDB is blocking
kubectl get pdb
kubectl describe pdb my-pdb

# Check for resource constraints
kubectl describe nodes | grep -A 5 "Allocated resources"
```

See [Scenario 4](#scenario-4-hpa-not-scaling) for a complete troubleshooting example.

## Security Contexts

Define privilege and access control settings for Pods and containers.

### Pod-Level Security Context

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: security-demo
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
    fsGroupChangePolicy: "OnRootMismatch"
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "sleep 3600"]
```

### Container-Level Security Context

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
spec:
  containers:
  - name: app
    image: nginx:alpine
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
        add:
        - NET_BIND_SERVICE
    volumeMounts:
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
  volumes:
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
```

### Security Context Fields

**Pod Level:**
- `runAsUser` - UID to run containers
- `runAsGroup` - GID to run containers
- `fsGroup` - GID for volume ownership
- `supplementalGroups` - Additional GIDs
- `seccompProfile` - Seccomp profile
- `seLinuxOptions` - SELinux options

**Container Level:**
- `runAsUser` - Override pod-level UID
- `runAsGroup` - Override pod-level GID
- `runAsNonRoot` - Fail if image runs as root
- `readOnlyRootFilesystem` - Make root filesystem read-only
- `allowPrivilegeEscalation` - Allow gaining more privileges
- `privileged` - Run as privileged container
- `capabilities` - Add/drop Linux capabilities

### Capabilities

```yaml
securityContext:
  capabilities:
    drop:
    - ALL  # Drop all capabilities
    add:
    - NET_BIND_SERVICE  # Allow binding to privileged ports
    - CHOWN             # Allow changing file ownership
    - DAC_OVERRIDE      # Override file permissions
```

Common capabilities:
- `NET_BIND_SERVICE` - Bind to ports < 1024
- `NET_ADMIN` - Network administration
- `SYS_TIME` - Set system clock
- `CHOWN` - Change file ownership
- `SETUID`/`SETGID` - Set user/group ID
- `KILL` - Send signals to processes

### Read-Only Root Filesystem

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: readonly-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: readonly-app
  template:
    metadata:
      labels:
        app: readonly-app
    spec:
      containers:
      - name: app
        image: nginx:alpine
        securityContext:
          readOnlyRootFilesystem: true
        volumeMounts:
        # Nginx needs these directories writable
        - name: cache
          mountPath: /var/cache/nginx
        - name: run
          mountPath: /var/run
        - name: tmp
          mountPath: /tmp
      volumes:
      - name: cache
        emptyDir: {}
      - name: run
        emptyDir: {}
      - name: tmp
        emptyDir: {}
```

**Read-Only Filesystem: Errors and Solutions**

📋 See what happens when readOnlyRootFilesystem is used without proper volume mounts:

```bash
# Deploy the broken version (will fail)
kubectl apply -f labs/productionizing/specs/ckad/readonly-filesystem-error.yaml

# Check pod status - readonly-error will fail
kubectl get pod readonly-error

# View the error
kubectl logs readonly-error
kubectl describe pod readonly-error | grep -A 10 Events
```

**Expected error output:**
```
Error: nginx: [emerg] mkdir() "/var/cache/nginx/client_temp" failed (30: Read-only file system)
```

**The problem:** nginx requires write access to:
- `/var/cache/nginx` - for caching
- `/var/run` - for PID files
- `/tmp` - for temporary files

**Check the fixed version:**

```bash
# Deploy the corrected version with writable volumes
kubectl get pod readonly-fixed

# Verify it's running successfully
kubectl get pod readonly-fixed -o jsonpath='{.status.phase}'  # Should be "Running"

# Confirm read-only root filesystem is enforced
kubectl exec readonly-fixed -- touch /test-file
# Output: touch: /test-file: Read-only file system

# But writable volumes work
kubectl exec readonly-fixed -- touch /tmp/test-file
kubectl exec readonly-fixed -- ls /tmp/test-file
```

**Key lesson:** When using `readOnlyRootFilesystem: true`, identify and mount writable volumes for:
- Application cache directories
- Temporary files
- PID/socket files
- Log files (if written locally)

**Cleanup:**

```bash
kubectl delete -f labs/productionizing/specs/ckad/readonly-filesystem-error.yaml
```

### Non-Root User

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nonroot-app
spec:
  securityContext:
    runAsNonRoot: true  # Enforces non-root requirement
    runAsUser: 1000
    runAsGroup: 1000
  containers:
  - name: app
    image: myapp:latest
```

### Security Best Practices

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hardened-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: hardened-app
  template:
    metadata:
      labels:
        app: hardened-app
    spec:
      # Disable automounting SA token
      automountServiceAccountToken: false

      # Pod-level security
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault

      containers:
      - name: app
        image: myapp:latest

        # Container-level security
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL

        # Resource limits
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"

        # Health probes
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          periodSeconds: 5

        volumeMounts:
        - name: tmp
          mountPath: /tmp

      volumes:
      - name: tmp
        emptyDir: {}
```

📋 Create a secure Deployment following all security best practices.

<details>
  <summary>Not sure how?</summary>

**Solution:**

```bash
# Deploy the hardened application
kubectl apply -f labs/productionizing/specs/ckad/exercise4-security-hardening.yaml

# Compare the two deployments
kubectl get deployments -l kubernetes.courselabs.co=productionizing

# Check insecure app (runs as root, writable filesystem)
kubectl get pod -l app=insecure-app -o jsonpath='{.items[0].spec.securityContext}'
# Output: (empty - no security context)

# Check hardened app security settings
kubectl get pod -l app=hardened-app -o jsonpath='{.items[0].spec.securityContext}' | jq .

# Verify container security context
kubectl get pod -l app=hardened-app -o jsonpath='{.items[0].spec.containers[0].securityContext}' | jq .

# Test security enforcement
HARDENED_POD=$(kubectl get pod -l app=hardened-app -o jsonpath='{.items[0].metadata.name}')

# Verify running as non-root
kubectl exec $HARDENED_POD -- id
# Expected: uid=1000 gid=1000

# Verify read-only root filesystem
kubectl exec $HARDENED_POD -- touch /test
# Expected: touch: /test: Read-only file system

# Verify writable volumes work
kubectl exec $HARDENED_POD -- touch /tmp/test
kubectl exec $HARDENED_POD -- ls /tmp/test
# Expected: /tmp/test

# Check Service Account token is not mounted
kubectl exec $HARDENED_POD -- ls /var/run/secrets/kubernetes.io/serviceaccount
# Expected: ls: /var/run/secrets/kubernetes.io/serviceaccount: No such file or directory

# Verify resource limits are set
kubectl describe pod $HARDENED_POD | grep -A 5 "Limits\|Requests"
```

**Security improvements checklist:**
- ✓ **runAsNonRoot: true** - Prevents root execution
- ✓ **runAsUser: 1000** - Specific non-root UID
- ✓ **readOnlyRootFilesystem: true** - Immutable container filesystem
- ✓ **allowPrivilegeEscalation: false** - Prevents privilege gains
- ✓ **capabilities: drop ALL** - Removes all Linux capabilities
- ✓ **automountServiceAccountToken: false** - No K8s API access
- ✓ **Resource limits set** - Prevents resource exhaustion
- ✓ **seccompProfile: RuntimeDefault** - Seccomp filtering enabled

**Cleanup:**

```bash
kubectl delete -f labs/productionizing/specs/ckad/exercise4-security-hardening.yaml
```

</details><br/>

## Service Accounts

Every Pod runs with a service account that determines API access permissions.

### Default Service Account

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: default-sa
spec:
  # Uses default SA in namespace if not specified
  containers:
  - name: app
    image: nginx
```

### Custom Service Account

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
---
apiVersion: v1
kind: Pod
metadata:
  name: custom-sa
spec:
  serviceAccountName: app-sa
  containers:
  - name: app
    image: nginx
```

### Disable Auto-Mount SA Token

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: no-sa-token
spec:
  automountServiceAccountToken: false
  containers:
  - name: app
    image: nginx
```

**Service Account with RBAC Example**

📋 Create a service account with permissions to read pods:

```bash
# Deploy service account with RBAC configuration
kubectl apply -f labs/productionizing/specs/ckad/serviceaccount-rbac.yaml

# Verify the service account was created
kubectl get serviceaccount pod-reader

# Check the role permissions
kubectl describe role pod-reader

# Check the role binding
kubectl describe rolebinding read-pods

# Test the permissions from within the pod
kubectl exec -it pod-reader-test -- bash

# Inside the pod, use kubectl to test permissions
kubectl get pods              # Should work - allowed by role
kubectl get services          # Should fail - not allowed by role
kubectl delete pod nginx      # Should fail - delete not allowed
exit
```

**Expected behavior:**

```bash
# This works (get/list/watch pods allowed)
$ kubectl get pods
NAME              READY   STATUS    RESTARTS   AGE
pod-reader-test   1/1     Running   0          1m

# This fails (services not in role)
$ kubectl get services
Error from server (Forbidden): services is forbidden: User "system:serviceaccount:default:pod-reader" cannot list resource "services"

# This fails (delete not in role verbs)
$ kubectl delete pod nginx
Error from server (Forbidden): pods "nginx" is forbidden: User "system:serviceaccount:default:pod-reader" cannot delete resource "pods"
```

**Verify RBAC configuration:**

```bash
# Check what the service account can do
kubectl auth can-i get pods --as=system:serviceaccount:default:pod-reader      # yes
kubectl auth can-i list pods --as=system:serviceaccount:default:pod-reader     # yes
kubectl auth can-i delete pods --as=system:serviceaccount:default:pod-reader   # no
kubectl auth can-i get services --as=system:serviceaccount:default:pod-reader  # no
```

**Cleanup:**

```bash
kubectl delete -f labs/productionizing/specs/ckad/serviceaccount-rbac.yaml
```

## Resource Quotas

Limit resource consumption at namespace level.

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: dev
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    pods: "50"
    services: "10"
    persistentvolumeclaims: "5"
```

**Resource Quota Enforcement Example**

📋 See how ResourceQuota limits prevent resource overconsumption:

```bash
# Deploy namespace with resource quota
kubectl apply -f labs/productionizing/specs/ckad/resourcequota-demo.yaml

# Check the quota configuration
kubectl describe resourcequota compute-quota -n quota-demo

# Try to deploy the first pod (within quota)
kubectl get pod within-quota -n quota-demo

# Check quota usage
kubectl describe resourcequota compute-quota -n quota-demo
```

**Expected quota status:**

```
Name:            compute-quota
Namespace:       quota-demo
Resource         Used    Hard
--------         ----    ----
limits.cpu       1       4
limits.memory    1Gi     4Gi
pods             1       10
requests.cpu     500m    2
requests.memory  512Mi   2Gi
```

**Try to exceed the quota:**

```bash
# This pod will fail if it would exceed quota
kubectl get pod exceeds-quota -n quota-demo

# If first pod is running, second pod might fail with:
kubectl describe pod exceeds-quota -n quota-demo
```

**Expected error (if quota exceeded):**

```
Error from server (Forbidden): pods "exceeds-quota" is forbidden: exceeded quota: compute-quota,
requested: requests.cpu=2,requests.memory=2Gi, used: requests.cpu=500m,requests.memory=512Mi,
limited: requests.cpu=2,requests.memory=2Gi
```

**Quota prevents:**
- Deploying pods that would exceed total CPU/memory requests
- Creating more pods than allowed
- Requesting more total resources than allocated to namespace

**Key learning:** In namespaces with ResourceQuota, **all pods must specify resource requests and limits**, or they will be rejected.

**Cleanup:**

```bash
kubectl delete namespace quota-demo
```

## Limit Ranges

Set default resource limits for containers in a namespace.

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: limit-range
  namespace: dev
spec:
  limits:
  - max:
      cpu: "2"
      memory: "2Gi"
    min:
      cpu: "100m"
      memory: "128Mi"
    default:
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:
      cpu: "250m"
      memory: "256Mi"
    type: Container
```

**LimitRange Application Example**

📋 See how LimitRange automatically applies defaults and enforces constraints:

```bash
# Deploy namespace with LimitRange
kubectl apply -f labs/productionizing/specs/ckad/limitrange-demo.yaml

# Check the LimitRange configuration
kubectl describe limitrange resource-limits -n limitrange-demo

# Check pod with no resources specified - gets defaults
kubectl get pod default-resources -n limitrange-demo -o jsonpath='{.spec.containers[0].resources}' | jq .
```

**Expected output (defaults applied):**

```json
{
  "limits": {
    "cpu": "500m",
    "memory": "512Mi"
  },
  "requests": {
    "cpu": "250m",
    "memory": "256Mi"
  }
}
```

**Test pods within limits:**

```bash
# Pod within limits - should succeed
kubectl get pod within-limits -n limitrange-demo

# Describe to see resources
kubectl describe pod within-limits -n limitrange-demo | grep -A 5 "Limits\|Requests"
```

**Test pod exceeding limits:**

```bash
# Pod exceeding max - should be rejected
kubectl get pod exceeds-max -n limitrange-demo

# Check why it was rejected
kubectl describe pod exceeds-max -n limitrange-demo
```

**Expected error:**

```
Error from server (Forbidden): error when creating "pod": pods "exceeds-max" is forbidden:
[maximum cpu usage per Container is 2, but limit is 3.]
[maximum memory usage per Container is 2Gi, but limit is 3Gi.]
```

**LimitRange enforces:**
- **min** - Minimum resources required
- **max** - Maximum resources allowed
- **default** - Default limits if not specified
- **defaultRequest** - Default requests if not specified

**Key differences from ResourceQuota:**
- LimitRange = **per-pod** constraints
- ResourceQuota = **total namespace** constraints

**Cleanup:**

```bash
kubectl delete namespace limitrange-demo
```

## Pod Disruption Budgets

Ensure minimum availability during voluntary disruptions.

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-app-pdb
spec:
  minAvailable: 2  # or maxUnavailable: 1
  selector:
    matchLabels:
      app: web-app
```

**PodDisruptionBudget Preventing Node Drain**

📋 Deploy a PDB and see how it protects application availability:

```bash
# Deploy application with PDB
kubectl apply -f labs/productionizing/specs/ckad/pdb-demo.yaml

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod -l app=web-app --timeout=60s

# Check current pod distribution
kubectl get pods -l app=web-app -o wide

# Check PDB status
kubectl get pdb web-app-pdb
kubectl describe pdb web-app-pdb
```

**Expected PDB status:**

```
NAME          MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
web-app-pdb   3               N/A               1                     1m
```

**Simulate node drain (test only - skip in production):**

```bash
# Get node names
kubectl get nodes

# Try to drain a node with pods from our deployment
# Note: This is a dry-run, won't actually drain
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data --dry-run=client

# PDB would prevent draining if it would violate minAvailable
# With 4 replicas and minAvailable=3, only 1 pod can be evicted at a time
```

**How PDB protects:**

1. **Initial state**: 4 pods running, minAvailable=3
2. **Drain starts**: Can evict 1 pod (leaving 3 available) ✓
3. **Try to evict 2nd**: Blocked by PDB (would leave only 2 available) ✗
4. **After new pod ready**: Can evict next pod

**Check PDB conditions:**

```bash
# View PDB events
kubectl get events --field-selector involvedObject.name=web-app-pdb

# Check current disruptions allowed
kubectl get pdb web-app-pdb -o jsonpath='{.status.disruptionsAllowed}'
```

**Alternative PDB using maxUnavailable:**

```bash
# Check the alternative PDB definition
kubectl describe pdb web-app-pdb-max
# maxUnavailable: 1 means at most 1 pod can be unavailable
# Equivalent to minAvailable: 3 (with 4 replicas)
```

**Cleanup:**

```bash
kubectl delete -f labs/productionizing/specs/ckad/pdb-demo.yaml
```

## Pod Priority and Preemption

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000
globalDefault: false
description: "High priority for critical apps"
---
apiVersion: v1
kind: Pod
metadata:
  name: critical-app
spec:
  priorityClassName: high-priority
  containers:
  - name: app
    image: nginx
```

**Pod Priority and Preemption Example**

📋 See how high-priority pods can preempt lower-priority pods when resources are scarce:

```bash
# Deploy priority classes and workloads
kubectl apply -f labs/productionizing/specs/ckad/priority-preemption.yaml

# Check priority classes
kubectl get priorityclass
kubectl describe priorityclass low-priority high-priority

# Check deployed pods
kubectl get pods -l kubernetes.courselabs.co=productionizing -o wide

# View priority assigned to pods
kubectl get pods -o custom-columns=\
NAME:.metadata.name,\
PRIORITY:.spec.priorityClassName,\
PRIORITY-VALUE:.spec.priority,\
STATUS:.status.phase
```

**Expected priority values:**
```
NAME                      PRIORITY       PRIORITY-VALUE   STATUS
low-priority-app-xxx      low-priority   100              Running
low-priority-app-xxx      low-priority   100              Running
critical-app              high-priority  1000             Running/Pending
```

**Preemption scenario (on resource-constrained cluster):**

1. **Low-priority pods running** (using available resources)
2. **High-priority pod created** (no resources available)
3. **Kubernetes preempts** low-priority pods to make room
4. **High-priority pod scheduled** in their place

**View preemption events:**

```bash
# Check events for the high-priority pod
kubectl describe pod critical-app | grep -A 10 Events

# If preemption occurred, you'll see:
# Type    Reason             Message
# Normal  Preempting         Preempting pod low-priority-app-xxx
# Normal  Scheduled          Successfully assigned to node
```

**Check pod status after preemption:**

```bash
# Some low-priority pods may be terminated
kubectl get pods -l app=low-priority

# High-priority pod should be running
kubectl get pod critical-app
```

**Priority classes in system:**

```bash
# System priority classes (pre-installed)
kubectl get priorityclass
# system-cluster-critical (2000000000) - highest
# system-node-critical    (2000001000) - highest
# high-priority           (1000)        - custom
# low-priority            (100)         - custom
```

**Best practices:**
- Use high priority only for truly critical workloads
- Set reasonable resource requests on high-priority pods
- Monitor preemption events to avoid excessive disruption

**Cleanup:**

```bash
kubectl delete -f labs/productionizing/specs/ckad/priority-preemption.yaml
```

## Graceful Termination

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: graceful-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: graceful-app
  template:
    metadata:
      labels:
        app: graceful-app
    spec:
      terminationGracePeriodSeconds: 30
      containers:
      - name: app
        image: myapp:latest
        lifecycle:
          preStop:
            exec:
              command: ["/bin/sh", "-c", "sleep 15"]
```

**Graceful Shutdown Workflow Example**

📋 Deploy an application with proper graceful termination:

```bash
# Deploy application with graceful shutdown configuration
kubectl apply -f labs/productionizing/specs/ckad/graceful-shutdown.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=graceful-app --timeout=60s

# Check the termination configuration
kubectl get pod -l app=graceful-app -o jsonpath='{.items[0].spec.terminationGracePeriodSeconds}'
# Output: 60

# View the preStop hook configuration
kubectl get pod -l app=graceful-app -o jsonpath='{.items[0].spec.containers[0].lifecycle.preStop}' | jq .
```

**Test graceful shutdown:**

```bash
# Delete a pod and watch the shutdown sequence
PODNAME=$(kubectl get pod -l app=graceful-app -o jsonpath='{.items[0].metadata.name}')

# Watch pod status in real-time
kubectl get pod $PODNAME -w &

# Delete the pod
kubectl delete pod $PODNAME

# View the logs during shutdown
kubectl logs $PODNAME -f
```

**Graceful shutdown sequence:**

```
1. DELETE request received
   └─> Pod status changes to Terminating

2. Pod removed from Service endpoints
   └─> No new connections routed to pod

3. preStop hook executes
   └─> Sleeps 15 seconds (drains connections)
   └─> Logs: "Received shutdown signal, waiting for connections to drain..."

4. SIGTERM sent to container
   └─> Application begins shutdown

5. Container has (60s - 15s = 45s) to exit gracefully
   └─> Application saves state, closes connections

6. If still running after 60s total
   └─> SIGKILL sent (forceful termination)
```

**Timeline example:**

```
T+0s:  Pod deletion requested
T+0s:  Pod marked Terminating, removed from Service
T+0s:  preStop hook starts (sleep 15)
T+15s: preStop hook completes
T+15s: SIGTERM sent to main process
T+15-60s: Application handles SIGTERM and exits
T+60s: SIGKILL sent if still running (not graceful)
```

**Verify graceful behavior:**

```bash
# Check events
kubectl describe pod $PODNAME | tail -20

# Expected events:
# Killing  - Stopping container app
# Killing  - Container app preStop hook completed
```

**Key configuration values:**

| Setting | Value | Purpose |
|---------|-------|---------|
| `terminationGracePeriodSeconds` | 60 | Total time allowed for shutdown |
| `preStop sleep` | 15 | Time to drain connections |
| Remaining time | 45s | Application shutdown time |

**Best practices:**
- Set `terminationGracePeriodSeconds` > preStop duration + app shutdown time
- Use preStop to drain connections before SIGTERM
- Ensure application handles SIGTERM properly
- Test shutdown behavior under load

**Cleanup:**

```bash
kubectl delete -f labs/productionizing/specs/ckad/graceful-shutdown.yaml
```

## Lab Exercises

### Exercise 1: Complete Health Check Implementation

Create a Deployment with:
- Startup probe allowing 60 seconds for initialization
- Readiness probe checking HTTP /ready endpoint
- Liveness probe checking HTTP /health endpoint
- Appropriate timing configuration for each

See the complete solution in the [Combined Probe Strategy section](#combined-probe-strategy) above. The solution is provided in `/labs/productionizing/specs/ckad/exercise1-health-checks.yaml`

### Exercise 2: Resource Management and QoS

Create three Deployments demonstrating each QoS class:
1. Guaranteed - requests = limits
2. Burstable - requests < limits
3. BestEffort - no requests or limits

Verify QoS assignment and test resource pressure scenarios.

See the complete solution in the [QoS Classes section](#quality-of-service-qos-classes) above. The solution is provided in `/labs/productionizing/specs/ckad/exercise2-qos-stress.yaml`

### Exercise 3: HPA with Load Testing

Create a Deployment with HPA that:
- Starts with 2 replicas
- Scales up to 10 replicas based on 70% CPU
- Includes resource requests
- Deploy load generator to trigger scaling

See the complete solution in the [HPA section](#horizontal-pod-autoscaling-hpa) above. The solution is provided in `/labs/productionizing/specs/ckad/exercise3-hpa-load.yaml`

### Exercise 4: Security Hardening

Take an insecure Deployment and harden it:
- Run as non-root user
- Read-only root filesystem
- Drop all capabilities
- Disable SA token auto-mount
- Add resource limits

See the complete solution in the [Security Contexts section](#security-contexts) above. The solution is provided in `/labs/productionizing/specs/ckad/exercise4-security-hardening.yaml`

### Exercise 5: Production-Ready Application

Create a complete production-ready Deployment with:
- All three probe types
- Resource requests and limits (Burstable QoS)
- Security contexts (non-root, read-only filesystem)
- HPA for autoscaling
- Multiple replicas
- PodDisruptionBudget

**Solution:**

```bash
# Deploy the complete production-ready application
kubectl apply -f labs/productionizing/specs/ckad/exercise5-production-ready.yaml

# Wait for all resources to be ready
kubectl wait --for=condition=ready pod -l app=production-app --timeout=120s

# Verify deployment configuration
kubectl describe deployment production-app

# Check all three probe types
kubectl get pod -l app=production-app -o jsonpath='{.items[0].spec.containers[0]}' | jq '.startupProbe, .readinessProbe, .livenessProbe'

# Verify QoS class (should be Burstable)
kubectl get pod -l app=production-app -o jsonpath='{.items[0].status.qosClass}'

# Check security context
kubectl get pod -l app=production-app -o jsonpath='{.items[0].spec.securityContext}' | jq .
kubectl get pod -l app=production-app -o jsonpath='{.items[0].spec.containers[0].securityContext}' | jq .

# Verify HPA is working
kubectl get hpa production-app-hpa
kubectl describe hpa production-app-hpa

# Check PDB status
kubectl get pdb production-app-pdb
kubectl describe pdb production-app-pdb

# Test the application
kubectl port-forward svc/production-app 8080:80
# Visit http://localhost:8080

# Verify graceful shutdown
PODNAME=$(kubectl get pod -l app=production-app -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod $PODNAME
kubectl get pod $PODNAME -w  # Watch graceful termination
```

**Production readiness checklist:**

✅ **Health Checks**
- Startup probe: 60s window for initialization
- Readiness probe: Traffic routing control
- Liveness probe: Container health monitoring

✅ **Resources**
- CPU: 250m request, 500m limit
- Memory: 256Mi request, 512Mi limit
- QoS: Burstable (can burst when available)

✅ **Security**
- runAsNonRoot: true
- readOnlyRootFilesystem: true
- capabilities: drop ALL
- automountServiceAccountToken: false
- seccompProfile: RuntimeDefault

✅ **Scaling & Availability**
- 3 replicas minimum
- HPA: scales 3-10 based on CPU (70%) and memory (80%)
- PDB: minAvailable 2 (maintains availability during disruptions)

✅ **Graceful Termination**
- terminationGracePeriodSeconds: 45s
- preStop hook: 15s connection drain
- Total shutdown window: 45s

**Cleanup:**

```bash
kubectl delete -f labs/productionizing/specs/ckad/exercise5-production-ready.yaml
```

## Common CKAD Scenarios

### Scenario 1: Debug Crashing Container

**Problem:** Pod keeps restarting in a crash loop due to an aggressive liveness probe.

```bash
# Deploy the broken application
kubectl apply -f labs/productionizing/specs/ckad/scenario1-crashing-probe.yaml

# Watch the crash loop
kubectl get pods -l app=crash-loop -w

# Check pod status - notice increasing restart count
kubectl get pod -l app=crash-loop
```

**Investigate the issue:**

```bash
# Check pod events
kubectl describe pod -l app=crash-loop | grep -A 20 Events

# You'll see:
# Liveness probe failed
# Killing container
# Container will be restarted
```

**Root cause analysis:**

```bash
# View the liveness probe configuration
kubectl get deployment crash-loop-broken -o jsonpath='{.spec.template.spec.containers[0].livenessProbe}' | jq .
```

**Problem identified:**
- `initialDelaySeconds: 5` - Too short for app to start
- `failureThreshold: 2` - Too aggressive (only 10s total before restart)
- App takes ~30s to start but probe starts checking at 5s
- Probe fails → container killed → restart loop

**Apply the fix:**

```bash
# Deploy the fixed version with startup probe
kubectl apply -f labs/productionizing/specs/ckad/scenario1-crashing-probe.yaml

# Watch the fixed pod - should start successfully
kubectl get pods -l app=crash-loop-fixed -w

# Verify no restarts
kubectl get pod -l app=crash-loop-fixed
# RESTARTS column should be 0
```

**Solution summary:**
- Added **startup probe** to allow 60s for initialization
- Liveness probe only starts after startup succeeds
- No more premature restarts

**Key lesson:** Use startup probes for applications with slow initialization to prevent liveness probe false positives.

**Cleanup:**

```bash
kubectl delete -f labs/productionizing/specs/ckad/scenario1-crashing-probe.yaml
```

### Scenario 2: Fix OOMKilled Pods

**Problem:** Pods are being terminated with OOMKilled status due to insufficient memory limits.

```bash
# Deploy the broken application
kubectl apply -f labs/productionizing/specs/ckad/scenario2-oom-fix.yaml

# Watch the pod status
kubectl get pods -l app=oom-app -w
```

**Identify OOMKilled status:**

```bash
# Check pod status
kubectl get pod -l app=oom-app

# You'll see status like:
# NAME            READY   STATUS      RESTARTS   AGE
# oom-broken-xxx  0/1     OOMKilled   3          2m

# Check the last termination reason
kubectl describe pod -l app=oom-app | grep -A 10 "Last State"
```

**Expected output:**

```
Last State:     Terminated
  Reason:       OOMKilled
  Exit Code:    137
  Started:      ...
  Finished:     ...
```

**Check memory configuration:**

```bash
# View resource limits
kubectl describe deployment oom-broken | grep -A 5 "Limits\|Requests"

# Output shows:
# Limits:
#   memory:  128Mi    ← Too low!
# Requests:
#   memory:  64Mi
```

**Analyze memory usage:**

```bash
# If pod is running briefly, check actual usage
kubectl top pod -l app=oom-app

# Check metrics to understand actual memory needs
kubectl describe node | grep -A 10 "Non-terminated Pods"
```

**Apply the fix:**

```bash
# The fixed version has increased memory limits
kubectl get deployment oom-fixed -o jsonpath='{.spec.template.spec.containers[0].resources}' | jq .

# Output shows:
# {
#   "limits": {
#     "cpu": "200m",
#     "memory": "512Mi"    ← Increased!
#   },
#   "requests": {
#     "cpu": "100m",
#     "memory": "256Mi"    ← Increased!
#   }
# }

# Check that fixed version is running
kubectl get pod -l app=oom-app-fixed
# Should show Running status with 0 restarts
```

**Solution summary:**
- Identified OOMKilled status (exit code 137)
- Increased memory requests: 64Mi → 256Mi
- Increased memory limits: 128Mi → 512Mi
- Based on actual application requirements

**Key lessons:**
- Monitor memory usage with `kubectl top`
- Memory exceeds limit → OOMKilled (cannot be throttled)
- Always set realistic memory limits based on testing
- Include headroom for spikes

**Cleanup:**

```bash
kubectl delete -f labs/productionizing/specs/ckad/scenario2-oom-fix.yaml
```

### Scenario 3: Application Not Receiving Traffic

**Problem:** Service exists and pods are running, but no traffic reaches the application.

```bash
# Deploy the broken application
kubectl apply -f labs/productionizing/specs/ckad/scenario3-no-traffic.yaml

# Pods appear to be running
kubectl get pods -l app=no-traffic

# But Service has no endpoints
kubectl get endpoints no-traffic-broken
```

**Investigate the issue:**

```bash
# Service exists
kubectl get svc no-traffic-broken

# Pods are running but not Ready
kubectl get pods -l app=no-traffic -o wide
# READY column shows 0/1

# Check why pods aren't ready
kubectl describe pod -l app=no-traffic | grep -A 10 "Readiness"
```

**Expected output:**

```
Readiness:  http-get http://:80/ready delay=0s timeout=1s period=5s
Readiness probe failed: HTTP probe failed with statuscode: 404
```

**Root cause identified:**

```bash
# Check the readiness probe path
kubectl get deployment no-traffic-broken -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}' | jq .

# Output shows:
# {
#   "httpGet": {
#     "path": "/ready",    ← This path doesn't exist!
#     "port": 80
#   },
#   "periodSeconds": 5,
#   "failureThreshold": 3
# }
```

**Problem:** Readiness probe checks `/ready` but nginx only serves `/`

**Verify Service endpoints are empty:**

```bash
# No endpoints registered because pods aren't ready
kubectl get endpoints no-traffic-broken
# ENDPOINTS: <none>

# Service can't route traffic without endpoints
kubectl describe svc no-traffic-broken
```

**Apply the fix:**

```bash
# Deploy the fixed version
# Fixed readiness probe checks "/" instead of "/ready"

# Verify pods are now ready
kubectl get pods -l app=no-traffic-fixed
# READY column shows 1/1

# Check endpoints are populated
kubectl get endpoints no-traffic-fixed
# ENDPOINTS: 10.1.2.3:80,10.1.2.4:80,10.1.2.5:80

# Test the service
kubectl run test-pod --image=busybox --rm -it --restart=Never -- \
  wget -qO- http://no-traffic-fixed
```

**Expected:** You should receive nginx welcome page.

**Solution summary:**
- Readiness probe was checking wrong path
- Changed from `/ready` (404) to `/` (200)
- Pods now pass readiness checks
- Service endpoints populated
- Traffic flows correctly

**Key lessons:**
- **Pods Running ≠ Pods Ready**
- Readiness probe failures remove pod from Service endpoints
- Always verify readiness probe path exists
- Check `kubectl get endpoints` to diagnose traffic issues
- Use `kubectl describe pod` to see probe failures

**Traffic flow requirements:**
1. ✅ Pod Running
2. ✅ Readiness probe passing
3. ✅ Pod added to Service endpoints
4. ✅ Traffic routes to pod

**Cleanup:**

```bash
kubectl delete -f labs/productionizing/specs/ckad/scenario3-no-traffic.yaml
```

### Scenario 4: HPA Not Scaling

**Problem:** HPA is configured but not scaling the deployment despite high load.

```bash
# Deploy the broken HPA configuration
kubectl apply -f labs/productionizing/specs/ckad/scenario4-hpa-not-scaling.yaml

# Check HPA status
kubectl get hpa hpa-broken
```

**Symptom:**

```
NAME         REFERENCE              TARGETS         MINPODS   MAXPODS   REPLICAS
hpa-broken   Deployment/hpa-broken  <unknown>/50%   1         5         1
```

**Notice:** TARGETS shows `<unknown>/50%` - HPA can't get metrics!

**Investigate the issue:**

```bash
# Describe HPA for detailed error messages
kubectl describe hpa hpa-broken

# Look for error messages:
# Warning  FailedGetResourceMetric  missing request for cpu
# Warning  FailedComputeMetricsReplicas  failed to get cpu utilization
```

**Check pod resource configuration:**

```bash
# View container resources
kubectl get deployment hpa-broken -o jsonpath='{.spec.template.spec.containers[0].resources}' | jq .

# Output:
# {}   ← No resources defined!
```

**Root cause:** HPA requires `resources.requests.cpu` to calculate utilization percentage, but none are defined.

**Verify metrics server is working:**

```bash
# Ensure metrics server is available
kubectl top nodes
kubectl top pods

# If these work, metrics server is fine
# The problem is missing resource requests
```

**Apply the fix:**

```bash
# The fixed version includes resource requests
kubectl get deployment hpa-fixed -o jsonpath='{.spec.template.spec.containers[0].resources}' | jq .

# Output shows:
# {
#   "requests": {
#     "cpu": "200m",      ← Required for HPA!
#     "memory": "128Mi"
#   },
#   "limits": {
#     "cpu": "500m",
#     "memory": "256Mi"
#   }
# }

# Check HPA status now
kubectl get hpa hpa-fixed

# After ~1 minute, should show actual metrics:
# NAME        REFERENCE             TARGETS   MINPODS   MAXPODS   REPLICAS
# hpa-fixed   Deployment/hpa-fixed  15%/50%   1         5         1
```

**Generate load to test scaling:**

```bash
# Create load generator
kubectl run -it --rm load-generator --image=busybox --restart=Never -- sh -c \
  "while true; do wget -q -O- http://hpa-fixed; done"

# Watch HPA scale up
kubectl get hpa hpa-fixed -w

# Watch deployment scale
kubectl get deployment hpa-fixed -w
```

**Expected behavior:**
1. CPU utilization rises above 50%
2. HPA calculates desired replicas
3. Deployment scales up (1 → 2 → 3 → up to 5)
4. Load distributes across more pods
5. CPU per pod drops below target

**Solution summary:**
- HPA requires `resources.requests.cpu` to calculate % utilization
- Added CPU request: 200m
- HPA now shows actual CPU metrics
- Scaling works correctly

**Common HPA issues:**

| Symptom | Cause | Solution |
|---------|-------|----------|
| `<unknown>/X%` | No resource requests | Add `resources.requests.cpu` |
| `unable to get metrics` | Metrics server missing | Install metrics server |
| `failed to get cpu utilization` | Pods not ready | Wait for pods to start |
| Not scaling up | Already at maxReplicas | Increase maxReplicas |
| Not scaling down | Within stabilization window | Wait (default 5 min) |

**Cleanup:**

```bash
kubectl delete -f labs/productionizing/specs/ckad/scenario4-hpa-not-scaling.yaml
```

### Scenario 5: Security Context Preventing Startup

**Problem:** Pod fails to start due to security context restrictions incompatible with the container image.

```bash
# Deploy the broken security configuration
kubectl apply -f labs/productionizing/specs/ckad/scenario5-security-startup-failure.yaml

# Check pod status
kubectl get pod security-broken
```

**Symptom:**

```
NAME              READY   STATUS                  RESTARTS   AGE
security-broken   0/1     CreateContainerError    0          10s
```

**Investigate the errors:**

```bash
# Check pod events
kubectl describe pod security-broken | grep -A 20 Events

# Look for error messages
kubectl get pod security-broken -o jsonpath='{.status.containerStatuses[0].state}' | jq .
```

**Expected errors:**

```
Error: container has runAsNonRoot and image will run as root
Error: failed to create containerd task: failed to create shim: OCI runtime create failed:
  container_linux.go: starting container process caused:
  exec: "/docker-entrypoint.sh": permission denied: unknown
```

**Root cause analysis:**

```bash
# Check the security context
kubectl get pod security-broken -o jsonpath='{.spec.securityContext}' | jq .

# Output:
# {
#   "runAsNonRoot": true,
#   "runAsUser": 1000
# }

# Check the container image
kubectl get pod security-broken -o jsonpath='{.spec.containers[0].image}'
# nginx:alpine    ← This image runs as root (UID 0) by default!
```

**Problems identified:**

1. **Image incompatibility:** nginx:alpine runs as root, but `runAsNonRoot: true` prevents this
2. **Read-only filesystem:** nginx needs to write to `/var/cache/nginx`, `/var/run`, `/tmp`
3. **Missing volumes:** No writable volumes provided for required directories

**Apply the fix:**

```bash
# The fixed version uses nginxinc/nginx-unprivileged
kubectl get pod security-fixed -o jsonpath='{.spec.containers[0].image}'
# nginxinc/nginx-unprivileged:alpine    ← Runs as non-root!

# Check it's running successfully
kubectl get pod security-fixed
# STATUS: Running

# Verify security settings are enforced
kubectl exec security-fixed -- id
# uid=1000 gid=1000 groups=1000

# Verify read-only root filesystem
kubectl exec security-fixed -- touch /test
# touch: /test: Read-only file system    ← Good!

# Verify writable volumes work
kubectl exec security-fixed -- touch /tmp/test
kubectl exec security-fixed -- ls /tmp/test
# /tmp/test    ← Works!

# Test the application
kubectl port-forward security-fixed 8080:8080
# Visit http://localhost:8080 - nginx welcome page
```

**Solution summary:**

| Issue | Broken | Fixed |
|-------|--------|-------|
| **Image** | nginx:alpine (root) | nginxinc/nginx-unprivileged:alpine (UID 1000) |
| **Port** | 80 (privileged) | 8080 (unprivileged) |
| **Writable volumes** | None | /var/cache/nginx, /var/run, /tmp |
| **Security context** | Incompatible | Compatible |

**Key lessons:**

1. **Choose security-compatible images:**
   - Use images designed for non-root (unprivileged variants)
   - Or configure image to support non-root

2. **readOnlyRootFilesystem requirements:**
   - Identify directories the app needs to write
   - Mount emptyDir volumes for those paths

3. **Common image alternatives:**
   - `nginx` → `nginxinc/nginx-unprivileged`
   - `redis` → `bitnami/redis`
   - `postgres` → `bitnami/postgresql`
   - Or build custom images with non-root USER

4. **Debugging steps:**
   - Check `kubectl describe pod` for error messages
   - Verify image user matches security context
   - Ensure writable volumes for required paths
   - Test with `kubectl exec` after startup

**Prevention checklist:**

Before applying strict security contexts:
- ✅ Verify image supports non-root execution
- ✅ Identify writable directories needed
- ✅ Mount emptyDir volumes for write paths
- ✅ Use unprivileged ports (> 1024)
- ✅ Test in development first

**Cleanup:**

```bash
kubectl delete -f labs/productionizing/specs/ckad/scenario5-security-startup-failure.yaml
```

## Best Practices for CKAD

1. **Health Probes**
   - Always use readiness probes in production
   - Use liveness probes carefully (avoid false positives)
   - Add startup probes for slow-starting apps
   - Use different paths for different probe types

2. **Resources**
   - Always set requests and limits
   - Start conservative, tune based on monitoring
   - Aim for Burstable QoS for most apps
   - Use Guaranteed QoS for critical workloads

3. **Autoscaling**
   - Set minReplicas >= 2 for availability
   - Configure behavior for gradual scale-down
   - Test HPA with realistic load
   - Monitor HPA decisions

4. **Security**
   - Run as non-root whenever possible
   - Use read-only root filesystem
   - Drop ALL capabilities, add only what's needed
   - Disable SA token auto-mount unless needed
   - Use specific user/group IDs

5. **Availability**
   - Use multiple replicas
   - Configure PodDisruptionBudgets
   - Set appropriate terminationGracePeriodSeconds
   - Use preStop hooks for graceful shutdown

## Quick Reference Commands

```bash
# Health Probes
kubectl describe pod mypod | grep -A 10 Liveness
kubectl describe pod mypod | grep -A 10 Readiness

# Resources
kubectl top pods
kubectl top nodes
kubectl describe pod mypod | grep -A 5 Limits
kubectl get pod mypod -o jsonpath='{.status.qosClass}'

# HPA
kubectl get hpa
kubectl describe hpa myhpa
kubectl autoscale deployment myapp --min=2 --max=10 --cpu-percent=70

# Security
kubectl exec mypod -- whoami
kubectl exec mypod -- id
kubectl get pod mypod -o jsonpath='{.spec.securityContext}'
kubectl get pod mypod -o jsonpath='{.spec.containers[0].securityContext}'

# Service Accounts
kubectl get sa
kubectl describe sa mysa
kubectl get pod mypod -o jsonpath='{.spec.serviceAccountName}'

# Resource Quotas
kubectl get resourcequota
kubectl describe resourcequota myquota

# Limit Ranges
kubectl get limitrange
kubectl describe limitrange mylimitrange

# PDB
kubectl get pdb
kubectl describe pdb mypdb

# Check Pod disruptions
kubectl drain node-1 --dry-run
```

## Cleanup

```bash
# Delete specific resources
kubectl delete deployment myapp
kubectl delete hpa myhpa
kubectl delete pdb mypdb

# Delete all resources with label
kubectl delete all,hpa,pdb -l app=myapp
```

---

## Next Steps

After mastering production readiness, continue with these CKAD topics:
- [Deployments](../deployments/CKAD.md) - Rolling updates and rollback strategies
- [Services](../services/CKAD.md) - Service mesh and advanced networking
- [Monitoring](../monitoring/CKAD.md) - Observability and metrics
- [RBAC](../rbac/CKAD.md) - Advanced authorization
