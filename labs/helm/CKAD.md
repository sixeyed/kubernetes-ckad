# Helm for CKAD

This document extends the [basic Helm lab](README.md) with CKAD exam-specific scenarios and requirements.

## CKAD Exam Context

Helm is listed as a supplementary topic for CKAD - you don't need deep expertise, but you should understand:
- What Helm is and why it's used
- How to install and upgrade releases from charts
- How to customize values when deploying
- Basic troubleshooting of Helm releases
- Understanding of Helm vs kubectl deployment
- Working with chart repositories

**Exam Tip:** Helm questions are typically straightforward - install a chart with specific values or troubleshoot a failed release. Focus on the CLI commands rather than creating charts.

## What is Helm?

Helm is a package manager for Kubernetes, similar to apt/yum for Linux or npm for Node.js.

### Core Concepts

**Chart**: A Helm package containing Kubernetes resource templates
**Release**: An instance of a chart running in a cluster
**Repository**: A collection of charts (like Docker Hub for applications)
**Values**: Configuration parameters that customize a chart

### Why Helm Matters for CKAD

1. **Simplifies deployment** - One command instead of multiple kubectl applies
2. **Parameterization** - Same chart works across environments
3. **Versioning** - Track and rollback application versions
4. **Third-party apps** - Easy installation of complex applications (Prometheus, Nginx Ingress, etc.)
5. **Release management** - Upgrade, rollback, and uninstall as a unit

## Installing Helm CLI

Before using Helm, you need the CLI installed:

```bash
# Check if Helm is installed
helm version

# If not installed, install it
# On Linux:
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

# On macOS:
brew install helm

# On Windows:
choco install kubernetes-helm
```

**Exam Note:** Helm should already be installed on the exam environment.

## Basic Helm Commands for CKAD

### Install a Release

```bash
# Install from local chart directory
helm install <release-name> <chart-path>

# Install from repository
helm install <release-name> <repo>/<chart>

# Install with custom values
helm install <release-name> <chart> --set key=value

# Install with values file
helm install <release-name> <chart> -f values.yaml

# Install in specific namespace
helm install <release-name> <chart> -n <namespace> --create-namespace
```

### List Releases

```bash
# List releases in current namespace
helm list

# List all releases in all namespaces
helm list --all-namespaces

# Short form
helm ls -A
```

### Get Release Information

```bash
# Get release status
helm status <release-name>

# Get release values (what was configured)
helm get values <release-name>

# Get release manifest (actual Kubernetes YAML)
helm get manifest <release-name>

# Get full release details
helm get all <release-name>
```

### Upgrade a Release

```bash
# Upgrade with new values
helm upgrade <release-name> <chart> --set key=newvalue

# Upgrade and reuse previous values
helm upgrade <release-name> <chart> --reuse-values

# Upgrade with values file
helm upgrade <release-name> <chart> -f values.yaml
```

### Rollback a Release

```bash
# View release history
helm history <release-name>

# Rollback to previous version
helm rollback <release-name>

# Rollback to specific revision
helm rollback <release-name> <revision>
```

### Uninstall a Release

```bash
# Uninstall (remove) a release
helm uninstall <release-name>

# Uninstall from specific namespace
helm uninstall <release-name> -n <namespace>

# Keep history after uninstall
helm uninstall <release-name> --keep-history
```

### Working with Repositories

```bash
# List configured repositories
helm repo list

# Add a repository
helm repo add <repo-name> <repo-url>

# Update repository index
helm repo update

# Search for charts
helm search repo <keyword>

# Search for charts with versions
helm search repo <chart> --versions
```

### Inspect Charts

```bash
# Show chart information
helm show chart <repo>/<chart>

# Show chart README
helm show readme <repo>/<chart>

# Show default values
helm show values <repo>/<chart>

# Show all chart information
helm show all <repo>/<chart>
```

## Common Helm Repositories for CKAD

