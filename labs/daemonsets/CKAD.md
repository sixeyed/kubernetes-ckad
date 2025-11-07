# DaemonSets - CKAD Requirements

This document covers the CKAD (Certified Kubernetes Application Developer) exam requirements for DaemonSets, building on the basics covered in [README.md](README.md).

## CKAD Exam Requirements

The CKAD exam expects you to understand and implement:
- DaemonSet creation and management
- Update strategies (RollingUpdate vs OnDelete)
- Node selection with nodeSelector, node affinity, and taints/tolerations
- Init containers in DaemonSet Pods
- HostPath volumes and security considerations
- Pod affinity/anti-affinity with DaemonSets
- Differences between DaemonSets and Deployments
- Troubleshooting DaemonSet issues
- Common use cases (logging, monitoring, networking)

## DaemonSet Basics

DaemonSets ensure exactly one Pod runs on each node (or a subset of nodes). Unlike Deployments, you cannot specify the number of replicas - Kubernetes automatically creates Pods based on the number of matching nodes.

### Basic DaemonSet Spec

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
  labels:
    app: node-exporter
spec:
  selector:
    matchLabels:
      app: node-exporter
  template:
    metadata:
      labels:
        app: node-exporter
    spec:
      containers:
      - name: node-exporter
        image: prom/node-exporter:latest
        ports:
        - containerPort: 9100
          name: metrics
```

Key differences from Deployments:
- No `replicas` field (automatic based on nodes)
- Update strategy defaults differ
- Scheduling behavior differs

📋 Create a DaemonSet that runs a simple web server on all nodes.

<details>
  <summary>Not sure how?</summary>

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: webserver
spec:
  selector:
    matchLabels:
      app: webserver
  template:
    metadata:
      labels:
        app: webserver
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
```

```bash
kubectl apply -f daemonset.yaml
kubectl get daemonset webserver
kubectl get pods -l app=webserver -o wide
```

</details><br/>

## Update Strategies

DaemonSets support two update strategies that control how Pods are replaced during updates.

### RollingUpdate (Default)

Pods are updated automatically when the DaemonSet spec changes:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: logging-agent
spec:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1  # or percentage like "20%"
  selector:
    matchLabels:
      app: logging-agent
  template:
    metadata:
      labels:
        app: logging-agent
    spec:
      containers:
      - name: fluentd
        image: fluent/fluentd:v1.15
```

- **maxUnavailable**: Maximum number of Pods that can be unavailable during update
- Default: `maxUnavailable: 1` (one node at a time)
- Can be number or percentage (e.g., "20%")

### OnDelete

Pods are updated only when manually deleted:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: logging-agent
spec:
  updateStrategy:
    type: OnDelete
  selector:
    matchLabels:
      app: logging-agent
  template:
    metadata:
      labels:
        app: logging-agent
    spec:
      containers:
      - name: fluentd
        image: fluent/fluentd:v1.16  # Updated version
```

Workflow with OnDelete:
1. Update DaemonSet spec (`kubectl apply`)
2. DaemonSet is updated but Pods remain unchanged
3. Manually delete Pods one by one
4. New Pods created with updated spec

```bash
# Update DaemonSet
kubectl apply -f daemonset-updated.yaml

# Check Pods (still running old version)
kubectl get pods -l app=logging-agent

# Manually delete Pods to trigger update
kubectl delete pod -l app=logging-agent --field-selector spec.nodeName=node-1
```

### Comparing RollingUpdate vs OnDelete

Create two DaemonSets to see the difference:

**Deploy both strategies:**

```bash
# Deploy RollingUpdate DaemonSet
kubectl apply -f labs/daemonsets/specs/ckad/update-rolling.yaml

# Deploy OnDelete DaemonSet
kubectl apply -f labs/daemonsets/specs/ckad/update-ondelete.yaml

# Check both DaemonSets
kubectl get daemonset
kubectl get pods -l app=logger -o wide
```

**Update both to new version:**

```bash
# Apply updated versions
kubectl apply -f labs/daemonsets/specs/ckad/update-rolling-v2.yaml
kubectl apply -f labs/daemonsets/specs/ckad/update-ondelete-v2.yaml

# Watch the difference
kubectl get pods -l strategy=rolling -w    # Updates automatically
kubectl get pods -l strategy=ondelete      # No change until manual deletion
```

**Observe behavior:**

```bash
# RollingUpdate: Pods update automatically
kubectl rollout status daemonset/logger-rolling

# OnDelete: Pods remain on old version
kubectl get pods -l strategy=ondelete -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image

# Manually delete OnDelete pods to trigger update
kubectl delete pod -l strategy=ondelete --field-selector spec.nodeName=<node-name>

# Verify new pod created with updated image
kubectl get pods -l strategy=ondelete -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image
```

**Cleanup:**

```bash
kubectl delete daemonset logger-rolling logger-ondelete
```

📋 Create a DaemonSet with OnDelete strategy, update it, and manually control the rollout.

<details>
  <summary>Not sure how?</summary>

Create the initial DaemonSet:

```bash
# Deploy version 1
kubectl apply -f labs/daemonsets/specs/ckad/exercise2-ondelete-v1.yaml

# Verify deployment
kubectl get daemonset controlled-rollout
kubectl get pods -l app=controlled-rollout -o wide

# Check version in each pod
kubectl get pods -l app=controlled-rollout -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,VERSION:.metadata.labels.version
```

Update to version 2 with controlled rollout:

```bash
# Apply version 2 (DaemonSet updated, but pods unchanged)
kubectl apply -f labs/daemonsets/specs/ckad/exercise2-ondelete-v2.yaml

# Verify DaemonSet is updated
kubectl get daemonset controlled-rollout -o yaml | grep -A 2 "image:"

# Pods still running version 1
kubectl get pods -l app=controlled-rollout -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image

# Get list of nodes
kubectl get nodes -o name

# Manually update pods one node at a time
# First node
kubectl delete pod -l app=controlled-rollout --field-selector spec.nodeName=<node-1>

# Wait for pod to be ready
kubectl wait --for=condition=ready pod -l app=controlled-rollout --field-selector spec.nodeName=<node-1> --timeout=60s

# Verify version 2 is running
kubectl get pods -l app=controlled-rollout -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,IMAGE:.spec.containers[0].image

# Continue with remaining nodes one by one
# Second node
kubectl delete pod -l app=controlled-rollout --field-selector spec.nodeName=<node-2>
kubectl wait --for=condition=ready pod -l app=controlled-rollout --field-selector spec.nodeName=<node-2> --timeout=60s

# Verify all pods updated
kubectl get pods -l app=controlled-rollout -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,VERSION:.metadata.labels.version
```

Rollback if issues occur:

```bash
# If problems detected, rollback by applying v1 again
kubectl apply -f labs/daemonsets/specs/ckad/exercise2-ondelete-v1.yaml

# Delete affected pods to get v1 back
kubectl delete pod -l app=controlled-rollout --field-selector spec.nodeName=<node-name>

# Or delete all pods if needed
kubectl delete pod -l app=controlled-rollout
```

Cleanup:

```bash
kubectl delete daemonset controlled-rollout
```

</details><br/>

## Node Selection

Control which nodes run DaemonSet Pods using node selectors, affinity, or tolerations.

### Node Selectors

Simple label-based node selection:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: ssd-monitor
spec:
  selector:
    matchLabels:
      app: ssd-monitor
  template:
    metadata:
      labels:
        app: ssd-monitor
    spec:
      nodeSelector:
        disktype: ssd  # Only run on nodes with this label
      containers:
      - name: monitor
        image: monitoring-agent:latest
```

```bash
# Label nodes
kubectl label nodes node-1 disktype=ssd
kubectl label nodes node-2 disktype=ssd

# Verify DaemonSet Pods
kubectl get pods -l app=ssd-monitor -o wide
```

### Node Affinity

More expressive node selection with required and preferred rules:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: gpu-monitor
spec:
  selector:
    matchLabels:
      app: gpu-monitor
  template:
    metadata:
      labels:
        app: gpu-monitor
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: gpu
                operator: In
                values:
                - nvidia
                - amd
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: gpu-type
                operator: In
                values:
                - high-memory
```

### Tolerations for Tainted Nodes

Allow DaemonSet Pods to run on tainted nodes:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-problem-detector
spec:
  selector:
    matchLabels:
      app: node-problem-detector
  template:
    metadata:
      labels:
        app: node-problem-detector
    spec:
      tolerations:
      # Run on master nodes
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
      # Run on nodes with disk pressure
      - key: node.kubernetes.io/disk-pressure
        effect: NoSchedule
      # Run on all nodes regardless of taints
      - operator: Exists
        effect: NoSchedule
      containers:
      - name: detector
        image: k8s.gcr.io/node-problem-detector:v0.8.10
```

Common tolerations for system DaemonSets:

```yaml
tolerations:
# Tolerate master/control-plane nodes
- key: node-role.kubernetes.io/master
  effect: NoSchedule
