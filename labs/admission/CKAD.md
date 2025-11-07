# Admission Control for CKAD

This document extends the [basic admission lab](README.md) with CKAD exam-specific scenarios and requirements.

## CKAD Exam Context

Admission control is typically covered at a conceptual level in CKAD. You need to:
- Understand what admission controllers are and when they run
- Recognize admission controller error messages
- Debug failures caused by admission policies
- Understand Pod Security Standards
- Work with existing admission policies (OPA Gatekeeper constraints)
- Know common built-in admission controllers

**Exam Tip:** You won't need to write custom admission webhooks, but you WILL need to troubleshoot apps that fail due to admission policies and understand error messages.

## What Are Admission Controllers?

Admission controllers are plugins that intercept requests to the Kubernetes API server **after authentication and authorization** but **before** objects are persisted.

### Request Flow

```
Client → Authentication → Authorization → Admission Controllers → Persistence (etcd)
                                            ↓
                                    [Mutating] → [Validating]
```

1. **Mutating Admission** - Can modify/mutate the object (runs first)
2. **Validating Admission** - Can accept or reject the object (runs after mutating)

### Why Admission Controllers Matter for CKAD

- **Enforce policies** - Security, resource limits, naming conventions
- **Set defaults** - Add missing fields automatically
- **Validate configurations** - Prevent invalid or dangerous configurations
- **Block deployment** - Your perfectly valid YAML might be rejected by policy

## Built-in Admission Controllers (CKAD Relevant)

You don't enable/disable these in the exam, but you should know what they do:

| Admission Controller | Purpose | CKAD Relevance |
|---------------------|---------|----------------|
| **NamespaceLifecycle** | Prevents objects in terminating/non-existent namespaces | Common error source |
| **LimitRanger** | Enforces LimitRange constraints | Resource management |
| **ResourceQuota** | Enforces ResourceQuota constraints | Namespace quotas |
| **ServiceAccount** | Automates ServiceAccount injection | Security context |
| **DefaultStorageClass** | Adds default storage class to PVCs | Storage |
| **PodSecurity** | Enforces Pod Security Standards | Security (important!) |
| **MutatingAdmissionWebhook** | Calls external webhooks to mutate objects | Policy enforcement |
| **ValidatingAdmissionWebhook** | Calls external webhooks to validate objects | Policy enforcement |

## Recognizing Admission Controller Errors

### Common Error Patterns

When you see these errors, it's an admission controller:

```
Error from server: admission webhook "..." denied the request: ...
```

```
Error creating: pods "..." is forbidden: failed quota: ... must specify limits.cpu
```

```
Error: failed to create pod: admission webhook "validate.nginx.ingress.kubernetes.io" denied
```

### Debugging Admission Failures

**Scenario:** You apply a Deployment but Pods aren't created.

```bash
# 1. Check Deployment
kubectl get deploy myapp
kubectl describe deploy myapp

# 2. Check ReplicaSet (admission errors often appear here)
kubectl get rs -l app=myapp
kubectl describe rs -l app=myapp

# Look for: "Error creating: admission webhook ... denied the request: ..."
```

📋 Deploy the whoami app and debug why it fails:

```bash
kubectl apply -f labs/admission/specs/whoami
```

<details>
  <summary>Solution</summary>

```bash
# Deployment creates, but Pods don't
kubectl get deploy whoami
# READY 0/2

# Check ReplicaSet events
kubectl describe rs -l app=whoami
# Error creating: admission webhook "servicetokenpolicy.courselabs.co"
# denied the request: automountServiceAccountToken must be set to false

# The admission controller is rejecting Pods without this field
# Fix: Update the Deployment to include automountServiceAccountToken: false
kubectl apply -f labs/admission/specs/whoami/fix
```

</details><br />

## Pod Security Standards (PSS)

Pod Security Standards replaced Pod Security Policies (deprecated in 1.21, removed in 1.25).

### Three Policy Levels

| Level | Description | Use Case |
|-------|-------------|----------|
| **Privileged** | Unrestricted, allows everything | Trusted system workloads |
| **Baseline** | Minimally restrictive, prevents known privilege escalations | Common applications |
| **Restricted** | Heavily restricted, follows Pod hardening best practices | Security-critical applications |

### Enforcement Modes

Applied at the **namespace level**:

| Mode | Behavior |
|------|----------|
| **enforce** | Policy violations reject the Pod |
| **audit** | Violations allowed but logged to audit log |
| **warn** | Violations allowed but warning returned to user |

### Applying Pod Security Standards

```bash
# Label namespace to enforce baseline standard
kubectl label namespace my-app pod-security.kubernetes.io/enforce=baseline

# Multiple modes can be used together
kubectl label namespace my-app \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted
```

### Common Baseline Restrictions

The **baseline** policy prevents:
- `hostNetwork: true`
- `hostPID: true`
- `hostIPC: true`
- `hostPath` volumes
- `privileged: true` containers
- Capability additions (except safe ones)

### Common Restricted Restrictions

The **restricted** policy additionally requires:
- `runAsNonRoot: true`
- Dropped ALL capabilities
- `seccompProfile` set
- No privilege escalation

