# Operators - CKAD Requirements

This document covers the CKAD (Certified Kubernetes Application Developer) exam requirements for Operators and Custom Resources, building on the basics covered in [README.md](README.md).

## CKAD Exam Requirements

The CKAD exam expects you to understand and implement:
- Understanding Custom Resource Definitions (CRDs)
- Creating and managing custom resources
- Working with operator-managed applications
- Understanding the operator pattern
- Querying and describing custom resources
- Troubleshooting operator deployments
- Understanding controller patterns
- Working with Helm operators

## Custom Resource Definitions (CRDs)

CRDs extend Kubernetes by adding new resource types to the API.

### Basic CRD Structure

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: backends.stable.example.com
spec:
  group: stable.example.com
  names:
    plural: backends
    singular: backend
    kind: Backend
    shortNames:
    - be
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
            properties:
              replicas:
                type: integer
                minimum: 1
                maximum: 10
              image:
                type: string
              port:
                type: integer
```

### CRD Components

**metadata.name**: Must be `<plural>.<group>`

**spec.group**: API group for the custom resource (e.g., `stable.example.com`)

**spec.names**: Defines how the resource is referenced
- `plural`: Plural name for CLI (`kubectl get backends`)
- `singular`: Singular name (`kubectl get backend mybackend`)
- `kind`: The kind field in YAML manifests
- `shortNames`: Abbreviations (`kubectl get be`)

**spec.scope**: Either `Namespaced` or `Cluster`

**spec.versions**: List of API versions
- `served`: Whether this version is enabled
- `storage`: Which version is used for storage (only one can be true)
- `schema`: OpenAPI v3 schema for validation

### Creating a Simple CRD

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: applications.apps.example.com
spec:
  group: apps.example.com
  names:
    plural: applications
    singular: application
    kind: Application
    shortNames:
    - app
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
            properties:
              name:
                type: string
              version:
                type: string
              replicas:
                type: integer
                minimum: 1
              image:
                type: string
            required:
            - name
            - image
```

Deploy the CRD:

```bash
kubectl apply -f crd.yaml
kubectl get crds
kubectl describe crd applications.apps.example.com
```

### Creating Custom Resources

Once the CRD is installed, you can create custom resources:

```yaml
apiVersion: apps.example.com/v1
kind: Application
metadata:
  name: myapp
  namespace: default
spec:
  name: myapp
  version: "1.0"
  replicas: 3
  image: nginx:alpine
```

```bash
kubectl apply -f myapp.yaml
kubectl get applications
kubectl get app  # Using short name
kubectl describe application myapp
```

📋 Create a CRD for a "Database" resource with fields for engine, version, and storage size.

<details>
  <summary>Not sure how?</summary>

Create the CRD with validation rules:

```bash
# Deploy the Database CRD
kubectl apply -f labs/operators/specs/ckad/database-crd.yaml

# Verify CRD is installed
kubectl get crds databases.db.example.com
kubectl describe crd databases.db.example.com

# Check available fields
kubectl explain database.spec
```

<details>
  <summary>Database CRD YAML</summary>

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: databases.db.example.com
spec:
  group: db.example.com
  names:
    plural: databases
    singular: database
    kind: Database
    shortNames:
    - db
  scope: Namespaced
  versions:
  - name: v1
    served: true
    storage: true
    additionalPrinterColumns:
    - name: Engine
      type: string
      jsonPath: .spec.engine
    - name: Version
      type: string
      jsonPath: .spec.version
    - name: Storage
      type: string
      jsonPath: .spec.storageSize
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              engine:
                type: string
                enum:
                - postgres
                - mysql
                - mongodb
                - redis
              version:
                type: string
                pattern: '^[0-9]+\.[0-9]+(\.[0-9]+)?$'
              storageSize:
                type: string
                pattern: '^[0-9]+[GM]i$'
              replicas:
                type: integer
                minimum: 1
                maximum: 5
            required:
            - engine
            - version
            - storageSize
```

</details>

Now create custom resources:

```bash
# Create a PostgreSQL database
kubectl apply -f labs/operators/specs/ckad/database-postgres.yaml

# Create a MySQL database
kubectl apply -f labs/operators/specs/ckad/database-mysql.yaml

# Create a Redis cache
kubectl apply -f labs/operators/specs/ckad/database-redis.yaml

# List all databases
kubectl get databases
# NAME                  ENGINE     VERSION   STORAGE   AGE
# production-postgres   postgres   14.5      50Gi      10s
# dev-mysql             mysql      8.0       10Gi      9s
# cache-redis           redis      7.0       5Gi       8s

# Use short name
kubectl get db

# Get specific database
kubectl describe database production-postgres

# Query with custom columns
kubectl get databases -o custom-columns=NAME:.metadata.name,ENGINE:.spec.engine,REPLICAS:.spec.replicas
```

</details><br/>

### CRD Validation

Add validation rules using OpenAPI schema:

```yaml
schema:
  openAPIV3Schema:
    type: object
    properties:
      spec:
        type: object
        properties:
          size:
            type: string
            enum:
            - small
            - medium
            - large
          replicas:
            type: integer
            minimum: 1
            maximum: 5
          email:
            type: string
            pattern: '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
          tags:
            type: array
            items:
              type: string
        required:
        - size
        - replicas
```

**Validation Examples**

Test validation with invalid resources:

```bash
# Try to create database with invalid engine (will fail)
kubectl apply -f labs/operators/specs/ckad/validation-invalid-engine.yaml
# Error: validation failure in databases.db.example.com:
# spec.engine: Unsupported value: "oracle": supported values: "postgres", "mysql", "mongodb", "redis"

# Try invalid version format (will fail)
kubectl apply -f labs/operators/specs/ckad/validation-invalid-version.yaml
# Error: validation failure: spec.version in body should match '^[0-9]+\.[0-9]+(\.[0-9]+)?$'

# Try invalid storage size format (will fail)
kubectl apply -f labs/operators/specs/ckad/validation-invalid-storage.yaml
# Error: validation failure: spec.storageSize in body should match '^[0-9]+[GM]i$'

# Try replicas exceeding maximum (will fail)
kubectl apply -f labs/operators/specs/ckad/validation-invalid-replicas.yaml
# Error: validation failure: spec.replicas in body should be less than or equal to 5

# Try missing required fields (will fail)
kubectl apply -f labs/operators/specs/ckad/validation-missing-required.yaml
# Error: validation failure: spec.version in body is required
# Error: validation failure: spec.storageSize in body is required
```

**Understanding Validation Errors:**

- **Enum validation**: Rejects values not in the allowed list
- **Pattern validation**: Checks string format with regex
- **Min/Max validation**: Enforces numeric boundaries
- **Required fields**: Ensures critical fields are present
- **Type validation**: Enforces correct data types

These validation rules prevent invalid configurations before they're stored in etcd.

### Additional Printer Columns

Customize the output of `kubectl get`:

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: applications.apps.example.com
spec:
  group: apps.example.com
  names:
    plural: applications
    singular: application
    kind: Application
  scope: Namespaced
  versions:
  - name: v1
    served: true
    storage: true
    additionalPrinterColumns:
    - name: Version
      type: string
      jsonPath: .spec.version
    - name: Replicas
      type: integer
      jsonPath: .spec.replicas
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              version:
                type: string
              replicas:
                type: integer
```

Result:
```bash
kubectl get applications
# NAME    VERSION   REPLICAS   AGE
# myapp   1.0       3          5m
```

### Subresources

Enable status and scale subresources:

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: applications.apps.example.com
spec:
  group: apps.example.com
  names:
    plural: applications
    singular: application
    kind: Application
  scope: Namespaced
  versions:
  - name: v1
    served: true
    storage: true
    subresources:
      status: {}  # Enable status subresource
      scale:      # Enable scale subresource
        specReplicasPath: .spec.replicas
        statusReplicasPath: .status.replicas
        labelSelectorPath: .status.labelSelector
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              replicas:
                type: integer
          status:
            type: object
            properties:
              replicas:
                type: integer
              labelSelector:
                type: string
```

With status subresource:
```bash
# Update status separately from spec
kubectl patch application myapp --subresource=status --type=merge -p '{"status":{"replicas":3}}'
```

With scale subresource:
```bash
# Use kubectl scale command
kubectl scale application myapp --replicas=5
```

**Complete Subresources Example**

Deploy a CRD with both status and scale subresources:

```bash
# Create CRD with subresources enabled
kubectl apply -f labs/operators/specs/ckad/app-crd-with-subresources.yaml

# Create a WebApp resource
kubectl apply -f labs/operators/specs/ckad/webapp-example.yaml

# View the resource
kubectl get webapps
# NAME        DESIRED   CURRENT   READY   AGE
# mywebapp    3         0                 5s
```

**Working with Status Subresource:**

```bash
# Update status (typically done by operator/controller)
kubectl patch webapp mywebapp --subresource=status --type=merge -p '
{
  "status": {
    "replicas": 3,
    "availableReplicas": 3,
    "labelSelector": "app=mywebapp",
    "conditions": [
      {
        "type": "Ready",
        "status": "True",
        "lastTransitionTime": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
        "reason": "AllPodsReady",
        "message": "All replicas are ready"
      }
    ]
  }
}'

# View updated status
kubectl get webapp mywebapp -o yaml | grep -A 20 "^status:"

# Check specific status condition
kubectl get webapp mywebapp -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
# True
```

**Working with Scale Subresource:**

```bash
# Scale using kubectl scale command
kubectl scale webapp mywebapp --replicas=5

# Verify the change
kubectl get webapp mywebapp -o jsonpath='{.spec.replicas}'
# 5

# Get current scale
kubectl get webapp mywebapp --subresource=scale
# NAME        DESIRED   CURRENT   AGE
# mywebapp    5         3         2m

# Patch scale directly
kubectl patch webapp mywebapp --subresource=scale --type=merge -p '{"spec":{"replicas":2}}'

