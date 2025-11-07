# CKAD Practice: StatefulSets

This guide covers CKAD exam requirements for working with StatefulSets. Complete the [basic lab](README.md) first to understand the fundamentals.

## CKAD Exam Relevance

**Exam Domain**: Application Deployment (20%)
- Understand Deployments and how to perform rolling updates
- Use ConfigMaps and Secrets to configure applications
- **Understand multi-container Pod design patterns (e.g., sidecar, init containers)**
- **Understand how to use PersistentVolumeClaims for storage**

**StatefulSets** are often tested in scenarios involving:
- Applications requiring stable network identities
- Ordered deployment and scaling
- Persistent storage per Pod
- Databases, message queues, or other stateful services

## Quick Reference

### Essential kubectl Commands

```bash
# Create and manage StatefulSets
kubectl apply -f statefulset.yaml
kubectl get statefulsets                     # or 'sts'
kubectl describe statefulset <name>
kubectl scale statefulset <name> --replicas=5
kubectl delete statefulset <name>

# Watch StatefulSet Pods (notice ordered creation)
kubectl get pods -l app=<name> --watch

# Check StatefulSet rollout
kubectl rollout status statefulset/<name>
kubectl rollout history statefulset/<name>

# Access specific StatefulSet Pod
kubectl exec <statefulset-name>-0 -- <command>
kubectl logs <statefulset-name>-0

# Check PVCs created by StatefulSet
kubectl get pvc -l app=<name>

# Check headless Service endpoints
kubectl get endpoints <service-name>
```

### StatefulSet vs Deployment

| Feature | StatefulSet | Deployment |
|---------|-------------|------------|
| Pod Names | Predictable: `<name>-0`, `<name>-1` | Random: `<name>-<hash>-<id>` |
| Creation Order | Sequential (by default) | Parallel |
| Deletion Order | Reverse sequential | Parallel |
| Network Identity | Stable DNS per Pod | Load-balanced via Service |
| Storage | volumeClaimTemplates (PVC per Pod) | Shared PVC or emptyDir |
| Use Case | Stateful apps (DB, queues) | Stateless apps (web servers) |

### Pod Management Policies

```yaml
spec:
  podManagementPolicy: OrderedReady  # Default: sequential creation
  # OR
  podManagementPolicy: Parallel      # Create all Pods simultaneously
```

## CKAD Scenarios

### Scenario 1: Create Basic StatefulSet with Headless Service

**Time Target**: 5-6 minutes

Create a StatefulSet with 3 replicas and a headless Service.

```bash
# Create headless Service (REQUIRED for StatefulSet)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  clusterIP: None  # Headless Service
  selector:
    app: web
  ports:
  - port: 80
    name: web
EOF

# Create StatefulSet
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: web  # Must match Service name
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
          name: web
EOF

# Watch Pods being created sequentially
kubectl get pods -l app=web --watch
```

**Key Learning**:
- Pods are created in order: `web-0`, then `web-1`, then `web-2`
- Each Pod must be Running and Ready before the next starts
- Headless Service (clusterIP: None) is mandatory

### Scenario 2: StatefulSet with PersistentVolumeClaims

**Time Target**: 6-7 minutes

Create a StatefulSet where each Pod gets its own PVC automatically.

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: data-app
spec:
  clusterIP: None
  selector:
    app: data-app
  ports:
  - port: 80
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: data-app
spec:
  serviceName: data-app
  replicas: 3
  selector:
    matchLabels:
      app: data-app
  template:
    metadata:
      labels:
        app: data-app
    spec:
      containers:
      - name: app
        image: nginx:alpine
        volumeMounts:
        - name: data
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:  # Each Pod gets its own PVC
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 100Mi
EOF

# Watch PVCs being created (one per Pod)
kubectl get pvc --watch

