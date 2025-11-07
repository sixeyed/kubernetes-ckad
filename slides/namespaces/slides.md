---
layout: cover
---

# Kubernetes Namespaces

<div class="abs-br m-6 flex gap-2">
  <carbon-partition-auto class="text-6xl text-blue-400" />
</div>

<!--
METADATA:
sentence: Namespaces allow you to partition a single Kubernetes cluster into multiple virtual clusters.
search_anchor: partition a single Kubernetes cluster
-->
<div v-click="1" class="mt-8 text-xl opacity-80">
Isolating workloads in virtual clusters
</div>

<!--
METADATA:
sentence: Run multiple environments (dev, test, prod) on one cluster
search_anchor: Run multiple environments
-->
<div v-click="2" class="mt-6 text-lg">
<carbon-partition-auto class="inline-block text-xl text-green-400" /> Run multiple environments on one cluster
</div>

<!--
METADATA:
sentence: Apply resource quotas and limits per namespace
search_anchor: Apply resource quotas and limits per namespace
-->
<div v-click="3" class="mt-2 text-lg">
<carbon-rule class="inline-block text-xl text-purple-400" /> Apply resource quotas and limits
</div>

<!--
METADATA:
sentence: Manage access controls at the namespace level
search_anchor: Manage access controls at the namespace level
-->
<div v-click="4" class="mt-2 text-lg">
<carbon-locked class="inline-block text-xl text-blue-400" /> Manage access controls per namespace
</div>

<!--
METADATA:
sentence: This is a core CKAD exam topic, so understanding namespaces is essential for both the certification and real-world Kubernetes operations.
search_anchor: core CKAD exam topic
-->
<div v-click="5" class="mt-6 text-sm opacity-60">
Core CKAD exam topic
</div>

---
layout: center
---

# The Multi-Tenancy Problem

<!--
METADATA:
sentence: Imagine you're running a large Kubernetes cluster with: 50 different applications, Multiple teams (platform, data, web, mobile), Different environments (dev, staging, production), Hundreds of Pods, Services, and ConfigMaps
search_anchor: large Kubernetes cluster
-->
<div v-click="1">

```mermaid
graph TB
    C[Cluster] --> A1[50 Applications]
    C --> T[Multiple Teams]
    C --> E[Multiple Environments]
    C --> R[Hundreds of Resources]
    style C fill:#ef4444,color:#fff
    style A1 fill:#fbbf24
    style T fill:#fbbf24
    style E fill:#fbbf24
    style R fill:#fbbf24
```

</div>

<div class="grid grid-cols-2 gap-4 mt-8 text-sm">
<!--
METADATA:
sentence: Name collisions between applications
search_anchor: Name collisions between applications
-->
<div v-click="2">
<carbon-close class="inline-block text-3xl text-red-400" /> Name collisions
</div>
<!--
METADATA:
sentence: Accidental deletion of production resources
search_anchor: Accidental deletion of production resources
-->
<div v-click="3">
<carbon-warning class="inline-block text-3xl text-red-400" /> Accidental deletions
</div>
<!--
METADATA:
sentence: Resource contention - one app consuming all cluster resources
search_anchor: Resource contention
-->
<div v-click="4">
<carbon-dashboard class="inline-block text-3xl text-red-400" /> Resource contention
</div>
<!--
METADATA:
sentence: Difficult access control - everyone can see everything
search_anchor: Difficult access control
-->
<div v-click="5">
<carbon-unlocked class="inline-block text-3xl text-red-400" /> No access control
</div>
<!--
METADATA:
sentence: No cost tracking per team or application
search_anchor: No cost tracking per team
-->
<div v-click="6">
<carbon-currency-dollar class="inline-block text-3xl text-red-400" /> No cost tracking
</div>
</div>

<!--
METADATA:
sentence: Namespaces solve these problems by providing logical isolation within a single physical cluster.
search_anchor: providing logical isolation
-->
<div v-click="7" class="mt-6 text-center text-lg">
<carbon-partition-auto class="inline-block text-3xl text-green-400" /> Namespaces provide logical isolation
</div>

---
layout: center
---

# What Are Namespaces?

<!--
METADATA:
sentence: A namespace is a virtual cluster boundary within your physical cluster.
search_anchor: virtual cluster boundary
-->
<div v-click="1">

