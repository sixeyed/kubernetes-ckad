# CKAD Practice: PersistentVolumes and Storage

This guide covers CKAD exam requirements for working with persistent volumes and storage. Complete the [basic lab](README.md) first to understand the fundamentals.

## CKAD Exam Relevance

**Exam Domain**: Application Environment, Configuration and Security (25%)
- Understand and define resource requirements and limits
- Understand ConfigMaps and Secrets
- **Create and consume PersistentVolumeClaims for storage**

## Quick Reference

### Common kubectl Commands

```bash
# List storage resources
kubectl get pv                           # PersistentVolumes (cluster-wide)
kubectl get pvc                          # PersistentVolumeClaims (namespaced)
kubectl get sc                           # StorageClasses

# Describe for troubleshooting
kubectl describe pvc <name>
kubectl describe pv <name>

# Check Pod volume mounts
kubectl describe pod <name> | grep -A 5 Volumes
kubectl exec <pod> -- df -h              # Check mounted filesystems

# Delete PVC (may delete PV depending on reclaim policy)
kubectl delete pvc <name>
```

### Access Modes Quick Reference

| Mode | Abbreviation | Description | Use Case |
|------|--------------|-------------|----------|
| ReadWriteOnce | RWO | Read-write by single node | Most common, default for block storage |
| ReadOnlyMany | ROX | Read-only by multiple nodes | Shared configuration data |
| ReadWriteMany | RWX | Read-write by multiple nodes | Shared application data (requires NFS/similar) |
| ReadWriteOncePod | RWOP | Read-write by single Pod | Kubernetes 1.22+ for strict single-Pod access |

## CKAD Scenarios

### Scenario 1: Create a PVC and Mount in a Pod

**Time Target**: 3-4 minutes

Create a PVC requesting 500Mi of storage, then deploy a Pod that uses it.

```bash
# Create PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-storage
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
EOF

# Create Pod using the PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
spec:
  containers:
  - name: app
    image: nginx:alpine
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: app-storage
EOF

# Verify
kubectl get pvc app-storage
kubectl exec app-pod -- df -h /data
```

**Verification**:
- PVC should be in `Bound` status
- Pod should be in `Running` status
- `/data` should show mounted filesystem with ~500Mi capacity

### Scenario 2: Shared Volume Between Containers

**Time Target**: 4-5 minutes

Create a multi-container Pod where one container writes data and another reads it using a shared volume.

**Real-World Use Case**: Log aggregation is a common sidecar pattern where the main application writes logs to a shared volume, and a sidecar container processes, filters, or forwards those logs to a centralized logging system (like ELK, Splunk, or CloudWatch).

```bash
kubectl apply -f labs/persistentvolumes/specs/ckad/logs-aggregator-sidecar.yaml
```

This creates two example Pods:
1. **log-aggregator-app**: Main container writes application logs, sidecar processes and aggregates them
2. **log-forwarder-pattern**: Simulates how tools like Fluentd or Filebeat forward logs

Verify the log aggregation:
```bash
# Check main application logs
kubectl logs log-aggregator-app -c app

# Check aggregated logs from sidecar
kubectl logs log-aggregator-app -c log-aggregator

# Watch real-time aggregation
kubectl logs -f log-aggregator-app -c log-aggregator
```

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: shared-volume-pod
spec:
  volumes:
  - name: shared-data
    emptyDir: {}
  containers:
  - name: writer
    image: busybox
    command: ["/bin/sh", "-c"]
    args:
      - while true; do
          echo "$(date) - Log entry" >> /data/app.log;
          sleep 5;
        done
    volumeMounts:
    - name: shared-data
      mountPath: /data
  - name: reader
    image: busybox
    command: ["/bin/sh", "-c"]
    args:
      - tail -f /data/app.log
    volumeMounts:
    - name: shared-data
      mountPath: /data
EOF