- key: node-role.kubernetes.io/control-plane
  effect: NoSchedule

# Tolerate not-ready nodes
- key: node.kubernetes.io/not-ready
  effect: NoExecute

# Tolerate unreachable nodes
- key: node.kubernetes.io/unreachable
  effect: NoExecute

# Tolerate any taint (use for critical system pods)
- operator: Exists
```

### Running DaemonSets on Master/Control-Plane Nodes

Deploy a DaemonSet that runs on all nodes including master:

```bash
# Deploy system monitor with master tolerations
kubectl apply -f labs/daemonsets/specs/ckad/master-tolerations.yaml

# Check DaemonSet
kubectl get daemonset system-monitor

# Verify pods running on all nodes including master
kubectl get pods -l app=system-monitor -o wide

# Check which nodes have the DaemonSet
kubectl get pods -l app=system-monitor -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,STATUS:.status.phase

# View logs from a pod
kubectl logs -l app=system-monitor --tail=20

# Check the tolerations
kubectl get daemonset system-monitor -o jsonpath='{.spec.template.spec.tolerations}' | jq
```

**Why this works:**
- Master nodes typically have taints like `node-role.kubernetes.io/master:NoSchedule` or `node-role.kubernetes.io/control-plane:NoSchedule`
- Our DaemonSet tolerates these taints, allowing scheduling on master nodes
- System DaemonSets (monitoring, logging, networking) often need this capability

**Cleanup:**

```bash
kubectl delete daemonset system-monitor
```

📋 Create a DaemonSet that runs on nodes labeled `monitoring=enabled` and tolerates node pressure conditions.

<details>
  <summary>Not sure how?</summary>

Label nodes for monitoring:

```bash
# Label specific nodes for monitoring
kubectl label nodes <node-1> monitoring=enabled
kubectl label nodes <node-2> monitoring=enabled

# Verify labels
kubectl get nodes -L monitoring
```

Deploy the DaemonSet:

```bash
# Deploy monitoring agent
kubectl apply -f labs/daemonsets/specs/ckad/node-selector-tolerations.yaml

# Verify it only runs on labeled nodes
kubectl get daemonset monitoring-agent
kubectl get pods -l app=monitoring-agent -o wide

# Check which nodes have the pods
kubectl get pods -l app=monitoring-agent -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName
```

Test node pressure tolerations:

```bash
# Simulate disk pressure on a node (requires appropriate permissions)
# In practice, you would see these taints appear automatically when nodes experience pressure

# View the tolerations
kubectl get daemonset monitoring-agent -o jsonpath='{.spec.template.spec.tolerations}' | jq

# The DaemonSet tolerates:
# - node.kubernetes.io/memory-pressure
# - node.kubernetes.io/disk-pressure
# - node.kubernetes.io/pid-pressure
```

Add/remove nodes from monitoring:

```bash
# Add another node to monitoring
kubectl label nodes <node-3> monitoring=enabled

# Wait for pod to be scheduled
kubectl get pods -l app=monitoring-agent -o wide

# Remove node from monitoring
kubectl label nodes <node-3> monitoring-

# Pod will be deleted from that node
kubectl get pods -l app=monitoring-agent -o wide
```

Cleanup:

```bash
# Delete DaemonSet
kubectl delete daemonset monitoring-agent

# Remove labels
kubectl label nodes --all monitoring-
```

</details><br/>

## Init Containers in DaemonSets

Init containers run before main containers and are useful for setup tasks.

### Common Use Cases

1. **Waiting for dependencies**
2. **Downloading configuration**
3. **Setting up volumes**
4. **Security/compliance checks**

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: app-with-init
spec:
  selector:
    matchLabels:
      app: app-with-init
  template:
    metadata:
      labels:
        app: app-with-init
    spec:
      initContainers:
      # Init container 1: Download configuration
      - name: config-downloader
        image: busybox
        command: ['sh', '-c']
        args:
        - |
          echo "Downloading config..."
          wget -O /config/app.conf http://config-server/app.conf
        volumeMounts:
        - name: config
          mountPath: /config

      # Init container 2: Set permissions
      - name: permission-setter
        image: busybox
        command: ['sh', '-c']
        args:
        - |
          chown -R 1000:1000 /data
          chmod 755 /data
        volumeMounts:
        - name: data
          mountPath: /data

      containers:
      - name: app
        image: myapp:latest
        volumeMounts:
        - name: config
          mountPath: /etc/app
        - name: data
          mountPath: /var/app/data

      volumes:
      - name: config
        emptyDir: {}
      - name: data
        hostPath:
          path: /var/lib/myapp
          type: DirectoryOrCreate
```

### Init Container Patterns

**Pattern 1: Wait for Service**

```yaml
initContainers:
- name: wait-for-db
  image: busybox
  command: ['sh', '-c']
  args:
  - |
    until nslookup mysql.default.svc.cluster.local; do
      echo "Waiting for mysql service..."
      sleep 2
    done
```

**Pattern 2: Clone Git Repository**

```yaml
initContainers:
- name: git-clone
  image: alpine/git
  command: ['git', 'clone']
  args:
  - 'https://github.com/user/config.git'
  - '/config'
  volumeMounts:
  - name: config
    mountPath: /config
```

**Pattern 3: Generate Configuration**

```yaml
initContainers:
- name: config-generator
  image: busybox
  command: ['sh', '-c']
  args:
  - |
    cat > /config/app.conf <<EOF
    NODE_NAME=${NODE_NAME}
    POD_IP=${POD_IP}
    EOF
  env:
  - name: NODE_NAME
    valueFrom:
      fieldRef:
        fieldPath: spec.nodeName
  - name: POD_IP
    valueFrom:
      fieldRef:
        fieldPath: status.podIP
  volumeMounts:
  - name: config
    mountPath: /config
```

### Init Container Failure and Retry Behavior

Init containers that fail will be retried automatically until they succeed:

```bash
# Deploy DaemonSet with init container waiting for a service
kubectl apply -f labs/daemonsets/specs/ckad/init-failure-demo.yaml

# Check DaemonSet status
kubectl get daemonset init-failure-demo

# Pods will be stuck in Init phase
kubectl get pods -l app=init-failure-demo

# Check init container status
kubectl describe pod -l app=init-failure-demo | grep -A 10 "Init Containers"

# View init container logs (shows retry attempts)
kubectl logs -l app=init-failure-demo -c wait-for-service

# You'll see repeated attempts like:
# "Waiting for required service..."
# "Service not found, retrying in 5 seconds..."
```

Create the required service to allow init containers to complete:

```bash
# Create the required service
kubectl apply -f labs/daemonsets/specs/ckad/required-service.yaml

# Wait for pods to complete initialization
kubectl get pods -l app=init-failure-demo -w

# Once service exists, init containers succeed
kubectl get pods -l app=init-failure-demo

# Check the logs
kubectl logs -l app=init-failure-demo -c wait-for-service
kubectl logs -l app=init-failure-demo -c verify-readiness
kubectl logs -l app=init-failure-demo -c app
```

**Key behaviors:**
- Init containers run sequentially (one must complete before next starts)
- Failed init containers restart with exponential backoff (10s, 20s, 40s... up to 5 minutes)
- Pod remains in `Init:0/2` or similar status until all init containers succeed
- Main container doesn't start until all init containers complete successfully
- Logs from previous init container attempts are lost on restart

**Cleanup:**

```bash
kubectl delete daemonset init-failure-demo
kubectl delete -f labs/daemonsets/specs/ckad/required-service.yaml
```

📋 Create a DaemonSet with multiple init containers that prepare the environment before the main application starts.

<details>
  <summary>Not sure how?</summary>

Deploy DaemonSet with chained init containers:

```bash
# Deploy the DaemonSet
kubectl apply -f labs/daemonsets/specs/ckad/init-containers.yaml

# Watch initialization process
kubectl get pods -l app=app-with-init -w

# Check init container execution
kubectl describe pod -l app=app-with-init | grep -A 20 "Init Containers"
```

View init container logs to see sequential execution:

```bash
# Get pod name
POD=$(kubectl get pod -l app=app-with-init -o jsonpath='{.items[0].metadata.name}')

# View first init container (setup-directories)
kubectl logs $POD -c setup-directories

# View second init container (fetch-config)
kubectl logs $POD -c fetch-config

# View third init container (set-permissions)
kubectl logs $POD -c set-permissions

# View main container
kubectl logs $POD -c app
```

Verify the setup:

```bash
# Check all containers in pod
kubectl get pod -l app=app-with-init -o jsonpath='{.items[0].spec.initContainers[*].name}'; echo
kubectl get pod -l app=app-with-init -o jsonpath='{.items[0].spec.containers[*].name}'; echo

# Exec into running pod to verify setup
kubectl exec -it $POD -- sh

# Inside pod:
# Check configuration file
cat /etc/app/app.conf

# Check data directories
ls -la /var/app/data/

# Check log file
cat /var/app/data/logs/app.log

# Exit
exit
```

