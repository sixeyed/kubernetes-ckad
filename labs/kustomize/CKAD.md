# CKAD Exam Guide: Kustomize

## Why Kustomize Matters for CKAD

**Domain**: Application Deployment (20% of exam)
**Importance**: ⭐⭐⭐⭐⭐ CRITICAL - Explicit exam requirement

Kustomize is a **required topic** for the CKAD exam. You will likely face at least one question requiring you to:
- Create or modify a kustomization.yaml file
- Deploy resources using kubectl apply -k
- Create overlays for different environments
- Understand base and overlay patterns

**Time estimate**: 5-8 minutes per Kustomize question on the exam

---

## Quick Reference for the Exam

### Essential Commands

```bash
# Apply a kustomization (most common)
kubectl apply -k <directory>

# Preview without applying (debugging)
kubectl kustomize <directory>

# Delete kustomization resources
kubectl delete -k <directory>

# Diff to see changes
kubectl diff -k <directory>
```

### Basic kustomization.yaml Structure

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# List of resource files to include
resources:
  - deployment.yaml
  - service.yaml

# Common labels for all resources
commonLabels:
  app: myapp

# Add prefix to all resource names
namePrefix: dev-

# Set namespace for all resources
namespace: development

# Modify replicas
replicas:
  - name: myapp
    count: 3

# Modify images
images:
  - name: nginx
    newTag: 1.21
```

---

## Exam Scenarios You'll Face

### Scenario 1: Create a Kustomization from Existing YAML

**Task**: "You have deployment.yaml and service.yaml. Create a kustomization.yaml that applies both resources with a `prod-` prefix and sets namespace to `production`."

**Solution**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml

namePrefix: prod-
namespace: production
```

**Apply**:
```bash
kubectl apply -k .
```

### Scenario 2: Create Environment-Specific Overlay

**Task**: "Create a prod overlay that references the base/ directory and sets replicas to 5."

**Directory structure**:
```
base/
  kustomization.yaml
  deployment.yaml
overlays/
  prod/
    kustomization.yaml
```

**overlays/prod/kustomization.yaml**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

namePrefix: prod-
namespace: production

replicas:
  - name: myapp
    count: 5
```

### Scenario 3: Patch a Deployment

**Task**: "Add environment variable `ENV=production` to the deployment using a patch."

**Create patch.yaml**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      containers:
        - name: myapp
          env:
            - name: ENV
              value: production
```

**Update kustomization.yaml**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml

patches:
  - path: patch.yaml
```

### Scenario 4: Change Image Tag

**Task**: "Deploy the staging environment with image tag v2.1 instead of the base tag."

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

images:
  - name: myapp
    newTag: v2.1
```

---

## Common Kustomize Transformations (Know These!)

| Transformation | Purpose | Example |
|----------------|---------|---------|
| `namePrefix` | Add prefix to all resources | `namePrefix: dev-` |
| `nameSuffix` | Add suffix to all resources | `nameSuffix: -v2` |
| `namespace` | Set namespace for all resources | `namespace: production` |
| `commonLabels` | Add labels to all resources | `commonLabels: {env: prod}` |
| `commonAnnotations` | Add annotations to all resources | `commonAnnotations: {ver: "1.0"}` |
| `replicas` | Change replica count | `replicas: [{name: app, count: 5}]` |
| `images` | Change image tags | `images: [{name: nginx, newTag: 1.21}]` |

---

## Exam Tips & Time Savers

### ✅ DO This

1. **Use kubectl kustomize first** - Preview output before applying:
   ```bash
   kubectl kustomize overlays/prod > preview.yaml
   # Review preview.yaml
   kubectl apply -k overlays/prod
   ```

2. **Remember the -k flag** - It works with many kubectl commands:
   ```bash
   kubectl apply -k <dir>
   kubectl delete -k <dir>
   kubectl diff -k <dir>
   kubectl get -k <dir>
   ```