```mermaid
graph TB
    subgraph Cluster[Physical Cluster]
        subgraph NS1[dev namespace]
            P1[Pod: web]
            S1[Service: web]
        end
        subgraph NS2[prod namespace]
            P2[Pod: web]
            S2[Service: web]
        end
    end
    style Cluster fill:#60a5fa,color:#fff
    style NS1 fill:#4ade80
    style NS2 fill:#fbbf24
```

</div>

<!--
METADATA:
sentence: A namespace is a virtual cluster boundary within your physical cluster.
search_anchor: within your physical cluster
-->
<div v-click="2" class="mt-8 text-center text-lg">
Virtual cluster boundaries within physical cluster
</div>

<div class="grid grid-cols-2 gap-4 mt-6 text-sm">
<!--
METADATA:
sentence: Namespaces contain resources (Pods, Services, ConfigMaps, etc.)
search_anchor: Namespaces contain resources
-->
<div v-click="3">
<carbon-container-software class="inline-block text-2xl text-blue-400" /> Contains resources
</div>
<!--
METADATA:
sentence: Resources in one namespace are isolated from another
search_anchor: Resources in one namespace are isolated
-->
<div v-click="4">
<carbon-partition-auto class="inline-block text-2xl text-green-400" /> Logical isolation
</div>
<!--
METADATA:
sentence: Names must be unique within a namespace, but can be reused across namespaces
search_anchor: unique within a namespace
-->
<div v-click="5">
<carbon-tag class="inline-block text-2xl text-purple-400" /> Unique names per namespace
</div>
<!--
METADATA:
sentence: Namespaces are flat - they cannot be nested
search_anchor: Namespaces are flat
-->
<div v-click="6">
<carbon-rule class="inline-block text-2xl text-yellow-400" /> Flat structure (no nesting)
</div>
</div>

---
layout: center
---

# Default Namespaces

<!--
METADATA:
sentence: Default namespaces in every cluster:
search_anchor: Default namespaces in every cluster
-->
<div v-click="1">

```mermaid
graph TB
    K[Kubernetes Cluster]
    K --> D[default<br/>User resources]
    K --> S[kube-system<br/>System components]
    K --> P[kube-public<br/>Public resources]
    K --> N[kube-node-lease<br/>Node heartbeats]
    style K fill:#60a5fa
    style D fill:#4ade80
    style S fill:#fbbf24
    style P fill:#a78bfa
    style N fill:#ef4444
```

</div>

<div class="grid grid-cols-2 gap-4 mt-8 text-sm">
<!--
METADATA:
sentence: default - Where resources go if no namespace is specified
search_anchor: default - Where resources go
-->
<div v-click="2">
<carbon-document class="inline-block text-2xl text-green-400" /> <strong>default:</strong> Resources without -n flag
</div>
<!--
METADATA:
sentence: kube-system - Kubernetes system components (DNS, dashboard, etc.)
search_anchor: kube-system - Kubernetes system components
-->
<div v-click="3">
<carbon-kubernetes class="inline-block text-2xl text-yellow-400" /> <strong>kube-system:</strong> DNS, dashboard, controllers
</div>
<!--
METADATA:
sentence: kube-public - Publicly readable resources
search_anchor: kube-public - Publicly readable resources
-->
<div v-click="4">
<carbon-view class="inline-block text-2xl text-purple-400" /> <strong>kube-public:</strong> Publicly readable data
</div>
<!--
METADATA:
sentence: kube-node-lease - Node heartbeat information (Kubernetes 1.13+)
search_anchor: kube-node-lease - Node heartbeat information
-->
<div v-click="5">
<carbon-activity class="inline-block text-2xl text-red-400" /> <strong>kube-node-lease:</strong> Node health (1.13+)
</div>
</div>

---
layout: center
---

# Namespace Scoping

<!--
METADATA:
sentence: Not all Kubernetes resources are namespace-scoped. Understanding this distinction is critical.
search_anchor: Not all Kubernetes resources are namespace-scoped
-->
<div v-click="1" class="mb-6">