# Verify both containers can access the shared volume
kubectl logs shared-volume-pod -c writer
kubectl logs shared-volume-pod -c reader
```

**Key Learning**: EmptyDir volumes are shared between all containers in a Pod.

### Scenario 3: Use Specific StorageClass

**Time Target**: 3-4 minutes

Create a PVC using a specific StorageClass (useful when cluster has multiple storage types).

**Cloud Provider StorageClass Examples**:

Different cloud providers offer different storage classes optimized for various workloads. Here are common examples:

<details>
<summary>AWS EKS Storage Classes</summary>

```yaml
# AWS EBS gp3 (General Purpose SSD - recommended)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: aws-ebs-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp3
  resources:
    requests:
      storage: 10Gi

# AWS EBS io2 (Provisioned IOPS - high performance)
# Use for databases requiring consistent low latency
storageClassName: io2  # Change to io2 for high-performance workloads
```

Common AWS StorageClasses:
- `gp3`: General Purpose SSD (latest generation)
- `gp2`: General Purpose SSD (previous generation)
- `io2`: Provisioned IOPS SSD (high performance)
- `st1`: Throughput Optimized HDD (big data)
- `sc1`: Cold HDD (infrequent access)

</details>

<details>
<summary>Azure AKS Storage Classes</summary>

```yaml
# Azure Premium SSD
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: azure-disk-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: managed-premium
  resources:
    requests:
      storage: 10Gi

# Azure Standard SSD (cost-effective)
storageClassName: managed  # For less demanding workloads
```

Common Azure StorageClasses:
- `managed-premium`: Premium SSD (production workloads)
- `managed`: Standard SSD (balanced performance/cost)
- `azurefile`: Azure Files for ReadWriteMany scenarios
- `azurefile-premium`: Premium Azure Files

</details>

<details>
<summary>GCP GKE Storage Classes</summary>

```yaml
# GCP Standard Persistent Disk
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: gcp-pd-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: standard-rwo
  resources:
    requests:
      storage: 10Gi

# GCP SSD Persistent Disk (higher performance)
storageClassName: premium-rwo  # For performance-critical workloads
```

Common GCP StorageClasses:
- `standard-rwo`: Standard Persistent Disk (HDD)
- `premium-rwo`: SSD Persistent Disk
- `balanced-rwo`: Balanced Persistent Disk (SSD)

</details>

See complete examples in `labs/persistentvolumes/specs/ckad/cloud-provider-examples.yaml`

```bash
# First, check available StorageClasses
kubectl get storageclass

# Create PVC with specific StorageClass
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: fast-storage
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: <your-storage-class-name>  # Replace with actual name
  resources:
    requests:
      storage: 1Gi
EOF

kubectl get pvc fast-storage
```

**Exam Tip**: If no `storageClassName` is specified, the default StorageClass is used.

### Scenario 4: Troubleshoot Pending PVC

**Time Target**: 3-4 minutes

Common reasons why a PVC stays in `Pending` state:

```bash
# Create a PVC that might have issues
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: debug-pvc
spec:
  accessModes:
    - ReadWriteMany  # May not be supported by default StorageClass
  resources:
    requests:
      storage: 100Gi  # May exceed available storage
EOF

# Troubleshooting steps
kubectl get pvc debug-pvc
kubectl describe pvc debug-pvc  # Check Events section

# Common issues and solutions:
# 1. Unsupported access mode → Change to ReadWriteOnce
# 2. No StorageClass available → Specify valid storageClassName
# 3. Insufficient storage → Reduce storage request
# 4. No nodes with required labels (for local PV) → Add labels to nodes
```

**Troubleshooting Checklist**:
1. Check PVC status: `kubectl get pvc`
2. View events: `kubectl describe pvc <name>`
3. Check available StorageClasses: `kubectl get sc`
4. Verify StorageClass provisioner is running
5. Check if cluster has capacity for requested size

### Scenario 5: Pod with Multiple Volumes

**Time Target**: 5-6 minutes

Create a Pod with multiple volume types (common in real-world scenarios).

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: db-storage
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  config.json: |
    {
      "database": "/data/db",
      "cache": "/cache",
      "logs": "/logs"
    }
---
apiVersion: v1
kind: Pod
metadata:
  name: multi-volume-app
spec:
  containers:
  - name: app
    image: busybox
    command: ["/bin/sh", "-c", "cat /config/config.json && sleep 3600"]
    volumeMounts:
    - name: persistent-data
      mountPath: /data
    - name: cache-data
      mountPath: /cache
    - name: logs
      mountPath: /logs
    - name: config
      mountPath: /config
  volumes:
  - name: persistent-data
    persistentVolumeClaim:
      claimName: db-storage
  - name: cache-data
    emptyDir: {}
  - name: logs
    emptyDir: {}
  - name: config
    configMap:
      name: app-config
EOF

# Verify all volumes are mounted
kubectl exec multi-volume-app -- df -h
kubectl exec multi-volume-app -- cat /config/config.json
```

