# ConfigMaps - CKAD Requirements

This document covers the CKAD (Certified Kubernetes Application Developer) exam requirements for ConfigMaps, building on the basics covered in [README.md](README.md).

## CKAD Exam Requirements

The CKAD exam expects you to understand and implement:
- Creating ConfigMaps using multiple methods (YAML, imperative commands, from files)
- Consuming ConfigMaps as environment variables (individual keys and all keys)
- Consuming ConfigMaps as volume mounts (entire ConfigMap and selective keys)
- Using subPath to mount individual files without overwriting directories
- Understanding ConfigMap update behavior and immutability
- Troubleshooting ConfigMap-related issues
- ConfigMap size limits and best practices

## Creating ConfigMaps - Multiple Methods

### Method 1: From YAML (Declarative)

The standard approach using YAML manifests:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: default
data:
  # Simple key-value pairs
  database_host: "mysql.default.svc.cluster.local"
  database_port: "3306"
  log_level: "info"

  # File-like data
  app.properties: |
    server.port=8080
    server.timeout=30
    cache.enabled=true

  config.json: |
    {
      "features": {
        "darkMode": true,
        "notifications": false
      }
    }
```

### Method 2: From Literal Values (Imperative)

Quick creation from command line:

```bash
# Single literal
kubectl create configmap app-config --from-literal=database_host=mysql.default.svc.cluster.local

# Multiple literals
kubectl create configmap app-config \
  --from-literal=database_host=mysql.default.svc.cluster.local \
  --from-literal=database_port=3306 \
  --from-literal=log_level=info
```

### Method 3: From Files

Create ConfigMap from existing configuration files:

```bash
# From a single file (key = filename, value = file contents)
kubectl create configmap nginx-config --from-file=nginx.conf

# From a single file with custom key name
kubectl create configmap nginx-config --from-file=custom-name=nginx.conf

# From multiple files
kubectl create configmap app-config \
  --from-file=app.properties \
  --from-file=config.json

# From a directory (creates one key per file in directory)
kubectl create configmap app-config --from-file=./config-dir/
```

See complete examples: [`specs/ckad/creation-methods.yaml`](specs/ckad/creation-methods.yaml)

This file demonstrates:
- ConfigMap from file with default key (key = filename)
- ConfigMap from file with custom key
- ConfigMap from multiple files
- ConfigMap from literals
- ConfigMap from env file

### Method 4: From Environment Files

Create from `.env` file format:

```bash
# Contents of app.env:
# DATABASE_HOST=mysql
# DATABASE_PORT=3306
# LOG_LEVEL=info

kubectl create configmap app-config --from-env-file=app.env
```

📋 Create a ConfigMap using all four methods and compare the resulting YAML structure.

<details>
  <summary>Not sure how?</summary>

```bash
# View the ConfigMap YAML
kubectl get configmap app-config -o yaml

# Or describe it
kubectl describe configmap app-config
```

```bash
# Compare different creation methods
kubectl apply -f labs/configmaps/specs/ckad/creation-methods.yaml
kubectl get configmap from-file-default-key -o yaml
kubectl get configmap from-literals -o yaml
kubectl get configmap from-env-file -o yaml

# Notice how keys differ based on creation method
```

</details><br/>

## Consuming ConfigMaps as Environment Variables

### Loading All Keys as Environment Variables

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-config
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "env && sleep 3600"]
    envFrom:
    - configMapRef:
        name: app-config
```

### Loading Individual Keys as Environment Variables

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-selective-config
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "env && sleep 3600"]
    env:
    - name: DATABASE_HOST
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: database_host
    - name: DATABASE_PORT
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: database_port
    - name: CUSTOM_VALUE
      value: "hardcoded-value"  # Mix with direct values
```

### Using ConfigMap with envFrom Prefix

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-prefix
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "env && sleep 3600"]
    envFrom:
    - configMapRef:
        name: app-config
      prefix: APP_CONFIG_
```

> This prefixes all keys with `APP_CONFIG_` (e.g., `APP_CONFIG_database_host`)

📋 Create a Pod that uses both `envFrom` and individual `env` entries, then verify which takes precedence.

<details>
  <summary>Not sure how?</summary>

See complete examples: [`specs/ckad/consume-env-vars.yaml`](specs/ckad/consume-env-vars.yaml)

Precedence rules:
1. Individual `env` entries override `envFrom`
2. Later `env` entries override earlier ones
3. `envFrom` sources are merged, with later sources overriding earlier ones

```yaml
env:
- name: LOG_LEVEL
  value: "debug"  # This overrides any value from envFrom
envFrom:
- configMapRef:
    name: app-config  # LOG_LEVEL from here is ignored
```

</details><br/>

## Consuming ConfigMaps as Volume Mounts

