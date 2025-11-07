# Pods - CKAD Requirements

This document covers the CKAD (Certified Kubernetes Application Developer) exam requirements for Pods, building on the basics covered in [README.md](README.md).

## CKAD Exam Requirements

The CKAD exam expects you to understand and implement:
- Multi-container Pod patterns (sidecar, ambassador, adapter)
- Init containers
- Resource requests and limits
- Liveness, readiness, and startup probes
- Environment variables and configuration
- Security contexts
- Pod scheduling (node selectors, affinity, taints/tolerations)
- Pod lifecycle and restart policies

## Multi-Container Pods

Pods can run multiple containers that work together. Common patterns include:

### Sidecar Pattern

The sidecar pattern runs a helper container alongside the main application container.

See complete example: [`specs/ckad/sidecar-pattern.yaml`](specs/ckad/sidecar-pattern.yaml)

```yaml
# Example: web app with log processor sidecar
apiVersion: v1
kind: Pod
metadata:
  name: web-with-sidecar
spec:
  containers:
  - name: web-app
    image: nginx:alpine
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/nginx
  - name: log-processor
    image: busybox:latest
    command: ['sh', '-c', 'while true; do tail -n 100 /logs/access.log | wc -l; sleep 10; done']
    volumeMounts:
    - name: shared-logs
      mountPath: /logs
  volumes:
  - name: shared-logs
    emptyDir: {}
```

📋 Create and deploy a multi-container Pod with a sidecar pattern.

### Ambassador Pattern

The ambassador pattern uses a proxy container to simplify connectivity for the main container.

See complete example: [`specs/ckad/ambassador-pattern.yaml`](specs/ckad/ambassador-pattern.yaml)

The ambassador acts as a proxy, allowing the main application to connect to `localhost` instead of knowing external service URLs.

### Adapter Pattern

The adapter pattern transforms the output of the main container to match a standard format.

See complete example: [`specs/ckad/adapter-pattern.yaml`](specs/ckad/adapter-pattern.yaml)

The adapter container reads logs from the main application and transforms them into a standardized format (e.g., converting custom logs to JSON).

## Init Containers

Init containers run before the main application containers and are often used for setup tasks.

See complete examples:
- Basic init containers: [`specs/ckad/init-container.yaml`](specs/ckad/init-container.yaml)
- Waiting for services: [`specs/ckad/init-wait-for-service.yaml`](specs/ckad/init-wait-for-service.yaml)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-init
spec:
  initContainers:
  - name: init-setup
    image: busybox
    command: ['sh', '-c', 'echo Initializing... && sleep 5']
  containers:
  - name: app
    image: nginx
```

Key characteristics:
- Init containers run to completion before app containers start
- They run sequentially in the order defined
- If an init container fails, the Pod restarts (subject to restart policy)

📋 Create a Pod with an init container that checks for a service availability before starting the main app.

<details>
  <summary>Not sure how?</summary>

See solution: [`specs/ckad/init-wait-for-service.yaml`](specs/ckad/init-wait-for-service.yaml)

```yaml
initContainers:
- name: wait-for-database
  image: busybox:latest
  command:
  - sh
  - -c
  - |
    until nslookup database-service.default.svc.cluster.local; do
      echo "Waiting for database..."
      sleep 2
    done
```

</details><br/>

## Resource Requests and Limits

Resource management is critical for CKAD. You must understand:
- **Requests**: Minimum resources guaranteed to the container
- **Limits**: Maximum resources the container can use

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: resource-demo
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
```

See OOMKilled example: [`specs/ckad/resources-oomkilled.yaml`](specs/ckad/resources-oomkilled.yaml)

When a container exceeds its memory limit, Kubernetes kills it with status `OOMKilled` (Out Of Memory). The Pod will restart according to its `restartPolicy`.

📋 Create a Pod that requests 100m CPU and 128Mi memory, with limits of 200m CPU and 256Mi memory.

### Quality of Service (QoS) Classes

Kubernetes assigns QoS classes based on resource configuration:
- **Guaranteed**: Requests = Limits for all containers
- **Burstable**: At least one container has requests or limits set
- **BestEffort**: No requests or limits set