**Key Learning**: Different volume types serve different purposes:
- PVC for persistent data
- EmptyDir for temporary/cache data
- ConfigMap for configuration files

### Scenario 6: Data Persistence After Pod Deletion

**Time Target**: 4-5 minutes

Demonstrate that PVC data persists even when Pods are deleted.

```bash
# Create PVC and Pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: persistent-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: writer-pod
spec:
  containers:
  - name: writer
    image: busybox
    command: ["/bin/sh", "-c"]
    args:
      - echo "Important data: $(date)" > /data/important.txt &&
        cat /data/important.txt &&
        sleep 3600
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: persistent-data
EOF

# Wait for Pod to write data
sleep 5
kubectl logs writer-pod

# Delete the Pod
kubectl delete pod writer-pod

# Create new Pod with same PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: reader-pod
spec:
  containers:
  - name: reader
    image: busybox
    command: ["/bin/sh", "-c"]
    args:
      - cat /data/important.txt && sleep 3600
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: persistent-data
EOF

# Verify data persisted
kubectl logs reader-pod
```

**Key Learning**: PVC lifecycle is independent of Pod lifecycle.

## Advanced CKAD Topics

### Volume SubPaths

Use `subPath` to mount specific files or subdirectories from a volume:

**Real-World Use Cases**:

1. **Single file mounts**: Mount a specific config file without hiding other files in the directory
2. **Shared PVC isolation**: Multiple applications share one PVC but access different subdirectories
3. **Database separation**: Separate data, logs, and config on the same volume
4. **Multi-tenant applications**: Isolate tenant data using subdirectories

<details>
<summary>Example 1: Mount Single Config File</summary>

```yaml
# Mount only nginx.conf without hiding other files in /etc/nginx/conf.d/
apiVersion: v1
kind: Pod
metadata:
  name: subpath-example
spec:
  containers:
  - name: app
    image: nginx:alpine
    volumeMounts:
    - name: config-volume
      mountPath: /etc/nginx/nginx.conf
      subPath: nginx.conf  # Mount only this file, not entire ConfigMap
  volumes:
  - name: config-volume
    configMap:
      name: nginx-config
```

</details>

<details>
<summary>Example 2: Shared PVC with Multiple Deployments</summary>

```yaml
# Two deployments sharing one PVC, each using their own subdirectory
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-app-storage
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
---
# Deployment 1 uses /app1 subdirectory
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app1
  template:
    metadata:
      labels:
        app: app1
    spec:
      containers:
      - name: app
        image: nginx:alpine
        volumeMounts:
        - name: data
          mountPath: /data
          subPath: app1  # Only accesses app1 subdirectory
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: shared-app-storage
```

**Note**: With ReadWriteOnce, only one Pod can mount at a time. Use ReadWriteMany for simultaneous access.

</details>

<details>
<summary>Example 3: Database with Separate Subdirectories</summary>

```yaml
# PostgreSQL with separate data and logs subdirectories
apiVersion: v1
kind: Pod
metadata:
  name: postgres-subpaths
spec:
  containers:
  - name: postgres
    image: postgres:14-alpine
    env:
    - name: POSTGRES_PASSWORD
      value: "example"
    - name: PGDATA
      value: /var/lib/postgresql/data/pgdata
    volumeMounts:
    - name: storage
      mountPath: /var/lib/postgresql/data
      subPath: data
    - name: storage
      mountPath: /var/log/postgresql
      subPath: logs
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: database-storage
```

</details>

