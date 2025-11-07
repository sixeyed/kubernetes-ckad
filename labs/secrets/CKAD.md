# Secrets - CKAD Exam Topics

This document covers the CKAD exam requirements for Kubernetes Secrets. Make sure you've completed the [basic Secrets lab](README.md) first, as it covers fundamental concepts of creating and using Secrets.

## CKAD Secrets Requirements

The CKAD exam expects you to understand and work with:

- Imperative Secret creation (literals, files, env-files)
- Declarative Secret creation (YAML)
- Different Secret types (Opaque, docker-registry, TLS, etc.)
- Using Secrets as environment variables (env and envFrom)
- Using Secrets as volume mounts
- Managing Secret updates and triggering rollouts
- imagePullSecrets for private registries
- Security best practices and troubleshooting

## API Specs

- [Secret](https://kubernetes.io/docs/reference/kubernetes-api/config-and-storage-resources/secret-v1/)
- [ServiceAccount](https://kubernetes.io/docs/reference/kubernetes-api/authentication-resources/service-account-v1/)

## Imperative Secret Creation

In the CKAD exam, you'll often create Secrets imperatively for speed. Understanding all the creation methods is critical.

### From Literal Values

```
# Create from single literal
kubectl create secret generic my-secret --from-literal=password=mysecretpass

# Create from multiple literals
kubectl create secret generic my-secret \
  --from-literal=username=admin \
  --from-literal=password=secretpass123 \
  --from-literal=database=mydb

# Verify creation
kubectl get secret my-secret
kubectl describe secret my-secret
```

### From Files

```
# Create from single file (key = filename, value = file contents)
kubectl create secret generic app-config --from-file=config.json

# Create from multiple files
kubectl create secret generic app-secrets \
  --from-file=./secrets/cert.pem \
  --from-file=./secrets/key.pem

# Create with custom key name
kubectl create secret generic tls-certs \
  --from-file=certificate=./cert.pem \
  --from-file=private-key=./key.pem
```

### From Env Files

```
# Create from env file (each line becomes a key-value pair)
kubectl create secret generic db-config --from-env-file=database.env

# Example database.env content:
# DB_HOST=postgres.example.com
# DB_PORT=5432
# DB_USER=appuser
# DB_PASSWORD=secretpass
```

### Exam Tip: Dry Run for YAML

Generate Secret YAML without creating it:

```
kubectl create secret generic my-secret \
  --from-literal=key1=value1 \
  --from-literal=key2=value2 \
  --dry-run=client -o yaml > secret.yaml

# Edit if needed, then apply
kubectl apply -f secret.yaml
```

See complete examples: [`specs/ckad/secret-types.yaml`](specs/ckad/secret-types.yaml)

**Practice exercise**:

```bash
# Create secrets using different methods
kubectl create secret generic literal-secret --from-literal=password=secret123
kubectl create secret generic file-secret --from-file=./tls.crt
echo -e "USER=admin\nPASS=secret" > creds.env
kubectl create secret generic env-secret --from-env-file=creds.env

# Verify all were created
kubectl get secrets | grep secret

# Compare the structure
kubectl get secret literal-secret -o yaml
kubectl get secret file-secret -o yaml
kubectl get secret env-secret -o yaml

# Decode values
kubectl get secret literal-secret -o jsonpath='{.data.password}' | base64 -d
kubectl get secret env-secret -o jsonpath='{.data.USER}' | base64 -d

# Cleanup
kubectl delete secret literal-secret file-secret env-secret
rm creds.env
```

## Secret Types

Kubernetes supports multiple Secret types for different use cases. The `type` field is metadata that helps validate content and provides usage hints.

### Opaque Secrets (default)

Default type for arbitrary key-value data:

```
kubectl create secret generic my-secret --from-literal=key=value
```

See: [`specs/ckad/secret-types.yaml`](specs/ckad/secret-types.yaml) - includes Opaque secret examples.

**Opaque secret YAML structure**:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
type: Opaque  # Default type
data:
  # Base64-encoded values
  username: YWRtaW4=  # "admin"
  password: c2VjcmV0MTIz  # "secret123"
stringData:
  # Plain text values (automatically base64-encoded)
  api-key: "my-api-key-12345"
  database-url: "postgres://user:pass@db.example.com:5432/mydb"
```

```bash
# Decode secret values
kubectl get secret my-secret -o jsonpath='{.data.username}' | base64 -d
# Output: admin

# View all keys
kubectl get secret my-secret -o jsonpath='{.data}' | jq 'keys'
```

### Docker Registry Secrets

For pulling images from private registries:

```
kubectl create secret docker-registry regcred \
  --docker-server=https://registry.example.com \
  --docker-username=myuser \
  --docker-password=mypassword \
  --docker-email=user@example.com

# View the generated secret
kubectl get secret regcred -o yaml
```

Use in Pod spec:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: private-app
spec:
  containers:
  - name: app
    image: registry.example.com/myapp:v1
  imagePullSecrets:
  - name: regcred
```

See complete examples: [`specs/ckad/imagepullsecrets.yaml`](specs/ckad/imagepullsecrets.yaml)

This file includes:
- Docker registry secret creation (imperative and declarative)
- Pod using imagePullSecrets
- Deployment with multiple registry secrets
- ServiceAccount with automatic imagePullSecrets
- Examples for Docker Hub, GCR, ECR, ACR, Harbor

**Exercise: Using private registry secrets**:

```bash
# 1. Create docker-registry secret
kubectl create secret docker-registry my-registry \
  --docker-server=registry.example.com \
  --docker-username=myuser \
  --docker-password=mypassword \
  --docker-email=user@example.com

# 2. Use in Pod (will attempt to pull from private registry)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: private-image-pod
spec:
  containers:
  - name: app
    image: registry.example.com/myapp:v1
  imagePullSecrets:
  - name: my-registry
EOF

# 3. Troubleshoot if image pull fails
kubectl describe pod private-image-pod | grep -A 10 Events
# Look for: ImagePullBackOff, ErrImagePull
# Common issues:
# - Wrong credentials
# - Wrong registry URL
# - Secret not in same namespace
# - Image doesn't exist

# Verify secret is correct
kubectl get secret my-registry -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq

# Cleanup
kubectl delete pod private-image-pod
kubectl delete secret my-registry
```

### TLS Secrets

For storing TLS certificates and keys:

```
# Create from certificate files
kubectl create secret tls my-tls-cert \
  --cert=path/to/cert.pem \
  --key=path/to/key.pem

# View structure
kubectl get secret my-tls-cert -o yaml
```

The TLS Secret type automatically validates that `tls.crt` and `tls.key` fields are present.

See complete examples: [`specs/ckad/tls-certificates.yaml`](specs/ckad/tls-certificates.yaml)

This file includes:
- TLS secret for Ingress
- Self-signed certificate example
- Mutual TLS (mTLS) with client certificates
- Certificate rotation examples

**Exercise: TLS certificates**:

```bash
# 1. Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=myapp.example.com/O=myorg"

# 2. Create TLS secret
kubectl create secret tls myapp-tls \
  --cert=tls.crt \
  --key=tls.key

# Verify structure
kubectl get secret myapp-tls -o yaml
# Shows: tls.crt and tls.key fields (both base64-encoded)

# 3. Use in Ingress (see ingress lab for complete setup)
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
spec:
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-tls  # References TLS secret
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-service
            port:
              number: 80
EOF

# Verify TLS is configured
kubectl describe ingress myapp-ingress | grep TLS
# TLS: myapp-tls terminates myapp.example.com

# Cleanup
kubectl delete ingress myapp-ingress
kubectl delete secret myapp-tls
rm tls.crt tls.key
```

### ServiceAccount Token Secrets

ServiceAccount tokens can be stored as Secrets (though in newer Kubernetes versions, these are auto-projected):

```
# ServiceAccount automatically gets a Secret
kubectl create serviceaccount my-sa

kubectl get sa my-sa -o yaml
kubectl get secrets
```

**ServiceAccount tokens**:

- **Legacy behavior** (< Kubernetes 1.24): ServiceAccounts automatically created non-expiring token Secrets
- **Current behavior** (≥ 1.24): Tokens are auto-projected into Pods as volumes with expiration
- **Manual token creation**: Use `kubectl create token my-sa` for short-lived tokens
- **When to manually create token Secrets**: For long-lived tokens (CI/CD, external integrations), though this is discouraged

```bash
# Create long-lived token Secret (legacy)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: my-sa-token
  annotations:
    kubernetes.io/service-account.name: my-sa
type: kubernetes.io/service-account-token
EOF

# Token is automatically populated by Kubernetes
kubectl get secret my-sa-token -o jsonpath='{.data.token}' | base64 -d
```

### Basic Auth Secrets

For HTTP basic authentication:

```bash
kubectl create secret generic basic-auth \
  --from-literal=username=admin \
  --from-literal=password=secretpass \
  --type=kubernetes.io/basic-auth
```

See: [`specs/ckad/secret-types.yaml`](specs/ckad/secret-types.yaml) for basic-auth examples.

**Usage with Ingress annotations**:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: protected-app
  annotations:
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: basic-auth
    nginx.ingress.kubernetes.io/auth-realm: "Authentication Required"
spec:
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp
            port:
              number: 80
```

### SSH Auth Secrets

For SSH private keys:

```bash
kubectl create secret generic ssh-key \
  --from-file=ssh-privatekey=~/.ssh/id_rsa \
  --type=kubernetes.io/ssh-auth
```

**Usage for git operations**:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: git-clone-pod
spec:
  containers:
  - name: git
    image: alpine/git
    command:
    - sh
    - -c
    - |
      mkdir -p ~/.ssh
      cp /ssh-keys/ssh-privatekey ~/.ssh/id_rsa
      chmod 600 ~/.ssh/id_rsa
      ssh-keyscan github.com >> ~/.ssh/known_hosts
      git clone git@github.com:user/private-repo.git /workspace
      ls -la /workspace
    volumeMounts:
    - name: ssh-keys
      mountPath: /ssh-keys
      readOnly: true
  volumes:
  - name: ssh-keys
    secret:
      secretName: ssh-key
      defaultMode: 0400
```

## Using Secrets in Pods

### As Environment Variables

#### Using envFrom (all keys)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-secrets
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'env']
    envFrom:
    - secretRef:
        name: my-secret
```

All keys from the Secret become environment variables.

#### Using env (specific keys)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-secrets
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'echo $DB_PASSWORD']
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: password
    - name: DB_USER
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: username
```

Only specified keys are loaded, and you can rename them.

See complete examples: [`specs/ckad/consume-secrets.yaml`](specs/ckad/consume-secrets.yaml)

This file includes 10 methods for consuming secrets, including all environment variable patterns.

**Exercise: Secret consumption with environment variables**:

```bash
# 1. Create multi-key secret
kubectl create secret generic db-config \
  --from-literal=DB_HOST=postgres.example.com \
  --from-literal=DB_PORT=5432 \
  --from-literal=DB_USER=appuser \
  --from-literal=DB_PASS=secret123

# 2. Pod using envFrom (all keys)
kubectl run pod-envfrom --image=busybox --command -- sh -c "env | grep DB_ && sleep 3600" \
  --dry-run=client -o yaml | \
  kubectl patch -f - --local --type=json -p='[{"op":"add","path":"/spec/containers/0/envFrom","value":[{"secretRef":{"name":"db-config"}}]}]' -o yaml | \
  kubectl apply -f -

# 3. Pod with specific keys
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pod-specific-keys
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'env | grep DATABASE && sleep 3600']
    env:
    - name: DATABASE_HOST
      valueFrom:
        secretKeyRef:
          name: db-config
          key: DB_HOST
    - name: DATABASE_PASSWORD  # Renamed from DB_PASS
      valueFrom:
        secretKeyRef:
          name: db-config
          key: DB_PASS
EOF

# 4. Verify environment variables
kubectl exec pod-envfrom -- env | grep DB_
kubectl exec pod-specific-keys -- env | grep DATABASE

# Cleanup
kubectl delete pod pod-envfrom pod-specific-keys
kubectl delete secret db-config
```

### As Volume Mounts

Mounting Secrets as files in containers:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-secret-volume
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'cat /etc/secrets/config.json']
    volumeMounts:
    - name: secret-volume
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secret-volume
    secret:
      secretName: app-config