Test init container dependency chain:

```bash
# Delete and watch recreation
kubectl delete pod $POD

# Watch init containers run in sequence
kubectl get pods -l app=app-with-init -w

# Each init container must complete before next starts:
# 1. setup-directories (creates dirs)
# 2. fetch-config (generates config using directories)
# 3. set-permissions (sets permissions on directories)
# 4. app container starts (uses prepared environment)
```

Cleanup:

```bash
kubectl delete daemonset app-with-init
```

</details><br/>

## HostPath Volumes

DaemonSets commonly use HostPath volumes to access node resources.

### Basic HostPath Usage

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: log-collector
spec:
  selector:
    matchLabels:
      app: log-collector
  template:
    metadata:
      labels:
        app: log-collector
    spec:
      containers:
      - name: collector
        image: fluent/fluentd
        volumeMounts:
        - name: varlog
          mountPath: /var/log
          readOnly: true
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
          type: Directory
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
          type: Directory
```

### HostPath Types

```yaml
volumes:
- name: example
  hostPath:
    path: /path/on/host
    type: Directory          # Must exist as directory
    # type: DirectoryOrCreate # Create if doesn't exist
    # type: File             # Must exist as file
    # type: FileOrCreate     # Create file if doesn't exist
    # type: Socket           # Must exist as Unix socket
    # type: CharDevice       # Must exist as character device
    # type: BlockDevice      # Must exist as block device
```

### Security Considerations

HostPath volumes have security implications:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: secure-host-access
spec:
  selector:
    matchLabels:
      app: secure-host-access
  template:
    metadata:
      labels:
        app: secure-host-access
    spec:
      # Security context for the Pod
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000

      containers:
      - name: app
        image: myapp:latest
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: host-data
          mountPath: /host-data
          readOnly: true  # Read-only when possible

      volumes:
      - name: host-data
        hostPath:
          path: /var/lib/data
          type: Directory
```

### Security Risks of Unrestricted HostPath Access

**DANGEROUS EXAMPLE - Do not use in production:**

```bash
# Deploy insecure DaemonSet (for educational purposes only)
kubectl apply -f labs/daemonsets/specs/ckad/hostpath-insecure.yaml

# Check the DaemonSet
kubectl get daemonset hostpath-insecure
kubectl get pods -l app=hostpath-insecure

# View the dangerous capabilities
POD=$(kubectl get pod -l app=hostpath-insecure -o jsonpath='{.items[0].metadata.name}')
kubectl logs $POD

# Exec into pod to see the risks
kubectl exec -it $POD -- sh

# Inside the container (DANGER ZONE):
# Can read any file on host
cat /host-root/etc/passwd

# Can access host processes
ls -la /host-root/proc

# Can modify host filesystem
echo "Compromised" > /host-root/tmp/compromised.txt

# Can potentially escape container and access host
ls -la /host-root/root/

# Exit
exit
```

**Why this is dangerous:**

1. **Full host filesystem access** - Can read/write any file on host
2. **Running as root** - No privilege restrictions
3. **Privileged mode** - Can perform any operation
4. **No securityContext** - No protection against container escape
5. **Read-write mount** - Can modify critical system files

**Security Best Practices:**

```yaml
# DO THIS INSTEAD:
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000
  containers:
  - name: secure-app
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
    volumeMounts:
    - name: host-data
      mountPath: /data
      readOnly: true  # Read-only when possible
  volumes:
  - name: host-data
    hostPath:
      path: /var/lib/specific-data  # Specific path, not root
      type: Directory
```

**Cleanup:**

```bash
kubectl delete daemonset hostpath-insecure
# Remove the created file
sudo rm -f /tmp/insecure-modification.txt 2>/dev/null || true
```

### Common HostPath Use Cases

1. **Log Collection**
   ```yaml
   - hostPath:
       path: /var/log
   ```

2. **Container Runtime Socket**
   ```yaml
   - hostPath:
       path: /var/run/docker.sock
       type: Socket
   ```

3. **Host Metrics**
   ```yaml
   - hostPath:
       path: /proc
   - hostPath:
       path: /sys
   ```

4. **Certificate Storage**
   ```yaml
   - hostPath:
       path: /etc/ssl/certs
       type: Directory
   ```

📋 Create a DaemonSet that collects logs from `/var/log` with appropriate security settings.

<details>
  <summary>Not sure how?</summary>

Deploy secure log collector:

```bash
# Deploy log collector with security best practices
kubectl apply -f labs/daemonsets/specs/ckad/log-collector-secure.yaml

# Verify deployment
kubectl get daemonset log-collector
kubectl get pods -l app=log-collector -o wide

# Check security context
kubectl get daemonset log-collector -o yaml | grep -A 10 securityContext

# View the security settings:
# - runAsNonRoot: true
# - runAsUser: 1000 (non-root user)
# - readOnlyRootFilesystem: true
# - allowPrivilegeEscalation: false
# - capabilities dropped: ALL
# - hostPath volumes mounted read-only
```

View logs from the collector:

```bash
# Get pod name
POD=$(kubectl get pod -l app=log-collector -o jsonpath='{.items[0].metadata.name}')

# View collector logs
kubectl logs $POD --tail=50

# Check resource usage
kubectl top pod $POD
```

Verify read-only access:

```bash
# Exec into pod
kubectl exec -it $POD -- sh

# Inside container:
# Can read logs (if permissions allow)
ls -la /var/log/ 2>/dev/null || echo "Limited access due to security context (expected)"

# Cannot write to host paths (read-only mount)
touch /var/log/test.txt 2>&1  # Should fail

# Cannot write to container root (read-only filesystem)
touch /test.txt 2>&1  # Should fail

# Exit
exit
```

Compare with insecure approach:

```bash
# View the differences
echo "=== Secure Configuration ==="
kubectl get daemonset log-collector -o yaml | grep -A 15 securityContext

echo "=== Volume Mounts ==="
kubectl get daemonset log-collector -o yaml | grep -A 5 volumeMounts
```

Test on multiple nodes:

```bash
# View pods across all nodes
kubectl get pods -l app=log-collector -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,STATUS:.status.phase

# View logs from all pods
kubectl logs -l app=log-collector --tail=10 --prefix=true
```

Cleanup:

```bash
kubectl delete daemonset log-collector
```

**Key Security Features:**
- Non-root user (UID 1000)
- Read-only host path mounts
- Read-only root filesystem
- No privilege escalation
- All capabilities dropped
- Minimal resource requests/limits
- Seccomp profile applied

</details><br/>

## Host Networking and Ports

DaemonSets can use host networking for direct node access.

### Host Network Mode

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: network-monitor
spec:
  selector:
    matchLabels:
      app: network-monitor
  template:
    metadata:
      labels:
        app: network-monitor
    spec:
      hostNetwork: true  # Use host network namespace
      hostPID: true      # Use host PID namespace (optional)
      hostIPC: true      # Use host IPC namespace (optional)
      dnsPolicy: ClusterFirstWithHostNet  # Maintain k8s DNS

      containers:
      - name: monitor
        image: network-monitor:latest
        ports:
        - containerPort: 9100
          hostPort: 9100  # Expose on host
          protocol: TCP
```

### Host Ports

Expose container ports directly on the node:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
spec:
  selector:
    matchLabels:
      app: node-exporter
  template:
    metadata:
      labels:
        app: node-exporter
    spec:
      containers:
      - name: exporter
        image: prom/node-exporter
        ports:
        - containerPort: 9100
          hostPort: 9100  # Accessible at node-ip:9100
          name: metrics
```

### Comparing hostNetwork vs hostPort

Deploy both types to see the difference:

**Deploy hostNetwork DaemonSet:**

```bash
# Deploy with hostNetwork: true
kubectl apply -f labs/daemonsets/specs/ckad/host-network.yaml

# Check DaemonSet
kubectl get daemonset network-monitor-hostnet
kubectl get pods -l mode=hostnetwork -o wide

# Get pod details
POD_HOSTNET=$(kubectl get pod -l mode=hostnetwork -o jsonpath='{.items[0].metadata.name}')

# Check pod IP (should match node IP)
kubectl get pod $POD_HOSTNET -o jsonpath='{.status.podIP}'; echo
kubectl get pod $POD_HOSTNET -o jsonpath='{.status.hostIP}'; echo
# These IPs should be the SAME
```

**Deploy hostPort DaemonSet:**

```bash
# Deploy with hostPort
kubectl apply -f labs/daemonsets/specs/ckad/host-port.yaml

# Check DaemonSet
kubectl get daemonset network-monitor-hostport
kubectl get pods -l mode=hostport -o wide

# Get pod details
POD_HOSTPORT=$(kubectl get pod -l mode=hostport -o jsonpath='{.items[0].metadata.name}')

# Check pod IP (different from node IP)
kubectl get pod $POD_HOSTPORT -o jsonpath='{.status.podIP}'; echo
kubectl get pod $POD_HOSTPORT -o jsonpath='{.status.hostIP}'; echo
# These IPs should be DIFFERENT
```