# Verify each Pod has its own PVC
kubectl get pvc
# Should see: data-data-app-0, data-data-app-1, data-data-app-2
```

**Key Learning**:
- `volumeClaimTemplates` creates a PVC for each Pod
- PVC name format: `<volume-name>-<statefulset-name>-<ordinal>`
- PVCs persist even if Pod is deleted
- When Pod is recreated, it reattaches to the same PVC

### Scenario 3: Access Individual Pods via DNS

**Time Target**: 4-5 minutes

StatefulSet Pods have stable DNS names. Learn to access them directly.

```bash
# Deploy a StatefulSet (using previous example)
# Deploy a test Pod to run DNS queries from
kubectl run test --image=busybox --rm -it --restart=Never -- sh

# Inside the test Pod, test DNS resolution
nslookup web
# Returns all 3 Pod IPs

nslookup web-0.web.default.svc.cluster.local
# Returns only web-0's IP

nslookup web-1.web.default.svc.cluster.local
# Returns only web-1's IP

nslookup web-2.web.default.svc.cluster.local
# Returns only web-2's IP

exit
```

**DNS Pattern**: `<pod-name>.<service-name>.<namespace>.svc.cluster.local`

**Use Case**: Applications like databases where you need to connect to a specific instance (e.g., primary vs replica).

### Scenario 4: Parallel Pod Management

**Time Target**: 4-5 minutes

**When to Use Parallel Pod Management:**
- **Distributed caches** (Redis, Memcached) where instances are independent
- **Web application tiers** where instances don't need ordered startup
- **Stateless workers** that need stable identities but not sequential creation
- **Performance optimization** when faster startup is more important than ordering

**Real-World Example: Redis Cache Cluster**

By default, StatefulSet Pods are created sequentially. For some apps, you want parallel creation.

```bash
# Deploy Redis cache cluster with parallel startup
kubectl apply -f /home/user/kubernetes-ckad/labs/statefulsets/specs/ckad/parallel-cache.yaml

# Watch all Pods start simultaneously (not sequentially)
kubectl get pods -l app=redis-cache --watch

# Verify all Pods started in parallel
kubectl get pods -l app=redis-cache

# Test connecting to specific cache instances
kubectl run redis-test --image=redis:7-alpine --rm -it --restart=Never -- redis-cli -h redis-cache-0.redis-cache ping
kubectl run redis-test --image=redis:7-alpine --rm -it --restart=Never -- redis-cli -h redis-cache-1.redis-cache ping

# Cleanup
kubectl delete -f /home/user/kubernetes-ckad/labs/statefulsets/specs/ckad/parallel-cache.yaml
```

**Key Learning**:
- `podManagementPolicy: Parallel` creates all Pods at once
- Faster startup when Pods don't depend on each other
- Still get stable names and network identities
- Ideal for horizontally scalable stateful applications
- Each Pod still gets its own PVC (if using volumeClaimTemplates)

**Performance Comparison:**
- **OrderedReady (default)**: 5 Pods might take 50+ seconds (10s each, sequential)
- **Parallel**: All 5 Pods start within 10-15 seconds total

### Scenario 5: Scale StatefulSet

**Time Target**: 3-4 minutes

Scaling StatefulSets maintains the ordered naming convention.

```bash
# Scale up to 5 replicas
kubectl scale statefulset web --replicas=5

# Watch new Pods being added
kubectl get pods -l app=web --watch
# web-3 and web-4 are created sequentially

# Scale down to 2 replicas
kubectl scale statefulset web --replicas=2

# Watch Pods being removed in reverse order
kubectl get pods -l app=web --watch
# web-4 is deleted first, then web-3
```

**Key Learning**:
- Scale up: adds Pods with next ordinal numbers
- Scale down: removes Pods in reverse order (highest ordinal first)
- PVCs are NOT deleted when scaling down

### Scenario 6: Update StatefulSet (Rolling Update)

**Time Target**: 5-6 minutes

StatefulSets update in reverse order (from highest ordinal to lowest).

```bash
# Create initial StatefulSet
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: update-demo
spec:
  clusterIP: None
  selector:
    app: update-demo
  ports:
  - port: 80
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: update-demo
spec:
  serviceName: update-demo
  replicas: 3
  selector:
    matchLabels:
      app: update-demo
  template:
    metadata:
      labels:
        app: update-demo
    spec:
      containers:
      - name: nginx
        image: nginx:1.19-alpine
        ports:
        - containerPort: 80
  updateStrategy:
    type: RollingUpdate  # Default
