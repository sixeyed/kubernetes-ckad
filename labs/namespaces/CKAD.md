# Namespaces for CKAD

This document extends the [basic namespaces lab](README.md) with CKAD exam-specific scenarios and requirements.

## CKAD Exam Context

In the CKAD exam, you'll frequently work with namespaces to:
- Isolate exam tasks from each other
- Demonstrate understanding of resource scoping
- Work with resource quotas and limits
- Manage cross-namespace communication

**Exam Tip:** Always verify which namespace you're working in before running commands. Use `kubectl config set-context --current --namespace <name>` or the `-n` flag consistently.

## API specs

- [Namespace](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.20/#namespace-v1-core)
- [ResourceQuota](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.20/#resourcequota-v1-core)
- [LimitRange](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.20/#limitrange-v1-core)

## Imperative Namespace Management

The CKAD exam rewards speed, so you should be comfortable with imperative commands:

```
# Create a namespace imperatively
kubectl create namespace ckad-practice

# Create with a specific manifest
kubectl create namespace dev --dry-run=client -o yaml > namespace.yaml

# Set as default for current context
kubectl config set-context --current --namespace ckad-practice

# List all namespaces
kubectl get namespaces
kubectl get ns

# Describe a namespace to see resource quotas
kubectl describe ns ckad-practice

# Delete a namespace (WARNING: deletes all resources inside)
kubectl delete namespace ckad-practice
```

📋 Create a namespace called `exam-prep`, set it as your default, create a pod called `nginx` running `nginx:alpine`, then switch back to the `default` namespace.

<details>
  <summary>Solution</summary>

```
kubectl create namespace exam-prep
kubectl config set-context --current --namespace exam-prep
kubectl run nginx --image=nginx:alpine
kubectl get pods
kubectl config set-context --current --namespace default
```

</details><br />

## Resource Quotas in CKAD

Resource quotas limit the total resources that can be consumed in a namespace. This is a key CKAD topic.

### Understanding ResourceQuota

A ResourceQuota can limit:
- **Compute resources**: CPU, memory requests and limits
- **Object counts**: Pods, Services, ConfigMaps, Secrets, PVCs
- **Storage**: Total storage requests

Example quota spec:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: dev
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    pods: "10"
```

### CKAD Scenario: Applying Quotas

Create a namespace with quotas and test the limits:

```
# Create namespace
kubectl create namespace quota-test

# Create a quota (you'll need to write the YAML in exam)
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: mem-cpu-quota
  namespace: quota-test
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 2Gi
    limits.cpu: "4"
    limits.memory: 4Gi
    pods: "5"
EOF

# Check the quota
kubectl describe quota -n quota-test
```

**Important for CKAD**: When a namespace has a ResourceQuota for CPU or memory, **every** Pod must specify resource requests and limits, or it will be rejected.

Try creating a pod without resource limits:

```
kubectl -n quota-test run nginx --image=nginx

# This will fail - check the error
kubectl -n quota-test get pods
kubectl -n quota-test get events
```

📋 Create a Pod in the `quota-test` namespace with resource requests and limits that will be accepted.

<details>
  <summary>Solution</summary>

```
kubectl -n quota-test run nginx --image=nginx \
  --requests=cpu=100m,memory=128Mi \
  --limits=cpu=200m,memory=256Mi

# Or with YAML:
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  namespace: quota-test
spec:
  containers:
  - name: nginx
    image: nginx
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "200m"
        memory: "256Mi"
EOF

# Verify quota usage
kubectl describe quota mem-cpu-quota -n quota-test
```

</details><br />

## LimitRanges in CKAD

LimitRanges define default, minimum, and maximum resource constraints for containers and PVCs in a namespace. They're crucial for CKAD as they work alongside ResourceQuotas.

### LimitRange vs ResourceQuota

Key differences for CKAD:

| Feature | LimitRange | ResourceQuota |
|---------|-----------|---------------|
| **Scope** | Per Pod/Container | Total for namespace |
| **Purpose** | Set defaults and boundaries | Limit aggregate usage |
| **When applied** | Pod creation time | Accumulated across all resources |
| **Default values** | YES - can set defaults | NO - must be explicit |
| **Rejection** | Rejects individual pods | Rejects when total exceeded |

### Default Resource Limits

LimitRanges can automatically apply resource limits to containers that don't specify them:

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: demo
spec:
  limits:
  - default:           # Default limits (if not specified)
      cpu: 500m
      memory: 512Mi
    defaultRequest:    # Default requests (if not specified)
      cpu: 100m
      memory: 128Mi
    type: Container
```

**CKAD Exam Tip:** When a LimitRange with defaults exists, pods without resource specs will get these defaults automatically. This is different from ResourceQuota, which rejects pods without specs.

### Min/Max Constraints

LimitRanges can enforce boundaries:

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: min-max-limits
  namespace: demo
spec:
  limits:
  - max:
      cpu: "2"
      memory: 2Gi
    min:
      cpu: 50m
      memory: 64Mi
    type: Container
```

Test this behavior:

```
# Create namespace with LimitRange
kubectl create namespace limitrange-demo
kubectl apply -f labs/namespaces/specs/ckad/limitrange-examples.yaml

# Try to create pod exceeding max
kubectl -n limitrange-demo run too-big --image=nginx \
  --requests=cpu=3,memory=3Gi

# This will fail - exceeds max constraints
```

### LimitRange with Ratio Constraints

You can also enforce a maximum ratio between limits and requests:

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: ratio-limits
  namespace: demo
spec:
  limits:
  - maxLimitRequestRatio:
      cpu: "4"      # Limit can be max 4x the request
      memory: "2"   # Limit can be max 2x the request
    type: Container
```

This prevents users from setting very low requests but high limits, which could cause scheduling issues.

### CKAD Scenario: LimitRange with Defaults

📋 Create a namespace with a LimitRange that sets default CPU request to 100m, default CPU limit to 200m, default memory request to 128Mi, and default memory limit to 256Mi. Then create a pod without resource specifications and verify the defaults are applied.

<details>
  <summary>Solution</summary>

```
# Create namespace
kubectl create namespace defaults-test

# Create LimitRange
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: defaults
  namespace: defaults-test
spec:
  limits:
  - default:
      cpu: 200m
      memory: 256Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    type: Container
EOF

# Create pod without resource specs
kubectl -n defaults-test run nginx --image=nginx

# Check that defaults were applied
kubectl -n defaults-test get pod nginx -o yaml | grep -A 10 resources:

# You should see:
#   resources:
#     limits:
#       cpu: 200m
#       memory: 256Mi
#     requests:
#       cpu: 100m
#       memory: 128Mi
```

</details><br />

### LimitRange for Storage

LimitRanges can also constrain PersistentVolumeClaim sizes:

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: storage-limits
  namespace: demo
spec:
  limits:
  - max:
      storage: 10Gi
    min:
      storage: 1Gi
    type: PersistentVolumeClaim
```

**Important for CKAD:** When both ResourceQuota and LimitRange are present, pods must satisfy both. The LimitRange validates individual containers, while ResourceQuota tracks cumulative usage.

## ServiceAccounts and Namespaces

ServiceAccounts are namespace-scoped. Each namespace gets a `default` ServiceAccount automatically.

```
# List ServiceAccounts in a namespace
kubectl get serviceaccounts -n default
kubectl get sa -n default

# Create a ServiceAccount
kubectl create serviceaccount my-sa -n default

# Create a pod using a specific ServiceAccount
kubectl run pod-with-sa --image=nginx \
  --serviceaccount=my-sa \
  -n default
```

📋 Create a namespace `app-namespace`, create a ServiceAccount `app-sa` in it, and run a pod using that ServiceAccount.

<details>
  <summary>Solution</summary>

```
kubectl create namespace app-namespace
kubectl create serviceaccount app-sa -n app-namespace
kubectl run app-pod --image=nginx --serviceaccount=app-sa -n app-namespace

# Verify
kubectl describe pod app-pod -n app-namespace | grep -i serviceaccount
```

</details><br />

### ServiceAccount Tokens and Mounting

Every ServiceAccount automatically gets a token that can be used to authenticate to the Kubernetes API. Understanding this is important for CKAD.

**Default Behavior:**
- Each namespace has a `default` ServiceAccount
- Pods automatically use the `default` ServiceAccount unless specified
- Token is mounted at `/var/run/secrets/kubernetes.io/serviceaccount/`
- Token provides identity for API authentication

```
# Create a pod and check the mounted token
kubectl run test-pod --image=nginx
kubectl exec test-pod -- ls -la /var/run/secrets/kubernetes.io/serviceaccount/

# You'll see:
# - ca.crt      (CA certificate)
# - namespace   (current namespace)
# - token       (JWT token)
```

### Disabling Automatic Token Mounting

For security, you might want to disable automatic token mounting:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: no-token-pod
spec:
  serviceAccountName: my-sa
  automountServiceAccountToken: false  # Disable token mounting
  containers:
  - name: nginx
    image: nginx
```

You can also disable it at the ServiceAccount level:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: no-auto-mount-sa
automountServiceAccountToken: false
```

### Using ServiceAccounts with RBAC

ServiceAccounts are subjects in RBAC bindings. This is a key CKAD pattern for controlling pod permissions:

**Complete RBAC Example:**

```
# Create namespace
kubectl create namespace rbac-demo

# Create ServiceAccount
kubectl create serviceaccount pod-reader-sa -n rbac-demo

# Create Role with specific permissions
cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: rbac-demo
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get"]
EOF

# Bind Role to ServiceAccount
kubectl create rolebinding read-pods \
  --role=pod-reader \
  --serviceaccount=rbac-demo:pod-reader-sa \
  -n rbac-demo

# Create pod using the ServiceAccount
kubectl -n rbac-demo run test-pod --image=nginx \
  --serviceaccount=pod-reader-sa
```

### Testing ServiceAccount Permissions

You can test what a ServiceAccount can do:

```
# Check if ServiceAccount can list pods
kubectl auth can-i list pods \
  --as=system:serviceaccount:rbac-demo:pod-reader-sa \
  -n rbac-demo

# Check if ServiceAccount can delete pods (should be no)
kubectl auth can-i delete pods \
  --as=system:serviceaccount:rbac-demo:pod-reader-sa \
  -n rbac-demo
```

### ServiceAccount in Pod Spec

📋 Create a ServiceAccount with permissions to read ConfigMaps, then create a pod that uses this ServiceAccount and verify it can list ConfigMaps from within the pod.

<details>
  <summary>Solution</summary>

```
# Create namespace
kubectl create namespace sa-test

# Create ServiceAccount
kubectl create serviceaccount configmap-reader -n sa-test

# Create Role
cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: configmap-reader-role
  namespace: sa-test
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]
EOF

# Create RoleBinding
kubectl create rolebinding read-configmaps \
  --role=configmap-reader-role \
  --serviceaccount=sa-test:configmap-reader \
  -n sa-test

# Create a test ConfigMap
kubectl create configmap test-cm --from-literal=key=value -n sa-test

# Create pod with kubectl image to test
kubectl run kubectl-pod --image=bitnami/kubectl:latest \
  --serviceaccount=configmap-reader \
  -n sa-test \
  -- sleep 3600

# Test from inside the pod
kubectl -n sa-test exec kubectl-pod -- kubectl get configmaps

# This should succeed and show test-cm

# Try to list pods (should fail - no permission)
kubectl -n sa-test exec kubectl-pod -- kubectl get pods
```

</details><br />

**CKAD Exam Tip:** ServiceAccounts are commonly combined with RBAC to demonstrate understanding of pod-level permissions. Practice creating the full chain: ServiceAccount → Role → RoleBinding → Pod.

## Cross-Namespace Communication

This is critical for CKAD - understanding how pods in different namespaces communicate.

### Service DNS Patterns

Services are namespace-scoped. DNS follows this pattern:

```
<service-name>.<namespace>.svc.cluster.local
```

- **Short name** (`service-name`): Only works within the same namespace
- **Namespace-qualified** (`service-name.namespace`): Works across namespaces
- **FQDN** (`service-name.namespace.svc.cluster.local`): Full qualified name

### CKAD Scenario: Cross-Namespace Service Access

Let's create services in different namespaces and test connectivity:

```
# Create two namespaces
kubectl create namespace frontend
kubectl create namespace backend

# Deploy a backend service
kubectl -n backend run db --image=nginx --port=80
kubectl -n backend expose pod db --port=80

# Deploy a frontend pod with a test container
kubectl -n frontend run web --image=busybox --command -- sleep 3600
```

Test DNS resolution from the frontend namespace:

```
# This will fail - service is in different namespace
kubectl -n frontend exec web -- nslookup db

# This will work - namespace-qualified
kubectl -n frontend exec web -- nslookup db.backend

# This will work - FQDN
kubectl -n frontend exec web -- nslookup db.backend.svc.cluster.local

# Test actual connectivity
kubectl -n frontend exec web -- wget -qO- http://db.backend
```

📋 Create a ConfigMap in the `backend` namespace that contains the correct DNS name for the `db` service, then mount it in the `web` pod.

<details>
  <summary>Solution</summary>

```
# Create ConfigMap with service URL
kubectl -n backend create configmap db-config \
  --from-literal=DB_HOST=db.backend.svc.cluster.local

# You'd need to recreate the pod to mount the ConfigMap
# In the exam, you might need to write this YAML:
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: web
  namespace: frontend
spec:
  containers:
  - name: busybox
    image: busybox
    command: ["sleep", "3600"]
    env:
    - name: DB_HOST
      valueFrom:
        configMapKeyRef:
          name: db-config
          key: DB_HOST
EOF

# Note: This requires the ConfigMap to be in the same namespace
# For cross-namespace ConfigMap access, see solution notes
```

**Important**: ConfigMaps and Secrets are namespace-scoped and cannot be directly referenced across namespaces. You need to create them in the same namespace as the pod.

</details><br />

### Cross-Namespace ConfigMap/Secret Strategies

ConfigMaps and Secrets cannot be referenced directly across namespaces. Here are strategies for CKAD:

#### Strategy 1: Duplicate Resources

The simplest approach is to create the same ConfigMap/Secret in each namespace:

```
# Create the same secret in multiple namespaces
kubectl create secret generic shared-secret \
  --from-literal=api-key=12345 \
  -n frontend

kubectl create secret generic shared-secret \
  --from-literal=api-key=12345 \
  -n backend

kubectl create secret generic shared-secret \
  --from-literal=api-key=12345 \
  -n database
```

**Pros:** Simple, secure (namespace isolation maintained)
**Cons:** Harder to manage updates, duplication

#### Strategy 2: Use Service DNS Names in ConfigMaps

Store cross-namespace service URLs in ConfigMaps within each namespace:

```
# In frontend namespace
kubectl create configmap service-urls \
  --from-literal=BACKEND_URL=http://api.backend.svc.cluster.local \
  --from-literal=DB_URL=postgres://db.database.svc.cluster.local:5432 \
  -n frontend

# In backend namespace
kubectl create configmap service-urls \
  --from-literal=DB_URL=postgres://db.database.svc.cluster.local:5432 \
  -n backend
```

**CKAD Pattern:** This is the most common pattern in the exam. Each namespace has its own ConfigMap with FQDNs for cross-namespace services.

#### Strategy 3: External Configuration

For production (less common in CKAD), use external systems:
- External secret management (Vault, AWS Secrets Manager)
- ConfigMap/Secret replication operators
- GitOps with automated replication

### NetworkPolicy with Namespace Selectors

NetworkPolicies can control traffic between namespaces using namespace selectors. This is a key CKAD skill.

#### Basic Namespace Isolation

Allow traffic only from specific namespaces:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-frontend
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
          tier: frontend  # Only from namespaces with this label
    ports:
    - protocol: TCP
      port: 8080
```

**Important:** The namespace must have the label for this to work:

```
kubectl label namespace frontend tier=frontend
kubectl label namespace backend tier=backend
```

#### Three-Tier Application Isolation

Complete example for frontend → backend → database:

```
# Label namespaces
kubectl label namespace frontend-ns tier=frontend
kubectl label namespace backend-ns tier=backend
kubectl label namespace database-ns tier=database

# Apply NetworkPolicies
kubectl apply -f labs/namespaces/specs/ckad/networkpolicy-namespace-selectors.yaml

# Test connectivity
kubectl -n frontend-ns run test --image=busybox --rm -it -- \
  wget -qO- http://backend-svc.backend-ns

# This should work

# Try from wrong namespace
kubectl -n database-ns run test --image=busybox --rm -it -- \
  wget -qO- http://backend-svc.backend-ns

# This should timeout (blocked by NetworkPolicy)
```

#### Combining Pod and Namespace Selectors

You can combine both for fine-grained control:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend-api
  namespace: backend
spec:
  podSelector:
    matchLabels:
      app: api
      role: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          tier: frontend
      podSelector:
        matchLabels:
          app: web
    ports:
    - protocol: TCP
      port: 8080
```

This allows only pods labeled `app=web` in namespaces labeled `tier=frontend` to access pods labeled `app=api,role=backend` in the backend namespace.

### Best Practices for Multi-Namespace Applications

For CKAD exam success:

#### 1. Naming Conventions

Use consistent naming across namespaces:

```
# Service names
database → mysql, postgres, redis
backend  → api, api-service
frontend → web, web-service

# Makes DNS predictable:
# mysql.database.svc.cluster.local
# api.backend.svc.cluster.local
# web.frontend.svc.cluster.local
```

#### 2. Label Strategy

Apply consistent labels to namespaces and resources:

```yaml
# Namespace labels
tier: frontend | backend | database
env: dev | staging | prod
team: platform | product
```

#### 3. Resource Organization

Create resources in this order:
1. Namespaces with labels
2. ResourceQuotas and LimitRanges
3. ConfigMaps and Secrets
4. ServiceAccounts and RBAC
5. NetworkPolicies
6. Workloads (Deployments, Pods)
7. Services

#### 4. Service Discovery Pattern

Always use FQDN in cross-namespace communication:

```yaml
env:
- name: DATABASE_HOST
  value: "postgres.database.svc.cluster.local"
- name: DATABASE_PORT
  value: "5432"
- name: API_ENDPOINT
  value: "http://api.backend.svc.cluster.local:8080"
```

#### 5. Testing Cross-Namespace Communication

Quick test pattern for CKAD:

```
# Deploy test pod with network tools
kubectl -n frontend run test --image=busybox --rm -it -- sh

# Inside pod, test DNS resolution
nslookup api.backend.svc.cluster.local

# Test connectivity
wget -qO- http://api.backend.svc.cluster.local:8080/health

# Test from different namespace
kubectl -n backend run test --image=busybox --rm -it -- \
  wget -qO- http://db.database.svc.cluster.local:5432
```

📋 Create three namespaces (frontend, backend, database) with appropriate labels, deploy a pod in each, create services, and configure NetworkPolicies so that: frontend can reach backend, backend can reach database, but frontend cannot directly reach database.

<details>
  <summary>Solution</summary>

```
# Create and label namespaces
kubectl create namespace frontend
kubectl create namespace backend
kubectl create namespace database
kubectl label namespace frontend tier=frontend
kubectl label namespace backend tier=backend
kubectl label namespace database tier=database

# Deploy pods
kubectl -n frontend run web --image=nginx --port=80
kubectl -n backend run api --image=nginx --port=80
kubectl -n database run db --image=postgres:alpine --port=5432 \
  --env="POSTGRES_PASSWORD=example"

# Expose as services
kubectl -n frontend expose pod web --port=80
kubectl -n backend expose pod api --port=80
kubectl -n database expose pod db --port=5432

# Create NetworkPolicies
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-allow-frontend
  namespace: backend
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          tier: frontend
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-allow-backend
  namespace: database
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          tier: backend
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-default-deny
  namespace: database
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF

# Test: frontend → backend (should work)
kubectl -n frontend exec web -- curl -s http://api.backend

# Test: backend → database (should work)
kubectl -n backend exec api -- nc -zv db.database 5432

# Test: frontend → database (should fail/timeout)
kubectl -n frontend exec web -- nc -zv -w 5 db.database 5432
```

</details><br />

## Namespace-Scoped vs Cluster-Scoped Resources

Understanding resource scope is important for CKAD:

**Namespace-scoped resources:**
- Pods, Deployments, ReplicaSets, StatefulSets, DaemonSets
- Services, Endpoints
- ConfigMaps, Secrets
- ServiceAccounts
- PersistentVolumeClaims (PVCs)
- ResourceQuotas, LimitRanges
- NetworkPolicies
- Ingresses

**Cluster-scoped resources:**
- Nodes
- Namespaces themselves
- PersistentVolumes (PVs)
- StorageClasses
- ClusterRoles, ClusterRoleBindings
- CustomResourceDefinitions (CRDs)

```
# List all API resources with their scope
kubectl api-resources --namespaced=true
kubectl api-resources --namespaced=false

# Get cluster-scoped resources (no -n flag needed)
kubectl get nodes
kubectl get pv
kubectl get clusterroles
```

## CKAD Exam Patterns and Tips

### Common Exam Tasks

1. **Create namespace and set context**
   ```
   kubectl create ns exam-task-1
   kubectl config set-context --current --namespace exam-task-1
   ```

2. **Deploy application with quotas**
   - Create namespace
   - Apply ResourceQuota
   - Deploy pods with resource requests/limits
   - Verify quota usage

3. **Cross-namespace service discovery**
   - Deploy services in different namespaces
   - Configure pods to communicate using FQDN
   - Test connectivity

4. **Resource isolation**
   - Deploy similar apps in different namespaces
   - Apply different quotas/limits
   - Verify isolation

### Time-Saving Tips

1. **Use aliases**
   ```
   alias k=kubectl
   alias kn='kubectl config set-context --current --namespace'
   ```

2. **Always verify namespace before running commands**
   ```
   kubectl config view --minify | grep namespace
   ```

3. **Use `-n` flag vs changing context**
   - Changing context is safer but slower
   - Using `-n` is faster but requires discipline
   - In exam, use what you're comfortable with

4. **Imperative commands with --dry-run**
   ```
   # Generate YAML quickly
   kubectl create quota my-quota --hard=cpu=2,memory=2Gi \
     --namespace=test --dry-run=client -o yaml > quota.yaml
   ```

## Practice Exercises

### Exercise 1: Multi-Namespace Application

Deploy a three-tier application across namespaces:
- `database` namespace: MySQL pod and service
- `api` namespace: API pod that connects to database
- `web` namespace: Web frontend that connects to API

Requirements:
- Apply ResourceQuota to each namespace (cpu: 1, memory: 1Gi)
- All pods must have resource requests and limits
- Test cross-namespace communication
- Use ConfigMaps for service discovery

<details>
  <summary>Solution</summary>

**Step 1: Deploy the complete application**

```
# Apply all resources at once
kubectl apply -f labs/namespaces/specs/ckad/exercise-1-multi-namespace-app.yaml

# This creates:
# - 3 namespaces: database, api, web
# - ResourceQuotas in each namespace
# - MySQL pod and service in database namespace
# - API pod and service in api namespace
# - Web pod and service in web namespace
# - ConfigMaps and Secrets for configuration
```

**Step 2: Verify namespace creation and quotas**

```
# Check namespaces
kubectl get namespaces | grep -E "database|api|web"

# Verify quotas are applied
kubectl describe quota -n database
kubectl describe quota -n api
kubectl describe quota -n web

# Should show:
# - requests.cpu: 1
# - requests.memory: 1Gi
# - limits.cpu: 2
# - limits.memory: 2Gi
# - pods: 5
```

**Step 3: Verify pods are running with resources**

```
# Check all pods
kubectl get pods -n database
kubectl get pods -n api
kubectl get pods -n web

# Verify resource specifications
kubectl get pod mysql -n database -o yaml | grep -A 10 resources:
kubectl get pod api -n api -o yaml | grep -A 10 resources:
kubectl get pod web -n web -o yaml | grep -A 10 resources:

# Each should have requests and limits defined
```

**Step 4: Check ConfigMaps and Secrets**

```
# API namespace configuration
kubectl describe configmap db-config -n api
kubectl describe secret db-secret -n api

# Should show:
# DB_HOST: mysql.database.svc.cluster.local
# DB_PORT: 3306
# DB_NAME: appdb

# Web namespace configuration
kubectl describe configmap api-config -n web

# Should show:
# API_URL: http://api.api.svc.cluster.local
```

**Step 5: Test cross-namespace connectivity**

```
# Test database service DNS from API namespace
kubectl -n api run test --image=busybox --rm -it -- \
  nslookup mysql.database.svc.cluster.local

# Should resolve successfully

# Test API service DNS from web namespace
kubectl -n web run test --image=busybox --rm -it -- \
  nslookup api.api.svc.cluster.local

# Should resolve successfully

# Test actual connectivity from API to database
kubectl -n api exec api -- nc -zv mysql.database 3306

# Should connect successfully

# Test web to API connectivity
kubectl -n web exec web -- curl -s http://api.api
```

**Step 6: Verify environment variables**

```
# Check API pod has database configuration
kubectl -n api exec api -- env | grep DB_

# Should show:
# DB_HOST=mysql.database.svc.cluster.local
# DB_PORT=3306
# DB_NAME=appdb
# DB_USER=appuser
# DB_PASSWORD=apppassword

# Check web pod has API configuration
kubectl -n web exec web -- env | grep API_

# Should show:
# API_URL=http://api.api.svc.cluster.local
# API_PORT=80
```

**Step 7: Check quota usage**

```
# See how much of the quota is used
kubectl describe quota -n database
kubectl describe quota -n api
kubectl describe quota -n web

# Should show Used/Hard for each resource
# Example output:
# Resource          Used   Hard
# --------          ----   ----
# limits.cpu        500m   2
# limits.memory     512Mi  2Gi
# pods              1      5
# requests.cpu      250m   1
# requests.memory   256Mi  1Gi
```

**Step 8: Test quota enforcement**

```
# Try to exceed pod quota in database namespace
for i in {1..5}; do
  kubectl -n database run test-pod-$i --image=nginx \
    --requests=cpu=50m,memory=64Mi \
    --limits=cpu=100m,memory=128Mi
done

# After 4 pods (plus mysql = 5 total), the next should fail
kubectl get pods -n database

# Try to exceed memory quota
kubectl -n api run big-pod --image=nginx \
  --requests=cpu=100m,memory=900Mi \
  --limits=cpu=200m,memory=1800Mi

# This should fail - exceeds remaining quota
```

**Cleanup:**

```
kubectl delete namespace database api web
```

</details><br />

### Exercise 2: Quota Enforcement

Create a namespace `limited-resources` with the following constraints:
- Maximum 3 pods
- Maximum 2 CPU cores total
- Maximum 2Gi memory total
- Try to exceed limits and observe behavior

<details>
  <summary>Solution</summary>

**Step 1: Deploy the namespace with quota**

```
# Apply the exercise specs
kubectl apply -f labs/namespaces/specs/ckad/exercise-2-quota-enforcement.yaml

# Or create manually:
kubectl create namespace limited-resources

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: strict-quota
  namespace: limited-resources
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 2Gi
    limits.cpu: "4"
    limits.memory: 4Gi
    pods: "3"
    services: "2"
    configmaps: "5"
    secrets: "5"
EOF
```

**Step 2: Verify quota creation**

```
# Check the quota
kubectl describe quota strict-quota -n limited-resources

# Should show:
# Resource               Used  Hard
# --------               ----  ----
# limits.cpu             0     4
# limits.memory          0     4Gi
# pods                   0     3
# requests.cpu           0     2
# requests.memory        0     2Gi
# services               0     2
# configmaps             0     5
# secrets                0     5
```

**Step 3: Create first pod (should succeed)**

```
# Create pod-1 using 500m CPU and 512Mi memory
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pod-1
  namespace: limited-resources
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    resources:
      requests:
        cpu: "500m"
        memory: "512Mi"
      limits:
        cpu: "1000m"
        memory: "1Gi"
EOF

# Verify it's running
kubectl get pod pod-1 -n limited-resources

# Check quota usage
kubectl describe quota strict-quota -n limited-resources

# Should show:
# requests.cpu: 500m/2
# requests.memory: 512Mi/2Gi
# pods: 1/3
```

**Step 4: Create second pod (should succeed)**

```
# Create pod-2
kubectl -n limited-resources run pod-2 --image=nginx:alpine \
  --requests=cpu=500m,memory=512Mi \
  --limits=cpu=1000m,memory=1Gi

# Check quota usage
kubectl describe quota strict-quota -n limited-resources

# Should show:
# requests.cpu: 1/2
# requests.memory: 1Gi/2Gi
# pods: 2/3
```

**Step 5: Create third pod (should succeed, reaches limit)**

```
# Create pod-3 using remaining quota
kubectl -n limited-resources run pod-3 --image=busybox \
  --requests=cpu=200m,memory=256Mi \
  --limits=cpu=500m,memory=512Mi \
  -- sleep 3600

# Check quota usage
kubectl describe quota strict-quota -n limited-resources

# Should show:
# requests.cpu: 1.7/2
# requests.memory: 1.75Gi/2Gi (approximately)
# pods: 3/3
```

**Step 6: Try to create fourth pod (should FAIL - pod count exceeded)**

```
# Attempt to create pod-4
kubectl -n limited-resources run pod-4 --image=nginx \
  --requests=cpu=100m,memory=128Mi \
  --limits=cpu=200m,memory=256Mi

# This should fail with error:
# Error from server (Forbidden): pods "pod-4" is forbidden:
# exceeded quota: strict-quota, requested: pods=1, used: pods=3, limited: pods=3

# Check events to see the rejection
kubectl get events -n limited-resources | grep quota
```

**Step 7: Delete a pod and try again**

```
# Delete pod-3 to free up space
kubectl delete pod pod-3 -n limited-resources

# Wait a moment for quota to update
sleep 5

# Now pod-4 should succeed
kubectl -n limited-resources run pod-4 --image=nginx \
  --requests=cpu=100m,memory=128Mi \
  --limits=cpu=200m,memory=256Mi

# Verify it's created
kubectl get pods -n limited-resources
```

**Step 8: Try to exceed resource quota**

```
# Try to create a pod that exceeds remaining CPU quota
kubectl -n limited-resources run pod-too-big --image=nginx \
  --requests=cpu=1500m,memory=512Mi \
  --limits=cpu=2000m,memory=1Gi

# This should fail with error about exceeding requests.cpu quota

# Try without resource specifications
kubectl -n limited-resources run pod-no-resources --image=nginx

# This should also fail:
# Error: pods "pod-no-resources" is forbidden:
# failed quota: strict-quota: must specify limits.cpu,limits.memory,requests.cpu,requests.memory
```

**Step 9: Test service quota**

```
# Create first service
kubectl -n limited-resources create service clusterip svc-1 --tcp=80:80

# Create second service (reaches limit)
kubectl -n limited-resources create service clusterip svc-2 --tcp=8080:8080

# Try to create third service (should fail)
kubectl -n limited-resources create service clusterip svc-3 --tcp=9090:9090

# Should fail: exceeded quota: strict-quota, requested: services=1, used: services=2, limited: services=2

# Verify
kubectl get svc -n limited-resources
kubectl describe quota strict-quota -n limited-resources | grep services
```

**Step 10: Understanding quota behavior**

```
# Key lessons:
echo "1. ResourceQuota REQUIRES resource specs when CPU/memory quotas exist"
echo "2. Quota is enforced at creation time, not runtime"
echo "3. Deleting resources immediately frees quota"
echo "4. Quota applies to aggregate of ALL resources in namespace"

# View complete quota status
kubectl get resourcequota -n limited-resources -o yaml
```

**Cleanup:**

```
kubectl delete namespace limited-resources
```

</details><br />

### Exercise 3: Namespace Migration

Move an application from namespace `dev` to namespace `prod`:
- Export existing resources
- Modify namespace references
- Apply to new namespace
- Verify functionality
- Clean up old namespace

<details>
  <summary>Solution</summary>

**Method 1: Using Pre-made YAML (Recommended for Exam)**

```
# Deploy dev environment
kubectl apply -f labs/namespaces/specs/ckad/exercise-3-namespace-migration.yaml

# This creates both dev and prod namespaces with all resources
# Dev has 1 replica, prod has 3 replicas
# Configurations are different between environments
```

**Method 2: Manual Migration (Step-by-Step)**

**Step 1: Deploy initial dev environment**

```
# Create dev namespace
kubectl create namespace dev

# Deploy application in dev
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: dev
data:
  APP_ENV: development
  LOG_LEVEL: debug
---
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
  namespace: dev
type: Opaque
stringData:
  API_KEY: dev-api-key-12345
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  namespace: dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: app
        image: nginx:alpine
        envFrom:
        - configMapRef:
            name: app-config
        - secretRef:
            name: app-secret
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "200m"
            memory: "256Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: app-service
  namespace: dev
spec:
  selector:
    app: myapp
  ports:
  - port: 80
EOF

# Verify dev deployment
kubectl get all -n dev
```

**Step 2: Export dev resources**

```
# Export ConfigMap
kubectl get configmap app-config -n dev -o yaml > /tmp/app-config.yaml

# Export Secret
kubectl get secret app-secret -n dev -o yaml > /tmp/app-secret.yaml

# Export Deployment
kubectl get deployment app -n dev -o yaml > /tmp/app-deployment.yaml

# Export Service
kubectl get service app-service -n dev -o yaml > /tmp/app-service.yaml

# List exported files
ls -la /tmp/*.yaml
```

**Step 3: Modify exports for prod namespace**

```
# Update ConfigMap for prod
sed -i 's/namespace: dev/namespace: prod/g' /tmp/app-config.yaml
sed -i 's/development/production/g' /tmp/app-config.yaml
sed -i 's/debug/info/g' /tmp/app-config.yaml

# Update Secret for prod
sed -i 's/namespace: dev/namespace: prod/g' /tmp/app-secret.yaml
sed -i 's/dev-api-key-12345/prod-api-key-67890/g' /tmp/app-secret.yaml

# Update Deployment for prod
sed -i 's/namespace: dev/namespace: prod/g' /tmp/app-deployment.yaml
sed -i 's/replicas: 1/replicas: 3/g' /tmp/app-deployment.yaml

# Update Service for prod
sed -i 's/namespace: dev/namespace: prod/g' /tmp/app-service.yaml

# Remove unnecessary fields (resourceVersion, uid, creationTimestamp, status)
for file in /tmp/*.yaml; do
  sed -i '/resourceVersion:/d' $file
  sed -i '/uid:/d' $file
  sed -i '/creationTimestamp:/d' $file
  sed -i '/^status:/,$d' $file
done
```

**Step 4: Create prod namespace with quota**

```
# Create prod namespace
kubectl create namespace prod

# Apply ResourceQuota for production
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: prod-quota
  namespace: prod
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    pods: "20"
EOF

# Verify quota
kubectl describe quota -n prod
```

**Step 5: Deploy to prod namespace**

```
# Apply all migrated resources
kubectl apply -f /tmp/app-config.yaml
kubectl apply -f /tmp/app-secret.yaml
kubectl apply -f /tmp/app-deployment.yaml
kubectl apply -f /tmp/app-service.yaml

# Wait for deployment to be ready
kubectl rollout status deployment app -n prod

# Verify all resources
kubectl get all -n prod
```

**Step 6: Verify prod deployment**

```
# Check pod count (should be 3)
kubectl get pods -n prod

# Verify environment variables
POD_NAME=$(kubectl get pod -n prod -l app=myapp -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n prod $POD_NAME -- env | grep -E "APP_ENV|LOG_LEVEL|API_KEY"

# Should show:
# APP_ENV=production
# LOG_LEVEL=info
# API_KEY=prod-api-key-67890

# Test service
kubectl -n prod run test --image=busybox --rm -it -- \
  wget -qO- http://app-service
```

**Step 7: Parallel testing (both environments running)**

```
# Dev should still be running
kubectl get all -n dev

# Compare environments
echo "=== DEV ==="
kubectl get pods -n dev
kubectl exec -n dev $(kubectl get pod -n dev -l app=myapp -o jsonpath='{.items[0].metadata.name}') \
  -- env | grep APP_ENV

echo "=== PROD ==="
kubectl get pods -n prod
kubectl exec -n prod $(kubectl get pod -n prod -l app=myapp -o jsonpath='{.items[0].metadata.name}') \
  -- env | grep APP_ENV
```

**Step 8: Cutover - switch traffic to prod**

```
# In a real scenario, you might:
# 1. Update DNS/Ingress to point to prod
# 2. Perform smoke tests
# 3. Monitor for issues
# 4. Keep dev as rollback option

# For this exercise, verify prod is ready
kubectl get deployment app -n prod -o wide
kubectl get endpoints app-service -n prod
```

**Step 9: Clean up dev namespace**

```
# After verifying prod works, delete dev
kubectl delete namespace dev

# Verify only prod remains
kubectl get namespace | grep -E "dev|prod"
kubectl get all -n prod
```

**Alternative Method: Using kubectl with namespace override**

```
# Quick migration using kubectl
kubectl get all -n dev -o yaml \
  | sed 's/namespace: dev/namespace: prod/g' \
  | kubectl apply -f -

# This is faster but less controlled
# Use cautiously in exam
```

**Key Migration Considerations:**

1. **StatefulSets & PVCs**: These require special handling as PVCs are bound to specific namespaces
2. **ServiceAccounts**: Recreate RBAC in target namespace
3. **Network Policies**: Update namespace selectors
4. **Ingress**: Update host/path configurations
5. **Secrets**: Consider re-encrypting for prod

**Cleanup:**

```
kubectl delete namespace dev prod
```

</details><br />

## Advanced CKAD Topics

### Pod Security Standards per Namespace

Kubernetes Pod Security Standards define different isolation levels that can be applied per namespace.

**Three Security Levels:**

| Level | Description | Use Case |
|-------|-------------|----------|
| **Privileged** | Unrestricted, allows all workloads | System namespaces, trusted workloads |
| **Baseline** | Minimally restrictive, prevents known privilege escalations | General applications |
| **Restricted** | Heavily restricted, follows pod hardening best practices | Security-sensitive applications |

**Applying Security Standards to Namespaces:**

```
# Create namespace with restricted security
kubectl create namespace restricted-apps

# Label namespace with security standard
kubectl label namespace restricted-apps \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted

# Create namespace with baseline security
kubectl create namespace baseline-apps
kubectl label namespace baseline-apps \
  pod-security.kubernetes.io/enforce=baseline

# Apply example workloads
kubectl apply -f labs/namespaces/specs/ckad/pod-security-standards.yaml
```

**Testing Security Enforcement:**

```
# Try to create privileged pod in restricted namespace (will fail)
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: privileged-pod
  namespace: restricted-apps
spec:
  containers:
  - name: nginx
    image: nginx
    securityContext:
      privileged: true
EOF

# Error: pods "privileged-pod" is forbidden: violates PodSecurity "restricted:latest"

# Create compliant pod in restricted namespace
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
  namespace: restricted-apps
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: nginx
    image: nginx:alpine
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
      runAsNonRoot: true
      runAsUser: 1000
EOF
```

**CKAD Tip:** Know the three levels and how to apply them with namespace labels. Be ready to troubleshoot pods failing due to security constraints.

### Resource Quotas with Priority Classes

PriorityClasses allow you to assign importance to pods, and you can create separate quotas for different priority levels.

**Creating Priority Classes:**

```
# High priority class
cat << EOF | kubectl apply -f -
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000
globalDefault: false
description: "High priority workloads"
EOF

# Low priority class
cat << EOF | kubectl apply -f -
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: low-priority
value: 100
globalDefault: false
description: "Low priority workloads"
EOF
```

**Quota with Priority Class Scopes:**

```
# Create namespace
kubectl create namespace priority-demo

# Quota for high-priority pods
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: high-priority-quota
  namespace: priority-demo
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    pods: "10"
  scopeSelector:
    matchExpressions:
    - operator: In
      scopeName: PriorityClass
      values: ["high-priority"]
EOF

# Quota for low-priority pods
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: low-priority-quota
  namespace: priority-demo
spec:
  hard:
    requests.cpu: "1"
    requests.memory: 2Gi
    pods: "5"
  scopeSelector:
    matchExpressions:
    - operator: In
      scopeName: PriorityClass
      values: ["low-priority"]
EOF
```

**Using Priority Classes:**

```
# Deploy high-priority pod
kubectl -n priority-demo run critical-app --image=nginx \
  --requests=cpu=500m,memory=512Mi \
  --limits=cpu=1000m,memory=1Gi \
  --overrides='{"spec":{"priorityClassName":"high-priority"}}'

# Deploy low-priority pod
kubectl -n priority-demo run batch-job --image=busybox \
  --requests=cpu=200m,memory=256Mi \
  --limits=cpu=400m,memory=512Mi \
  --overrides='{"spec":{"priorityClassName":"low-priority"}}' \
  -- sleep 3600

# Check quota usage per priority
kubectl describe quota -n priority-demo
```

### Namespace Lifecycle and Finalizers

Understanding namespace deletion and finalizers is important when resources aren't cleaning up properly.

**Namespace Phases:**

- **Active**: Namespace is operational
- **Terminating**: Namespace is being deleted, waiting for finalizers

**Common Namespace Stuck in Terminating:**

```
# Create namespace with resources
kubectl create namespace stuck-ns
kubectl -n stuck-ns run pod1 --image=nginx

# Delete namespace
kubectl delete namespace stuck-ns

# If namespace gets stuck in Terminating state:
kubectl get namespace stuck-ns -o yaml

# You'll see finalizers:
# spec:
#   finalizers:
#   - kubernetes

# Force deletion (use with caution)
kubectl get namespace stuck-ns -o json \
  | jq '.spec.finalizers=[]' \
  | kubectl replace --raw "/api/v1/namespaces/stuck-ns/finalize" -f -
```

**Viewing Namespace Finalizers:**

```
# Check namespace finalizers
kubectl get namespace default -o jsonpath='{.spec.finalizers}'

# Common finalizers:
# - kubernetes (default, ensures all resources deleted)
# - controller.cattle.io/namespace-auth (Rancher)
# - foregroundDeletion (cascade deletion)
```

### Automating Namespace Creation with Templates

For CKAD, you might need to quickly create namespaces with standard configurations.

**Namespace Template with Quotas and Limits:**

```bash
#!/bin/bash
# namespace-template.sh

NAMESPACE=$1
CPU_QUOTA=${2:-2}
MEMORY_QUOTA=${3:-4Gi}

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: $NAMESPACE
  labels:
    created-by: template
    environment: development
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ${NAMESPACE}-quota
  namespace: $NAMESPACE
spec:
  hard:
    requests.cpu: "${CPU_QUOTA}"
    requests.memory: ${MEMORY_QUOTA}
    limits.cpu: "$((CPU_QUOTA * 2))"
    limits.memory: $((${MEMORY_QUOTA%%Gi} * 2))Gi
    pods: "10"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: ${NAMESPACE}-limits
  namespace: $NAMESPACE
spec:
  limits:
  - default:
      cpu: 500m
      memory: 512Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    type: Container
EOF

echo "Created namespace: $NAMESPACE with CPU quota: $CPU_QUOTA, Memory quota: $MEMORY_QUOTA"
```

**Using the Template:**

```
# Make script executable
chmod +x namespace-template.sh

# Create namespace with default quotas
./namespace-template.sh my-app

# Create namespace with custom quotas
./namespace-template.sh big-app 4 8Gi

# Verify
kubectl describe namespace my-app
kubectl describe quota -n my-app
kubectl describe limitrange -n my-app
```

**CKAD Exam Pattern: Quick Namespace Setup**

```
# Create function in exam environment
create-app-namespace() {
  NS=$1
  kubectl create namespace $NS
  kubectl label namespace $NS tier=application env=dev
  cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: quota
  namespace: $NS
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 2Gi
    limits.cpu: "4"
    limits.memory: 4Gi
    pods: "10"
EOF
}

# Use in exam
create-app-namespace my-exam-task
```

### Cross-Namespace Resource Sharing Patterns

While ConfigMaps and Secrets can't be shared directly, here are advanced patterns:

**Pattern 1: Service Reference ConfigMap**

```
# Create reference configmap in each namespace
for ns in frontend backend database; do
  kubectl create configmap service-registry -n $ns \
    --from-literal=frontend=web.frontend.svc.cluster.local \
    --from-literal=backend=api.backend.svc.cluster.local \
    --from-literal=database=db.database.svc.cluster.local
done
```

**Pattern 2: ExternalName Services**

```
# In frontend namespace, create ExternalName service to backend
kubectl -n frontend create service externalname backend-alias \
  --external-name=api.backend.svc.cluster.local

# Now frontend can use short name "backend-alias"
kubectl -n frontend run test --image=busybox --rm -it -- \
  nslookup backend-alias
```

**Pattern 3: Namespace-wide Default ServiceAccount**

```
# Create service account with cluster-level read permissions
kubectl create namespace shared-services
kubectl create serviceaccount shared-reader -n shared-services

# Create ClusterRole
kubectl create clusterrole namespace-viewer \
  --verb=get,list,watch \
  --resource=services,endpoints

# Bind to ServiceAccount
kubectl create clusterrolebinding shared-reader-binding \
  --clusterrole=namespace-viewer \
  --serviceaccount=shared-services:shared-reader
```

These advanced topics demonstrate production-ready patterns that may appear in CKAD exam scenarios.

## Common Pitfalls

1. **Forgetting to set namespace** - Always verify with `kubectl config view --minify | grep namespace`

2. **Resource requirements with quotas** - When ResourceQuota exists, all containers need requests/limits

3. **ConfigMap/Secret scope** - Cannot reference across namespaces directly

4. **Service DNS short names** - Only work within same namespace

5. **Label selectors** - Don't span namespaces; Services only select pods in same namespace

6. **Default namespace** - Never assume; always specify explicitly in exam

## Cleanup

```
# Clean up all practice namespaces
kubectl delete namespace quota-test
kubectl delete namespace frontend
kubectl delete namespace backend
kubectl delete namespace exam-prep

# Or delete multiple at once
kubectl delete ns quota-test frontend backend exam-prep
```

## Next Steps

After mastering namespaces for CKAD:
1. Practice [RBAC](../rbac/) for namespace-level access control
2. Study [NetworkPolicy](../networkpolicy/) for namespace isolation
3. Review [Resource Management](../productionizing/) for production patterns
4. Explore [Multi-tenancy patterns](https://kubernetes.io/docs/concepts/security/multi-tenancy/)

---

## Study Checklist for CKAD

- [ ] Create namespaces imperatively
- [ ] Set and switch namespace context
- [ ] Apply ResourceQuotas
- [ ] Create LimitRanges
- [ ] Deploy pods with resource requests/limits
- [ ] Create and use ServiceAccounts in namespaces
- [ ] Resolve services across namespaces using DNS
- [ ] List resources across all namespaces
- [ ] Understand namespace-scoped vs cluster-scoped resources
- [ ] Handle ConfigMap/Secret namespace scoping
- [ ] Clean up resources by deleting namespaces