### Mounting Entire ConfigMap

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-volume
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "ls -la /config && cat /config/* && sleep 3600"]
    volumeMounts:
    - name: config-volume
      mountPath: /config
      readOnly: true
  volumes:
  - name: config-volume
    configMap:
      name: app-config
```

> Each key in the ConfigMap becomes a file in `/config/`

### Mounting Specific Keys

Mount only selected keys from the ConfigMap:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-selective-mount
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "ls -la /config && sleep 3600"]
    volumeMounts:
    - name: config-volume
      mountPath: /config
      readOnly: true
  volumes:
  - name: config-volume
    configMap:
      name: app-config
      items:
      - key: app.properties
        path: application.properties  # Rename the file
      - key: config.json
        path: config.json
```

### Using subPath to Avoid Overwriting Directories

**Problem**: Volume mounts replace the entire target directory, potentially breaking apps.

**Solution**: Use `subPath` to mount individual files:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-with-config
spec:
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - name: config-volume
      mountPath: /etc/nginx/nginx.conf
      subPath: nginx.conf  # Mount only this file, not entire /etc/nginx
      readOnly: true
  volumes:
  - name: config-volume
    configMap:
      name: nginx-config
```

**Without subPath**: Mounting to `/etc/nginx` replaces the ENTIRE directory, removing all default nginx configs, causing nginx to fail.

**With subPath**: Only the specific file is mounted, preserving other files in `/etc/nginx/`.

See complete example with nginx: [`specs/ckad/exercises/ex2-nginx-subpath.yaml`](specs/ckad/exercises/ex2-nginx-subpath.yaml)

📋 Create a ConfigMap with nginx configuration and mount it using subPath to avoid breaking the container.

<details>
  <summary>Not sure how?</summary>

See solution: [`specs/ckad/exercises/ex2-nginx-subpath.yaml`](specs/ckad/exercises/ex2-nginx-subpath.yaml)

```bash
kubectl apply -f labs/configmaps/specs/ckad/exercises/ex2-nginx-subpath.yaml
kubectl get pod nginx-custom
kubectl logs nginx-custom
kubectl exec nginx-custom -- ls -la /etc/nginx/
```

</details><br/>

## File Permissions for ConfigMap Volumes

Control file permissions when mounting ConfigMaps:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-permissions
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "ls -la /config && sleep 3600"]
    volumeMounts:
    - name: config-volume
      mountPath: /config
      readOnly: true
  volumes:
  - name: config-volume
    configMap:
      name: app-config
      defaultMode: 0644  # rw-r--r--
      items:
      - key: app.properties
        path: app.properties
        mode: 0600  # rw------- (override default)
```

See complete examples: [`specs/ckad/consume-volumes.yaml`](specs/ckad/consume-volumes.yaml) - Method 3 demonstrates custom permissions.

**Verify file permissions inside container**:

```bash
kubectl apply -f labs/configmaps/specs/ckad/consume-volumes.yaml
kubectl exec app-volume-custom -- ls -la /config/

# Output shows different permissions:
# -rw-r--r-- webserver.conf (mode 0644)
# -rw------- application.properties (mode 0600)

kubectl exec app-volume-custom -- stat /config/application.properties
```

## ConfigMap Updates and Propagation

### Update Behavior

- **Environment Variables**: NOT updated when ConfigMap changes (requires Pod restart)
- **Volume Mounts**: Updated automatically after a short delay (kubelet sync period)

```bash
# Update a ConfigMap
kubectl edit configmap app-config

# For environment variables: must restart Pod
kubectl delete pod app-with-config
kubectl apply -f pod.yaml

# For volume mounts: wait for automatic update (up to 60 seconds)
kubectl exec app-with-volume -- watch cat /config/app.properties
```

See complete examples: [`specs/ckad/updates.yaml`](specs/ckad/updates.yaml)

**Hands-on update propagation test**:

```bash
# Deploy pods with different consumption methods
kubectl apply -f labs/configmaps/specs/ckad/updates.yaml

# Watch the volume-mounted pod
kubectl logs -f pod-volume-mount

# In another terminal, update the ConfigMap
kubectl edit configmap dynamic-config
# Change the message and version fields

# Observe timing:
# - pod-volume-mount: Changes appear after ~60 seconds (kubelet sync period)
# - pod-env-vars: No changes (requires pod restart)
# - pod-subpath-mount: No changes (subPath doesn't support updates)

# Verify environment variables don't update
kubectl exec pod-env-vars -- env | grep CONFIG_
```

### Immutable ConfigMaps

Make ConfigMaps immutable for better performance and safety:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-immutable
data:
  database_host: "mysql.default.svc.cluster.local"
immutable: true
```

Benefits:
- Protects against accidental updates
- Improves cluster performance (kube-apiserver doesn't watch for changes)
- For updates, must delete and recreate ConfigMap + Pods

See complete examples: [`specs/ckad/immutable.yaml`](specs/ckad/immutable.yaml)

**Testing immutable ConfigMap protection**:

```bash
# Create immutable ConfigMap
kubectl apply -f labs/configmaps/specs/ckad/immutable.yaml

