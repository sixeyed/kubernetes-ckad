# NetworkPolicy for CKAD

This document extends the [basic networkpolicy lab](README.md) with CKAD exam-specific scenarios and requirements.

## CKAD Exam Context

NetworkPolicy is a critical CKAD topic. You need to:
- Understand ingress and egress traffic control
- Use pod selectors and namespace selectors
- Configure port-based restrictions
- Apply CIDR-based rules
- Implement default deny policies
- Debug network connectivity issues

**Exam Tip:** NetworkPolicy is **additive** - multiple policies combine to allow traffic. Start with no access, then add what you need. Always test connectivity after applying policies.

**Important:** Not all Kubernetes clusters enforce NetworkPolicy. The exam environment should support it, but local dev clusters may not (Docker Desktop doesn't, Calico/Cilium do).

## API specs

- [NetworkPolicy (networking.k8s.io/v1)](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.20/#networkpolicy-v1-networking-k8s-io)
- [NetworkPolicy concepts](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

## NetworkPolicy Basics

NetworkPolicies work at the Pod level (not Service level):
- Select Pods using label selectors
- Define ingress (incoming) and/or egress (outgoing) rules
- Rules are **allow-lists** (whitelist model)
- Multiple policies are **additive** (union of all rules)
- Without any policy, all traffic is allowed

### Basic Structure

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: my-policy
  namespace: default
spec:
  podSelector:        # Which Pods this policy applies to
    matchLabels:
      app: myapp
  policyTypes:        # Which traffic directions to control
  - Ingress
  - Egress
  ingress:           # Rules for incoming traffic
  - from:
    - podSelector:
        matchLabels:
          role: frontend
    ports:
    - protocol: TCP
      port: 80
  egress:            # Rules for outgoing traffic
  - to:
    - podSelector:
        matchLabels:
          role: backend
    ports:
    - protocol: TCP
      port: 3306
```

## Imperative vs Declarative

**Important:** NetworkPolicy has **no imperative create command**. You must write YAML.

```
# Generate template (requires YAML editing)
kubectl create networkpolicy my-policy --dry-run=client -o yaml > netpol.yaml

# Apply NetworkPolicy
kubectl apply -f netpol.yaml

# Get NetworkPolicies
kubectl get networkpolicies
kubectl get netpol  # shorthand

# Describe to see details
kubectl describe networkpolicy my-policy

# Delete
kubectl delete networkpolicy my-policy
```

## Default Deny Policies

Best practice: Start with default deny, then explicitly allow required traffic.

### Deny All Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}  # Empty selector = applies to all Pods
  policyTypes:
  - Ingress
  # No ingress rules = deny all incoming traffic
```

### Deny All Egress

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-egress
spec:
  podSelector: {}
  policyTypes:
  - Egress
  # No egress rules = deny all outgoing traffic
```

### Deny All Ingress and Egress

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

📋 Create a default deny-all policy in your namespace, deploy two nginx pods, and verify they cannot communicate.

<details>
  <summary>Solution</summary>

```
# Create deny-all policy
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

# Deploy test pods
kubectl run pod1 --image=nginx
kubectl run pod2 --image=busybox --command -- sleep 3600

# Wait for pods to be ready (they won't be fully ready due to network policy)
kubectl get pods

# Try to communicate (this will fail)
kubectl exec pod2 -- wget -O- --timeout=2 http://pod1
# Should timeout or fail

# Check network policy
kubectl describe networkpolicy default-deny-all
```

</details><br />

## Ingress Rules (Incoming Traffic)

Ingress rules control traffic **to** Pods selected by `podSelector`.

### Allow from Specific Pods

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-frontend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
```

This allows traffic **to** `app=backend` pods **from** `app=frontend` pods.

### Allow from Specific Namespaces

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-namespace
spec:
  podSelector:
    matchLabels:
      app: api
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          team: platform
```

This allows traffic **to** `app=api` pods **from** any pod in namespaces labeled `team=platform`.

### Allow from Specific Pods in Specific Namespaces

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-pod-in-namespace
spec:
  podSelector:
    matchLabels:
      app: database
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          env: production
      podSelector:
        matchLabels:
          app: backend
```

**Important:** When `namespaceSelector` and `podSelector` are in the **same** list item (same `-`), it's an **AND** condition - pods must match both.

### Allow from Pods OR Namespaces

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-multiple-sources
spec:
  podSelector:
    matchLabels:
      app: api
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: web
    - namespaceSelector:
        matchLabels:
          env: test
```

**Important:** Multiple items in the `from` list (multiple `-`) are **OR** conditions - traffic from either source is allowed.

### Allow from IP Blocks (CIDR)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-cidr
spec:
  podSelector:
    matchLabels:
      app: public-api
  ingress:
  - from:
    - ipBlock:
        cidr: 192.168.1.0/24
        except:
        - 192.168.1.5/32
```

This allows traffic from `192.168.1.0/24` except from `192.168.1.5`.

### Allow on Specific Ports

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-http-https
spec:
  podSelector:
    matchLabels:
      app: web
  ingress:
  - from:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
```

This allows traffic to ports 80 and 443 only.

📋 Create a NetworkPolicy that allows ingress to `app=api` pods on port 8080 from `app=web` pods only.

<details>
  <summary>Solution</summary>

```
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-allow-from-web
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: web
    ports:
    - protocol: TCP
      port: 8080
EOF

kubectl describe netpol api-allow-from-web
```

</details><br />

## Egress Rules (Outgoing Traffic)

Egress rules control traffic **from** Pods selected by `podSelector`.

### Allow to Specific Pods

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-to-backend
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: backend
```

### Allow DNS (Critical for Most Apps)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
spec:
  podSelector:
    matchLabels:
      app: myapp
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
```

**Important:** Most applications need DNS. If you have egress policies, you typically need to allow DNS explicitly.

### Allow to External IPs

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-external-api
spec:
  podSelector:
    matchLabels:
      app: web
  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 169.254.169.254/32  # Block cloud metadata service
    ports:
    - protocol: TCP
      port: 443
```

### Combined Egress Rules

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-egress
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
  - Egress
  egress:
  # Allow DNS
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
  # Allow to backend on port 8080
  - to:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 8080
  # Allow HTTPS to internet
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
    ports:
    - protocol: TCP
      port: 443
```

📋 Create a NetworkPolicy for `app=frontend` pods that allows egress to `app=api` pods on port 8080 and allows DNS.

<details>
  <summary>Solution</summary>

```
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-egress
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
  - Egress
  egress:
  # Allow DNS
  - to:
    - namespaceSelector: {}
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
  # Allow to API
  - to:
    - podSelector:
        matchLabels:
          app: api
    ports:
    - protocol: TCP
      port: 8080
EOF
```

</details><br />

## Common CKAD Patterns

### Pattern 1: Three-Tier Application

Web tier → API tier → Database tier

```yaml
---
# Database: Allow ingress from API only
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-policy
spec:
  podSelector:
    matchLabels:
      tier: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: api
    ports:
    - protocol: TCP
      port: 3306
---
# API: Allow ingress from web, egress to db
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-policy
spec:
  podSelector:
    matchLabels:
      tier: api
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: web
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: database
    ports:
    - protocol: TCP
      port: 3306
---
# Web: Allow ingress from anywhere, egress to api
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-policy
spec:
  podSelector:
    matchLabels:
      tier: web
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector: {}  # Allow from any pod
    ports:
    - protocol: TCP
      port: 80
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: api
    ports:
    - protocol: TCP
      port: 8080
```

### Pattern 2: Namespace Isolation

Isolate namespaces from each other:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: namespace-isolation
  namespace: prod
spec:
  podSelector: {}  # All pods in this namespace
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}  # Only from pods in same namespace
```

### Pattern 3: Allow All Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-all-ingress
spec:
  podSelector:
    matchLabels:
      app: public
  policyTypes:
  - Ingress
  ingress:
  - {}  # Empty rule = allow all
```

### Pattern 4: Allow All Egress

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-all-egress
spec:
  podSelector:
    matchLabels:
      app: unrestricted
  policyTypes:
  - Egress
  egress:
  - {}  # Empty rule = allow all
```

## Testing NetworkPolicy

### Test Connectivity Between Pods

```bash
# Get pod IPs
kubectl get pods -o wide

# Test with wget (for HTTP)
kubectl exec pod1 -- wget -O- --timeout=2 http://pod2

# Test with curl
kubectl exec pod1 -- curl -m 2 http://pod2

# Test with nc (netcat) for any port
kubectl exec pod1 -- nc -zv pod2-ip 8080

# Test with ping (ICMP - often blocked by default)
kubectl exec pod1 -- ping -c 2 pod2-ip
```

### Test DNS Resolution

```bash
# Check if DNS works
kubectl exec pod1 -- nslookup kubernetes.default

# Check service DNS
kubectl exec pod1 -- nslookup my-service

# Check cross-namespace
kubectl exec pod1 -- nslookup my-service.other-namespace.svc.cluster.local
```

### Debug NetworkPolicy

```bash
# List all NetworkPolicies
kubectl get networkpolicies --all-namespaces

# Describe to see which pods are selected
kubectl describe networkpolicy my-policy

# Check pod labels
kubectl get pods --show-labels

# Check if pod is affected by any policy
kubectl get networkpolicies --all-namespaces -o yaml | grep -A 5 "podSelector"
```

## CKAD Exam Scenarios

### Scenario 1: Allow Web to API Communication

**Task:** You have `app=web` and `app=api` pods. Create a NetworkPolicy so web can access api on port 8080.

<details>
  <summary>Solution</summary>

```
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-allow-web
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: web
    ports:
    - protocol: TCP
      port: 8080
EOF
```

</details><br />

### Scenario 2: Namespace-Level Isolation

**Task:** Create a NetworkPolicy in the `prod` namespace that only allows traffic from pods within the same namespace.

<details>
  <summary>Solution</summary>

```
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: prod-isolation
  namespace: prod
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}
EOF
```

</details><br />

### Scenario 3: Allow Only Specific Namespaces

**Task:** Create a NetworkPolicy for `app=api` pods that allows ingress only from pods in namespaces labeled `env=prod`.

<details>
  <summary>Solution</summary>

```
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-allow-prod-namespace
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          env: prod
EOF
```

</details><br />

### Scenario 4: Database with Multiple Clients

**Task:** Create a NetworkPolicy for `app=database` pods that allows ingress on port 5432 from both `app=api` and `app=analytics` pods.

<details>
  <summary>Solution</summary>

```
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-allow-clients
spec:
  podSelector:
    matchLabels:
      app: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: api
    - podSelector:
        matchLabels:
          app: analytics
    ports:
    - protocol: TCP
      port: 5432
EOF
```

</details><br />

### Scenario 5: Egress with DNS

**Task:** Create a NetworkPolicy for `app=web` pods that allows egress to `app=api` on port 8080 and allows DNS queries.

<details>
  <summary>Solution</summary>

```
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-egress-policy
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
  - Egress
  egress:
  # DNS
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
  # API access
  - to:
    - podSelector:
        matchLabels:
          app: api
    ports:
    - protocol: TCP
      port: 8080
EOF
```

Note: DNS selector might vary by cluster. You may need:
```yaml
podSelector:
  matchLabels:
    k8s-app: kube-dns
```

</details><br />

## Advanced Topics

### Named Ports in NetworkPolicy

NetworkPolicy can reference ports by name (as defined in Pod spec) instead of numbers:

```yaml
# Pod with named port
apiVersion: v1
kind: Pod
metadata:
  name: web
  labels:
    app: web
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - name: http
      containerPort: 80
    - name: https
      containerPort: 443
---
# NetworkPolicy using named ports
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-allow-http
spec:
  podSelector:
    matchLabels:
      app: web
  ingress:
  - from:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: http  # References the named port
```

**Benefits:**
- More maintainable - change port number in one place
- Self-documenting - port names describe purpose
- Flexibility - different pods can use different port numbers for same service

**Important:** Named port must exist in the target Pod's container spec.

### Combining Multiple NetworkPolicies

NetworkPolicies are **additive** - multiple policies combine with OR logic:

```yaml
# Policy 1: Allow from frontend
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-frontend
spec:
  podSelector:
    matchLabels:
      app: api
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
---
# Policy 2: Allow from monitoring
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-monitoring
spec:
  podSelector:
    matchLabels:
      app: api
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: prometheus
```

**Result:** `app=api` pods accept traffic from **both** `app=frontend` AND `app=prometheus`.

**Key Points:**
- No precedence or priority - all matching policies apply
- Union of all rules - any policy allowing traffic permits it
- Cannot use one policy to deny what another allows
- Order doesn't matter - policies are evaluated together

**Pattern: Incremental Access**
```yaml
# 1. Start with deny-all
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
spec:
  podSelector: {}
  policyTypes:
  - Ingress
---
# 2. Add access as needed
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-web-to-api
spec:
  podSelector:
    matchLabels:
      app: api
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: web
```

### NetworkPolicy for StatefulSets

StatefulSets have stable network identities - use this for precise control:

```yaml
# StatefulSet (stable pod names: db-0, db-1, db-2)
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db
spec:
  serviceName: db
  replicas: 3
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
      - name: postgres
        image: postgres:13
        ports:
        - containerPort: 5432
---
# Headless Service for StatefulSet
apiVersion: v1
kind: Service
metadata:
  name: db
spec:
  clusterIP: None
  selector:
    app: database
  ports:
  - port: 5432
---
# NetworkPolicy for StatefulSet
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-policy
spec:
  podSelector:
    matchLabels:
      app: database
  policyTypes:
  - Ingress
  - Egress
  ingress:
  # Allow from application pods
  - from:
    - podSelector:
        matchLabels:
          app: api
    ports:
    - protocol: TCP
      port: 5432
  egress:
  # Allow DNS
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: UDP
      port: 53
  # Allow inter-pod communication for replication
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
```

**StatefulSet Considerations:**
- Pods need to communicate with each other (replication, clustering)
- Egress rules must allow pod-to-pod within the StatefulSet
- Each pod has stable DNS: `db-0.db.namespace.svc.cluster.local`
- NetworkPolicy applies to all replicas (uses same labels)

### Using endPort for Port Ranges (1.22+)

Kubernetes 1.22+ supports port ranges with `endPort`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-port-range
spec:
  podSelector:
    matchLabels:
      app: media-server
  ingress:
  - from:
    - podSelector: {}
    ports:
    # Allow RTP media ports 10000-20000
    - protocol: UDP
      port: 10000
      endPort: 20000
    # Single port can still be specified
    - protocol: TCP
      port: 8080
```

**Use Cases:**
- Media streaming (RTP/RTCP dynamic ports)
- FTP passive mode (dynamic data ports)
- Database clusters with port ranges
- Legacy applications with configurable port ranges

**Important:**
- Requires Kubernetes 1.22+ and CNI plugin support
- `port` is the start of range (inclusive)
- `endPort` is the end of range (inclusive)
- Both port and endPort must be specified

### NetworkPolicy Best Practices for Microservices

**1. Defense in Depth**
```yaml
# Start with deny-all
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

**2. Service-Specific Policies**
```yaml
# One policy per service
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: user-service-policy
spec:
  podSelector:
    matchLabels:
      service: user-api
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          service: api-gateway
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          service: user-database
    ports:
    - protocol: TCP
      port: 5432
```

**3. Always Allow DNS**
```yaml
# Include in every egress policy
egress:
- to:
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: kube-system
  ports:
  - protocol: UDP
    port: 53
  - protocol: TCP
    port: 53
```

**4. Monitoring and Observability**
```yaml
# Allow Prometheus scraping
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-prometheus
spec:
  podSelector:
    matchLabels:
      prometheus: scrape
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
      podSelector:
        matchLabels:
          app: prometheus
    ports:
    - protocol: TCP
      port: 9090
```

**5. Namespace Isolation**
```yaml
# Isolate production from development
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: namespace-isolation
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector: {}  # Same namespace only
  egress:
  - to:
    - podSelector: {}  # Same namespace only
  - to:  # Allow DNS
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
```

**6. Use Labels Consistently**
```yaml
# Standard label structure
metadata:
  labels:
    app: user-service        # Application name
    tier: backend           # Architecture tier
    version: v2             # Version (for canary)
    team: platform          # Owning team
```

### Performance Considerations

**Scale Challenges:**
- Each NetworkPolicy is processed by every node's CNI plugin
- Many policies increase CPU/memory on nodes
- Complex selectors are more expensive to evaluate

**Optimization Strategies:**

**1. Consolidate Policies**
```yaml
# Instead of multiple policies per pod
# BAD: 5 separate policies for same podSelector
---
# GOOD: One policy with all rules
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-all-rules
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: web
    - podSelector:
        matchLabels:
          app: mobile
    ports:
    - protocol: TCP
      port: 8080
  egress:
  # All egress rules here
```

**2. Use Namespace-Level Policies**
```yaml
# One policy for entire namespace instead of per-service
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: namespace-policy
spec:
  podSelector: {}  # All pods in namespace
  # Common rules for all services
```

**3. Avoid Overly Complex Selectors**
```yaml
# SLOW: Complex matchExpressions
podSelector:
  matchExpressions:
  - key: app
    operator: In
    values: [web, api, frontend, backend]
  - key: version
    operator: NotIn
    values: [v1, v2]

# FAST: Simple matchLabels
podSelector:
  matchLabels:
    tier: frontend
```

**4. Monitor NetworkPolicy Performance**
```bash
# Check node CPU/memory with many policies
kubectl top nodes

# Count policies per namespace
kubectl get netpol --all-namespaces | wc -l

# Review policy complexity
kubectl get netpol -o yaml | grep -E "podSelector|namespaceSelector"
```

**Performance Guidelines:**
- **< 100 policies**: No issues
- **100-500 policies**: Monitor node resources
- **> 500 policies**: Consider policy consolidation
- **Per-pod policies**: Consolidate where possible
- **Complex selectors**: Simplify if performance degrades

**Testing Impact:**
```bash
# Measure pod startup time before/after policies
time kubectl run test --image=nginx

# Check CNI plugin logs for errors
kubectl logs -n kube-system -l k8s-app=calico-node
```

## Common CKAD Pitfalls

1. **Forgetting DNS** - Egress policies often block DNS, causing "unknown host" errors
2. **Empty podSelector meaning** - `podSelector: {}` means ALL pods (not none)
3. **AND vs OR confusion** - Same list item = AND, different items = OR
4. **Policy not enforced** - Not all clusters support NetworkPolicy (check CNI)
5. **Service vs Pod** - NetworkPolicy works on Pods, not Services
6. **policyTypes required** - If you specify `policyTypes`, you must list what you want
7. **Namespace labels** - namespaceSelector needs namespace to have labels
8. **Bidirectional communication** - Allowing A→B doesn't allow B→A (need both policies)
9. **Port names** - Using named ports requires matching container port names
10. **CIDR for pod IPs** - Pod IPs change, use pod/namespace selectors instead

## NetworkPolicy Rules Reference

### podSelector Scope

```yaml
spec:
  podSelector: {}           # All pods in current namespace
  podSelector:              # Specific pods in current namespace
    matchLabels:
      app: web
```

### Ingress From

```yaml
ingress:
- from:
  - podSelector:           # Pods in same namespace
      matchLabels:
        app: web
  - namespaceSelector:     # OR: All pods in matching namespaces
      matchLabels:
        env: prod
  - ipBlock:               # OR: IP ranges
      cidr: 10.0.0.0/8
```

### Ingress From (AND condition)

```yaml
ingress:
- from:
  - namespaceSelector:     # Pods must match both
      matchLabels:
        env: prod
    podSelector:
      matchLabels:
        app: web
```

### Egress To

```yaml
egress:
- to:
  - podSelector:           # Same rules as ingress
      matchLabels:
        app: api
  ports:
  - protocol: TCP
    port: 8080
```

### Port Specifications

```yaml
ports:
- protocol: TCP            # TCP or UDP
  port: 80                 # Target port
- protocol: TCP
  port: 443
  endPort: 8443           # Port range (1.22+)
```

## Quick Reference Commands

```bash
# Get NetworkPolicies
kubectl get networkpolicy
kubectl get netpol
kubectl get netpol --all-namespaces

# Describe policy
kubectl describe networkpolicy my-policy

# Get policy YAML
kubectl get networkpolicy my-policy -o yaml

# Delete policy
kubectl delete networkpolicy my-policy

# Test connectivity
kubectl exec pod1 -- wget -O- --timeout=2 http://pod2
kubectl exec pod1 -- nc -zv pod2-ip port

# Check pod labels (for troubleshooting)
kubectl get pods --show-labels

# Check namespace labels
kubectl get namespaces --show-labels
```

## Practice Exercises

### Exercise 1: Complete Three-Tier App

Deploy a three-tier application (web, api, database) with:
- Default deny-all policy
- Web accepts traffic from anywhere on port 80
- Web can connect to API on port 8080
- API accepts traffic from web only
- API can connect to database on port 5432
- Database accepts traffic from API only
- All pods can access DNS

<details>
  <summary>Solution</summary>

**Step 1: Create the namespace and deploy the complete application**

```bash
# Apply the complete three-tier application with NetworkPolicies
kubectl apply -f labs/networkpolicy/specs/ckad/exercise1-three-tier.yaml

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod -l tier=web -n three-tier --timeout=60s
kubectl wait --for=condition=ready pod -l tier=api -n three-tier --timeout=60s
kubectl wait --for=condition=ready pod -l tier=database -n three-tier --timeout=60s
```

**Step 2: Verify the deployment**

```bash
# Check all resources are created
kubectl get all -n three-tier

# View all NetworkPolicies
kubectl get networkpolicies -n three-tier

# Check that we have:
# - default-deny-all (blocks everything)
# - web-ingress and web-egress
# - api-ingress and api-egress
# - database-ingress and database-egress
```

**Step 3: Test network connectivity**

```bash
# Get pod names
WEB_POD=$(kubectl get pod -n three-tier -l tier=web -o jsonpath='{.items[0].metadata.name}')
API_POD=$(kubectl get pod -n three-tier -l tier=api -o jsonpath='{.items[0].metadata.name}')
DB_POD=$(kubectl get pod -n three-tier -l tier=database -o jsonpath='{.items[0].metadata.name}')

echo "Web Pod: $WEB_POD"
echo "API Pod: $API_POD"
echo "DB Pod: $DB_POD"

# Test 1: Web can reach API (should work)
kubectl exec -n three-tier $WEB_POD -- wget -O- --timeout=2 http://api:8080 2>/dev/null | head -5
# Expected: Response from API service

# Test 2: API can reach Database (should work)
kubectl exec -n three-tier $API_POD -- nc -zv database 5432 2>&1
# Expected: database (10.x.x.x:5432) open

# Test 3: Web cannot reach Database directly (should fail)
kubectl exec -n three-tier $WEB_POD -- nc -zv database 5432 2>&1
# Expected: timeout or connection refused

# Test 4: Verify DNS works from all tiers
kubectl exec -n three-tier $WEB_POD -- nslookup api
kubectl exec -n three-tier $API_POD -- nslookup database
kubectl exec -n three-tier $DB_POD -- nslookup kubernetes.default
# All should resolve successfully
```

**Step 4: Examine NetworkPolicy details**

```bash
# View default deny policy
kubectl describe networkpolicy default-deny-all -n three-tier

# View web tier policies
kubectl describe networkpolicy web-ingress -n three-tier
kubectl describe networkpolicy web-egress -n three-tier

# View API tier policies
kubectl describe networkpolicy api-ingress -n three-tier
kubectl describe networkpolicy api-egress -n three-tier

# View database tier policies
kubectl describe networkpolicy database-ingress -n three-tier
kubectl describe networkpolicy database-egress -n three-tier
```

**Step 5: Test security boundaries**

```bash
# Create a test pod outside the three-tier namespace
kubectl run test-external --image=busybox --command -- sleep 3600

# Try to access services from external pod (should all fail)
kubectl exec test-external -- wget -O- --timeout=2 http://web.three-tier 2>&1
kubectl exec test-external -- nc -zv api.three-tier 8080 2>&1
kubectl exec test-external -- nc -zv database.three-tier 5432 2>&1
# All should timeout - default deny policy blocks external access

# Clean up test pod
kubectl delete pod test-external
```

**Understanding the Architecture:**

This exercise demonstrates **defense in depth** with NetworkPolicy:

1. **Default Deny**: Start with zero trust - all traffic blocked
2. **Least Privilege**: Each tier only allows necessary communication
3. **Layer Isolation**: Web → API → Database (no bypass)
4. **DNS Required**: All egress policies include DNS for service discovery

**Key NetworkPolicy Patterns Used:**

```yaml
# Pattern 1: Default Deny All
spec:
  podSelector: {}  # Applies to all pods
  policyTypes:
  - Ingress
  - Egress
  # No rules = deny all

# Pattern 2: Selective Ingress
spec:
  podSelector:
    matchLabels:
      tier: api
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: web  # Only web tier can connect

# Pattern 3: DNS + Specific Egress
egress:
- to:  # DNS
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: kube-system
  ports:
  - protocol: UDP
    port: 53
- to:  # Specific service
  - podSelector:
      matchLabels:
        tier: database
  ports:
  - protocol: TCP
    port: 5432
```

**Cleanup:**

```bash
# Delete the entire namespace and all resources
kubectl delete namespace three-tier
```

</details><br />

### Exercise 2: Cross-Namespace Communication

- Create two namespaces: `frontend` and `backend`
- Label `backend` namespace with `tier=backend`
- Deploy app in `frontend`, api in `backend`
- Create NetworkPolicy allowing frontend app to access backend api
- Verify communication works cross-namespace

<details>
  <summary>Solution</summary>

**Step 1: Deploy the complete cross-namespace application**

```bash
# Apply all resources (namespaces, deployments, services, and policies)
kubectl apply -f labs/networkpolicy/specs/ckad/exercise2-cross-namespace.yaml

# Wait for pods to be ready in both namespaces
kubectl wait --for=condition=ready pod -l app=webapp -n frontend --timeout=60s
kubectl wait --for=condition=ready pod -l app=api -n backend --timeout=60s
```

**Step 2: Verify the namespaces and labels**

```bash
# Check namespaces were created with correct labels
kubectl get namespaces frontend backend --show-labels

# Expected output should show:
# frontend   tier=frontend,env=demo
# backend    tier=backend,env=demo

# View resources in frontend namespace
kubectl get all -n frontend

# View resources in backend namespace
kubectl get all -n backend
```

**Step 3: Examine the NetworkPolicies**

```bash
# View NetworkPolicy in backend namespace
kubectl get networkpolicies -n backend
kubectl describe networkpolicy api-allow-from-frontend-ns -n backend

# This policy allows ingress to app=api from any pod in namespaces labeled tier=frontend

# View NetworkPolicy in frontend namespace
kubectl get networkpolicies -n frontend
kubectl describe networkpolicy webapp-egress-to-backend -n frontend

# This policy allows egress from app=webapp to app=api in namespaces labeled tier=backend
```

**Step 4: Test cross-namespace communication**

```bash
# Get pod names
FRONTEND_POD=$(kubectl get pod -n frontend -l app=webapp -o jsonpath='{.items[0].metadata.name}')
BACKEND_POD=$(kubectl get pod -n backend -l app=api -o jsonpath='{.items[0].metadata.name}')

echo "Frontend Pod: $FRONTEND_POD"
echo "Backend Pod: $BACKEND_POD"

# Test 1: Frontend can reach backend API (should work)
kubectl exec -n frontend $FRONTEND_POD -- wget -O- --timeout=2 http://api.backend:8080 2>/dev/null | head -5
# Expected: Response from API service

# Test 2: Frontend can resolve backend service DNS (should work)
kubectl exec -n frontend $FRONTEND_POD -- nslookup api.backend
# Expected: Successful DNS resolution

# Test 3: Verify the API pod is accessible
kubectl exec -n backend $BACKEND_POD -- wget -O- http://localhost:8080 2>/dev/null | head -5
# Expected: Response from local API
```

**Step 5: Test namespace isolation**

```bash
# Create a test namespace without the required label
kubectl create namespace test-ns

# Deploy a test pod in the unlabeled namespace
kubectl run test-pod -n test-ns --image=busybox --command -- sleep 3600

# Try to access backend API from unlabeled namespace (should fail)
kubectl exec -n test-ns test-pod -- wget -O- --timeout=2 http://api.backend:8080 2>&1
# Expected: timeout - no NetworkPolicy allows this traffic

# Label the test namespace
kubectl label namespace test-ns tier=frontend

# Now try again (should work because namespace has tier=frontend label)
kubectl exec -n test-ns test-pod -- wget -O- --timeout=2 http://api.backend:8080 2>/dev/null | head -5
# Expected: Success - namespace selector now matches

# Clean up test resources
kubectl delete pod test-pod -n test-ns
kubectl delete namespace test-ns
```

**Step 6: Understanding namespace selectors**

```bash
# View the alternative policy that uses both namespace and pod selectors
kubectl get networkpolicy api-allow-from-frontend-app -n backend -o yaml

# This shows the AND condition:
# - namespaceSelector matches tier=frontend
# - podSelector matches app=webapp
# Both must be true for traffic to be allowed
```

**Understanding Cross-Namespace NetworkPolicy:**

This exercise demonstrates **namespace-based access control**:

1. **Namespace Labels**: Namespaces must be labeled for selection
2. **Namespace Selector**: Allows traffic from matching namespaces
3. **Combined Selectors**: AND vs OR logic for precise control
4. **DNS Service Discovery**: Cross-namespace service names (`service.namespace`)

**Key Patterns:**

```yaml
# Pattern 1: Allow from any pod in labeled namespace (OR)
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        tier: frontend  # Any pod in tier=frontend namespaces

# Pattern 2: Allow from specific pods in labeled namespace (AND)
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        tier: frontend
    podSelector:  # Same list item = AND
      matchLabels:
        app: webapp  # Must be webapp pod AND in tier=frontend namespace

# Pattern 3: Egress to specific namespace
egress:
- to:
  - namespaceSelector:
      matchLabels:
        tier: backend
    podSelector:
      matchLabels:
        app: api
```

**Common Pitfalls:**

1. **Forgetting to label namespaces**: `namespaceSelector` requires namespace labels
2. **AND vs OR confusion**: Same list item = AND, separate items = OR
3. **DNS requirements**: Egress policies must allow DNS for service discovery
4. **Service naming**: Cross-namespace: `service.namespace.svc.cluster.local`

**Step 7: Experiment with different configurations**

```bash
# Remove the namespace label and test
kubectl label namespace frontend tier-
# Communication should fail now

# Re-add the label
kubectl label namespace frontend tier=frontend
# Communication should work again

# Try the more restrictive policy
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-allow-from-frontend-app
  namespace: backend
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          tier: frontend
      podSelector:
        matchLabels:
          app: webapp
    ports:
    - protocol: TCP
      port: 8080
EOF

# This is more restrictive - only webapp pods (not all pods) in frontend namespace
```

**Cleanup:**

```bash
# Delete both namespaces and all resources
kubectl delete namespace frontend backend
```

**Real-World Use Cases:**

1. **Multi-tenant clusters**: Isolate different teams/environments
2. **Microservices**: Frontend tier accessing backend services
3. **Shared services**: Allow specific namespaces to access shared databases
4. **Platform services**: Monitoring namespace accessing application namespaces

</details><br />

### Exercise 3: Egress Restriction

Create a policy that:
- Applies to `app=restricted` pods
- Allows egress to internal services only (10.0.0.0/8)
- Blocks all external traffic
- Allows DNS

<details>
  <summary>Solution</summary>

**Step 1: Deploy the egress restriction demo**

```bash
# Apply all resources (namespace, pods, services, and policies)
kubectl apply -f labs/networkpolicy/specs/ckad/exercise3-egress-restriction.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=internal-api -n restricted-egress --timeout=60s
kubectl wait --for=condition=ready pod -l app=restricted -n restricted-egress --timeout=60s
kubectl wait --for=condition=ready pod unrestricted-pod -n restricted-egress --timeout=30s
```

**Step 2: Verify the deployment**

```bash
# Check all resources in the namespace
kubectl get all -n restricted-egress

# View the NetworkPolicies
kubectl get networkpolicies -n restricted-egress

# Describe the main egress policy
kubectl describe networkpolicy restricted-egress-policy -n restricted-egress
```

**Step 3: Test internal service access (should work)**

```bash
# Get pod names
RESTRICTED_POD=$(kubectl get pod -n restricted-egress -l app=restricted -o jsonpath='{.items[0].metadata.name}')
UNRESTRICTED_POD=unrestricted-pod

echo "Restricted Pod: $RESTRICTED_POD"
echo "Unrestricted Pod: $UNRESTRICTED_POD"

# Test 1: Restricted pod can access internal service (should work)
kubectl exec -n restricted-egress $RESTRICTED_POD -- curl -m 2 http://internal-api:8080 2>/dev/null | head -5
# Expected: Success - internal service is in 10.0.0.0/8 range

# Test 2: Restricted pod can resolve DNS (should work)
kubectl exec -n restricted-egress $RESTRICTED_POD -- nslookup internal-api
# Expected: Successful DNS resolution

# Test 3: Restricted pod can resolve kubernetes service
kubectl exec -n restricted-egress $RESTRICTED_POD -- nslookup kubernetes.default
# Expected: Success - DNS is allowed
```

**Step 4: Test external access is blocked (should fail)**

```bash
# Test 1: Restricted pod cannot access external sites (should timeout)
kubectl exec -n restricted-egress $RESTRICTED_POD -- curl -m 2 https://www.google.com 2>&1
# Expected: timeout - external traffic blocked

# Test 2: Restricted pod cannot access external IP
kubectl exec -n restricted-egress $RESTRICTED_POD -- curl -m 2 http://8.8.8.8 2>&1
# Expected: timeout - not in 10.0.0.0/8 range

# Test 3: Compare with unrestricted pod (should work)
kubectl exec -n restricted-egress $UNRESTRICTED_POD -- curl -m 2 https://www.google.com 2>/dev/null | head -10
# Expected: Success - unrestricted pod has no egress policy
```

**Step 5: Understand the CIDR-based egress rules**

```bash
# View the NetworkPolicy YAML
kubectl get networkpolicy restricted-egress-policy -n restricted-egress -o yaml

# Key sections to observe:
# 1. DNS egress rule (to kube-system namespace)
# 2. CIDR-based egress rule (10.0.0.0/8)
# 3. No rule for external traffic (0.0.0.0/0)
```

**Step 6: Test with cluster IP ranges**

```bash
# Get the service cluster IP
INTERNAL_API_IP=$(kubectl get service internal-api -n restricted-egress -o jsonpath='{.spec.clusterIP}')
echo "Internal API Service IP: $INTERNAL_API_IP"

# Verify it's in the 10.0.0.0/8 range
# Kubernetes typically uses 10.x.x.x for service IPs

# Test direct IP access
kubectl exec -n restricted-egress $RESTRICTED_POD -- curl -m 2 http://$INTERNAL_API_IP:8080 2>/dev/null | head -5
# Expected: Success - IP is in allowed CIDR range

# Get pod IP
INTERNAL_API_POD_IP=$(kubectl get pod -n restricted-egress -l app=internal-api -o jsonpath='{.items[0].status.podIP}')
echo "Internal API Pod IP: $INTERNAL_API_POD_IP"

# Test pod IP access
kubectl exec -n restricted-egress $RESTRICTED_POD -- curl -m 2 http://$INTERNAL_API_POD_IP:8080 2>/dev/null | head -5
# Expected: Success if pod IP is in 10.0.0.0/8
```

**Step 7: Examine alternative configurations**

```bash
# View the multi-CIDR policy
kubectl get networkpolicy restricted-egress-multi-cidr -n restricted-egress -o yaml

# This shows how to allow multiple internal networks:
# - 10.0.0.0/8
# - 172.16.0.0/12
# - 192.168.0.0/16

# View the service-only policy
kubectl get networkpolicy restricted-egress-services-only -n restricted-egress -o yaml

# This is the most restrictive - only allows specific labeled services
```

**Step 8: Test the service-only approach**

```bash
# Create a test pod with the v3 label
kubectl run test-restricted-v3 -n restricted-egress --image=curlimages/curl:latest \
  --labels=app=restricted-v3 --command -- sleep 3600

# Wait for it to be ready
kubectl wait --for=condition=ready pod test-restricted-v3 -n restricted-egress --timeout=30s

# Test: Can access labeled internal service (should work)
kubectl exec -n restricted-egress test-restricted-v3 -- curl -m 2 http://internal-api:8080 2>/dev/null | head -5
# Expected: Success - policy allows to app=internal-api

# Test: Cannot access external (should fail)
kubectl exec -n restricted-egress test-restricted-v3 -- curl -m 2 https://www.google.com 2>&1
# Expected: timeout

# Clean up test pod
kubectl delete pod test-restricted-v3 -n restricted-egress
```

**Understanding Egress Restrictions:**

This exercise demonstrates **outbound traffic control**:

1. **Default Deny**: Without egress rules, pods can access anything
2. **CIDR Restrictions**: Limit to specific IP ranges (internal networks)
3. **DNS Requirement**: Always include DNS or services won't resolve
4. **Selector-Based**: More maintainable than IP-based rules

**Key NetworkPolicy Patterns:**

```yaml
# Pattern 1: CIDR-based egress (allows IP ranges)
egress:
- to:
  - ipBlock:
      cidr: 10.0.0.0/8  # Internal cluster network
      except:
      - 10.0.0.1/32     # Block specific IPs (e.g., metadata service)

# Pattern 2: Multiple internal networks
egress:
- to:
  - ipBlock:
      cidr: 10.0.0.0/8
- to:
  - ipBlock:
      cidr: 172.16.0.0/12
- to:
  - ipBlock:
      cidr: 192.168.0.0/16

# Pattern 3: Service-based (most maintainable)
egress:
- to:
  - podSelector:
      matchLabels:
        app: database
    ports:
    - protocol: TCP
      port: 5432
```

**Common Use Cases:**

1. **Security Compliance**: Prevent data exfiltration to external services
2. **Cost Control**: Block unnecessary external API calls
3. **Air-Gapped Networks**: Completely isolated environments
4. **Regulated Industries**: Restrict to approved internal services

**Troubleshooting Egress Issues:**

```bash
# Check if DNS is working
kubectl exec -n restricted-egress $RESTRICTED_POD -- nslookup kubernetes.default
# If this fails, DNS egress rule is missing or incorrect

# Check cluster IP ranges
kubectl cluster-info dump | grep -m 1 service-cluster-ip-range
# Ensure your CIDR blocks match cluster configuration

# Check pod network CIDR
kubectl cluster-info dump | grep -m 1 cluster-cidr
# Pod IPs must be in allowed CIDR for pod-to-pod communication

# Test with netcat to specific IPs
kubectl exec -n restricted-egress $RESTRICTED_POD -- nc -zv 10.96.0.1 443
# Test connectivity to specific IPs in allowed range
```

**Best Practices for Egress Policies:**

1. **Start Restrictive**: Begin with deny-all, add what's needed
2. **Use Selectors**: Prefer pod/namespace selectors over CIDR
3. **Always Allow DNS**: Include DNS in every egress policy
4. **Document CIDR Ranges**: Clearly document why each range is allowed
5. **Test Thoroughly**: Verify both allowed and blocked traffic
6. **Monitor**: Watch for failed connections indicating missing rules

**Advanced: Blocking Cloud Metadata Services**

```yaml
# Common pattern to block cloud provider metadata APIs
egress:
- to:
  - ipBlock:
      cidr: 0.0.0.0/0
      except:
      - 169.254.169.254/32  # AWS/GCP metadata
      - 169.254.169.253/32  # Azure metadata
```

**Cleanup:**

```bash
# Delete the namespace and all resources
kubectl delete namespace restricted-egress
```

**CKAD Exam Tips for Egress:**

1. **CIDR Notation**: Know common ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)
2. **DNS is Critical**: Without DNS, service names won't resolve
3. **ipBlock vs Selectors**: Use ipBlock for external IPs, selectors for pods
4. **Testing**: Always verify both allowed and denied traffic
5. **Multiple Rules**: Each egress item is OR'd together

</details><br />

## Cleanup

```bash
# Delete specific NetworkPolicy
kubectl delete networkpolicy my-policy

# Delete all NetworkPolicies in namespace
kubectl delete networkpolicy --all

# Delete by label
kubectl delete networkpolicy -l app=myapp

# Delete in specific namespace
kubectl delete networkpolicy --all -n production
```

## Next Steps

After mastering NetworkPolicy for CKAD:
1. Practice [Namespaces](../namespaces/) - Often combined with NetworkPolicy
2. Study [Services](../services/) - Understanding pod-to-service communication
3. Review [RBAC](../rbac/) - Access control complement to network control
4. Explore [Ingress](../ingress/) - External access patterns

---

## Study Checklist for CKAD

- [ ] Understand NetworkPolicy structure (podSelector, policyTypes, ingress, egress)
- [ ] Create default deny policies (ingress, egress, both)
- [ ] Write ingress rules with podSelector
- [ ] Write ingress rules with namespaceSelector
- [ ] Combine pod and namespace selectors (AND vs OR)
- [ ] Use ipBlock for CIDR-based rules
- [ ] Write egress rules for outbound traffic
- [ ] Always include DNS in egress policies
- [ ] Configure port-specific rules
- [ ] Understand policy additivity (multiple policies combine)
- [ ] Test connectivity with wget/curl/nc
- [ ] Debug policies with describe and labels
- [ ] Create namespace isolation policies
- [ ] Implement multi-tier application network security
- [ ] Recognize when NetworkPolicy is not enforced (CNI support)