**Compare the differences:**

```bash
# hostNetwork pod uses host's network namespace
echo "=== hostNetwork Pod ==="
kubectl exec $POD_HOSTNET -- hostname -i

# hostPort pod uses pod network but exposes port on host
echo "=== hostPort Pod ==="
kubectl exec $POD_HOSTPORT -- hostname -i

# View DNS policy
echo "=== DNS Policies ==="
kubectl get pod $POD_HOSTNET -o jsonpath='{.spec.dnsPolicy}'; echo
kubectl get pod $POD_HOSTPORT -o jsonpath='{.spec.dnsPolicy}'; echo
```

**Key Differences:**

| Feature | hostNetwork | hostPort |
|---------|-------------|----------|
| Pod IP | Same as node IP | Different from node IP |
| Network Namespace | Host network namespace | Pod network namespace |
| DNS | Uses ClusterFirstWithHostNet | Uses ClusterFirst |
| Port Conflicts | Across all pods on node | Only for same hostPort |
| Use Case | Network monitoring, CNI | Metrics exporters |
| Security | Less isolated | Better isolation |

**Test connectivity:**

```bash
# Get node IP
NODE_IP=$(kubectl get pod $POD_HOSTNET -o jsonpath='{.status.hostIP}')

# Test hostNetwork service (if nc/netcat is available)
# curl http://$NODE_IP:9100

# Test hostPort service
# curl http://$NODE_IP:9101

# From within cluster
kubectl run test-pod --image=busybox --rm -it --restart=Never -- wget -qO- http://$NODE_IP:9101
```

**Cleanup:**

```bash
kubectl delete daemonset network-monitor-hostnet network-monitor-hostport
```

## Pod Affinity with DaemonSets

Schedule Pods relative to DaemonSet Pods.

### Co-locate with DaemonSet Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: debug-pod
spec:
  affinity:
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app: nginx-ds  # DaemonSet Pod label
        topologyKey: kubernetes.io/hostname
  containers:
  - name: debug
    image: busybox
    command: ['sleep', '3600']
```

This Pod will be scheduled on the same node as the DaemonSet Pod.

### Avoid DaemonSet Pods

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: heavy-daemonset
              topologyKey: kubernetes.io/hostname
      containers:
      - name: app
        image: myapp:latest
```

### Debugging with Pod Affinity

Use pod affinity to schedule a debug pod on the same node as a DaemonSet pod:

**Deploy DaemonSet:**

```bash
# Deploy the DaemonSet
kubectl apply -f labs/daemonsets/specs/ckad/debug-daemonset.yaml

# Verify deployment
kubectl get daemonset app-daemonset
kubectl get pods -l app=myapp -o wide

# Note which nodes have pods
kubectl get pods -l app=myapp -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName
```

**Deploy debug pod with affinity:**

```bash
# Deploy debug pod (will be co-located with DaemonSet pod)
kubectl apply -f labs/daemonsets/specs/ckad/debug-pod-affinity.yaml

# Wait for pod to be scheduled
kubectl get pod debug-pod -o wide

# Verify it's on same node as a DaemonSet pod
DS_POD=$(kubectl get pod -l app=myapp -o jsonpath='{.items[0].metadata.name}')
DS_NODE=$(kubectl get pod $DS_POD -o jsonpath='{.spec.nodeName}')
DEBUG_NODE=$(kubectl get pod debug-pod -o jsonpath='{.spec.nodeName}')

echo "DaemonSet pod on node: $DS_NODE"
echo "Debug pod on node: $DEBUG_NODE"
# Should be the same node
```

**Use debug pod to troubleshoot:**

```bash
# Access shared HostPath volume
kubectl exec -it debug-pod -- sh

# Inside debug pod:
# Access shared volume
ls -la /shared/

# Create test file
echo "Debug test" > /shared/test.txt

# Exit
exit

# Verify from DaemonSet pod
kubectl exec $DS_POD -- ls -la /usr/share/nginx/html/
kubectl exec $DS_POD -- cat /usr/share/nginx/html/test.txt
```

**Debug networking:**

```bash
# From debug pod, test connectivity to DaemonSet pod
DS_POD_IP=$(kubectl get pod $DS_POD -o jsonpath='{.status.podIP}')

kubectl exec debug-pod -- sh -c "
  echo 'Testing connectivity to DaemonSet pod...'
  wget -qO- http://$DS_POD_IP:80 || echo 'Connection failed'
"

# Check if both pods see same node resources
kubectl exec debug-pod -- df -h /shared
kubectl exec $DS_POD -- df -h /usr/share/nginx/html
```

**When to use this pattern:**
- Debugging DaemonSet pods without disrupting them
- Accessing shared host resources for investigation
- Testing network connectivity from same node
- Inspecting shared volumes
- Running diagnostic tools alongside production pods

**Cleanup:**

```bash
kubectl delete pod debug-pod
kubectl delete daemonset app-daemonset
# Clean up shared directory
sudo rm -rf /tmp/shared-data 2>/dev/null || true
```

## Resource Management

Set resource requests and limits for DaemonSet Pods.

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: resource-managed
spec:
  selector:
    matchLabels:
      app: resource-managed
  template:
    metadata:
      labels:
        app: resource-managed
    spec:
      containers:
      - name: app
        image: myapp:latest
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"

      # Priority for critical system DaemonSets
      priorityClassName: system-node-critical
```

### Priority Classes for DaemonSets

System DaemonSets should use priority classes:

- `system-node-critical` - Highest priority for critical node services
- `system-cluster-critical` - High priority for critical cluster services

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: critical-system-ds
spec:
  selector:
    matchLabels:
      app: critical-system
  template:
    metadata:
      labels:
        app: critical-system
    spec:
      priorityClassName: system-node-critical
      containers:
      - name: app
        image: critical-app:latest
```

### Priority Class Preemption Example

Demonstrate how high-priority DaemonSets can preempt lower-priority pods:

```bash
# First, deploy normal-priority deployment (fills up nodes)
kubectl apply -f labs/daemonsets/specs/ckad/priority-class-demo.yaml

# Check deployed resources
kubectl get deployment normal-priority-app
kubectl get pods -l app=normal-app -o wide

# Now deploy critical DaemonSet
# If nodes are full, it will preempt normal-priority pods
kubectl get daemonset critical-system-ds
kubectl get pods -l app=critical-system -o wide

# Check events to see preemption
kubectl get events --sort-by='.lastTimestamp' | grep -i preempt

# Describe a node to see priority-based scheduling
kubectl describe node <node-name> | grep -A 5 "Priority"
```

**Check priority classes:**

```bash
# View built-in priority classes
kubectl get priorityclasses

# system-node-critical has highest priority
kubectl get priorityclass system-node-critical -o yaml

# Compare priorities
echo "=== Critical DaemonSet Priority ==="
kubectl get daemonset critical-system-ds -o jsonpath='{.spec.template.spec.priorityClassName}'; echo

echo "=== Normal App Priority ==="
kubectl get deployment normal-priority-app -o jsonpath='{.spec.template.spec.priorityClassName}'; echo
# Empty means default priority (0)
```

**Observe resource distribution:**

```bash
# Count pods per type
echo "Critical system pods: $(kubectl get pods -l app=critical-system | grep -c Running)"
echo "Normal priority pods: $(kubectl get pods -l app=normal-app | grep -c Running)"

# If nodes were full, some normal pods may have been evicted
kubectl get pods -l app=normal-app -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,REASON:.status.reason
```

**Priority class values (built-in):**
- `system-node-critical`: 2000001000 (highest)
- `system-cluster-critical`: 2000000000
- Default: 0 (no priorityClassName specified)

**Cleanup:**

```bash
kubectl delete daemonset critical-system-ds
kubectl delete deployment normal-priority-app
```

## Differences: DaemonSet vs Deployment

| Feature | DaemonSet | Deployment |
|---------|-----------|------------|
| **Replicas** | Automatic (one per node) | Manual specification |
| **Scheduling** | One per node | Distributed by scheduler |
| **Update Strategy** | RollingUpdate (remove first) | RollingUpdate (create first) |
| **Use Case** | Node-level services | Application workloads |
| **Scaling** | Add/remove nodes | Change replica count |
| **Node Selector** | Common | Less common |
| **HostPath Volumes** | Common | Rare |

### When to Use DaemonSet

- **Monitoring agents** (node-exporter, datadog-agent)
- **Log collectors** (fluentd, filebeat)
- **Network plugins** (calico, weave)
- **Storage plugins** (ceph, glusterfs)
- **Security agents** (falco, sysdig)
- **Node maintenance** (node-problem-detector)

### When to Use Deployment

- **Stateless applications**
- **APIs and web services**
- **Background workers**
- **Anything needing horizontal scaling**