# Try to update it (will fail)
kubectl patch configmap immutable-config -p '{"data":{"setting1":"new-value"}}'
# Error: field is immutable

# Try with edit (will also fail)
kubectl edit configmap immutable-config
# Error message when you save: "field is immutable"
```

📋 Create an immutable ConfigMap, deploy a Pod using it, then try to update the ConfigMap.

<details>
  <summary>Not sure how?</summary>

**Proper workflow for updating immutable ConfigMaps**:

```bash
# Step 1: Create immutable ConfigMap v1
kubectl apply -f labs/configmaps/specs/ckad/immutable.yaml

# Step 2: Deploy pod using it
kubectl get pod app-with-versioned-config

# Step 3: To update, create NEW ConfigMap with different name
# Edit the pod/deployment spec to reference app-config-v2

# Step 4: Delete old pod and create new one (or use Deployment rolling update)
kubectl delete pod app-with-versioned-config
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: app-with-versioned-config
spec:
  containers:
  - name: app
    image: busybox:latest
    command: ['sh', '-c', 'env && sleep 3600']
    envFrom:
    - configMapRef:
        name: app-config-v2  # Changed from v1 to v2
EOF

# Best practice: version ConfigMaps in their names (app-config-v1, app-config-v2)
```

</details><br/>

## Binary Data in ConfigMaps

ConfigMaps can store binary data using `binaryData` field:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: binary-config
binaryData:
  # Base64-encoded binary data
  image.png: iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==
data:
  # Regular text data
  config.txt: "text configuration"
```

Create from binary file:

```bash
# Kubernetes automatically base64-encodes binary files
kubectl create configmap binary-config --from-file=image.png
```

**Mount and use binary data**:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-binary
spec:
  containers:
  - name: app
    image: nginx:alpine
    volumeMounts:
    - name: binary-data
      mountPath: /usr/share/nginx/html/assets
  volumes:
  - name: binary-data
    configMap:
      name: binary-config
```

```bash
# Verify binary file is mounted correctly
kubectl exec app-with-binary -- ls -lh /usr/share/nginx/html/assets/
kubectl exec app-with-binary -- file /usr/share/nginx/html/assets/image.png
```

> **Note**: For large binary files or many images, use PersistentVolumes instead of ConfigMaps.

## ConfigMap Size Limits

- Maximum ConfigMap size: **1 MiB** (1,048,576 bytes)
- Includes all keys and values combined
- Best practice: Keep ConfigMaps small and focused

**Testing size limit**:

```bash
# Create a ConfigMap that's too large (will fail)
dd if=/dev/zero of=large-file.bin bs=1M count=2
kubectl create configmap too-large --from-file=large-file.bin
# Error: ConfigMap "too-large" is invalid: data: Too long: must have at most 1048576 bytes

# Check ConfigMap size
kubectl get configmap app-config -o json | jq '.data | length'
kubectl get configmap app-config -o yaml | wc -c  # Total bytes including metadata
```

## Optional ConfigMaps

Make ConfigMap references optional to avoid Pod startup failures:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-optional-config
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "env && sleep 3600"]
    envFrom:
    - configMapRef:
        name: app-config
        optional: true  # Pod starts even if ConfigMap doesn't exist
    volumeMounts:
    - name: config-volume
      mountPath: /config
      readOnly: true
  volumes:
  - name: config-volume
    configMap:
      name: optional-config
      optional: true  # Pod starts even if ConfigMap doesn't exist
```

📋 Create a Pod referencing a non-existent ConfigMap with and without the optional flag.

<details>
  <summary>Not sure how?</summary>

**Testing optional vs required ConfigMaps**:

```bash
# Test 1: Pod with required (non-optional) ConfigMap that doesn't exist
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pod-required-config
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'echo "App running" && sleep 3600']
    envFrom:
    - configMapRef:
        name: non-existent-config
        # optional: false is the default
EOF

# Pod gets stuck in CreateContainerConfigError
kubectl get pod pod-required-config
# NAME                   READY   STATUS                       RESTARTS   AGE
# pod-required-config    0/1     CreateContainerConfigError   0          10s

kubectl describe pod pod-required-config
# Error: configmap "non-existent-config" not found

# Test 2: Pod with optional ConfigMap that doesn't exist
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pod-optional-config
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'echo "App running without config" && sleep 3600']
    envFrom:
    - configMapRef:
        name: non-existent-config
        optional: true  # Pod starts anyway
EOF

# Pod starts successfully
kubectl get pod pod-optional-config
# NAME                   READY   STATUS    RESTARTS   AGE
# pod-optional-config    1/1     Running   0          5s

kubectl logs pod-optional-config
# App running without config

# Cleanup
kubectl delete pod pod-required-config pod-optional-config
```