```mermaid
graph LR
    R[Resources]
    R --> NS[Namespace-Scoped]
    R --> CS[Cluster-Scoped]
    NS --> P[Pods<br/>Services<br/>ConfigMaps<br/>Secrets<br/>PVCs]
    CS --> N[Nodes<br/>Namespaces<br/>PersistentVolumes<br/>StorageClasses<br/>ClusterRoles]
    style R fill:#60a5fa
    style NS fill:#4ade80
    style CS fill:#fbbf24
```

</div>

<div class="grid grid-cols-2 gap-6">
<!--
METADATA:
sentence: Namespace-scoped resources need -n namespace flag
search_anchor: Namespace-scoped resources need -n
-->
<div v-click="2">
<carbon-tag class="text-4xl text-green-400 mb-2" />
<strong>Namespace-scoped</strong><br/>
<span class="text-sm opacity-80">Need -n flag to query</span>
</div>
<!--
METADATA:
sentence: Cluster-scoped resources are global, visible to all
search_anchor: Cluster-scoped resources are global
-->
<div v-click="3">
<carbon-network-3 class="text-4xl text-yellow-400 mb-2" />
<strong>Cluster-scoped</strong><br/>
<span class="text-sm opacity-80">Global, visible to all</span>
</div>
</div>

<!--
METADATA:
sentence: Use kubectl api-resources --namespaced=true to list all namespace-scoped resources.
search_anchor: kubectl api-resources --namespaced=true
-->
<div v-click="4" class="mt-6 text-center text-sm">
<carbon-terminal class="inline-block text-2xl text-blue-400" /> kubectl api-resources --namespaced=true
</div>

---
layout: center
---

# Resource Quotas

<!--
METADATA:
sentence: Resource Quotas limit the total resources that can be consumed in a namespace.
search_anchor: Resource Quotas limit the total resources
-->
<div v-click="1">

```mermaid
graph TB
    NS[Namespace] --> RQ[ResourceQuota]
    RQ --> C[CPU Limits<br/>4 cores max]
    RQ --> M[Memory Limits<br/>8GB max]
    RQ --> O[Object Counts<br/>10 Pods max]
    RQ --> S[Storage<br/>100GB max]
    style NS fill:#60a5fa
    style RQ fill:#fbbf24
    style C fill:#4ade80
    style M fill:#4ade80
    style O fill:#4ade80
    style S fill:#4ade80
```

</div>

<!--
METADATA:
sentence: Resource Quotas limit the total resources that can be consumed in a namespace.
search_anchor: total resources that can be consumed
-->
<div v-click="2" class="mt-8 text-center text-lg">
Limit total resources consumed in a namespace
</div>

<div class="grid grid-cols-3 gap-4 mt-6 text-sm">
<!--
METADATA:
sentence: Compute resources: CPU requests and limits (total across all Pods), Memory requests and limits
search_anchor: Compute resources: CPU requests
-->
<div v-click="3">
<carbon-dashboard class="inline-block text-2xl text-blue-400" /> Compute resources
</div>
<!--
METADATA:
sentence: Object counts: Maximum number of Pods, Services, ConfigMaps, Secrets
search_anchor: Object counts: Maximum number of Pods
-->
<div v-click="4">
<carbon-rule class="inline-block text-2xl text-green-400" /> Object counts
</div>
<!--
METADATA:
sentence: Storage: Total storage requests across all PVCs, Storage by StorageClass
search_anchor: Storage: Total storage requests
-->
<div v-click="5">
<carbon-data-base class="inline-block text-2xl text-purple-400" /> Storage limits
</div>
</div>

<!--
METADATA:
sentence: When a namespace has ResourceQuota for CPU or memory, every Pod must specify resource requests and limits, or it will be rejected.
search_anchor: every Pod must specify resource requests and limits
-->
<div v-click="6" class="mt-6 text-center text-red-400">
<carbon-warning class="inline-block text-2xl" /> With quotas, Pods MUST specify resources!
</div>

---
layout: center
---

# LimitRange

<!--
METADATA:
sentence: LimitRanges work alongside ResourceQuotas but at the Pod/container level.
search_anchor: LimitRanges work alongside ResourceQuotas
-->
<div v-click="1">

```mermaid
graph LR
    LR[LimitRange] --> D[Default Values]
    LR --> MM[Min/Max Constraints]
    LR --> R[Request/Limit Ratios]
    D --> A[Apply to Pods]
    MM --> A
    R --> A
    style LR fill:#60a5fa
    style D fill:#4ade80
    style MM fill:#fbbf24
    style R fill:#a78bfa
    style A fill:#ef4444
```