### Decision Tree: DaemonSet vs Deployment

```
                    Need to run on specific nodes?
                               |
                    +----------+----------+
                    |                     |
                   YES                   NO
                    |                     |
            One per node?          How many replicas?
                    |                     |
         +----------+----------+    +-----+-----+
         |                     |    |           |
        YES                   NO    Fixed    Scalable
         |                     |    Count       |
         |                     |      |         |
    DaemonSet            Deployment  |    Deployment
         |                     |      |         |
    Examples:              StatefulSet|    Examples:
    - Logging                   |     |    - Web apps
    - Monitoring          Examples:   |    - APIs
    - Network plugins     - Apps need|    - Workers
    - Storage plugins       fixed    |
    - Security agents       replicas |
                           - Databases
                           - Kafka
```

**Quick Decision Guide:**

| Question | DaemonSet | Deployment |
|----------|-----------|------------|
| Need one copy per node? | ✅ YES | ❌ NO |
| Need to access host resources? | ✅ Usually | ❌ Rarely |
| Need to control replica count? | ❌ NO | ✅ YES |
| Infrastructure/platform component? | ✅ Usually | ❌ Usually not |
| Application workload? | ❌ Usually not | ✅ YES |
| Need horizontal scaling? | ❌ NO | ✅ YES |
| Scales with nodes? | ✅ YES | ❌ NO |

**Real-world examples:**

```bash
# DaemonSet use cases
kubectl get daemonsets -A
# Common:
# - kube-proxy (networking)
# - node-exporter (monitoring)
# - fluentd (logging)
# - calico-node (CNI)

# Deployment use cases
kubectl get deployments -A
# Common:
# - coredns (DNS service)
# - metrics-server (metrics API)
# - ingress-controller (might be DaemonSet too)
# - application workloads
```

## Troubleshooting DaemonSets

### Common Issues

**Issue 1: Pods Not Scheduling**

```bash
# Check DaemonSet status
kubectl get daemonset my-ds

# Check Pod status
kubectl get pods -l app=my-ds

# Describe DaemonSet for events
kubectl describe daemonset my-ds

# Check node labels
kubectl get nodes --show-labels

# Common causes:
# - nodeSelector doesn't match any nodes
# - Insufficient node resources
# - Taints without tolerations
# - Pod security policy violations
```

**Issue 2: Update Stuck**

```bash
# Check update status
kubectl rollout status daemonset/my-ds

# Check rollout history
kubectl rollout history daemonset/my-ds

# Check Pod events
kubectl describe pod -l app=my-ds

# Common causes:
# - Invalid image
# - Misconfigured probes
# - Resource constraints
# - maxUnavailable too restrictive
```

**Issue 3: Pods on Wrong Nodes**

```bash
# Check Pod distribution
kubectl get pods -l app=my-ds -o wide

# Verify node labels
kubectl get nodes -L disktype,zone

# Check DaemonSet node selector
kubectl get daemonset my-ds -o yaml | grep -A 5 nodeSelector

# Verify tolerations
kubectl get daemonset my-ds -o yaml | grep -A 10 tolerations
```

### Debugging Commands

```bash
# Get DaemonSet details
kubectl get daemonset
kubectl get daemonset my-ds -o yaml
kubectl describe daemonset my-ds

# Check rollout status
kubectl rollout status daemonset/my-ds
kubectl rollout history daemonset/my-ds

# Rollback if needed
kubectl rollout undo daemonset/my-ds
kubectl rollout undo daemonset/my-ds --to-revision=2

# Check Pods
kubectl get pods -l app=my-ds -o wide
kubectl describe pod -l app=my-ds
kubectl logs -l app=my-ds
kubectl logs -l app=my-ds --previous  # Previous container logs

# Check node readiness
kubectl get nodes
kubectl describe node node-1

# Check Pod scheduling
kubectl get events --sort-by='.lastTimestamp'
kubectl describe node node-1 | grep -A 10 "Non-terminated Pods"

# Delete and recreate specific Pod
kubectl delete pod my-ds-abc123

# Force delete if stuck
kubectl delete pod my-ds-abc123 --grace-period=0 --force
```

### Troubleshooting Scenario: Failed Update

**Scenario:** DaemonSet update is stuck with some pods failing to start.

**Step 1: Identify the problem**

```bash
# Check DaemonSet status
kubectl get daemonset broken-app
# Shows: DESIRED=3, CURRENT=3, READY=0, UP-TO-DATE=1, AVAILABLE=0

# Check rollout status
kubectl rollout status daemonset/broken-app
# Output: Waiting for daemon set "broken-app" rollout to finish: 0 of 3 updated pods are available...

# Check pods
kubectl get pods -l app=broken-app
# Some pods in ImagePullBackOff or ErrImagePull
```

**Step 2: Investigate the failing pods**

```bash
# Describe a failing pod
POD=$(kubectl get pod -l app=broken-app -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod $POD

# Look for error messages:
# Events:
#   Failed to pull image "nginx:invalid-tag": rpc error: code = Unknown desc = Error response from daemon: manifest for nginx:invalid-tag not found

# Check image pull errors
kubectl get pod $POD -o jsonpath='{.status.containerStatuses[0].state.waiting.message}'; echo
```

**Step 3: Check DaemonSet history**

```bash
# View rollout history
kubectl rollout history daemonset/broken-app

# Check previous revision
kubectl rollout history daemonset/broken-app --revision=1
```

**Step 4: Fix the issue**

Option A: Rollback to previous version:

```bash
# Rollback to last known good version
kubectl rollout undo daemonset/broken-app

# Watch rollback progress
kubectl rollout status daemonset/broken-app

# Verify pods are running
kubectl get pods -l app=broken-app
```

Option B: Fix the configuration:

```bash
# Edit DaemonSet to fix image
kubectl edit daemonset broken-app
# Change image from "nginx:invalid-tag" to "nginx:alpine"

# Watch the update
kubectl get pods -l app=broken-app -w

# Verify all pods are running
kubectl get daemonset broken-app
```

**Step 5: Verify the fix**

```bash
# Check all pods are ready
kubectl get pods -l app=broken-app -o wide

# Check DaemonSet is healthy
kubectl get daemonset broken-app
# Should show: DESIRED=3, CURRENT=3, READY=3, UP-TO-DATE=3, AVAILABLE=3

# Test application
POD=$(kubectl get pod -l app=broken-app -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -- nginx -v
```

**Practice this scenario:**

```bash
# Create the broken DaemonSet
kubectl apply -f labs/daemonsets/specs/ckad/broken-update.yaml

# Follow steps above to identify and fix
# ...

# Apply the fixed version
kubectl apply -f labs/daemonsets/specs/ckad/broken-update-fixed.yaml

# Verify fix
kubectl get pods -l app=broken-app

# Cleanup
kubectl delete daemonset broken-app
```

## Lab Exercises

### Exercise 1: Create Multi-Node DaemonSet

Create a DaemonSet that:
- Runs nginx on all nodes
- Uses RollingUpdate strategy with maxUnavailable=1
- Includes resource requests and limits
- Exposes metrics on hostPort 9090

<details>
  <summary>Solution</summary>

**Deploy the DaemonSet:**

```bash
# Apply the spec
kubectl apply -f labs/daemonsets/specs/ckad/exercise1-multinode.yaml

# Verify deployment
kubectl get daemonset nginx-metrics

# Check desired vs current
kubectl get daemonset nginx-metrics -o custom-columns=NAME:.metadata.name,DESIRED:.status.desiredNumberScheduled,CURRENT:.status.currentNumberScheduled,READY:.status.numberReady
```

**Verify pods on all nodes:**

```bash
# List all pods with their nodes
kubectl get pods -l app=nginx-metrics -o wide

# Count pods per node
kubectl get pods -l app=nginx-metrics -o custom-columns=NODE:.spec.nodeName --no-headers | sort | uniq -c

# Should see one pod per node
```

**Test resource limits:**

```bash
# Check resource configuration
kubectl get daemonset nginx-metrics -o jsonpath='{.spec.template.spec.containers[0].resources}' | jq

# Verify actual resource usage
kubectl top pods -l app=nginx-metrics
```

**Test hostPort exposure:**

```bash
# Get node IP
NODE_IP=$(kubectl get node -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# Test from within cluster
kubectl run test --image=busybox --rm -it --restart=Never -- wget -qO- http://$NODE_IP:9090 || echo "Port accessible"

# Check port binding
kubectl get pods -l app=nginx-metrics -o jsonpath='{.items[0].spec.containers[0].ports}' | jq
```

**Test update strategy:**

```bash
# Check update strategy
kubectl get daemonset nginx-metrics -o jsonpath='{.spec.updateStrategy}' | jq

# Update image to test RollingUpdate
kubectl set image daemonset/nginx-metrics nginx=nginx:1.25-alpine

# Watch the rollout (updates one node at a time with maxUnavailable: 1)
kubectl rollout status daemonset/nginx-metrics

# Check rollout history
kubectl rollout history daemonset/nginx-metrics
```