<details>
<summary>Example 4: Dynamic subPath with Environment Variables</summary>

```yaml
# Use subPathExpr to create tenant-specific directories
apiVersion: v1
kind: Pod
metadata:
  name: multi-tenant
spec:
  containers:
  - name: app
    image: busybox
    env:
    - name: TENANT_ID
      value: "tenant-123"
    volumeMounts:
    - name: data
      mountPath: /data
      subPathExpr: $(TENANT_ID)/data  # Creates tenant-specific path
  volumes:
  - name: data
    emptyDir: {}
```

</details>

Complete examples in `labs/persistentvolumes/specs/ckad/subpath-shared-pvc.yaml`

**Use Case**: When you need to mount a single file without hiding other files in the target directory, or when organizing multiple applications on shared storage.

### Volume Expansion

Some StorageClasses support volume expansion, allowing you to increase PVC size without recreating resources.

**Step-by-Step Volume Expansion Example**:

```bash
# Step 1: Verify StorageClass supports expansion
kubectl get sc -o yaml | grep allowVolumeExpansion
# Should show: allowVolumeExpansion: true

# Step 2: Create PVC with expandable StorageClass
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: expandable-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: <your-expandable-storage-class>
  resources:
    requests:
      storage: 1Gi
EOF

# Step 3: Create Pod using the PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: expansion-test
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "df -h /data && sleep 3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: expandable-pvc
EOF

# Step 4: Check current size
kubectl exec expansion-test -- df -h /data

# Step 5: Expand the PVC to 2Gi
kubectl patch pvc expandable-pvc -p '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}'

# Step 6: Monitor expansion progress
kubectl get pvc expandable-pvc -w
kubectl describe pvc expandable-pvc | grep -A 5 Conditions

# Step 7: For offline expansion, restart the Pod
kubectl delete pod expansion-test
kubectl apply -f <pod-spec>  # Recreate the Pod

# Step 8: Verify new size
kubectl exec expansion-test -- df -h /data
```

**Volume Type Expansion Support**:

| Volume Type | Online Expansion | Offline Expansion | Not Supported |
|-------------|------------------|-------------------|---------------|
| AWS EBS (gp2, gp3, io1, io2) | ✅ | - | - |
| Azure Disk (Premium, Standard SSD) | ✅ | - | - |
| GCP Persistent Disk (all types) | ✅ | - | - |
| Ceph RBD | ✅ | - | - |
| Cinder (OpenStack) | ✅ | - | - |
| Portworx | ✅ | - | - |
| Azure File | - | ✅ | - |
| GlusterFS | - | ✅ | - |
| HostPath | - | - | ❌ |
| Local Volumes | - | - | ❌ |
| EmptyDir | - | - | ❌ (ephemeral) |
| NFS | Depends on backend | Depends on backend | - |

**Key Differences**:
- **Online Expansion**: No Pod restart required, filesystem automatically resizes
- **Offline Expansion**: Pod restart required to complete filesystem resize
- **Not Supported**: Volume type does not support expansion at all

**Important Notes**:
- You can only INCREASE volume size, never decrease
- Expansion is a one-way operation
- Some cloud providers have quota limits on expansion
- Always verify StorageClass has `allowVolumeExpansion: true`

See complete working example in `labs/persistentvolumes/specs/ckad/volume-expansion.yaml`

**Exam Note**: Not all storage types support expansion. Check the StorageClass configuration before attempting expansion.

### ReadWriteMany Volumes

For scenarios requiring shared storage across multiple Pods:

**Practical Exercise: Deploy NFS for ReadWriteMany**

ReadWriteMany (RWX) access mode allows multiple Pods on different nodes to mount the same volume simultaneously. This requires network-based storage.

<details>
<summary>Option 1: Simple NFS Server for Testing (Single-Node Clusters)</summary>

```bash
# Deploy NFS server and create RWX PVC
kubectl apply -f labs/persistentvolumes/specs/ckad/nfs-provisioner.yaml

# Wait for NFS server to be ready
kubectl wait --for=condition=Ready pod -l app=nfs-server -n nfs-provisioner --timeout=60s

# Verify PVC is bound
kubectl get pvc shared-nfs-pvc

# Deploy multiple Pods using the shared volume
kubectl get pods -l app=nfs-writer
kubectl get pods -l app=nfs-reader

# Verify shared access - check logs from readers
kubectl logs -l app=nfs-reader --tail=10

# All reader Pods should see data written by all writer Pods
```