</details><br/>

## Using ConfigMaps with Command Arguments

Inject ConfigMap values into container command/args:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-args
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c"]
    args:
    - |
      echo "Database: $(DATABASE_HOST):$(DATABASE_PORT)"
      echo "Log Level: $(LOG_LEVEL)"
      sleep 3600
    env:
    - name: DATABASE_HOST
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: database_host
    - name: DATABASE_PORT
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: database_port
    - name: LOG_LEVEL
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: log_level
```

> **Note**: ConfigMap values cannot be directly referenced in `command` or `args` without environment variables. The `$(VAR_NAME)` syntax requires the value to be defined as an environment variable first. This is a Kubernetes limitation - unlike Helm templates or other templating systems, raw YAML doesn't support direct ConfigMap key substitution in command/args fields.
>
> Alternative: Mount ConfigMap as a file and read it in the command:
> ```yaml
> command: ["sh", "-c", "cat /config/database_host && sleep 3600"]
> volumeMounts:
> - name: config
>   mountPath: /config
> ```

## Troubleshooting ConfigMaps

### Common Issues

1. **Pod in CreateContainerConfigError state**
   ```bash
   kubectl describe pod app-with-config
   # Look for: "configmap "app-config" not found"
   ```

2. **Wrong key name**
   ```bash
   kubectl describe pod app-with-config
   # Look for: "key "wrong_key" not found in ConfigMap"
   ```

3. **Volume mount overwrites directory**
   - Use `subPath` to mount individual files
   - Or mount to a different directory and symlink

4. **ConfigMap updates not reflecting**
   - Environment variables: require Pod restart
   - Volume mounts: wait up to 60 seconds
   - Check kubelet sync period

### Debugging Commands

```bash
# List all ConfigMaps
kubectl get configmaps

# View ConfigMap contents
kubectl describe configmap app-config
kubectl get configmap app-config -o yaml

# Check which Pods use a ConfigMap
kubectl get pods -o json | jq '.items[] | select(.spec.volumes[]?.configMap.name=="app-config") | .metadata.name'

# View environment variables in running Pod
kubectl exec app-with-config -- env

# View mounted files in Pod
kubectl exec app-with-config -- ls -la /config
kubectl exec app-with-config -- cat /config/app.properties

# Check Pod events for ConfigMap errors
kubectl describe pod app-with-config
```

See complete troubleshooting scenarios: [`specs/ckad/troubleshooting.yaml`](specs/ckad/troubleshooting.yaml)

**Step-by-step debugging example**:

```bash
# Deploy troubleshooting scenarios
kubectl apply -f labs/configmaps/specs/ckad/troubleshooting.yaml

# Scenario 1: Pod stuck in CreateContainerConfigError
kubectl get pod pod-missing-configmap
# NAME                     READY   STATUS                       RESTARTS   AGE
# pod-missing-configmap    0/1     CreateContainerConfigError   0          10s

# Step 1: Check pod description for errors
kubectl describe pod pod-missing-configmap | grep -A 5 Events
# Error: configmap "non-existent-configmap" not found

# Step 2: List available ConfigMaps
kubectl get configmaps

# Step 3: Fix by creating the ConfigMap
kubectl create configmap non-existent-configmap --from-literal=key=value

# Step 4: Verify pod recovers
kubectl get pod pod-missing-configmap
# NAME                     READY   STATUS    RESTARTS   AGE
# pod-missing-configmap    1/1     Running   0          2m

# Cleanup
kubectl delete -f labs/configmaps/specs/ckad/troubleshooting.yaml
```

## Lab Exercises

### Exercise 1: Multi-Method ConfigMap Creation

Create the same configuration using three different methods and verify the output is identical:

1. Create ConfigMap from YAML with these settings:
   - `app.name=myapp`
   - `app.version=1.0.0`
   - `app.environment=production`

2. Create the same ConfigMap using `--from-literal`

3. Create the same ConfigMap using `--from-env-file`

<details>
  <summary>Solution</summary>

```bash
# Method 1: From YAML
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-yaml
data:
  app.name: "myapp"
  app.version: "1.0.0"
  app.environment: "production"
EOF

# Method 2: From literals
kubectl create configmap app-config-literal \
  --from-literal=app.name=myapp \
  --from-literal=app.version=1.0.0 \
  --from-literal=app.environment=production

# Method 3: From env file
cat > app.env <<EOF
app.name=myapp
app.version=1.0.0
app.environment=production
EOF

kubectl create configmap app-config-envfile --from-env-file=app.env

# Verify all three are identical
kubectl get configmap app-config-yaml -o yaml | grep -A 10 "^data:"
kubectl get configmap app-config-literal -o yaml | grep -A 10 "^data:"
kubectl get configmap app-config-envfile -o yaml | grep -A 10 "^data:"