EOF

# Update the image
kubectl set image statefulset/update-demo nginx=nginx:1.20-alpine

# Watch rolling update (reverse order)
kubectl get pods -l app=update-demo --watch
# update-demo-2 updates first, then -1, then -0

# Check rollout status
kubectl rollout status statefulset/update-demo

# View rollout history
kubectl rollout history statefulset/update-demo
```

**Key Learning**:
- Updates happen in reverse order (highest to lowest ordinal)
- Each Pod completes before the next starts
- Protects the first Pod (often the primary in leader-follower setups)
- Use `updateStrategy: OnDelete` to manually control updates

### Scenario 7: Troubleshoot StatefulSet Issues

**Time Target**: 4-5 minutes

Common StatefulSet problems and how to debug them.

```bash
# Problem: StatefulSet Pods stuck in Pending
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: broken-sts
spec:
  clusterIP: None
  selector:
    app: broken-sts
  ports:
  - port: 80
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: broken-sts
spec:
  serviceName: broken-sts
  replicas: 3
  selector:
    matchLabels:
      app: broken-sts
  template:
    metadata:
      labels:
        app: broken-sts
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        volumeMounts:
        - name: data
          mountPath: /data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteMany" ]  # May not be supported!
      resources:
        requests:
          storage: 10Gi  # May be too large!
EOF

# Troubleshooting steps
kubectl get statefulset broken-sts
kubectl get pods -l app=broken-sts
kubectl describe pod broken-sts-0

# Common issues:
# 1. PVC can't be provisioned
kubectl get pvc
kubectl describe pvc data-broken-sts-0

# 2. No headless Service
kubectl get svc broken-sts
# Should show clusterIP: None

# 3. Storage Class doesn't support access mode
kubectl get storageclass
kubectl describe storageclass <default-sc>

# Fix: Update access mode or storage size
kubectl delete statefulset broken-sts
# Edit and reapply with ReadWriteOnce and smaller size
```

**Troubleshooting Checklist**:
1. ✅ Headless Service exists with matching name
2. ✅ Service selector matches Pod labels
3. ✅ PVC can be provisioned (check storage capacity)
4. ✅ Access mode is supported by StorageClass
5. ✅ Previous Pod is Ready before next starts (OrderedReady)

## Advanced CKAD Topics

### OnDelete Update Strategy

**When to Use OnDelete:**
- **Database clusters** requiring manual schema migration per instance
- **Stateful services** where you need to verify each instance before proceeding
- **Blue-green deployments** at the Pod level
- **Manual coordination** with external systems or monitoring
- **Zero-downtime requirements** with custom validation steps

**Real-World Scenario: PostgreSQL Cluster with Schema Migration**

Imagine updating a PostgreSQL cluster where you need to:
1. Update the first replica
2. Run and verify schema migration
3. Check replication lag
4. Only then proceed to the next instance

Manually control when Pods are updated:

```yaml
spec:
  updateStrategy:
    type: OnDelete  # Pods only update when manually deleted
```

**Use Case**: When you need to coordinate updates manually (e.g., performing database migrations).

**Practical Example:**

```bash
# Deploy initial PostgreSQL cluster
kubectl apply -f /home/user/kubernetes-ckad/labs/statefulsets/specs/ckad/ondelete-postgres.yaml

# Wait for all Pods to be ready
kubectl wait --for=condition=Ready pod -l app=postgres --timeout=120s

# Update the StatefulSet image (e.g., PostgreSQL 15 -> 16)
kubectl set image statefulset/postgres-cluster postgres=postgres:16-alpine

# Notice: Nothing happens! Pods stay on old version
kubectl get pods -l app=postgres -o wide

# Manual update process with validation:

# Step 1: Update replica (highest ordinal first - safest)
echo "Updating postgres-cluster-2..."
kubectl delete pod postgres-cluster-2
kubectl wait --for=condition=Ready pod/postgres-cluster-2 --timeout=120s

# Step 2: Verify the updated Pod
kubectl exec postgres-cluster-2 -- psql -U appuser -d myapp -c "SELECT version();"