# View with additional printer columns
kubectl get webapps
# NAME        DESIRED   CURRENT   READY   AGE
# mywebapp    2         5         True    3m
```

**Benefits of Subresources:**

- **Status**: Separates desired state (spec) from observed state (status)
- **Scale**: Enables standard scaling commands and HPA integration
- **RBAC**: Allows different permissions for spec vs status updates
- **Consistency**: Follows Kubernetes conventions for stateful resources

## Understanding the Operator Pattern

Operators = Custom Resources + Controllers

### Controller Pattern

A controller watches Kubernetes resources and takes action to reconcile desired state with actual state.

**Controller Loop:**
1. Watch for resource changes (Create, Update, Delete)
2. Compare desired state (spec) with actual state (status)
3. Take action to reconcile differences
4. Update resource status
5. Repeat

### Operator Components

**Custom Resource Definition (CRD)**
- Defines the schema for custom resources
- Installed in the cluster
- Extends the Kubernetes API

**Custom Resource (CR)**
- Instance of a CRD
- Defines desired state
- Created by users

**Controller**
- Watches custom resources
- Reconciles desired state
- Usually runs as a Deployment
- Requires RBAC permissions

```
┌─────────────────────────────────────────────┐
│           Operator Pattern                   │
│                                              │
│  ┌──────────┐      ┌──────────────────┐    │
│  │   CRD    │─────▶│  Custom Resource │    │
│  │(Schema)  │      │  (User creates)  │    │
│  └──────────┘      └──────────┬───────┘    │
│                               │              │
│                               │ watches      │
│                               ▼              │
│                      ┌─────────────────┐    │
│                      │   Controller    │    │
│                      │   (Reconciles)  │    │
│                      └────────┬────────┘    │
│                               │              │
│                               │ creates      │
│                               ▼              │
│                   ┌──────────────────────┐  │
│                   │  Kubernetes Objects  │  │
│                   │ (Deployments, etc.)  │  │
│                   └──────────────────────┘  │
└─────────────────────────────────────────────┘
```

**Detailed Operator Workflow:**

```
┌──────────────────── Operator Lifecycle ────────────────────┐
│                                                              │
│  1. Installation Phase                                      │
│  ┌────────────┐    ┌──────────────┐    ┌────────────┐     │
│  │   Install  │───▶│  Create CRDs │───▶│   Deploy   │     │
│  │  Operator  │    │   in Cluster │    │ Controller │     │
│  └────────────┘    └──────────────┘    └─────┬──────┘     │
│                                               │             │
│  2. Runtime Phase                            │             │
│                         ┌────────────────────┘             │
│                         ▼                                   │
│  ┌────────────┐    ┌────────────┐    ┌──────────────┐    │
│  │   User     │───▶│  Create CR │───▶│  Controller  │    │
│  │  kubectl   │    │  (Database)│    │   Watches    │    │
│  └────────────┘    └────────────┘    └──────┬───────┘    │
│                                              │             │
│  3. Reconciliation Loop                     │             │
│                         ┌────────────────────┘             │
│                         ▼                                   │
│  ┌─────────────┐   ┌──────────┐   ┌────────────────┐     │
│  │  Read CR    │──▶│ Compare  │──▶│ Take Action    │     │
│  │  Spec       │   │ Desired  │   │ Create/Update  │     │
│  │             │   │ vs Actual│   │ Resources      │     │
│  └─────────────┘   └──────────┘   └───────┬────────┘     │
│                                            │               │
│  4. Status Update                         │               │
│                         ┌──────────────────┘               │
│                         ▼                                   │
│  ┌─────────────┐   ┌──────────┐   ┌────────────────┐     │
│  │ Update CR   │◀──│  Check   │◀──│  Created:      │     │
│  │ Status      │   │  Health  │   │  - Deployment  │     │
│  │ (Phase,     │   │  Status  │   │  - Service     │     │
│  │  Replicas)  │   │          │   │  - PVC         │     │
│  └─────────────┘   └──────────┘   └────────────────┘     │
│         │                                                   │
│         └────── Loop back to step 3 (Continuous) ─────────┤
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

**Example: Database Operator Workflow**

```
User Creates:
  kind: Database
  spec:
    engine: postgres
    replicas: 3
         │
         ▼
Controller Watches and Creates:
  ├─▶ StatefulSet (3 postgres pods)
  ├─▶ Service (headless + loadbalancer)
  ├─▶ ConfigMap (postgres.conf)
  ├─▶ Secret (passwords)
  ├─▶ PVC (3x storage volumes)
  └─▶ CronJob (backups)
         │
         ▼
Controller Updates Status:
  status:
    phase: Running
    readyReplicas: 3
    conditions:
    - type: Ready
      status: True
```

## Working with Operators

### Installing an Operator

Most operators are installed via manifests or Helm charts.

**Via Manifests:**
```bash
# Install CRDs
kubectl apply -f https://example.com/operator/crds.yaml

# Install operator
kubectl apply -f https://example.com/operator/operator.yaml

# Verify installation
kubectl get crds
kubectl get pods -n operator-namespace
kubectl logs -n operator-namespace -l app=operator
```

**Via Helm:**
```bash
# Add Helm repository
helm repo add operator https://example.com/charts
helm repo update

# Install operator
helm install my-operator operator/operator-chart

# Verify installation
helm list
kubectl get crds
kubectl get pods
```

### Operator Permissions (RBAC)

Operators need permissions to watch and manage resources:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: myoperator
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: myoperator
rules:
# Watch custom resources
- apiGroups: ["apps.example.com"]
  resources: ["applications"]
  verbs: ["get", "list", "watch", "update", "patch"]
- apiGroups: ["apps.example.com"]
  resources: ["applications/status"]
  verbs: ["update", "patch"]
# Manage Kubernetes resources
- apiGroups: ["apps"]
  resources: ["deployments", "statefulsets"]
  verbs: ["get", "list", "create", "update", "delete"]