### CKAD Scenario: Pod Security Standard Violation

```bash
# Create namespace with baseline enforcement
kubectl create namespace secure-app
kubectl label namespace secure-app pod-security.kubernetes.io/enforce=baseline

# Try to create a privileged pod
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: privileged-pod
  namespace: secure-app
spec:
  containers:
  - name: nginx
    image: nginx
    securityContext:
      privileged: true
EOF
```

You'll get an error like:
```
Error from server (Forbidden): error when creating "STDIN": pods "privileged-pod" is forbidden:
violates PodSecurity "baseline:latest": privileged (container "nginx" must not set
securityContext.privileged=true)
```

📋 Create a namespace with `restricted` enforcement and try to run a basic nginx pod.

<details>
  <summary>Solution</summary>

```bash
# Create namespace with restricted policy
kubectl create namespace restricted-ns
kubectl label namespace restricted-ns pod-security.kubernetes.io/enforce=restricted

# Try basic nginx (will fail)
kubectl run nginx --image=nginx -n restricted-ns
# Error: violates PodSecurity "restricted:latest": allowPrivilegeEscalation != false
# runAsNonRoot != true...

# Fix: Create Pod with proper security context
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  namespace: restricted-ns
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
EOF
```

Note: nginx:alpine might still fail if the image runs as root. You may need a non-root image.

</details><br />

## ResourceQuota Admission Control

ResourceQuota is an admission controller that enforces namespace quotas.

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

### Quota Violation Errors

```bash
# When quota is exceeded, you see:
Error from server (Forbidden): pods "myapp-xxxx" is forbidden:
exceeded quota: compute-quota, requested: limits.memory=4Gi,
used: limits.memory=6Gi, limited: limits.memory=8Gi
```

### Debugging Quota Issues

```bash
# Check quota status
kubectl describe resourcequota -n dev

# Shows:
# Resource        Used  Hard
# --------        ----  ----
# limits.memory   6Gi   8Gi
# pods            8     10

# To fix: Delete some pods or increase quota
```

📋 Create a namespace with a quota of 2 pods, deploy 3 pods, and observe the error.

<details>
  <summary>Solution</summary>

```bash
# Create namespace with pod quota
kubectl create namespace quota-test
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: pod-quota
  namespace: quota-test
spec:
  hard:
    pods: "2"
EOF

# Try to create 3 pods
kubectl run pod1 --image=nginx -n quota-test
kubectl run pod2 --image=nginx -n quota-test
kubectl run pod3 --image=nginx -n quota-test

# Third pod fails
# Error from server (Forbidden): pods "pod3" is forbidden:
# exceeded quota: pod-quota, requested: pods=1, used: pods=2, limited: pods=2

# Check quota
kubectl describe resourcequota pod-quota -n quota-test
```

</details><br />

## LimitRange Admission Control

LimitRange enforces default limits and min/max constraints.

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: mem-limit-range
spec:
  limits:
  - default:          # Default limits
      memory: 512Mi
      cpu: 500m
    defaultRequest:   # Default requests
      memory: 256Mi
      cpu: 100m
    max:              # Maximum allowed
      memory: 1Gi
      cpu: 1
    min:              # Minimum required
      memory: 128Mi
      cpu: 50m
    type: Container
```

### LimitRange Violation Errors

```bash
# When you exceed max:
Error from server (Forbidden): pods "big-pod" is forbidden:
maximum memory usage per Container is 1Gi, but limit is 2Gi
```

### Debugging LimitRange Issues

```bash
# Check LimitRange
kubectl describe limitrange mem-limit-range

# Shows defaults, min, max for resources
```

## OPA Gatekeeper (Practical CKAD Usage)

In CKAD, you won't create Gatekeeper policies, but you may need to work with existing ones.

### Understanding Gatekeeper Constraints

```bash
# List constraint templates (the policy definitions)
kubectl get constrainttemplates

# List specific constraints (policy instances)
kubectl get requiredlabels
kubectl get k8srequiredlabels  # Common convention

# Describe to see violations
kubectl describe requiredlabels my-policy
```

### Gatekeeper Error Messages

```
Error from server ([my-policy] you must provide labels: {"app", "owner"}):
error when creating "pod.yaml": admission webhook "validation.gatekeeper.sh"
denied the request
```

### Debugging Gatekeeper Violations

```bash
# 1. Check which constraints exist
kubectl get constraints --all-namespaces

# 2. Describe the constraint to understand requirements
kubectl describe <constraint-type> <constraint-name>

# Look for:
# - Match: Which resources this applies to
# - Parameters: What's required/restricted
# - Violations: Current violations (helpful!)

# 3. Fix your YAML to meet requirements
```

📋 Given a Gatekeeper constraint requiring `app` and `version` labels, deploy a compliant pod.

<details>
  <summary>Solution</summary>

```bash
# Assume constraint exists requiring app and version labels

# Check constraint
kubectl get requiredlabels
kubectl describe requiredlabels my-policy

# Create compliant pod
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: myapp
  labels:
    app: myapp
    version: "1.0"
spec:
  containers:
  - name: nginx
    image: nginx