</details>

<details>
<summary>Option 2: HostPath RWX (Docker Desktop/Minikube Only)</summary>

```yaml
# WARNING: Only works on single-node clusters!
apiVersion: v1
kind: PersistentVolume
metadata:
  name: hostpath-rwx
spec:
  capacity:
    storage: 2Gi
  accessModes:
    - ReadWriteMany
  hostPath:
    path: /tmp/shared-data
    type: DirectoryOrCreate
```

</details>

**Troubleshooting ReadWriteMany by Cluster Type**:

<details>
<summary>AWS EKS - RWX Issues</summary>

**Problem**: PVC with ReadWriteMany stays in Pending state

**Cause**: EBS volumes only support ReadWriteOnce

**Solution**: Use AWS EFS (Elastic File System)

```bash
# Install EFS CSI Driver
kubectl apply -k "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.5"

# Create EFS filesystem in AWS Console or with AWS CLI
# Note your EFS filesystem ID (fs-xxxxxx)

# Create StorageClass for EFS
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: fs-xxxxxx  # Replace with your EFS ID
  directoryPerms: "700"
EOF

# Create PVC with ReadWriteMany
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: efs-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: efs-sc
  resources:
    requests:
      storage: 5Gi
EOF
```

</details>

<details>
<summary>Azure AKS - RWX Issues</summary>

**Problem**: Azure Disk doesn't support ReadWriteMany

**Solution**: Use Azure Files (built-in support)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: azure-files-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: azurefile  # Built-in StorageClass
  resources:
    requests:
      storage: 5Gi
```

**Alternative**: Azure NetApp Files for enterprise scenarios

</details>

<details>
<summary>GCP GKE - RWX Issues</summary>

**Problem**: GCP Persistent Disk doesn't support ReadWriteMany

**Solution**: Use Google Filestore

```bash
# Install Filestore CSI Driver
kubectl apply -f https://github.com/kubernetes-sigs/gcp-filestore-csi-driver/raw/master/deploy/kubernetes/overlays/stable/deploy-driver.yaml

# Create Filestore instance (via GCP Console or gcloud)
# Then create PVC referencing Filestore
```

**Alternative**: Use ReadOnlyMany if data is read-only

</details>

<details>
<summary>Docker Desktop / Minikube - RWX Issues</summary>

**Problem**: No RWX support in default StorageClass

**Solutions**:
1. Use hostPath with RWX (works since it's single-node)
2. Deploy simple NFS server (see nfs-provisioner.yaml)
3. Use EmptyDir for testing (not persistent)

</details>

<details>
<summary>General RWX Troubleshooting Commands</summary>

```bash
# Check which StorageClasses support RWX
kubectl get sc -o custom-columns=NAME:.metadata.name,PROVISIONER:.provisioner

# Describe pending PVC to see error
kubectl describe pvc <pvc-name>

# Check if Pods are on different nodes
kubectl get pods -o wide

# Verify volume is mounted in Pod
kubectl exec <pod-name> -- mount | grep <mount-path>

# Test concurrent writes from multiple Pods
kubectl exec <pod-1> -- sh -c 'echo "Pod 1 write" >> /data/test.txt'
kubectl exec <pod-2> -- sh -c 'echo "Pod 2 write" >> /data/test.txt'
kubectl exec <pod-1> -- cat /data/test.txt  # Should see both writes
```

</details>

Complete examples and troubleshooting guide in `labs/persistentvolumes/specs/ckad/nfs-provisioner.yaml`

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-storage
spec:
  accessModes:
    - ReadWriteMany  # Multiple nodes can mount read-write
  resources:
    requests:
      storage: 5Gi
  # storageClassName: nfs-storage  # Typically requires NFS or similar
```