```

Each key in the Secret becomes a file in the mount directory.

#### Mounting Specific Keys

```yaml
volumes:
- name: secret-volume
  secret:
    secretName: app-config
    items:
    - key: config.json
      path: application-config.json
    - key: database.conf
      path: db/database.conf
```

You can:
- Select specific keys to mount
- Rename files (key -> path)
- Set custom file permissions

See: [`specs/ckad/consume-secrets.yaml`](specs/ckad/consume-secrets.yaml) - Methods 5-10 cover volume mounting.

**Exercise: Secret volume mounts with permissions**:

```bash
# Deploy examples from consume-secrets.yaml
kubectl apply -f labs/secrets/specs/ckad/consume-secrets.yaml

# Check pod with entire secret mounted
kubectl exec app-volume-all -- ls -la /secrets/

# Check pod with selective keys and custom permissions
kubectl exec app-volume-selective -- ls -la /config/
kubectl exec app-volume-selective -- stat -c "%a %n" /config/db-pass

# Check pod with custom default mode
kubectl exec app-volume-permissions -- ls -la /secrets/

# Cleanup
kubectl delete -f labs/secrets/specs/ckad/consume-secrets.yaml
```

## Managing Secret Updates

### Understanding Update Behavior

**Environment Variables**: Static for Pod lifetime - never update even if Secret changes

**Volume Mounts**: Kubernetes updates them automatically (with cache delay), but apps may not reload

From the basic lab, you learned about hot reloads and manual rollouts. Here are CKAD-specific patterns:

### Pattern 1: Annotation-Based Updates

Force Deployment rollout when Secret changes by updating Pod template metadata:

**Annotation approach example**:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    metadata:
      annotations:
        config-version: "v1"  # Change this to trigger rollout
    spec:
      containers:
      - name: app
        image: myapp:latest
        envFrom:
        - secretRef:
            name: app-secret
```

