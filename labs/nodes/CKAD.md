# Nodes for CKAD

This document extends the [basic nodes lab](README.md) with CKAD exam-specific scenarios and requirements.

## CKAD Exam Context

Understanding nodes is fundamental for CKAD, though you won't manage node infrastructure directly. You need to:
- Understand node labels and how to use them
- Use node selectors to control pod placement
- Understand node capacity and resource allocation
- Troubleshoot pods that won't schedule due to node issues
- Understand node conditions and their impact on pods
- Know how to check node status and resources

**Exam Tip:** Node-related questions often appear as troubleshooting scenarios - "Why won't this pod schedule?" Understanding node capacity, taints, and selectors is key.

## What Are Nodes?

Nodes are the worker machines in a Kubernetes cluster that run your containerized applications.

### Node Components

Each node runs:
- **kubelet**: Agent that manages pods on the node
- **container runtime**: Docker, containerd, or CRI-O
- **kube-proxy**: Network proxy for services

### Node Information

```bash
# List all nodes
kubectl get nodes

# Detailed node information
kubectl describe node <node-name>

# Node status in YAML
kubectl get node <node-name> -o yaml

# Wide output with more details
kubectl get nodes -o wide
```

## Understanding Node Labels

Nodes have automatic labels that identify their characteristics:

### Standard Node Labels

```bash
# Show node labels
kubectl get nodes --show-labels

# Common standard labels:
kubernetes.io/arch=amd64            # CPU architecture
kubernetes.io/os=linux              # Operating system
kubernetes.io/hostname=node-1       # Node hostname
topology.kubernetes.io/region=us-west-1
topology.kubernetes.io/zone=us-west-1a
node.kubernetes.io/instance-type=t3.large
```

### Custom Labels

```bash
# Add custom label to node
kubectl label node <node-name> disktype=ssd

# Add multiple labels
kubectl label node <node-name> environment=production tier=frontend

# Update existing label
kubectl label node <node-name> disktype=nvme --overwrite

# Remove label
kubectl label node <node-name> disktype-

# List nodes with specific label
kubectl get nodes -l disktype=ssd
```

## Node Selectors for Pod Placement

The simplest way to control where pods run is using node selectors.

### Basic Node Selector

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  nodeSelector:
    disktype: ssd
  containers:
  - name: nginx
    image: nginx
```

This pod will only schedule on nodes with the label `disktype=ssd`.

### Multiple Label Selectors

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: frontend
spec:
  nodeSelector:
    disktype: ssd
    environment: production
  containers:
  - name: app
    image: myapp:1.0
```

Pod requires nodes with BOTH labels (AND logic).

## Exercise 1: Node Selectors

**Task**: Deploy a pod to a specific type of node using labels.

1. Label a node with `workload=compute-intensive`
2. Create a pod that only runs on nodes with this label
3. Verify the pod is scheduled correctly
4. Try to create a pod with a non-existent label selector

<details>
  <summary>Step-by-Step Solution</summary>

```bash
# Step 1: Get list of nodes
kubectl get nodes

# Step 2: Label one node
kubectl label node <your-node-name> workload=compute-intensive

# Step 3: Verify label
kubectl get nodes -L workload
kubectl get nodes --show-labels | grep workload

# Step 4: Create pod with node selector
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: compute-pod
spec:
  nodeSelector:
    workload: compute-intensive
  containers:
  - name: app
    image: nginx
EOF

# Step 5: Verify pod placement
kubectl get pod compute-pod -o wide
# NODE column should show the labeled node

kubectl describe pod compute-pod | grep -A5 "Node-Selectors"

# Step 6: Try with non-existent label
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: impossible-pod
spec:
  nodeSelector:
    workload: non-existent-type
  containers:
  - name: app
    image: nginx
EOF

# Step 7: Check why it won't schedule
kubectl get pods impossible-pod
# Shows: Pending

kubectl describe pod impossible-pod
# Events show: 0/X nodes are available: X node(s) didn't match Pod's node affinity/selector

# Cleanup
kubectl delete pod compute-pod impossible-pod
kubectl label node <your-node-name> workload-
```

**Key Learning**: Pods with node selectors that don't match any node will remain in Pending state.

</details><br />

## Node Capacity and Resource Allocation

Every node has finite CPU and memory. Understanding capacity is crucial for troubleshooting.

### Checking Node Capacity

```bash
# View node capacity
kubectl describe node <node-name>

# Look for these sections:
# Capacity:        Total resources
# Allocatable:     Available for pods (after system reserves)
# Allocated resources:  Currently requested by pods
```

