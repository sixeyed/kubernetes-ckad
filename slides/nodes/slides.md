---
layout: cover
---

# Understanding Nodes

<div class="abs-br m-6 flex gap-2">
  <carbon-server class="text-6xl text-blue-400" />
</div>

<!--
METADATA:
sentence: Nodes are the machines running your containers.
search_anchor: machines running your containers
-->
<div v-click class="mt-8 text-xl opacity-80">
The worker machines that run your containers
</div>

---
layout: center
---

# What is a Node?

<!--
METADATA:
sentence: Nodes are worker machines (physical servers, VMs, cloud instances) that run containers in Kubernetes clusters.
search_anchor: worker machines
-->
<div v-click="1">

```mermaid
graph TB
    C[Cluster] --> N1[Node 1<br/>Worker Machine]
    C --> N2[Node 2<br/>Worker Machine]
    C --> N3[Node 3<br/>Worker Machine]
    N1 --> P1[Pods]
    N1 --> P2[Pods]
    N2 --> P3[Pods]
    N3 --> P4[Pods]
    style C fill:#60a5fa
    style N1 fill:#4ade80
    style N2 fill:#4ade80
    style N3 fill:#4ade80
```

</div>

<!--
METADATA:
sentence: Nodes are worker machines (physical servers, VMs, cloud instances) that run containers in Kubernetes clusters.
search_anchor: physical servers, VMs, cloud instances
-->
<div v-click="2" class="mt-8 text-center text-lg">
Physical or virtual machines that run containerized workloads
</div>

<div class="grid grid-cols-2 gap-6 mt-6 text-sm">
<!--
METADATA:
sentence: Nodes are worker machines (physical servers, VMs, cloud instances) that run containers in Kubernetes clusters.
search_anchor: run containers in Kubernetes clusters
-->
<div v-click="3">
<carbon-server class="text-4xl text-blue-400 mb-2" />
<strong>Worker nodes</strong><br/>
Run application Pods
</div>
<!--
METADATA:
sentence: Kubernetes stores node information in its database, queryable via kubectl.
search_anchor: Kubernetes stores node information
-->
<div v-click="4">
<carbon-cloud-services class="text-4xl text-purple-400 mb-2" />
<strong>Control plane</strong><br/>
Manages the cluster
</div>
</div>

<!--
METADATA:
sentence: Kubernetes stores node information in its database, queryable via kubectl.
search_anchor: queryable via kubectl
-->
<div v-click="5" class="mt-6 text-center text-sm opacity-80">
Nodes are the compute resources of your cluster
</div>

---
layout: center
---

# Node Components

<!--
METADATA:
sentence: Each node runs: kubelet: Manages containers, Container runtime: Docker, containerd, CRI-O, kube-proxy: Network proxy
search_anchor: Each node runs
-->
<div v-click="1">

```mermaid
graph TB
    N[Node] --> K[kubelet<br/>Pod lifecycle]
    N --> CR[Container Runtime<br/>containerd, CRI-O]
    N --> KP[kube-proxy<br/>Network rules]
    K --> API[Talks to<br/>API Server]
    CR --> C[Runs containers]
    KP --> NET[Manages<br/>networking]
    style N fill:#60a5fa
    style K fill:#4ade80
    style CR fill:#fbbf24
    style KP fill:#a78bfa
```

</div>

<div class="grid grid-cols-3 gap-4 mt-8 text-sm">
<!--
METADATA:
sentence: kubelet: Manages containers
search_anchor: kubelet: Manages containers
-->
<div v-click="2">
<carbon-application class="text-3xl text-green-400 mb-2" />
<strong>kubelet</strong><br/>
Manages Pods
</div>
<!--
METADATA:
sentence: Container runtime: Docker, containerd, CRI-O
search_anchor: Container runtime: Docker, containerd, CRI-O
-->
<div v-click="3">
<carbon-container-software class="text-3xl text-yellow-400 mb-2" />
<strong>Container runtime</strong><br/>
Runs containers
</div>
<!--
METADATA:
sentence: kube-proxy: Network proxy
search_anchor: kube-proxy: Network proxy
-->
<div v-click="4">
<carbon-network-3 class="text-3xl text-purple-400 mb-2" />
<strong>kube-proxy</strong><br/>
Network routing
</div>
</div>

