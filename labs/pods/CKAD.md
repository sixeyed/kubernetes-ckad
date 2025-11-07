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

See complete solution: [`specs/ckad/env-configmap-secret-combined.yaml`](specs/ckad/env-configmap-secret-yaml)

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

> **TODO**: Add example showing read-only root filesystem

📋 Create a Pod that runs as non-root user with a read-only root filesystem.

<details>
  <summary>Not sure how?</summary>

> **TODO**: Add solution showing non-root user + readOnlyRootFilesystem

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

> **TODO**: Add example showing how to create service account and verify Pod is using it

📋 Create a custom service account and assign it to a Pod.

<details>
  <summary>Not sure how?</summary>

> **TODO**: Add solution with ServiceAccount creation and Pod assignment

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

> **TODO**: Add example showing requiredDuringSchedulingIgnoredDuringExecution

> **TODO**: Add example showing preferredDuringSchedulingIgnoredDuringExecution

### Pod Affinity and Anti-Affinity

Controls Pod placement relative to other Pods.

> **TODO**: Add example showing pod affinity (schedule near certain Pods)

> **TODO**: Add example showing pod anti-affinity (spread Pods across nodes)

### Taints and Tolerations

> **TODO**: Add example showing how to add tolerations to schedule on tainted nodes

📋 Create a Pod with node affinity that requires SSD disk and prefers nodes in us-west region.

<details>
  <summary>Not sure how?</summary>

> **TODO**: Add solution with node affinity rules

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

> **TODO**: Add example showing postStart hook

> **TODO**: Add example showing preStop hook

📋 Create a Pod with preStop hook that performs graceful shutdown.

<details>
  <summary>Not sure how?</summary>

> **TODO**: Add solution showing preStop hook implementation

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

> **TODO**: Add example showing various combinations of command/args

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

> **TODO**: Add troubleshooting scenario with misconfigured probes

### Scenario 2: Update Environment Variables

> **TODO**: Add scenario showing how to update Pod with new env vars

### Scenario 3: Fix Resource Issues

> **TODO**: Add scenario with OOMKilled or CPU throttling

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
