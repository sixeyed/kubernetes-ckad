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

**TODO**: Create examples:
- `specs/usage/pod-volume-mount.yaml` - Mount entire Secret
- `specs/usage/pod-volume-selective.yaml` - Mount specific keys
- `specs/usage/pod-volume-permissions.yaml` - Custom file modes

**TODO**: Add exercise:
1. Create Secret with multiple config files
2. Mount entire Secret as volume
3. Mount only specific keys with custom paths
4. Set file permissions (mode: 0400)
5. Verify file contents and permissions in Pod

## Managing Secret Updates

### Understanding Update Behavior

**Environment Variables**: Static for Pod lifetime - never update even if Secret changes

**Volume Mounts**: Kubernetes updates them automatically (with cache delay), but apps may not reload

From the basic lab, you learned about hot reloads and manual rollouts. Here are CKAD-specific patterns:

### Pattern 1: Annotation-Based Updates

Force Deployment rollout when Secret changes by updating Pod template metadata:

**TODO**: Create complete example:
- `specs/updates/app-secret-v1.yaml` - Initial Secret
- `specs/updates/deployment-v1.yaml` - Deployment with annotation
- `specs/updates/app-secret-v2.yaml` - Updated Secret (same name)
- `specs/updates/deployment-v2.yaml` - Updated with new annotation value

Example annotation approach:

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

**TODO**: Add step-by-step exercise:
1. Deploy app with secret and annotation
2. Update Secret data
3. Update annotation in Deployment (v1 -> v2)
4. Verify rollout triggered automatically
5. Show how to rollback if needed

### Pattern 2: Immutable Secrets with Versioned Names

Create new Secret with version suffix instead of updating:

**TODO**: Create example:
- `specs/updates/app-secret-v1.yaml` - Secret named app-secret-v1
- `specs/updates/app-secret-v2.yaml` - Secret named app-secret-v2
- `specs/updates/deployment-rolling.yaml` - Deployment referencing version

```yaml
# Update process:
# 1. Create app-secret-v2
# 2. Update Deployment to reference app-secret-v2
# 3. Automatic rollout happens
# 4. Can rollback by reverting to app-secret-v1
```

**TODO**: Add exercise comparing both patterns with pros/cons

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

**TODO**: Add example and exercise demonstrating immutable Secrets

## Security Best Practices

### Encoding vs Encryption

**Critical Understanding**: Base64 encoding is NOT encryption!

```
# Anyone with kubectl access can decode Secrets
kubectl get secret my-secret -o jsonpath='{.data.password}' | base64 -d
```

**TODO**: Add comprehensive security section covering:

1. **Encryption at Rest**
   - How to enable etcd encryption
   - Cloud provider default encryption
   - Reference to cluster setup docs

2. **RBAC for Secrets**
   - Creating Roles that deny Secret access
   - Separating Secret management from app deployment
   - Example RBAC policies (reference to rbac lab)

3. **External Secret Management**
   - Brief overview of External Secrets Operator
   - HashiCorp Vault integration
   - AWS Secrets Manager / Azure Key Vault
   - Note: Out of CKAD scope but important to know

4. **Avoiding Secrets in Git**
   - Never commit encoded Secrets to version control
   - Using .gitignore for secret files
   - Sealed Secrets for GitOps workflows

**TODO**: Create examples:
- `specs/security/rbac-deny-secrets.yaml` - Role denying Secret access
- `specs/security/rbac-secrets-only.yaml` - Role allowing only Secret management

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

**TODO**: Create troubleshooting exercise with:
- Pod referencing non-existent Secret
- Pod in wrong namespace
- Secret with typo in name

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

**TODO**: Create comprehensive troubleshooting lab:
1. Pod with missing Secret reference
2. Pod with wrong Secret key name
3. Secret in different namespace
4. Secret created after Pod (Pod doesn't auto-restart)
5. Volume mount path conflicts
6. File permission issues

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

**TODO**: Add systematic debugging guide with decision tree

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

**TODO**: Create examples:
- `specs/serviceaccount/sa-with-imagepullsecret.yaml`
- `specs/serviceaccount/pod-using-sa.yaml`

**TODO**: Add exercise:
1. Create docker-registry Secret
2. Create ServiceAccount referencing Secret
3. Create Pod using ServiceAccount
4. Verify image pull works
5. Show how multiple Pods can share same ServiceAccount

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

**TODO**: Add 10 rapid-fire practice scenarios matching exam format

## Lab Challenge: Multi-Tier Application with Secrets

Build a complete application demonstrating all Secret patterns:

**TODO**: Create comprehensive challenge with:

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

**TODO**: Create all necessary specs in `specs/challenge/` directory

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

**TODO**: Add links to external resources for these topics

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