3. **Use resources to reference base** - In overlays, always include:
   ```yaml
   resources:
     - ../../base
   ```

4. **Keep it simple** - Use built-in transformations before patches:
   ```yaml
   # Prefer this (built-in)
   replicas:
     - name: myapp
       count: 5

   # Over this (patch)
   patches:
     - patch: |-
         - op: replace
           path: /spec/replicas
           value: 5
   ```

### ❌ DON'T Do This

1. **Don't forget apiVersion** - Always include at the top:
   ```yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   ```

2. **Don't use absolute paths** - Use relative paths in resources:
   ```yaml
   # ✅ Correct
   resources:
     - ../../base

   # ❌ Wrong
   resources:
     - /home/user/base
   ```

3. **Don't create overlays without resources** - Always reference what you're overlaying:
   ```yaml
   # ❌ Missing resources reference
   namePrefix: prod-

   # ✅ Correct
   resources:
     - ../../base
   namePrefix: prod-
   ```

---

## Troubleshooting on the Exam

### Error: "no matches for kind"

**Cause**: Missing apiVersion or kind in kustomization.yaml
**Fix**: Add the header:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
```

### Error: "unable to find one or more files"

**Cause**: Incorrect path in resources or patches
**Fix**: Check relative paths, use `ls` to verify files exist

### Error: "resource already exists"

**Cause**: Resources already applied, name collision
**Fix**: Either delete existing resources or use different namePrefix

### Resources not in expected namespace

**Cause**: Forgot to set namespace in overlay
**Fix**: Add `namespace: <namespace-name>` to kustomization.yaml

---

## Kustomize vs Helm (Know the Difference!)

Both are in CKAD curriculum. Here's when to use each:

| Aspect | Kustomize | Helm |
|--------|-----------|------|
| **Use in Exam** | Environment configs (dev/staging/prod) | Installing packaged apps |
| **Command** | `kubectl apply -k` | `helm install` |
| **Syntax** | Standard YAML | Go templates |
| **Built-in** | Yes (kubectl 1.14+) | No, separate tool |
| **Best for** | Same app, multiple environments | Distributing reusable apps |

**Exam Tip**: If the question mentions "dev, staging, prod environments" → think Kustomize!

---

## Practice Scenarios (Time Yourself: 7 minutes each)

### Practice 1: Basic Kustomization

Create a kustomization that:
- Includes deployment.yaml and service.yaml
- Sets namespace to `test`
- Adds prefix `test-`
- Sets replicas to 3

<details>
<summary>Solution</summary>

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml

namespace: test
namePrefix: test-
replicas:
  - name: myapp
    count: 3
```

```bash
kubectl apply -k .
```
</details>

### Practice 2: Overlay Pattern

Given a base/ directory with resources, create an overlay:
- Directory: overlays/dev
- Namespace: development
- Prefix: dev-
- Image tag: v1-dev

<details>
<summary>Solution</summary>

```yaml
# overlays/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

namespace: development
namePrefix: dev-

images:
  - name: myapp
    newTag: v1-dev
```

```bash
kubectl apply -k overlays/dev
```
</details>

### Practice 3: Quick Deployment Change

Change the image tag of an existing kustomization from v1 to v2 and reapply.

<details>
<summary>Solution</summary>

Add or update in kustomization.yaml:
```yaml
images:
  - name: myapp
    newTag: v2
```

```bash
kubectl apply -k .
```
</details>

---

## Exam Day Checklist

Before attempting a Kustomize question:

- [ ] **Read carefully** - Note the environment (dev/staging/prod)
- [ ] **Check namespace** - Is a specific namespace required?
- [ ] **Verify paths** - Are you in the right directory?
- [ ] **Preview first** - Use `kubectl kustomize .` to check output
- [ ] **Apply** - Use `kubectl apply -k <directory>`
- [ ] **Verify** - Check that resources are created correctly

---

## Key Points to Remember