**Exercise: Trigger rollout with annotation change**:

```bash
# 1. Create secret and deployment with annotation
kubectl create secret generic app-secret --from-literal=API_KEY=initial-key
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
      annotations:
        secret-version: "v1"  # This triggers rollouts
    spec:
      containers:
      - name: app
        image: busybox
        command: ['sh', '-c', 'echo API_KEY=\$API_KEY && sleep 3600']
        envFrom:
        - secretRef:
            name: app-secret
EOF

# 2. Update Secret
kubectl create secret generic app-secret --from-literal=API_KEY=updated-key --dry-run=client -o yaml | kubectl apply -f -

# 3. Update annotation to trigger rollout
kubectl patch deployment myapp -p '{"spec":{"template":{"metadata":{"annotations":{"secret-version":"v2"}}}}}'

# 4. Watch rollout
kubectl rollout status deployment myapp

# 5. Verify new secret value
kubectl exec deployment/myapp -- printenv API_KEY
# Output: updated-key

# Rollback if needed
kubectl rollout undo deployment myapp
kubectl rollout status deployment myapp

# Cleanup
kubectl delete deployment myapp
kubectl delete secret app-secret
```

### Pattern 2: Immutable Secrets with Versioned Names

Create new Secret with version suffix instead of updating:

**Versioned secrets example**:

```bash
# Pattern 2: Immutable versioned secrets
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: app-secret-v1
immutable: true
data:
  API_KEY: aW5pdGlhbC1rZXk=  # initial-key
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-versioned
spec:
  replicas: 2
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
        image: busybox
        command: ['sh', '-c', 'echo API_KEY=\$API_KEY && sleep 3600']
        envFrom:
        - secretRef:
            name: app-secret-v1
EOF

# To update: Create v2 and update deployment
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: app-secret-v2
immutable: true
data:
  API_KEY: dXBkYXRlZC1rZXk=  # updated-key
EOF

kubectl set env deployment/myapp-versioned --from=secret/app-secret-v2 --overwrite
# Automatic rollout triggered
```

**Pattern comparison**:

| Pattern | Pros | Cons |
|---------|------|------|
| **Annotation-based** | Same Secret name; simpler rollback | Manual annotation update needed; Secret is mutable |
| **Versioned names** | Immutable; explicit versions; easy rollback | More Secrets to manage; cleanup needed |

**Best practice**: Use versioned immutable Secrets for production.

### Immutable Secrets (Kubernetes 1.21+)

Mark Secrets as immutable for security and performance:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: immutable-secret
data:
  key: dmFsdWU=
immutable: true
```

Benefits:
- Prevents accidental updates
- Improves performance (Kubernetes doesn't watch for changes)
- Must delete and recreate to update

**Exercise: Immutable secrets**:

```bash
# Create immutable secret
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: immutable-secret
immutable: true
data:
  key: dmFsdWU=  # "value"
