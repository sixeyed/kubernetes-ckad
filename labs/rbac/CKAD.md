# CKAD Exam Preparation: Advanced RBAC

This document covers advanced Role-Based Access Control (RBAC) topics required for the Certified Kubernetes Application Developer (CKAD) exam. Complete the [basic RBAC lab](README.md) first before working through these exercises.

## Prerequisites

Before starting this lab, you should be familiar with:
- Roles and RoleBindings
- ClusterRoles and ClusterRoleBindings
- ServiceAccounts and their usage
- Basic `kubectl auth can-i` commands
- API groups and resource types

## CKAD RBAC Topics Covered

- ServiceAccount creation and management
- Complex RBAC rules (resourceNames, subresources)
- Multiple permissions and API groups
- Built-in ClusterRoles (view, edit, admin, cluster-admin)
- Aggregated ClusterRoles
- RBAC for specific resources (Secrets, ConfigMaps)
- Cross-namespace access patterns
- SecurityContext and ServiceAccount tokens
- Troubleshooting permission issues
- Production security best practices

## ServiceAccount Deep Dive

### Creating and Managing ServiceAccounts

ServiceAccounts are the identity mechanism for Pods accessing the Kubernetes API:

```bash
# Create a ServiceAccount imperatively (exam speed)
kubectl create serviceaccount myapp

# Create with YAML for more control
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: myapp
  namespace: default
EOF

# List ServiceAccounts
kubectl get serviceaccounts
kubectl get sa  # shorthand

# Describe ServiceAccount
kubectl describe sa myapp
```

📋 **CKAD Pattern**: You'll often need to create a ServiceAccount, configure RBAC, and attach it to a Pod.

**Example**: [specs/ckad/serviceaccounts/basic-sa.yaml](specs/ckad/serviceaccounts/basic-sa.yaml)

This example demonstrates the complete flow:
1. ServiceAccount creation
2. Role with pod reading permissions
3. RoleBinding connecting SA to Role
4. Pod configured to use the ServiceAccount

```bash
# Deploy the example
kubectl apply -f labs/rbac/specs/ckad/serviceaccounts/basic-sa.yaml

# Verify permissions
kubectl auth can-i get pods --as=system:serviceaccount:default:basic-app
kubectl auth can-i list pods --as=system:serviceaccount:default:basic-app

# Check the pod
kubectl get pod basic-app-pod -o jsonpath='{.spec.serviceAccountName}'
```

### Using ServiceAccounts in Pods

Attach ServiceAccounts to Pods via the Pod spec:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  serviceAccountName: myapp  # References the ServiceAccount
  containers:
  - name: app
    image: nginx
```

Update existing Deployment to use ServiceAccount:

```bash
# Patch deployment to use ServiceAccount
kubectl patch deployment myapp -p '{"spec":{"template":{"spec":{"serviceAccountName":"myapp"}}}}'

# Set ServiceAccount imperatively (faster for exam)
kubectl set serviceaccount deployment myapp myapp
```

### Disabling ServiceAccount Token Mounting

Security best practice: Disable token mounting for apps that don't use the API:

**Example**: [specs/ckad/serviceaccounts/no-token-pod.yaml](specs/ckad/serviceaccounts/no-token-pod.yaml)

```yaml
# Option 1: Disable at Pod level
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  automountServiceAccountToken: false
  containers:
  - name: app
    image: nginx
---
# Option 2: Disable at ServiceAccount level (better)
apiVersion: v1
kind: ServiceAccount
metadata:
  name: secure-sa
automountServiceAccountToken: false
```

📋 **CKAD Security Tip**: Always disable automount for ServiceAccounts/Pods that don't need API access.

```bash
# Deploy the example
kubectl apply -f labs/rbac/specs/ckad/serviceaccounts/no-token-pod.yaml

# Verify no token is mounted
kubectl exec no-token-pod -- ls /var/run/secrets/kubernetes.io/serviceaccount/
# Should fail or show empty directory
```

## Complex RBAC Rules

### Multiple Resources and Verbs

Roles can define permissions for multiple resources:

**Example**: [specs/ckad/roles/multi-resource-role.yaml](specs/ckad/roles/multi-resource-role.yaml)

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-manager
  namespace: default
rules:
# Pods and logs
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
# ConfigMaps and Secrets
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list"]
# Deployments
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "update", "patch"]
```

📋 **CKAD Critical**: Know the API groups for common resources:
- Core resources (Pod, Service, ConfigMap, Secret): `apiGroups: [""]`
- Deployments, StatefulSets, DaemonSets: `apiGroups: ["apps"]`
- Jobs, CronJobs: `apiGroups: ["batch"]`
- NetworkPolicies: `apiGroups: ["networking.k8s.io"]`

```bash
# Deploy and test multi-resource role
kubectl apply -f labs/rbac/specs/ckad/roles/multi-resource-role.yaml

# Test various permissions
kubectl auth can-i get pods --as=system:serviceaccount:default:app-manager-sa
kubectl auth can-i update deployments --as=system:serviceaccount:default:app-manager-sa
kubectl auth can-i get secrets --as=system:serviceaccount:default:app-manager-sa
```