### Official Helm Stable Repository (Deprecated)

The old "stable" repo is deprecated. Use project-specific repos instead.

### Popular Repositories

```bash
# Bitnami (very popular for common apps)
helm repo add bitnami https://charts.bitnami.com/bitnami

# Prometheus Community
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Nginx Ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

# Jetstack (for cert-manager)
helm repo add jetstack https://charts.jetstack.io

# Update after adding repos
helm repo update
```

## CKAD Scenario 1: Installing a Chart with Custom Values

**Task:** Install a release of nginx from the bitnami repository, naming it `web-server`, with 2 replicas and a NodePort service on port 30080.

<details>
  <summary>Solution</summary>

```bash
# Add bitnami repo if not already added
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Check default values to know parameter names
helm show values bitnami/nginx | grep -A5 replicaCount
helm show values bitnami/nginx | grep -A10 service

# Install with custom values
helm install web-server bitnami/nginx \
  --set replicaCount=2 \
  --set service.type=NodePort \
  --set service.nodePorts.http=30080

# Verify installation
helm list
kubectl get pods,svc -l app.kubernetes.io/instance=web-server
```

**Alternative using values file:**

```bash
# Create values file
cat <<EOF > nginx-values.yaml
replicaCount: 2
service:
  type: NodePort
  nodePorts:
    http: 30080
EOF

# Install with values file
helm install web-server bitnami/nginx -f nginx-values.yaml
```

</details><br />

## CKAD Scenario 2: Upgrading a Release

**Task:** The `web-server` release is running with 2 replicas. Upgrade it to 3 replicas while keeping all other settings.

<details>
  <summary>Solution</summary>

```bash
# Check current values
helm get values web-server

# Upgrade with reuse-values to keep existing settings
helm upgrade web-server bitnami/nginx \
  --reuse-values \
  --set replicaCount=3

# Verify upgrade
helm list
kubectl get pods -l app.kubernetes.io/instance=web-server

# Check history
helm history web-server
```

**Common Mistake:**

```bash
# ❌ This will reset other values to defaults
helm upgrade web-server bitnami/nginx --set replicaCount=3

# ✅ This preserves previous custom values
helm upgrade web-server bitnami/nginx --reuse-values --set replicaCount=3
```

</details><br />

## CKAD Scenario 3: Rolling Back a Release

**Task:** The latest upgrade of `web-server` introduced issues. Roll back to the previous working version.

<details>
  <summary>Solution</summary>

```bash
# Check release history
helm history web-server

# Shows output like:
# REVISION  STATUS      DESCRIPTION
# 1         superseded  Install complete
# 2         deployed    Upgrade complete

# Rollback to previous revision
helm rollback web-server

# Or rollback to specific revision
helm rollback web-server 1

# Verify rollback
helm history web-server
kubectl get pods -l app.kubernetes.io/instance=web-server

# Check that revision 3 is now the rollback
# REVISION  STATUS      DESCRIPTION
# 1         superseded  Install complete
# 2         superseded  Upgrade complete
# 3         deployed    Rollback to 1
```

</details><br />

## CKAD Scenario 4: Finding and Installing from Repository

**Task:** Find a Redis chart in the bitnami repository, check its default values, and install it with authentication disabled.

<details>
  <summary>Solution</summary>

```bash
# Search for redis charts
helm search repo redis

# Shows multiple results, we want bitnami/redis

# Check default values
helm show values bitnami/redis | less

# Look for authentication settings (usually auth.enabled)
helm show values bitnami/redis | grep -A5 auth

# Install with authentication disabled
helm install my-redis bitnami/redis --set auth.enabled=false

# Verify installation
helm list
kubectl get all -l app.kubernetes.io/instance=my-redis

# Test connection (from within cluster)
kubectl run redis-client --rm -it --image=redis -- redis-cli -h my-redis-master
```

</details><br />

## CKAD Scenario 5: Troubleshooting Failed Installation

