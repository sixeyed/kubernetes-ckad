# Troubleshooting Application Modeling for CKAD

This document extends the [basic troubleshooting-2 lab](README.md) with CKAD exam-focused troubleshooting scenarios.

## CKAD Exam Context

Application modeling troubleshooting is **critical** for CKAD. You'll face scenarios where:
- ConfigMaps or Secrets have wrong keys
- Volume mounts reference non-existent paths
- Namespaces don't exist
- Resource names are mismatched
- Environment variables reference wrong ConfigMap/Secret keys
- Permissions prevent access to resources

**Exam Weight**: Troubleshooting appears across all domains
**Time Target**: 5-8 minutes per troubleshooting scenario

**Exam Tip:** Most CKAD troubleshooting involves reading `kubectl describe` output carefully and checking resource references.

## Common Application Modeling Issues

### Issue 1: ConfigMap Key Mismatch

**Symptom**: Pod crashes or environment variable is empty

**Example Problem**:
```yaml
# ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  database_url: "postgres://db:5432"  # Key name

---
# Pod referencing wrong key
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: app
    image: myapp
    env:
    - name: DB_URL
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: db_url  # Wrong! Should be database_url
```

**Diagnosis**:
```bash
kubectl describe pod app
# Events show: Error: couldn't find key db_url in ConfigMap default/app-config

kubectl get configmap app-config -o yaml
# Check actual keys in data section
```

**Fix**:
```bash
# Option 1: Fix the pod to use correct key
kubectl edit pod app
# Change key: db_url to key: database_url

# Option 2: Fix ConfigMap to match pod expectation
kubectl edit configmap app-config
# Rename database_url to db_url
```

### Issue 2: Secret Not Found

**Symptom**: Pod stuck in `CreateContainerConfigError`

**Example Problem**:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: app
    image: myapp
    env:
    - name: PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-credentials  # Secret doesn't exist
          key: password
```

**Diagnosis**:
```bash
kubectl describe pod app
# Events: Error: secret "db-credentials" not found

kubectl get secrets
# Check if secret exists
```

**Fix**:
```bash
# Create the missing secret
kubectl create secret generic db-credentials --from-literal=password=mypassword

# Or fix pod to reference existing secret
kubectl get secrets  # Find actual secret name
kubectl edit pod app  # Update secret name
```

### Issue 3: Volume Mount Path Mismatch

**Symptom**: Application can't find configuration file

**Example Problem**:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: app
    image: myapp
    volumeMounts:
    - name: config
      mountPath: /etc/app/config  # App expects /app/config
  volumes:
  - name: config
    configMap:
      name: app-config
```

**Diagnosis**:
```bash
kubectl logs app
# Shows: Error: cannot open /app/config/app.conf

kubectl describe pod app
# Check volumeMounts section

kubectl exec app -- ls /etc/app/config
# Verify where files are actually mounted
```

**Fix**:
```bash
kubectl edit pod app
# Change mountPath to /app/config
```

### Issue 4: Wrong Namespace

**Symptom**: Resources not found

**Example Problem**:
```bash
# ConfigMap in namespace 'production'
kubectl create configmap app-config --from-literal=key=value -n production

# Pod in namespace 'default' trying to reference it
kubectl run app --image=myapp --env="CONFIG_FROM_CM=app-config" -n default
# Error: ConfigMap not found
```

**Diagnosis**:
```bash
kubectl get pod app -n default -o yaml | grep namespace
# Pod is in default namespace

kubectl get configmap app-config
# Not found (looking in default)

kubectl get configmap app-config -n production
# Found in production namespace
```

**Fix**:
```bash
# Option 1: Move ConfigMap to same namespace as Pod
kubectl get configmap app-config -n production -o yaml | \
  kubectl apply -n default -f -

# Option 2: Move Pod to same namespace as ConfigMap
kubectl delete pod app -n default
kubectl run app --image=myapp -n production
```

**Key Learning:** ConfigMaps, Secrets, and Pods must be in the same namespace.

### Issue 5: PersistentVolumeClaim Bound to Wrong PV

**Symptom**: Pod using wrong storage

**Example Problem**:
```yaml
# PVC requests 10Gi but binds to 1Gi PV
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-storage
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

**Diagnosis**:
```bash
kubectl get pvc app-storage
# Shows: Bound to pv-1gi