**Verify liveness and readiness probes:**

```bash
# Check probe configuration
kubectl get daemonset nginx-metrics -o jsonpath='{.spec.template.spec.containers[0].livenessProbe}' | jq
kubectl get daemonset nginx-metrics -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}' | jq

# View pod events for probe checks
POD=$(kubectl get pod -l app=nginx-metrics -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod $POD | grep -A 5 "Liveness\|Readiness"
```

**Cleanup:**

```bash
kubectl delete daemonset nginx-metrics
```

</details>

### Exercise 2: Controlled Rollout with OnDelete

Create a DaemonSet with OnDelete strategy:
1. Deploy initial version
2. Update to new version
3. Manually control rollout one node at a time
4. Rollback if issues occur

<details>
  <summary>Solution</summary>

**Step 1: Deploy initial version**

```bash
# Deploy version 1
kubectl apply -f labs/daemonsets/specs/ckad/exercise2-ondelete-v1.yaml

# Verify deployment
kubectl get daemonset controlled-rollout
kubectl get pods -l app=controlled-rollout -o wide

# Check version labels
kubectl get pods -l app=controlled-rollout -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,VERSION:.metadata.labels.version,IMAGE:.spec.containers[0].image
```

**Step 2: Update to new version (DaemonSet only, pods unchanged)**

```bash
# Apply version 2
kubectl apply -f labs/daemonsets/specs/ckad/exercise2-ondelete-v2.yaml

# DaemonSet is updated
kubectl get daemonset controlled-rollout -o jsonpath='{.spec.template.spec.containers[0].image}'; echo

# But pods still run v1 (OnDelete strategy)
kubectl get pods -l app=controlled-rollout -o custom-columns=NAME:.metadata.name,VERSION:.metadata.labels.version,IMAGE:.spec.containers[0].image
```

**Step 3: Manually rollout one node at a time**

```bash
# Get list of nodes with pods
kubectl get pods -l app=controlled-rollout -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName --no-headers

# Update first node
NODE1=$(kubectl get pod -l app=controlled-rollout -o jsonpath='{.items[0].spec.nodeName}')
echo "Updating pod on $NODE1"

# Delete pod on first node
kubectl delete pod -l app=controlled-rollout --field-selector spec.nodeName=$NODE1

# Wait for new pod to be ready
kubectl wait --for=condition=ready pod -l app=controlled-rollout --field-selector spec.nodeName=$NODE1 --timeout=60s

# Verify new version is running
kubectl get pods -l app=controlled-rollout -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,VERSION:.metadata.labels.version

# Test the application
POD=$(kubectl get pod -l app=controlled-rollout --field-selector spec.nodeName=$NODE1 -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -- cat /usr/share/nginx/html/index.html
# Should show "Version 2.0 - UPDATED"

# If successful, continue with next node
NODE2=$(kubectl get pod -l app=controlled-rollout -o jsonpath='{.items[1].spec.nodeName}')
echo "Updating pod on $NODE2"
kubectl delete pod -l app=controlled-rollout --field-selector spec.nodeName=$NODE2
kubectl wait --for=condition=ready pod -l app=controlled-rollout --field-selector spec.nodeName=$NODE2 --timeout=60s

# Continue for remaining nodes...
```

**Step 4: Rollback if issues occur**

```bash
# If problems detected on any node, rollback
kubectl apply -f labs/daemonsets/specs/ckad/exercise2-ondelete-v1.yaml

# Delete pods on affected nodes to rollback
kubectl delete pod -l app=controlled-rollout --field-selector spec.nodeName=$NODE1

# Verify rollback
kubectl get pods -l app=controlled-rollout -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,VERSION:.metadata.labels.version,IMAGE:.spec.containers[0].image
```

**Verify final state:**

```bash
# All pods should be on same version
kubectl get pods -l app=controlled-rollout -o custom-columns=NAME:.metadata.name,VERSION:.metadata.labels.version --no-headers | sort -k2 | uniq -c

# Check DaemonSet status
kubectl get daemonset controlled-rollout
```

**Cleanup:**

```bash
kubectl delete daemonset controlled-rollout
```

</details>

### Exercise 3: Node Selection Scenarios

Create three DaemonSets:
1. Runs only on nodes labeled `env=production`
2. Runs only on nodes with SSD storage
3. Runs on all nodes including master/control-plane

<details>
  <summary>Solution</summary>

**DaemonSet 1: Production nodes only**

```bash
# Label production nodes
kubectl label nodes <node-1> env=production
kubectl label nodes <node-2> env=production

# Verify labels
kubectl get nodes -L env

# Deploy production monitor
kubectl apply -f labs/daemonsets/specs/ckad/exercise3-production.yaml

# Verify it only runs on production nodes
kubectl get pods -l app=monitor,env=production -o wide

# Verify by node selector
kubectl get daemonset prod-monitor -o jsonpath='{.spec.template.spec.nodeSelector}' | jq
```

**DaemonSet 2: SSD nodes only**

```bash
# Label nodes with SSD storage
kubectl label nodes <node-1> disktype=ssd
# Assume node-1 has SSD

# Deploy SSD monitor
kubectl apply -f labs/daemonsets/specs/ckad/exercise3-ssd.yaml

# Verify it only runs on SSD nodes
kubectl get pods -l app=ssd-monitor -o wide
kubectl get daemonset ssd-monitor -o jsonpath='{.spec.template.spec.nodeSelector}' | jq

# Add another SSD node
kubectl label nodes <node-3> disktype=ssd

# Watch new pod get scheduled
kubectl get pods -l app=ssd-monitor -w

# Remove SSD label from a node
kubectl label nodes <node-3> disktype-

# Pod should be removed from that node
kubectl get pods -l app=ssd-monitor -o wide
```

**DaemonSet 3: All nodes including master**

```bash
# Deploy to all nodes
kubectl apply -f labs/daemonsets/specs/ckad/exercise3-all-nodes.yaml

# Verify it runs on ALL nodes
kubectl get pods -l app=all-nodes-monitor -o wide

# Check tolerations
kubectl get daemonset all-nodes-monitor -o jsonpath='{.spec.template.spec.tolerations}' | jq

# Count pods vs nodes
echo "Nodes: $(kubectl get nodes --no-headers | wc -l)"
echo "Pods: $(kubectl get pods -l app=all-nodes-monitor --no-headers | wc -l)"
# Should be equal

# Check if running on master/control-plane
kubectl get pods -l app=all-nodes-monitor -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName
```

**Verify all three DaemonSets:**

```bash
# List all DaemonSets
kubectl get daemonset -l exercise=ex3

# Summary of pod distribution
echo "=== Production Monitor ==="
kubectl get pods -l env=production -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName --no-headers

echo "=== SSD Monitor ==="
kubectl get pods -l app=ssd-monitor -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName --no-headers

echo "=== All Nodes Monitor ==="
kubectl get pods -l app=all-nodes-monitor -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName --no-headers
```

**Cleanup:**

```bash
# Delete DaemonSets
kubectl delete daemonset prod-monitor ssd-monitor all-nodes-monitor

# Remove labels
kubectl label nodes --all env- disktype-
```

</details>

### Exercise 4: Init Container Setup

Create a DaemonSet with init containers that:
1. Wait for a ConfigMap to exist
2. Download configuration from a URL
3. Set up directory permissions
4. Main container uses the prepared environment

<details>
  <summary>Solution</summary>

**Step 1: Create ConfigMap**

```bash
# Deploy ConfigMap and DaemonSet
kubectl apply -f labs/daemonsets/specs/ckad/exercise4-configmap.yaml

# Verify ConfigMap
kubectl get configmap app-config
kubectl describe configmap app-config
```

**Step 2: Watch initialization**

```bash
# Watch pods start
kubectl get pods -l app=init-demo -w

# Check init container status
kubectl get pods -l app=init-demo -o jsonpath='{.items[0].status.initContainerStatuses[*].name}'; echo
```

**Step 3: View init container logs**

```bash
# Get pod name
POD=$(kubectl get pod -l app=init-demo -o jsonpath='{.items[0].metadata.name}')

# View first init container (wait-for-config)
kubectl logs $POD -c wait-for-config

# View second init container (download-config)
kubectl logs $POD -c download-config

# View third init container (setup-directories)
kubectl logs $POD -c setup-directories

# View main container
kubectl logs $POD -c app
```

**Step 4: Verify prepared environment**

```bash
# Exec into running container
kubectl exec -it $POD -- sh

# Inside container:
# Check ConfigMap configuration
cat /etc/config/app.properties

# Check runtime configuration (created by init container)
cat /etc/runtime/runtime.conf

# Check directories (created by init container)
ls -la /var/app/data/
ls -la /var/app/data/logs/
ls -la /var/app/data/cache/

# Check log file (written by main container)
cat /var/app/data/logs/app.log

# Exit
exit
```