---
layout: center
---

# Node Status

<!--
METADATA:
sentence: kubectl get nodes  # List all nodes
search_anchor: kubectl get nodes
-->
<div v-click="1" class="text-sm">

```bash
kubectl get nodes
# Shows: Ready or NotReady
```

</div>

<!--
METADATA:
sentence: get shows summary, describe shows detailed information including events, capacity, and conditions.
search_anchor: get shows summary
-->
<div v-click="2">

```mermaid
stateDiagram-v2
    [*] --> Ready
    [*] --> NotReady
    Ready --> NotReady: Kubelet stops<br/>Network fails<br/>Disk pressure
    NotReady --> Ready: Issue resolved
    NotReady --> [*]: Node removed
```

</div>

<div class="grid grid-cols-2 gap-6 mt-8 text-sm">
<!--
METADATA:
sentence: Ready status means node can accept workloads.
search_anchor: Ready status means node can accept workloads
-->
<div v-click="3">
<carbon-checkmark class="text-4xl text-green-400 mb-2" />
<strong>Ready</strong><br/>
Accepting workloads
</div>
<!--
METADATA:
sentence: Ready status means node can accept workloads.
search_anchor: node can accept workloads
-->
<div v-click="4">
<carbon-close class="text-4xl text-red-400 mb-2" />
<strong>NotReady</strong><br/>
Cannot run Pods
</div>
</div>

---
layout: center
---

# Node Conditions

<!--
METADATA:
sentence: kubectl describe node <name>  # Specific node
search_anchor: kubectl describe node
-->
<div v-click="1" class="text-sm mb-4">

```bash
kubectl describe node <node-name>
```

</div>

<div class="text-xs">

| Condition | Meaning |
|-----------|---------|
<!--
METADATA:
sentence: Ready: Node is healthy and ready for Pods
search_anchor: Ready: Node is healthy
-->
| <span v-click="2">Ready</span> | <span v-click="2">Node is healthy and ready for Pods</span> |
<!--
METADATA:
sentence: DiskPressure: Node is low on disk space
search_anchor: DiskPressure: Node is low on disk space
-->
| <span v-click="3">DiskPressure</span> | <span v-click="3">Disk capacity low</span> |
<!--
METADATA:
sentence: MemoryPressure: Node is low on memory
search_anchor: MemoryPressure: Node is low on memory
-->
| <span v-click="4">MemoryPressure</span> | <span v-click="4">Memory capacity low</span> |
<!--
METADATA:
sentence: PIDPressure: Too many processes running
search_anchor: PIDPressure: Too many processes running
-->
| <span v-click="5">PIDPressure</span> | <span v-click="5">Too many processes</span> |
<!--
METADATA:
sentence: NetworkUnavailable: Network not configured
search_anchor: NetworkUnavailable: Network not configured
-->
| <span v-click="6">NetworkUnavailable</span> | <span v-click="6">Network not configured</span> |

</div>

<!--
METADATA:
sentence: Ready status means node can accept workloads.
search_anchor: accept workloads
-->
<div v-click="7" class="mt-8 text-center text-sm">
<carbon-information class="inline-block text-2xl text-blue-400" /> Conditions provide health insights
</div>

---
layout: center
---

# Node Capacity and Allocatable

<!--
METADATA:
sentence: Capacity: Total resources on node (CPU, memory)
search_anchor: Capacity: Total resources on node
-->
<div v-click="1">

```mermaid
graph TB
    C[Node Capacity<br/>Total resources] --> R[Reserved<br/>System daemons]
    C --> A[Allocatable<br/>For Pods]
    A --> P1[Pod 1]
    A --> P2[Pod 2]
    A --> P3[Pod 3]
    style C fill:#60a5fa
    style R fill:#ef4444
    style A fill:#4ade80
```

</div>