See complete examples for all QoS classes: [`specs/ckad/qos-classes.yaml`](specs/ckad/qos-classes.yaml)

To identify QoS class: `kubectl describe pod <pod-name>` and look for the `QoS Class:` field.

## Health Probes

Health probes monitor container health and are essential for production workloads.

### Liveness Probe

Restarts the container if the probe fails.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-demo
spec:
  containers:
  - name: app
    image: nginx
    livenessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 3
      periodSeconds: 3
```

See exec command example: [`specs/ckad/probes-liveness-exec.yaml`](specs/ckad/probes-liveness-exec.yaml)

```yaml
livenessProbe:
  exec:
    command:
    - cat
    - /tmp/healthy
  initialDelaySeconds: 5
  periodSeconds: 5
```

### Readiness Probe

Removes Pod from service endpoints if the probe fails (doesn't restart).

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: readiness-demo
spec:
  containers:
  - name: app
    image: nginx
    readinessProbe:
      httpGet:
        path: /ready
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 5
```

### Startup Probe

Allows slow-starting containers more time before liveness checks begin.

See complete example: [`specs/ckad/probes-startup.yaml`](specs/ckad/probes-startup.yaml)

Startup probes are useful for applications that take a long time to initialize. The liveness probe doesn't start checking until the startup probe succeeds.

📋 Create a Pod with both liveness and readiness probes using different methods (httpGet, exec, tcpSocket).

<details>
  <summary>Not sure how?</summary>

See complete solution with all probe types: [`specs/ckad/probes-all-types.yaml`](specs/ckad/probes-all-types.yaml)

This example shows:
- Startup probe with `exec` command
- Liveness probe with `httpGet`
- Readiness probe with `tcpSocket`

</details><br/>

## Environment Variables and Configuration

### Basic Environment Variables

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: env-demo
spec:
  containers:
  - name: app
    image: nginx
    env:
    - name: ENVIRONMENT
      value: "production"
    - name: LOG_LEVEL
      value: "info"
```

### Environment Variables from ConfigMaps

See complete examples: [`specs/ckad/env-configmap.yaml`](specs/ckad/env-configmap.yaml)

Shows three approaches: individual keys with `valueFrom`, all keys with `envFrom`, and ConfigMap as volume mount.

### Environment Variables from Secrets

See complete examples: [`specs/ckad/env-secret.yaml`](specs/ckad/env-secret.yaml)

Similar to ConfigMaps but for sensitive data. Secrets are base64-encoded and can be mounted as volumes with specific permissions.

📋 Create a Pod that uses environment variables from both ConfigMap and Secret.

<details>
  <summary>Not sure how?</summary>

See complete solution: [`specs/ckad/env-configmap-secret-combined.yaml`](specs/ckad/env-configmap-secret-combined.yaml)

This example demonstrates:
- Creating ConfigMap and Secret
- Using both in the same Pod
- Combining individual keys and `envFrom`
- Best practices for configuration management

</details><br/>

## Security Contexts

Security contexts define privilege and access control settings.

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
  name: security-demo-2
spec:
  containers:
  - name: app
    image: nginx
    securityContext:
      allowPrivilegeEscalation: false
      runAsNonRoot: true
      runAsUser: 1000
      capabilities:
        drop:
        - ALL
        add:
        - NET_BIND_SERVICE
```

See complete examples: [`specs/ckad/security-readonly-filesystem.yaml`](specs/ckad/security-readonly-filesystem.yaml)

This example shows:
- Running nginx with read-only root filesystem
- Mounting writable volumes for required directories (`/var/cache/nginx`, `/var/run`, `/tmp`)
- Combining with `runAsNonRoot` and dropped capabilities
- Testing the read-only restriction

📋 Create a Pod that runs as non-root user with a read-only root filesystem.

<details>
  <summary>Not sure how?</summary>

See solution: [`specs/ckad/security-readonly-filesystem.yaml`](specs/ckad/security-readonly-filesystem.yaml)

```yaml
securityContext:
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1000
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
volumeMounts:
- name: tmp
  mountPath: /tmp  # Writable temp directory
```