### Resource-Specific Permissions (resourceNames)

Grant access to specific named resources:

**Example**: [specs/ckad/roles/named-resources.yaml](specs/ckad/roles/named-resources.yaml)

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: specific-secret-reader
  namespace: default
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["db-password", "api-key"]  # Only these secrets
  verbs: ["get"]
```

⚠️ **CKAD Gotcha**: `resourceNames` works with `get`, `delete`, `update`, `patch` but NOT with `list` or `watch`.

```bash
# Deploy example with named resource restrictions
kubectl apply -f labs/rbac/specs/ckad/roles/named-resources.yaml

# Verify specific secret access works
kubectl auth can-i get secret/db-password --as=system:serviceaccount:default:secret-reader-sa

# Verify other secrets are blocked
kubectl auth can-i get secret/other-secret --as=system:serviceaccount:default:secret-reader-sa
# Should return "no"

# List won't work with resourceNames
kubectl auth can-i list secrets --as=system:serviceaccount:default:secret-reader-sa
# Returns "no" because resourceNames doesn't work with list
```

### Subresource Permissions

Some resources have subresources requiring explicit permissions:

**Example**: [specs/ckad/roles/subresources.yaml](specs/ckad/roles/subresources.yaml)

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-logger
  namespace: default
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["pods/log"]  # Subresource for logs
  verbs: ["get"]
- apiGroups: [""]
  resources: ["pods/exec"]  # Subresource for exec
  verbs: ["create"]
```

Common subresources:
- `pods/log` - Access to pod logs
- `pods/exec` - Execute commands in pods
- `pods/portforward` - Port forwarding
- `pods/status` - Pod status updates
- `deployments/scale` - Scaling deployments

```bash
# Deploy subresource example
kubectl apply -f labs/rbac/specs/ckad/roles/subresources.yaml

# Test subresource permissions
kubectl auth can-i get pods/log --as=system:serviceaccount:default:pod-operator-sa
kubectl auth can-i create pods/exec --as=system:serviceaccount:default:pod-operator-sa
kubectl auth can-i update deployments/scale --as=system:serviceaccount:default:pod-operator-sa
```

### Wildcard Permissions

Use wildcards carefully (generally not recommended for production):

```yaml
rules:
- apiGroups: ["*"]           # All API groups
  resources: ["*"]            # All resources
  verbs: ["*"]                # All verbs (full access)
```

📋 **CKAD Exam**: Wildcards might appear in troubleshooting scenarios - recognize overly permissive rules.

## Built-in ClusterRoles

Kubernetes provides predefined ClusterRoles for common use cases:

### Standard User-Facing Roles

```bash
# View available built-in ClusterRoles
kubectl get clusterroles | grep -E '^(view|edit|admin|cluster-admin)'

# Describe built-in roles
kubectl describe clusterrole view
kubectl describe clusterrole edit
kubectl describe clusterrole admin
kubectl describe clusterrole cluster-admin
```

**Role Hierarchy:**

1. **view** - Read-only access to most resources (no secrets)
2. **edit** - Modify most resources, create/delete pods, services (no RBAC)
3. **admin** - Full access in namespace including RBAC (no quota/namespace modification)
4. **cluster-admin** - Full cluster access (superuser)

📋 **CKAD Quick Reference:**

```bash
# Grant view access to user in namespace
kubectl create rolebinding dev-view \
  --clusterrole=view \
  --user=developer@example.com \
  --namespace=dev

# Grant edit access to ServiceAccount in namespace
kubectl create rolebinding app-edit \
  --clusterrole=edit \
  --serviceaccount=default:myapp \
  --namespace=default

# Grant admin access cluster-wide
kubectl create clusterrolebinding admin-user \
  --clusterrole=admin \
  --user=admin@example.com
```

**Example**: [specs/ckad/built-in-roles/personas.yaml](specs/ckad/built-in-roles/personas.yaml)

This example demonstrates using built-in ClusterRoles for different user personas:
- **Developer**: edit access in development, view in production
- **Operator**: admin access in production
- **Viewer**: view access across namespaces

```bash
# Deploy persona example
kubectl apply -f labs/rbac/specs/ckad/built-in-roles/personas.yaml

# Test developer permissions
kubectl auth can-i create pods --as=system:serviceaccount:development:developer -n development  # yes
kubectl auth can-i create pods --as=system:serviceaccount:development:developer -n production   # no

# Test operator permissions
kubectl auth can-i create rolebindings --as=system:serviceaccount:production:operator -n production  # yes

# Test viewer permissions
kubectl auth can-i get pods --as=system:serviceaccount:default:viewer -n development  # yes
kubectl auth can-i delete pods --as=system:serviceaccount:default:viewer -n development  # no
```

### Using ClusterRoles with RoleBindings

ClusterRoles can be bound at namespace level for restricted scope:

**Example**: [specs/ckad/rolebindings/clusterrole-in-namespace.yaml](specs/ckad/rolebindings/clusterrole-in-namespace.yaml)