1. **Kustomize is built into kubectl** (kubectl apply -k)
2. **Base + Overlays pattern** for environment management
3. **No templating** - works with standard YAML
4. **Common transformations**: namePrefix, namespace, replicas, images
5. **Relative paths** in resources and patches
6. **Preview with kubectl kustomize** before applying
7. **Different from Helm** - know when to use which

---

## Time Management

**Typical exam question**: 6-8 minutes

| Task | Time |
|------|------|
| Read requirements | 1 min |
| Create/modify kustomization.yaml | 3-4 min |
| Apply and verify | 2-3 min |

If stuck beyond 8 minutes → **flag and move on**. Come back later.

---

## Additional Resources

During the exam you can access:
- [Kustomize Documentation](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/)
- [Kustomization Reference](https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/)

**Bookmark these** before the exam!

---

## Summary

✅ **Master these for CKAD**:
- Creating kustomization.yaml files
- Base and overlay pattern
- Using kubectl apply -k
- Common transformations (namespace, namePrefix, replicas, images)
- Understanding when to use Kustomize vs Helm

🎯 **Exam weight**: 20% of total score (Application Deployment domain)
⏱️ **Time per question**: 6-8 minutes
📊 **Difficulty**: Medium (with practice)

Practice this lab multiple times until you can complete the exercises in under 10 minutes!

## Deep Dive: Base and Overlay Pattern

The base and overlay pattern is fundamental to Kustomize and commonly appears on the CKAD exam.

### Understanding the Pattern

**Base**: Contains your core application manifests that are common across all environments.

```
base/
├── kustomization.yaml
├── deployment.yaml
├── service.yaml
└── configmap.yaml
```

**Overlay**: Contains environment-specific customizations that build on the base.

```
overlays/
├── development/
│   ├── kustomization.yaml
│   └── replica-count.yaml
├── staging/
│   ├── kustomization.yaml
│   └── resource-limits.yaml
└── production/
    ├── kustomization.yaml
    ├── replica-count.yaml
    └── resource-limits.yaml
```

### Creating a Complete Base

Here's a realistic base configuration for a web application:

**base/deployment.yaml**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  labels:
    app: webapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: webapp
        image: nginx:1.21
        ports:
        - containerPort: 80
        env:
        - name: ENVIRONMENT
          value: "base"
```

**base/service.yaml**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp
spec:
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

**base/configmap.yaml**:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config
data:
  app.conf: |
    server {
      listen 80;
      server_name localhost;
    }
```

**base/kustomization.yaml**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml

commonLabels:
  app: webapp
  managed-by: kustomize
```

## Exercise 1: Create Development Overlay

**Task**: Create a development overlay that:
1. References the base configuration
2. Sets namespace to `development`
3. Adds prefix `dev-`
4. Changes replicas to 2
5. Changes image tag to `1.22`
6. Adds label `environment: dev`

<details>
  <summary>Step-by-Step Solution</summary>

**Step 1: Create directory structure**

```bash
mkdir -p overlays/development
```

**Step 2: Create the kustomization file**

Create `overlays/development/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Reference to base
resources:
  - ../../base

# Environment-specific namespace
namespace: development

# Add prefix to resource names
namePrefix: dev-

# Add environment label
commonLabels:
  environment: dev

# Change replica count
replicas:
  - name: webapp
    count: 2

# Change image tag
images:
  - name: nginx
    newTag: "1.22"
```

**Step 3: Preview the output**

```bash
# Preview what will be created
kubectl kustomize overlays/development

# Save to file for review
kubectl kustomize overlays/development > dev-preview.yaml
cat dev-preview.yaml
```

**Step 4: Apply the development overlay**

```bash
# Create namespace first
kubectl create namespace development

# Apply the kustomization
kubectl apply -k overlays/development