</div>

<!--
METADATA:
sentence: LimitRanges work alongside ResourceQuotas but at the Pod/container level.
search_anchor: at the Pod/container level
-->
<div v-click="2" class="mt-8 text-center text-lg">
Per-Pod/container defaults and constraints
</div>

<div class="grid grid-cols-2 gap-6 mt-6 text-sm">
<!--
METADATA:
sentence: Default values: If a Pod doesn't specify resources, LimitRange applies defaults
search_anchor: Default values: If a Pod doesn't specify
-->
<div v-click="3">
<carbon-settings class="text-3xl text-green-400 mb-2" />
<strong>Default Values</strong><br/>
Auto-apply when not specified
</div>
<!--
METADATA:
sentence: Min/Max constraints: Enforce minimum resource requests (no tiny containers), Enforce maximum limits (no huge containers)
search_anchor: Min/Max constraints: Enforce minimum
-->
<div v-click="4">
<carbon-rule class="text-3xl text-yellow-400 mb-2" />
<strong>Min/Max Constraints</strong><br/>
Enforce resource boundaries
</div>
</div>

<!--
METADATA:
sentence: ResourceQuota: Total resources for the entire namespace, LimitRange: Per-container or per-Pod constraints
search_anchor: ResourceQuota: Total resources for the entire namespace
-->
<div v-click="5" class="mt-6 text-center text-sm opacity-80">
ResourceQuota = namespace total • LimitRange = per-container
</div>

---
layout: center
---

# Cross-Namespace Communication

<!--
METADATA:
sentence: Services are namespace-scoped, but Pods can communicate across namespaces using DNS.
search_anchor: Pods can communicate across namespaces using DNS
-->
<div v-click="1">

```mermaid
graph TB
    subgraph frontend[frontend namespace]
        F[Frontend Pod]
    end
    subgraph backend[backend namespace]
        B[Backend Service]
    end
    F -->|web-service.backend| B
    F -->|web-service.backend.svc.cluster.local| B
    style frontend fill:#4ade80
    style backend fill:#60a5fa
```

</div>

<!--
METADATA:
sentence: Services are namespace-scoped, but Pods can communicate across namespaces using DNS.
search_anchor: Services are namespace-scoped
-->
<div v-click="2" class="mt-8 text-center text-lg">
Services accessible via DNS across namespaces
</div>

<div class="grid grid-cols-3 gap-4 mt-6 text-xs">
<!--
METADATA:
sentence: Short name (same namespace only): web-service - Only resolves within the same namespace
search_anchor: Short name (same namespace only)
-->
<div v-click="3" class="text-center">
<carbon-text-font class="text-3xl text-green-400 mb-2" />
<strong>Short name</strong><br/>
web-service<br/>
<span class="opacity-60">Same namespace only</span>
</div>
<!--
METADATA:
sentence: Namespace-qualified: web-service.production - Resolves from any namespace
search_anchor: Namespace-qualified: web-service.production
-->
<div v-click="4" class="text-center">
<carbon-network-1 class="text-3xl text-blue-400 mb-2" />
<strong>Qualified</strong><br/>
web-service.production<br/>
<span class="opacity-60">Any namespace</span>
</div>
<!--
METADATA:
sentence: Fully-qualified domain name (FQDN): web-service.production.svc.cluster.local - Complete, unambiguous service address
search_anchor: Fully-qualified domain name (FQDN)
-->
<div v-click="5" class="text-center">
<carbon-network-3 class="text-3xl text-purple-400 mb-2" />
<strong>FQDN</strong><br/>
web.prod.svc.cluster.local<br/>
<span class="opacity-60">Fully qualified</span>
</div>
</div>

<!--
METADATA:
sentence: Kubernetes networking is flat - any Pod can reach any other Pod by IP address, regardless of namespace.
search_anchor: Kubernetes networking is flat
-->
<div v-click="6" class="mt-6 text-center text-sm opacity-80">
Kubernetes networking is flat - any Pod can reach any Pod by IP
</div>