# Step 3: Run schema migration if needed
kubectl exec postgres-cluster-2 -- psql -U appuser -d myapp -c "
  CREATE TABLE IF NOT EXISTS migrations (
    id SERIAL PRIMARY KEY,
    version VARCHAR(50),
    applied_at TIMESTAMP DEFAULT NOW()
  );
  INSERT INTO migrations (version) VALUES ('v2.0.0');
"

# Step 4: Verify data integrity
kubectl exec postgres-cluster-2 -- psql -U appuser -d myapp -c "SELECT * FROM migrations;"

# Step 5: Once verified, update next Pod
echo "Updating postgres-cluster-1..."
kubectl delete pod postgres-cluster-1
kubectl wait --for=condition=Ready pod/postgres-cluster-1 --timeout=120s

# Step 6: Finally update the primary (postgres-cluster-0)
echo "Updating postgres-cluster-0 (primary)..."
kubectl delete pod postgres-cluster-0
kubectl wait --for=condition=Ready pod/postgres-cluster-0 --timeout=120s

# Verify all Pods updated
kubectl get pods -l app=postgres -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'

# Cleanup
kubectl delete -f /home/user/kubernetes-ckad/labs/statefulsets/specs/ckad/ondelete-postgres.yaml
kubectl delete pvc -l app=postgres
```

**Advantages of OnDelete:**
- Full control over update timing
- Validate each instance before proceeding
- Coordinate with external processes (backups, monitoring)
- Implement custom rollback logic
- Zero automation surprises during critical updates

### Partition Updates

**When to Use Partitions:**
- **Canary deployments** for stateful applications
- **Gradual rollouts** with validation at each stage
- **A/B testing** different versions in production
- **Risk mitigation** by keeping critical Pods (primary/leader) on stable version
- **Performance testing** new version with subset of traffic

**Real-World Scenario: API Service Canary Deployment**

You want to deploy a new API version but test it on 40% of instances before full rollout:
- **Pods 0, 1, 2** (60%): Stay on v1 (stable, includes primary)
- **Pods 3, 4** (40%): Update to v2 (canary)

Update only some replicas (canary pattern):

```yaml
spec:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: 3  # Only update Pods with ordinal >= 3
```

**Use Case**: Test new version on higher-ordinal Pods before updating all.

**Complete Canary Deployment Example:**

```bash
# Step 1: Deploy initial version (v1)
kubectl apply -f /home/user/kubernetes-ckad/labs/statefulsets/specs/ckad/partition-canary.yaml

# Wait for all Pods
kubectl wait --for=condition=Ready pod -l app=api --timeout=120s

# Verify initial deployment (all on v1 - nginx:1.24-alpine)
kubectl get pods -l app=api -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,VERSION:.metadata.labels.version

# Step 2: Update to v2 with partition (canary on Pods 3, 4)
kubectl patch statefulset api-service -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":3}}}}'
kubectl set image statefulset/api-service api=nginx:1.25-alpine
kubectl patch statefulset api-service -p '{"spec":{"template":{"metadata":{"labels":{"version":"v2"}}}}}'

# Watch only Pods 3 and 4 update
kubectl get pods -l app=api --watch

# Step 3: Verify canary deployment
kubectl get pods -l app=api -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image

# Should show:
# api-service-0: nginx:1.24-alpine (v1)
# api-service-1: nginx:1.24-alpine (v1)
# api-service-2: nginx:1.24-alpine (v1)
# api-service-3: nginx:1.25-alpine (v2) <- Canary
# api-service-4: nginx:1.25-alpine (v2) <- Canary

# Step 4: Test canary Pods
kubectl exec api-service-3 -- nginx -v  # Should show 1.25
kubectl exec api-service-4 -- nginx -v  # Should show 1.25
kubectl exec api-service-0 -- nginx -v  # Should show 1.24 (unchanged)

# Step 5: Monitor canary performance (simulate)
echo "Monitor metrics, error rates, latency for Pods 3, 4..."
echo "If canary looks good, proceed with full rollout"
echo "If issues found, rollback canary by deleting and setting partition back"