EOF
```

</details><br />

## Common CKAD Scenarios

### Scenario 1: Deployment Not Creating Pods

**Symptom:** Deployment exists, ReplicaSet exists, but no Pods.

```bash
kubectl get deploy myapp  # 0/3 ready
kubectl get rs -l app=myapp  # 0 desired pods

# Check ReplicaSet events
kubectl describe rs -l app=myapp
# Look for admission webhook errors
```

**Common Causes:**
- Validating webhook rejecting Pods
- ResourceQuota exceeded
- LimitRange violation
- Pod Security Standard violation

### Scenario 2: Pod Security Standard Error

**Error:**
```
violates PodSecurity "baseline:latest": hostNetwork (pod must not set
spec.securityContext.hostNetwork=true)
```

**Fix:**
```yaml
# Remove or set to false
spec:
  hostNetwork: false  # or remove this line
```

### Scenario 3: ResourceQuota Error

**Error:**
```
exceeded quota: compute-quota, requested: limits.cpu=2, used: limits.cpu=3, limited: limits.cpu=4
```

**Fix Options:**
1. Reduce resource requests in your Pods
2. Delete other Pods in the namespace
3. Increase the quota (if you have permission)

```bash
# Check current usage
kubectl describe resourcequota -n namespace

# Option 1: Scale down other deployments
kubectl scale deploy other-app --replicas=0 -n namespace
```

### Scenario 4: Missing Required Labels (Gatekeeper)

**Error:**
```
admission webhook "validation.gatekeeper.sh" denied the request:
you must provide labels: {"app"}
```

**Fix:**
```yaml
metadata:
  labels:
    app: myapp  # Add missing label
```

## Troubleshooting Checklist

When a resource won't create:

1. **Check the object status**
   ```bash
   kubectl get <resource-type> <name>
   kubectl describe <resource-type> <name>
   ```

2. **For Deployments, check ReplicaSets**
   ```bash
   kubectl describe rs -l app=<app-label>
   ```

3. **Look for admission webhook errors** in events
   - Format: `admission webhook "..." denied the request: ...`

4. **Check namespace labels** for Pod Security Standards
   ```bash
   kubectl get namespace <ns> --show-labels
   ```

5. **Check ResourceQuotas**
   ```bash
   kubectl describe resourcequota -n <namespace>
   ```

6. **Check LimitRanges**
   ```bash
   kubectl describe limitrange -n <namespace>
   ```

7. **Check Gatekeeper constraints**
   ```bash
   kubectl get constraints --all-namespaces
   ```

8. **Read the error message carefully** - it usually tells you exactly what's wrong

## Advanced Topics

### Custom Resource Definitions with Validation

CRDs can include OpenAPI v3 schema validation that runs during admission:

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: applications.example.com
spec:
  group: example.com
  names:
    kind: Application
    plural: applications
  scope: Namespaced
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            required:
            - replicas
            - image
            properties:
              replicas:
                type: integer
                minimum: 1
                maximum: 10
              image:
                type: string
                pattern: '^[a-z0-9\-\./:]+$'
```

**CKAD Relevance:** When working with custom resources (Operators, Helm charts), validation errors come from CRD schemas.

### Admission Webhook Failure Policies

Webhooks have a `failurePolicy` that determines behavior when the webhook fails:

| Policy | Behavior | Risk |
|--------|----------|------|
| **Fail** | Reject the request if webhook errors | Safe but can block all deployments |
| **Ignore** | Allow the request if webhook errors | Unsafe but prevents outages |

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: my-webhook
webhooks:
- name: validate.example.com
  failurePolicy: Fail  # or Ignore
  timeoutSeconds: 10
  # ...
```

**CKAD Impact:** If a webhook is down with `Fail` policy, you can't create any matching resources. Look for timeout errors.

### Namespace Selectors in Webhooks

Webhooks can target specific namespaces:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: my-webhook
webhooks:
- name: validate.example.com
  namespaceSelector:
    matchLabels:
      environment: production
  # Only applies to namespaces with environment=production label
```

**Debugging:**
```bash
# Check if namespace matches webhook selector
kubectl get namespace my-ns --show-labels

# Check webhook namespace selectors
kubectl get validatingwebhookconfigurations my-webhook -o yaml | grep -A5 namespaceSelector
```

### Audit Annotations

Admission controllers can add audit annotations that appear in audit logs:

```bash
# When admission controller adds annotations, they appear in audit events
# You won't see these in normal kubectl output

# Example audit log entry:
{
  "annotations": {
    "mutation.gatekeeper.sh/applied": "true",
    "validation.gatekeeper.sh/constraint": "required-labels"
  }
}
```

**CKAD Relevance:** Minimal for exam, but helps understand why certain fields were added automatically.

### Dry-run with Admission Controllers

Use `--dry-run=server` to test admission without creating resources:

```bash
# Client-side dry-run (no admission check)
kubectl apply -f pod.yaml --dry-run=client

# Server-side dry-run (runs through admission)
kubectl apply -f pod.yaml --dry-run=server

# This will show admission errors without creating the object
kubectl apply -f privileged-pod.yaml --dry-run=server -n secure-ns
# Error: violates PodSecurity "baseline:latest": privileged
```