**Task:** A Helm installation failed. Identify why and fix it.

<details>
  <summary>Solution</summary>

```bash
# Attempt installation that might fail
helm install broken-app some-chart

# Check status
helm status broken-app

# If the release is in failed state, check events
kubectl get events --sort-by='.lastTimestamp'

# Get the manifest to see what was attempted
helm get manifest broken-app

# Check pods if any were created
kubectl get pods -l app.kubernetes.io/instance=broken-app

# Describe pods to see errors
kubectl describe pod <pod-name>

# Common issues:
# 1. Image pull errors - wrong image name/tag
# 2. Resource limits exceeded - adjust values
# 3. Missing dependencies - install prerequisites first
# 4. Namespace issues - ensure namespace exists

# Fix and upgrade (or uninstall and reinstall)
helm uninstall broken-app
helm install broken-app some-chart --set <correct-values>
```

</details><br />

## Understanding Helm Charts Structure

While you won't create charts on the CKAD exam, understanding the structure helps with troubleshooting:

```
chart-name/
├── Chart.yaml          # Chart metadata (name, version, description)
├── values.yaml         # Default configuration values
├── templates/          # Kubernetes manifest templates
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   └── _helpers.tpl   # Template helpers
└── charts/             # Dependent charts (optional)
```

### Chart.yaml Example

```yaml
apiVersion: v2
name: my-app
description: A Helm chart for my application
version: 1.0.0        # Chart version
appVersion: "2.0.0"   # Application version
```

### values.yaml Example

```yaml
replicaCount: 2

image:
  repository: nginx
  tag: "1.21"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

### Template Example

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-deployment
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        ports:
        - containerPort: 80
        resources:
          {{- toYaml .Values.resources | nindent 10 }}
```

### Template Variables

Common template variables you might see:

| Variable | Description | Example |
|----------|-------------|---------|
| `.Release.Name` | Name given to release | `my-app` |
| `.Release.Namespace` | Namespace of release | `default` |
| `.Chart.Name` | Name from Chart.yaml | `nginx` |
| `.Chart.Version` | Chart version | `1.0.0` |
| `.Values.<key>` | Value from values.yaml | `.Values.replicaCount` |

## Helm vs kubectl: When to Use Each

### Use Helm When:

- ✅ Deploying complex multi-resource applications
- ✅ Need parameterization across environments (dev/staging/prod)
- ✅ Installing third-party applications
- ✅ Want atomic rollback of all resources together
- ✅ Need release versioning and history

### Use kubectl When:

- ✅ Simple, static resource deployments
- ✅ Quick testing or troubleshooting
- ✅ Direct manipulation of specific resources
- ✅ Resources don't need parameterization
- ✅ CKAD exam tasks that don't specifically ask for Helm

**CKAD Exam Tip:** If the question doesn't specifically mention Helm, use kubectl - it's usually faster.

## Common Helm Pitfalls and Solutions

### Pitfall 1: Forgetting --reuse-values

**Problem:** Upgrading resets previous custom values to defaults.

```bash
# ❌ Wrong - loses previous customizations
helm upgrade myapp bitnami/nginx --set newKey=newValue

# ✅ Correct - preserves previous values
helm upgrade myapp bitnami/nginx --reuse-values --set newKey=newValue
```

### Pitfall 2: Chart vs App Version Confusion

**Problem:** Not understanding the difference between chart version and app version.

- **Chart Version**: Version of the Helm chart (packaging)
- **App Version**: Version of the application itself

```bash
# Install specific chart version
helm install myapp bitnami/nginx --version 13.2.0

# This installs chart v13.2.0, which may package nginx v1.23.1
# Check with: helm show chart bitnami/nginx --version 13.2.0
```

### Pitfall 3: Wrong Value Key Names

**Problem:** Using incorrect key names for values.