<div class="grid grid-cols-2 gap-6 mt-8 text-sm">
<!--
METADATA:
sentence: Capacity: Total resources on node (CPU, memory)
search_anchor: Total resources on node
-->
<div v-click="2">
<carbon-server class="text-4xl text-blue-400 mb-2" />
<strong>Capacity</strong><br/>
Total node resources
</div>
<!--
METADATA:
sentence: Allocatable: Available for Pods (capacity minus system reserved)
search_anchor: Allocatable: Available for Pods
-->
<div v-click="3">
<carbon-application class="text-4xl text-green-400 mb-2" />
<strong>Allocatable</strong><br/>
Available for Pods
</div>
</div>

<!--
METADATA:
sentence: System components reserve some resources. Pods can only use allocatable amount.
search_anchor: Pods can only use allocatable amount
-->
<div v-click="4" class="mt-6 text-center text-sm opacity-80">
Allocatable = Capacity - Reserved for system
</div>

---
layout: center
---

# Node Selectors

<!--
METADATA:
sentence: Labels used for Pod scheduling with nodeSelector or affinity.
search_anchor: Labels used for Pod scheduling with nodeSelector
-->
<div v-click="1">

```yaml
apiVersion: v1
kind: Pod
spec:
  nodeSelector:
    disktype: ssd
    gpu: "true"
  containers:
  - name: app
    image: myapp
```

</div>

<!--
METADATA:
sentence: Labels used for Pod scheduling with nodeSelector or affinity.
search_anchor: Pod scheduling with nodeSelector or affinity
-->
<div v-click="2" class="mt-8 text-center text-lg">
Schedule Pods to specific nodes using labels
</div>

<!--
METADATA:
sentence: Labels are key-value pairs providing node metadata.
search_anchor: Labels are key-value pairs providing node metadata
-->
<div v-click="3" class="mt-6">

```mermaid
graph LR
    P[Pod<br/>nodeSelector:<br/>disktype: ssd] --> N1[Node 1<br/>disktype: ssd]
    P -.->|No match| N2[Node 2<br/>disktype: hdd]
    style P fill:#60a5fa
    style N1 fill:#4ade80
    style N2 fill:#ef4444
```

</div>

<!--
METADATA:
sentence: Labels are key-value pairs providing node metadata.
search_anchor: key-value pairs providing node metadata
-->
<div v-click="4" class="mt-6 text-center text-sm opacity-80">
Simple key-value label matching
</div>

---
layout: center
---

# Node Affinity

<!--
METADATA:
sentence: Labels used for Pod scheduling with nodeSelector or affinity.
search_anchor: nodeSelector or affinity
-->
<div v-click="1" class="text-xs">

```yaml
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
            - arm64
```

</div>

<!--
METADATA:
sentence: Labels used for Pod scheduling with nodeSelector or affinity.
search_anchor: affinity
-->
<div v-click="2" class="mt-8 text-center text-lg">
More expressive than nodeSelector
</div>

<div class="grid grid-cols-2 gap-6 mt-6 text-sm">
<!--
METADATA:
sentence: Labels used for Pod scheduling with nodeSelector or affinity.
search_anchor: scheduling with nodeSelector
-->
<div v-click="3">
<carbon-rule class="text-4xl text-red-400 mb-2" />
<strong>Required</strong><br/>
Must match
</div>
<!--
METADATA:
sentence: Labels used for Pod scheduling with nodeSelector or affinity.
search_anchor: scheduling
-->
<div v-click="4">
<carbon-information class="text-4xl text-blue-400 mb-2" />
<strong>Preferred</strong><br/>
Try to match
</div>
</div>

<!--
METADATA:
sentence: Labels used for Pod scheduling with nodeSelector or affinity.
search_anchor: Labels used for Pod scheduling
-->
<div v-click="5" class="mt-6 text-center text-xs">
Operators: In, NotIn, Exists, DoesNotExist, Gt, Lt
</div>

---
layout: center
---

# Taints and Tolerations

<!--
METADATA:
sentence: Taint a node: kubectl taint node <name> key=value:NoSchedule
search_anchor: Taint a node
-->
<div v-click="1">