```yaml
# ClusterRole defines permissions (reusable)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
---
# RoleBinding applies ClusterRole to specific namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dev-secret-reader
  namespace: dev
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole  # References ClusterRole
  name: secret-reader
subjects:
- kind: ServiceAccount
  name: myapp
  namespace: dev
```

📋 **CKAD Pattern**: Use ClusterRole + RoleBinding to apply consistent permissions across multiple namespaces.

```bash
# Deploy ClusterRole in namespace example
kubectl apply -f labs/rbac/specs/ckad/rolebindings/clusterrole-in-namespace.yaml

# Verify SA can access secrets in dev namespace
kubectl auth can-i get secrets --as=system:serviceaccount:dev:myapp -n dev  # yes

# Verify SA can access secrets in staging namespace
kubectl auth can-i get secrets --as=system:serviceaccount:dev:myapp -n staging  # yes

# Verify SA cannot access secrets in other namespaces
kubectl auth can-i get secrets --as=system:serviceaccount:dev:myapp -n default  # no
```

## Aggregated ClusterRoles

Aggregate permissions from multiple ClusterRoles using label selectors:

**Example**: [specs/ckad/clusterroles/aggregated.yaml](specs/ckad/clusterroles/aggregated.yaml)

```yaml
# Aggregated ClusterRole (collects permissions)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-reader
aggregationRule:
  clusterRoleSelectors:
  - matchLabels:
      rbac.example.com/aggregate-to-monitoring: "true"
rules: []  # Rules automatically added from matching ClusterRoles
---
# Component ClusterRole 1
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pod-metrics-reader
  labels:
    rbac.example.com/aggregate-to-monitoring: "true"
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
# Component ClusterRole 2
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-metrics-reader
  labels:
    rbac.example.com/aggregate-to-monitoring: "true"
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list"]
```

📋 **CKAD Use Case**: Built-in roles like `admin`, `edit`, `view` use aggregation - you can extend them!

```bash
# Deploy aggregated ClusterRole example
kubectl apply -f labs/rbac/specs/ckad/clusterroles/aggregated.yaml

# Check that monitoring-reader has aggregated permissions
kubectl describe clusterrole monitoring-reader

# Test aggregated permissions
kubectl auth can-i get pods --as=system:serviceaccount:default:monitoring-sa  # yes
kubectl auth can-i get nodes --as=system:serviceaccount:default:monitoring-sa  # yes
kubectl auth can-i get services --as=system:serviceaccount:default:monitoring-sa  # yes
```

**Exercise: Extending Built-in View Role**

Example: [specs/ckad/aggregation/extend-view-role.yaml](specs/ckad/aggregation/extend-view-role.yaml)

This demonstrates extending the built-in `view` ClusterRole with custom permissions:

```bash
# Deploy the extension
kubectl apply -f labs/rbac/specs/ckad/aggregation/extend-view-role.yaml

# The built-in 'view' ClusterRole now includes NetworkPolicy and PV permissions
kubectl describe clusterrole view | grep -A 5 networkpolicies
kubectl describe clusterrole view | grep -A 5 persistentvolumes

# Test extended permissions
kubectl create rolebinding test-view --clusterrole=view --serviceaccount=default:extended-viewer
kubectl auth can-i get networkpolicies --as=system:serviceaccount:default:extended-viewer  # yes (extended)
```

## RBAC for Specific Resources

### Secrets Management

Grant restricted access to secrets:

**Example**: [specs/ckad/rbac-secrets/secret-manager.yaml](specs/ckad/rbac-secrets/secret-manager.yaml)

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-manager
  namespace: default
rules:
# Read all secrets
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
# Only create/update specific secret types
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["app-secrets"]
  verbs: ["create", "update", "patch"]
```

⚠️ **Security Note**: The `view` ClusterRole intentionally excludes Secrets and ConfigMaps.

```bash
# Deploy secret RBAC example
kubectl apply -f labs/rbac/specs/ckad/rbac-secrets/secret-manager.yaml

# Verify can list secrets
kubectl auth can-i list secrets --as=system:serviceaccount:default:secret-manager-sa  # yes

# Verify can get specific secret
kubectl auth can-i get secret/app-secrets --as=system:serviceaccount:default:secret-manager-sa  # yes

# Verify cannot get other secrets
kubectl auth can-i get secret/admin-secrets --as=system:serviceaccount:default:secret-manager-sa  # no
```

### ConfigMaps Access

Similar pattern for ConfigMaps:

**Example**: [specs/ckad/rbac-configmaps/configmap-editor.yaml](specs/ckad/rbac-configmaps/configmap-editor.yaml)

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: configmap-editor
  namespace: default
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

```bash
# Deploy ConfigMap RBAC examples
kubectl apply -f labs/rbac/specs/ckad/rbac-configmaps/configmap-editor.yaml

# Test full editor permissions
kubectl auth can-i create configmaps --as=system:serviceaccount:default:configmap-editor-sa  # yes
kubectl auth can-i delete configmaps --as=system:serviceaccount:default:configmap-editor-sa  # yes