# Compare using diff
diff <(kubectl get configmap app-config-yaml -o json | jq -S .data) \
     <(kubectl get configmap app-config-literal -o json | jq -S .data)
# No output = identical

# Cleanup
kubectl delete configmap app-config-yaml app-config-literal app-config-envfile
rm app.env
```

</details>

### Exercise 2: Mixed Environment Variable Sources

Create a Pod that gets configuration from:
- A ConfigMap (database settings)
- Hardcoded environment variables (app name)
- Another ConfigMap with prefix (feature flags)

Verify the final environment variables and check for conflicts.

<details>
  <summary>Solution</summary>

See: [`specs/ckad/consume-env-vars.yaml`](specs/ckad/consume-env-vars.yaml) for detailed examples.

```bash
# Create ConfigMaps
kubectl create configmap db-config \
  --from-literal=DB_HOST=postgres.example.com \
  --from-literal=DB_PORT=5432 \
  --from-literal=APP_NAME=database-app

kubectl create configmap feature-flags \
  --from-literal=dark_mode=true \
  --from-literal=beta_features=enabled

# Create Pod with mixed sources
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: mixed-env-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'env | sort && sleep 3600']
    env:
    # Hardcoded values (highest precedence)
    - name: APP_NAME
      value: "my-custom-app"  # Overrides DB_HOST from db-config
    - name: VERSION
      value: "1.0.0"
    envFrom:
    # ConfigMap 1
    - configMapRef:
        name: db-config
    # ConfigMap 2 with prefix
    - configMapRef:
        name: feature-flags
      prefix: FEATURE_
EOF

# Verify environment variables
kubectl logs mixed-env-pod

# Check precedence: env overrides envFrom
kubectl exec mixed-env-pod -- printenv APP_NAME
# Output: my-custom-app (NOT database-app from ConfigMap)

kubectl exec mixed-env-pod -- printenv | grep -E "(DB_|FEATURE_)"
# DB_HOST=postgres.example.com
# DB_PORT=5432
# FEATURE_dark_mode=true
# FEATURE_beta_features=enabled

# Cleanup
kubectl delete pod mixed-env-pod
kubectl delete configmap db-config feature-flags
```

**Precedence rules observed**:
1. `env` entries override `envFrom` (APP_NAME = "my-custom-app")
2. Prefixes are applied to `envFrom` sources (FEATURE_ prefix)
3. Both ConfigMaps are merged successfully

</details>

### Exercise 3: Selective Key Mounting

Create a ConfigMap with 5 different configuration files. Create a Pod that:
- Mounts only 2 specific files to `/config`
- Renames one file during mounting
- Sets custom file permissions (0600)

<details>
  <summary>Solution</summary>

See: [`specs/ckad/consume-volumes.yaml`](specs/ckad/consume-volumes.yaml) - Method 3 for detailed example.

```bash
# Create ConfigMap with 5 files
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: multi-file-config
data:
  file1.txt: "Content of file 1"
  file2.txt: "Content of file 2"
  file3.txt: "Content of file 3"
  file4.txt: "Content of file 4"
  file5.txt: "Content of file 5"
EOF

# Create Pod mounting only 2 files with custom names and permissions
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: selective-mount-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'ls -la /config/ && cat /config/* && sleep 3600']
    volumeMounts:
    - name: config
      mountPath: /config
  volumes:
  - name: config
    configMap:
      name: multi-file-config
      items:
      - key: file1.txt
        path: renamed-file1.txt  # Renamed
        mode: 0600  # rw------- (only owner can read/write)
      - key: file3.txt
        path: file3.txt
        mode: 0600
      # file2, file4, file5 are NOT mounted
EOF

# Verify selective mounting
kubectl logs selective-mount-pod
# Should show only 2 files in /config/

kubectl exec selective-mount-pod -- ls -la /config/
# -rw------- renamed-file1.txt
# -rw------- file3.txt

kubectl exec selective-mount-pod -- stat -c "%a %n" /config/renamed-file1.txt
# 600 /config/renamed-file1.txt

# Cleanup
kubectl delete pod selective-mount-pod
kubectl delete configmap multi-file-config
```

</details>

### Exercise 4: ConfigMap Update Propagation

Create a ConfigMap and two Pods:
1. Pod A: Uses ConfigMap as environment variables
2. Pod B: Uses ConfigMap as volume mount

Update the ConfigMap and observe:
- Which Pod sees the changes?
- How long does it take?
- What's needed to update the other Pod?

<details>
  <summary>Solution</summary>

See: [`specs/ckad/updates.yaml`](specs/ckad/updates.yaml) for complete examples.

```bash
# Deploy the update propagation test
kubectl apply -f labs/configmaps/specs/ckad/updates.yaml

