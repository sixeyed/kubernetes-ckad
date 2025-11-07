# Clusters - CKAD Exam Topics

This document covers the CKAD exam requirements for working with multi-node Kubernetes clusters. Make sure you've completed the [basic Clusters lab](README.md) first, as it covers fundamental concepts of cluster architecture and node management.

## CKAD Cluster Management Requirements

The CKAD exam expects you to understand and work with:

- Multi-node cluster architecture
- Node labels and selectors
- Taints and tolerations
- Pod scheduling controls
- Affinity and anti-affinity rules
- Node maintenance (cordon, drain, uncordon)
- DaemonSets for node-level workloads
- Resource requests and limits affecting scheduling
- Understanding API version compatibility

## Reference

- [Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)
- [Node Selector](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector)
- [Node Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity)
- [DaemonSets](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)
- [Managing Resources](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)

## Understanding Node Labels

Every node in a Kubernetes cluster has labels that identify its characteristics:

### Standard Node Labels

```bash
# View all node labels
kubectl get nodes --show-labels

# View specific labels
kubectl get nodes -o custom-columns=NAME:.metadata.name,LABELS:.metadata.labels
```

**Built-in labels (always present):**

| Label | Purpose | Example Values |
|-------|---------|----------------|
| `kubernetes.io/hostname` | Node hostname | `node-1`, `ip-10-0-1-23` |
| `kubernetes.io/os` | Operating system | `linux`, `windows` |
| `kubernetes.io/arch` | CPU architecture | `amd64`, `arm64` |
| `node.kubernetes.io/instance-type` | Instance type | `t3.medium`, `n1-standard-2` |
| `topology.kubernetes.io/zone` | Availability zone | `us-east-1a`, `europe-west1-b` |
| `topology.kubernetes.io/region` | Cloud region | `us-east-1`, `europe-west1` |

**Special labels:**

| Label | Purpose |
|-------|---------|
| `node-role.kubernetes.io/control-plane` | Marks control plane nodes |
| `node-role.kubernetes.io/master` | Legacy control plane label |

### Adding Custom Labels

```bash
# Add a label to a node
kubectl label node <node-name> environment=production

# Add multiple labels
kubectl label node <node-name> disk-type=ssd storage=high-performance

# Update existing label (requires --overwrite)
kubectl label node <node-name> environment=staging --overwrite

# Remove a label
kubectl label node <node-name> environment-

# View updated labels
kubectl get nodes --show-labels
```

**Common custom label patterns:**

```bash
# Environment
kubectl label node node-1 environment=production

# Hardware characteristics
kubectl label node node-1 disk=ssd
kubectl label node node-2 disk=hdd
kubectl label node node-3 gpu=nvidia-t4

# Workload types
kubectl label node node-1 workload=compute-intensive
kubectl label node node-2 workload=memory-intensive

# Team or project
kubectl label node node-1 team=backend
kubectl label node node-2 team=frontend
```

### Exercise: Working with Node Labels

Try these node labeling operations:

```bash
# 1. View all node labels
kubectl get nodes --show-labels

# 2. View specific label columns
kubectl get nodes -o custom-columns=NAME:.metadata.name,LABELS:.metadata.labels

# 3. Add custom labels to first node
kubectl label node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') environment=production
kubectl label node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') disk=ssd

# 4. Query nodes by label selector
kubectl get nodes -l environment=production
kubectl get nodes -l disk=ssd

# 5. Use multiple selectors (AND logic)
kubectl get nodes -l environment=production,disk=ssd

# 6. Update existing label (requires --overwrite)
kubectl label node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') environment=staging --overwrite

# 7. Remove a label (note the minus sign)
kubectl label node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') disk-

# 8. View updated labels
kubectl get nodes --show-labels
```

**Practice with example manifests:**

```bash
# Label nodes using the provided script
chmod +x specs/ckad/labels/label-nodes.sh
./specs/ckad/labels/label-nodes.sh

# Deploy Pods with node selectors
kubectl apply -f specs/ckad/labels/node-label-examples.yaml

# Verify Pods scheduled on correct nodes
kubectl get pods -o wide

# Check which Pod is waiting (no matching node)
kubectl get pods
kubectl describe pod <pending-pod-name>

# Cleanup
kubectl delete -f specs/ckad/labels/node-label-examples.yaml
```

## Node Selectors

Node selectors are the simplest way to constrain Pods to specific nodes:

### Basic Node Selector

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-app
spec:
  nodeSelector:
    disk: ssd
  containers:
  - name: nginx
    image: nginx
```

Pod will **only** be scheduled on nodes with `disk=ssd` label.

### Using Standard Labels

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: linux-app
spec:
  nodeSelector:
    kubernetes.io/os: linux
    kubernetes.io/arch: amd64
  containers:
  - name: app
    image: myapp:latest
```

### Multiple Node Selectors

All labels must match (AND logic):

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-app
spec:
  nodeSelector:
    gpu: nvidia-t4
    environment: production
  containers:
  - name: ml-app
    image: ml-training:v1
```

Pod needs a node with **both** `gpu=nvidia-t4` AND `environment=production`.

### Deployment with Node Selector

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      nodeSelector:
        workload: compute-intensive
      containers:
      - name: api
        image: backend-api:v2
```

### Exercise: Node Selectors in Action

Practice node selector scheduling:

```bash
# 1. Label nodes with different characteristics
kubectl label node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') disk=ssd environment=production workload=compute-intensive

# If you have multiple nodes:
if [ $(kubectl get nodes --no-headers | wc -l) -gt 1 ]; then
  kubectl label node $(kubectl get nodes -o jsonpath='{.items[1].metadata.name}') disk=hdd environment=staging workload=memory-intensive
fi

# 2. Deploy Pods with basic node selectors
kubectl apply -f specs/ckad/node-selector/basic-selector.yaml

# 3. Verify Pods scheduled on correct nodes
kubectl get pods -o wide

# Check which nodes each Pod landed on
kubectl get pods -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,SELECTORS:.spec.nodeSelector

# 4. Deploy Deployments with node selectors
kubectl apply -f specs/ckad/node-selector/deployment-selector.yaml

# Watch Pods being scheduled
kubectl get pods -o wide -w

# 5. Deploy Pods with multiple selectors (all must match)
kubectl apply -f specs/ckad/node-selector/multiple-selectors.yaml

# 6. Test what happens when no nodes match
# Look for the "impossible-requirements" Pod
kubectl get pods
kubectl describe pod impossible-requirements

# You should see: "0/X nodes are available: X node(s) didn't match Pod's node affinity/selector"

# 7. Fix the pending Pod by updating node labels
kubectl label node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') region=mars
kubectl get pod impossible-requirements -o wide

# Cleanup
kubectl delete -f specs/ckad/node-selector/
kubectl label nodes --all region-
```

**Key observations:**
- Pods with matching node selectors schedule immediately
- Pods without matching nodes stay Pending
- All nodeSelector labels must match (AND logic)
- Standard Kubernetes labels work alongside custom labels

## Taints and Tolerations

Taints repel Pods from nodes unless the Pod has a matching toleration.

### Understanding Taints

**Taint structure:** `key=value:effect`

**Effects:**

| Effect | Behavior |
|--------|----------|
| `NoSchedule` | New Pods won't be scheduled (existing Pods unaffected) |
| `PreferNoSchedule` | Try to avoid scheduling here (soft constraint) |
| `NoExecute` | New Pods won't be scheduled, existing Pods evicted |

### Adding Taints to Nodes

```bash
# NoSchedule - no new Pods scheduled
kubectl taint nodes node-1 key=value:NoSchedule

# PreferNoSchedule - avoid if possible
kubectl taint nodes node-2 key=value:PreferNoSchedule

# NoExecute - evict existing Pods
kubectl taint nodes node-3 key=value:NoExecute

# Real examples
kubectl taint nodes node-1 dedicated=gpu:NoSchedule
kubectl taint nodes node-2 maintenance=true:NoExecute
kubectl taint nodes master node-role.kubernetes.io/master:NoSchedule

# Remove taint (note the minus sign)
kubectl taint nodes node-1 key=value:NoSchedule-
```

### Viewing Taints

```bash
# View all node taints
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

# Describe specific node
kubectl describe node <node-name> | grep Taints
```

### Pod Tolerations

Tolerations allow Pods to be scheduled on tainted nodes:

**Exact match toleration:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-workload
spec:
  tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "gpu"
    effect: "NoSchedule"
  containers:
  - name: gpu-app
    image: gpu-app:v1
```

**Wildcard toleration (tolerates any value):**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: system-monitor
spec:
  tolerations:
  - key: "node-role.kubernetes.io/master"
    operator: "Exists"
    effect: "NoSchedule"
  containers:
  - name: monitor
    image: prometheus-exporter:v1
```

**Tolerate all taints:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: admin-pod
spec:
  tolerations:
  - operator: "Exists"
  containers:
  - name: admin-tools
    image: admin-tools:v1
```

**Toleration with time limit (NoExecute only):**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: graceful-shutdown
spec:
  tolerations:
  - key: "node.kubernetes.io/unreachable"
    operator: "Exists"
    effect: "NoExecute"
    tolerationSeconds: 300
  containers:
  - name: app
    image: myapp:v1
```

Pod can stay for 300 seconds after node becomes unreachable before being evicted.

### Deployment with Tolerations

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: batch-processor
spec:
  replicas: 5
  selector:
    matchLabels:
      app: batch
  template:
    metadata:
      labels:
        app: batch
    spec:
      tolerations:
      - key: "disk"
        operator: "Equal"
        value: "hdd"
        effect: "NoSchedule"
      - key: "workload"
        operator: "Equal"
        value: "batch"
        effect: "PreferNoSchedule"
      containers:
      - name: processor
        image: batch-processor:v1
```

**Key Point:** Tolerations allow scheduling but don't guarantee it. Combine with node selectors or affinity for guaranteed placement.

### Exercise: Taints and Tolerations

Practice tainting nodes and using tolerations:

```bash
# 1. View current node taints
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

# 2. Taint a node with NoSchedule effect
kubectl taint node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') dedicated=gpu:NoSchedule

# 3. Try to deploy a Pod without toleration (will be Pending)
kubectl run no-toleration --image=nginx --restart=Never
kubectl get pod no-toleration
kubectl describe pod no-toleration | grep -A 5 Events

# You should see: "0/X nodes are available: X node(s) had taints that the pod didn't tolerate"

# 4. Deploy Pods with exact match tolerations
kubectl apply -f specs/ckad/taints/toleration-exact.yaml
kubectl get pods -o wide

# 5. Deploy Pods with Exists operator (wildcard)
kubectl apply -f specs/ckad/taints/toleration-exists.yaml
kubectl get pods -o wide

# 6. Test NoExecute taint (evicts existing Pods)
kubectl run test-eviction --image=nginx --restart=Never
sleep 3
kubectl get pod test-eviction -o wide

# Apply NoExecute taint
kubectl taint node $(kubectl get pod test-eviction -o jsonpath='{.spec.nodeName}') maintenance=true:NoExecute

# Pod will be evicted
kubectl get pod test-eviction

# 7. Deploy Pods with universal tolerations (runs anywhere)
kubectl apply -f specs/ckad/taints/toleration-all.yaml
kubectl get pods -o wide

# 8. Combine node selector with tolerations
kubectl apply -f specs/ckad/taints/combined-selector-toleration.yaml
kubectl get pods -o wide

# 9. Remove taints
kubectl taint node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') dedicated=gpu:NoSchedule-
kubectl taint nodes --all maintenance=true:NoExecute- --ignore-not-found=true

