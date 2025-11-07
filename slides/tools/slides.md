---
layout: cover
---

# kubectl Productivity

<div class="abs-br m-6 flex gap-2">
  <carbon-terminal class="text-6xl text-blue-400" />
</div>

<!--
METADATA:
sentence: While advanced tools are beyond CKAD, kubectl mastery is essential.
search_anchor: kubectl mastery is essential
-->
<div v-click class="mt-8 text-xl opacity-80">
Master kubectl for CKAD exam success
</div>

---
layout: center
---

# Why kubectl Proficiency Matters

<!--
METADATA:
sentence: CKAD is time-pressured: 2 hours for 15-20 questions. Every second counts.
search_anchor: CKAD is time-pressured
-->
<div v-click="1">

```mermaid
graph LR
    E[CKAD Exam] --> T[2 hours]
    T --> Q[15-20 questions]
    Q --> S[Speed is Critical]
    style E fill:#60a5fa
    style T fill:#fbbf24
    style Q fill:#ef4444
    style S fill:#4ade80
```

</div>

<div class="grid grid-cols-2 gap-6 mt-8 text-sm">
<!--
METADATA:
sentence: Autocomplete: 5-10 sec per command
search_anchor: Autocomplete: 5-10 sec per command
-->
<div v-click="2">
<carbon-flash class="text-4xl text-green-400 mb-2" />
<strong>Autocomplete</strong><br/>
Save 5-10 sec per command
</div>
<!--
METADATA:
sentence: Aliases: 2-3 sec per command
search_anchor: Aliases: 2-3 sec per command
-->
<div v-click="3">
<carbon-keyboard class="text-4xl text-blue-400 mb-2" />
<strong>Aliases</strong><br/>
Save 2-3 sec per command
</div>
<!--
METADATA:
sentence: Short names: 2-3 sec per command
search_anchor: Short names: 2-3 sec per command
-->
<div v-click="4">
<carbon-text-short-paragraph class="text-4xl text-purple-400 mb-2" />
<strong>Short Names</strong><br/>
Save 2-3 sec per command
</div>
<!--
METADATA:
sentence: Quick output formatting: 10-15 sec per query
search_anchor: Quick output formatting: 10-15 sec per query
-->
<div v-click="5">
<carbon-view class="text-4xl text-yellow-400 mb-2" />
<strong>Output Formats</strong><br/>
Save 10-15 sec per query
</div>
</div>

<!--
METADATA:
sentence: Expert kubectl usage saves 30-50% of your time:
search_anchor: Expert kubectl usage saves 30-50%
-->
<div v-click="6" class="mt-8 text-center text-xl">
<carbon-checkmark class="inline-block text-3xl text-green-400" /> Expert kubectl = 30-50% time savings
</div>

---
layout: center
---

# kubectl Autocomplete

<!--
METADATA:
sentence: Enable bash completion:
search_anchor: Enable bash completion
-->
<div v-click="1" class="mb-6">

```bash
# Enable bash completion
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc
```

</div>

<!--
METADATA:
sentence: Use Tab for autocomplete:
search_anchor: Use Tab for autocomplete
-->
<div v-click="2">

```mermaid
graph LR
    T[Type: kubectl get po] --> TAB[Press TAB]
    TAB --> C[Completes: kubectl get pods]
    style TAB fill:#4ade80
    style C fill:#60a5fa
```

</div>

<div class="grid grid-cols-3 gap-4 mt-8 text-sm">
<!--
METADATA:
sentence: Resource types: `kubectl get po<TAB>`
search_anchor: Resource types
-->
<div v-click="3">
<carbon-cube class="inline-block text-3xl text-blue-400" />
<strong>Resource types</strong><br/>
<code>po&lt;TAB&gt;</code>
</div>
<!--
METADATA:
sentence: Resource names: `kubectl describe pod nginx-<TAB>`
search_anchor: Resource names
-->
<div v-click="4">
<carbon-tag class="inline-block text-3xl text-green-400" />
<strong>Resource names</strong><br/>
<code>nginx-&lt;TAB&gt;</code>
</div>
<!--
METADATA:
sentence: Namespaces: `kubectl get pods -n kube-<TAB>`
search_anchor: Namespaces
-->
<div v-click="5">
<carbon-folder class="inline-block text-3xl text-purple-400" />
<strong>Namespaces</strong><br/>
<code>kube-&lt;TAB&gt;</code>
</div>
</div>

<!--
METADATA:
sentence: Saves typing and prevents typos. Essential for exam speed.
search_anchor: Essential for exam speed
-->
<div v-click="6" class="mt-8 text-center text-lg">
<carbon-lightning class="inline-block text-2xl text-yellow-400" /> Essential for exam speed!
</div>

---
layout: center
---

# Short Names and Aliases

<!--
METADATA:
sentence: Short resource names:
search_anchor: Short resource names
-->
<div v-click="1" class="mb-4">

```bash
# Short resource names
po = pods
svc = services
deploy = deployments
rs = replicasets
cm = configmaps
ns = namespaces
```

</div>

<!--
METADATA:
sentence: Useful aliases:
search_anchor: Useful aliases
-->
<div v-click="2">