EOF

# Try to update (will fail)
kubectl patch secret immutable-secret -p '{"data":{"key":"bmV3dmFsdWU="}}'
# Error: field is immutable

# Must delete and recreate
kubectl delete secret immutable-secret
kubectl create secret generic immutable-secret --from-literal=key=newvalue
kubectl patch secret immutable-secret -p '{"immutable":true}'
```

## Security Best Practices

### Encoding vs Encryption

**Critical Understanding**: Base64 encoding is NOT encryption!

```
# Anyone with kubectl access can decode Secrets
kubectl get secret my-secret -o jsonpath='{.data.password}' | base64 -d
```

### 1. Encryption at Rest

```bash
# etcd encryption must be configured on control plane
# Cloud providers (EKS, AKS, GKE) enable encryption by default
# Verify with cluster admin tools

# For self-managed clusters, create EncryptionConfiguration
# See: https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/
```

### 2. RBAC for Secrets

```yaml
# Role that DENIES secret access (deny pattern)
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: no-secrets-access
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch", "create", "update"]
# Secrets intentionally omitted

---
# Role for SECRET MANAGEMENT ONLY
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secrets-manager
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch", "create", "update", "delete"]
```

See [RBAC lab](../rbac/README.md) for complete access control examples.

### 3. External Secret Management

**Out of CKAD scope**, but important for production:
- **External Secrets Operator**: Syncs secrets from external systems
- **HashiCorp Vault**: Enterprise secret management
- **Cloud providers**: AWS Secrets Manager, Azure Key Vault, GCP Secret Manager
- **Sealed Secrets**: Encrypted secrets safe for Git commits

### 4. Avoiding Secrets in Git

```bash
# NEVER commit Secrets to Git, even base64-encoded
echo "*.secret.yaml" >> .gitignore
echo "secrets/" >> .gitignore

# Use GitOps-safe approaches:
# - Sealed Secrets (encrypts for specific cluster)
# - External Secrets Operator
# - Secret references only, create manually per environment
```

## Troubleshooting Secrets

### Common Issues

**1. Secret Not Found**

```
# Check Secret exists
kubectl get secret my-secret

# Check namespace
kubectl get secret my-secret -n correct-namespace

# Pod must be in same namespace as Secret
kubectl get pods -o wide
```

**Troubleshooting exercise**: Deploy the broken specs from [`specs/ckad/exercises/ex1-complete-secrets.yaml`](specs/ckad/exercises/ex1-complete-secrets.yaml) and fix common issues using `kubectl describe` and `kubectl logs`.

**2. Decoding Base64 Values**

```
# View Secret data (encoded)
kubectl get secret my-secret -o yaml

# Decode specific key
kubectl get secret my-secret -o jsonpath='{.data.password}' | base64 -d

# Decode all keys
kubectl get secret my-secret -o json | jq -r '.data | map_values(@base64d)'
```

**3. Pod Fails to Start**

```
# Check events
kubectl describe pod myapp

# Common errors:
# - "secret 'my-secret' not found"
# - "key 'password' not found in secret 'my-secret'"

# Verify Secret has required keys
kubectl describe secret my-secret
```

**Comprehensive troubleshooting checklist**:
1. Verify Secret exists: `kubectl get secret <name>`
2. Check namespace: Secrets must be in same namespace as Pod
3. Verify Secret keys: `kubectl describe secret <name>`
4. Check Pod events: `kubectl describe pod <name> | grep Events -A 20`
5. Restart Pod after Secret creation: `kubectl delete pod <name>`
6. For volume mounts: Check mountPath and verify files exist inside container

**4. Environment Variables Not Set**

```
# Check if Secret is loaded
kubectl exec myapp -- env | grep PASSWORD