**Exam Strategy:** Use `--dry-run=server` to validate YAML before applying.

### Common Gatekeeper ConstraintTemplates

Gatekeeper has a library of common constraint templates:

| ConstraintTemplate | Purpose | Common Use |
|-------------------|---------|------------|
| **K8sRequiredLabels** | Enforce required labels | `app`, `owner`, `version` labels |
| **K8sAllowedRepos** | Restrict image registries | Only pull from internal registry |
| **K8sContainerLimits** | Enforce resource limits | All containers must have limits |
| **K8sRequiredResources** | Require resource requests/limits | Enforce resource management |
| **K8sBlockNodePort** | Block NodePort services | Security in multi-tenant |
| **K8sPSPCapabilities** | Restrict Linux capabilities | Security hardening |
| **K8sNoHostNamespace** | Block host network/PID/IPC | Prevent privilege escalation |

**Finding Templates:**
```bash
# List installed templates
kubectl get constrainttemplates

# View template definition
kubectl describe constrainttemplate k8srequiredlabels

# View active constraints
kubectl get constraints --all-namespaces
```

**Example Constraint:**
```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: must-have-app-label
spec:
  match:
    kinds:
    - apiGroups: [""]
      kinds: ["Pod"]
  parameters:
    labels:
    - key: "app"
```

**CKAD Practice:** If you see Gatekeeper errors, describe the constraint to find requirements.

## Common CKAD Pitfalls

1. **Ignoring ReplicaSet events** - Admission errors often appear here, not on Deployment
2. **Not checking namespace labels** - Pod Security Standards are namespace-scoped
3. **Assuming YAML is valid** - Admission controllers add runtime checks beyond schema validation
4. **Not reading error messages** - They're usually very specific about what's wrong
5. **Forgetting ResourceQuota applies at creation** - Existing pods aren't affected by new quotas
6. **Not checking constraint violations** - `describe` on Gatekeeper constraints shows current violations
7. **Missing securityContext** - Restricted Pod Security Standard requires many security fields
8. **Debugging wrong object** - For Deployments, check ReplicaSet; for StatefulSets, check Pods
9. **Not considering defaults** - LimitRange and mutating webhooks can add fields automatically
10. **Webhook timeout** - If webhook is down, object creation may hang or fail

## Quick Reference

### Check Admission Status

```bash
# Check Pod Security Standards on namespace
kubectl get namespace <ns> --show-labels | grep pod-security

# Check ResourceQuota
kubectl describe resourcequota -n <namespace>

# Check LimitRange
kubectl describe limitrange -n <namespace>

# Check Gatekeeper constraints
kubectl get constraints --all-namespaces

# Check for webhook configs
kubectl get validatingwebhookconfigurations
kubectl get mutatingwebhookconfigurations
```

### Apply Pod Security Standards

```bash
# Enforce baseline
kubectl label namespace <ns> pod-security.kubernetes.io/enforce=baseline

# Enforce restricted
kubectl label namespace <ns> pod-security.kubernetes.io/enforce=restricted

# Warn only (don't enforce)
kubectl label namespace <ns> pod-security.kubernetes.io/warn=baseline

# Audit mode
kubectl label namespace <ns> pod-security.kubernetes.io/audit=baseline
```

### Debug Admission Failures

```bash
# For Deployments
kubectl describe deploy <name>
kubectl describe rs -l app=<label>

# For Pods
kubectl describe pod <name>

# Check events
kubectl get events --sort-by='.lastTimestamp'

# Check quota usage
kubectl describe resourcequota -n <namespace>
```

## Practice Exercises

### Exercise 1: Debug Admission Failure

Given:
- A Deployment that creates a ReplicaSet but no Pods
- An unknown admission policy in place

Tasks:
1. Identify the admission controller blocking the Pods
2. Read the error message to understand requirements
3. Fix the Deployment to pass admission

<details>
  <summary>Step-by-Step Solution</summary>

**Setup:**

First, install Gatekeeper (if not already installed):

```bash
# Install OPA Gatekeeper
kubectl apply -f labs/admission/specs/opa-gatekeeper

# Wait for Gatekeeper to be ready
kubectl wait --for=condition=ready pod -l app=gatekeeper -n gatekeeper-system --timeout=180s
```

Create the namespace and apply the constraint:

```bash
# Create namespace for the exercise
kubectl create namespace exercise1

# Apply the constraint that requires 'app' and 'environment' labels
kubectl apply -f labs/admission/specs/ckad/exercise1-constraint.yaml

# Wait for constraint to be ready
sleep 10
```

**Step 1: Deploy the broken application**

```bash
# Try to deploy the application (it has a missing label)
kubectl apply -f labs/admission/specs/ckad/exercise1-deployment-broken.yaml
```

The Deployment will be created, but no Pods will appear:

```bash
kubectl get deploy web-app -n exercise1
# NAME      READY   UP-TO-DATE   AVAILABLE   AGE
# web-app   0/3     0            0           10s
```

**Step 2: Identify why Pods aren't created**