```bash
# Useful aliases
alias k=kubectl
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kdp='kubectl describe pod'
alias kl='kubectl logs'
```

</div>

<!--
METADATA:
sentence: Every keystroke saved adds up!
search_anchor: Before/After comparison
-->
<div v-click="3" class="mt-8 text-center">

```bash
# Before
kubectl get pods -n production

# After
kgp -n production
```

</div>

<!--
METADATA:
sentence: Every keystroke saved adds up!
search_anchor: Every keystroke saved
-->
<div v-click="4" class="mt-6 text-center text-yellow-400 text-sm">
<carbon-time class="inline-block text-2xl" /> Every keystroke saved adds up!
</div>

---
layout: center
---

# Output Formatting Mastery

<!--
METADATA:
sentence: Essential formats:
search_anchor: Essential formats
-->
<div v-click="1" class="mb-4">

```bash
kubectl get pods -o wide         # Extended info
kubectl get pods -o yaml         # Full YAML
kubectl get pods -o json         # JSON format
kubectl get pods -o name         # Just names
kubectl get pods --show-labels   # With labels
```

</div>

<!--
METADATA:
sentence: JSONPath for specific fields:
search_anchor: JSONPath for specific fields
-->
<div v-click="2" class="mb-4">

```bash
# JSONPath for specific fields
kubectl get pod nginx -o jsonpath='{.spec.containers[0].image}'
```

</div>

<!--
METADATA:
sentence: Custom columns:
search_anchor: Custom columns
-->
<div v-click="3">

```bash
# Custom columns
kubectl get pods -o custom-columns=\
NAME:.metadata.name,\
IMAGE:.spec.containers[0].image
```

</div>

<div class="grid grid-cols-3 gap-4 mt-6 text-sm">
<!--
METADATA:
sentence: kubectl get pods -o wide  # Extended info
search_anchor: output format wide
-->
<div v-click="4" class="text-center">
<carbon-view class="text-3xl text-blue-400 mb-1" />
<code>-o wide</code>
</div>
<!--
METADATA:
sentence: kubectl get pods -o yaml  # Full YAML
search_anchor: output format yaml
-->
<div v-click="5" class="text-center">
<carbon-document class="text-3xl text-green-400 mb-1" />
<code>-o yaml</code>
</div>
<!--
METADATA:
sentence: kubectl get pod nginx -o jsonpath='{.spec.containers[0].image}'
search_anchor: output format jsonpath
-->
<div v-click="6" class="text-center">
<carbon-filter class="text-3xl text-purple-400 mb-1" />
<code>-o jsonpath</code>
</div>
</div>

---
layout: center
---

# kubectl explain

<!--
METADATA:
sentence: On-demand API documentation:
search_anchor: On-demand API documentation
-->
<div v-click="1">

```mermaid
graph TB
    K[kubectl explain] --> R[On-demand API docs]
    R --> P[Pod specs]
    R --> D[Deployment configs]
    R --> S[Any resource]
    style K fill:#60a5fa
    style R fill:#4ade80
```

</div>

<!--
METADATA:
sentence: kubectl explain pod
search_anchor: kubectl explain commands
-->
<div v-click="2" class="mt-6">

```bash
kubectl explain pod
kubectl explain pod.spec
kubectl explain pod.spec.containers
kubectl explain deployment.spec.strategy
```

</div>

<div class="grid grid-cols-2 gap-6 mt-8 text-sm">
<!--
METADATA:
sentence: Shows field descriptions, types, and whether required.
search_anchor: field descriptions
-->
<div v-click="3">
<carbon-document class="text-4xl text-blue-400 mb-2" />
<strong>Field descriptions</strong><br/>
Types and requirements
</div>
<!--
METADATA:
sentence: Works offline.
search_anchor: Works offline
-->
<div v-click="4">
<carbon-offline class="text-4xl text-green-400 mb-2" />
<strong>Works offline</strong><br/>
No internet needed
</div>
</div>

<!--
METADATA:
sentence: Invaluable during exam when you forget exact syntax.
search_anchor: Invaluable during exam
-->
<div v-click="5" class="mt-6 text-center text-lg">
<carbon-idea class="inline-block text-2xl text-yellow-400" /> Invaluable when you forget syntax!
</div>

---
layout: center
---

# Imperative Commands

<!--
METADATA:
sentence: Generate resources without writing YAML:
search_anchor: Generate resources without writing YAML
-->
<div v-click="1" class="mb-4">

```bash
# Generate resources without YAML
kubectl run nginx --image=nginx
kubectl create deployment web --image=nginx --replicas=3
kubectl expose deployment web --port=80
kubectl create configmap app-config --from-literal=KEY=VALUE
kubectl create secret generic db-secret --from-literal=password=secret
```

</div>

<!--
METADATA:
sentence: With --dry-run for YAML:
search_anchor: With --dry-run for YAML
-->
<div v-click="2" class="mb-4">

```bash
# Generate YAML with --dry-run
kubectl run nginx --image=nginx --dry-run=client -o yaml > pod.yaml
kubectl create deployment web --image=nginx --replicas=3 \
  --dry-run=client -o yaml > deployment.yaml
```