**Important**:
- Default StorageClasses (like AWS EBS, Azure Disk) typically only support `ReadWriteOnce`
- `ReadWriteMany` requires network storage (NFS, CephFS, etc.)
- Check your cluster's available StorageClasses

## CKAD Practice Exercises

### Exercise 1: Quick PVC Creation

**Objective**: Create resources quickly (exam time pressure simulation)

1. Create a PVC named `webapp-storage` requesting 250Mi with ReadWriteOnce access
2. Create a Deployment named `webapp` with 2 replicas using `nginx:alpine` image
3. Mount the PVC to `/usr/share/nginx/html` in all Pods
4. Verify all Pods are running and have the volume mounted

**Time Limit**: 5 minutes

<details>
<summary>Solution</summary>

```bash
# Create PVC
kubectl create -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: webapp-storage
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 250Mi
EOF

# Create Deployment
kubectl create deployment webapp --image=nginx:alpine --replicas=2 --dry-run=client -o yaml | \
kubectl patch -f - --dry-run=client -o yaml --type=json -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/volumes",
    "value": [{"name": "storage", "persistentVolumeClaim": {"claimName": "webapp-storage"}}]
  },
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/volumeMounts",
    "value": [{"name": "storage", "mountPath": "/usr/share/nginx/html"}]
  }
]' | kubectl apply -f -

# Verify
kubectl get pvc webapp-storage
kubectl get pods -l app=webapp
kubectl exec -it deployment/webapp -- df -h /usr/share/nginx/html
```

</details>

### Exercise 2: Debug Storage Issues

**Objective**: Troubleshoot common PVC problems

You're given a Pod that won't start due to storage issues. Fix it.

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: broken-pod
spec:
  containers:
  - name: app
    image: nginx:alpine
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: missing-pvc  # This PVC doesn't exist!
EOF
```

**Tasks**:
1. Identify why the Pod is failing
2. Create the missing PVC
3. Verify the Pod starts successfully

**Time Limit**: 3 minutes

<details>
<summary>Solution</summary>

```bash
# Check Pod status
kubectl get pod broken-pod
kubectl describe pod broken-pod  # Shows: PVC "missing-pvc" not found

# Create the missing PVC
kubectl create -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: missing-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Mi
EOF

# Delete and recreate Pod (or wait for kubelet to retry)
kubectl delete pod broken-pod
kubectl apply -f <original-pod-spec>

# Verify
kubectl get pod broken-pod
kubectl get pvc missing-pvc
```

</details>

### Exercise 3: Multi-Container Shared Storage

**Objective**: Implement sidecar pattern with shared volumes

Create a Pod with:
1. Main container: `nginx:alpine` serving files from `/usr/share/nginx/html`
2. Sidecar container: `busybox` writing the current date to `/html/index.html` every 5 seconds
3. Both containers share an EmptyDir volume

Verify you can curl the nginx service and see updated timestamps.

**Time Limit**: 6 minutes

<details>
<summary>Solution</summary>

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: shared-web-pod
  labels:
    app: shared-web
spec:
  volumes:
  - name: html
    emptyDir: {}
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
    volumeMounts:
    - name: html
      mountPath: /usr/share/nginx/html
  - name: writer
    image: busybox
    command: ["/bin/sh", "-c"]
    args:
      - while true; do
          echo "<h1>Last updated: $(date)</h1>" > /html/index.html;
          sleep 5;
        done
    volumeMounts:
    - name: html
      mountPath: /html
---
apiVersion: v1
kind: Service
metadata:
  name: shared-web
spec:
  selector:
    app: shared-web
  ports:
  - port: 80
    targetPort: 80
  type: NodePort
EOF

# Wait for Pod to be ready
kubectl wait --for=condition=Ready pod/shared-web-pod

# Test (wait a few seconds between calls to see timestamp change)
kubectl exec shared-web-pod -c nginx -- cat /usr/share/nginx/html/index.html
sleep 6
kubectl exec shared-web-pod -c nginx -- cat /usr/share/nginx/html/index.html
```

</details>

**Advanced Variations**:

For more realistic production scenarios, see advanced sidecar patterns in `labs/persistentvolumes/specs/ckad/advanced-sidecar.yaml`:

1. **Log Rotation**: Sidecar automatically rotates application logs to prevent disk space issues
2. **Metrics Collection**: Sidecar collects and aggregates application metrics
3. **Configuration Reloader**: Sidecar watches for config changes and notifies the main container
4. **Security Scanner**: Sidecar scans uploaded files for malicious content
5. **Backup Agent**: Sidecar performs periodic backups of application data

**Example: Deploy Log Rotation Sidecar**

```bash
kubectl apply -f labs/persistentvolumes/specs/ckad/advanced-sidecar.yaml

# Check log rotation in action
kubectl logs log-rotation-pod -c app --tail=20
kubectl logs log-rotation-pod -c log-rotator --tail=20

# Verify rotated log files
kubectl exec log-rotation-pod -c log-rotator -- ls -lh /var/log/app/
```

### Exercise 4: StatefulSet with PVC Templates

**Objective**: Understand how StatefulSets manage persistent storage

**Time Limit**: 8 minutes

This is an advanced topic that may appear in CKAD scenarios involving databases or stateful applications.

StatefulSets use `volumeClaimTemplates` to automatically create a dedicated PVC for each Pod. These PVCs persist even when Pods are deleted or the StatefulSet is scaled down.

<details>
<summary>Solution</summary>

**Step 1: Deploy StatefulSet with volumeClaimTemplates**

```bash
kubectl apply -f labs/persistentvolumes/specs/ckad/statefulset-pvc.yaml

# Wait for all Pods to be ready
kubectl get statefulset web -w
# Ctrl+C when all 3 Pods are Running

# Check created Pods (predictable names: web-0, web-1, web-2)
kubectl get pods -l app=nginx-stateful
```

**Step 2: Verify PVCs were created automatically**

```bash
# Each Pod gets its own PVC named: {volumeClaimTemplate-name}-{statefulset-name}-{ordinal}
kubectl get pvc

# Should see: www-web-0, www-web-1, www-web-2
# All should be in Bound status
```

**Step 3: Write unique data to each Pod**

```bash
# Write to web-0
kubectl exec web-0 -- sh -c 'echo "Data from web-0 at $(date)" >> /usr/share/nginx/html/data.txt'

# Write to web-1
kubectl exec web-1 -- sh -c 'echo "Data from web-1 at $(date)" >> /usr/share/nginx/html/data.txt'

# Write to web-2
kubectl exec web-2 -- sh -c 'echo "Data from web-2 at $(date)" >> /usr/share/nginx/html/data.txt'

# Verify each Pod has different data
kubectl exec web-0 -- cat /usr/share/nginx/html/data.txt
kubectl exec web-1 -- cat /usr/share/nginx/html/data.txt
kubectl exec web-2 -- cat /usr/share/nginx/html/data.txt
```

**Step 4: Test PVC retention after Pod deletion**

```bash
# Delete web-1
kubectl delete pod web-1

# StatefulSet automatically recreates web-1
kubectl get pods -l app=nginx-stateful -w
# Ctrl+C when web-1 is Running again

# Verify data persisted (should see same data as before)
kubectl exec web-1 -- cat /usr/share/nginx/html/data.txt
```

**Step 5: Scale down and verify PVC retention**

```bash
# Scale down to 1 replica
kubectl scale statefulset web --replicas=1

# Check Pods (only web-0 should remain)
kubectl get pods -l app=nginx-stateful

# IMPORTANT: PVCs still exist even though Pods are gone!
kubectl get pvc
# Should still see: www-web-0, www-web-1, www-web-2
```

**Step 6: Scale back up and verify data persists**

```bash
# Scale back up to 3 replicas
kubectl scale statefulset web --replicas=3

# Wait for Pods to be ready
kubectl wait --for=condition=Ready pod/web-2 --timeout=60s

# Verify data persisted through scaling
kubectl exec web-1 -- cat /usr/share/nginx/html/data.txt
kubectl exec web-2 -- cat /usr/share/nginx/html/data.txt

# Data should be intact - Pods reconnected to their original PVCs!
```

**Step 7: Understand PVC lifecycle**