```mermaid
graph TB
    N[Node with Taint<br/>node=special:NoSchedule] --> B{Pod has<br/>toleration?}
    B -->|Yes| A[Pod scheduled]
    B -->|No| D[Pod rejected]
    style N fill:#fbbf24
    style A fill:#4ade80
    style D fill:#ef4444
```

</div>

<!--
METADATA:
sentence: Taint a node: kubectl taint node <name> key=value:NoSchedule
search_anchor: kubectl taint node
-->
<div v-click="2" class="mt-8 text-center text-lg">
Nodes repel Pods unless Pods tolerate the taint
</div>

<div class="grid grid-cols-2 gap-6 mt-6 text-sm">
<!--
METADATA:
sentence: Taint a node: kubectl taint node <name> key=value:NoSchedule
search_anchor: key=value:NoSchedule
-->
<div v-click="3">
<carbon-warning class="text-4xl text-yellow-400 mb-2" />
<strong>Taint</strong><br/>
Applied to node
</div>
<!--
METADATA:
sentence: Essential for node management.
search_anchor: Essential for node management
-->
<div v-click="4">
<carbon-checkmark class="text-4xl text-green-400 mb-2" />
<strong>Toleration</strong><br/>
Added to Pod
</div>
</div>

---
layout: center
---

# Taint Effects

<div class="grid grid-cols-3 gap-6 mt-6">
<!--
METADATA:
sentence: Taint a node: kubectl taint node <name> key=value:NoSchedule
search_anchor: NoSchedule
-->
<div v-click="1">
<carbon-close class="text-4xl text-red-400 mb-2" />
<strong>NoSchedule</strong><br/>
<span class="text-sm opacity-80">Don't schedule new Pods</span>
</div>
<!--
METADATA:
sentence: Essential for node management.
search_anchor: node management
-->
<div v-click="2">
<carbon-warning class="text-4xl text-yellow-400 mb-2" />
<strong>PreferNoSchedule</strong><br/>
<span class="text-sm opacity-80">Try not to schedule</span>
</div>
<!--
METADATA:
sentence: kubectl drain <name>  # Evict Pods
search_anchor: Evict Pods
-->
<div v-click="3">
<carbon-delete class="text-4xl text-purple-400 mb-2" />
<strong>NoExecute</strong><br/>
<span class="text-sm opacity-80">Evict existing Pods</span>
</div>
</div>

<!--
METADATA:
sentence: Taint a node: kubectl taint node <name> key=value:NoSchedule
search_anchor: taint node
-->
<div v-click="4" class="mt-8">

```bash
# Add taint
kubectl taint nodes node1 key=value:NoSchedule

# Remove taint
kubectl taint nodes node1 key=value:NoSchedule-
```

</div>

<!--
METADATA:
sentence: kubectl drain <name>  # Evict Pods
search_anchor: drain
-->
<div v-click="5" class="mt-6 text-center text-sm">
<carbon-information class="inline-block text-2xl text-blue-400" /> NoExecute evicts Pods without matching toleration
</div>

---
layout: center
---

# Cordon and Drain

<!--
METADATA:
sentence: Cordon/drain for maintenance: kubectl cordon <name>  # Mark unschedulable
search_anchor: Cordon/drain for maintenance
-->
<div v-click="1">

```mermaid
graph LR
    N[Node] -->|cordon| C[Cordoned<br/>No new Pods]
    C -->|drain| D[Drained<br/>All Pods evicted]
    D -->|uncordon| N
    style N fill:#4ade80
    style C fill:#fbbf24
    style D fill:#ef4444
```

</div>

<!--
METADATA:
sentence: kubectl cordon <name>  # Mark unschedulable
search_anchor: kubectl cordon
-->
<div v-click="2" class="mt-8">

```bash
# Mark node as unschedulable
kubectl cordon <node-name>

# Evict all Pods and mark unschedulable
kubectl drain <node-name> --ignore-daemonsets

# Mark node as schedulable again
kubectl uncordon <node-name>
```

</div>

<!--
METADATA:
sentence: kubectl uncordon <name>  # Re-enable
search_anchor: kubectl uncordon
-->
<div v-click="3" class="mt-6 text-center text-sm">
<carbon-tools class="inline-block text-2xl text-yellow-400" /> Used for maintenance
</div>