# Watch both pods in separate terminals
kubectl logs -f pod-volume-mount &
kubectl logs -f pod-env-vars &

# Update the ConfigMap
kubectl edit configmap dynamic-config
# Change: message: "Updated configuration at $(date)"
# Change: version: "2.0"

# Observations:
# - pod-volume-mount: Shows new values after 30-60 seconds (kubelet sync)
# - pod-env-vars: Shows old values (no update without pod restart)

# Verify the behavior
kubectl exec pod-volume-mount -- cat /config/message
# Output: Updated configuration...

kubectl exec pod-env-vars -- printenv CONFIG_MESSAGE
# Output: Original configuration (unchanged)

# Restart the env-vars pod to get updates
kubectl delete pod pod-env-vars
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pod-env-vars
spec:
  containers:
  - name: app
    image: busybox:latest
    command: ['sh', '-c', 'env | grep CONFIG_ && sleep 3600']
    envFrom:
    - configMapRef:
        name: dynamic-config
      prefix: CONFIG_
EOF

kubectl exec pod-env-vars -- printenv CONFIG_MESSAGE
# Output: Updated configuration... (now updated)

# Cleanup
kubectl delete -f labs/configmaps/specs/ckad/updates.yaml
```

**Key findings**:
- Volume mounts: Auto-update after ~60 seconds
- Environment variables: Require pod restart
- subPath mounts: Never update (must restart pod)

</details>

### Exercise 5: Fixing Broken Volume Mounts

Debug and fix a Pod that's in CrashLoopBackoff due to incorrect ConfigMap volume mount that overwrites the application directory.

<details>
  <summary>Solution</summary>

See: [`specs/ckad/exercises/ex2-nginx-subpath.yaml`](specs/ckad/exercises/ex2-nginx-subpath.yaml)

```bash
# Broken configuration (overwrites /etc/nginx/)
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  nginx.conf: |
    events {}
    http {
      server {
        listen 8080;
        location / { return 200 "Custom config\\n"; }
      }
    }
---
apiVersion: v1
kind: Pod
metadata:
  name: nginx-broken
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    volumeMounts:
    - name: config
      mountPath: /etc/nginx  # BROKEN: overwrites entire directory
  volumes:
  - name: config
    configMap:
      name: nginx-config
EOF

# Pod crashes because /etc/nginx/ is replaced, missing critical files
kubectl get pod nginx-broken
# STATUS: CrashLoopBackOff or Error

kubectl logs nginx-broken
# Error: nginx.conf missing required files

# FIXED configuration using subPath
kubectl delete pod nginx-broken
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: nginx-fixed
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    volumeMounts:
    - name: config
      mountPath: /etc/nginx/nginx.conf  # FIXED: mount only the file
      subPath: nginx.conf  # Using subPath to mount single file
  volumes:
  - name: config
    configMap:
      name: nginx-config
EOF

# Pod runs successfully
kubectl get pod nginx-fixed
# STATUS: Running

kubectl exec nginx-fixed -- ls -la /etc/nginx/
# Shows nginx.conf plus all default nginx files

# Cleanup
kubectl delete pod nginx-fixed
kubectl delete configmap nginx-config
```

**Key lesson**: Use `subPath` when mounting into directories that contain required files.

</details>

### Exercise 6: Immutable ConfigMap Workflow

Create an immutable ConfigMap and demonstrate the proper workflow to update it:
1. Create immutable ConfigMap and Pod
2. Attempt to update (observe error)
3. Perform rolling update with new ConfigMap

<details>
  <summary>Solution</summary>

See: [`specs/ckad/immutable.yaml`](specs/ckad/immutable.yaml) and [`specs/ckad/updates.yaml`](specs/ckad/updates.yaml)

```bash
# Step 1: Create immutable ConfigMap v1
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-v1
immutable: true
data:
  version: "1.0"
  feature_enabled: "false"
EOF

# Step 2: Create Deployment using v1
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
        config-version: v1
    spec:
      containers:
      - name: app
        image: busybox
        command: ['sh', '-c', 'cat /config/version && sleep 3600']
        volumeMounts:
        - name: config
          mountPath: /config
      volumes:
      - name: config
        configMap:
          name: app-config-v1
EOF

# Step 3: Attempt to update immutable ConfigMap (fails)
kubectl patch configmap app-config-v1 -p '{"data":{"version":"1.1"}}'
# Error: field is immutable

# Step 4: Create new ConfigMap v2
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-v2
immutable: true
data:
  version: "2.0"
  feature_enabled: "true"
  new_setting: "enabled"
EOF

# Step 5: Update Deployment to use v2 (triggers rolling update)
kubectl patch deployment myapp -p '{"spec":{"template":{"metadata":{"labels":{"config-version":"v2"}},"spec":{"volumes":[{"name":"config","configMap":{"name":"app-config-v2"}}]}}}}'