The solution demonstrates:
- `readOnlyRootFilesystem: true` prevents writes to container filesystem
- `runAsNonRoot: true` ensures container doesn't run as root
- Mount `emptyDir` volumes for directories that need write access
- Drop all capabilities for maximum security

</details><br/>

## Service Accounts

Every Pod runs with a service account that determines API access permissions.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sa-demo
spec:
  serviceAccountName: my-service-account
  containers:
  - name: app
    image: nginx
```

See complete examples: [`specs/ckad/serviceaccount.yaml`](specs/ckad/serviceaccount.yaml)

The examples demonstrate:
- Creating a custom ServiceAccount
- Assigning it to a Pod with `serviceAccountName`
- Verifying the mounted service account token at `/var/run/secrets/kubernetes.io/serviceaccount/`
- Disabling automatic token mounting with `automountServiceAccountToken: false`
- Using RBAC to grant API access permissions to the ServiceAccount
- Making authenticated API calls using the service account token

📋 Create a custom service account and assign it to a Pod.

<details>
  <summary>Not sure how?</summary>

See complete solution: [`specs/ckad/serviceaccount.yaml`](specs/ckad/serviceaccount.yaml)

```bash
# Create ServiceAccount
kubectl apply -f labs/pods/specs/ckad/serviceaccount.yaml

# Verify the ServiceAccount was created
kubectl get serviceaccount my-service-account

# Check the Pod is using the ServiceAccount
kubectl get pod pod-with-sa -o jsonpath='{.spec.serviceAccountName}'

# Verify token is mounted
kubectl exec pod-with-sa -- ls /var/run/secrets/kubernetes.io/serviceaccount/
```

The example includes three scenarios:
1. Basic ServiceAccount assignment
2. Disabled token mounting for increased security
3. ServiceAccount with RBAC permissions for API access

</details><br/>

## Pod Scheduling

### Node Selectors

Simple node selection based on labels.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: node-selector-demo
spec:
  nodeSelector:
    disktype: ssd
  containers:
  - name: app
    image: nginx
```

### Node Affinity

More expressive node selection with required and preferred rules.

See complete examples: [`specs/ckad/scheduling-node-affinity.yaml`](specs/ckad/scheduling-node-affinity.yaml)

**Required Affinity** - Pod will ONLY schedule on nodes matching criteria:

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: disktype
          operator: In
          values:
          - ssd
```

**Preferred Affinity** - Pod prefers matching nodes but can schedule elsewhere:

```yaml
affinity:
  nodeAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 80
      preference:
        matchExpressions:
        - key: region
          operator: In
          values:
          - us-west
```

The examples also show:
- Combined required and preferred rules
- Different operators: `In`, `NotIn`, `Exists`, `DoesNotExist`, `Gt`, `Lt`
- Multiple match expressions for complex scheduling decisions

### Pod Affinity and Anti-Affinity

Controls Pod placement relative to other Pods.

See complete examples: [`specs/ckad/scheduling-pod-affinity.yaml`](specs/ckad/scheduling-pod-affinity.yaml)

**Pod Affinity** - Schedule NEAR other pods (same node/zone):

```yaml
affinity:
  podAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchExpressions:
        - key: app
          operator: In
          values:
          - cache
      topologyKey: kubernetes.io/hostname  # Same node
```

**Pod Anti-Affinity** - Schedule AWAY from other pods (different nodes):

```yaml
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchExpressions:
        - key: app
          operator: In
          values:
          - web
      topologyKey: kubernetes.io/hostname  # Different nodes
```

Common use cases:
- **Affinity**: Co-locate app with cache for low latency
- **Anti-Affinity**: Spread replicas across nodes for high availability
- **Zone-level**: Use `topology.kubernetes.io/zone` for cross-zone distribution

### Taints and Tolerations

Taints on nodes repel pods; tolerations allow pods to schedule on tainted nodes.

See complete examples: [`specs/ckad/scheduling-tolerations.yaml`](specs/ckad/scheduling-tolerations.yaml)

**First, taint a node** (command line):
```bash
kubectl taint nodes node1 env=production:NoSchedule
```

**Then add toleration to Pod**:
```yaml
tolerations:
- key: "env"
  operator: "Equal"
  value: "production"
  effect: "NoSchedule"