# The file also includes read-only and specific ConfigMap examples
```

### Service Account Token Access

Control access to ServiceAccount tokens:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: token-manager
  namespace: default
rules:
- apiGroups: [""]
  resources: ["serviceaccounts"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["serviceaccounts/token"]  # Subresource
  verbs: ["create"]
```

## Cross-Namespace Access

### ServiceAccount in Different Namespace

RoleBindings can reference subjects from other namespaces:

**Example**: [specs/ckad/cross-namespace/cross-ns-access.yaml](specs/ckad/cross-namespace/cross-ns-access.yaml)

```yaml
# ServiceAccount in namespace "app"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: data-processor
  namespace: app
---
# Role in namespace "data"
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: data-reader
  namespace: data
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list"]
---
# RoleBinding granting app/data-processor access to data namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: data-processor-binding
  namespace: data
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: data-reader
subjects:
- kind: ServiceAccount
  name: data-processor
  namespace: app  # Different namespace!
```

📋 **CKAD Pattern**: Apps often need to access resources in other namespaces (shared configs, monitoring).

```bash
# Deploy cross-namespace access example
kubectl apply -f labs/rbac/specs/ckad/cross-namespace/cross-ns-access.yaml

# Verify ServiceAccount from 'app' namespace can access resources in 'data' namespace
kubectl auth can-i get configmaps --as=system:serviceaccount:app:data-processor -n data  # yes
kubectl auth can-i get secrets --as=system:serviceaccount:app:data-processor -n data  # yes

# Verify no access in app's own namespace (no binding there)
kubectl auth can-i get configmaps --as=system:serviceaccount:app:data-processor -n app  # no
```

### Listing Namespaces

Namespace listing requires cluster-level permissions:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: namespace-lister
rules:
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list"]
```

**Exercise: Multi-Namespace Application**

Example: [specs/ckad/cross-namespace/multi-namespace-app.yaml](specs/ckad/cross-namespace/multi-namespace-app.yaml)

This demonstrates a realistic multi-tier application with cross-namespace dependencies:

```bash
# Deploy multi-namespace application
kubectl apply -f labs/rbac/specs/ckad/cross-namespace/multi-namespace-app.yaml

# Verify frontend can access shared resources
kubectl auth can-i get configmaps --as=system:serviceaccount:frontend:frontend-app -n shared  # yes
kubectl auth can-i get secrets --as=system:serviceaccount:frontend:frontend-app -n shared  # yes

# Verify frontend can query backend services
kubectl auth can-i get services --as=system:serviceaccount:frontend:frontend-app -n backend  # yes

# Verify backend can access shared resources
kubectl auth can-i get configmaps --as=system:serviceaccount:backend:backend-api -n shared  # yes

# Check the pods are running with correct permissions
kubectl get pods -n frontend
kubectl get pods -n backend
```

## RBAC Troubleshooting

### Debugging Permission Issues

Essential commands for troubleshooting RBAC:

```bash
# Check if current user can perform action
kubectl auth can-i create pods
kubectl auth can-i delete deployments --namespace=prod

# Check specific user/ServiceAccount permissions
kubectl auth can-i list secrets \
  --as=system:serviceaccount:default:myapp

# Check in specific namespace
kubectl auth can-i get pods \
  --as=system:serviceaccount:default:myapp \
  --namespace=dev

# List all actions user can perform
kubectl auth can-i --list

# List all actions in specific namespace
kubectl auth can-i --list --namespace=dev
```

### Finding RBAC Bindings

Locate what permissions are granted:

```bash
# Find RoleBindings for ServiceAccount
kubectl get rolebindings -A -o json | \
  jq -r '.items[] | select(.subjects[]? | select(.kind=="ServiceAccount" and .name=="myapp"))'

# Find ClusterRoleBindings for ServiceAccount
kubectl get clusterrolebindings -A -o json | \
  jq -r '.items[] | select(.subjects[]? | select(.kind=="ServiceAccount" and .name=="myapp"))'

# Describe all RoleBindings in namespace
kubectl describe rolebindings -n default

# Get RoleBinding in YAML
kubectl get rolebinding app-admin -o yaml
```

### Common RBAC Errors

**Troubleshooting Exercise**: [specs/ckad/troubleshooting/broken-rbac.yaml](specs/ckad/troubleshooting/broken-rbac.yaml) | [Fixed version](specs/ckad/troubleshooting/fixed-rbac.yaml)

The broken-rbac.yaml file contains 5 common RBAC errors for practice. Try to identify and fix them!

```bash
# Deploy broken examples (they won't work correctly)
kubectl apply -f labs/rbac/specs/ckad/troubleshooting/broken-rbac.yaml

# Test and identify issues
kubectl auth can-i get pods --as=system:serviceaccount:default:broken-sa-1
kubectl describe rolebinding broken-binding-1
kubectl describe role broken-role-3