**Step 5: Test init container dependency chain**

```bash
# Delete pod to watch re-initialization
kubectl delete pod $POD

# Watch init containers run sequentially
kubectl get pods -l app=init-demo -w

# Each init container must complete before next starts
kubectl get pod -l app=init-demo -o jsonpath='{range .items[0].status.initContainerStatuses[*]}{.name}: {.state.terminated.reason}{"\n"}{end}'
```

**Step 6: Test ConfigMap dependency**

```bash
# Delete ConfigMap to see init container waiting
kubectl delete configmap app-config

# Delete pod to restart
POD=$(kubectl get pod -l app=init-demo -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod $POD

# Pod will be stuck in Init:0/3
kubectl get pods -l app=init-demo

# Recreate ConfigMap
kubectl apply -f labs/daemonsets/specs/ckad/exercise4-configmap.yaml

# Pod should complete initialization
kubectl get pods -l app=init-demo -w
```

**Step 7: Verify on multiple nodes**

```bash
# Check pods on all nodes
kubectl get pods -l app=init-demo -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,STATUS:.status.phase

# View logs from all pods
kubectl logs -l app=init-demo -c app --tail=5 --prefix=true
```

**Cleanup:**

```bash
kubectl delete -f labs/daemonsets/specs/ckad/exercise4-configmap.yaml
```

</details>

### Exercise 5: HostPath Log Collection

Create a DaemonSet that:
- Collects logs from `/var/log`
- Uses read-only HostPath volumes
- Implements proper security contexts
- Exports logs to stdout

<details>
  <summary>Solution</summary>

This exercise is already covered in detail above. Here's a summary workflow:

```bash
# Deploy secure log collector
kubectl apply -f labs/daemonsets/specs/ckad/log-collector-secure.yaml

# Verify security settings
kubectl get daemonset log-collector -o yaml | grep -A 15 securityContext

# Test read-only access
POD=$(kubectl get pod -l app=log-collector -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -- sh -c 'touch /var/log/test.txt 2>&1' || echo "Write blocked (expected)"

# View collected logs
kubectl logs $POD --tail=20

# Verify resource limits
kubectl top pod $POD

# Cleanup
kubectl delete daemonset log-collector
```

Refer to the "HostPath Volumes" section above for full details.

</details>

### Exercise 6: Debugging with Pod Affinity

Create:
1. A DaemonSet running on all nodes
2. A debug Pod that schedules on the same node as a specific DaemonSet Pod
3. Verify both Pods can access shared HostPath

<details>
  <summary>Solution</summary>

This exercise is covered in detail in the "Pod Affinity with DaemonSets" section above. Here's a summary workflow:

```bash
# Deploy DaemonSet
kubectl apply -f labs/daemonsets/specs/ckad/debug-daemonset.yaml

# Deploy debug pod with pod affinity
kubectl apply -f labs/daemonsets/specs/ckad/debug-pod-affinity.yaml

# Verify co-location
DS_POD=$(kubectl get pod -l app=myapp -o jsonpath='{.items[0].metadata.name}')
DS_NODE=$(kubectl get pod $DS_POD -o jsonpath='{.spec.nodeName}')
DEBUG_NODE=$(kubectl get pod debug-pod -o jsonpath='{.spec.nodeName}')
echo "DaemonSet on: $DS_NODE"
echo "Debug pod on: $DEBUG_NODE"

# Test shared volume access
kubectl exec debug-pod -- sh -c 'echo "test" > /shared/test.txt'
kubectl exec $DS_POD -- cat /usr/share/nginx/html/test.txt

# Cleanup
kubectl delete pod debug-pod
kubectl delete daemonset app-daemonset
```

Refer to the "Debugging with Pod Affinity" section above for full details.

</details>

## Common CKAD Scenarios

### Scenario 1: Deploy Monitoring Agent

**Task:** Deploy a node-exporter DaemonSet for Prometheus monitoring on all nodes including master.

**Requirements:**
- Runs on all nodes (including master/control-plane)
- Uses hostNetwork for access to node metrics
- Exposes metrics on port 9100
- Accesses `/proc`, `/sys`, and root filesystem
- Uses read-only mounts
- Includes a headless Service for discovery

**Solution:**

```bash
# Deploy node-exporter DaemonSet with Service
kubectl apply -f labs/daemonsets/specs/ckad/node-exporter.yaml

# Verify deployment on all nodes
kubectl get daemonset node-exporter
kubectl get pods -l app=node-exporter -o wide

# Check if running on master/control-plane
kubectl get pods -l app=node-exporter -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName | grep -i master || echo "Check control-plane nodes"

# Verify hostNetwork mode
kubectl get pod -l app=node-exporter -o jsonpath='{.items[0].spec.hostNetwork}'; echo

# Check exposed ports
kubectl get pod -l app=node-exporter -o jsonpath='{.items[0].spec.containers[0].ports}' | jq

# Test metrics endpoint (from within cluster)
NODE_IP=$(kubectl get node -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- curl -s http://$NODE_IP:9100/metrics | head -20

# Check Service
kubectl get service node-exporter
kubectl describe service node-exporter

# Verify volume mounts
kubectl get daemonset node-exporter -o jsonpath='{.spec.template.spec.volumes}' | jq
kubectl get daemonset node-exporter -o jsonpath='{.spec.template.spec.containers[0].volumeMounts}' | jq

# Test scraping from all nodes
for pod in $(kubectl get pods -l app=node-exporter -o jsonpath='{.items[*].metadata.name}'); do
  echo "=== $pod ==="
  kubectl exec $pod -- wget -qO- http://localhost:9100/metrics 2>/dev/null | head -5
done
```

**Verification checklist:**
- [ ] DaemonSet running on all nodes
- [ ] Tolerations configured for master nodes
- [ ] hostNetwork enabled
- [ ] Port 9100 accessible
- [ ] Read-only volume mounts
- [ ] Security context (non-root user)
- [ ] Headless Service created
- [ ] Metrics endpoint responding

**Cleanup:**

```bash
kubectl delete -f labs/daemonsets/specs/ckad/node-exporter.yaml
```

### Scenario 2: Fix Broken Update

**Task:** A DaemonSet update has failed. Identify the issue and fix it.

**Scenario:** Your team updated a DaemonSet but pods are failing to start. You need to troubleshoot and resolve the issue.

**Solution:**

```bash
# Deploy the broken DaemonSet
kubectl apply -f labs/daemonsets/specs/ckad/broken-update.yaml

# Step 1: Identify the problem
kubectl get daemonset broken-app
# Notice: DESIRED vs READY mismatch

kubectl get pods -l app=broken-app
# Pods in ImagePullBackOff or ErrImagePull

# Step 2: Check rollout status
kubectl rollout status daemonset/broken-app
# Will show: "Waiting for daemon set rollout to finish..."

# Step 3: Investigate failing pod
POD=$(kubectl get pod -l app=broken-app -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod $POD | tail -20

# Look for error message:
# "Failed to pull image "nginx:invalid-tag": manifest for nginx:invalid-tag not found"

# Check container status
kubectl get pod $POD -o jsonpath='{.status.containerStatuses[0].state}' | jq

# Step 4: Check rollout history
kubectl rollout history daemonset/broken-app

# Step 5: Fix the issue
# Option A: Rollback (if there's a previous version)
kubectl rollout undo daemonset/broken-app

# Option B: Fix and apply corrected version
kubectl apply -f labs/daemonsets/specs/ckad/broken-update-fixed.yaml

# Step 6: Verify the fix
kubectl rollout status daemonset/broken-app
kubectl get pods -l app=broken-app -o wide

# All pods should be Running
kubectl get daemonset broken-app
# DESIRED should equal READY

# Step 7: Test the application
POD=$(kubectl get pod -l app=broken-app -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -- nginx -v
kubectl exec $POD -- curl -s localhost

# View events
kubectl get events --field-selector involvedObject.kind=DaemonSet,involvedObject.name=broken-app --sort-by='.lastTimestamp'
```

**Common issues to check:**
1. **Image pull errors** - Invalid image tags
2. **Resource constraints** - Insufficient node resources
3. **Configuration errors** - Invalid environment variables
4. **Probe failures** - Misconfigured health checks
5. **Security policies** - Pod security policy violations
6. **Node selection** - nodeSelector/affinity issues

**Cleanup:**

```bash
kubectl delete daemonset broken-app
```

### Scenario 3: Migrate from Deployment to DaemonSet

**Task:** Convert a logging agent Deployment to a DaemonSet for better node coverage.

**Scenario:** Your logging agent is currently deployed as a Deployment with 3 replicas, but you want one instance on every node instead.

**Solution:**