Example output:
```
Capacity:
  cpu:                4
  memory:             16Gi
  pods:               110

Allocatable:
  cpu:                4
  memory:             15.5Gi
  pods:               110

Allocated resources:
  CPU Requests  CPU Limits  Memory Requests  Memory Limits
  ------------  ----------  ---------------  -------------
  1000m (25%)   2000m (50%) 2Gi (13%)        4Gi (26%)
```

### Resource Pressure

Nodes can experience resource pressure when resources are low:

- **MemoryPressure**: Node is low on memory
- **DiskPressure**: Node is low on disk space
- **PIDPressure**: Too many processes running

```bash
# Check node conditions
kubectl describe node <node-name> | grep -A10 Conditions

# Example output:
# Conditions:
#   Type             Status  Reason
#   ----             ------  ------
#   MemoryPressure   False   KubeletHasSufficientMemory
#   DiskPressure     False   KubeletHasNoDiskPressure
#   PIDPressure      False   KubeletHasSufficientPID
#   Ready            True    KubeletReady
```

## Exercise 2: Troubleshoot Node Resource Issues

**Scenario**: A pod won't schedule. Diagnose if it's due to node resources.

<details>
  <summary>Step-by-Step Solution</summary>

```bash
# Step 1: Create a pod with large resource requests
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: huge-pod
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        memory: "100Gi"  # Impossible request
        cpu: "50"
EOF

# Step 2: Check pod status
kubectl get pod huge-pod
# Shows: Pending

# Step 3: Describe pod to see events
kubectl describe pod huge-pod

# Look for events like:
# Warning  FailedScheduling  pod has unbound immediate PersistentVolumeClaims
# 0/3 nodes are available: 3 Insufficient cpu, 3 Insufficient memory

# Step 4: Check node capacity
kubectl describe nodes | grep -A10 "Allocatable"

# Step 5: Calculate if pod can fit
# Compare pod requests against node allocatable resources

# Step 6: Fix by reducing requests
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: reasonable-pod
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        memory: "100Mi"
        cpu: "100m"
EOF

# Step 7: Verify it schedules
kubectl get pod reasonable-pod -o wide

# Cleanup
kubectl delete pod huge-pod reasonable-pod
```

**Key Learning**: Always check pod resource requests against node allocatable resources when troubleshooting scheduling issues.

</details><br />

## Node Conditions and Status

Nodes report various conditions that affect scheduling:

| Condition | Meaning | Impact |
|-----------|---------|--------|
| Ready | Node is healthy and ready to accept pods | Pods can schedule |
| MemoryPressure | Node is low on memory | New pods may not schedule |
| DiskPressure | Node is low on disk | New pods may not schedule |
| PIDPressure | Too many processes | New pods may not schedule |
| NetworkUnavailable | Network not configured | Pods won't have network |

### Checking Node Health

```bash
# Quick status check
kubectl get nodes

# Detailed conditions
kubectl describe node <node-name> | grep -A10 Conditions

# Check if node is ready
kubectl get nodes -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}'
```

### Node Not Ready

If a node shows `NotReady`:

```bash
# Check node conditions
kubectl describe node <node-name>

# Common causes:
# - kubelet not running
# - Network issues
# - Insufficient resources
# - Node shut down

# Pods on NotReady nodes:
# - Existing pods continue running (if node comes back)
# - After ~5 minutes, pods are evicted
# - New pods won't schedule to NotReady nodes
```

## Taints and Tolerations (Brief Overview)

Taints prevent pods from scheduling on nodes unless they have matching tolerations.

### Understanding Taints

```bash
# Add taint to node
kubectl taint nodes <node-name> key=value:NoSchedule

# View node taints
kubectl describe node <node-name> | grep Taints

# Remove taint
kubectl taint nodes <node-name> key=value:NoSchedule-
```

### Common Taint Effects

- **NoSchedule**: Pods won't schedule unless they tolerate
- **PreferNoSchedule**: Soft preference, avoid if possible
- **NoExecute**: Evict existing pods that don't tolerate

### Pod Tolerations

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: tolerant-pod
spec:
  tolerations:
  - key: "key"
    operator: "Equal"
    value: "value"
    effect: "NoSchedule"
  containers:
  - name: app
    image: nginx
```

**CKAD Note**: For comprehensive taint/toleration coverage, see the [clusters lab](../clusters/CKAD.md). For advanced pod placement, see the [affinity lab](../affinity/CKAD.md).

## Exercise 3: Working with Taints

**Task**: Taint a node and deploy pods with and without tolerations.

<details>
  <summary>Step-by-Step Solution</summary>

```bash
# Step 1: Taint a node (use NoSchedule for testing)
kubectl taint nodes <node-name> dedicated=special-workload:NoSchedule

# Step 2: Verify taint
kubectl describe node <node-name> | grep Taints

# Step 3: Try to create pod WITHOUT toleration
kubectl run no-toleration --image=nginx