# Compare with fixed version
kubectl apply -f labs/rbac/specs/ckad/troubleshooting/fixed-rbac.yaml
```

**Error 1**: Forbidden - Missing permissions
```
Error from server (Forbidden): pods is forbidden: User "system:serviceaccount:default:myapp"
cannot list resource "pods" in API group "" in the namespace "default"
```

**Solution**: Create Role with required permissions and bind to ServiceAccount

**Error 2**: RoleBinding references non-existent Role
```
rolebinding.rbac.authorization.k8s.io/app-binding created
# But permissions don't work
```

**Debug**:
```bash
kubectl describe rolebinding app-binding
# Check Events section for warnings
```

**Error 3**: ServiceAccount not found
```
Error: serviceaccount "myapp" not found
```

**Solution**: Create ServiceAccount before creating RoleBinding

### Validating RBAC Configuration

```bash
# Check Role exists
kubectl get role pod-reader -n default

# Check RoleBinding references correct Role
kubectl get rolebinding pod-reader-binding -o yaml | grep -A 3 roleRef

# Verify ServiceAccount exists
kubectl get sa myapp

# Test permissions work
kubectl auth can-i get pods --as=system:serviceaccount:default:myapp
```

## Production Security Best Practices

### Principle of Least Privilege

**Examples**: [specs/ckad/least-privilege/good-vs-bad.yaml](specs/ckad/least-privilege/good-vs-bad.yaml)

This file contains 5 examples comparing bad (overly permissive) vs good (least privilege) RBAC patterns:

```bash
# Deploy good vs bad examples
kubectl apply -f labs/rbac/specs/ckad/least-privilege/good-vs-bad.yaml

# Review bad examples (labeled example: bad)
kubectl get roles -l example=bad

# Review good examples (labeled example: good)
kubectl get roles -l example=good

# Compare the differences
kubectl describe role bad-wildcard-role
kubectl describe role good-minimal-role
```

**Bad Example** (overly permissive):
```yaml
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
```

**Good Example** (minimal permissions):
```yaml
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  resourceNames: ["app-config"]
  verbs: ["get"]
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["app-secrets"]
  verbs: ["get"]
```

### ServiceAccount Per Application

Each application should have its own ServiceAccount:

```bash
# Bad: Multiple apps sharing default ServiceAccount
# Good: Each app has dedicated ServiceAccount

kubectl create sa frontend-app
kubectl create sa backend-api
kubectl create sa data-processor
```

### Namespace Isolation

Use namespaces + RBAC for environment isolation:

**Example**: [specs/ckad/isolation/namespace-isolation.yaml](specs/ckad/isolation/namespace-isolation.yaml)

```yaml
# Dev namespace with relaxed permissions
---
apiVersion: v1
kind: Namespace
metadata:
  name: dev
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dev-edit
  namespace: dev
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: edit
subjects:
- kind: Group
  name: developers
---
# Production namespace with strict permissions
---
apiVersion: v1
kind: Namespace
metadata:
  name: prod
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: prod-view
  namespace: prod
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view
subjects:
- kind: Group
  name: developers
```

```bash
# Deploy namespace isolation example
kubectl apply -f labs/rbac/specs/ckad/isolation/namespace-isolation.yaml

# Test developer permissions (edit in dev, view in prod)
kubectl auth can-i create pods --as=system:serviceaccount:default:developer -n dev  # yes
kubectl auth can-i create pods --as=system:serviceaccount:default:developer -n prod  # no
kubectl auth can-i get pods --as=system:serviceaccount:default:developer -n prod  # yes

# Test SRE permissions (admin in prod)
kubectl auth can-i create rolebindings --as=system:serviceaccount:default:sre -n prod  # yes
kubectl auth can-i create rolebindings --as=system:serviceaccount:default:sre -n dev  # no

# Test app ServiceAccount permissions (scoped to own namespace)
kubectl auth can-i get secrets --as=system:serviceaccount:prod:app-prod -n prod  # yes
kubectl auth can-i get secrets --as=system:serviceaccount:prod:app-prod -n dev  # no
```

### Audit and Review

Regular RBAC audits:

```bash
# List all ClusterRoleBindings (high risk)
kubectl get clusterrolebindings

# Find ServiceAccounts with cluster-admin
kubectl get clusterrolebindings -o json | \
  jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name'

# List all RoleBindings across namespaces
kubectl get rolebindings -A

# Check for wildcard permissions
kubectl get clusterroles -o json | \
  jq -r '.items[] | select(.rules[]? | select(.verbs[]? == "*")) | .metadata.name'
```

## CKAD Lab Exercises

### Exercise 1: Create ServiceAccount with Basic Permissions

Create a ServiceAccount named `webapp` in the default namespace with permissions to:
- Get and list Pods
- Get and list Services
- Get ConfigMaps named `app-config` only

Deploy a Pod using this ServiceAccount and verify permissions.

**Exercise Files**:
- [Exercise](specs/ckad/exercises/ex1-basic-rbac/exercise.yaml)
- [Solution](specs/ckad/exercises/ex1-basic-rbac/solution.yaml)

```bash
# Try the exercise first
cat labs/rbac/specs/ckad/exercises/ex1-basic-rbac/exercise.yaml

# Create your solution
kubectl create serviceaccount webapp
kubectl create role webapp-role --verb=get,list --resource=pods,services
kubectl create role configmap-getter --verb=get --resource=configmaps --resource-name=app-config
# ... complete the rest