```bash
# ❌ Wrong key name - value ignored silently
helm install myapp bitnami/nginx --set replicas=3

# ✅ Correct key name
helm install myapp bitnami/nginx --set replicaCount=3

# Always check the chart's values.yaml for correct keys:
helm show values bitnami/nginx | grep replica
```

### Pitfall 4: Namespace Issues

**Problem:** Release not visible or creates resources in wrong namespace.

```bash
# List only shows releases in current namespace by default
helm list

# Show all namespaces
helm list --all-namespaces

# Install in specific namespace (create if needed)
helm install myapp bitnami/nginx -n production --create-namespace
```

### Pitfall 5: Repository Not Updated

**Problem:** Getting old chart versions or "not found" errors.

```bash
# ❌ Repo index is stale
helm install myapp bitnami/nginx

# ✅ Update repos first
helm repo update
helm install myapp bitnami/nginx
```

## Helm Release States

Understanding release states helps with troubleshooting:

| State | Meaning | Next Action |
|-------|---------|-------------|
| `deployed` | Successfully installed/upgraded | Normal operation |
| `superseded` | Replaced by newer revision | Historical record |
| `failed` | Installation/upgrade failed | Check logs, uninstall or fix |
| `pending-install` | Installation in progress | Wait or troubleshoot if stuck |
| `pending-upgrade` | Upgrade in progress | Wait or troubleshoot if stuck |
| `uninstalled` | Removed (with --keep-history) | Can be purged |

```bash
# Check release status
helm status myapp

# See history including failed revisions
helm history myapp
```

## Customizing Values: Multiple Methods

### Method 1: Command Line --set

```bash
# Single value
helm install myapp bitnami/nginx --set replicaCount=3

# Multiple values
helm install myapp bitnami/nginx \
  --set replicaCount=3 \
  --set service.type=NodePort \
  --set service.nodePorts.http=30080

# Nested values with dot notation
helm install myapp bitnami/nginx --set image.tag=1.21.0

# Array values
helm install myapp bitnami/nginx --set 'ingress.hosts[0]=example.com'
```

### Method 2: Values File

```bash
# Create custom values file
cat <<EOF > custom-values.yaml
replicaCount: 3
service:
  type: NodePort
  nodePorts:
    http: 30080
image:
  tag: "1.21.0"
EOF

# Install with values file
helm install myapp bitnami/nginx -f custom-values.yaml
```

### Method 3: Multiple Values Files

```bash
# Base configuration
cat <<EOF > base-values.yaml
replicaCount: 2
EOF

# Environment-specific overrides
cat <<EOF > prod-values.yaml
replicaCount: 5
resources:
  limits:
    cpu: 200m
    memory: 256Mi
EOF

# Files are merged, later files override earlier ones
helm install myapp bitnami/nginx -f base-values.yaml -f prod-values.yaml
```

### Method 4: Combining Methods

```bash
# Values file + command line (--set overrides file)
helm install myapp bitnami/nginx \
  -f custom-values.yaml \
  --set replicaCount=4
```

**Precedence Order** (highest to lowest):
1. `--set` parameters (highest priority)
2. Values files (in order specified)
3. Default values.yaml in chart

## Exercise 1: Install PostgreSQL Database

Deploy a PostgreSQL database using Helm with the following requirements:
1. Use the bitnami/postgresql chart
2. Release name: `mydb`
3. Database name: `appdb`
4. Username: `appuser`
5. Disable authentication (for testing)
6. Use a NodePort service on port 30432

<details>
  <summary>Step-by-Step Solution</summary>