# Verify deployment
kubectl get all -n development
kubectl get deployment -n development dev-webapp -o yaml | grep -E '(replicas|image:)'
```

**Expected Output**:
- Deployment named `dev-webapp` in `development` namespace
- 2 replicas
- Image `nginx:1.22`
- All resources have `environment: dev` label

**Step 5: Test the application**

```bash
# Check pods
kubectl get pods -n development -l environment=dev

# Check service
kubectl get svc -n development dev-webapp

# Port-forward to test (if needed)
kubectl port-forward -n development svc/dev-webapp 8080:80
curl localhost:8080
```

</details><br />

## Exercise 2: Create Production Overlay with Patches

**Task**: Create a production overlay that:
1. References the base
2. Sets namespace to `production`
3. Adds prefix `prod-`
4. Sets replicas to 5
5. Adds resource limits and requests
6. Adds environment variable `ENVIRONMENT=production`
7. Uses a strategic merge patch for the environment variable

<details>
  <summary>Step-by-Step Solution</summary>

**Step 1: Create directory**

```bash
mkdir -p overlays/production
```

**Step 2: Create environment variable patch**

Create `overlays/production/env-patch.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  template:
    spec:
      containers:
      - name: webapp
        env:
        - name: ENVIRONMENT
          value: "production"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
```

**Step 3: Create kustomization**

Create `overlays/production/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Reference base
resources:
  - ../../base

# Production namespace
namespace: production

# Prefix for production
namePrefix: prod-

# Production labels
commonLabels:
  environment: production
  tier: frontend

# Set high replica count for production
replicas:
  - name: webapp
    count: 5

# Use stable image tag
images:
  - name: nginx
    newTag: "1.21.6"

# Apply strategic merge patch
patches:
  - path: env-patch.yaml
```

**Step 4: Apply production overlay**

```bash
# Create namespace
kubectl create namespace production

# Preview first
kubectl kustomize overlays/production | head -50

# Apply
kubectl apply -k overlays/production

# Verify
kubectl get deployment -n production prod-webapp -o yaml
```

**Step 5: Verify all customizations**

```bash
# Check replicas
kubectl get deployment -n production prod-webapp -o jsonpath='{.spec.replicas}'
# Should show: 5

# Check image
kubectl get deployment -n production prod-webapp -o jsonpath='{.spec.template.spec.containers[0].image}'
# Should show: nginx:1.21.6

# Check environment variable
kubectl get deployment -n production prod-webapp -o jsonpath='{.spec.template.spec.containers[0].env}'

# Check resources
kubectl get deployment -n production prod-webapp -o jsonpath='{.spec.template.spec.containers[0].resources}'

# Check labels
kubectl get deployment -n production prod-webapp --show-labels
# Should include: environment=production,tier=frontend
```

</details><br />

## Exercise 3: Multi-Environment Deployment

**Scenario**: You have a base configuration and need to deploy to three environments simultaneously: dev, staging, and prod, each with different configurations.

**Requirements**:

| Environment | Namespace | Prefix | Replicas | Image Tag | Service Type |
|-------------|-----------|--------|----------|-----------|--------------|
| Development | development | dev- | 1 | latest | ClusterIP |
| Staging | staging | stg- | 3 | v2.0 | ClusterIP |
| Production | production | prod- | 5 | v2.0 | NodePort (30080) |

<details>
  <summary>Complete Solution</summary>

**Step 1: Create all directory structures**

```bash
mkdir -p overlays/{development,staging,production}
```

**Step 2: Development overlay**

Create `overlays/development/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

namespace: development
namePrefix: dev-

replicas:
  - name: webapp
    count: 1

images:
  - name: nginx
    newTag: latest

commonLabels:
  environment: development
```

**Step 3: Staging overlay**

Create `overlays/staging/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

namespace: staging
namePrefix: stg-

replicas:
  - name: webapp
    count: 3

images:
  - name: nginx
    newTag: v2.0

commonLabels:
  environment: staging
```

**Step 4: Production overlay with service patch**

Create `overlays/production/service-patch.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
```

Create `overlays/production/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