```

**Taint effects**:
- `NoSchedule`: Pod won't be scheduled unless it tolerates the taint
- `PreferNoSchedule`: Kubernetes tries to avoid scheduling but not guaranteed
- `NoExecute`: Pod is evicted if it doesn't tolerate (can set `tolerationSeconds`)

**Toleration operators**:
- `Equal`: Match specific key and value
- `Exists`: Match any value for the key (or all taints if no key specified)

The examples include:
- Basic toleration for specific taints
- Multiple tolerations in one Pod
- `tolerationSeconds` for temporary toleration
- Combined with node affinity for precise placement

📋 Create a Pod with node affinity that requires SSD disk and prefers nodes in us-west region.

<details>
  <summary>Not sure how?</summary>

See solution: [`specs/ckad/scheduling-node-affinity.yaml`](specs/ckad/scheduling-node-affinity.yaml)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: node-affinity-combined
spec:
  affinity:
    nodeAffinity:
      # MUST have SSD
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: disktype
            operator: In
            values:
            - ssd
      # PREFERS us-west region
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        preference:
          matchExpressions:
          - key: region
            operator: In
            values:
            - us-west
  containers:
  - name: app
    image: nginx:alpine
```

This combines both `required` (must have SSD) and `preferred` (us-west region preferred but not mandatory) rules.

</details><br/>

## Pod Lifecycle and Restart Policies

### Restart Policies

Kubernetes supports three restart policies:
- **Always** (default): Always restart the container
- **OnFailure**: Restart only if container exits with error
- **Never**: Never restart the container

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: restart-demo
spec:
  restartPolicy: OnFailure
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'exit 1']
```

### Pod Lifecycle Hooks

Lifecycle hooks allow you to run code at specific points in a container's lifecycle.

See complete examples: [`specs/ckad/lifecycle-hooks.yaml`](specs/ckad/lifecycle-hooks.yaml)

**postStart Hook** - Runs immediately after container starts:

```yaml
lifecycle:
  postStart:
    exec:
      command:
      - sh
      - -c
      - |
        echo "Container started at $(date)" > /tmp/startup
        # Initialize cache, warm up services, etc.
```

**preStop Hook** - Runs before container stops (graceful shutdown):

```yaml
lifecycle:
  preStop:
    exec:
      command:
      - sh
      - -c
      - |
        echo "Graceful shutdown initiated"
        # Drain connections, save state, cleanup
        sleep 15
        echo "Ready to terminate"
```

Key points:
- `postStart` runs asynchronously with the container ENTRYPOINT
- If `postStart` fails, the container is killed
- `preStop` runs before the TERM signal is sent
- Pod's `terminationGracePeriodSeconds` includes preStop time
- Both hooks can use `exec` or `httpGet` handlers

📋 Create a Pod with preStop hook that performs graceful shutdown.

<details>
  <summary>Not sure how?</summary>

See complete solution: [`specs/ckad/lifecycle-hooks.yaml`](specs/ckad/lifecycle-hooks.yaml)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: webapp-with-hooks
spec:
  containers:
  - name: web
    image: nginx:alpine
    lifecycle:
      preStop:
        exec:
          command:
          - sh
          - -c
          - |
            # Graceful shutdown sequence
            echo "Starting graceful shutdown..."

            # 1. Stop accepting new connections
            echo "Stopped accepting new connections"

            # 2. Wait for existing requests to complete
            echo "Waiting for existing requests..."
            sleep 15

            # 3. Flush cache/save state
            echo "Flushing cache to disk..."
            sync

            echo "Graceful shutdown complete"
  terminationGracePeriodSeconds: 60  # Must be >= preStop duration
```

The solution demonstrates a production-ready graceful shutdown sequence that allows in-flight requests to complete before termination.

</details><br/>

## Labels and Annotations

Labels are used for organization and selection; annotations store non-identifying metadata.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: labels-demo
  labels:
    app: myapp
    tier: frontend
    environment: production
    version: v1.2.3
  annotations:
    description: "Main application frontend"
    owner: "platform-team@company.com"