```bash
# Add bitnami repo if not present
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Check available values
helm show values bitnami/postgresql | grep -E '(database|username|auth|service)' | head -30

# Create values file
cat <<EOF > postgres-values.yaml
auth:
  enablePostgresUser: true
  postgresPassword: ""
  username: appuser
  password: ""
  database: appdb

primary:
  service:
    type: NodePort
    nodePorts:
      postgresql: 30432
EOF

# Install
helm install mydb bitnami/postgresql -f postgres-values.yaml

# Or with --set flags
helm install mydb bitnami/postgresql \
  --set auth.username=appuser \
  --set auth.password="" \
  --set auth.database=appdb \
  --set primary.service.type=NodePort \
  --set primary.service.nodePorts.postgresql=30432

# Verify
helm list
kubectl get all -l app.kubernetes.io/instance=mydb

# Test connection
kubectl run postgresql-client --rm --tty -i --restart='Never' --image=postgres:15 --env="PGPASSWORD=" --command -- psql --host mydb-postgresql --username appuser --dbname appdb -c '\l'
```

</details><br />

## Exercise 2: Upgrade and Rollback

Starting with the PostgreSQL installation from Exercise 1:
1. Upgrade to enable metrics exporter
2. Check the new pods created
3. Roll back to the original configuration
4. Verify rollback was successful

<details>
  <summary>Step-by-Step Solution</summary>

```bash
# Check current configuration
helm get values mydb

# Upgrade to enable metrics
helm upgrade mydb bitnami/postgresql \
  --reuse-values \
  --set metrics.enabled=true

# Check new resources
kubectl get all -l app.kubernetes.io/instance=mydb
# You should see metrics exporter pods

# Check history
helm history mydb
# Shows revision 1 (install) and revision 2 (upgrade)

# Rollback to revision 1
helm rollback mydb 1

# Or just rollback to previous
helm rollback mydb

# Verify rollback
helm history mydb
# Shows revision 3 (rollback to 1)

kubectl get all -l app.kubernetes.io/instance=mydb
# Metrics exporter should be gone

# Cleanup
helm uninstall mydb
```

</details><br />

## Exercise 3: Multiple Releases from Same Chart

Deploy two independent WordPress sites using Helm:
1. First site: `blog`, replicas: 1, service port: 30081
2. Second site: `shop`, replicas: 2, service port: 30082
3. Verify they are independent releases
4. Verify they don't interfere with each other

<details>
  <summary>Step-by-Step Solution</summary>

```bash
# Add bitnami repo if needed
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Install first release - blog
helm install blog bitnami/wordpress \
  --set replicaCount=1 \
  --set service.type=NodePort \
  --set service.nodePorts.http=30081 \
  --set wordpressUsername=admin \
  --set wordpressPassword=admin123

# Install second release - shop
helm install shop bitnami/wordpress \
  --set replicaCount=2 \
  --set service.type=NodePort \
  --set service.nodePorts.http=30082 \
  --set wordpressUsername=admin \
  --set wordpressPassword=admin123

# List releases
helm list
# Shows both blog and shop

# Verify independence - check labels
kubectl get pods --show-labels | grep wordpress
# Each pod has app.kubernetes.io/instance=blog or shop

# Check services
kubectl get svc | grep wordpress
# Two separate services on different ports

# Verify each site
curl -I http://localhost:30081  # Blog site
curl -I http://localhost:30082  # Shop site

# Cleanup
helm uninstall blog shop
```

**Key Learning:** Each Helm release is independent. Labels include the release name, preventing resource conflicts.

</details><br />

## Troubleshooting Helm Issues

### Issue 1: Release Install Hangs

**Symptom:** `helm install` command doesn't complete

**Debugging:**

```bash
# In another terminal, check what's happening
kubectl get pods -l app.kubernetes.io/instance=<release-name>

# Check events
kubectl get events --sort-by='.lastTimestamp'

# Common causes:
# - Image pull errors
# - Insufficient resources
# - Failed init containers
# - CrashLoopBackOff
```

**Fix:**

```bash
# If installation is stuck, uninstall
helm uninstall <release-name>

# Fix the underlying issue (check pod errors)
kubectl describe pod <pod-name>

# Reinstall with corrections
helm install <release-name> <chart> --set <fix>
```

### Issue 2: Values Not Applied

**Symptom:** Custom values don't seem to take effect