# Or check the solution
kubectl apply -f labs/rbac/specs/ckad/exercises/ex1-basic-rbac/solution.yaml

# Verify
kubectl auth can-i get pods --as=system:serviceaccount:default:webapp  # yes
kubectl auth can-i get configmap/app-config --as=system:serviceaccount:default:webapp  # yes
kubectl auth can-i get configmap/other-config --as=system:serviceaccount:default:webapp  # no
```

### Exercise 2: Multi-Resource Role

Create a Role named `developer` in namespace `dev` that allows:
- Full access to Pods (all verbs)
- Read-only access to Deployments and ReplicaSets
- Read-only access to ConfigMaps
- No access to Secrets

Bind this role to a ServiceAccount named `dev-user`.

**Exercise Files**:
- [Exercise](specs/ckad/exercises/ex2-multi-resource/exercise.yaml)
- [Solution](specs/ckad/exercises/ex2-multi-resource/solution.yaml)

```bash
# Review the exercise
cat labs/rbac/specs/ckad/exercises/ex2-multi-resource/exercise.yaml

# Deploy the solution
kubectl apply -f labs/rbac/specs/ckad/exercises/ex2-multi-resource/solution.yaml

# Verify full Pod access
kubectl auth can-i create pods --as=system:serviceaccount:dev:dev-user -n dev  # yes
kubectl auth can-i delete pods --as=system:serviceaccount:dev:dev-user -n dev  # yes

# Verify read-only Deployment access
kubectl auth can-i get deployments --as=system:serviceaccount:dev:dev-user -n dev  # yes
kubectl auth can-i update deployments --as=system:serviceaccount:dev:dev-user -n dev  # no

# Verify no Secret access
kubectl auth can-i get secrets --as=system:serviceaccount:dev:dev-user -n dev  # no
```

### Exercise 3: Cross-Namespace Access

Setup scenario:
- ServiceAccount `backend` in namespace `app`
- Needs to read ConfigMap `shared-config` in namespace `shared`
- Should not have access to anything else in `shared` namespace

Configure RBAC to enable this access pattern.

**Exercise Files**:
- [Exercise](specs/ckad/exercises/ex3-cross-namespace/exercise.yaml)
- [Solution](specs/ckad/exercises/ex3-cross-namespace/solution.yaml)

```bash
# Review the exercise requirements
cat labs/rbac/specs/ckad/exercises/ex3-cross-namespace/exercise.yaml

# Deploy the solution
kubectl apply -f labs/rbac/specs/ckad/exercises/ex3-cross-namespace/solution.yaml

# Verify cross-namespace access works
kubectl auth can-i get configmap/shared-config --as=system:serviceaccount:app:backend -n shared  # yes

# Verify access to other ConfigMaps is blocked
kubectl auth can-i get configmap/other-config --as=system:serviceaccount:app:backend -n shared  # no

# Verify list is blocked (resourceNames doesn't work with list)
kubectl auth can-i list configmaps --as=system:serviceaccount:app:backend -n shared  # no
```

### Exercise 4: Troubleshoot RBAC

Given a broken RBAC configuration where a Pod can't access required resources:
1. Identify the permission issue
2. Determine what Role/RoleBinding is missing or misconfigured
3. Fix the configuration
4. Verify the Pod now works

**Exercise Files**:
- [Broken Configuration](specs/ckad/exercises/ex4-troubleshoot/broken.yaml)
- [Fixed Solution](specs/ckad/exercises/ex4-troubleshoot/solution.yaml)

```bash
# Deploy the broken configuration
kubectl apply -f labs/rbac/specs/ckad/exercises/ex4-troubleshoot/broken.yaml

# Test and identify issues
kubectl auth can-i get configmaps --as=system:serviceaccount:default:app-reader
# Should be "yes" but returns "no"

# Debug the issue
kubectl describe role configmap-reader
# Notice wrong API group

kubectl describe rolebinding app-reader-binding
# Notice missing namespace in subject

# Apply the fix
kubectl apply -f labs/rbac/specs/ckad/exercises/ex4-troubleshoot/solution.yaml

# Verify fixed
kubectl auth can-i get configmaps --as=system:serviceaccount:default:app-reader  # yes
```

### Exercise 5: Secure Application Deployment

Deploy a complete application with production-grade RBAC:
- Custom ServiceAccount with minimal permissions
- Disable token automounting where not needed
- Configure access to specific Secrets and ConfigMaps
- Use namespaces for isolation
- Verify with `kubectl auth can-i` commands

**Exercise Files**:
- [Exercise Requirements](specs/ckad/exercises/ex5-production/exercise.yaml)
- [Complete Solution](specs/ckad/exercises/ex5-production/solution.yaml)

```bash
# Review the exercise requirements
cat labs/rbac/specs/ckad/exercises/ex5-production/exercise.yaml

# Deploy the complete production solution
kubectl apply -f labs/rbac/specs/ckad/exercises/ex5-production/solution.yaml