# 10. Cleanup
kubectl delete pod no-toleration test-eviction --ignore-not-found=true
kubectl delete -f specs/ckad/taints/
```

**Practice with the interactive script:**

```bash
chmod +x specs/ckad/taints/taint-examples.sh
./specs/ckad/taints/taint-examples.sh
```

**Key concepts:**
- **NoSchedule**: New Pods won't be scheduled (existing Pods stay)
- **PreferNoSchedule**: Soft constraint (try to avoid)
- **NoExecute**: New Pods won't schedule AND existing Pods are evicted
- **Toleration types**: Equal (exact match) vs Exists (wildcard)
- Combine tolerations with node selectors for precise placement

## Node Affinity

More expressive than node selectors, supporting complex scheduling rules:

### Required Node Affinity

Pod must be placed on matching nodes:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-app
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: disk
            operator: In
            values:
            - ssd
            - nvme
  containers:
  - name: nginx
    image: nginx
```

Pod requires nodes with `disk=ssd` OR `disk=nvme`.

### Preferred Node Affinity

Soft constraint, scheduler tries to honor but not required:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-app
spec:
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 1
        preference:
          matchExpressions:
          - key: disk
            operator: In
            values:
            - ssd
  containers:
  - name: nginx
    image: nginx
```

Scheduler prefers nodes with `disk=ssd` but will schedule elsewhere if needed.

### Affinity Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `In` | Value in list | `disk In [ssd, nvme]` |
| `NotIn` | Value not in list | `disk NotIn [hdd]` |
| `Exists` | Key exists | `gpu Exists` |
| `DoesNotExist` | Key doesn't exist | `spot DoesNotExist` |
| `Gt` | Greater than (numeric) | `cpu-count Gt 16` |
| `Lt` | Less than (numeric) | `memory-gb Lt 64` |

### Combining Required and Preferred

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: data-processor
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: kubernetes.io/arch
            operator: In
            values:
            - amd64
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 80
        preference:
          matchExpressions:
          - key: disk
            operator: In
            values:
            - ssd
      - weight: 20
        preference:
          matchExpressions:
          - key: network
            operator: In
            values:
            - 10gbit
  containers:
  - name: processor
    image: data-processor:v1
```

**Weight:** Higher weights are more preferred (1-100).

### Multiple Node Selector Terms (OR Logic)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: flexible-app
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: environment
            operator: In
            values:
            - production
        - matchExpressions:
          - key: environment
            operator: In
            values:
            - staging
          - key: region
            operator: In
            values:
            - us-east
  containers:
  - name: app
    image: myapp:v1
```

Pod can run on:
- Nodes with `environment=production` OR
- Nodes with `environment=staging` AND `region=us-east`

### Exercise: Node Affinity

Practice node affinity rules:

```bash
# 1. Label nodes for affinity testing
kubectl label node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') disk=ssd environment=production cpu-count=8

if [ $(kubectl get nodes --no-headers | wc -l) -gt 1 ]; then
  kubectl label node $(kubectl get nodes -o jsonpath='{.items[1].metadata.name}') disk=hdd environment=staging cpu-count=4
fi

# 2. Deploy with required affinity (hard constraint)
kubectl apply -f specs/ckad/affinity/required-affinity.yaml
kubectl get pods -o wide

# Check if any Pods are Pending
kubectl get pods | grep Pending

# 3. Deploy with preferred affinity (soft constraint)
kubectl apply -f specs/ckad/affinity/preferred-affinity.yaml
kubectl get pods -o wide

# Notice: Preferred Pods schedule even if preference not met

# 4. Deploy with combined affinity (required + preferred)
kubectl apply -f specs/ckad/affinity/combined-affinity.yaml
kubectl get pods -o wide

# 5. Test multiple selector terms (OR logic)
kubectl apply -f specs/ckad/affinity/multiple-terms.yaml
kubectl get pods -o wide

# 6. Test all operators
kubectl apply -f specs/ckad/affinity/operators-examples.yaml
kubectl get pods -o wide

# Check which operators work
kubectl describe pod operator-in | grep -A 5 Node-Selectors
kubectl describe pod operator-gt | grep -A 5 Node-Selectors

# 7. Compare node selector vs affinity
# Node selector - simple but inflexible
kubectl run simple --image=nginx --overrides='{"spec":{"nodeSelector":{"disk":"ssd"}}}'

# Affinity - more expressive
kubectl run advanced --image=nginx --dry-run=client -o yaml > /tmp/affinity-pod.yaml
# Edit to add affinity rules, then apply

# 8. Cleanup
kubectl delete -f specs/ckad/affinity/
kubectl delete pod simple advanced --ignore-not-found=true
kubectl label nodes --all disk- environment- cpu-count-
```

**Key observations:**
- **Required affinity**: Hard constraint, Pod won't schedule without match
- **Preferred affinity**: Soft constraint, scheduler tries but not mandatory
- **Weight**: Higher weights (1-100) are more preferred
- **OR logic**: Multiple nodeSelectorTerms create alternatives
- **AND logic**: Multiple matchExpressions within a term all must match
- More flexible than nodeSelector but more verbose

## Pod Affinity and Anti-Affinity

Control Pod placement relative to other Pods:

### Pod Affinity

Schedule Pods close to other Pods:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-frontend
spec:
  affinity:
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - cache
        topologyKey: kubernetes.io/hostname
  containers:
  - name: frontend
    image: web-frontend:v1
```

This Pod must be on the same node (`topologyKey: kubernetes.io/hostname`) as a Pod with `app=cache` label.

**Common topology keys:**
- `kubernetes.io/hostname` - Same node
- `topology.kubernetes.io/zone` - Same availability zone
- `topology.kubernetes.io/region` - Same region

### Pod Anti-Affinity

Keep Pods apart (high availability):

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
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - web
            topologyKey: kubernetes.io/hostname
      containers:
      - name: nginx
        image: nginx