# Step 6: Expand canary to 60% (Pods 2, 3, 4)
kubectl patch statefulset api-service -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":2}}}}'
kubectl get pods -l app=api --watch

# Step 7: Full rollout (update all remaining Pods)
kubectl patch statefulset api-service -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":0}}}}'
kubectl get pods -l app=api --watch

# All Pods now on v2
kubectl get pods -l app=api -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image

# Cleanup
kubectl delete -f /home/user/kubernetes-ckad/labs/statefulsets/specs/ckad/partition-canary.yaml
kubectl delete pvc -l app=api
```

**Advanced Partition Strategy:**

```bash
# Rollout stages for 5-replica StatefulSet:
# Stage 1: Canary (20%) - partition: 4 (only Pod 4 updates)
# Stage 2: Small group (40%) - partition: 3 (Pods 3, 4 updated)
# Stage 3: Majority (60%) - partition: 2 (Pods 2, 3, 4 updated)
# Stage 4: Almost all (80%) - partition: 1 (Pods 1, 2, 3, 4 updated)
# Stage 5: Complete (100%) - partition: 0 (all Pods updated)
```

**Rollback Strategy:**

```bash
# If canary shows problems, rollback canary Pods:
# Delete canary Pods
kubectl delete pod api-service-3 api-service-4

# Reset to previous image
kubectl set image statefulset/api-service api=nginx:1.24-alpine

# Canary Pods will recreate with old version
# Pods 0, 1, 2 were never affected
```

**Key Benefits:**
- **Protect critical Pods**: Primary/leader (Pod 0) updates last
- **Gradual validation**: Verify each stage before proceeding
- **Easy rollback**: Only affected Pods need to rollback
- **Production testing**: Test in real environment with real traffic
- **Flexible stages**: Adjust partition to control rollout speed

### StatefulSet with Init Containers

Common pattern for stateful apps requiring initialization:

**When to Use Init Containers with StatefulSets:**
- **Database schema initialization** before app starts
- **Permission fixes** on volumes (especially with UID/GID mismatches)
- **Wait for dependencies** (primary instance, external services)
- **Configuration generation** based on Pod ordinal or hostname
- **Data migration** or seeding for new instances
- **Network prerequisites** (DNS resolution, connectivity checks)

**Complete Examples:**

**Example 1: MySQL with Schema Initialization**

Deploy a MySQL StatefulSet that automatically initializes database schema:

```bash
# Deploy MySQL cluster with automatic schema initialization
kubectl apply -f /home/user/kubernetes-ckad/labs/statefulsets/specs/ckad/init-containers.yaml

# Watch Pods being created with init containers
kubectl get pods -l app=mysql-init --watch

# Check init container logs (see schema being initialized)
kubectl logs mysql-init-0 -c fix-permissions
kubectl logs mysql-init-0 -c wait-for-primary
kubectl logs mysql-init-0 -c prepare-init-scripts

# Verify main container started successfully
kubectl logs mysql-init-0 -c mysql

# Test database schema was initialized
kubectl exec mysql-init-0 -c mysql -- mysql -uroot -prootpassword -e "SHOW DATABASES;"
kubectl exec mysql-init-0 -c mysql -- mysql -uroot -prootpassword appdb -e "SHOW TABLES;"
kubectl exec mysql-init-0 -c mysql -- mysql -uroot -prootpassword appdb -e "SELECT * FROM users;"

# Test replica Pods (they waited for primary)
kubectl exec mysql-init-1 -c mysql -- mysql -uroot -prootpassword appdb -e "SELECT * FROM users;"

# Cleanup
kubectl delete -f /home/user/kubernetes-ckad/labs/statefulsets/specs/ckad/init-containers.yaml
kubectl delete pvc -l app=mysql-init
```

**Example 2: Dynamic Configuration Generation**

Deploy an application where each Pod gets instance-specific configuration:

```bash
# Already deployed as part of init-containers.yaml
# Watch the second StatefulSet
kubectl get pods -l app=app-with-config --watch

# Check generated configuration for each Pod
kubectl exec app-with-config-0 -- cat /etc/app/app.conf
# Should show: instance.role=primary