# Step 4: Check if it schedules
kubectl get pod no-toleration -o wide
# If you have other nodes, it schedules there
# If this is your only node, it stays Pending

# Step 5: Describe to see why
kubectl describe pod no-toleration
# Events: "0/X nodes are available: 1 node(s) had taints that the pod didn't tolerate"

# Step 6: Create pod WITH toleration
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: with-toleration
spec:
  tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "special-workload"
    effect: "NoSchedule"
  containers:
  - name: nginx
    image: nginx
EOF

# Step 7: Verify it schedules on tainted node
kubectl get pod with-toleration -o wide

# Cleanup
kubectl delete pod no-toleration with-toleration
kubectl taint nodes <node-name> dedicated=special-workload:NoSchedule-
```

**Key Learning**: Taints and tolerations work together - taints repel, tolerations allow.

</details><br />

## Draining and Cordoning Nodes

For maintenance, you can remove workloads from nodes.

### Cordon (Prevent New Pods)

```bash
# Mark node as unschedulable (existing pods stay)
kubectl cordon <node-name>

# Verify
kubectl get nodes
# Shows: SchedulingDisabled

# Uncordon to allow scheduling again
kubectl uncordon <node-name>
```

### Drain (Evict Existing Pods)

```bash
# Evict pods from node
kubectl drain <node-name> --ignore-daemonsets

# Common options:
kubectl drain <node-name> \
  --ignore-daemonsets \           # Skip DaemonSet pods
  --delete-emptydir-data \        # Delete emptyDir volumes
  --force                         # Force eviction

# After maintenance, uncordon
kubectl uncordon <node-name>
```

**CKAD Note**: You might need to drain a node to complete a task like "Move all pods from node-1 to node-2".

## Exercise 4: Cordon and Drain

**Task**: Safely remove all pods from a node for maintenance.

<details>
  <summary>Step-by-Step Solution</summary>

```bash
# Step 1: Deploy some pods
kubectl create deployment test-app --image=nginx --replicas=3

# Step 2: Check which nodes they're on
kubectl get pods -o wide

# Step 3: Cordon a node (prevents new pods)
kubectl cordon <node-name>

# Step 4: Verify node status
kubectl get nodes
# Shows: SchedulingDisabled for cordoned node

# Step 5: Scale up deployment
kubectl scale deployment test-app --replicas=6

# Step 6: New pods won't schedule on cordoned node
kubectl get pods -o wide
# New pods go to other nodes only

# Step 7: Drain the node (evicts existing pods)
kubectl drain <node-name> --ignore-daemonsets --force

# Step 8: Watch pods move
kubectl get pods -o wide -w
# Pods on drained node are terminated
# New pods created on other nodes

# Step 9: After maintenance, uncordon
kubectl uncordon <node-name>

# Step 10: Verify node is schedulable again
kubectl get nodes

# Cleanup
kubectl delete deployment test-app
```

**Key Learning**: Cordon prevents new pods; drain evicts existing pods. Always uncordon after maintenance.

</details><br />

## Common CKAD Troubleshooting Scenarios

### Scenario 1: Pod Stuck in Pending

**Symptom**: Pod shows `Pending` status

**Diagnosis**:
```bash
kubectl describe pod <pod-name>
```

**Common Causes**:
1. **Insufficient resources**: Node doesn't have enough CPU/memory
2. **No matching node selector**: Labels don't match any node
3. **Node taints**: Pod doesn't tolerate node taints
4. **All nodes unschedulable**: All nodes cordoned

**Solutions**:
```bash
# Check node resources
kubectl describe nodes | grep -A10 "Allocated resources"

# Check node selectors
kubectl get pod <pod-name> -o yaml | grep -A5 nodeSelector

# Check taints
kubectl describe nodes | grep Taints

# Check if nodes are ready
kubectl get nodes
```

### Scenario 2: Node NotReady

**Symptom**: Node shows `NotReady` status

**Diagnosis**:
```bash
kubectl describe node <node-name>
```

**Common Causes**:
- kubelet stopped
- Network connectivity issues
- Disk full
- Memory exhausted

**Impact**: Pods won't schedule to NotReady nodes. After ~5 minutes, existing pods are evicted.

### Scenario 3: Pods Evicted from Node

**Symptom**: Pods terminated with status `Evicted`

**Diagnosis**:
```bash
kubectl describe pod <pod-name>
```

**Common Reasons**:
- Node pressure (memory, disk, PID)
- Node drain operation
- Node NotReady for extended period

**Solution**: Check node conditions and address pressure:
```bash
kubectl describe node <node-name> | grep -A10 Conditions
```

## Quick Command Reference

```bash
# Node Information
kubectl get nodes                          # List nodes
kubectl get nodes -o wide                  # More details
kubectl describe node <name>               # Full node info
kubectl top nodes                          # Resource usage (requires metrics-server)