- apiGroups: [""]
  resources: ["services", "configmaps", "secrets"]
  verbs: ["get", "list", "create", "update", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: myoperator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: myoperator
subjects:
- kind: ServiceAccount
  name: myoperator
  namespace: default
```

### Operator Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myoperator
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myoperator
  template:
    metadata:
      labels:
        app: myoperator
    spec:
      serviceAccountName: myoperator
      containers:
      - name: operator
        image: example.com/myoperator:v1.0
        env:
        - name: WATCH_NAMESPACE
          value: ""  # Watch all namespaces
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
```

📋 Check what permissions an operator's service account has.

<details>
  <summary>Not sure how?</summary>

Deploy a complete operator with RBAC:

```bash
# Deploy operator RBAC resources
kubectl apply -f labs/operators/specs/ckad/simple-operator-rbac.yaml

# Verify ServiceAccount created
kubectl get serviceaccount webapp-operator

# Verify ClusterRole created
kubectl get clusterrole webapp-operator
kubectl describe clusterrole webapp-operator

# Verify ClusterRoleBinding created
kubectl get clusterrolebinding webapp-operator
kubectl describe clusterrolebinding webapp-operator
```

**Check Operator Permissions:**

```bash
# List all ClusterRoleBindings for the operator's ServiceAccount
kubectl get clusterrolebinding -o json | \
  jq -r '.items[] | select(.subjects[]?.name=="webapp-operator") | .metadata.name'
# webapp-operator

# Check permissions for custom resources
kubectl auth can-i get webapps --as system:serviceaccount:default:webapp-operator
# yes
kubectl auth can-i create webapps --as system:serviceaccount:default:webapp-operator
# yes
kubectl auth can-i update webapps/status --as system:serviceaccount:default:webapp-operator
# yes

# Check permissions for managed resources
kubectl auth can-i create deployments --as system:serviceaccount:default:webapp-operator
# yes
kubectl auth can-i delete services --as system:serviceaccount:default:webapp-operator
# yes
kubectl auth can-i create secrets --as system:serviceaccount:default:webapp-operator
# yes

# Check what operator CANNOT do
kubectl auth can-i create customresourcedefinitions --as system:serviceaccount:default:webapp-operator
# no
kubectl auth can-i delete nodes --as system:serviceaccount:default:webapp-operator
# no
```

**View Complete RBAC Configuration:**

```bash
# Get the full ClusterRole definition
kubectl get clusterrole webapp-operator -o yaml

# Check which resources the operator can manage
kubectl get clusterrole webapp-operator -o jsonpath='{.rules[*].resources}' | tr ' ' '\n' | sort -u
# configmaps
# deployments
# events
# pods
# secrets
# services
# webapps
# webapps/scale
# webapps/status

# Check which verbs the operator has for webapps
kubectl get clusterrole webapp-operator -o json | \
  jq -r '.rules[] | select(.resources[] | contains("webapps")) | .verbs[]' | sort -u
# create
# delete
# get
# list
# patch
# update
# watch

# List all permissions in readable format
kubectl get clusterrole webapp-operator -o json | \
  jq -r '.rules[] | "\(.apiGroups[]) - \(.resources[]) - \(.verbs[])"'
```

**Test RBAC with Different Operations:**

```bash
# Test as the operator (should succeed)
kubectl auth can-i list pods --as system:serviceaccount:default:webapp-operator
kubectl auth can-i create deployments --as system:serviceaccount:default:webapp-operator
kubectl auth can-i update webapps/status --as system:serviceaccount:default:webapp-operator

# Test operations that should fail
kubectl auth can-i create namespaces --as system:serviceaccount:default:webapp-operator
# no - operator doesn't have namespace permissions
kubectl auth can-i delete crds --as system:serviceaccount:default:webapp-operator
# no - operator doesn't manage CRDs
```

**Debug RBAC Issues:**

If an operator has permission errors in logs:

```bash
# Check operator pod logs for RBAC errors
kubectl logs -l app=webapp-operator | grep -i "forbidden\|unauthorized"

# Common error: "is forbidden: User "system:serviceaccount:default:webapp-operator" cannot create resource"

# Troubleshoot:
# 1. Verify ServiceAccount exists
kubectl get sa webapp-operator

# 2. Check if ServiceAccount is bound to a role
kubectl get clusterrolebinding -o json | \
  jq -r '.items[] | select(.subjects[]?.name=="webapp-operator") | {name:.metadata.name, role:.roleRef.name}'

# 3. Verify the role has required permissions
kubectl get clusterrole webapp-operator -o yaml

# 4. Add missing permissions if needed
kubectl edit clusterrole webapp-operator
```

</details><br/>

## Common Operator Use Cases

### Database Operators

Manage database lifecycle:

```yaml
apiVersion: databases.example.com/v1
kind: PostgresCluster
metadata:
  name: production-db
spec:
  version: "14"
  replicas: 3
  storage:
    size: 100Gi
    storageClass: fast-ssd
  backup:
    enabled: true
    schedule: "0 2 * * *"
    retention: 7
  monitoring:
    enabled: true
```

**Operator manages:**
- StatefulSet for database pods
- Services for connectivity
- ConfigMaps for configuration
- Secrets for credentials
- PersistentVolumeClaims for storage
- Backup CronJobs
- Monitoring sidecars

### Message Queue Operators

Deploy message brokers:

```yaml
apiVersion: messaging.example.com/v1
kind: KafkaCluster
metadata:
  name: event-broker
spec:
  version: "3.2"
  replicas: 3
  zookeeper:
    replicas: 3
  storage:
    size: 50Gi
  config:
    log.retention.hours: 168
    num.partitions: 10
```

### Application Operators

Manage complex applications:

```yaml
apiVersion: apps.example.com/v1
kind: ApplicationDeployment
metadata:
  name: myapp
spec:
  version: "2.0"
  components:
    frontend:
      replicas: 3
      image: myapp/frontend:2.0
    backend:
      replicas: 5
      image: myapp/backend:2.0
    cache:
      replicas: 2
      image: redis:6
  ingress:
    enabled: true
    hostname: myapp.example.com
```

**Hands-On: Deploy a Complete Operator**

This example shows deploying a WebApp operator that manages applications:

**Step 1: Install the CRD**

```bash
# Deploy the WebApp CRD with subresources
kubectl apply -f labs/operators/specs/ckad/app-crd-with-subresources.yaml

# Verify CRD installation
kubectl get crds webapps.apps.example.com
kubectl api-resources | grep webapp
```

**Step 2: Deploy Operator RBAC**

```bash
# Create ServiceAccount, ClusterRole, and ClusterRoleBinding
kubectl apply -f labs/operators/specs/ckad/simple-operator-rbac.yaml

# Verify RBAC setup
kubectl get serviceaccount webapp-operator
kubectl get clusterrole webapp-operator
kubectl get clusterrolebinding webapp-operator

# Check operator has required permissions
kubectl auth can-i create deployments --as system:serviceaccount:default:webapp-operator
kubectl auth can-i update webapps/status --as system:serviceaccount:default:webapp-operator
```

**Step 3: Deploy the Operator Controller**

```bash
# Deploy the operator deployment
kubectl apply -f labs/operators/specs/ckad/simple-operator-deployment.yaml

# Watch operator start
kubectl get pods -l app=webapp-operator -w

# Check operator logs
kubectl logs -l app=webapp-operator
# Should show: "Watching for WebApp resources..."
```

**Step 4: Create Custom Resources**

```bash
# Create a WebApp resource
kubectl apply -f labs/operators/specs/ckad/webapp-example.yaml

# Watch the operator create managed resources
kubectl get webapps
kubectl get deployments
kubectl get services
kubectl get pods

# Check WebApp status
kubectl describe webapp mywebapp
```

**Step 5: Observe Operator Behavior**

```bash
# Watch operator logs as it processes the WebApp
kubectl logs -l app=webapp-operator -f

# See what resources operator created
kubectl get all -l app=mywebapp

# Check the WebApp status (updated by operator)
kubectl get webapp mywebapp -o jsonpath='{.status}' | jq
```

**Step 6: Test Operator Reconciliation**

```bash
# Delete a pod managed by the operator
kubectl delete pod -l app=mywebapp --force --grace-period=0

# Watch operator recreate it
kubectl get pods -l app=mywebapp -w

# Manually delete the deployment
kubectl delete deployment mywebapp

# Watch operator recreate it
kubectl get deployments -w
```

**Step 7: Scale the Application**

```bash
# Scale using the scale subresource
kubectl scale webapp mywebapp --replicas=5

# Watch operator update deployment
kubectl get webapp mywebapp -o jsonpath='{.spec.replicas}'
kubectl get deployment mywebapp -o jsonpath='{.spec.replicas}'

# Check status
kubectl get webapps
```

**Step 8: Update the Application**

```bash
# Edit the WebApp to change image
kubectl patch webapp mywebapp --type=merge -p '{"spec":{"image":"nginx:1.26-alpine"}}'

# Watch operator update deployment
kubectl get deployment mywebapp -o jsonpath='{.spec.template.spec.containers[0].image}'

# Check rollout status
kubectl rollout status deployment mywebapp
```

**Step 9: Cleanup**

```bash
# Delete the custom resource (operator cleans up managed resources)
kubectl delete webapp mywebapp

# Verify operator deleted managed resources
kubectl get deployments
kubectl get services
kubectl get pods

# Delete the operator
kubectl delete -f labs/operators/specs/ckad/simple-operator-deployment.yaml
kubectl delete -f labs/operators/specs/ckad/simple-operator-rbac.yaml

# Delete the CRD
kubectl delete -f labs/operators/specs/ckad/app-crd-with-subresources.yaml
```

**What We Learned:**
- Operators watch custom resources and reconcile state
- They create and manage standard Kubernetes resources
- RBAC controls what resources operators can manage
- Operators continuously monitor and fix drift
- Deleting a CR triggers cleanup of managed resources

## Querying Custom Resources

### Basic Queries

```bash
# List all custom resources of a type
kubectl get applications
kubectl get applications -A  # All namespaces
kubectl get applications -n dev

# Get with output formats
kubectl get applications -o wide
kubectl get applications -o yaml
kubectl get applications -o json

# Use short names
kubectl get app
kubectl get apps

# Describe custom resource
kubectl describe application myapp

# Get specific fields
kubectl get application myapp -o jsonpath='{.spec.version}'
kubectl get applications -o custom-columns=NAME:.metadata.name,VERSION:.spec.version
```

### Advanced Queries

```bash
# Filter by labels
kubectl get applications -l environment=production
kubectl get applications -l 'tier in (frontend,backend)'

# Filter by field selector
kubectl get applications --field-selector metadata.namespace=default

# Watch for changes
kubectl get applications -w

# Get events for custom resource
kubectl get events --field-selector involvedObject.name=myapp

# JSONPath queries
kubectl get applications -o jsonpath='{.items[*].metadata.name}'
kubectl get applications -o jsonpath='{.items[?(@.spec.replicas>3)].metadata.name}'
```

### Checking Status

Many operators update the status subresource:

```bash
# Get full status
kubectl get application myapp -o jsonpath='{.status}' | jq

# Check specific status fields
kubectl get application myapp -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'

# Wait for condition
kubectl wait --for=condition=Ready application/myapp --timeout=300s
```

**Understanding Status Conditions**

Status conditions follow a standard pattern in Kubernetes:

```yaml
status:
  conditions:
  - type: Ready              # Condition type
    status: "True"          # True, False, or Unknown
    lastTransitionTime: "2024-01-15T10:30:00Z"
    reason: AllPodsReady    # Machine-readable reason
    message: All replicas are ready  # Human-readable message
```

**Common Condition Types:**

- **Ready**: Resource is ready and operational
- **Progressing**: Resource is being created/updated
- **Available**: Minimum required replicas are available
- **Degraded**: Resource is running but not at full capacity
- **Failed**: Resource encountered an error

**Example with Multiple Conditions:**

```bash
# Deploy example with status
kubectl apply -f labs/operators/specs/ckad/app-crd-with-subresources.yaml
kubectl apply -f labs/operators/specs/ckad/webapp-example.yaml

# Simulate status update (normally done by operator)
kubectl patch webapp mywebapp --subresource=status --type=merge -p '
{
  "status": {
    "replicas": 3,
    "availableReplicas": 3,
    "conditions": [
      {
        "type": "Ready",
        "status": "True",
        "lastTransitionTime": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
        "reason": "AllPodsReady",
        "message": "All replicas are ready"
      },
      {
        "type": "Progressing",
        "status": "True",
        "lastTransitionTime": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
        "reason": "NewReplicaSetAvailable",
        "message": "Deployment has successfully progressed"
      },
      {
        "type": "Available",
        "status": "True",
        "lastTransitionTime": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
        "reason": "MinimumReplicasAvailable",
        "message": "Deployment has minimum availability"
      }
    ]
  }
}'

# View all conditions
kubectl get webapp mywebapp -o jsonpath='{.status.conditions[*]}' | jq

# Check specific condition status
kubectl get webapp mywebapp -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
# True

# Get condition message
kubectl get webapp mywebapp -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}'
# All replicas are ready

# Check if resource is NOT ready
kubectl get webapp mywebapp -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep -q "False" && echo "Not Ready" || echo "Ready"
```

**Interpreting Status Conditions:**

```bash
# Get all conditions with their status
kubectl get webapp mywebapp -o json | jq -r '.status.conditions[] | "\(.type): \(.status) - \(.message)"'
# Ready: True - All replicas are ready
# Progressing: True - Deployment has successfully progressed
# Available: True - Deployment has minimum availability

# Check last transition time for each condition
kubectl get webapp mywebapp -o json | jq -r '.status.conditions[] | "\(.type): \(.lastTransitionTime)"'

# Filter for failed conditions
kubectl get webapp mywebapp -o json | jq -r '.status.conditions[] | select(.status=="False") | "\(.type): \(.reason) - \(.message)"'
```

**Wait for Specific Conditions:**

```bash
# Wait for Ready condition
kubectl wait --for=condition=Ready webapp/mywebapp --timeout=300s

# Wait for multiple resources to be ready
kubectl wait --for=condition=Ready webapp --all --timeout=300s

# Check if condition exists before waiting
if kubectl get webapp mywebapp -o jsonpath='{.status.conditions[?(@.type=="Ready")]}' > /dev/null 2>&1; then
  kubectl wait --for=condition=Ready webapp/mywebapp --timeout=60s
fi
```

**Example: Troubleshooting with Conditions:**

```bash
# Create a resource
kubectl apply -f labs/operators/specs/ckad/webapp-example.yaml

# Resource not ready - check why
kubectl get webapp mywebapp -o json | jq '.status.conditions[] | select(.status=="False")'
# {
#   "type": "Ready",
#   "status": "False",
#   "reason": "PodsFailing",
#   "message": "2 of 3 pods are in CrashLoopBackOff"
# }

# Get more details from the condition message
kubectl get webapp mywebapp -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}'

# Compare with events
kubectl get events --field-selector involvedObject.name=mywebapp
```

**Status Condition Best Practices:**

1. **Always check conditions**: They provide the most detailed status
2. **Use `kubectl wait`**: For automation and scripts
3. **Check reason and message**: For troubleshooting context
4. **Monitor transitions**: Track when conditions change state
5. **Multiple conditions**: Resources may have several conditions simultaneously

## Troubleshooting Operators

### Common Issues

**Issue 1: CRD Not Found**

```bash
# Error: "the server doesn't have a resource type 'applications'"

# Check if CRD is installed
kubectl get crds | grep applications

# Install CRD if missing
kubectl apply -f crd.yaml
```

**Issue 2: Operator Pod Not Running**

```bash
# Check operator pod status
kubectl get pods -l app=myoperator
kubectl describe pod -l app=myoperator
kubectl logs -l app=myoperator

# Common causes:
# - Image pull errors
# - RBAC permission denied
# - Resource limits too low
# - Missing dependencies
```

**Issue 3: Custom Resource Created but Nothing Happens**

```bash
# Check operator logs for errors
kubectl logs -l app=myoperator --tail=100

# Check operator is watching correct namespace
kubectl get deployment myoperator -o jsonpath='{.spec.template.spec.containers[0].env}'

# Verify RBAC permissions
kubectl auth can-i create deployments --as system:serviceaccount:default:myoperator

# Check custom resource is valid
kubectl get application myapp -o yaml
kubectl describe application myapp
```

**Issue 4: Operator Creating Wrong Resources**

```bash
# Check operator version
kubectl get deployment myoperator -o jsonpath='{.spec.template.spec.containers[0].image}'

# Check operator configuration
kubectl get configmap -l app=myoperator
kubectl describe configmap myoperator-config

# Review custom resource spec
kubectl get application myapp -o yaml
```

### Debugging Commands

```bash
# Get all custom resource types
kubectl get crds
kubectl api-resources --api-group=apps.example.com

# Check CRD details
kubectl get crd applications.apps.example.com -o yaml
kubectl explain applications.spec

# Check operator status
kubectl get deployment -l app=myoperator
kubectl get pods -l app=myoperator
kubectl logs -l app=myoperator --tail=50 -f

# Check operator RBAC
kubectl get serviceaccount myoperator -o yaml
kubectl get clusterrole myoperator -o yaml
kubectl get clusterrolebinding myoperator -o yaml

# Check custom resources
kubectl get applications -A
kubectl describe application myapp
kubectl get application myapp -o yaml

# Check objects created by operator
kubectl get all -l managed-by=myoperator
kubectl get all -l application=myapp

# Check events
kubectl get events --sort-by='.lastTimestamp'
kubectl get events --field-selector involvedObject.name=myapp

# Delete and recreate custom resource
kubectl delete application myapp
kubectl apply -f myapp.yaml
```

**Complete Troubleshooting Scenario**

**Scenario**: You deployed an operator, created a custom resource, but nothing is working. Let's debug systematically.

**Step 1: Verify CRD Installation**

```bash
# Check if CRD exists
kubectl get crds | grep webapp
# If missing: Error message "the server doesn't have a resource type 'webapps'"

# If CRD missing, install it
kubectl apply -f labs/operators/specs/ckad/app-crd-with-subresources.yaml

# Verify CRD is ready
kubectl get crd webapps.apps.example.com
kubectl describe crd webapps.apps.example.com
```

**Step 2: Check Operator Pod Status**

```bash
# Find operator pod
kubectl get pods -l app=webapp-operator

# If pod is missing, deploy operator
kubectl apply -f labs/operators/specs/ckad/simple-operator-rbac.yaml
kubectl apply -f labs/operators/specs/ckad/simple-operator-deployment.yaml

# If pod exists but not running, check status
kubectl describe pod -l app=webapp-operator

# Common pod issues:
# - ImagePullBackOff: Image doesn't exist or auth failed
# - CrashLoopBackOff: Container crashes on start
# - Pending: Resource constraints or scheduling issues
```

**Step 3: Check Operator Logs**

```bash
# View operator logs
kubectl logs -l app=webapp-operator --tail=50

# Look for common errors:
# "forbidden" -> RBAC permission denied
# "not found" -> Missing dependencies
# "connection refused" -> Network/API server issues
# "panic" or "fatal" -> Code errors

# Follow logs in real-time
kubectl logs -l app=webapp-operator -f
```

**Step 4: Verify RBAC Permissions**

```bash
# Check if ServiceAccount exists
kubectl get serviceaccount webapp-operator

# Check if ClusterRole exists
kubectl get clusterrole webapp-operator

# Check if ClusterRoleBinding exists
kubectl get clusterrolebinding webapp-operator

# Test specific permissions operator needs
kubectl auth can-i create deployments --as system:serviceaccount:default:webapp-operator
kubectl auth can-i update webapps/status --as system:serviceaccount:default:webapp-operator

# If permissions missing, check binding
kubectl describe clusterrolebinding webapp-operator

# View all permissions
kubectl describe clusterrole webapp-operator
```

**Step 5: Verify Custom Resource is Valid**

```bash
# Try to create the WebApp
kubectl apply -f labs/operators/specs/ckad/webapp-example.yaml

# If validation fails, check the error
# Error: validation failure means CRD schema rejection

# Verify custom resource was created
kubectl get webapps
kubectl describe webapp mywebapp

# Check for events on the resource
kubectl get events --field-selector involvedObject.name=mywebapp --sort-by='.lastTimestamp'
```

**Step 6: Check What Operator Created**

```bash
# List all resources that should exist
kubectl get deployments
kubectl get services
kubectl get pods

# Check if operator created resources with labels
kubectl get all -l app=mywebapp

# If nothing created, operator likely not watching or has RBAC issues
# Check operator logs again:
kubectl logs -l app=webapp-operator | grep -i "mywebapp\|error\|failed"
```

**Step 7: Test Operator Reconciliation**

```bash
# Force operator to reconcile by updating custom resource
kubectl patch webapp mywebapp --type=merge -p '{"spec":{"replicas":4}}'

# Watch operator logs to see if it processes the change
kubectl logs -l app=webapp-operator -f

# If no logs appear, operator isn't watching
# Check operator's WATCH_NAMESPACE environment variable
kubectl get deployment webapp-operator -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="WATCH_NAMESPACE")].value}'
```

**Step 8: Detailed Error Investigation**

```bash
# Get complete operator pod details
kubectl get pod -l app=webapp-operator -o yaml

# Check resource limits
kubectl get pod -l app=webapp-operator -o jsonpath='{.spec.containers[0].resources}'

# Check operator service account
kubectl get pod -l app=webapp-operator -o jsonpath='{.spec.serviceAccountName}'
# Should be: webapp-operator

# Verify service account has correct role binding
kubectl get clusterrolebinding webapp-operator -o yaml
```

**Step 9: Network and API Access**

```bash
# Test operator can reach Kubernetes API
kubectl exec -it $(kubectl get pod -l app=webapp-operator -o name) -- sh
# Inside pod:
# curl https://kubernetes.default.svc/api/v1/namespaces/default
# Should return JSON (if operator has basic cluster permissions)

# Check DNS resolution
kubectl exec -it $(kubectl get pod -l app=webapp-operator -o name) -- nslookup kubernetes.default.svc
```

**Step 10: Fix Common Issues**

**Issue: RBAC Permission Denied**
```bash
# Add missing permissions to ClusterRole
kubectl edit clusterrole webapp-operator

# Or reapply complete RBAC
kubectl apply -f labs/operators/specs/ckad/simple-operator-rbac.yaml

# Restart operator pod to pick up new permissions
kubectl rollout restart deployment webapp-operator
```

**Issue: Operator Not Watching Namespace**
```bash
# Check WATCH_NAMESPACE setting
kubectl set env deployment/webapp-operator WATCH_NAMESPACE=""

# Verify change
kubectl rollout status deployment webapp-operator
```

**Issue: Resource Limits Too Low**
```bash
# Increase operator resources
kubectl patch deployment webapp-operator -p '
{
  "spec": {
    "template": {
      "spec": {
        "containers": [
          {
            "name": "operator",
            "resources": {
              "limits": {
                "cpu": "500m",
                "memory": "512Mi"
              },
              "requests": {
                "cpu": "200m",
                "memory": "256Mi"
              }
            }
          }
        ]
      }
    }
  }
}'
```

**Step 11: Verify Fix**

```bash
# Check operator is running
kubectl get pods -l app=webapp-operator
# STATUS should be: Running

# Create a test custom resource
kubectl apply -f labs/operators/specs/ckad/webapp-example.yaml

# Watch for managed resources to be created
kubectl get all -l app=mywebapp -w

# Check operator processed the resource
kubectl logs -l app=webapp-operator | tail -20

# Verify status is updated
kubectl get webapp mywebapp -o jsonpath='{.status}' | jq
```

**Troubleshooting Checklist:**
- [ ] CRD is installed and ready
- [ ] Operator pod is running
- [ ] Operator logs show no errors
- [ ] RBAC permissions are correct
- [ ] Custom resource passes validation
- [ ] Operator creates managed resources
- [ ] Status is updated by operator
- [ ] Reconciliation works on updates

## Updating Custom Resources

### Updating Spec

```bash
# Edit interactively
kubectl edit application myapp

# Patch specific field
kubectl patch application myapp --type='json' \
  -p='[{"op": "replace", "path": "/spec/replicas", "value": 5}]'

# Replace from file
kubectl apply -f myapp-updated.yaml

# Using kubectl set (if supported)
kubectl set image application/myapp container=newimage:v2
```

### Updating Status (Controller Only)

```bash
# Status should only be updated by the operator
# But for testing, you can update it manually:
kubectl patch application myapp --subresource=status --type=merge \
  -p '{"status":{"replicas":5,"ready":true}}'
```

### Scaling (if scale subresource enabled)

```bash
# Use kubectl scale
kubectl scale application myapp --replicas=10

# Check current scale
kubectl get application myapp -o jsonpath='{.spec.replicas}'
```

## Deleting Custom Resources and CRDs

### Deleting Custom Resources

```bash
# Delete specific resource
kubectl delete application myapp

# Delete multiple resources
kubectl delete application app1 app2 app3

# Delete by label
kubectl delete applications -l environment=dev

# Delete all in namespace
kubectl delete applications --all
```

### Deleting CRDs

> **Warning:** Deleting a CRD deletes all custom resources of that type!

```bash
# List custom resources first
kubectl get applications -A

# Delete custom resources
kubectl delete applications --all -A

# Then delete CRD
kubectl delete crd applications.apps.example.com

# Or delete operator (which usually manages CRD deletion)
kubectl delete -f operator.yaml
```

### Cleanup Order

When removing an operator:

1. Delete custom resources (let operator clean up)
2. Wait for operator to delete managed objects
3. Delete operator deployment
4. Delete CRDs
5. Delete RBAC objects

```bash
# 1. Delete custom resources
kubectl delete applications --all

# 2. Wait for cleanup
kubectl get pods -l managed-by=myoperator --watch

# 3. Delete operator
kubectl delete deployment myoperator

# 4. Delete CRDs
kubectl delete crd applications.apps.example.com

# 5. Delete RBAC
kubectl delete serviceaccount myoperator
kubectl delete clusterrole myoperator
kubectl delete clusterrolebinding myoperator
```

**Hands-On Cleanup Example**

This example demonstrates proper cleanup order with a complete operator deployment:

**Setup: Deploy Everything**

```bash
# 1. Install CRD
kubectl apply -f labs/operators/specs/ckad/app-crd-with-subresources.yaml

# 2. Install operator RBAC
kubectl apply -f labs/operators/specs/ckad/simple-operator-rbac.yaml

# 3. Deploy operator
kubectl apply -f labs/operators/specs/ckad/simple-operator-deployment.yaml

# 4. Wait for operator to be ready
kubectl wait --for=condition=Ready pod -l app=webapp-operator --timeout=60s

# 5. Create custom resources
kubectl apply -f labs/operators/specs/ckad/webapp-example.yaml

# 6. Verify everything is running
kubectl get crds webapps.apps.example.com
kubectl get pods -l app=webapp-operator
kubectl get webapps
kubectl get all -l app=mywebapp
```

**Cleanup: Proper Order**

**Step 1: Delete Custom Resources (Let operator clean up)**

```bash
# List all custom resources before deleting
kubectl get webapps -A

# Delete custom resources (operator watches and cleans up managed resources)
kubectl delete webapp mywebapp

# Watch operator clean up managed resources
kubectl get deployments,services,pods -l app=mywebapp -w
# Resources should disappear as operator processes deletion

# Verify all custom resources are gone
kubectl get webapps
# No resources found
```

**Step 2: Wait for Managed Resources Cleanup**

```bash
# Verify operator cleaned up all managed resources
kubectl get all -l app=mywebapp
# No resources found

# Check for any leftover resources
kubectl get deployment mywebapp
# Error from server (NotFound): deployments.apps "mywebapp" not found

# Good! Operator cleaned up properly
```

**Step 3: Delete the Operator Deployment**

```bash
# Now safe to delete operator (no custom resources remain)
kubectl delete -f labs/operators/specs/ckad/simple-operator-deployment.yaml

# Verify operator pod is terminating
kubectl get pods -l app=webapp-operator -w

# Check operator pod is gone
kubectl get pods -l app=webapp-operator
# No resources found
```

**Step 4: Delete CRDs**

```bash
# Delete the CRD (only after all custom resources are deleted)
kubectl delete -f labs/operators/specs/ckad/app-crd-with-subresources.yaml

# WARNING: If custom resources still exist, they'll be deleted with CRD
# Verify CRD is gone
kubectl get crds webapps.apps.example.com
# Error from server (NotFound)
```

**Step 5: Delete RBAC Resources**

```bash
# Clean up RBAC (last step)
kubectl delete -f labs/operators/specs/ckad/simple-operator-rbac.yaml

# Verify RBAC resources are deleted
kubectl get serviceaccount webapp-operator
kubectl get clusterrole webapp-operator
kubectl get clusterrolebinding webapp-operator
# All should return: Error from server (NotFound)
```

**Complete Cleanup Verification**

```bash
# Verify complete cleanup
echo "Checking for leftover resources..."

# Check custom resources
kubectl get webapps -A
# No resources found

# Check CRD
kubectl get crds | grep webapp
# (no output)

# Check operator
kubectl get pods -l app=webapp-operator
# No resources found

# Check RBAC
kubectl get clusterrole webapp-operator
# Error from server (NotFound)

echo "Cleanup complete!"
```

**What Happens If You Delete in Wrong Order?**

**Scenario: Delete CRD before custom resources**

```bash
# DON'T DO THIS - example of what NOT to do
kubectl delete crd webapps.apps.example.com

# This will:
# 1. Delete the CRD
# 2. Delete ALL custom resources of that type (webapps)
# 3. Operator may not have chance to clean up managed resources
# 4. You'll have orphaned deployments, services, etc.

# Result: Orphaned resources
kubectl get deployments,services -l app=mywebapp
# Resources still exist but no custom resource to track them!
```

**Scenario: Delete operator before custom resources**

```bash
# DON'T DO THIS
kubectl delete deployment webapp-operator
kubectl delete webapp mywebapp  # Operator not running to handle cleanup!

# This will:
# 1. Delete the operator
# 2. Custom resource gets deleted but operator can't process it
# 3. Managed resources become orphaned

# Manual cleanup required:
kubectl delete deployment,service,pod -l app=mywebapp
```

**Safe Emergency Cleanup (if things went wrong)**

```bash
# If you deleted in wrong order and have orphaned resources:

# 1. Delete all managed resources by label
kubectl delete all -l managed-by=operator
kubectl delete all -l app=mywebapp

# 2. Force delete stuck custom resources
kubectl delete webapp --all --force --grace-period=0

# 3. Remove finalizers if resources are stuck
kubectl patch webapp mywebapp -p '{"metadata":{"finalizers":[]}}' --type=merge

# 4. Delete CRD (force if needed)
kubectl delete crd webapps.apps.example.com --force --grace-period=0

# 5. Clean up RBAC
kubectl delete serviceaccount,clusterrole,clusterrolebinding -l app=webapp-operator
```

**Cleanup Best Practices:**

1. **Always delete in order**: Custom Resources → Operator → CRDs → RBAC
2. **Verify each step**: Check resources are gone before proceeding
3. **Let operator clean up**: Wait for operator to remove managed resources
4. **Check for finalizers**: Some operators use finalizers to prevent premature deletion
5. **Label everything**: Makes emergency cleanup easier with label selectors
6. **Document cleanup**: Include cleanup steps in operator documentation

## Lab Exercises

### Exercise 1: Create and Use a CRD

Create a CRD for "Website" resources with the following:
- Fields: domain, replicas, sslEnabled
- Validation: replicas 1-10, domain must be valid format
- Additional printer columns showing domain and replicas
- Create several Website resources and query them

<details>
  <summary>Solution</summary>

**Step 1: Create the Website CRD**

```bash
# Deploy the CRD
kubectl apply -f labs/operators/specs/ckad/website-crd.yaml

# Verify CRD installation
kubectl get crds websites.web.example.com

# Check available fields
kubectl explain website.spec
kubectl explain website.spec.domain
kubectl explain website.spec.replicas
```

**Step 2: Create Website Resources**

```bash
# Create production website
kubectl apply -f labs/operators/specs/ckad/website-production.yaml

# Create staging website
kubectl apply -f labs/operators/specs/ckad/website-staging.yaml

# Create development website
kubectl apply -f labs/operators/specs/ckad/website-dev.yaml
```

**Step 3: Query Websites**

```bash
# List all websites (using additional printer columns)
kubectl get websites
# NAME              DOMAIN                 REPLICAS   SSL     AGE
# production-site   www.example.com        5          true    30s
# staging-site      staging.example.com    2          true    25s
# dev-site          dev.example.com        1          false   20s

# Use short name
kubectl get ws
kubectl get site

# Filter by labels
kubectl get websites -l environment=production

# Get with custom columns
kubectl get websites -o custom-columns=\
NAME:.metadata.name,\
DOMAIN:.spec.domain,\
REPLICAS:.spec.replicas,\
SSL:.spec.sslEnabled

# Get specific fields with JSONPath
kubectl get websites -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.domain}{"\t"}{.spec.replicas}{"\n"}{end}'

# Get SSL-enabled websites
kubectl get websites -o json | jq -r '.items[] | select(.spec.sslEnabled==true) | .metadata.name'

# Sort by replica count
kubectl get websites -o json | jq -r '.items | sort_by(.spec.replicas) | .[] | "\(.metadata.name): \(.spec.replicas)"'
```

**Step 4: Test Validation**

```bash
# Try invalid domain (will fail)
cat <<EOF | kubectl apply -f -
apiVersion: web.example.com/v1
kind: Website
metadata:
  name: invalid-domain
spec:
  domain: INVALID_DOMAIN  # Uppercase not allowed
  replicas: 2
  sslEnabled: true
EOF
# Error: validation failure

# Try invalid replicas (will fail)
cat <<EOF | kubectl apply -f -
apiVersion: web.example.com/v1
kind: Website
metadata:
  name: too-many-replicas
spec:
  domain: test.example.com
  replicas: 15  # Exceeds maximum of 10
  sslEnabled: true
EOF
# Error: validation failure

# Valid website
cat <<EOF | kubectl apply -f -
apiVersion: web.example.com/v1
kind: Website
metadata:
  name: test-site
spec:
  domain: test.example.com
  replicas: 3
  sslEnabled: true
EOF
# Success!
```

**Step 5: Update Websites**

```bash
# Scale production website
kubectl patch website production-site --type=merge -p '{"spec":{"replicas":8}}'

# Enable SSL on dev site
kubectl patch website dev-site --type=merge -p '{"spec":{"sslEnabled":true}}'

# Verify changes
kubectl get websites
```

**Step 6: Cleanup**

```bash
# Delete all websites
kubectl delete websites --all

# Delete CRD
kubectl delete crd websites.web.example.com
```

</details>

### Exercise 2: Inspect an Operator

Deploy a sample operator (NATS or MySQL from README):
1. Identify all CRDs it installs
2. Check its RBAC permissions
3. Examine its deployment configuration
4. View its logs
5. Create a custom resource and watch what happens

<details>
  <summary>Solution</summary>

**Step 1: Deploy the Operator (using WebApp example)**

```bash
# Install CRD
kubectl apply -f labs/operators/specs/ckad/app-crd-with-subresources.yaml

# Install RBAC
kubectl apply -f labs/operators/specs/ckad/simple-operator-rbac.yaml

# Deploy operator
kubectl apply -f labs/operators/specs/ckad/simple-operator-deployment.yaml

# Wait for operator to start
kubectl wait --for=condition=Ready pod -l app=webapp-operator --timeout=60s
```

**Step 2: Identify All CRDs**

```bash
# List all CRDs installed by operator
kubectl get crds | grep -E "apps.example.com|web.example.com"

# Get detailed information about the CRD
kubectl get crd webapps.apps.example.com -o yaml

# Check CRD group and versions
kubectl get crd webapps.apps.example.com -o jsonpath='{.spec.group}'
# apps.example.com

kubectl get crd webapps.apps.example.com -o jsonpath='{.spec.versions[*].name}'
# v1

# Check resource names
kubectl api-resources | grep apps.example.com
# NAME      SHORTNAMES   APIVERSION              NAMESPACED   KIND
# webapps   wa           apps.example.com/v1     true         WebApp

# Inspect CRD schema
kubectl explain webapp
kubectl explain webapp.spec
kubectl explain webapp.status
```

**Step 3: Check RBAC Permissions**

```bash
# Find ServiceAccount used by operator
kubectl get deployment webapp-operator -o jsonpath='{.spec.template.spec.serviceAccountName}'
# webapp-operator

# Find associated ClusterRole
kubectl get clusterrolebinding -o json | \
  jq -r '.items[] | select(.subjects[]?.name=="webapp-operator") | .roleRef.name'
# webapp-operator

# Examine ClusterRole permissions
kubectl get clusterrole webapp-operator -o yaml

# List all API groups operator can access
kubectl get clusterrole webapp-operator -o jsonpath='{.rules[*].apiGroups}' | tr ' ' '\n' | sort -u

# List all resources operator can manage
kubectl get clusterrole webapp-operator -o jsonpath='{.rules[*].resources}' | tr ' ' '\n' | sort -u

# Check specific permissions
echo "Custom Resource Permissions:"
kubectl auth can-i get webapps --as system:serviceaccount:default:webapp-operator
kubectl auth can-i create webapps --as system:serviceaccount:default:webapp-operator
kubectl auth can-i update webapps/status --as system:serviceaccount:default:webapp-operator

echo "Managed Resource Permissions:"
kubectl auth can-i create deployments --as system:serviceaccount:default:webapp-operator
kubectl auth can-i create services --as system:serviceaccount:default:webapp-operator
kubectl auth can-i create configmaps --as system:serviceaccount:default:webapp-operator
kubectl auth can-i create secrets --as system:serviceaccount:default:webapp-operator

echo "Denied Permissions (should be 'no'):"
kubectl auth can-i create crds --as system:serviceaccount:default:webapp-operator
kubectl auth can-i delete nodes --as system:serviceaccount:default:webapp-operator
```

**Step 4: Examine Deployment Configuration**

```bash
# Get complete deployment details
kubectl get deployment webapp-operator -o yaml

# Check operator image
kubectl get deployment webapp-operator -o jsonpath='{.spec.template.spec.containers[0].image}'

# Check environment variables
kubectl get deployment webapp-operator -o jsonpath='{.spec.template.spec.containers[*].env[*]}' | jq

# Check resource limits
kubectl get deployment webapp-operator -o jsonpath='{.spec.template.spec.containers[0].resources}' | jq

# Check replicas
kubectl get deployment webapp-operator -o jsonpath='{.spec.replicas}'

# Check health probes
kubectl get deployment webapp-operator -o jsonpath='{.spec.template.spec.containers[0].livenessProbe}' | jq
kubectl get deployment webapp-operator -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}' | jq

# Check which namespace operator watches
kubectl get deployment webapp-operator -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="WATCH_NAMESPACE")].value}'
# Empty string means all namespaces
```

**Step 5: View Operator Logs**

```bash
# Get current logs
kubectl logs -l app=webapp-operator

# Follow logs in real-time
kubectl logs -l app=webapp-operator -f

# Get logs with timestamps
kubectl logs -l app=webapp-operator --timestamps

# Get last 50 lines
kubectl logs -l app=webapp-operator --tail=50

# Search for specific events
kubectl logs -l app=webapp-operator | grep -i "watching\|reconcile\|error"

# Check previous logs if pod restarted
kubectl logs -l app=webapp-operator --previous
```

**Step 6: Create Custom Resource and Watch**

```bash
# Open a second terminal to watch logs
# Terminal 1:
kubectl logs -l app=webapp-operator -f

# Terminal 2: Create custom resource
kubectl apply -f labs/operators/specs/ckad/webapp-example.yaml

# Watch what operator creates
kubectl get all -w

# Check what resources were created
kubectl get deployments
kubectl get services
kubectl get pods

# Check custom resource status (updated by operator)
kubectl get webapp mywebapp -o yaml

# Check events
kubectl get events --sort-by='.lastTimestamp' | grep webapp

# Verify operator reconciliation
kubectl delete pod -l app=mywebapp
# Watch operator logs - it should detect and recreate pods
```

**Analysis Summary:**

```bash
# Create a summary report
echo "=== Operator Analysis Report ==="
echo ""
echo "CRDs Installed:"
kubectl get crds | grep apps.example.com

echo ""
echo "Operator Pod:"
kubectl get pods -l app=webapp-operator

echo ""
echo "ServiceAccount:"
kubectl get sa webapp-operator

echo ""
echo "ClusterRole Permissions:"
kubectl get clusterrole webapp-operator -o jsonpath='{.rules[*].resources}' | tr ' ' '\n' | sort -u

echo ""
echo "Environment Variables:"
kubectl get deployment webapp-operator -o jsonpath='{.spec.template.spec.containers[0].env[*]}' | jq

echo ""
echo "Custom Resources:"
kubectl get webapps

echo ""
echo "Managed Resources:"
kubectl get all -l app=mywebapp
```

**Cleanup:**

```bash
kubectl delete webapp mywebapp
kubectl delete -f labs/operators/specs/ckad/simple-operator-deployment.yaml
kubectl delete -f labs/operators/specs/ckad/simple-operator-rbac.yaml
kubectl delete -f labs/operators/specs/ckad/app-crd-with-subresources.yaml
```

</details>

### Exercise 3: Troubleshoot Broken Operator

Given a broken operator deployment:
1. Operator pod is in CrashLoopBackoff
2. Custom resources created but nothing happens
3. Objects created but in wrong configuration

Debug and fix each issue.

<details>
  <summary>Solution</summary>

**Scenario 1: Operator Pod in CrashLoopBackOff**

```bash
# Deploy broken operator with non-existent image
kubectl apply -f labs/operators/specs/ckad/broken-operator-crashloop.yaml

# Check pod status
kubectl get pods -l app=crashloop-operator
# NAME                                   READY   STATUS             RESTARTS   AGE
# crashloop-operator-xxx                 0/1     ImagePullBackOff   0          30s

# Diagnose the issue
kubectl describe pod -l app=crashloop-operator
# Events show: Failed to pull image "nonexistent-image:latest"

# Fix 1: Update image to valid one
kubectl set image deployment/crashloop-operator operator=kiamol/ch10-image-gallery-operator:latest

# If it crashes due to resource limits
kubectl get pod -l app=crashloop-operator -o jsonpath='{.spec.containers[0].resources}'

# Fix 2: Increase resource limits
kubectl patch deployment crashloop-operator -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "operator",
          "resources": {
            "requests": {"cpu": "100m", "memory": "128Mi"},
            "limits": {"cpu": "200m", "memory": "256Mi"}
          }
        }]
      }
    }
  }
}'

# Verify fix
kubectl get pods -l app=crashloop-operator
# STATUS should be: Running

# Cleanup
kubectl delete deployment crashloop-operator
kubectl delete serviceaccount crashloop-operator
```

**Scenario 2: Custom Resources Created But Nothing Happens**

```bash
# Deploy operator with insufficient RBAC
kubectl apply -f labs/operators/specs/ckad/app-crd-with-subresources.yaml
kubectl apply -f labs/operators/specs/ckad/broken-operator-no-rbac.yaml

# Create custom resource
kubectl apply -f labs/operators/specs/ckad/webapp-example.yaml

# Check if resources were created
kubectl get webapps
# mywebapp exists

kubectl get deployments
# No deployments - operator didn't create them!

# Diagnose: Check operator logs
kubectl logs -l app=broken-operator
# Error: "forbidden: User system:serviceaccount:default:broken-operator cannot create resource deployments"

# Check RBAC permissions
kubectl auth can-i create deployments --as system:serviceaccount:default:broken-operator
# no

# View current ClusterRole
kubectl get clusterrole broken-operator -o yaml
# Only has: get, list, watch (missing create, update, delete)

# Fix: Update ClusterRole with correct permissions
kubectl apply -f labs/operators/specs/ckad/simple-operator-rbac.yaml

# Update deployment to use correct ServiceAccount
kubectl patch deployment broken-operator -p '{"spec":{"template":{"spec":{"serviceAccountName":"webapp-operator"}}}}'

# Restart operator pods to pick up new permissions
kubectl rollout restart deployment broken-operator

# Trigger reconciliation
kubectl patch webapp mywebapp --type=merge -p '{"spec":{"replicas":4}}'

# Verify fix
kubectl get deployments
# mywebapp deployment should now exist

kubectl logs -l app=broken-operator | tail -20
# Should show successful reconciliation

# Cleanup
kubectl delete webapp mywebapp
kubectl delete deployment broken-operator
kubectl delete clusterrolebinding broken-operator
kubectl delete clusterrole broken-operator
kubectl delete serviceaccount broken-operator
```

**Scenario 3: Operator Creates Resources with Wrong Configuration**

```bash
# Setup: Deploy working operator
kubectl apply -f labs/operators/specs/ckad/app-crd-with-subresources.yaml
kubectl apply -f labs/operators/specs/ckad/simple-operator-rbac.yaml
kubectl apply -f labs/operators/specs/ckad/simple-operator-deployment.yaml

# Create custom resource requesting 3 replicas
kubectl apply -f labs/operators/specs/ckad/webapp-example.yaml

# Check what was created
kubectl get webapp mywebapp -o jsonpath='{.spec.replicas}'
# 3 (correct)

# Check deployment created by operator
kubectl get deployment mywebapp -o jsonpath='{.spec.replicas}'
# Might be wrong if operator has bug

# Scenario: Operator not watching for updates
# Update custom resource
kubectl patch webapp mywebapp --type=merge -p '{"spec":{"replicas":5}}'

# Wait and check if deployment updated
sleep 10
kubectl get deployment mywebapp -o jsonpath='{.spec.replicas}'
# Still 3 - operator didn't reconcile!

# Diagnose: Check operator is watching correct namespace
kubectl get deployment webapp-operator -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="WATCH_NAMESPACE")].value}'

# Diagnose: Check operator logs
kubectl logs -l app=webapp-operator | grep -i "watch\|reconcile"

# Fix: Ensure operator watches all namespaces
kubectl set env deployment/webapp-operator WATCH_NAMESPACE=""

# Wait for operator to restart
kubectl rollout status deployment webapp-operator

# Trigger reconciliation by updating custom resource
kubectl patch webapp mywebapp --type=merge -p '{"metadata":{"annotations":{"reconcile":"'$(date +%s)'"}}}'

# Verify deployment now matches
kubectl get deployment mywebapp -o jsonpath='{.spec.replicas}'
# Should be 5

# Alternative fix: Delete and recreate custom resource
kubectl delete webapp mywebapp
kubectl apply -f labs/operators/specs/ckad/webapp-example.yaml

# Cleanup
kubectl delete webapp mywebapp
kubectl delete -f labs/operators/specs/ckad/simple-operator-deployment.yaml
kubectl delete -f labs/operators/specs/ckad/simple-operator-rbac.yaml
kubectl delete -f labs/operators/specs/ckad/app-crd-with-subresources.yaml
```

**Common Troubleshooting Steps:**

1. **Check pod status**: `kubectl get pods -l app=operator-name`
2. **View pod events**: `kubectl describe pod -l app=operator-name`
3. **Check logs**: `kubectl logs -l app=operator-name --tail=50`
4. **Verify RBAC**: `kubectl auth can-i <verb> <resource> --as system:serviceaccount:namespace:sa-name`
5. **Check environment**: `kubectl get deployment operator-name -o jsonpath='{.spec.template.spec.containers[0].env[*]}'`
6. **Test reconciliation**: Update custom resource and watch for changes
7. **Check custom resource**: `kubectl get <cr> -o yaml`
8. **View events**: `kubectl get events --sort-by='.lastTimestamp'`

</details>

### Exercise 4: Operator Lifecycle

Practice full operator lifecycle:
1. Install operator
2. Create custom resources
3. Update custom resources
4. Scale resources
5. Delete resources (observe cleanup)
6. Uninstall operator properly

<details>
  <summary>Solution</summary>

**Complete Operator Lifecycle Workflow**

**Phase 1: Installation**

```bash
# Step 1: Install CRD
kubectl apply -f labs/operators/specs/ckad/app-crd-with-subresources.yaml

# Verify CRD
kubectl get crds webapps.apps.example.com
kubectl api-resources | grep webapp

# Step 2: Install RBAC
kubectl apply -f labs/operators/specs/ckad/simple-operator-rbac.yaml

# Verify RBAC
kubectl get serviceaccount webapp-operator
kubectl get clusterrole webapp-operator
kubectl get clusterrolebinding webapp-operator

# Step 3: Deploy Operator
kubectl apply -f labs/operators/specs/ckad/simple-operator-deployment.yaml

# Wait for operator to be ready
kubectl wait --for=condition=Ready pod -l app=webapp-operator --timeout=60s

# Verify operator is running
kubectl get pods -l app=webapp-operator
kubectl logs -l app=webapp-operator
```

**Phase 2: Create Custom Resources**

```bash
# Create WebApp resource
kubectl apply -f labs/operators/specs/ckad/webapp-example.yaml

# Watch operator create managed resources
kubectl get webapps -w &
kubectl get all -w &

# Verify custom resource
kubectl get webapp mywebapp
kubectl describe webapp mywebapp

# Verify operator created managed resources
kubectl get deployments
kubectl get services
kubectl get pods

# Check status updated by operator
kubectl get webapp mywebapp -o jsonpath='{.status}' | jq
```

**Phase 3: Update Custom Resources**

```bash
# Update 1: Change image
kubectl patch webapp mywebapp --type=merge -p '
{
  "spec": {
    "image": "nginx:1.26-alpine"
  }
}'

# Watch operator update deployment
kubectl get deployment mywebapp -o jsonpath='{.spec.template.spec.containers[0].image}'
kubectl rollout status deployment mywebapp

# Update 2: Change port
kubectl patch webapp mywebapp --type=merge -p '
{
  "spec": {
    "port": 8080
  }
}'

# Verify change
kubectl get webapp mywebapp -o jsonpath='{.spec.port}'

# Update 3: Edit directly
kubectl edit webapp mywebapp
# Change replicas from 3 to 4, save and exit

# Verify deployment updated
kubectl get deployment mywebapp -o jsonpath='{.spec.replicas}'
```

**Phase 4: Scale Resources**

```bash
# Scale using kubectl scale (if scale subresource enabled)
kubectl scale webapp mywebapp --replicas=6

# Verify scaling
kubectl get webapp mywebapp -o jsonpath='{.spec.replicas}'
kubectl get deployment mywebapp -o jsonpath='{.spec.replicas}'
kubectl get pods -l app=mywebapp

# Watch pods scale up
kubectl get pods -l app=mywebapp -w

# Scale down
kubectl scale webapp mywebapp --replicas=2

# Verify scale down
kubectl get pods -l app=mywebapp -w
```

**Phase 5: Delete Resources and Observe Cleanup**

```bash
# Before deleting, note what resources exist
echo "Resources before deletion:"
kubectl get webapp mywebapp
kubectl get deployment mywebapp
kubectl get service mywebapp
kubectl get pods -l app=mywebapp

# Delete custom resource
kubectl delete webapp mywebapp

# Watch operator clean up managed resources
kubectl get deployments -w &
kubectl get services -w &
kubectl get pods -l app=mywebapp -w

# Verify cleanup completed
echo "Resources after deletion:"
kubectl get webapp mywebapp
# Error: Not found (expected)

kubectl get deployment mywebapp
# Error: Not found (operator cleaned up)

kubectl get service mywebapp
# Error: Not found (operator cleaned up)

kubectl get pods -l app=mywebapp
# No resources found (operator cleaned up)
```

**Phase 6: Uninstall Operator Properly**

```bash
# Step 1: Ensure no custom resources remain
kubectl get webapps -A
# No resources found

# Step 2: Delete operator deployment
kubectl delete -f labs/operators/specs/ckad/simple-operator-deployment.yaml

# Verify operator pod is gone
kubectl get pods -l app=webapp-operator
# No resources found

# Step 3: Delete CRDs
kubectl delete -f labs/operators/specs/ckad/app-crd-with-subresources.yaml

# Verify CRD is gone
kubectl get crds webapps.apps.example.com
# Error: Not found

# Step 4: Delete RBAC
kubectl delete -f labs/operators/specs/ckad/simple-operator-rbac.yaml

# Verify RBAC is gone
kubectl get serviceaccount webapp-operator
# Error: Not found
kubectl get clusterrole webapp-operator
# Error: Not found
kubectl get clusterrolebinding webapp-operator
# Error: Not found

# Final verification - everything should be clean
kubectl get crds | grep webapp
kubectl get pods -l app=webapp-operator
kubectl get webapps -A
echo "Operator lifecycle complete - all resources cleaned up!"
```

**Lifecycle Summary:**
1. Install: CRD → RBAC → Operator
2. Use: Create CRs → Update CRs → Scale CRs
3. Uninstall: Delete CRs → Delete Operator → Delete CRD → Delete RBAC

</details>

### Exercise 5: Multi-Tenant Operator

Deploy operator in multi-tenant scenario:
1. Operator watches all namespaces
2. Create custom resources in different namespaces
3. Verify isolation between namespaces
4. Check RBAC permissions

<details>
  <summary>Solution</summary>

**Multi-Tenant Operator Deployment**

**Step 1: Create Namespaces for Different Tenants**

```bash
# Create tenant namespaces
kubectl apply -f labs/operators/specs/ckad/multi-tenant-namespaces.yaml

# Verify namespaces
kubectl get namespaces | grep tenant
# operator-system
# tenant-a
# tenant-b
# tenant-c
```

**Step 2: Install CRD (Cluster-Wide)**

```bash
# Install WebApp CRD (available cluster-wide)
kubectl apply -f labs/operators/specs/ckad/app-crd-with-subresources.yaml

# Verify CRD is available
kubectl api-resources | grep webapp
```

**Step 3: Deploy Operator in operator-system Namespace**

```bash
# Deploy operator RBAC (cluster-wide permissions)
kubectl apply -f labs/operators/specs/ckad/multi-tenant-namespace-operator.yaml

# Verify operator is running
kubectl get pods -n operator-system
kubectl wait --for=condition=Ready pod -l app=multitenant-operator -n operator-system --timeout=60s

# Check operator watches all namespaces
kubectl get deployment multitenant-operator -n operator-system -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="WATCH_NAMESPACE")].value}'
# Empty = watches all namespaces

# View operator logs
kubectl logs -n operator-system -l app=multitenant-operator
```

**Step 4: Create Custom Resources in Different Namespaces**

```bash
# Deploy WebApps for each tenant
kubectl apply -f labs/operators/specs/ckad/multi-tenant-webapps.yaml

# Verify custom resources in each namespace
kubectl get webapps -A
# NAMESPACE   NAME           DESIRED   CURRENT   READY   AGE
# tenant-a    tenant-a-app   2         0                 10s
# tenant-b    tenant-b-app   3         0                 10s
# tenant-c    tenant-c-app   1         0                 10s

# Check tenant-a resources
kubectl get webapps -n tenant-a
kubectl get all -n tenant-a

# Check tenant-b resources
kubectl get webapps -n tenant-b
kubectl get all -n tenant-b

# Check tenant-c resources
kubectl get webapps -n tenant-c
kubectl get all -n tenant-c
```

**Step 5: Verify Isolation Between Namespaces**

```bash
# Check that resources don't cross namespaces
kubectl get pods -n tenant-a
# Only tenant-a-app pods

kubectl get pods -n tenant-b
# Only tenant-b-app pods

kubectl get pods -n tenant-c
# Only tenant-c-app pods

# Verify services are namespaced
kubectl get services -n tenant-a
kubectl get services -n tenant-b
kubectl get services -n tenant-c

# Test cross-namespace access (should fail)
kubectl get webapp tenant-a-app -n tenant-b
# Error: Not found (correct - it's in tenant-a)

# Verify each tenant has isolated resources
echo "Tenant A resources:"
kubectl get all -n tenant-a
echo "Tenant B resources:"
kubectl get all -n tenant-b
echo "Tenant C resources:"
kubectl get all -n tenant-c
```

**Step 6: Check Operator RBAC Permissions**

```bash
# Operator needs cluster-wide permissions to watch all namespaces
kubectl get clusterrole multitenant-operator

# Check operator can create resources in any namespace
kubectl auth can-i create deployments --as system:serviceaccount:operator-system:multitenant-operator -n tenant-a
# yes

kubectl auth can-i create deployments --as system:serviceaccount:operator-system:multitenant-operator -n tenant-b
# yes

kubectl auth can-i create services --as system:serviceaccount:operator-system:multitenant-operator -n tenant-c
# yes

# Check operator can manage webapps cluster-wide
kubectl auth can-i get webapps --as system:serviceaccount:operator-system:multitenant-operator -A
# yes

# View complete permissions
kubectl describe clusterrole multitenant-operator
```

**Step 7: Test Tenant Operations**

```bash
# Scale tenant-a application
kubectl scale webapp tenant-a-app -n tenant-a --replicas=5

# Update tenant-b application
kubectl patch webapp tenant-b-app -n tenant-b --type=merge -p '{"spec":{"replicas":4}}'

# Delete and recreate tenant-c application
kubectl delete webapp tenant-c-app -n tenant-c
kubectl apply -f - <<EOF
apiVersion: apps.example.com/v1
kind: WebApp
metadata:
  name: tenant-c-app
  namespace: tenant-c
spec:
  replicas: 2
  image: nginx:1.25-alpine
  port: 80
EOF

# Verify operator handled all operations
kubectl logs -n operator-system -l app=multitenant-operator | tail -30

# Check all tenants are running correctly
kubectl get webapps -A
kubectl get pods -A | grep tenant
```

**Step 8: Cleanup Multi-Tenant Setup**

```bash
# Delete custom resources in all namespaces
kubectl delete webapps --all -n tenant-a
kubectl delete webapps --all -n tenant-b
kubectl delete webapps --all -n tenant-c

# Wait for operator to clean up managed resources
kubectl get all -n tenant-a
kubectl get all -n tenant-b
kubectl get all -n tenant-c

# Delete operator
kubectl delete deployment multitenant-operator -n operator-system

# Delete namespaces (this removes all resources in them)
kubectl delete namespace tenant-a tenant-b tenant-c operator-system

# Delete CRD and RBAC
kubectl delete crd webapps.apps.example.com
kubectl delete clusterrole multitenant-operator
kubectl delete clusterrolebinding multitenant-operator
```

**Key Multi-Tenant Concepts:**

1. **Operator Namespace**: Operator runs in dedicated namespace (operator-system)
2. **Watch All**: WATCH_NAMESPACE="" allows operator to watch all namespaces
3. **ClusterRole**: Operator needs cluster-wide permissions for multi-tenant operations
4. **Resource Isolation**: Each tenant's resources stay in their namespace
5. **Centralized Management**: Single operator manages resources across all namespaces
6. **RBAC Scope**: Operator has cluster-wide access but tenants are isolated

</details>

## Common CKAD Scenarios

### Scenario 1: Install and Configure Database Operator

**Task**: Deploy a PostgreSQL cluster using an operator with backup enabled.

<details>
  <summary>Solution</summary>

```bash
# Step 1: Install PostgreSQL CRD
kubectl apply -f labs/operators/specs/ckad/postgres-operator-crd.yaml

# Verify CRD
kubectl get crds postgresclusters.postgres.example.com
kubectl explain postgrescluster.spec

# Step 2: Create PostgreSQL cluster
kubectl apply -f labs/operators/specs/ckad/postgres-cluster.yaml

# Step 3: Verify custom resource
kubectl get postgrescluster production-db
kubectl describe postgrescluster production-db

# Step 4: Check what operator would create (simulated)
# In a real operator deployment, these would be created:
# - StatefulSet for postgres pods
# - Services for database access
# - ConfigMaps for configuration
# - Secrets for passwords
# - PersistentVolumeClaims for storage
# - CronJob for backups

echo "Expected resources:"
echo "StatefulSet: production-db-postgres (3 replicas)"
echo "Service: production-db (headless)"
echo "Service: production-db-loadbalancer"
echo "ConfigMap: production-db-config"
echo "Secret: production-db-credentials"
echo "PVC: data-production-db-postgres-0"
echo "PVC: data-production-db-postgres-1"
echo "PVC: data-production-db-postgres-2"
echo "CronJob: production-db-backup"

# Step 5: Query database cluster status
kubectl get postgrescluster production-db -o jsonpath='{.spec}' | jq
kubectl get postgrescluster production-db -o jsonpath='{.status}' | jq

# Step 6: Scale database cluster
kubectl patch postgrescluster production-db --type=merge -p '{"spec":{"replicas":5}}'

# Step 7: Update backup schedule
kubectl patch postgrescluster production-db --type=merge -p '
{
  "spec": {
    "backup": {
      "schedule": "0 3 * * *",
      "retention": 14
    }
  }
}'

# Step 8: Cleanup
kubectl delete postgrescluster production-db
kubectl delete crd postgresclusters.postgres.example.com
```

</details>

### Scenario 2: Debug Failing Custom Resource

**Task**: A PostgreSQL cluster fails to create with validation errors. Identify and fix the issues.

<details>
  <summary>Solution</summary>

```bash
# Step 1: Try to create broken database cluster
kubectl apply -f labs/operators/specs/ckad/postgres-cluster-broken.yaml

# Step 2: Check for validation errors
# Error 1: Invalid cron schedule
# Error 2: Retention exceeds maximum (90)
# Error 3: Storage class doesn't exist

# Step 3: View the broken resource
kubectl get -f labs/operators/specs/ckad/postgres-cluster-broken.yaml -o yaml

# Step 4: Identify issues
echo "Issues found:"
echo "1. schedule: 'invalid-cron' - not a valid cron expression"
echo "2. retention: 100 - exceeds maximum of 90"
echo "3. storageClass: 'nonexistent-storage-class' - doesn't exist"
echo "4. size: 1Gi - too small for production database"

# Step 5: Create fixed version
cat <<EOF | kubectl apply -f -
apiVersion: postgres.example.com/v1
kind: PostgresCluster
metadata:
  name: fixed-db
  namespace: default
spec:
  version: "15"
  replicas: 3
  storage:
    size: 100Gi
    storageClass: standard  # Use existing storage class
  backup:
    enabled: true
    schedule: "0 2 * * *"  # Valid cron: 2 AM daily
    retention: 7  # Within allowed range (1-90)
  monitoring:
    enabled: true
EOF

# Step 6: Verify fixed version
kubectl get postgrescluster fixed-db
kubectl describe postgrescluster fixed-db

# Step 7: Check validation passed
kubectl get postgrescluster fixed-db -o jsonpath='{.spec}' | jq

# Step 8: Cleanup
kubectl delete postgrescluster fixed-db
kubectl delete crd postgresclusters.postgres.example.com
```

**Debugging Steps Used:**
1. Read error message carefully
2. Check CRD validation rules with `kubectl explain`
3. Verify referenced resources exist (storage classes)
4. Test with corrected values
5. Validate against schema requirements

</details>

### Scenario 3: Upgrade Application via Operator

**Task**: Upgrade a PostgreSQL cluster from version 15 to version 16 using the operator.

<details>
  <summary>Solution</summary>

```bash
# Step 1: Deploy PostgreSQL operator CRD
kubectl apply -f labs/operators/specs/ckad/postgres-operator-crd.yaml

# Step 2: Create initial cluster (version 15)
cat <<EOF | kubectl apply -f -
apiVersion: postgres.example.com/v1
kind: PostgresCluster
metadata:
  name: upgrade-demo
  namespace: default
spec:
  version: "15"  # Initial version
  replicas: 3
  storage:
    size: 100Gi
    storageClass: standard
  backup:
    enabled: true
    schedule: "0 2 * * *"
    retention: 7
EOF

# Step 3: Verify current version
kubectl get postgrescluster upgrade-demo -o jsonpath='{.spec.version}'
# Output: 15

# Step 4: Check current status
kubectl describe postgrescluster upgrade-demo
# Note the current phase/status

# Step 5: Perform upgrade (update version to 16)
kubectl apply -f labs/operators/specs/ckad/postgres-cluster-upgrade.yaml

# OR use patch:
kubectl patch postgrescluster upgrade-demo --type=merge -p '{"spec":{"version":"16"}}'

# Step 6: Watch operator perform upgrade
kubectl get postgrescluster upgrade-demo -w

# In a real operator, this would:
# 1. Set status to "Upgrading"
# 2. Drain connections from old version
# 3. Take backup before upgrade
# 4. Update StatefulSet with new image
# 5. Perform rolling update
# 6. Run post-upgrade tasks
# 7. Update status to "Running"

# Step 7: Verify upgrade completed
kubectl get postgrescluster upgrade-demo -o jsonpath='{.spec.version}'
# Output: 16

kubectl get postgrescluster upgrade-demo -o jsonpath='{.status.phase}'
# Output: Running (in real operator)

# Step 8: Check upgrade history
kubectl describe postgrescluster upgrade-demo
# Look for events showing upgrade process

# Step 9: Rollback if needed (downgrade to version 15)
kubectl patch postgrescluster upgrade-demo --type=merge -p '{"spec":{"version":"15"}}'

# Step 10: Cleanup
kubectl delete postgrescluster upgrade-demo
kubectl delete crd postgresclusters.postgres.example.com
```

**Upgrade Best Practices:**
1. Always backup before upgrading
2. Test upgrade in non-production first
3. Review operator's upgrade documentation
4. Monitor status during upgrade
5. Have rollback plan ready
6. Check application compatibility with new version

</details>

### Scenario 4: Backup and Restore with Operator

**Task**: Use an operator to create a database backup and perform a restore operation.

<details>
  <summary>Solution</summary>

```bash
# Step 1: Install CRDs
kubectl apply -f labs/operators/specs/ckad/postgres-operator-crd.yaml
kubectl apply -f labs/operators/specs/ckad/backup-crd.yaml
kubectl apply -f labs/operators/specs/ckad/restore-crd.yaml

# Step 2: Create PostgreSQL cluster
kubectl apply -f labs/operators/specs/ckad/postgres-cluster.yaml

# Verify database is running
kubectl get postgrescluster production-db
kubectl describe postgrescluster production-db

# Step 3: Create manual backup
kubectl apply -f labs/operators/specs/ckad/database-backup.yaml

# Step 4: Check backup status
kubectl get databasebackup production-db-backup
kubectl describe databasebackup production-db-backup

# Watch backup progress
kubectl get databasebackup production-db-backup -o jsonpath='{.status.phase}'
# Pending → Running → Completed

# Check backup details
kubectl get databasebackup production-db-backup -o jsonpath='{.status}' | jq
# {
#   "phase": "Completed",
#   "startTime": "2024-01-15T02:00:00Z",
#   "completionTime": "2024-01-15T02:15:00Z",
#   "backupSize": "1.2Gi",
#   "message": "Backup completed successfully"
# }

# Step 5: List all backups
kubectl get databasebackups
kubectl get databasebackups -o custom-columns=\
NAME:.metadata.name,\
DATABASE:.spec.databaseRef.name,\
TYPE:.spec.backupType,\
STATUS:.status.phase,\
SIZE:.status.backupSize

# Step 6: Simulate data loss - delete and recreate database
kubectl delete postgrescluster production-db
# Wait for deletion to complete
sleep 10

# Step 7: Perform restore
kubectl apply -f labs/operators/specs/ckad/database-restore.yaml

# Step 8: Monitor restore progress
kubectl get databaserestore restore-production-db
kubectl describe databaserestore restore-production-db

# Watch restore status
kubectl get databaserestore restore-production-db -o jsonpath='{.status.phase}' -w
# Pending → Restoring → Completed

# Check restore details
kubectl get databaserestore restore-production-db -o jsonpath='{.status}' | jq
# {
#   "phase": "Completed",
#   "startTime": "2024-01-15T10:00:00Z",
#   "completionTime": "2024-01-15T10:20:00Z",
#   "message": "Database restored successfully from backup production-db-backup"
# }

# Step 9: Verify database restored
kubectl get postgrescluster production-db
kubectl describe postgrescluster production-db

# Step 10: Create backup schedule (automated backups)
kubectl patch postgrescluster production-db --type=merge -p '
{
  "spec": {
    "backup": {
      "enabled": true,
      "schedule": "0 2 * * *",
      "retention": 30
    }
  }
}'

# In a real operator, this would create a CronJob:
# - Runs daily at 2 AM
# - Creates DatabaseBackup resource automatically
# - Retains backups for 30 days
# - Prunes old backups

# Step 11: Point-in-time restore (advanced)
kubectl apply -f - <<EOF
apiVersion: backup.example.com/v1
kind: DatabaseRestore
metadata:
  name: pitr-restore
spec:
  databaseRef:
    name: production-db
  backupRef:
    name: production-db-backup
  pointInTime: "2024-01-15T14:30:00Z"  # Specific timestamp
EOF

# Step 12: Cleanup
kubectl delete databaserestore restore-production-db pitr-restore
kubectl delete databasebackup production-db-backup
kubectl delete postgrescluster production-db
kubectl delete crd postgresclusters.postgres.example.com
kubectl delete crd databasebackups.backup.example.com
kubectl delete crd databaserestores.backup.example.com
```

**Backup/Restore Best Practices:**
1. Test restore procedures regularly
2. Store backups in different location than primary data
3. Automate backups with schedules
4. Monitor backup completion and success
5. Document restore procedures
6. Verify backup integrity
7. Implement retention policies
8. Use point-in-time recovery when available

</details>

## Best Practices for CKAD

1. **Understanding Operators**
   - Know that operators = CRDs + controllers
   - Understand operators don't replace Kubernetes resources, they manage them
   - Operators are useful for complex stateful applications

2. **Working with CRDs**
   - Always check if CRD is installed before creating resources
   - Use `kubectl explain` to understand CRD fields
   - Check validation errors carefully

3. **Troubleshooting**
   - Start with operator logs
   - Check RBAC permissions
   - Verify CRDs are installed and correct version
   - Look at events for custom resources

4. **Resource Management**
   - Operators create many resources - use labels to track them
   - Clean up custom resources before uninstalling operator
   - Delete in correct order (resources → operator → CRDs)

5. **Production Use**
   - Always review operator's RBAC requirements
   - Monitor operator pod health
   - Understand what objects operator manages
   - Have rollback plan

## Quick Reference Commands

```bash
# CRDs
kubectl get crds
kubectl describe crd <name>
kubectl explain <crd-name>.spec
kubectl delete crd <name>

# Custom Resources
kubectl get <resource-type>
kubectl get <resource-type> -A
kubectl describe <resource-type> <name>
kubectl delete <resource-type> <name>

# Operators
kubectl get pods -l app=operator
kubectl logs -l app=operator -f
kubectl describe deployment operator

# RBAC
kubectl get serviceaccount <sa-name> -o yaml
kubectl get clusterrole <role-name> -o yaml
kubectl auth can-i <verb> <resource> --as system:serviceaccount:<namespace>:<sa-name>

# Troubleshooting
kubectl get events --sort-by='.lastTimestamp'
kubectl get events --field-selector involvedObject.name=<name>
kubectl get all -l <label-selector>

# API Resources
kubectl api-resources --api-group=<group>
kubectl api-versions | grep <group>
```

## Cleanup

```bash
# Delete custom resources
kubectl delete <resource-type> --all

# Delete operator
kubectl delete deployment <operator-name>

# Delete CRDs
kubectl delete crd <crd-name>

# Delete RBAC
kubectl delete serviceaccount,clusterrole,clusterrolebinding -l app=operator
```

---

## Next Steps

After mastering Operators and Custom Resources, continue with these CKAD topics:
- [Helm](../helm/CKAD.md) - Package management and templating
- [RBAC](../rbac/CKAD.md) - Advanced authorization
- [Admission Controllers](../admission/CKAD.md) - Policy enforcement
- [API Extensions](../api-extensions/CKAD.md) - Advanced cluster extensions