```

Each replica will be on a different node (no two Pods with `app=web` on same node).

### Preferred Pod Anti-Affinity

Soft constraint for spreading:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-api
spec:
  replicas: 5
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - backend
              topologyKey: topology.kubernetes.io/zone
      containers:
      - name: api
        image: backend-api:v1
```

Try to spread across zones, but allow multiple Pods per zone if necessary.

### Combining Pod and Node Affinity

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: disk
            operator: In
            values:
            - ssd
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - database
        topologyKey: topology.kubernetes.io/zone
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app
              operator: In
              values:
              - app-pod
          topologyKey: kubernetes.io/hostname
  containers:
  - name: app
    image: myapp:v1
```

Requirements:
- Must run on SSD node (node affinity)
- Must be in same zone as database Pod (pod affinity)
- Prefer not to run on same node as other app-pod instances (pod anti-affinity)

### Exercise: Pod Affinity and Anti-Affinity

Practice Pod-to-Pod scheduling:

```bash
# 1. Deploy cache Pods first (they'll be the target for affinity)
kubectl apply -f specs/ckad/pod-affinity/affinity-same-node.yaml --selector='metadata.name=cache-pod'
kubectl get pods -o wide

# 2. Deploy app Pods with affinity to cache (same node)
kubectl apply -f specs/ckad/pod-affinity/affinity-same-node.yaml
kubectl get pods -o wide

# Verify: app-with-cache should be on same node as cache-pod
kubectl get pods -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName

# 3. Deploy Pods with zone affinity
kubectl apply -f specs/ckad/pod-affinity/affinity-same-zone.yaml
kubectl get pods -o wide

# Check zone distribution
kubectl get pods -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,ZONE:.spec.nodeAffinity

# 4. Deploy with anti-affinity (spread across nodes for HA)
kubectl apply -f specs/ckad/pod-affinity/anti-affinity-spread.yaml
kubectl get pods -o wide

# Verify spreading - each replica on different node
kubectl get pods -l app=web-ha -o wide

# If you have fewer nodes than replicas, some Pods will be Pending
kubectl get pods | grep Pending
kubectl describe pod <pending-pod> | grep -A 5 Events

# 5. Deploy with combined affinities
kubectl apply -f specs/ckad/pod-affinity/combined-affinities.yaml
kubectl get pods -o wide

# 6. Show Pod distribution visualization
echo "=== Pod Distribution Across Nodes ==="
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
  echo "Node: $node"
  kubectl get pods -o wide --all-namespaces --field-selector spec.nodeName=$node | grep -v NAME
  echo ""
done

# 7. Test anti-affinity behavior
# Scale up deployment with anti-affinity
kubectl scale deployment web-ha --replicas=10
kubectl get pods -l app=web-ha -o wide

# Some Pods may be Pending if you have fewer nodes than replicas

# 8. Cleanup
kubectl delete -f specs/ckad/pod-affinity/
```

**Key concepts:**
- **Pod affinity**: Schedule near other Pods (same node/zone/region)
- **Pod anti-affinity**: Schedule away from other Pods (spreading)
- **Topology key**: Defines "closeness" (hostname=node, zone=AZ, region=region)
- **Required**: Hard constraint (Pod won't schedule if not met)
- **Preferred**: Soft constraint (scheduler tries but not mandatory)
- Use anti-affinity for HA, affinity for locality (reduce latency)

## DaemonSets

Ensure a Pod runs on every node (or selected nodes):

### Basic DaemonSet

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
  namespace: monitoring
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
        image: prom/node-exporter:latest
        ports:
        - containerPort: 9100
```

One Pod per node automatically.

### DaemonSet with Node Selector

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: gpu-device-plugin
spec:
  selector:
    matchLabels:
      app: gpu-plugin
  template:
    metadata:
      labels:
        app: gpu-plugin
    spec:
      nodeSelector:
        accelerator: nvidia-gpu
      containers:
      - name: plugin
        image: nvidia-device-plugin:v1
```

One Pod per node with `accelerator=nvidia-gpu` label.

### DaemonSet with Tolerations

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd-logging
spec:
  selector:
    matchLabels:
      app: fluentd
  template:
    metadata:
      labels:
        app: fluentd
    spec:
      tolerations:
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
      - key: node.kubernetes.io/disk-pressure
        effect: NoSchedule
      containers:
      - name: fluentd
        image: fluentd:v1.14
```

Runs on all nodes including control plane and nodes under disk pressure.

### DaemonSet Update Strategy

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nginx-ingress
spec:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  selector:
    matchLabels:
      app: ingress
  template:
    metadata:
      labels:
        app: ingress
    spec:
      containers:
      - name: nginx
        image: nginx-ingress:v1.0
```

**Update strategies:**
- `RollingUpdate` - Update one node at a time (default)
- `OnDelete` - Update only when Pods manually deleted

### Exercise: DaemonSets

Practice DaemonSet deployment and management:

```bash
# 1. Deploy basic DaemonSet (runs on all worker nodes)
kubectl apply -f specs/ckad/daemonset/basic-daemonset.yaml
kubectl get daemonset
kubectl get pods -o wide -l app=node-monitor

# 2. Verify one Pod per node
echo "Pods per node:"
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | while read node; do
  count=$(kubectl get pods -o wide --all-namespaces --field-selector spec.nodeName=$node | grep node-monitor | wc -l)
  echo "$node: $count Pod(s)"
done

# 3. Deploy DaemonSet with node selector (limited nodes)
kubectl label node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') accelerator=nvidia disk=ssd
kubectl apply -f specs/ckad/daemonset/node-selector-daemonset.yaml
kubectl get pods -o wide -l app=gpu-plugin

# Notice: Only runs on labeled nodes

# 4. Deploy DaemonSet with tolerations (runs on control plane)
kubectl apply -f specs/ckad/daemonset/toleration-daemonset.yaml
kubectl get pods -o wide -l app=cp-monitor