spec:
  containers:
  - name: app
    image: nginx
```

📋 Create three Pods with different labels, then use label selectors to query them.

<details>
  <summary>Not sure how?</summary>

```powershell
# Get pods with specific label
kubectl get pods -l app=myapp

# Get pods with label key
kubectl get pods -l environment

# Get pods with multiple label conditions
kubectl get pods -l 'app=myapp,tier=frontend'

# Get pods with label value in set
kubectl get pods -l 'environment in (production,staging)'
```

</details><br/>

## Container Lifecycle Commands

Override container commands and arguments.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: command-demo
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c"]
    args: ["echo Hello from the pod && sleep 3600"]
```

Understanding the relationship between Dockerfile and Pod spec:
- `command` in Pod spec overrides `ENTRYPOINT` in Dockerfile
- `args` in Pod spec overrides `CMD` in Dockerfile

See comprehensive examples: [`specs/ckad/command-args.yaml`](specs/ckad/command-args.yaml)

The examples demonstrate:

**1. Default image command** (no override):
```yaml
containers:
- name: app
  image: busybox:latest
  # Uses image default
```

**2. Override command only**:
```yaml
containers:
- name: app
  image: busybox:latest
  command: ["echo"]
```

**3. Override both command and args**:
```yaml
containers:
- name: app
  image: busybox:latest
  command: ["echo"]
  args: ["Hello, Kubernetes!"]
```

**4. Multi-line command with shell**:
```yaml
containers:
- name: app
  image: busybox:latest
  command: ["sh", "-c"]
  args:
  - |
    echo "Starting..."
    echo "Running..."
    sleep 3600
```

**5. Using environment variables in commands**:
```yaml
containers:
- name: app
  image: busybox:latest
  env:
  - name: MESSAGE
    value: "Hello"
  command: ["sh", "-c"]
  args: ["echo $MESSAGE"]
```

The file includes 10+ examples covering all common patterns, including using ConfigMaps for startup scripts.

## Lab Exercises

### Exercise 1: Multi-Container Pod

Create a Pod with two containers:
1. An nginx web server
2. A sidecar container that fetches content every 30 seconds

The containers should share a volume where the sidecar writes content and nginx serves it.

**Solution**: [`specs/ckad/exercises/ex1-multi-container.yaml`](specs/ckad/exercises/ex1-multi-container.yaml)

```bash
kubectl apply -f labs/pods/specs/ckad/exercises/ex1-multi-container.yaml
kubectl get pod content-server
kubectl port-forward content-server 8080:80
# Visit http://localhost:8080 to see fetched content
```

### Exercise 2: Resource Management

Create a Pod that demonstrates resource limits by:
1. Setting memory limit to 100Mi
2. Attempting to allocate 150M (exceeds limit)
3. Observing the OOMKilled behavior

**Solution**: [`specs/ckad/exercises/ex2-resource-limits.yaml`](specs/ckad/exercises/ex2-resource-limits.yaml)

```bash
kubectl apply -f labs/pods/specs/ckad/exercises/ex2-resource-limits.yaml
kubectl get pod memory-demo -w
kubectl describe pod memory-demo  # Look for OOMKilled status
```

### Exercise 3: Health Checks

Create a Pod with:
- Startup probe with 30 second grace period
- Liveness probe that checks for alive marker
- Readiness probe that checks for ready marker

**Solution**: [`specs/ckad/exercises/ex3-health-probes.yaml`](specs/ckad/exercises/ex3-health-probes.yaml)

```bash
kubectl apply -f labs/pods/specs/ckad/exercises/ex3-health-probes.yaml
kubectl get pod health-check-demo -w
kubectl describe pod health-check-demo  # Check probe status
```

### Exercise 4: Security Hardening

Create a Pod that follows security best practices:
- Runs as non-root user (UID 1000)
- Uses read-only root filesystem
- Drops all capabilities except NET_BIND_SERVICE
- Uses a custom service account
- Includes resource limits

**Solution**: [`specs/ckad/exercises/ex4-security-hardening.yaml`](specs/ckad/exercises/ex4-security-hardening.yaml)