```bash
# Even if you delete the StatefulSet, PVCs remain
kubectl delete statefulset web

# PVCs still exist (prevents accidental data loss)
kubectl get pvc

# Manual cleanup required
kubectl delete pvc www-web-0 www-web-1 www-web-2
```

**Key Learnings**:

1. **Automatic PVC Creation**: `volumeClaimTemplates` creates one PVC per Pod
2. **Predictable Naming**: PVCs follow pattern `{template-name}-{statefulset-name}-{ordinal}`
3. **Stable Identity**: Each Pod always reconnects to its original PVC
4. **PVC Retention**: PVCs persist through Pod deletion, scaling, and even StatefulSet deletion
5. **Manual Cleanup**: You must manually delete PVCs when done

**Additional Examples in statefulset-pvc.yaml**:
- PostgreSQL cluster with separate data and log volumes
- OrderedReady vs Parallel pod management
- Complete troubleshooting guide

</details>

**Test Script**: See `labs/persistentvolumes/specs/ckad/statefulset-pvc.yaml` for automated test script that demonstrates all PVC retention behaviors.

## Common Exam Pitfalls

### 1. PVC in Wrong Namespace
```bash
# PVCs are namespaced! Ensure you're in the correct namespace
kubectl config set-context --current --namespace=<target-namespace>
```

### 2. Access Mode Incompatibility
```bash
# ReadWriteMany not supported by most default StorageClasses
# Use ReadWriteOnce for most scenarios
```

### 3. Forgetting to Wait for PVC Binding
```bash
# Always verify PVC is Bound before using it
kubectl get pvc <name>
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/<name> --timeout=60s
```

### 4. Volume Name Mismatch
```yaml
# Ensure volume name matches between spec.volumes and spec.containers.volumeMounts
volumes:
- name: my-data  # Name here
  persistentVolumeClaim:
    claimName: my-pvc
containers:
- volumeMounts:
  - name: my-data  # Must match name above
    mountPath: /data
```

### 5. Case Sensitivity in Access Modes
```yaml
# Correct
accessModes:
  - ReadWriteOnce

# Wrong (will fail validation)
accessModes:
  - readwriteonce
```

## Exam Tips

1. **Use kubectl create for speed**: `kubectl create` can be faster than writing YAML from scratch for simple resources
2. **Learn the dry-run pattern**: `kubectl create ... --dry-run=client -o yaml > file.yaml` for templates
3. **Practice without autocomplete**: The exam environment may have limited autocomplete
4. **Bookmark kubectl docs**: Know how to quickly find examples in https://kubernetes.io/docs/
5. **Check resources immediately**: After creating PVC, always check status before moving on
6. **Time management**: Don't spend too long troubleshooting one resource; move on and come back if time permits

## Quick Command Reference Card

```bash
# Create PVC imperatively (no direct kubectl create pvc command, use YAML)
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mypvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
EOF

# List all storage resources
kubectl get pv,pvc,sc

# Describe for troubleshooting
kubectl describe pvc <name>

# Check Pod volume mounts
kubectl describe pod <name> | grep -A 10 Volumes
kubectl exec <pod> -- mount | grep <mount-path>

# Delete PVC (be careful - may delete data!)
kubectl delete pvc <name>

# Force delete stuck PVC
kubectl patch pvc <name> -p '{"metadata":{"finalizers":null}}'
kubectl delete pvc <name> --force --grace-period=0
```

## Additional Resources

- [Official Kubernetes PV/PVC Documentation](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [Storage Class Documentation](https://kubernetes.io/docs/concepts/storage/storage-classes/)
- [Volume Types Reference](https://kubernetes.io/docs/concepts/storage/volumes/)
- [CKAD Exam Curriculum](https://github.com/cncf/curriculum)

## Next Steps

After completing these exercises:
1. Practice creating PVCs and Pods under time pressure
2. Experiment with different StorageClasses in your cluster
3. Learn about StatefulSets and volume claim templates
4. Study [StatefulSets lab](../statefulsets/) for advanced persistent storage patterns

---

> Return to [basic PersistentVolumes lab](README.md) | [Course index](../../README.md)