# Common issues:
# - Wrong secret name in secretRef/secretKeyRef
# - Wrong key name in secretKeyRef
# - Pod not restarted after Secret creation
```

**5. Volume Mount Issues**

```
# Check if volume is mounted
kubectl exec myapp -- ls /etc/secrets

# Check file contents
kubectl exec myapp -- cat /etc/secrets/config.json

# Check permissions
kubectl exec myapp -- ls -la /etc/secrets

# Common issues:
# - Wrong mountPath
# - Volume not defined in Pod spec
# - Items reference non-existent keys
```

**Debugging decision tree**:
```
Pod not starting? → Check: kubectl describe pod → Secret not found? → Create Secret
                                                → Wrong key? → Fix secretKeyRef
                                                → Wrong namespace? → Check namespaces

Env vars empty? → Check: kubectl exec pod -- env → Wrong secretRef → Fix spec
                                                  → Pod created before Secret → Restart Pod

Files missing? → Check: kubectl exec pod -- ls /mount → Wrong mountPath → Fix volumeMounts
                                                        → Items not found → Check Secret keys
```

## Using Secrets with ServiceAccounts

ServiceAccounts can automatically mount Secrets as imagePullSecrets:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: myapp-sa
imagePullSecrets:
- name: regcred

---
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  serviceAccountName: myapp-sa
  containers:
  - name: app
    image: registry.example.com/myapp:v1
```

The Pod automatically gets access to the registry Secret through the ServiceAccount.

See: [`specs/ckad/imagepullsecrets.yaml`](specs/ckad/imagepullsecrets.yaml) - Method 4 demonstrates ServiceAccount with imagePullSecrets.

**Quick exercise**: Create ServiceAccount with registry secret and use in multiple Pods:

```bash
kubectl create secret docker-registry regcred --docker-server=registry.example.com --docker-username=user --docker-password=pass
kubectl create serviceaccount myapp-sa
kubectl patch serviceaccount myapp-sa -p '{"imagePullSecrets":[{"name":"regcred"}]}'
kubectl run pod1 --image=registry.example.com/app:v1 --serviceaccount=myapp-sa
kubectl run pod2 --image=registry.example.com/app:v2 --serviceaccount=myapp-sa
# Both pods automatically use regcred
```

## CKAD Exam Tips

### Speed Commands

```
# Quick Secret creation
kubectl create secret generic db-creds --from-literal=user=admin --from-literal=pass=secret

# Generate YAML
kubectl create secret generic my-secret --from-literal=key=value --dry-run=client -o yaml

# View decoded data quickly
kubectl get secret my-secret -o jsonpath='{.data.password}' | base64 -d

# Create from file and view
kubectl create secret generic config --from-file=app.conf --dry-run=client -o yaml

# Test Secret in Pod quickly
kubectl run test --rm -it --image=busybox --restart=Never -- env | grep KEY
```

### Common Patterns

**Pattern: Secret → Environment Variable**
```
kubectl create secret generic db --from-literal=password=secret123
kubectl run myapp --image=myapp:v1 --env="DB_PASS=value"  # Won't work with secretKeyRef imperatively
# Must use YAML for secretKeyRef
```

**Pattern: Quick Test Pod with Secret**
```yaml
kubectl run test --image=busybox -it --rm --restart=Never -- sh
# Then manually create with secretRef added
```

**Practice scenarios**: See [`specs/ckad/exercises/ex1-complete-secrets.yaml`](specs/ckad/exercises/ex1-complete-secrets.yaml) for a comprehensive exercise using all Secret patterns (Opaque, docker-registry, TLS) in a single multi-container application.

## Lab Challenge: Multi-Tier Application with Secrets

Build a complete application demonstrating all Secret patterns:

### Requirements

1. **Database Tier**
   - StatefulSet with MySQL/PostgreSQL
   - Root password from Secret (environment variable)
   - TLS certificates mounted as volumes
   - Custom database config file from Secret