namespace: production
namePrefix: prod-

replicas:
  - name: webapp
    count: 5

images:
  - name: nginx
    newTag: v2.0

commonLabels:
  environment: production
  tier: critical

patches:
  - path: service-patch.yaml
```

**Step 5: Deploy all environments**

```bash
# Create namespaces
kubectl create namespace development
kubectl create namespace staging
kubectl create namespace production

# Deploy to all environments
kubectl apply -k overlays/development
kubectl apply -k overlays/staging
kubectl apply -k overlays/production

# Verify all deployments
kubectl get deployments --all-namespaces -l managed-by=kustomize

# Compare configurations
echo "=== Development ==="
kubectl get deployment -n development dev-webapp -o jsonpath='{.spec.replicas}'
echo ""

echo "=== Staging ==="
kubectl get deployment -n staging stg-webapp -o jsonpath='{.spec.replicas}'
echo ""

echo "=== Production ==="
kubectl get deployment -n production prod-webapp -o jsonpath='{.spec.replicas}'
echo ""

# Check services
kubectl get svc --all-namespaces -l managed-by=kustomize
```

**Step 6: Cleanup**

```bash
# Remove all environments
kubectl delete -k overlays/development
kubectl delete -k overlays/staging
kubectl delete -k overlays/production

# Remove namespaces
kubectl delete namespace development staging production
```

**Key Learnings**:
1. Same base configuration deployed to multiple environments
2. Each environment has unique customizations
3. Kustomize ensures consistency while allowing flexibility
4. Easy to manage and version control
5. No template syntax required - just YAML

</details><br />

## Advanced Kustomize Features

### ConfigMap and Secret Generators

Kustomize can generate ConfigMaps and Secrets from files or literals:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Generate ConfigMap from file
configMapGenerator:
  - name: app-config
    files:
      - config.properties
    # Or from literals
  - name: app-env
    literals:
      - ENV=production
      - DEBUG=false

# Generate Secret from files
secretGenerator:
  - name: db-credentials
    files:
      - username.txt
      - password.txt
    # Or from literals
  - name: api-keys
    literals:
      - API_KEY=secret123
    type: Opaque
```

**CKAD Tip**: Generators automatically add a hash suffix to names, ensuring pods restart when config changes.

### JSON Patches

For complex modifications, use JSON patches:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml

patches:
  - target:
      kind: Deployment
      name: webapp
    patch: |-
      - op: add
        path: /spec/template/spec/containers/0/env/-
        value:
          name: NEW_VAR
          value: "new_value"
```

### Patch Strategies

Kustomize supports multiple patch strategies:

1. **Strategic Merge Patch** (default for most resources)
2. **JSON Patch** (for precise modifications)
3. **Merge Patch** (simple merges)

**Example - Strategic Merge**:

```yaml
# patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  template:
    spec:
      containers:
      - name: webapp
        env:
        - name: LOG_LEVEL
          value: debug
```

```yaml
# kustomization.yaml
patches:
  - path: patch.yaml
```

## Troubleshooting Advanced Scenarios

### Issue 1: Patch Not Applied

**Symptom**: Patch file exists but changes don't appear in output

**Debugging**:

```bash
# Check if patch is listed
cat kustomization.yaml | grep -A5 patches

# Preview output
kubectl kustomize . | grep -A10 "kind: Deployment"

# Verify patch syntax
kubectl kustomize . > output.yaml
cat output.yaml
```

**Common Causes**:
1. Wrong resource name in patch
2. Incorrect path in patch file reference
3. Typo in kustomization.yaml

**Fix**:

```yaml
# Ensure names match exactly
# Base deployment.yaml
metadata:
  name: webapp

# Patch file
metadata:
  name: webapp  # Must match exactly

# kustomization.yaml
patches:
  - path: patch.yaml  # Correct relative path