kubectl exec app-with-config-1 -- cat /etc/app/app.conf
# Should show: instance.role=replica, replication.master=app-with-config-0...

kubectl exec app-with-config-2 -- cat /etc/app/app.conf
# Should show: instance.role=replica

# View configuration via HTTP (served by nginx)
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- \
  curl -s http://app-with-config-0.app-with-config.default.svc.cluster.local:8080/config.txt

# Each Pod has different config based on its ordinal
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- \
  curl -s http://app-with-config-1.app-with-config.default.svc.cluster.local:8080/config.txt
```

**Common Init Container Patterns:**

**Pattern 1: Leader-Follower Logic**
```yaml
initContainers:
- name: wait-for-primary
  image: busybox
  command:
  - sh
  - -c
  - |
    if [ "$(hostname)" != "db-cluster-0" ]; then
      until nslookup db-cluster-0.db-cluster; do
        echo "Waiting for primary..."
        sleep 2
      done
    fi
```

**Pattern 2: Permissions Fix**
```yaml
initContainers:
- name: fix-permissions
  image: busybox
  command: ['sh', '-c', 'chown -R 999:999 /var/lib/mysql']
  volumeMounts:
  - name: data
    mountPath: /var/lib/mysql
```

**Pattern 3: Configuration Based on Ordinal**
```yaml
initContainers:
- name: generate-config
  image: busybox
  command:
  - sh
  - -c
  - |
    ORDINAL=$(echo $HOSTNAME | grep -o '[0-9]*$')
    if [ "$ORDINAL" = "0" ]; then
      echo "role=master" > /config/role.conf
    else
      echo "role=replica" > /config/role.conf
    fi
  volumeMounts:
  - name: config
    mountPath: /config
```

**Pattern 4: Data Seeding/Migration**
```yaml
initContainers:
- name: seed-data
  image: myapp-migration:v1
  command: ['python', '/scripts/migrate.py', '--init']
  env:
  - name: DB_HOST
    value: "localhost"
  volumeMounts:
  - name: data
    mountPath: /data
```

**Key Learning**:
- Init containers run in order (sequentially) before main container
- They can check Pod hostname/ordinal to implement role-based logic
- Perfect for stateful apps needing instance-specific initialization
- Failed init containers prevent main container from starting
- Each Pod in StatefulSet can have different init behavior based on ordinal

## CKAD Practice Exercises

### Exercise 1: Create StatefulSet from Scratch

**Objective**: Quickly create a functional StatefulSet under time pressure

**Requirements**:
1. Create a headless Service named `mysql`
2. Create a StatefulSet named `mysql` with 3 replicas
3. Use image `mysql:8.0`
4. Set environment variable `MYSQL_ROOT_PASSWORD=password`
5. Each Pod should have a 1Gi PVC mounted at `/var/lib/mysql`
6. Verify all Pods are Running and each has its own PVC

**Time Limit**: 7 minutes

<details>
<summary>Solution</summary>

```bash
# Create headless Service and StatefulSet
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: mysql
spec:
  clusterIP: None
  selector:
    app: mysql
  ports:
  - port: 3306
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: mysql
  replicas: 3
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: password
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 1Gi
EOF

# Verify
kubectl get statefulset mysql
kubectl get pods -l app=mysql
kubectl get pvc -l app=mysql
```

</details>

### Exercise 2: Access Specific Pod via DNS

**Objective**: Practice StatefulSet networking

Using the StatefulSet from Exercise 1:

1. Deploy a test Pod with mysql client
2. Connect to `mysql-0` specifically using its DNS name
3. Verify connection by running `SELECT @@hostname;`

**Time Limit**: 4 minutes

<details>
<summary>Solution</summary>

```bash
# Deploy mysql client Pod
kubectl run mysql-client --image=mysql:8.0 --rm -it --restart=Never -- \
  mysql -h mysql-0.mysql.default.svc.cluster.local -uroot -ppassword -e "SELECT @@hostname;"

# Expected output: mysql-0

# Test connection to mysql-1
kubectl run mysql-client --image=mysql:8.0 --rm -it --restart=Never -- \
  mysql -h mysql-1.mysql.default.svc.cluster.local -uroot -ppassword -e "SELECT @@hostname;"