---
layout: center
---

# Node Management Best Practices

<div class="grid grid-cols-2 gap-6 mt-6">
<!--
METADATA:
sentence: Label a node: kubectl label node <name> key=value
search_anchor: Label a node
-->
<div v-click="1">
<carbon-tag class="text-4xl text-blue-400 mb-2" />
<strong>Label nodes</strong><br/>
<span class="text-sm opacity-80">For scheduling and organization</span>
</div>
<!--
METADATA:
sentence: Capacity: Total resources on node (CPU, memory)
search_anchor: Total resources
-->
<div v-click="2">
<carbon-chart-line class="text-4xl text-green-400 mb-2" />
<strong>Monitor capacity</strong><br/>
<span class="text-sm opacity-80">Watch resource usage</span>
</div>
<!--
METADATA:
sentence: Taint a node: kubectl taint node <name> key=value:NoSchedule
search_anchor: Taint
-->
<div v-click="3">
<carbon-warning class="text-4xl text-yellow-400 mb-2" />
<strong>Use taints wisely</strong><br/>
<span class="text-sm opacity-80">Dedicated nodes for special workloads</span>
</div>
<!--
METADATA:
sentence: kubectl drain <name>  # Evict Pods
search_anchor: kubectl drain
-->
<div v-click="4">
<carbon-tools class="text-4xl text-purple-400 mb-2" />
<strong>Drain before maintenance</strong><br/>
<span class="text-sm opacity-80">Graceful Pod eviction</span>
</div>
</div>

---
layout: center
---

# Summary

<!--
METADATA:
sentence: Key skills: Query nodes with get/describe, understand capacity vs allocatable, read node labels, format output with -o and jsonpath, use explain for documentation.
search_anchor: Key skills
-->
<div v-click="1">

```mermaid
mindmap
  root((Nodes))
    Components
      kubelet
      Container runtime
      kube-proxy
    Status
      Ready NotReady
      Conditions
      Capacity
    Scheduling
      nodeSelector
      Node affinity
      Taints tolerations
    Management
      Cordon
      Drain
      Uncordon
```

</div>

---
layout: center
---

# Key Takeaways

<div class="grid grid-cols-2 gap-6 mt-6">
<!--
METADATA:
sentence: Nodes are worker machines (physical servers, VMs, cloud instances) that run containers in Kubernetes clusters.
search_anchor: Nodes are worker machines
-->
<div v-click="1">
<carbon-server class="text-4xl text-blue-400 mb-2" />
<strong>Nodes are workers</strong><br/>
<span class="text-sm opacity-80">Run your containerized workloads</span>
</div>
<!--
METADATA:
sentence: Labels are key-value pairs providing node metadata.
search_anchor: Labels
-->
<div v-click="2">
<carbon-tag class="text-4xl text-green-400 mb-2" />
<strong>Use labels</strong><br/>
<span class="text-sm opacity-80">For flexible scheduling</span>
</div>
<!--
METADATA:
sentence: Taint a node: kubectl taint node <name> key=value:NoSchedule
search_anchor: taint
-->
<div v-click="3">
<carbon-warning class="text-4xl text-purple-400 mb-2" />
<strong>Taints control placement</strong><br/>
<span class="text-sm opacity-80">Dedicated or restricted nodes</span>
</div>
<!--
METADATA:
sentence: kubectl drain <name>  # Evict Pods
search_anchor: Evict
-->
<div v-click="4">
<carbon-tools class="text-4xl text-yellow-400 mb-2" />
<strong>Drain for maintenance</strong><br/>
<span class="text-sm opacity-80">Graceful workload migration</span>
</div>
</div>

<!--
METADATA:
sentence: For CKAD: Master kubectl node commands, quickly find information, troubleshoot scheduling issues by checking node capacity and labels.
search_anchor: For CKAD
-->
<div v-click="5" class="mt-8 text-center text-lg">
<carbon-information class="inline-block text-3xl text-blue-400" /> Understand node management for CKAD!
</div>