```

### Issue 2: Multiple Bases or Resources

**Symptom**: Need to include multiple bases or external resources

**Solution**:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  # Multiple bases
  - ../../base/app
  - ../../base/database

  # External resources from URL
  - https://raw.githubusercontent.com/kubernetes/website/main/content/en/examples/application/deployment.yaml

  # Local files
  - extra-configmap.yaml
  - extra-secret.yaml
```

### Issue 3: ConfigMap Changes Not Triggering Pod Restart

**Problem**: Updated ConfigMap but pods still use old config

**Solution**: Use ConfigMap generator which adds hash suffix

```yaml
# Before (manual ConfigMap)
resources:
  - configmap.yaml  # Pods won't restart on changes

# After (generator)
configMapGenerator:
  - name: app-config
    files:
      - config.properties
# Generates: app-config-<hash>
# New hash triggers pod restart
```

### Issue 4: Name Collision After Applying Prefix/Suffix

**Symptom**: Resources have unexpected names or conflicts

**Debugging**:

```bash
# Preview exact names that will be created
kubectl kustomize . | grep "name:"

# Check existing resources
kubectl get all -n <namespace>
```

**Fix**: Ensure namePrefix/nameSuffix don't create collisions

```yaml
# Problematic
namePrefix: prod-
# If base has: prod-webapp
# Result: prod-prod-webapp

# Better
namePrefix: v2-
# Result: v2-webapp
```

## Common CKAD Kustomize Patterns

### Pattern 1: Quick Replica Change

**Question**: "Scale the deployment in the production overlay to 10 replicas"

**Approach**:
```bash
# Edit overlays/production/kustomization.yaml
# Add or update:
replicas:
  - name: <deployment-name>
    count: 10

# Apply
kubectl apply -k overlays/production
```

### Pattern 2: Environment Variable Injection

**Question**: "Add environment variable DATABASE_HOST=db.prod.svc to production deployment"

**Approach**:
```yaml
# Create patch file: overlays/production/env-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <deployment-name>
spec:
  template:
    spec:
      containers:
      - name: <container-name>
        env:
        - name: DATABASE_HOST
          value: db.prod.svc

# Add to kustomization.yaml:
patches:
  - path: env-patch.yaml
```

### Pattern 3: Change Service Type

**Question**: "Expose the staging service as NodePort on port 30090"

**Approach**:
```yaml
# Create: overlays/staging/service-patch.yaml
apiVersion: v1
kind: Service
metadata:
  name: <service-name>
spec:
  type: NodePort
  ports:
  - port: 80
    nodePort: 30090

# Add to kustomization.yaml:
patches:
  - path: service-patch.yaml
```

### Pattern 4: Multiple Image Tags

**Question**: "Update frontend image to v2.1 and backend image to v3.0"

**Approach**:
```yaml
images:
  - name: frontend
    newTag: v2.1
  - name: backend
    newTag: v3.0
```

## Real-World CKAD Scenario

**Exam Question**:
"You have a base application in `/opt/app/base` with a Deployment and Service. Create a production overlay in `/opt/app/overlays/production` that:
- Deploys to the `production` namespace
- Uses prefix `prod-`
- Sets 3 replicas
- Changes the image from `app:latest` to `app:v1.0.0`
- Adds label `tier: critical`
- Changes Service type to NodePort on port 30100
- Apply the configuration and verify"

<details>
  <summary>Complete Exam Solution</summary>