<!--
METADATA:
sentence: For network isolation, use NetworkPolicies - they can restrict traffic based on namespace labels.
search_anchor: For network isolation, use NetworkPolicies
-->
<div v-click="7" class="mt-2 text-center text-sm text-yellow-400">
<carbon-security class="inline-block text-2xl" /> For network isolation, use NetworkPolicies
</div>

---
layout: center
---

# ConfigMaps & Secrets Scoping

<!--
METADATA:
sentence: ConfigMaps and Secrets are namespace-scoped resources that cannot be shared across namespaces.
search_anchor: ConfigMaps and Secrets are namespace-scoped resources
-->
<div v-click="1">

```mermaid
graph TB
    subgraph app[app namespace]
        P1[Pod]
        C1[ConfigMap]
        P1 -.->|✓ Can mount| C1
    end
    subgraph shared[shared namespace]
        C2[ConfigMap]
    end
    P1 -.->|✗ Cannot mount| C2
    style app fill:#4ade80
    style shared fill:#60a5fa
```

</div>

<!--
METADATA:
sentence: ConfigMaps and Secrets are namespace-scoped resources that cannot be shared across namespaces.
search_anchor: cannot be shared across namespaces
-->
<div v-click="2" class="mt-8 text-center text-lg text-red-400">
<carbon-warning class="inline-block text-3xl" /> ConfigMaps & Secrets cannot cross namespaces
</div>

<div class="grid grid-cols-2 gap-6 mt-6 text-sm">
<!--
METADATA:
sentence: Can't reference a ConfigMap from namespace "shared" in a Pod in namespace "app", Must create duplicate ConfigMaps in each namespace
search_anchor: Must create duplicate ConfigMaps in each namespace
-->
<div v-click="3">
<carbon-copy class="text-3xl text-yellow-400 mb-2" />
<strong>Duplicate config</strong><br/>
Create in each namespace
</div>
<!--
METADATA:
sentence: Solution: Use FQDN service names (db.backend.svc.cluster.local)
search_anchor: Use FQDN service names
-->
<div v-click="4">
<carbon-network-3 class="text-3xl text-blue-400 mb-2" />
<strong>Use FQDN for services</strong><br/>
db.backend.svc.cluster.local
</div>
</div>

<!--
METADATA:
sentence: Or use tools like Kustomize/Helm to manage duplicates
search_anchor: use tools like Kustomize/Helm
-->
<div v-click="5" class="mt-6 text-center text-sm opacity-80">
Use Kustomize/Helm to manage duplicates
</div>

---
layout: center
---

# Managing Context

<!--
METADATA:
sentence: Every kubectl command operates against a namespace. You can specify it three ways:
search_anchor: Every kubectl command operates against a namespace
-->
<div v-click="1">

```mermaid
graph LR
    K[kubectl] --> F["-n flag<br/>(explicit)"]
    K --> C["Context<br/>(implicit)"]
    K --> Y["YAML metadata<br/>(declarative)"]
    style K fill:#60a5fa
    style F fill:#4ade80
    style C fill:#fbbf24
    style Y fill:#a78bfa
```

</div>

<div class="grid grid-cols-3 gap-4 mt-8 text-xs">
<!--
METADATA:
sentence: Using the -n flag (explicit): kubectl get pods -n production - Pros: Clear and explicit, no mistakes
search_anchor: Using the -n flag (explicit)
-->
<div v-click="2">
<carbon-terminal class="text-3xl text-green-400 mb-2" />
<strong>Flag method</strong><br/>
kubectl get pods -n prod<br/>
<span class="opacity-60">Clear, explicit</span>
</div>
<!--
METADATA:
sentence: Setting context namespace (implicit): kubectl config set-context --current --namespace production - Pros: Less typing, cleaner commands
search_anchor: Setting context namespace (implicit)
-->
<div v-click="3">
<carbon-settings class="text-3xl text-yellow-400 mb-2" />
<strong>Context method</strong><br/>
kubectl config set-context<br/>
<span class="opacity-60">Less typing</span>
</div>
<!--
METADATA:
sentence: Namespace in YAML (declarative): metadata: name: web-app, namespace: production - Pros: Self-documenting, version-controlled
search_anchor: Namespace in YAML (declarative)
-->
<div v-click="4">
<carbon-document class="text-3xl text-purple-400 mb-2" />
<strong>YAML method</strong><br/>
metadata: namespace: prod<br/>
<span class="opacity-60">Self-documenting</span>
</div>
</div>