**Debugging:**

```bash
# Check what values Helm actually used
helm get values <release-name>

# Check the generated manifest
helm get manifest <release-name>

# Compare with defaults
helm show values <repo>/<chart>
```

**Common Causes:**

1. Wrong key name in values
2. Typo in --set flag
3. Chart doesn't support the parameter
4. Need to escape special characters

**Fix:**

```bash
# Verify correct key names
helm show values <chart> | grep <your-key>

# Use values file for complex values
cat <<EOF > values.yaml
correct:
  key:
    name: value
EOF

helm upgrade <release> <chart> -f values.yaml
```

### Issue 3: Cannot Delete Release

**Symptom:** `helm uninstall` fails or resources remain

**Debugging:**

```bash
# Check if release exists
helm list --all-namespaces

# Try uninstall with wait
helm uninstall <release> --wait

# Check for remaining resources
kubectl get all -l app.kubernetes.io/instance=<release>
```

**Fix:**

```bash
# Force uninstall if needed
helm uninstall <release> --no-hooks

# Manually clean up remaining resources
kubectl delete all -l app.kubernetes.io/instance=<release>

# If in wrong namespace
helm uninstall <release> -n <namespace>
```

### Issue 4: Chart Not Found

**Symptom:** `Error: chart "<chart>" not found`

**Debugging:**

```bash
# List repositories
helm repo list

# Search for chart
helm search repo <chart>
```

**Fix:**

```bash
# Update repository indices
helm repo update

# Add repository if missing
helm repo add <repo-name> <repo-url>

# Search again
helm search repo <chart>

# Specify full chart path
helm install <release> <repo-name>/<chart>
```

## Quick Command Reference

### Installation & Management

```bash
# Install
helm install <release> <chart>
helm install <release> <chart> -f values.yaml
helm install <release> <chart> --set key=value
helm install <release> <chart> -n <namespace> --create-namespace

# List
helm list
helm list -A
helm list -n <namespace>

# Status
helm status <release>
helm get values <release>
helm get manifest <release>

# Upgrade
helm upgrade <release> <chart>
helm upgrade <release> <chart> --reuse-values
helm upgrade <release> <chart> --set key=newvalue

# Rollback
helm history <release>
helm rollback <release>
helm rollback <release> <revision>

# Uninstall
helm uninstall <release>
helm uninstall <release> -n <namespace>
```

### Repository Management

```bash
# List repos
helm repo list

# Add repo
helm repo add <name> <url>

# Update repos
helm repo update

# Remove repo
helm repo remove <name>

# Search
helm search repo <keyword>
helm search repo <chart> --versions
```

### Chart Information

```bash
# Show values
helm show values <repo>/<chart>
helm show values <repo>/<chart> --version <version>

# Show chart info
helm show chart <repo>/<chart>

# Show README
helm show readme <repo>/<chart>

# Show all
helm show all <repo>/<chart>
```

## Common CKAD Exam Patterns

### Pattern 1: Install with Custom Values

**Question:** "Install nginx using Helm with 3 replicas and NodePort service"

**Approach:**
1. Add repository if needed
2. Check values file for correct keys
3. Install with --set flags or values file
4. Verify installation

### Pattern 2: Upgrade Release

**Question:** "Upgrade the existing nginx release to use 5 replicas"

**Approach:**
1. Check current values: `helm get values <release>`
2. Upgrade with --reuse-values: `helm upgrade <release> <chart> --reuse-values --set replicaCount=5`
3. Verify: `helm history <release>` and `kubectl get pods`

### Pattern 3: Rollback Release

**Question:** "The latest upgrade broke the application. Roll back to the working version"

**Approach:**
1. Check history: `helm history <release>`
2. Rollback: `helm rollback <release>`
3. Verify: `helm status <release>`

### Pattern 4: Install from Repository

**Question:** "Install PostgreSQL from bitnami repository with database name 'myapp'"