kubectl describe pvc app-storage
# Check which PV it bound to and capacity

kubectl get pv
# List all PVs and their capacities
```

**Fix**:
```bash
# Delete and recreate PVC with specific PV or StorageClass
kubectl delete pvc app-storage
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-storage
spec:
  storageClassName: fast-storage  # Specific StorageClass
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
EOF
```

## CKAD Troubleshooting Scenarios

### Scenario 1: Debug ConfigMap Issues

**Task**: An application pod is failing. The pod should read configuration from a ConfigMap. Identify and fix the issue.

<details>
  <summary>Step-by-Step Solution</summary>

```bash
# Step 1: Create broken scenario
kubectl create configmap webapp-config --from-literal=server_port=8080

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: webapp
spec:
  containers:
  - name: app
    image: nginx
    env:
    - name: PORT
      valueFrom:
        configMapKeyRef:
          name: webapp-config
          key: port  # Wrong key!
EOF

# Step 2: Check pod status
kubectl get pod webapp
# Shows: CreateContainerConfigError

# Step 3: Describe pod to find issue
kubectl describe pod webapp
# Events: Error: couldn't find key port in ConfigMap default/webapp-config

# Step 4: Check ConfigMap keys
kubectl get configmap webapp-config -o yaml
# Shows: server_port is the actual key

# Step 5: Fix the pod
kubectl delete pod webapp

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: webapp
spec:
  containers:
  - name: app
    image: nginx
    env:
    - name: PORT
      valueFrom:
        configMapKeyRef:
          name: webapp-config
          key: server_port  # Corrected
EOF

# Step 6: Verify fix
kubectl get pod webapp
# Shows: Running

kubectl exec webapp -- env | grep PORT
# Shows: PORT=8080
```

**Key Learning:** Always verify ConfigMap/Secret keys match exactly what the Pod references.

</details><br />

### Scenario 2: Debug Volume Mount Issues

**Task**: A pod should mount a ConfigMap as a volume at `/config`. The pod is running but the application can't find the config file. Fix it.

<details>
  <summary>Step-by-Step Solution</summary>

```bash
# Step 1: Create scenario
kubectl create configmap app-conf --from-literal=app.properties="debug=true"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: config-app
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'cat /app/config/app.properties && sleep 3600']
    volumeMounts:
    - name: config-vol
      mountPath: /config  # Wrong path!
  volumes:
  - name: config-vol
    configMap:
      name: app-conf
EOF

# Step 2: Check pod logs
kubectl logs config-app
# Error: cat: can't open '/app/config/app.properties': No such file or directory

# Step 3: Check where volume is actually mounted
kubectl exec config-app -- ls /config
# Shows: app.properties (file exists here)

kubectl exec config-app -- ls /app/config
# Error: No such file or directory

# Step 4: Identify the issue
# App expects /app/config but volume is mounted at /config

# Step 5: Fix the mount path
kubectl delete pod config-app

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: config-app
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'cat /app/config/app.properties && sleep 3600']
    volumeMounts:
    - name: config-vol
      mountPath: /app/config  # Corrected
  volumes:
  - name: config-vol
    configMap:
      name: app-conf
EOF

# Step 6: Verify fix
kubectl logs config-app
# Shows: debug=true
```

**Key Learning:** Verify mount paths match what the application expects.

</details><br />

### Scenario 3: Debug Namespace Issues

**Task**: A deployment references a Secret for database credentials. The deployment is in namespace `app` but the Secret is in `default`. Fix the issue.

<details>
  <summary>Step-by-Step Solution</summary>

```bash
# Step 1: Create scenario
kubectl create namespace app

kubectl create secret generic db-creds \
  --from-literal=username=admin \
  --from-literal=password=secret

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: app
        image: nginx
        env:
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: db-creds
              key: username
EOF

# Step 2: Check pod status
kubectl get pods -n app
# Shows: CreateContainerConfigError

# Step 3: Describe pod
kubectl describe pod -n app -l app=backend
# Events: Error: secret "db-creds" not found

# Step 4: Check where secret exists
kubectl get secret db-creds -n app
# Error: not found