</div>

<!--
METADATA:
sentence: Much faster than writing from scratch.
search_anchor: Much faster than writing from scratch
-->
<div v-click="3" class="text-center text-xl mt-8">
<carbon-flash class="inline-block text-3xl text-green-400" /> Much faster than writing from scratch!
</div>

---
layout: center
---

# Debugging Workflow

<!--
METADATA:
sentence: Systematic debugging:
search_anchor: Systematic debugging
-->
<div v-click="1">

```mermaid
graph TD
    S[1. Status] --> D[2. Details]
    D --> L[3. Logs]
    L --> E[4. Exec]
    E --> EV[5. Events]
    style S fill:#fbbf24
    style D fill:#60a5fa
    style L fill:#4ade80
    style E fill:#a78bfa
    style EV fill:#ef4444
```

</div>

<!--
METADATA:
sentence: 1. **Status**: `kubectl get pods`
search_anchor: debugging commands
-->
<div v-click="2" class="mt-6">

```bash
# 1. Status
kubectl get pods

# 2. Details
kubectl describe pod <name>

# 3. Logs
kubectl logs <name>

# 4. Exec
kubectl exec -it <name> -- sh

# 5. Events
kubectl get events --sort-by=.metadata.creationTimestamp
```

</div>

<!--
METADATA:
sentence: Most issues solved by describe (shows events). Memorize this workflow.
search_anchor: Most issues solved by describe
-->
<div v-click="3" class="mt-6 text-center text-lg">
<carbon-checkmark class="inline-block text-2xl text-blue-400" /> Most issues solved by describe!
</div>

---
layout: center
---

# Context and Namespace Management

<!--
METADATA:
sentence: Set namespace context:
search_anchor: Set namespace context
-->
<div v-click="1" class="mb-6">

```bash
# Set namespace context
kubectl config set-context --current --namespace=<namespace>
```

</div>

<!--
METADATA:
sentence: Switch contexts:
search_anchor: Switch contexts
-->
<div v-click="2" class="mb-6">

```bash
# Switch contexts
kubectl config use-context <context-name>
kubectl config get-contexts
```

</div>

<!--
METADATA:
sentence: Per-command namespace:
search_anchor: Per-command namespace
-->
<div v-click="3">

```bash
# Per-command namespace
kubectl get pods -n kube-system
kubectl get pods -A  # All namespaces
```

</div>

<!--
METADATA:
sentence: Set namespace context to avoid -n flags
search_anchor: Set namespace once
-->
<div v-click="4" class="mt-8 text-center">
<carbon-idea class="inline-block text-3xl text-yellow-400" />
<strong class="ml-2">Set namespace once, avoid -n flags!</strong>
</div>

---
layout: center
---

# Summary

<!--
METADATA:
sentence: Master these for CKAD success:
search_anchor: Master these for CKAD success
-->
<div v-click="1">

```mermaid
mindmap
  root((kubectl<br/>Mastery))
    Autocomplete
      Tab completion
      Save time
      Prevent errors
    Shortcuts
      Short names: po svc
      Aliases: k=kubectl
      Quick commands
    Output
      -o wide yaml json
      JSONPath
      Custom columns
    Tools
      kubectl explain
      --dry-run
      Imperative commands
    Workflow
      get describe logs
      exec port-forward
      Systematic approach
```

</div>

---
layout: center
---

# Key Takeaways

<div class="grid grid-cols-2 gap-6 mt-6">
<!--
METADATA:
sentence: Every second counts.
search_anchor: Speed is critical
-->
<div v-click="1">
<carbon-lightning class="text-4xl text-yellow-400 mb-2" />
<strong>Speed is critical</strong><br/>
<span class="text-sm opacity-80">Every second counts</span>
</div>
<!--
METADATA:
sentence: Autocomplete saves typing
search_anchor: Master shortcuts
-->
<div v-click="2">
<carbon-keyboard class="text-4xl text-blue-400 mb-2" />
<strong>Master shortcuts</strong><br/>
<span class="text-sm opacity-80">Aliases, short names, Tab</span>
</div>
<!--
METADATA:
sentence: kubectl explain for on-demand docs
search_anchor: kubectl explain for on-demand docs
-->
<div v-click="3">
<carbon-document class="text-4xl text-green-400 mb-2" />
<strong>kubectl explain</strong><br/>
<span class="text-sm opacity-80">On-demand documentation</span>
</div>
<!--
METADATA:
sentence: Systematic debugging: get → describe → logs → exec
search_anchor: Systematic debugging
-->
<div v-click="4">
<carbon-debug class="text-4xl text-purple-400 mb-2" />
<strong>Systematic debugging</strong><br/>
<span class="text-sm opacity-80">Follow consistent workflow</span>
</div>
</div>

<!--
METADATA:
sentence: Practice until commands are muscle memory.
search_anchor: Practice until commands are muscle memory
-->
<div v-click="5" class="mt-8 text-center text-xl">
<carbon-certificate class="inline-block text-3xl text-green-400" /> Practice makes perfect! <carbon-arrow-right class="inline-block text-2xl" />
</div>