```bash
kubectl apply -f labs/pods/specs/ckad/exercises/ex4-security-hardening.yaml
kubectl get pod secure-web
kubectl exec secure-web -- id  # Verify running as UID 1000
kubectl describe pod secure-web  # Check security context
```

### Exercise 5: Advanced Scheduling

Create Pods that demonstrate:
1. Node affinity with required and preferred rules
2. Pod affinity (schedule with certain Pods)
3. Pod anti-affinity (spread across nodes)

**Solution**: [`specs/ckad/exercises/ex5-advanced-scheduling.yaml`](specs/ckad/exercises/ex5-advanced-scheduling.yaml)

```bash
kubectl apply -f labs/pods/specs/ckad/exercises/ex5-advanced-scheduling.yaml
kubectl get pods -o wide  # See which nodes pods are scheduled on
kubectl describe pod node-affinity-app  # Check scheduling decisions
```

## Common CKAD Scenarios

### Scenario 1: Debug a Failing Pod

See complete scenario: [`specs/ckad/scenario-debug-probes.yaml`](specs/ckad/scenario-debug-probes.yaml)

**Common probe issues and solutions:**

**Problem 1: Aggressive liveness probe**
- Issue: `initialDelaySeconds: 1` and `failureThreshold: 1` causes immediate restarts
- Solution: Increase `initialDelaySeconds` to allow startup time, use `failureThreshold: 3`

**Problem 2: Wrong port in probe**
- Issue: Probe checks port 8080 but app runs on port 80
- Solution: Verify port matches container's listening port

**Problem 3: Wrong path**
- Issue: Probe checks `/healthz` but endpoint doesn't exist (returns 404)
- Solution: Use existing path like `/` or create proper health endpoint

**Problem 4: Missing startup probe for slow apps**
- Issue: App takes 45s to start, but liveness probe starts at 10s and fails
- Solution: Add startup probe with `failureThreshold: 15` to allow adequate startup time

**Problem 5: Wrong command in exec probe**
- Issue: Command `/bin/check-health.sh` doesn't exist
- Solution: Use commands that exist in the container

**Debugging commands:**
```bash
# Check pod status and restart count
kubectl get pods
kubectl describe pod <pod-name>

# Look for probe failures in events
kubectl describe pod <pod-name> | grep -A 5 Events

# Check probe configuration
kubectl get pod <pod-name> -o yaml | grep -A 20 Probe

# Test probe manually
kubectl exec <pod-name> -- curl localhost:80/
kubectl exec <pod-name> -- cat /tmp/healthy

# View logs from previous instance
kubectl logs <pod-name> --previous
```

### Scenario 2: Update Environment Variables

See complete scenario: [`specs/ckad/scenario-update-env-vars.yaml`](specs/ckad/scenario-update-env-vars.yaml)

**Key concept:** You CANNOT update environment variables in a running Pod. Pods are immutable - you must recreate them.

**Method 1: Direct Pod Update (with downtime)**
```bash
# Export current Pod spec
kubectl get pod app-with-env -o yaml > pod.yaml

# Edit the file and modify env values
# Then recreate the Pod
kubectl delete pod app-with-env
kubectl apply -f pod.yaml
```

**Method 2: Using ConfigMap (recommended)**
```bash
# Edit the ConfigMap
kubectl edit configmap app-config

# Restart the Pod to pick up changes
kubectl delete pod app-with-configmap
kubectl apply -f pod.yaml
```

**Method 3: Using Deployment (best for production)**
```bash
# Update environment variable in Deployment
kubectl set env deployment/app-deployment ENV_VAR=new_value

# This triggers automatic rolling update with no downtime
kubectl rollout status deployment/app-deployment
```

**Method 4: ConfigMap as Volume Mount (hot reload)**
```yaml
# ConfigMap mounted as file - changes appear automatically
volumeMounts:
- name: config
  mountPath: /config
volumes:
- name: config
  configMap:
    name: reloadable-config
```
- Changes sync within ~60 seconds (kubelet sync period)
- Application must watch file and reload config
- No Pod restart needed

**Verification:**
```bash
# Check current env vars
kubectl exec <pod-name> -- env
kubectl exec <pod-name> -- printenv ENV_VAR_NAME

# Verify ConfigMap changes
kubectl get configmap <name> -o yaml
```