# Watch rolling update
kubectl rollout status deployment myapp

# Verify new version
kubectl exec deployment/myapp -- cat /config/version
# Output: 2.0

# Cleanup
kubectl delete deployment myapp
kubectl delete configmap app-config-v1 app-config-v2
```

**Best practices**:
- Version ConfigMaps in their names: `app-config-v1`, `app-config-v2`
- Use Deployments for automatic rolling updates
- Keep old ConfigMap versions for rollback capability

</details>

## Common CKAD Scenarios

### Scenario 1: Application Configuration Migration

**Task**: Migrate a legacy application from hardcoded environment variables to ConfigMaps.

```bash
# Before: Hardcoded in Deployment
# env:
# - name: DATABASE_HOST
#   value: "mysql.prod.example.com"
# - name: MAX_CONNECTIONS
#   value: "100"

# After: Extract to ConfigMap
kubectl create configmap app-settings \
  --from-literal=DATABASE_HOST=mysql.prod.example.com \
  --from-literal=MAX_CONNECTIONS=100

# Update Deployment to use ConfigMap
kubectl set env deployment/myapp --from=configmap/app-settings
```

**Benefits**: Centralized configuration, easier updates, separation of config from code.

### Scenario 2: Multi-Environment Configuration

**Task**: Manage dev/staging/prod configurations using ConfigMaps.

```bash
# Create environment-specific ConfigMaps
kubectl create configmap app-config --from-literal=env=dev --namespace=dev
kubectl create configmap app-config --from-literal=env=staging --namespace=staging
kubectl create configmap app-config --from-literal=env=prod --namespace=prod

# Or use immutable versioned ConfigMaps
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-prod-v1
  namespace: prod
immutable: true
data:
  database_url: "postgres://prod-db.example.com:5432/app"
  cache_ttl: "3600"
  log_level: "info"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-dev-v1
  namespace: dev
immutable: true
data:
  database_url: "postgres://dev-db.example.com:5432/app"
  cache_ttl: "60"
  log_level: "debug"
EOF
```

### Scenario 3: Configuration Hot-Reload

**Task**: Application detects ConfigMap changes and reloads without restart.

See: [`specs/ckad/updates.yaml`](specs/ckad/updates.yaml) - Scenario 4 demonstrates a config watcher.

```yaml
# Application watches for config file changes using md5sum/inotify
command:
- sh
- -c
- |
  LAST_HASH=""
  while true; do
    CURRENT_HASH=$(md5sum /config/app.conf | cut -d' ' -f1)
    if [ "$LAST_HASH" != "$CURRENT_HASH" ]; then
      echo "Config changed! Reloading..."
      # Reload application configuration
      LAST_HASH=$CURRENT_HASH
    fi
    sleep 5
  done
volumeMounts:
- name: config
  mountPath: /config
```

**Note**: Volume-mounted ConfigMaps update automatically. Environment variables do not.

### Scenario 4: Large Configuration Files

**Task**: Handle configuration files approaching the 1 MiB limit.

```bash
# Problem: ConfigMap too large
kubectl create configmap large-config --from-file=config.json
# Error: Too long: must have at most 1048576 bytes

# Solution 1: Split into multiple ConfigMaps
kubectl create configmap app-config-part1 --from-file=config-part1.json
kubectl create configmap app-config-part2 --from-file=config-part2.json

# Solution 2: Use PersistentVolume for large files
# Solution 3: Compress data (if app supports)
# Solution 4: Use external config service (Consul, etcd)

# Check ConfigMap size
kubectl get configmap large-config -o json | jq '.data | to_entries[] | .key + ": " + (.value | length | tostring)' -r
```

**Best practice**: ConfigMaps are for configuration, not large data files. Use PersistentVolumes for data storage.

## Best Practices for CKAD

1. **Naming Conventions**
   - Use descriptive names: `app-config`, `nginx-config`
   - Version immutable ConfigMaps: `app-config-v1`, `app-config-v2`

2. **Organization**
   - One ConfigMap per application/component
   - Separate environment-specific configs
   - Don't mix secrets with regular config (use Secrets instead)

3. **Size Management**
   - Keep ConfigMaps under 1 MiB
   - Split large configurations into multiple ConfigMaps
   - Consider external config stores for very large files

4. **Update Strategy**
   - Use immutable ConfigMaps for production
   - Version your ConfigMaps
   - Use Deployment rolling updates when changing config

5. **Security**
   - Use `readOnly: true` for volume mounts
   - Set appropriate file permissions (defaultMode)
   - Never store sensitive data (passwords, keys) in ConfigMaps

6. **Environment Variables vs. Files**
   - Use environment variables for: simple values, feature flags
   - Use files for: complex configs, multi-line data, structured data (JSON/YAML)

7. **Handling Missing ConfigMaps**
   - Use `optional: true` for non-critical config
   - Validate ConfigMap exists before deploying dependent resources

## Quick Reference Commands

```bash
# Create ConfigMap from literals
kubectl create configmap myconfig --from-literal=key1=value1 --from-literal=key2=value2