# Verify frontend permissions (minimal, no token)
kubectl auth can-i get configmap/frontend-config --as=system:serviceaccount:production:frontend-app -n production  # yes
kubectl auth can-i get configmap/backend-config --as=system:serviceaccount:production:frontend-app -n production  # no
kubectl auth can-i list services --as=system:serviceaccount:production:frontend-app -n production  # no

# Verify backend permissions (service discovery enabled)
kubectl auth can-i get configmap/backend-config --as=system:serviceaccount:production:backend-api -n production  # yes
kubectl auth can-i list services --as=system:serviceaccount:production:backend-api -n production  # yes
kubectl auth can-i list pods --as=system:serviceaccount:production:backend-api -n production  # yes
kubectl auth can-i get secret/frontend-secrets --as=system:serviceaccount:production:backend-api -n production  # no

# Check token mounting
kubectl get deployment frontend -n production -o jsonpath='{.spec.template.spec.automountServiceAccountToken}'  # false
kubectl get deployment backend -n production -o jsonpath='{.spec.template.spec.automountServiceAccountToken}'  # true

# View the complete architecture
kubectl get all,sa,role,rolebinding -n production
```

## Common CKAD Exam Scenarios

### Scenario 1: Create ServiceAccount and Assign to Pod

"Create a ServiceAccount named `api-access` and configure the deployment `backend` to use it"

```bash
# Create ServiceAccount
kubectl create sa api-access

# Update deployment
kubectl set serviceaccount deployment backend api-access

# Verify
kubectl get deployment backend -o jsonpath='{.spec.template.spec.serviceAccountName}'
```

### Scenario 2: Grant Role to ServiceAccount

"Create a Role that allows reading ConfigMaps and bind it to the ServiceAccount `myapp`"

```bash
# Create Role
kubectl create role configmap-reader \
  --verb=get,list \
  --resource=configmaps

# Create RoleBinding
kubectl create rolebinding myapp-configmap-reader \
  --role=configmap-reader \
  --serviceaccount=default:myapp

# Verify
kubectl auth can-i get configmaps --as=system:serviceaccount:default:myapp
```

### Scenario 3: Cluster-Wide Permissions

"Grant the ServiceAccount `monitor` in namespace `monitoring` cluster-wide read access to Pods"

```bash
# Create ClusterRole
kubectl create clusterrole pod-reader \
  --verb=get,list,watch \
  --resource=pods

# Create ClusterRoleBinding
kubectl create clusterrolebinding monitor-pod-reader \
  --clusterrole=pod-reader \
  --serviceaccount=monitoring:monitor

# Verify
kubectl auth can-i list pods --as=system:serviceaccount:monitoring:monitor -n kube-system
```

### Scenario 4: Use Built-in Role

"Grant edit permissions to ServiceAccount `developer` in namespace `dev` only"

```bash
# Create RoleBinding using built-in edit ClusterRole
kubectl create rolebinding developer-edit \
  --clusterrole=edit \
  --serviceaccount=dev:developer \
  --namespace=dev

# Verify
kubectl auth can-i create deployments --as=system:serviceaccount:dev:developer -n dev
kubectl auth can-i create deployments --as=system:serviceaccount:dev:developer -n prod
```

### Scenario 5: Debug Permission Issue

"A Pod is failing with 'Forbidden' errors when trying to list Secrets. Fix the RBAC configuration."

```bash
# 1. Identify the ServiceAccount
kubectl get pod mypod -o jsonpath='{.spec.serviceAccountName}'

# 2. Check current permissions
kubectl auth can-i list secrets --as=system:serviceaccount:default:myapp

# 3. Create Role with secret permissions
kubectl create role secret-reader --verb=get,list --resource=secrets

# 4. Create RoleBinding
kubectl create rolebinding myapp-secret-reader \
  --role=secret-reader \
  --serviceaccount=default:myapp

# 5. Verify fix
kubectl auth can-i list secrets --as=system:serviceaccount:default:myapp
```

## Quick Command Reference for CKAD

### ServiceAccount Commands

```bash
# Create ServiceAccount
kubectl create serviceaccount <name>
kubectl create sa <name>  # Short form

# List ServiceAccounts
kubectl get serviceaccounts
kubectl get sa

# Describe ServiceAccount
kubectl describe sa <name>

# Delete ServiceAccount
kubectl delete sa <name>

# Set ServiceAccount on Deployment
kubectl set serviceaccount deployment <deploy-name> <sa-name>
```

### Role Commands

```bash
# Create Role (imperative)
kubectl create role <name> \
  --verb=<verbs> \
  --resource=<resources> \
  --namespace=<ns>

# Example: Create pod reader role
kubectl create role pod-reader \
  --verb=get,list \
  --resource=pods

# Create ClusterRole
kubectl create clusterrole <name> \
  --verb=<verbs> \
  --resource=<resources>

# List Roles
kubectl get roles
kubectl get clusterroles

# Describe Role
kubectl describe role <name>
kubectl describe clusterrole <name>

# Delete Role
kubectl delete role <name>
kubectl delete clusterrole <name>
```

### RoleBinding Commands

```bash
# Create RoleBinding for ServiceAccount
kubectl create rolebinding <name> \
  --role=<role-name> \
  --serviceaccount=<namespace>:<sa-name> \
  --namespace=<ns>