### Scenario 3: Fix Resource Issues

See complete scenario: [`specs/ckad/scenario-resource-issues.yaml`](specs/ckad/scenario-resource-issues.yaml)

**Problem 1: OOMKilled (Out of Memory)**
```yaml
# Issue: Memory limit too low
resources:
  limits:
    memory: "50Mi"
  requests:
    memory: "50Mi"
# App tries to use 100M → OOMKilled
```

**Solution:** Increase memory limit appropriately
```yaml
resources:
  limits:
    memory: "150Mi"
  requests:
    memory: "100Mi"
```

**Problem 2: CPU Throttling**
```yaml
# Issue: CPU limit too restrictive
resources:
  limits:
    cpu: "100m"  # 0.1 CPU
# App needs 2 cores → Severe throttling, runs slowly
```

**Solution:** Increase CPU limit
```yaml
resources:
  limits:
    cpu: "1000m"  # 1 full CPU
  requests:
    cpu: "500m"
```

**Problem 3: No resource limits**
- Issue: Pod can consume all node resources, starving other pods
- Solution: Always set both requests and limits

**Problem 4: Memory leak**
- Issue: Application gradually consumes more memory → eventual OOMKilled
- Solution: Fix the application or increase limits (temporary workaround)

**Diagnostic commands:**
```bash
# Check for OOMKilled status
kubectl get pods
kubectl describe pod <pod-name>
# Look for: "Last State: Terminated, Reason: OOMKilled"

# Monitor resource usage
kubectl top pod <pod-name>
kubectl top pods --all-namespaces
kubectl top nodes

# Watch usage in real-time
watch kubectl top pod <pod-name>

# Check events for resource issues
kubectl get events --sort-by='.lastTimestamp'

# View logs from before OOMKilled
kubectl logs <pod-name> --previous

# Check resource configuration
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].resources}'
```

**Signs of issues:**
- **OOMKilled status**: Memory limit too low or memory leak
- **High restart count**: Resource or application issue
- **CPU at 100% of limit**: Possible throttling affecting performance
- **Pending status**: Insufficient node resources to schedule pod

**Best practices:**
```yaml
resources:
  requests:
    cpu: "250m"       # Guaranteed minimum
    memory: "128Mi"
  limits:
    cpu: "500m"       # Can burst to 0.5 CPU
    memory: "256Mi"   # Hard limit
```

## Quick Reference Commands

```powershell
# Create Pod from YAML
kubectl apply -f pod.yaml

# Get Pod with labels shown
kubectl get pods --show-labels

# Filter Pods by label
kubectl get pods -l app=myapp

# Get Pod YAML
kubectl get pod mypod -o yaml

# Edit Pod (limited fields)
kubectl edit pod mypod

# Delete and recreate Pod
kubectl delete pod mypod
kubectl apply -f pod.yaml

# Describe Pod (events, conditions, status)
kubectl describe pod mypod

# Get Pod logs
kubectl logs mypod
kubectl logs mypod -c container-name  # specific container

# Execute command in Pod
kubectl exec mypod -- command
kubectl exec -it mypod -- sh

# Get Pod with custom columns
kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,IP:.status.podIP

# Watch Pod status
kubectl get pods -w

# Get Pod resource usage
kubectl top pod mypod

# Port forward to Pod
kubectl port-forward mypod 8080:80

# Copy files to/from Pod
kubectl cp mypod:/path/to/file ./local-file
kubectl cp ./local-file mypod:/path/to/file
```

## Cleanup

Remove all Pods created in these exercises:

```powershell
kubectl delete pod --all
```

> Or use label selectors to remove specific Pods:

```powershell
kubectl delete pod -l exercise=ckad
```

---

## Next Steps

After mastering Pods, continue with these CKAD topics:
- [ConfigMaps](../configmaps/CKAD.md) - Configuration management
- [Secrets](../secrets/CKAD.md) - Secure configuration
- [Deployments](../deployments/CKAD.md) - Application deployment and scaling
- [Services](../services/CKAD.md) - Networking and load balancing