# Create ConfigMap from file
kubectl create configmap myconfig --from-file=config.properties

# Create ConfigMap from directory
kubectl create configmap myconfig --from-file=./config-dir/

# Create ConfigMap from env file
kubectl create configmap myconfig --from-env-file=app.env

# Create ConfigMap with custom key name
kubectl create configmap myconfig --from-file=custom-key=config.properties

# View ConfigMap
kubectl get configmap myconfig -o yaml
kubectl describe configmap myconfig

# Edit ConfigMap
kubectl edit configmap myconfig

# Update ConfigMap from file
kubectl create configmap myconfig --from-file=config.properties --dry-run=client -o yaml | kubectl apply -f -

# Delete ConfigMap
kubectl delete configmap myconfig

# List Pods using a ConfigMap (volume)
kubectl get pods -o json | jq '.items[] | select(.spec.volumes[]?.configMap.name=="myconfig") | .metadata.name'

# Check environment variables in Pod
kubectl exec mypod -- env
kubectl exec mypod -- printenv KEY_NAME

# Check mounted files in Pod
kubectl exec mypod -- ls -la /config
kubectl exec mypod -- cat /config/config.properties

# Watch for ConfigMap changes in mounted volume
kubectl exec mypod -- watch -n 1 cat /config/config.properties
```

## Integration with Other Resources

### ConfigMaps with Deployments

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
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
        image: myapp:1.0
        envFrom:
        - configMapRef:
            name: app-config
        volumeMounts:
        - name: config-volume
          mountPath: /config
          readOnly: true
      volumes:
      - name: config-volume
        configMap:
          name: app-files-config
```

### ConfigMaps with StatefulSets

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: statefulset-config
data:
  base-config: |
    common.setting=value
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: "web"
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      initContainers:
      - name: config-init
        image: busybox
        command:
        - sh
        - -c
        - |
          # Customize config per pod using hostname
          echo "pod.name=$(hostname)" >> /config/pod-config
          cat /config-base/base-config >> /config/pod-config
        volumeMounts:
        - name: config-base
          mountPath: /config-base
        - name: config
          mountPath: /config
      containers:
      - name: web
        image: nginx
        volumeMounts:
        - name: config
          mountPath: /etc/config
      volumes:
      - name: config-base
        configMap:
          name: statefulset-config
      - name: config
        emptyDir: {}
```

### ConfigMaps with Jobs/CronJobs

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: batch-job-config
data:
  script.sh: |
    #!/bin/sh
    echo "Processing batch job..."
    echo "Environment: $ENVIRONMENT"
    echo "Batch size: $BATCH_SIZE"
  environment: "production"
  batch_size: "1000"
---
apiVersion: batch/v1
kind: Job
metadata:
  name: data-processor
spec:
  template:
    spec:
      containers:
      - name: processor
        image: busybox
        command: ["/bin/sh", "/scripts/script.sh"]
        env:
        - name: ENVIRONMENT
          valueFrom:
            configMapKeyRef:
              name: batch-job-config
              key: environment
        - name: BATCH_SIZE
          valueFrom:
            configMapKeyRef:
              name: batch-job-config
              key: batch_size
        volumeMounts:
        - name: scripts
          mountPath: /scripts
      restartPolicy: Never
      volumes:
      - name: scripts
        configMap:
          name: batch-job-config
          defaultMode: 0755  # Executable
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: scheduled-processor
spec:
  schedule: "0 2 * * *"  # Run at 2am daily
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: processor
            image: busybox
            command: ["/bin/sh", "/scripts/script.sh"]
            envFrom:
            - configMapRef:
                name: batch-job-config
            volumeMounts:
            - name: scripts
              mountPath: /scripts
          restartPolicy: OnFailure
          volumes:
          - name: scripts
            configMap:
              name: batch-job-config
              defaultMode: 0755
```

## Cleanup

Remove all ConfigMaps created in these exercises:

```bash
# Delete specific ConfigMap
kubectl delete configmap app-config

# Delete multiple ConfigMaps
kubectl delete configmap config1 config2 config3

# Delete all ConfigMaps with label
kubectl delete configmap -l app=myapp

# Delete all ConfigMaps in namespace (careful!)
kubectl delete configmap --all
```

---

## Next Steps

After mastering ConfigMaps, continue with these CKAD topics:
- [Secrets](../secrets/CKAD.md) - Secure configuration management
- [Persistent Volumes](../persistentvolumes/CKAD.md) - Stateful storage
- [Deployments](../deployments/CKAD.md) - Rolling updates with configuration changes
- [Jobs](../jobs/CKAD.md) - ConfigMaps with batch workloads