<!--
METADATA:
sentence: Use -n flag when jumping between namespaces to avoid mistakes.
search_anchor: Use -n flag when jumping between namespaces
-->
<div v-click="5" class="mt-8 text-center text-sm">
<carbon-idea class="inline-block text-2xl text-blue-400" /> CKAD tip: Use -n flag when switching to avoid mistakes
</div>

---
layout: center
---

# Namespace Lifecycle

<!--
METADATA:
sentence: Namespaces have an important lifecycle behavior to understand:
search_anchor: Namespaces have an important lifecycle behavior
-->
<div v-click="1">

```mermaid
stateDiagram-v2
    [*] --> Active: kubectl create ns
    Active --> Terminating: kubectl delete ns
    Terminating --> [*]: All resources deleted
```

</div>

<!--
METADATA:
sentence: WARNING: Deleting a namespace deletes EVERYTHING inside it:
search_anchor: WARNING: Deleting a namespace deletes EVERYTHING
-->
<div v-click="2" class="mt-8 text-center text-2xl text-red-400">
<carbon-warning class="inline-block text-4xl" /> WARNING
</div>

<!--
METADATA:
sentence: WARNING: Deleting a namespace deletes EVERYTHING inside it:
search_anchor: deletes EVERYTHING inside it
-->
<div v-click="3" class="text-center text-lg mt-4">
Deleting a namespace deletes EVERYTHING inside
</div>

<div class="grid grid-cols-2 gap-4 mt-6 text-sm">
<!--
METADATA:
sentence: All Pods, Services, Deployments
search_anchor: All Pods, Services, Deployments
-->
<div v-click="4">
<carbon-close class="inline-block text-2xl text-red-400" /> All Pods, Services, Deployments
</div>
<!--
METADATA:
sentence: All ConfigMaps, Secrets
search_anchor: All ConfigMaps, Secrets
-->
<div v-click="5">
<carbon-close class="inline-block text-2xl text-red-400" /> All ConfigMaps, Secrets
</div>
<!--
METADATA:
sentence: All PersistentVolumeClaims
search_anchor: All PersistentVolumeClaims
-->
<div v-click="6">
<carbon-close class="inline-block text-2xl text-red-400" /> All PersistentVolumeClaims
</div>
<!--
METADATA:
sentence: Cannot be undone!
search_anchor: Cannot be undone!
-->
<div v-click="7">
<carbon-warning class="inline-block text-2xl text-red-400" /> Cannot be undone!
</div>
</div>

<!--
METADATA:
sentence: Namespace deletion is async: Namespace enters "Terminating" state, Kubernetes deletes all resources inside
search_anchor: Namespace deletion is async
-->
<div v-click="8" class="mt-6 text-center text-sm opacity-80">
Deletion is async - namespace enters "Terminating" state
</div>

---
layout: center
---

# Summary

<!--
METADATA:
sentence: Key takeaways participants should understand: Namespaces provide logical isolation within a cluster
search_anchor: Namespaces provide logical isolation within a cluster
-->
<div v-click="1">

```mermaid
mindmap
  root((Namespaces))
    Virtual Clusters
      Logical isolation
      Multi-tenancy
      Flat structure
    Scoping
      Namespace-scoped
      Cluster-scoped
      PV vs PVC
    Resource Control
      ResourceQuota total
      LimitRange per-container
      Enforce limits
    Communication
      DNS FQDN
      Flat networking
      NetworkPolicy
    Lifecycle
      Create delete
      Async termination
      Deletes all inside
```

</div>

<!--
METADATA:
sentence: Namespaces provide logical isolation within a cluster
search_anchor: logical isolation within a cluster
-->
<div v-click="2" class="mt-8 text-center text-lg">
<carbon-checkmark class="inline-block text-2xl text-green-400" /> Partition cluster into virtual clusters
</div>

<!--
METADATA:
sentence: ResourceQuotas limit total resources per namespace, LimitRanges set per-Pod/container defaults and constraints
search_anchor: ResourceQuotas limit total resources per namespace
-->
<div v-click="3" class="mt-2 text-center text-lg">
<carbon-checkmark class="inline-block text-2xl text-green-400" /> Control resources per namespace
</div>