kubectl get secret db-creds -n default
# Found in default namespace

# Step 5: Fix by creating secret in app namespace
kubectl get secret db-creds -n default -o yaml | \
  sed 's/namespace: default/namespace: app/' | \
  kubectl apply -f -

# Or simpler:
kubectl create secret generic db-creds \
  --from-literal=username=admin \
  --from-literal=password=secret \
  -n app

# Step 6: Verify fix
kubectl get pods -n app
# Shows: Running

kubectl exec -n app deployment/backend -- env | grep DB_USER
# Shows: DB_USER=admin
```

**Key Learning:** ConfigMaps and Secrets must be in the same namespace as the Pods that use them.

</details><br />

## Quick Troubleshooting Checklist

When a pod fails due to configuration issues:

- [ ] Check pod status: `kubectl get pod <name>`
- [ ] Read events: `kubectl describe pod <name>`
- [ ] Check logs: `kubectl logs <name>`
- [ ] Verify ConfigMap exists: `kubectl get cm <name>`
- [ ] Verify Secret exists: `kubectl get secret <name>`
- [ ] Check ConfigMap/Secret keys: `kubectl get cm/secret <name> -o yaml`
- [ ] Verify correct namespace: `kubectl get pod <name> -o yaml | grep namespace`
- [ ] Check volume mounts: `kubectl exec <pod> -- ls <mount-path>`
- [ ] Verify PVC status: `kubectl get pvc`
- [ ] Check resource names match exactly (case-sensitive!)

## Common Error Messages and Fixes

| Error Message | Cause | Fix |
|---------------|-------|-----|
| `couldn't find key X in ConfigMap` | Wrong key name | Check ConfigMap keys with `kubectl get cm -o yaml` |
| `secret "X" not found` | Secret doesn't exist or wrong namespace | Create secret or check namespace |
| `persistentvolumeclaim "X" not found` | PVC doesn't exist | Create PVC first |
| `CreateContainerConfigError` | ConfigMap/Secret issue | Check describe output for details |
| `No such file or directory` | Wrong volume mount path | Check mountPath matches application expectation |
| `not found` in logs | Application can't find config/secret files | Verify volume mounts and subPaths |

## Exam Tips

1. **Always start with describe**: `kubectl describe pod` shows most issues
2. **Check the namespace**: Many issues are namespace-related
3. **Verify names match exactly**: Kubernetes is case-sensitive
4. **Check keys in ConfigMaps/Secrets**: Use `-o yaml` to see actual keys
5. **Test volume mounts**: Use `kubectl exec` to verify files are where expected
6. **Read events carefully**: They usually point directly to the problem
7. **Check both pod and referenced resources**: ConfigMap might exist but have wrong keys
8. **Remember namespace scope**: ConfigMaps, Secrets, PVCs are namespaced
9. **Use -o yaml**: Great for seeing exact configuration
10. **Practice systematically**: Follow the same troubleshooting pattern every time

## Practice Exercises

```bash
# Exercise 1: Wrong ConfigMap key
kubectl create cm test-config --from-literal=app_name=myapp
kubectl run test --image=nginx --env="NAME=test-config:name"  # Wrong key
# Fix it!

# Exercise 2: Missing Secret
kubectl run secure-app --image=nginx --dry-run=client -o yaml > pod.yaml
# Edit to reference non-existent secret
kubectl apply -f pod.yaml
# Debug and fix!

# Exercise 3: Wrong namespace
kubectl create ns prod
kubectl create cm config --from-literal=env=dev
kubectl run app --image=nginx -n prod
# Edit to reference config CM
# Debug namespace issue!
```

## Summary

Application modeling troubleshooting is about systematically checking:

✅ **Key Skills:**
- Reading `kubectl describe` output
- Verifying resource names and keys
- Checking namespaces match
- Testing volume mounts
- Understanding error messages

✅ **Common Issues:**
- ConfigMap/Secret key mismatches
- Wrong namespaces
- Volume mount path errors
- Missing resources
- Name typos

🎯 **Exam relevance**: High - troubleshooting appears in every exam
⏱️ **Time target**: 5-8 minutes per scenario
📊 **Difficulty**: Medium (requires systematic approach)

Practice troubleshooting until your diagnostic process is automatic!