# Expected output: mysql-1
```

</details>

### Exercise 3: Scale and Verify PVC Retention

**Objective**: Understand PVC lifecycle with StatefulSets

1. Create a StatefulSet with 3 replicas and PVCs
2. Write data to a file in one Pod
3. Scale down to 1 replica
4. Scale back up to 3 replicas
5. Verify the data still exists in the original Pod

**Time Limit**: 8 minutes

<details>
<summary>Solution</summary>

```bash
# Create StatefulSet
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: data-test
spec:
  clusterIP: None
  selector:
    app: data-test
  ports:
  - port: 80
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: data-test
spec:
  serviceName: data-test
  replicas: 3
  selector:
    matchLabels:
      app: data-test
  template:
    metadata:
      labels:
        app: data-test
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        volumeMounts:
        - name: data
          mountPath: /data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 100Mi
EOF

# Wait for all Pods
kubectl wait --for=condition=Ready pod -l app=data-test --timeout=60s

# Write data to data-test-2
kubectl exec data-test-2 -- sh -c 'echo "Important data" > /data/important.txt'
kubectl exec data-test-2 -- cat /data/important.txt

# Scale down to 1
kubectl scale statefulset data-test --replicas=1

# Verify data-test-2 Pod is gone
kubectl get pods -l app=data-test

# Check PVCs still exist
kubectl get pvc -l app=data-test
# All 3 PVCs should still be there!

# Scale back up to 3
kubectl scale statefulset data-test --replicas=3

# Wait for data-test-2 to be Ready
kubectl wait --for=condition=Ready pod/data-test-2 --timeout=60s

# Verify data persisted
kubectl exec data-test-2 -- cat /data/important.txt
# Should still show "Important data"
```

**Key Takeaway**: PVCs are not deleted when StatefulSet scales down. Data persists.

</details>

### Exercise 4: Convert Deployment to StatefulSet

**Objective**: Understand when and how to migrate to StatefulSets

You have a Deployment that needs persistent storage per Pod:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
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
        image: nginx:alpine
        volumeMounts:
        - name: cache
          mountPath: /cache
      volumes:
      - name: cache
        emptyDir: {}
```

Convert this to a StatefulSet where each Pod has a 200Mi PVC for the cache.

**Time Limit**: 6 minutes

<details>
<summary>Solution</summary>

```bash
# Delete the Deployment first
kubectl delete deployment app

# Create headless Service and StatefulSet
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: app
spec:
  clusterIP: None
  selector:
    app: myapp
  ports:
  - port: 80
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: app
spec:
  serviceName: app
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
        image: nginx:alpine
        volumeMounts:
        - name: cache
          mountPath: /cache
  volumeClaimTemplates:
  - metadata:
      name: cache
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 200Mi
EOF

# Verify
kubectl get statefulset app
kubectl get pods -l app=myapp
kubectl get pvc
```

**Key Changes**:
1. Added headless Service
2. Changed `kind: Deployment` to `kind: StatefulSet`
3. Added `serviceName` field
4. Replaced `volumes: emptyDir` with `volumeClaimTemplates`

</details>

### Exercise 5: Parallel Pod Creation

**Objective**: Use podManagementPolicy for faster startup

Create a StatefulSet with 5 replicas that all start simultaneously (not sequentially).

**Requirements**:
- Name: `web-parallel`
- Image: `nginx:alpine`
- 5 replicas
- Pods should start in parallel

**Time Limit**: 5 minutes

<details>
<summary>Solution</summary>

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: web-parallel
spec:
  clusterIP: None
  selector:
    app: web-parallel
  ports:
  - port: 80
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web-parallel
spec:
  serviceName: web-parallel
  replicas: 5
  podManagementPolicy: Parallel  # Key field!
  selector:
    matchLabels:
      app: web-parallel
  template:
    metadata:
      labels:
        app: web-parallel
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
EOF