# Node Labels
kubectl get nodes --show-labels            # Show all labels
kubectl get nodes -L <label-key>           # Show specific label
kubectl label node <name> <key>=<value>    # Add label
kubectl label node <name> <key>-           # Remove label

# Node Selection
kubectl get nodes -l <key>=<value>         # Filter by label
kubectl get pods --field-selector spec.nodeName=<node>  # Pods on node

# Node Management
kubectl cordon <node>                      # Make unschedulable
kubectl uncordon <node>                    # Make schedulable
kubectl drain <node> --ignore-daemonsets   # Evict pods

# Node Capacity
kubectl describe node <name> | grep -A5 Capacity
kubectl describe node <name> | grep -A5 Allocatable
kubectl describe node <name> | grep -A10 "Allocated resources"

# Node Conditions
kubectl describe node <name> | grep -A10 Conditions
kubectl get node <name> -o jsonpath='{.status.conditions[?(@.type=="Ready")]}'
```

## Exam Tips

1. **Know node commands**: get, describe, label, cordon, uncordon, drain
2. **Check node capacity**: When pod is Pending, check if nodes have resources
3. **Verify node selectors**: Ensure pod label requirements match node labels
4. **Check taints**: Node taints can prevent scheduling
5. **Use -o wide**: Shows which node each pod is on
6. **Check node Ready status**: NotReady nodes won't accept new pods
7. **Remember drain vs cordon**: Cordon prevents new; drain evicts existing
8. **Use --ignore-daemonsets**: Required when draining nodes
9. **Check events**: `kubectl describe` shows scheduling failures
10. **Practice jsonpath**: Quickly query specific node fields

## Common Mistakes

1. ❌ Forgetting to uncordon after maintenance
2. ❌ Not using --ignore-daemonsets when draining
3. ❌ Confusing node selector with node affinity
4. ❌ Not checking node capacity when pod won't schedule
5. ❌ Assuming tainted nodes are broken (they're intentionally restricted)
6. ❌ Forgetting that NotReady pods are evicted after ~5 minutes
7. ❌ Not understanding the difference between Capacity and Allocatable
8. ❌ Labeling pods instead of nodes for nodeSelector
9. ❌ Using absolute paths instead of checking current nodes
10. ❌ Not reading describe output carefully for scheduling events

## Study Checklist

- [ ] List and describe nodes
- [ ] Show node labels
- [ ] Add and remove custom labels from nodes
- [ ] Create pods with nodeSelector
- [ ] Understand node capacity vs allocatable
- [ ] Check node conditions (Ready, MemoryPressure, etc.)
- [ ] Diagnose why pods won't schedule
- [ ] Use kubectl get pods -o wide to see node placement
- [ ] Cordon and uncordon nodes
- [ ] Drain nodes for maintenance
- [ ] Understand node taints and pod tolerations
- [ ] Check resource allocation on nodes
- [ ] Troubleshoot Pending pods
- [ ] Use JSONPath to query node information

## Practice Exercises

```bash
# 1. Label a node
kubectl label node <node-name> env=production

# 2. Create pod with node selector
kubectl run web --image=nginx --dry-run=client -o yaml > pod.yaml
# Edit pod.yaml to add nodeSelector: {env: production}
kubectl apply -f pod.yaml

# 3. Check node capacity
kubectl describe nodes | grep -A5 Allocatable

# 4. Cordon node
kubectl cordon <node-name>
kubectl get nodes  # Shows SchedulingDisabled

# 5. Drain node
kubectl drain <node-name> --ignore-daemonsets

# 6. Uncordon node
kubectl uncordon <node-name>
```

## Next Steps

After understanding nodes for CKAD:
1. Study [affinity](../affinity/) for advanced pod placement
2. Review [clusters](../clusters/) for taints, tolerations, and multi-node scenarios
3. Practice [troubleshooting](../troubleshooting/) for diagnosing scheduling issues
4. Learn [productionizing](../productionizing/) for resource limits and quality of service

---

## Summary

Nodes are the foundation of your Kubernetes cluster. For CKAD:

✅ **Master these skills:**
- Querying node information and labels
- Using nodeSelector for pod placement
- Understanding node capacity and resource allocation
- Troubleshooting pods that won't schedule
- Checking node conditions and health
- Cordoning and draining nodes

🎯 **Exam relevance**: Node understanding is foundational. Many troubleshooting questions involve node capacity, labels, or taints.
⏱️ **Time per question**: 3-5 minutes for node-related tasks
📊 **Difficulty**: Easy-Medium (mostly command knowledge)

Practice node commands until they're automatic - they're fundamental to many CKAD tasks!