Check the ReplicaSet events (this is where admission errors appear):

```bash
kubectl get rs -n exercise1
# Shows ReplicaSet exists but with 0 ready replicas

kubectl describe rs -n exercise1
```

You'll see an error message in the events section:

```
Warning  FailedCreate  5s (x3 over 7s)  replicaset-controller
  Error creating: admission webhook "validation.gatekeeper.sh" denied the request:
  [pod-must-have-labels] you must provide labels: {"environment"}
```

**Step 3: Understand the requirement**

Check the Gatekeeper constraint to understand what's required:

```bash
# List all constraints
kubectl get constraints --all-namespaces

# Describe the specific constraint
kubectl describe k8srequiredlabels pod-must-have-labels
```

The constraint shows:
- **Match**: Applies to all Pods in namespace `exercise1`
- **Parameters**: Requires labels `app` and `environment`

**Step 4: Fix the Deployment**

Update the Deployment to include the missing label:

```bash
# Apply the fixed version
kubectl apply -f labs/admission/specs/ckad/exercise1-deployment-fixed.yaml

# Verify Pods are now created
kubectl get pods -n exercise1
# NAME                       READY   STATUS    RESTARTS   AGE
# web-app-xxxxxxxxxx-xxxxx   1/1     Running   0          5s
# web-app-xxxxxxxxxx-xxxxx   1/1     Running   0          5s
# web-app-xxxxxxxxxx-xxxxx   1/1     Running   0          5s

kubectl get deploy web-app -n exercise1
# NAME      READY   UP-TO-DATE   AVAILABLE   AGE
# web-app   3/3     3            3           2m
```

**Alternative: Manual fix without the provided YAML**

```bash
# Edit the deployment directly
kubectl edit deploy web-app -n exercise1

# Add the missing label to spec.template.metadata.labels:
#   labels:
#     app: web-app
#     environment: development  # Add this line

# Save and exit - Pods will now be created
```

**Key Learnings:**

1. **Deployment creates but Pods don't** → Check ReplicaSet events
2. **Admission webhook error format** → `admission webhook "..." denied the request: ...`
3. **Gatekeeper errors include constraint name** → `[pod-must-have-labels]`
4. **Use describe on constraints** → Shows match rules and parameters
5. **Fix Pod template, not Deployment metadata** → Labels in `spec.template.metadata.labels`

**Cleanup:**

```bash
kubectl delete namespace exercise1
kubectl delete constrainttemplate k8srequiredlabels
```

</details><br />

### Exercise 2: Pod Security Standard

Tasks:
1. Create namespace `secure-app`
2. Apply `baseline` enforcement
3. Try to deploy a pod with `hostNetwork: true` (should fail)
4. Deploy a compliant pod
5. Change to `restricted` enforcement
6. Fix the pod to meet restricted requirements

<details>
  <summary>Detailed Solution</summary>

**Step 1: Create namespace with baseline enforcement**

```bash
# Create the namespace
kubectl create namespace secure-app

# Apply baseline Pod Security Standard with enforcement
kubectl label namespace secure-app pod-security.kubernetes.io/enforce=baseline

# Verify the label
kubectl get namespace secure-app --show-labels
```

**Step 2: Try to deploy a pod that violates baseline policy**

```bash
# Try to create a pod with hostNetwork (violates baseline)
kubectl apply -f labs/admission/specs/ckad/exercise2-pod-baseline-violation.yaml
```

You'll see an error:

```
Error from server (Forbidden): error when creating "exercise2-pod-baseline-violation.yaml":
pods "nginx-hostnetwork" is forbidden: violates PodSecurity "baseline:latest":
host namespaces (hostNetwork=true)
```

**Understanding the error:**
- The Pod Security admission controller intercepted the request
- "baseline" policy prohibits `hostNetwork: true`
- Other baseline violations include: `hostPID`, `hostIPC`, `privileged: true`, `hostPath` volumes

**Step 3: Deploy a baseline-compliant pod**

```bash
# Deploy a pod that meets baseline requirements
kubectl apply -f labs/admission/specs/ckad/exercise2-pod-baseline-compliant.yaml

# Verify it's running
kubectl get pod nginx-baseline -n secure-app
# NAME              READY   STATUS    RESTARTS   AGE
# nginx-baseline    1/1     Running   0          5s
```

This works because:
- No host namespace sharing
- No privileged containers
- No hostPath volumes
- No dangerous capabilities

**Step 4: Change to restricted enforcement**

```bash
# Update namespace to enforce restricted policy
kubectl label namespace secure-app pod-security.kubernetes.io/enforce=restricted --overwrite

# The existing pod continues running (policies apply at creation time)
kubectl get pod nginx-baseline -n secure-app
# Still running

# But try to create a new pod with the same spec
kubectl delete pod nginx-baseline -n secure-app
kubectl apply -f labs/admission/specs/ckad/exercise2-pod-baseline-compliant.yaml
```

You'll now get an error:

```
Error from server (Forbidden): error when creating "exercise2-pod-baseline-compliant.yaml":
pods "nginx-baseline" is forbidden: violates PodSecurity "restricted:latest":
allowPrivilegeEscalation != false (container "nginx" must set securityContext.allowPrivilegeEscalation=false),
unrestricted capabilities (container "nginx" must set securityContext.capabilities.drop=["ALL"]),
runAsNonRoot != true (pod or container "nginx" must set securityContext.runAsNonRoot=true),
seccompProfile (pod or container "nginx" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
```

**Step 5: Fix the pod to meet restricted requirements**

The error tells us exactly what's needed. Deploy the restricted-compliant pod:

```bash
# Deploy pod that meets all restricted requirements
kubectl apply -f labs/admission/specs/ckad/exercise2-pod-restricted-compliant.yaml

# Verify it's running
kubectl get pod nginx-restricted -n secure-app
# NAME               READY   STATUS    RESTARTS   AGE
# nginx-restricted   1/1     Running   0          8s
```

**What changed for restricted compliance:**

```yaml
spec:
  # 1. Pod must run as non-root
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
    # 2. Seccomp profile required
    seccompProfile:
      type: RuntimeDefault

  containers:
  - name: nginx
    # 3. Must use non-root image (standard nginx runs as root)
    image: nginxinc/nginx-unprivileged:alpine

    securityContext:
      # 4. Must explicitly disable privilege escalation
      allowPrivilegeEscalation: false

      # 5. Must drop ALL capabilities
      capabilities:
        drop:
        - ALL
```

**Step 6: Deploy a multi-replica Deployment with restricted policy**

```bash
# Deploy a full application
kubectl apply -f labs/admission/specs/ckad/exercise2-deployment-restricted.yaml

# Verify all pods are running
kubectl get deploy secure-web -n secure-app
# NAME         READY   UP-TO-DATE   AVAILABLE   AGE
# secure-web   2/2     2            2           15s

kubectl get pods -n secure-app -l app=secure-web
# NAME                          READY   STATUS    RESTARTS   AGE
# secure-web-xxxxxxxxxx-xxxxx   1/1     Running   0          15s
# secure-web-xxxxxxxxxx-xxxxx   1/1     Running   0          15s
```

**Testing the application:**

```bash
# Port-forward to test
kubectl port-forward deploy/secure-web 8080:8080 -n secure-app

# In another terminal
curl localhost:8080
# Should return nginx welcome page
```

**Step 7: Understanding enforcement modes**

You can use multiple modes together:

```bash
# Enforce baseline, but warn and audit for restricted
kubectl label namespace secure-app \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted \
  --overwrite

# Now baseline is enforced (blocks violations)
# But you get warnings for restricted violations
kubectl apply -f labs/admission/specs/ckad/exercise2-pod-baseline-compliant.yaml

# You'll see a warning but pod is created:
# Warning: would violate PodSecurity "restricted:latest": ...
# pod/nginx-baseline created
```

**Key Learnings:**

1. **Pod Security Standards are namespace-scoped** - Set via labels
2. **Three levels**: privileged (unrestricted), baseline (minimal), restricted (hardened)
3. **Three modes**: enforce (block), warn (show warning), audit (log only)
4. **Baseline prevents**: hostNetwork, hostPID, hostIPC, privileged, hostPath
5. **Restricted requires**: runAsNonRoot, drop ALL capabilities, no privilege escalation, seccomp profile
6. **Standard images may not work** - Many run as root (need nginx-unprivileged, etc.)
7. **Policies apply at creation** - Existing pods aren't affected by label changes
8. **Error messages are detailed** - They list every requirement that's not met
9. **Use warn mode to test** - Before enforcing restricted, use warn to find issues

**Common Issues and Fixes:**

| Error | Fix |
|-------|-----|
| `hostNetwork=true` | Remove or set to `false` |
| `allowPrivilegeEscalation != false` | Add `securityContext.allowPrivilegeEscalation: false` |
| `runAsNonRoot != true` | Add `securityContext.runAsNonRoot: true` and `runAsUser: 1000` |
| `unrestricted capabilities` | Add `capabilities: {drop: [ALL]}` |
| `seccompProfile` not set | Add `securityContext.seccompProfile: {type: RuntimeDefault}` |
| Image runs as root | Use non-root variants: `nginx-unprivileged`, `redis:alpine` with user flag |

**Cleanup:**

```bash
kubectl delete namespace secure-app
```

</details><br />

### Exercise 3: ResourceQuota Troubleshooting

Given:
- Namespace with ResourceQuota
- Deployment that partially scales

Tasks:
1. Identify why only some pods are created
2. Check quota usage
3. Fix by adjusting resources or quota

<details>
  <summary>Complete Solution</summary>

**Step 1: Create namespace and apply ResourceQuota**

```bash
# Create the namespace
kubectl create namespace quota-demo

# Apply the ResourceQuota
kubectl apply -f labs/admission/specs/ckad/exercise3-quota.yaml

# Verify quota is created
kubectl describe resourcequota compute-quota -n quota-demo
```

The quota shows:

```
Name:            compute-quota
Namespace:       quota-demo
Resource         Used  Hard
--------         ----  ----
limits.cpu       0     4
limits.memory    0     8Gi
pods             0     10
requests.cpu     0     2
requests.memory  0     4Gi
```