# Should see Pods on control plane nodes too

# 5. Test update strategies
kubectl apply -f specs/ckad/daemonset/update-strategy.yaml

# Watch rolling update in action
kubectl set image daemonset/rolling-update-ds app=nginx:1.22-alpine
kubectl rollout status daemonset/rolling-update-ds

# Check rollout history
kubectl rollout history daemonset/rolling-update-ds

# 6. Test OnDelete strategy
kubectl set image daemonset/ondelete-ds app=nginx:1.22-alpine
kubectl get pods -l app=ondelete-demo

# Pods won't update automatically - must delete manually
kubectl delete pod -l app=ondelete-demo --field-selector spec.nodeName=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl get pods -l app=ondelete-demo -o wide

# 7. View DaemonSet details
kubectl describe daemonset node-monitor
kubectl get daemonset node-monitor -o yaml

# 8. Cleanup
kubectl delete -f specs/ckad/daemonset/
kubectl label nodes --all accelerator- disk-
```

**Key concepts:**
- **DaemonSet**: Ensures one Pod per node (or subset of nodes)
- **Use cases**: Logging, monitoring, network agents, storage daemons
- **Update strategies**: RollingUpdate (automatic) vs OnDelete (manual)
- **maxUnavailable**: Controls how many nodes can be updating simultaneously
- Combine with node selectors for targeted deployment
- Use tolerations to run on control plane/tainted nodes

## Node Maintenance

### Cordon - Prevent Scheduling

Mark node as unschedulable:

```bash
# Cordon a node
kubectl cordon <node-name>

# Check node status
kubectl get nodes

# Node shows as Ready,SchedulingDisabled
```

**Use case:** Prevent new Pods before maintenance

### Drain - Evict Pods

Safely evict all Pods from a node:

```bash
# Drain node (respects PodDisruptionBudgets)
kubectl drain <node-name> --ignore-daemonsets

# Common flags:
kubectl drain <node-name> \
  --ignore-daemonsets \          # Required for DaemonSet Pods
  --delete-emptydir-data \       # Delete Pods with emptyDir volumes
  --force \                      # Force deletion (use carefully)
  --grace-period=300             # Wait time before force kill (seconds)
```

**What drain does:**
1. Cordons the node (prevents new Pods)
2. Evicts all Pods gracefully
3. Respects PodDisruptionBudgets (unless --disable-eviction)
4. Waits for termination or grace period

### Uncordon - Re-enable Scheduling

Mark node as schedulable again:

```bash
# Uncordon node
kubectl uncordon <node-name>

# Verify status
kubectl get nodes
```

**Note:** Existing Pods don't automatically move back. They stay where they were rescheduled.

### Complete Maintenance Workflow

```bash
# 1. Cordon the node
kubectl cordon worker-node-1

# 2. Check what will be evicted
kubectl get pods -o wide --all-namespaces | grep worker-node-1

# 3. Drain the node
kubectl drain worker-node-1 --ignore-daemonsets --delete-emptydir-data

# 4. Perform maintenance (upgrade, repair, etc.)
# ... do maintenance work ...

# 5. Uncordon when done
kubectl uncordon worker-node-1

# 6. Optional: Force rebalance
kubectl rollout restart deployment/myapp
```

### Exercise: Node Maintenance Operations

Practice safe node maintenance:

```bash
# 1. Deploy application across nodes
kubectl create deployment web-app --image=nginx:alpine --replicas=5
kubectl get pods -o wide -l app=web-app

# 2. Cordon a node (prevent new scheduling)
kubectl cordon $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl get nodes

# Node shows as Ready,SchedulingDisabled

# 3. Scale up and observe scheduling
kubectl scale deployment web-app --replicas=10
kubectl get pods -o wide -l app=web-app

# New Pods won't schedule on cordoned node

# 4. Deploy with PodDisruptionBudget
kubectl apply -f specs/ckad/maintenance/poddisruptionbudget.yaml

# Check PDB status
kubectl get pdb
kubectl describe pdb web-app-pdb

# 5. Drain the node (evict Pods)
kubectl drain $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') \
  --ignore-daemonsets \
  --delete-emptydir-data

# Watch Pods being evicted and rescheduled
kubectl get pods -o wide -w

# 6. Verify Pods moved
echo "Pods on drained node:"
kubectl get pods -o wide --all-namespaces \
  --field-selector spec.nodeName=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')

# Should only show DaemonSet Pods

# 7. Uncordon the node
kubectl uncordon $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl get nodes

# 8. Rebalance Pods (optional)
kubectl rollout restart deployment web-app
kubectl get pods -o wide -l app=web-app

# 9. Run complete workflow script
chmod +x specs/ckad/maintenance/maintenance-workflow.sh
./specs/ckad/maintenance/maintenance-workflow.sh

# 10. Test drain with force (use carefully!)
# kubectl drain <node> --force --ignore-daemonsets --delete-emptydir-data --grace-period=0

# 11. Cleanup
kubectl delete -f specs/ckad/maintenance/poddisruptionbudget.yaml
kubectl delete deployment web-app
```

**Common drain flags:**
- `--ignore-daemonsets`: Required for DaemonSet Pods
- `--delete-emptydir-data`: Delete Pods with emptyDir volumes
- `--force`: Force deletion (use carefully)
- `--grace-period=N`: Wait N seconds before force kill
- `--disable-eviction`: Bypass PodDisruptionBudgets (dangerous)

**Best practices:**
- Always cordon before drain
- Check PodDisruptionBudgets first
- Monitor Pod rescheduling
- Uncordon after maintenance
- Consider rebalancing workloads

## Resource Requests and Limits

Affect scheduling decisions:

### Resource Requests

Minimum guaranteed resources:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: resource-demo
spec:
  containers:
  - name: app
    image: myapp:v1
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
```