# Watch all 5 Pods start at once
kubectl get pods -l app=web-parallel --watch
```

</details>

## Common Exam Pitfalls

### 1. Forgetting the Headless Service
```bash
# StatefulSet will not work without a headless Service
# Always create the Service first!
```

### 2. Wrong Service Name
```yaml
# Service name and serviceName must match
apiVersion: v1
kind: Service
metadata:
  name: my-app  # This name
spec:
  clusterIP: None
---
apiVersion: apps/v1
kind: StatefulSet
spec:
  serviceName: my-app  # Must match this
```

### 3. Forgetting clusterIP: None
```yaml
# This is NOT a headless Service (missing clusterIP: None)
spec:
  selector:
    app: web
  ports:
  - port: 80

# Correct headless Service:
spec:
  clusterIP: None  # Required!
  selector:
    app: web
  ports:
  - port: 80
```

### 4. Deleting StatefulSet Without Cascading
```bash
# This deletes StatefulSet but NOT Pods (confusing!)
kubectl delete statefulset web --cascade=orphan

# Always use default cascading delete
kubectl delete statefulset web
```

### 5. Expecting PVCs to Auto-Delete
```bash
# When you delete a StatefulSet, PVCs are NOT deleted
# Must delete PVCs manually
kubectl delete statefulset web
kubectl delete pvc -l app=web
```

### 6. Using Wrong DNS Format
```bash
# Wrong (missing service name and namespace)
<pod-name>.cluster.local

# Correct format
<pod-name>.<service-name>.<namespace>.svc.cluster.local

# Example
web-0.web.default.svc.cluster.local
```

### 7. Label Mismatch
```yaml
# Service and StatefulSet selectors must match Pod labels
# Service
spec:
  selector:
    app: web  # Must match

# StatefulSet
spec:
  selector:
    matchLabels:
      app: web  # Must match
  template:
    metadata:
      labels:
        app: web  # Must match
```

## Exam Tips

1. **Memorize the headless Service pattern**: You'll likely need to create one from scratch
2. **Practice DNS name format**: `<pod>.<service>.<namespace>.svc.cluster.local`
3. **Remember volumeClaimTemplates syntax**: It's easy to get wrong under pressure
4. **Know the difference**: OrderedReady vs Parallel pod management
5. **Scale awareness**: Scaling down doesn't delete PVCs
6. **Update order**: StatefulSets update in reverse (highest ordinal first)
7. **Time management**: StatefulSet creation is slower due to sequential startup
8. **Use kubectl scale**: Faster than editing YAML for scale operations

## Quick Command Reference Card

```bash
# Create StatefulSet (no imperative command, use YAML)
kubectl apply -f statefulset.yaml

# List StatefulSets
kubectl get sts

# Describe for troubleshooting
kubectl describe sts <name>

# Scale StatefulSet
kubectl scale sts <name> --replicas=5

# Update image
kubectl set image sts/<name> <container>=<image>

# Check rollout
kubectl rollout status sts/<name>
kubectl rollout history sts/<name>

# Access specific Pod
kubectl exec <sts-name>-0 -- <command>

# Check PVCs for StatefulSet
kubectl get pvc -l app=<label>

# Delete StatefulSet (cascading)
kubectl delete sts <name>

# Delete StatefulSet and PVCs
kubectl delete sts <name>
kubectl delete pvc -l app=<label>

# Force delete stuck StatefulSet
kubectl delete sts <name> --force --grace-period=0
```

## Additional Resources

- [Official StatefulSet Documentation](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [StatefulSet Basics Tutorial](https://kubernetes.io/docs/tutorials/stateful-application/basic-stateful-set/)
- [Run Replicated Stateful Application](https://kubernetes.io/docs/tasks/run-application/run-replicated-stateful-application/)
- [CKAD Exam Curriculum](https://github.com/cncf/curriculum)

## Next Steps

After completing these exercises:
1. Practice creating StatefulSets under time pressure (< 5 minutes)
2. Study the [PersistentVolumes CKAD guide](../persistentvolumes/CKAD.md)
3. Learn about [Helm](../helm/) for managing complex StatefulSet deployments
4. Review [DaemonSets](../daemonsets/) for another Pod controller pattern

---

> Return to [basic StatefulSets lab](README.md) | [Course index](../../README.md)