**Understanding the quota:**
- Maximum 10 pods
- Total CPU requests: 2 cores
- Total CPU limits: 4 cores
- Total memory requests: 4Gi
- Total memory limits: 8Gi

**Step 2: Deploy an application that exceeds quota**

```bash
# Deploy web-app with 5 replicas
kubectl apply -f labs/admission/specs/ckad/exercise3-deployment-partial.yaml

# Check the deployment
kubectl get deploy web-app -n quota-demo
# NAME      READY   UP-TO-DATE   AVAILABLE   AGE
# web-app   4/5     4            4           20s
```

**Problem:** Only 4 out of 5 pods are created!

**Step 3: Identify the issue**

Check the ReplicaSet events:

```bash
# Get ReplicaSet
kubectl get rs -n quota-demo

# Describe to see errors
kubectl describe rs -n quota-demo
```

You'll see an error in events:

```
Warning  FailedCreate  10s (x5 over 30s)  replicaset-controller
  Error creating: pods "web-app-xxxxx" is forbidden: exceeded quota: compute-quota,
  requested: requests.cpu=500m, used: requests.cpu=2, limited: requests.cpu=2
```

**Step 4: Check current quota usage**

```bash
# Detailed quota status
kubectl describe resourcequota compute-quota -n quota-demo
```

Output shows:

```
Resource         Used  Hard
--------         ----  ----
limits.cpu       4     4
limits.memory    4Gi   8Gi
pods             4     10
requests.cpu     2     2      ← At limit!
requests.memory  2Gi   4Gi
```

**Analysis:**
- Each pod requests: CPU=500m, Memory=512Mi
- 4 pods consume: CPU=2000m (2 cores), Memory=2Gi
- The 5th pod needs: CPU=500m more, but quota only allows 2 cores total
- Quota is blocking the 5th pod

**Step 5: Calculate what fits**

```
Current pod resources:
  requests: cpu=500m, memory=512Mi
  limits: cpu=1, memory=1Gi

With 5 replicas:
  Total requests: cpu=2.5, memory=2.5Gi
  Total limits: cpu=5, memory=5Gi

Quota limits:
  requests.cpu: 2 (EXCEEDED by 0.5 cores)
  requests.memory: 4Gi (OK)
  limits.cpu: 4 (EXCEEDED by 1 core)
  limits.memory: 8Gi (OK)
```

**Step 6: Fix Option 1 - Reduce resource requests**

```bash
# Apply deployment with reduced resource requests
kubectl apply -f labs/admission/specs/ckad/exercise3-deployment-fixed.yaml

# Now check the deployment
kubectl get deploy web-app -n quota-demo
# NAME      READY   UP-TO-DATE   AVAILABLE   AGE
# web-app   5/5     5            5           45s

# All 5 pods are now running!
kubectl get pods -n quota-demo
```

**New resource calculation:**
```
Per pod: requests.cpu=200m, limits.cpu=500m
5 pods:  requests.cpu=1, limits.cpu=2.5
Within quota! ✓
```

**Step 7: Verify quota usage**

```bash
kubectl describe resourcequota compute-quota -n quota-demo
```

Now shows:

```
Resource         Used    Hard
--------         ----    ----
limits.cpu       2500m   4
limits.memory    2560Mi  8Gi
pods             5       10
requests.cpu     1       2      ← Plenty of room now
requests.memory  1280Mi  4Gi
```

**Step 8: Test what happens when quota is exceeded**

Deploy another application:

```bash
# Deploy another app
kubectl apply -f labs/admission/specs/ckad/exercise3-other-app.yaml

# Check status
kubectl get deploy api-service -n quota-demo
# NAME          READY   UP-TO-DATE   AVAILABLE   AGE
# api-service   3/3     3            3           10s
```

All 3 pods start because:
```
web-app: 5 pods * 200m = 1 core
api-service: 3 pods * 200m = 0.6 cores
Total: 1.6 cores (within quota of 2 cores)
```

**Step 9: Hit the quota limit**

```bash
# Try to scale web-app to 8 replicas
kubectl scale deploy web-app --replicas=8 -n quota-demo

# Check the deployment
kubectl get deploy web-app -n quota-demo
# NAME      READY   UP-TO-DATE   AVAILABLE   AGE
# web-app   7/8     7            7           5m

# Only 7 pods run - quota exceeded again
```

Check ReplicaSet:

```bash
kubectl describe rs -n quota-demo | grep -A5 "Error creating"
# Error creating: pods "web-app-xxxxx" is forbidden: exceeded quota: compute-quota,
# requested: requests.cpu=200m, used: requests.cpu=1800m, limited: requests.cpu=2
```

**Step 10: Fix Option 2 - Scale down other workloads**

```bash
# Check what's using resources
kubectl describe resourcequota compute-quota -n quota-demo

# Scale down api-service to free up resources
kubectl scale deploy api-service --replicas=1 -n quota-demo

# Wait a moment for pods to terminate
sleep 5

# Now web-app can scale up
kubectl get deploy web-app -n quota-demo
# NAME      READY   UP-TO-DATE   AVAILABLE   AGE
# web-app   8/8     8            8           7m
```