# Create RoleBinding for User
kubectl create rolebinding <name> \
  --role=<role-name> \
  --user=<username> \
  --namespace=<ns>

# Create RoleBinding using ClusterRole
kubectl create rolebinding <name> \
  --clusterrole=<clusterrole-name> \
  --serviceaccount=<namespace>:<sa-name> \
  --namespace=<ns>

# Create ClusterRoleBinding
kubectl create clusterrolebinding <name> \
  --clusterrole=<clusterrole-name> \
  --serviceaccount=<namespace>:<sa-name>

# List RoleBindings
kubectl get rolebindings
kubectl get clusterrolebindings

# Describe RoleBinding
kubectl describe rolebinding <name>
kubectl describe clusterrolebinding <name>

# Delete RoleBinding
kubectl delete rolebinding <name>
kubectl delete clusterrolebinding <name>
```

### Permission Testing Commands

```bash
# Check if you can perform action
kubectl auth can-i <verb> <resource>
kubectl auth can-i create pods
kubectl auth can-i delete deployments

# Check as different user/ServiceAccount
kubectl auth can-i <verb> <resource> --as=<user>
kubectl auth can-i get secrets --as=system:serviceaccount:default:myapp

# Check in specific namespace
kubectl auth can-i <verb> <resource> --namespace=<ns>
kubectl auth can-i list pods --namespace=kube-system

# List all permissions
kubectl auth can-i --list
kubectl auth can-i --list --namespace=<ns>
```

### Useful Exam Patterns

```bash
# Complete RBAC setup (one-liner)
kubectl create sa myapp && \
kubectl create role pod-reader --verb=get,list --resource=pods && \
kubectl create rolebinding myapp-pod-reader --role=pod-reader --serviceaccount=default:myapp

# Quick verification chain
kubectl auth can-i get pods --as=system:serviceaccount:default:myapp && \
kubectl auth can-i list pods --as=system:serviceaccount:default:myapp

# Generate YAML template (modify before applying)
kubectl create role myrole --verb=get --resource=pods --dry-run=client -o yaml > role.yaml

# Get ServiceAccount format for RoleBinding
kubectl get sa myapp -o jsonpath='{.metadata.name}{"\n"}'
```

## Exam Tips and Tricks

### Speed Tips

1. **Use imperative commands** whenever possible
2. **Remember shortcuts**: `sa` (ServiceAccount), `role`, `rolebinding`
3. **ServiceAccount format**: `system:serviceaccount:<namespace>:<name>`
4. **Chain commands** with `&&` to verify quickly
5. **Use kubectl explain**: `kubectl explain role.rules`

### Common Mistakes to Avoid

1. ❌ Forgetting namespace in ServiceAccount subject
   ```yaml
   subjects:
   - kind: ServiceAccount
     name: myapp
     namespace: default  # DON'T FORGET!
   ```

2. ❌ Wrong API group for resources
   ```yaml
   # Wrong
   apiGroups: ["apps"]
   resources: ["pods"]

   # Correct
   apiGroups: [""]
   resources: ["pods"]
   ```

3. ❌ Role and RoleBinding in different namespaces
   ```bash
   # Both must be in same namespace
   kubectl create role myrole --namespace=dev
   kubectl create rolebinding mybinding --role=myrole --namespace=dev
   ```

4. ❌ Using resourceNames with list/watch
   ```yaml
   # This won't work
   resources: ["secrets"]
   resourceNames: ["my-secret"]
   verbs: ["list"]  # list doesn't work with resourceNames
   ```

5. ❌ Creating RoleBinding before Role
   ```bash
   # Create Role first, then RoleBinding
   kubectl create role myrole --verb=get --resource=pods
   kubectl create rolebinding mybinding --role=myrole --serviceaccount=default:myapp
   ```

### Bookmarked Documentation

During exam, bookmark these pages:
- https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/
- https://kubernetes.io/docs/reference/kubectl/cheatsheet/

## Additional Resources

- [RBAC Official Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Configure Service Accounts](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/)
- [Managing Service Accounts](https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/)

## Study Checklist

- [ ] Create ServiceAccounts imperatively and declaratively
- [ ] Understand API groups for common resources
- [ ] Create Roles with multiple rules
- [ ] Create RoleBindings for ServiceAccounts
- [ ] Use ClusterRoles with RoleBindings
- [ ] Test permissions with `kubectl auth can-i`
- [ ] Troubleshoot RBAC issues
- [ ] Disable ServiceAccount token mounting
- [ ] Configure cross-namespace access
- [ ] Use built-in ClusterRoles (view, edit, admin)
- [ ] Understand resourceNames limitations
- [ ] Work with subresources (logs, exec, etc.)

## Cleanup

```bash
kubectl delete sa,role,rolebinding,clusterrole,clusterrolebinding -A -l kubernetes.courselabs.co=rbac-ckad
```

---

> Return to [basic RBAC lab](README.md) | Check [solution examples](solution-ckad.md)