**Scheduling impact:**
- Scheduler only places Pod on nodes with sufficient available resources
- Requests are reserved for the Pod

### Node Capacity and Allocatable

```bash
# View node capacity
kubectl describe node <node-name>

# Output shows:
# Capacity:
#   cpu:                4
#   memory:             16Gi
# Allocatable:
#   cpu:                3800m
#   memory:             15Gi
# Allocated resources:
#   cpu:                2000m (52%)
#   memory:             8Gi (53%)
```

**Key concepts:**
- **Capacity**: Total resources on node
- **Allocatable**: Available for Pods (capacity - system reserved)
- **Allocated**: Sum of all Pod requests

### Pod Won't Schedule Due to Resources

```bash
# Pod stuck in Pending state
kubectl get pods

# Check events
kubectl describe pod <pod-name>

# Common message:
# Warning  FailedScheduling  0/3 nodes are available: 3 Insufficient cpu.
```

**Solutions:**
- Reduce resource requests
- Add more nodes
- Remove/scale down other Pods

### Exercise: Resource Requests and Scheduling

```bash
# 1. View node capacity
kubectl describe node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') | grep -A 10 "Allocatable:"

# 2. Deploy Pod with resource requests
kubectl run resource-demo --image=nginx --restart=Never \
  --requests='memory=256Mi,cpu=500m' \
  --limits='memory=512Mi,cpu=1'

# 3. Check QoS class
kubectl get pod resource-demo -o jsonpath='{.status.qosClass}'
# Output: Guaranteed (requests == limits)

# 4. Deploy Burstable QoS Pod
kubectl run burstable-pod --image=nginx --restart=Never \
  --requests='memory=128Mi,cpu=100m' \
  --limits='memory=512Mi,cpu=500m'

kubectl get pod burstable-pod -o jsonpath='{.status.qosClass}'
# Output: Burstable (requests < limits)

# 5. Deploy BestEffort QoS Pod
kubectl run besteffort-pod --image=nginx --restart=Never
kubectl get pod besteffort-pod -o jsonpath='{.status.qosClass}'
# Output: BestEffort (no requests/limits)

# 6. Create Pod that won't fit on any node
kubectl run huge-pod --image=nginx --restart=Never \
  --requests='memory=999Gi,cpu=999'

kubectl get pod huge-pod
kubectl describe pod huge-pod | grep -A 5 Events
# Will see: "0/X nodes are available: X Insufficient memory, X Insufficient cpu"

# 7. View node resource allocation
kubectl top nodes
kubectl describe nodes | grep -A 5 "Allocated resources"

# 8. Cleanup
kubectl delete pod resource-demo burstable-pod besteffort-pod huge-pod
```

**QoS Classes:**
- **Guaranteed**: requests == limits for all containers (highest priority)
- **Burstable**: requests < limits (medium priority)
- **BestEffort**: no requests/limits (lowest priority, evicted first)

## API Version Compatibility

Different Kubernetes versions support different API versions:

### Checking API Versions

```bash
# List all available API versions
kubectl api-versions

# Check if specific API exists
kubectl api-versions | grep networking.k8s.io/v1

# Get API resources
kubectl api-resources
```

### Deprecated APIs

Common deprecations in Kubernetes:

| Resource | Deprecated API | Current API | Removed In |
|----------|---------------|-------------|------------|
| Ingress | `extensions/v1beta1` | `networking.k8s.io/v1` | v1.22 |
| CronJob | `batch/v1beta1` | `batch/v1` | v1.25 |
| PodSecurityPolicy | `policy/v1beta1` | Removed | v1.25 |

### Handling API Migrations

```bash
# Convert deprecated API to current version
kubectl convert -f old-ingress.yaml --output-version networking.k8s.io/v1

# Dry-run to check compatibility
kubectl apply --dry-run=server -f manifest.yaml
```

**CKAD Tip:** Always use stable (`v1`) APIs, not `beta` versions.

### Exercise: API Version Compatibility

```bash
# 1. List available API versions
kubectl api-versions | sort

# 2. Check specific API resources
kubectl api-resources | grep -i deployment
kubectl api-resources | grep -i ingress

# 3. Get API resource details
kubectl explain deployment --api-version=apps/v1
kubectl explain ingress --api-version=networking.k8s.io/v1

# 4. Validate manifest against cluster
kubectl apply --dry-run=server -f manifest.yaml

# 5. Check deprecated APIs in your cluster
kubectl get deployments.v1.apps
kubectl get ingresses.v1.networking.k8s.io
```

**Common API migrations:**
- Ingress: `extensions/v1beta1` → `networking.k8s.io/v1` (removed in v1.22)
- PodSecurityPolicy: `policy/v1beta1` → Removed in v1.25 (use Pod Security Standards)
- CronJob: `batch/v1beta1` → `batch/v1` (stable since v1.21)

## Troubleshooting Scheduling Issues

### Common Problems and Solutions

**1. Pod Stuck in Pending**

```bash
# Check Pod events
kubectl describe pod <pod-name>

# Common causes:
# - Insufficient resources
# - No nodes match selectors
# - All nodes are tainted
# - ImagePullBackOff (different issue)

# Debug steps:
kubectl get nodes
kubectl describe nodes
kubectl get pod <pod-name> -o yaml | grep -A 10 nodeSelector
kubectl get pod <pod-name> -o yaml | grep -A 10 affinity
```

**2. Pod on Wrong Node**

```bash
# Check where Pod landed
kubectl get pod <pod-name> -o wide

# Check node labels
kubectl get node <node-name> --show-labels

# Verify selectors and affinity
kubectl get pod <pod-name> -o yaml
```

**3. DaemonSet Not on All Nodes**

```bash
# Check DaemonSet status
kubectl get daemonset

# Check if nodes are tainted
kubectl describe nodes | grep Taints

# Check DaemonSet tolerations
kubectl describe daemonset <name> | grep -A 5 Tolerations
```