```bash
# Step 1: Examine base
cd /opt/app/base
ls
cat kustomization.yaml
cat deployment.yaml

# Step 2: Create production overlay directory
mkdir -p /opt/app/overlays/production
cd /opt/app/overlays/production

# Step 3: Create service patch
cat <<EOF > service-patch.yaml
apiVersion: v1
kind: Service
metadata:
  name: app  # Must match base service name
spec:
  type: NodePort
  ports:
  - port: 80
    nodePort: 30100
EOF

# Step 4: Create kustomization.yaml
cat <<EOF > kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

namespace: production
namePrefix: prod-

replicas:
  - name: app  # Must match base deployment name
    count: 3

images:
  - name: app
    newTag: v1.0.0

commonLabels:
  tier: critical

patches:
  - path: service-patch.yaml
EOF

# Step 5: Preview
kubectl kustomize /opt/app/overlays/production

# Step 6: Create namespace
kubectl create namespace production

# Step 7: Apply
kubectl apply -k /opt/app/overlays/production

# Step 8: Verify
kubectl get all -n production
kubectl get deployment -n production prod-app -o yaml | grep -E '(replicas|image:|tier)'
kubectl get svc -n production prod-app -o yaml | grep -E '(type|nodePort)'

# Step 9: Test the service
curl localhost:30100
```

**Time Taken**: Should complete in 6-8 minutes

</details><br />

## Exam Strategy for Kustomize

1. **Read the question twice** - Note all requirements
2. **Check if base exists** - Don't create base if it's already there
3. **Create overlay directory** - `mkdir -p overlays/<env>`
4. **Start with kustomization.yaml** - Get the structure right first
5. **Use built-in fields first** - replicas, images, namespace, namePrefix
6. **Patches for complex changes** - Environment variables, resources, service type
7. **Preview before applying** - `kubectl kustomize .`
8. **Create namespace** - Don't forget this step!
9. **Apply and verify** - `kubectl apply -k` then `kubectl get`
10. **Check all requirements** - Verify each requirement is met

## Kustomize Cheat Sheet for CKAD

```bash
# Essential Commands
kubectl apply -k <dir>              # Apply kustomization
kubectl kustomize <dir>             # Preview output
kubectl delete -k <dir>             # Delete resources
kubectl diff -k <dir>               # Show diff

# Common Transformations
namespace: <namespace>              # Set namespace
namePrefix: <prefix>-               # Add name prefix
nameSuffix: -<suffix>               # Add name suffix
commonLabels: {key: value}          # Add labels
replicas: [{name: app, count: N}]   # Set replicas
images: [{name: img, newTag: tag}]  # Change image tag

# Directory Structure
base/
  kustomization.yaml
  deployment.yaml
  service.yaml
overlays/
  dev/
    kustomization.yaml
  prod/
    kustomization.yaml
    patches/
```

## Final Practice Exercise

Complete this exercise without looking at solutions to test your readiness:

**Task**: Create a complete Kustomize setup for a web application:

1. Create base with Deployment (nginx:1.21, 1 replica) and Service (ClusterIP)
2. Create dev overlay: namespace=dev, prefix=dev-, replicas=1, tag=latest
3. Create prod overlay: namespace=prod, prefix=prod-, replicas=5, tag=1.21.6, NodePort=30200
4. Deploy both environments
5. Verify configurations
6. Clean up

**Time limit**: 10 minutes

<details>
  <summary>Check Your Solution</summary>

If you completed this in under 10 minutes with all requirements met, you're ready for the CKAD exam Kustomize questions!

Key points to verify:
- Both overlays reference ../../base correctly
- Correct replica counts
- Correct image tags
- Correct service types
- Resources deployed to correct namespaces
- All resources have correct prefixes

</details><br />

## Summary

Kustomize is a powerful, template-free way to manage Kubernetes configurations across environments. For CKAD:

✅ **Must Know**:
- Base and overlay pattern
- Creating kustomization.yaml files
- Using `kubectl apply -k`
- Common transformations (replicas, images, namespace, namePrefix)
- Strategic merge patches
- Debugging kustomization output

🎯 **Exam Tips**:
- Preview with `kubectl kustomize` before applying
- Use relative paths in resources
- Built-in transformations before patches
- Verify all requirements before moving on
- Practice until you can complete exercises in < 10 minutes

With solid practice on the exercises above, you'll be well-prepared for any Kustomize question on the CKAD exam!