**Approach:**
1. Add repo: `helm repo add bitnami https://charts.bitnami.com/bitnami`
2. Update: `helm repo update`
3. Check values: `helm show values bitnami/postgresql | grep database`
4. Install: `helm install mydb bitnami/postgresql --set auth.database=myapp`

## Exam Tips

1. **Check if Helm is appropriate** - If the question doesn't mention Helm, use kubectl
2. **Always update repos** before installing - `helm repo update`
3. **Check values.yaml** before installing - Know the correct key names
4. **Use --reuse-values** when upgrading - Prevents losing previous configurations
5. **Use --all-namespaces** when listing - Releases are namespace-scoped
6. **Test with helm get manifest** - Verify what will be deployed
7. **Keep history** - Helps with troubleshooting and rollback
8. **Use specific versions** in production scenarios - `--version` flag

## Common Mistakes to Avoid

1. ❌ Forgetting `--reuse-values` on upgrade
2. ❌ Using wrong value key names
3. ❌ Not specifying namespace when needed
4. ❌ Confusing chart version with app version
5. ❌ Not updating repos before searching/installing
6. ❌ Using `helm list` without `-A` and missing releases
7. ❌ Trying to `helm uninstall` in wrong namespace
8. ❌ Not checking default values before installation
9. ❌ Using Helm when kubectl would be faster
10. ❌ Forgetting `--create-namespace` flag

## Study Checklist for CKAD

- [ ] Understand what Helm is and when to use it
- [ ] Know how to add and update Helm repositories
- [ ] Can search for charts in repositories
- [ ] Can inspect chart values before installation
- [ ] Can install a release with custom values (--set and -f)
- [ ] Can list releases in current and all namespaces
- [ ] Can check release status and values
- [ ] Can upgrade a release with new values
- [ ] Can upgrade while preserving previous values (--reuse-values)
- [ ] Can view release history
- [ ] Can rollback to previous revision
- [ ] Can uninstall a release
- [ ] Understand release states and troubleshooting
- [ ] Know difference between chart version and app version
- [ ] Can work with values files and --set flags
- [ ] Understand when to use Helm vs kubectl

## Practice Exercises

Practice these until they become automatic:

```bash
# 1. Install nginx with 3 replicas
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install web bitnami/nginx --set replicaCount=3

# 2. Upgrade to 5 replicas
helm upgrade web bitnami/nginx --reuse-values --set replicaCount=5

# 3. Check history
helm history web

# 4. Rollback
helm rollback web

# 5. View configuration
helm get values web

# 6. Uninstall
helm uninstall web
```

## Additional Resources

During the exam you can access:
- [Helm Documentation](https://helm.sh/docs/)
- [Helm Commands Reference](https://helm.sh/docs/helm/)

**Bookmark these** before the exam!

## Cleanup

```bash
# List all releases
helm list --all-namespaces

# Uninstall all releases (example)
helm uninstall <release1> <release2> <release3>

# Or with namespace
helm uninstall <release> -n <namespace>
```

## Next Steps

After understanding Helm for CKAD:
1. Practice with common charts (nginx, postgresql, redis)
2. Understand when Helm adds value vs plain kubectl
3. Focus on the CLI commands, not chart creation
4. Practice troubleshooting failed installations

---

## Summary

Helm is a package manager for Kubernetes that simplifies deploying and managing complex applications. For CKAD:

✅ **Master these skills:**
- Installing releases with custom values
- Upgrading and rolling back releases
- Working with chart repositories
- Troubleshooting failed installations
- Understanding Helm vs kubectl trade-offs

🎯 **Exam weight**: Supplementary (may appear but not heavily weighted)
⏱️ **Time per question**: 5-8 minutes
📊 **Difficulty**: Easy-Medium (mostly command knowledge)

Focus on the essential CLI commands and when to use Helm vs kubectl. Don't spend time on chart creation - that's not tested on CKAD.