**4. Affinity Not Working**

```bash
# Verify labels exist on target Pods
kubectl get pods --show-labels

# Check topology key exists on nodes
kubectl get nodes --show-labels | grep <topology-key>

# Review affinity rules
kubectl get pod <pod-name> -o yaml | grep -A 20 affinity
```

### Exercise: Troubleshooting Scheduling

Practice diagnosing common scheduling issues:

```bash
# Scenario 1: Pod stuck in Pending
kubectl run test --image=nginx --dry-run=client -o yaml | \
  sed 's/resources: {}/resources:\n      requests:\n        memory: "999Gi"/' | \
  kubectl apply -f -

kubectl get pod test
kubectl describe pod test | grep -A 10 Events
# Fix: Reduce resource requests or add nodes

# Scenario 2: No nodes match selector
kubectl run selective --image=nginx --overrides='{"spec":{"nodeSelector":{"nonexistent":"label"}}}'
kubectl describe pod selective | grep -A 5 Events
# Fix: Add label to node or fix selector

# Scenario 3: All nodes tainted
kubectl taint nodes --all test=true:NoSchedule
kubectl run tainted-test --image=nginx
kubectl describe pod tainted-test
# Fix: Add toleration or remove taint
kubectl taint nodes --all test-

# Scenario 4: DaemonSet not on all nodes
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: test-ds
spec:
  selector:
    matchLabels:
      app: test-ds
  template:
    metadata:
      labels:
        app: test-ds
    spec:
      nodeSelector:
        nonexistent: label
      containers:
      - name: test
        image: nginx
EOF

kubectl get daemonset test-ds
# Fix: Remove or fix nodeSelector

# Scenario 5: Pod affinity not working
# Deploy without target Pods first
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: orphan-pod
spec:
  affinity:
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app: nonexistent
        topologyKey: kubernetes.io/hostname
  containers:
  - name: app
    image: nginx
EOF

kubectl describe pod orphan-pod | grep -A 5 Events
# Fix: Deploy target Pods first or use preferred affinity

# Cleanup
kubectl delete pod test selective tainted-test orphan-pod --ignore-not-found=true
kubectl delete daemonset test-ds --ignore-not-found=true
```

**Debugging checklist:**
1. Check Pod status: `kubectl get pods`
2. Check events: `kubectl describe pod <name>`
3. Check node status: `kubectl get nodes`
4. Check node labels: `kubectl get nodes --show-labels`
5. Check node taints: `kubectl describe nodes | grep Taints`
6. Check node resources: `kubectl describe nodes | grep -A 5 "Allocated resources"`
7. Check affinity rules: `kubectl get pod <name> -o yaml | grep -A 20 affinity`

## CKAD Exam Tips

### Quick Commands

```bash
# Node operations
kubectl get nodes
kubectl describe node <name>
kubectl label node <name> key=value
kubectl taint node <name> key=value:Effect
kubectl cordon <name>
kubectl drain <name> --ignore-daemonsets
kubectl uncordon <name>

# Check Pod scheduling
kubectl get pods -o wide
kubectl describe pod <name> | grep -A 5 Events
kubectl get pod <name> -o yaml | grep nodeName

# Test scheduling constraints
kubectl run test --image=nginx --dry-run=client -o yaml > pod.yaml
# Edit to add nodeSelector, affinity, tolerations
kubectl apply -f pod.yaml
kubectl get pod test -o wide
```

### Common Patterns

**Add node selector to existing Deployment:**
```bash
kubectl patch deployment myapp -p '
{
  "spec": {
    "template": {
      "spec": {
        "nodeSelector": {
          "disk": "ssd"
        }
      }
    }
  }
}'
```

**Quick toleration template:**
```yaml
tolerations:
- key: "key"
  operator: "Equal"
  value: "value"
  effect: "NoSchedule"
```

**Quick affinity template:**
```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: label-key
          operator: In
          values:
          - label-value
```

### What to Focus On

**High Priority for CKAD:**
- Node labels and selectors
- Taints and tolerations (especially NoSchedule, NoExecute)
- Basic node affinity
- DaemonSets
- Cordon/drain/uncordon
- Resource requests impacting scheduling

**Medium Priority:**
- Pod affinity and anti-affinity
- Preferred vs required affinities
- Topology keys
- Weight in preferred affinity

**Lower Priority:**
- Complex multi-term affinity rules
- Advanced scheduling plugins
- Cluster autoscaling

## 10 Rapid-Fire CKAD Practice Scenarios

Time yourself - aim for 2-3 minutes per scenario:

**Scenario 1:** Create a Pod named `ssd-app` that only runs on nodes with `disk=ssd` label.
```bash
kubectl run ssd-app --image=nginx --dry-run=client -o yaml | \
  sed '/spec:/a\  nodeSelector:\n    disk: ssd' | kubectl apply -f -
```

**Scenario 2:** Taint node `node-1` with `maintenance=true:NoSchedule` and deploy a Pod that tolerates it.
```bash
kubectl taint node node-1 maintenance=true:NoSchedule
kubectl run tolerant-pod --image=nginx --overrides='{"spec":{"tolerations":[{"key":"maintenance","operator":"Equal","value":"true","effect":"NoSchedule"}]}}'
```

**Scenario 3:** Deploy a 3-replica Deployment with anti-affinity to spread across nodes.
```bash
kubectl create deployment spread-app --image=nginx --replicas=3 --dry-run=client -o yaml | \
  sed '/spec:/a\      affinity:\n        podAntiAffinity:\n          requiredDuringSchedulingIgnoredDuringExecution:\n          - labelSelector:\n              matchLabels:\n                app: spread-app\n            topologyKey: kubernetes.io/hostname' | kubectl apply -f -
```