**Step 11: Fix Option 3 - Increase the quota (if you have permission)**

```bash
# Edit the quota
kubectl edit resourcequota compute-quota -n quota-demo

# Change:
#   requests.cpu: "2"
# To:
#   requests.cpu: "3"

# Or apply an updated YAML:
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: quota-demo
spec:
  hard:
    requests.cpu: "3"        # Increased from 2
    requests.memory: 4Gi
    limits.cpu: "6"          # Increased from 4
    limits.memory: 8Gi
    pods: "15"               # Increased from 10
EOF

# Now both deployments can scale as needed
```

**Key Learnings:**

1. **ResourceQuota is enforced at Pod creation time** - Not retroactively
2. **Admission controller blocks Pods that exceed quota** - Not Deployments
3. **Check ReplicaSet events** - That's where quota errors appear
4. **Quota tracks cumulative usage** - All pods in namespace count toward quota
5. **Calculate total resources needed** - Multiply per-pod resources by replica count
6. **Three fix strategies:**
   - Reduce resource requests/limits per pod
   - Scale down other workloads in the namespace
   - Increase the quota (if allowed)
7. **Quotas are namespace-scoped** - Other namespaces unaffected
8. **Use describe resourcequota** - Shows Used vs Hard limits clearly
9. **Pods vs. Resources** - You might have pod quota but hit CPU/memory first
10. **Existing pods keep running** - Even if you later reduce quota

**Common Scenarios:**

| Symptom | Likely Cause | Solution |
|---------|--------------|----------|
| Some replicas missing | Quota exceeded | Check `describe rs` for quota error |
| Can't create any pods | Pod count quota hit | Scale down or increase pod quota |
| Deployment stuck at 0/N | All quotas exceeded | Review `describe resourcequota` |
| First pods work, later fail | Cumulative quota hit | Calculate total resources needed |
| Scaling fails silently | Check ReplicaSet | `describe rs` shows admission errors |

**Troubleshooting Commands:**

```bash
# Check quota status
kubectl describe resourcequota -n <namespace>

# See all resource usage
kubectl top pods -n <namespace>

# Calculate what's consuming quota
kubectl get pods -n <namespace> -o custom-columns=\
NAME:.metadata.name,\
CPU_REQ:.spec.containers[*].resources.requests.cpu,\
MEM_REQ:.spec.containers[*].resources.requests.memory

# Check for quota-related errors
kubectl describe rs -n <namespace> | grep -A3 "exceeded quota"

# See events related to quota
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | grep quota
```

**Cleanup:**

```bash
kubectl delete namespace quota-demo
```

</details><br />

## Exam Tips

1. **Read error messages carefully** - They tell you exactly what's wrong
2. **Check ReplicaSet events for Deployments** - Admission errors appear there
3. **Know Pod Security Standard levels** - privileged, baseline, restricted
4. **Understand ResourceQuota is namespace-scoped**
5. **LimitRange provides defaults** - You might not need to specify limits
6. **Gatekeeper errors start with constraint name** - Look for it in describe
7. **Practice without admission controllers first** - Then add policies
8. **Use dry-run to test** - `kubectl apply --dry-run=server` catches admission errors
9. **Check namespace labels** - Pod Security Standards are set there
10. **Don't write webhook code** - Focus on using/debugging existing policies

## Cleanup

```bash
# Remove Gatekeeper constraints
kubectl delete constraints --all

# Remove constraint templates
kubectl delete constrainttemplates --all

# Remove OPA Gatekeeper
kubectl delete -f labs/admission/specs/opa-gatekeeper

# Remove custom webhooks
kubectl delete validatingwebhookconfigurations --all
kubectl delete mutatingwebhookconfigurations --all

# Clean up namespaces
kubectl delete namespace <test-namespaces>
```

## Next Steps

After understanding admission control for CKAD:
1. Practice [RBAC](../rbac/) - Works with admission for complete security
2. Review [Namespaces](../namespaces/) - ResourceQuota and LimitRange are namespace-scoped
3. Study [SecurityContext](../productionizing/) - Required for Pod Security Standards
4. Practice troubleshooting workflows - Admission errors are common

---

## Study Checklist for CKAD

- [ ] Understand admission controller request flow
- [ ] Recognize admission webhook error message format
- [ ] Know the three Pod Security Standard levels
- [ ] Apply Pod Security Standards to namespaces (labels)
- [ ] Debug Deployment admission failures via ReplicaSet events
- [ ] Check and interpret ResourceQuota status
- [ ] Understand LimitRange defaults and constraints
- [ ] List and describe Gatekeeper constraints
- [ ] Read admission error messages and fix YAML accordingly
- [ ] Use kubectl describe to find admission failures
- [ ] Know common baseline restrictions (no hostNetwork, etc.)
- [ ] Know common restricted requirements (runAsNonRoot, etc.)
- [ ] Check namespace labels for policies
- [ ] Understand quota is enforced at creation time
- [ ] Practice with dry-run to catch admission errors early