2. **Backend API Tier**
   - Deployment with 2 replicas
   - Database connection string from Secret
   - API keys as environment variables
   - JWT signing key mounted as file
   - Pull from private registry (imagePullSecret)

3. **Frontend Tier**
   - Deployment with 3 replicas
   - Backend API URL from ConfigMap (not Secret)
   - Feature flags from environment
   - TLS certificates for HTTPS

4. **Configuration Updates**
   - Update database password
   - Trigger rolling update using annotation pattern
   - Update API key using versioned Secret name
   - Verify zero-downtime updates

5. **Troubleshooting Tasks**
   - Fix Pod with wrong Secret reference
   - Debug environment variable not appearing
   - Resolve namespace mismatch
   - Fix file permission issue in volume mount

**Success Criteria:**
- All Pods running and healthy
- Secrets properly isolated by tier
- No plain-text secrets in YAML files committed to git
- Updates trigger automatic rollouts
- Can decode and verify all Secret values
- Application functions end-to-end

**Implementation**: This challenge combines concepts from all CKAD topics. Use [`specs/ckad/exercises/ex1-complete-secrets.yaml`](specs/ckad/exercises/ex1-complete-secrets.yaml) as a starting template and expand it with Deployments, Services, and Ingress from other labs.

## Advanced Topics (Beyond CKAD)

Brief mention of advanced patterns:

### External Secrets Operator

Syncs Secrets from external secret stores (AWS Secrets Manager, Azure Key Vault, HashiCorp Vault):

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-secret
spec:
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: database-credentials
  data:
  - secretKey: password
    remoteRef:
      key: prod/db/password
```

> Not required for CKAD but important for production systems

### Sealed Secrets

Encrypt Secrets for safe storage in Git:

```
# Install kubeseal CLI
# Encrypt Secret
kubeseal -f secret.yaml -w sealed-secret.yaml

# Commit sealed-secret.yaml to Git
# Deploy - controller decrypts in-cluster
kubectl apply -f sealed-secret.yaml
```

> Popular GitOps pattern but out of CKAD scope

**External resources**:
- External Secrets Operator: https://external-secrets.io
- HashiCorp Vault: https://www.vaultproject.io/docs/platform/k8s
- Sealed Secrets: https://github.com/bitnami-labs/sealed-secrets
- Cloud provider secret management:
  - AWS: https://docs.aws.amazon.com/secretsmanager
  - Azure: https://azure.microsoft.com/en-us/products/key-vault
  - GCP: https://cloud.google.com/secret-manager

## Quick Reference

### Creation

```bash
# From literals
kubectl create secret generic NAME --from-literal=KEY=VALUE

# From files
kubectl create secret generic NAME --from-file=PATH

# From env file
kubectl create secret generic NAME --from-env-file=FILE

# Docker registry
kubectl create secret docker-registry NAME --docker-server=SERVER --docker-username=USER --docker-password=PASS

# TLS
kubectl create secret tls NAME --cert=CERT --key=KEY
```

### Usage in Pods

```yaml
# Environment - all keys
envFrom:
- secretRef:
    name: secret-name

# Environment - specific key
env:
- name: VAR_NAME
  valueFrom:
    secretKeyRef:
      name: secret-name
      key: key-name

# Volume mount
volumes:
- name: vol-name
  secret:
    secretName: secret-name
volumeMounts:
- name: vol-name
  mountPath: /path
```

### Viewing

```bash
# List secrets
kubectl get secrets

# Describe (shows keys, not values)
kubectl describe secret NAME

# View YAML (base64 encoded)
kubectl get secret NAME -o yaml

# Decode value
kubectl get secret NAME -o jsonpath='{.data.KEY}' | base64 -d
```

## Cleanup

```
kubectl delete all,secret,sa -l kubernetes.courselabs.co=secrets

# If you created test namespaces
kubectl delete namespace ckad-secrets-test
```

## Further Reading

- [Secrets Documentation](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Secrets Best Practices](https://kubernetes.io/docs/concepts/security/secrets-good-practices/)
- [Encrypting Secret Data at Rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/)
- [Managing Secrets with kubectl](https://kubernetes.io/docs/tasks/configmap-secret/)

---

> Back to [basic Secrets lab](README.md) | [Course contents](../../README.md)