**Scenario 4:** Create a DaemonSet named `monitor` that runs on all nodes including control plane.
```bash
kubectl create deployment monitor --image=busybox --dry-run=client -o yaml | \
  sed 's/Deployment/DaemonSet/; s/replicas: 1//' | \
  sed '/spec:/a\      tolerations:\n      - operator: Exists' | kubectl apply -f -
```

**Scenario 5:** Cordon node `node-2`, drain it safely, then uncordon.
```bash
kubectl cordon node-2
kubectl drain node-2 --ignore-daemonsets --delete-emptydir-data
kubectl uncordon node-2
```

**Scenario 6:** Create a Pod with required node affinity for `environment=production` OR `environment=staging`.
```bash
kubectl run multi-env --image=nginx --dry-run=client -o yaml > /tmp/pod.yaml
# Edit to add affinity with multiple nodeSelectorTerms
kubectl apply -f /tmp/pod.yaml
```

**Scenario 7:** Deploy a Pod that must be in same zone as Pods labeled `app=database`.
```bash
kubectl run zone-app --image=nginx --overrides='{"spec":{"affinity":{"podAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":[{"labelSelector":{"matchLabels":{"app":"database"}},"topologyKey":"topology.kubernetes.io/zone"}]}}}}'
```

**Scenario 8:** Create a PodDisruptionBudget for deployment `web-app` with minAvailable 2.
```bash
kubectl create pdb web-app-pdb --selector=app=web-app --min-available=2
```

**Scenario 9:** Deploy a Pod with resource requests: 256Mi memory, 500m CPU.
```bash
kubectl run resource-pod --image=nginx --requests='memory=256Mi,cpu=500m'
```

**Scenario 10:** Find all Pods on node `node-1` and identify their QoS class.
```bash
kubectl get pods -o wide --all-namespaces --field-selector spec.nodeName=node-1
kubectl get pods -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass --all-namespaces
```

## Lab Challenge: Multi-Tier Application with Advanced Scheduling

Deploy a realistic application with various scheduling constraints:

### Challenge Instructions

Deploy a complete multi-tier application demonstrating advanced scheduling:

**Step 1: Node Preparation**
```bash
# Label nodes (adjust node names for your cluster)
kubectl label node node-1 disk=ssd environment=production memory=high
kubectl label node node-2 disk=ssd environment=production compute=optimized
kubectl label node node-3 disk=hdd environment=staging

# Taint database nodes
kubectl taint node node-1 database=critical:NoSchedule

# Add zone labels (if not present)
kubectl label node node-1 topology.kubernetes.io/zone=zone-a
kubectl label node node-2 topology.kubernetes.io/zone=zone-b
kubectl label node node-3 topology.kubernetes.io/zone=zone-c
```

**Step 2: Deploy Database Tier**
```bash
kubectl apply -f specs/ckad/challenge/database.yaml
kubectl get pods -o wide -l tier=database
# Verify: Only on SSD nodes, spread across nodes
```

**Step 3: Deploy Cache Tier**
```bash
kubectl apply -f specs/ckad/challenge/cache.yaml
kubectl get pods -o wide -l tier=cache
# Verify: On high-memory nodes, spread across zones, near database
```

**Step 4: Deploy Application Tier**
```bash
kubectl apply -f specs/ckad/challenge/application.yaml
kubectl get pods -o wide -l tier=app
# Verify: Spread across nodes, near cache
```

**Step 5: Deploy Monitoring**
```bash
kubectl apply -f specs/ckad/challenge/monitoring.yaml
kubectl get pods -o wide -l app=monitoring
# Verify: One Pod per node, including control plane
```

**Step 6: Create PodDisruptionBudgets**
```bash
kubectl apply -f specs/ckad/challenge/pdb.yaml
kubectl get pdb
```

**Step 7: Test Maintenance**
```bash
# Cordon and drain
kubectl cordon node-2
kubectl drain node-2 --ignore-daemonsets --delete-emptydir-data

# Verify application still available
kubectl get pods -o wide

# Uncordon
kubectl uncordon node-2
```

**Step 8: Verify Success**
```bash
# Run validation script
chmod +x specs/ckad/challenge/validate.sh
./specs/ckad/challenge/validate.sh
```

**Success Criteria:**
- ✅ Database Pods on SSD nodes with taints tolerated
- ✅ Cache Pods on high-memory nodes in different zones
- ✅ App Pods spread across nodes, co-located with cache by zone
- ✅ Monitoring on all nodes including control plane
- ✅ PodDisruptionBudgets protecting critical services
- ✅ Application survives node maintenance

**Challenge files:** See `specs/ckad/challenge/` directory

## Quick Reference

### Node Operations
```bash
kubectl get nodes --show-labels
kubectl label node <name> key=value
kubectl taint node <name> key=value:Effect
kubectl cordon <name>
kubectl drain <name> --ignore-daemonsets
kubectl uncordon <name>
```

### Node Selector
```yaml
spec:
  nodeSelector:
    disk: ssd
```

### Tolerations
```yaml
spec:
  tolerations:
  - key: "key"
    operator: "Equal"
    value: "value"
    effect: "NoSchedule"
```

### Node Affinity
```yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: disk
            operator: In
            values:
            - ssd
```

### Pod Anti-Affinity
```yaml
spec:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app: web
        topologyKey: kubernetes.io/hostname
```

## Cleanup

```bash
# Remove taints
kubectl taint nodes <name> key:Effect-

# Remove labels
kubectl label nodes <name> key-

# Uncordon nodes
kubectl uncordon <name>

# Delete test resources
kubectl delete all -l app=test
```

## Further Reading

- [Kubernetes Scheduling Framework](https://kubernetes.io/docs/concepts/scheduling-eviction/kube-scheduler/)
- [Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)
- [Assign Pods to Nodes](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)
- [Pod Priority and Preemption](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/)

---

> Back to [basic Clusters lab](README.md) | [Course contents](../../README.md)