```bash
# Step 1: Review current Deployment
kubectl apply -f labs/daemonsets/specs/ckad/deployment-to-convert.yaml

kubectl get deployment logging-agent
kubectl get pods -l app=logging -o wide

# Notice: Only 3 pods, may not cover all nodes
kubectl get nodes
# More nodes than pods

# Step 2: Analyze the Deployment spec
kubectl get deployment logging-agent -o yaml > /tmp/original-deployment.yaml

# Key differences to address:
# - Remove replicas field
# - Add tolerations for all nodes
# - Add update strategy
# - Ensure one pod per node coverage

# Step 3: Create DaemonSet spec from Deployment
# Manual conversion or use provided spec
cat labs/daemonsets/specs/ckad/deployment-converted.yaml

# Key changes made:
# - Changed kind from Deployment to DaemonSet
# - Removed replicas field
# - Added tolerations
# - Added updateStrategy
# - Added NODE_NAME environment variable
# - Added additional volume mounts

# Step 4: Delete Deployment
kubectl delete deployment logging-agent

# Verify pods are terminated
kubectl get pods -l app=logging
# Should show Terminating or no pods

# Step 5: Deploy DaemonSet
kubectl apply -f labs/daemonsets/specs/ckad/deployment-converted.yaml

# Step 6: Verify DaemonSet deployment
kubectl get daemonset logging-agent
kubectl get pods -l app=logging -o wide

# Count pods vs nodes
echo "Nodes: $(kubectl get nodes --no-headers | wc -l)"
echo "Pods: $(kubectl get pods -l app=logging --no-headers | wc -l)"
# Should be equal now

# Step 7: Verify functionality
POD=$(kubectl get pod -l app=logging -o jsonpath='{.items[0].metadata.name}')
kubectl logs $POD --tail=20

# Check volume mounts
kubectl exec $POD -- ls -la /var/log
kubectl exec $POD -- ls -la /var/lib/docker/containers 2>/dev/null || echo "Path may vary"

# Step 8: Verify coverage on all nodes
kubectl get pods -l app=logging -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName

# Each node should have exactly one pod
kubectl get pods -l app=logging -o custom-columns=NODE:.spec.nodeName --no-headers | sort | uniq -c
```

**Comparison:**

| Aspect | Deployment | DaemonSet |
|--------|-----------|-----------|
| Replicas | 3 (fixed) | One per node (automatic) |
| Node Coverage | Partial | Complete |
| Scaling | Manual | Automatic with nodes |
| Best For | Centralized logging | Per-node log collection |

**Cleanup:**

```bash
kubectl delete daemonset logging-agent
```

### Scenario 4: Schedule on Tainted Nodes

**Task:** Deploy a DaemonSet that runs on nodes with specific taints.

**Scenario:** Your cluster has nodes with special taints (`special=true:NoSchedule` and `dedicated=monitoring:NoSchedule`). You need to deploy a monitoring DaemonSet on these nodes.

**Solution:**

```bash
# Step 1: Check existing node taints
kubectl get nodes
kubectl describe nodes | grep -A 5 Taints

# Step 2: Add test taints to nodes (for practice)
# Taint a node with special workload
kubectl taint nodes <node-1> special=true:NoSchedule

# Taint another node for dedicated monitoring
kubectl taint nodes <node-2> dedicated=monitoring:NoSchedule

# Verify taints
kubectl describe node <node-1> | grep Taints
kubectl describe node <node-2> | grep Taints

# Step 3: Try deploying without tolerations (will fail on tainted nodes)
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: test-no-tolerations
spec:
  selector:
    matchLabels:
      app: test
  template:
    metadata:
      labels:
        app: test
    spec:
      containers:
      - name: test
        image: busybox
        command: ['sleep', '3600']
EOF

# Check where pods are scheduled
kubectl get pods -l app=test -o wide
# Won't be scheduled on tainted nodes

# Step 4: Deploy with proper tolerations
kubectl apply -f labs/daemonsets/specs/ckad/tainted-nodes-demo.yaml

# Step 5: Verify pods run on tainted nodes
kubectl get pods -l app=taint-tolerant -o wide

# Check pod tolerations
kubectl get daemonset taint-tolerant-app -o jsonpath='{.spec.template.spec.tolerations}' | jq

# Step 6: Verify pod on specifically tainted nodes
kubectl get pod -l app=taint-tolerant -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName

# Should see pods on both tainted and untainted nodes

# Step 7: Test taint variations
# Add a taint that DaemonSet doesn't tolerate
kubectl taint nodes <node-3> no-pods=true:NoSchedule

# Check if pod still doesn't schedule there
kubectl get pods -l app=taint-tolerant -o wide | grep node-3
# Should not appear (if node-3 was used)

# Step 8: Update DaemonSet to tolerate all taints
kubectl patch daemonset taint-tolerant-app -p '{"spec":{"template":{"spec":{"tolerations":[{"operator":"Exists"}]}}}}'

# Now pod should schedule on node-3
kubectl get pods -l app=taint-tolerant -o wide

# Step 9: View events for scheduling decisions
kubectl get events --field-selector involvedObject.kind=Pod --sort-by='.lastTimestamp' | grep -i taint
```

**Understanding tolerations:**

```yaml
# Exact match toleration
tolerations:
- key: "special"
  operator: "Equal"
  value: "true"
  effect: "NoSchedule"

# Key-only toleration (any value)
- key: "dedicated"
  operator: "Exists"
  effect: "NoSchedule"

# Tolerate all taints
- operator: "Exists"
```

**Taint effects:**
- `NoSchedule` - New pods won't schedule (existing pods stay)
- `PreferNoSchedule` - Try to avoid scheduling
- `NoExecute` - Evict existing pods that don't tolerate

**Cleanup:**

```bash
# Remove DaemonSets
kubectl delete daemonset test-no-tolerations taint-tolerant-app

# Remove taints
kubectl taint nodes <node-1> special-
kubectl taint nodes <node-2> dedicated-
kubectl taint nodes <node-3> no-pods-

# Verify taints removed
kubectl describe nodes | grep Taints
```

## Best Practices for CKAD

1. **Update Strategy**
   - Use RollingUpdate for most cases
   - Use OnDelete for critical infrastructure changes
   - Set appropriate maxUnavailable for cluster size

2. **Resource Management**
   - Always set resource requests and limits
   - Use priorityClassName for system DaemonSets
   - Monitor resource usage per node

3. **Security**
   - Minimize HostPath usage
   - Use readOnly mounts when possible
   - Apply security contexts
   - Use least-privilege service accounts

4. **Node Selection**
   - Use nodeSelector for simple cases
   - Use node affinity for complex rules
   - Add tolerations for system DaemonSets

5. **High Availability**
   - Consider maxUnavailable during updates
   - Test updates in non-production first
   - Have rollback plan ready

6. **Monitoring**
   - Expose metrics from DaemonSet Pods
   - Monitor resource usage per node
   - Alert on failed updates

## Quick Reference Commands

```bash
# Create DaemonSet
kubectl apply -f daemonset.yaml

# Get DaemonSets
kubectl get daemonset
kubectl get ds  # Short form

# Describe DaemonSet
kubectl describe daemonset my-ds

# Get DaemonSet YAML
kubectl get daemonset my-ds -o yaml

# Edit DaemonSet
kubectl edit daemonset my-ds

# Update DaemonSet from file
kubectl apply -f daemonset-updated.yaml

# Check rollout status
kubectl rollout status daemonset/my-ds

# View rollout history
kubectl rollout history daemonset/my-ds

# Rollback DaemonSet
kubectl rollout undo daemonset/my-ds
kubectl rollout undo daemonset/my-ds --to-revision=2

# Delete DaemonSet (keeps Pods)
kubectl delete daemonset my-ds --cascade=orphan

# Delete DaemonSet and Pods
kubectl delete daemonset my-ds

# Get Pods from DaemonSet
kubectl get pods -l app=my-ds -o wide

# Scale by adding node label
kubectl label node node-1 app=enabled

# Remove from node
kubectl label node node-1 app-

# Manual Pod deletion for OnDelete strategy
kubectl delete pod my-ds-abc123

# Check which nodes have DaemonSet Pods
kubectl get pods -l app=my-ds -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName

# View DaemonSet events
kubectl get events --field-selector involvedObject.kind=DaemonSet
```

## Cleanup

Remove all DaemonSets created in these exercises:

```bash
# Delete specific DaemonSet
kubectl delete daemonset my-ds

# Delete multiple DaemonSets
kubectl delete daemonset ds1 ds2 ds3

# Delete all DaemonSets with label
kubectl delete daemonset -l exercise=ckad

# Delete DaemonSet but keep Pods running
kubectl delete daemonset my-ds --cascade=orphan
```

---

## Next Steps

After mastering DaemonSets, continue with these CKAD topics:
- [Deployments](../deployments/CKAD.md) - Application deployment and scaling
- [StatefulSets](../statefulsets/CKAD.md) - Stateful application management
- [Jobs](../jobs/CKAD.md) - Batch workloads
- [Services](../services/CKAD.md) - Networking for DaemonSet Pods
