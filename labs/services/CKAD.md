# Services - CKAD Exam Topics

This document covers the CKAD exam requirements for Kubernetes Services. Make sure you've completed the [basic Services lab](README.md) first, as it covers the fundamental concepts of ClusterIP, NodePort, and LoadBalancer services.

## CKAD Services Requirements

The CKAD exam expects you to understand and work with:

- Service types and use cases
- Endpoints and EndpointSlices
- Multi-port Services
- Headless Services
- Services without selectors (external services)
- ExternalName Services
- Session affinity
- DNS and service discovery
- Service troubleshooting

## API Specs

- [Service](https://kubernetes.io/docs/reference/kubernetes-api/service-resources/service-v1/)
- [Endpoints](https://kubernetes.io/docs/reference/kubernetes-api/service-resources/endpoints-v1/)
- [EndpointSlice](https://kubernetes.io/docs/reference/kubernetes-api/service-resources/endpoint-slice-v1/)

## Understanding Endpoints

When a Service is created with a selector, Kubernetes automatically creates an **Endpoints** object. This object tracks which Pod IP addresses match the Service selector.

From the basic lab, you should have the whoami service deployed. Check its endpoints:

```
kubectl get endpoints whoami

kubectl describe endpoints whoami
```

The Endpoints object lists all the IP addresses of Pods that match the Service selector. This is how the Service knows where to route traffic.

### Endpoints vs EndpointSlices

**EndpointSlices** are a newer API that scales better for Services with many endpoints:

```
kubectl get endpointslices

kubectl describe endpointslice whoami
```

> EndpointSlices split large endpoint lists into multiple objects, improving performance in large clusters.

### Comparing Endpoints and EndpointSlices

Let's examine both resources to understand the differences:

```
# View traditional Endpoints
kubectl get endpoints whoami -o yaml

# View EndpointSlices (newer API)
kubectl get endpointslices -l kubernetes.io/service-name=whoami

# Detailed view of an EndpointSlice
kubectl describe endpointslice <endpointslice-name>
```

**Key differences:**

| Feature | Endpoints | EndpointSlices |
|---------|-----------|----------------|
| **Max endpoints** | ~1000 (performance degrades) | 100 per slice (creates multiple) |
| **Updates** | Replace entire object | Update only changed slices |
| **Network topology** | No support | Supports topology-aware routing |
| **Dual-stack** | Limited | Full IPv4/IPv6 support |
| **API version** | v1 (stable since 1.0) | v1 (stable since 1.21) |

**When to use each:**
- **Endpoints**: Maintained for backward compatibility; automatically created
- **EndpointSlices**: Default for new clusters (1.21+); better performance at scale

For CKAD, you should be familiar with both, but you'll primarily interact with Endpoints objects since they're simpler and sufficient for most exam scenarios.

## Multi-Port Services

Services can expose multiple ports for applications that listen on different ports (e.g., HTTP on 8080, metrics on 9090).

Here's a Service spec with multiple ports - [whoami-multiport.yaml](./specs/ckad/whoami-multiport.yaml):

```yaml
apiVersion: v1
kind: Service
metadata:
  name: whoami-multiport
spec:
  selector:
    app: whoami
  type: ClusterIP
  ports:
    - name: http          # Named port for clarity
      port: 80            # Service port
      targetPort: http-web # References named port in Pod
      protocol: TCP
    - name: metrics
      port: 9090
      targetPort: 9090
      protocol: TCP
    - name: admin
      port: 8888
      targetPort: 80      # Can map to same container port
      protocol: TCP
```

**Try it now:**

```
# Deploy the multi-port service
kubectl apply -f labs/services/specs/ckad/whoami-multiport.yaml

# Check the service configuration
kubectl get svc whoami-multiport
kubectl describe svc whoami-multiport

# Test connectivity to different ports from a test pod
kubectl exec sleep -- curl -s whoami-multiport:80
kubectl exec sleep -- curl -s whoami-multiport:9090
kubectl exec sleep -- curl -s whoami-multiport:8888
```

**Key points:**
- Each port must have a unique `name` within the Service
- Port names must be lowercase alphanumeric or `-` (max 15 chars)
- Different Service ports can target the same container port
- Clients can reference ports by name in some contexts (e.g., SRV records)

### Named Ports in Pods

You can name ports in Pod specs and reference them in Services. This is especially useful when port numbers change between versions.

**Deployment with named ports** - [whoami-deployment-named-ports.yaml](./specs/ckad/whoami-deployment-named-ports.yaml):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: whoami-named-ports
spec:
  replicas: 2
  selector:
    matchLabels:
      app: whoami-named
  template:
    metadata:
      labels:
        app: whoami-named
    spec:
      containers:
        - name: whoami
          image: sixeyed/whoami:21.04
          ports:
            - name: http-web    # Named port
              containerPort: 80
              protocol: TCP
```

**Service referencing named port** - [whoami-service-named-ports.yaml](./specs/ckad/whoami-service-named-ports.yaml):

```yaml
apiVersion: v1
kind: Service
metadata:
  name: whoami-named
spec:
  selector:
    app: whoami-named
  ports:
    - name: http
      port: 8080
      targetPort: http-web  # References the named port, not a number
      protocol: TCP
```

**Try it:**

```
# Deploy the deployment and service
kubectl apply -f labs/services/specs/ckad/whoami-deployment-named-ports.yaml
kubectl apply -f labs/services/specs/ckad/whoami-service-named-ports.yaml

# Verify the service is working
kubectl get svc whoami-named
kubectl exec sleep -- curl -s whoami-named:8080
```

**Benefits of named ports:**
- **Version flexibility**: Change container port numbers without updating Services
- **Clarity**: Self-documenting - `http-web` is clearer than `8080`
- **Multiple versions**: Different Pod versions can use different port numbers but same name
- **CKAD tip**: Use numeric ports in the exam for speed unless specifically needed

## Headless Services

A **headless Service** has no ClusterIP (set `clusterIP: None`). Instead of load balancing, DNS returns all Pod IP addresses directly.

Use cases:
- StatefulSets (covered in the [statefulsets lab](../statefulsets/README.md))
- Client-side load balancing
- Service discovery without load balancing

Here's a headless service spec - [whoami-headless.yaml](./specs/ckad/whoami-headless.yaml):

```yaml
apiVersion: v1
kind: Service
metadata:
  name: whoami-headless
spec:
  clusterIP: None  # This makes the service headless
  selector:
    app: whoami
  ports:
    - name: http
      port: 80
      targetPort: 80
      protocol: TCP
```

**Try it now:**

```
# Deploy the headless service
kubectl apply -f labs/services/specs/ckad/whoami-headless.yaml

# Check the service - notice no CLUSTER-IP
kubectl get svc whoami-headless

# DNS lookup returns all Pod IPs, not a Service IP
kubectl exec sleep -- nslookup whoami-headless

# Compare with regular service (returns single ClusterIP)
kubectl exec sleep -- nslookup whoami
```

**Expected behavior:**

```
# Headless service returns multiple A records (one per Pod)
Name:      whoami-headless.default.svc.cluster.local
Address 1: 10.244.1.5 10-244-1-5.whoami-headless.default.svc.cluster.local
Address 2: 10.244.2.4 10-244-2-4.whoami-headless.default.svc.cluster.local
Address 3: 10.244.3.3 10-244-3-3.whoami-headless.default.svc.cluster.local

# Regular service returns single ClusterIP
Name:      whoami.default.svc.cluster.local
Address 1: 10.96.100.123 whoami.default.svc.cluster.local
```

**Key differences:**
- **No ClusterIP**: Service has `ClusterIP: None` in its spec
- **DNS returns all Pods**: Each Pod gets its own DNS A record
- **Client-side selection**: Application chooses which Pod to connect to
- **StatefulSet integration**: Each StatefulSet Pod gets predictable DNS name

**CKAD exam tip**: Headless services are commonly used with StatefulSets for stable network identities.

## Services Without Selectors

Services don't always target Pods. You can create a Service without a selector to:
- Route to external services (databases, APIs outside the cluster)
- Manually manage endpoints
- Migrate services gradually

When you create a Service without a selector, Kubernetes doesn't create Endpoints automatically. You must create them manually.

**Service without selector** - [external-api-service.yaml](./specs/ckad/external-api-service.yaml):

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-api
spec:
  # No selector - endpoints will be managed manually
  ports:
    - name: http
      port: 80
      targetPort: 8080
      protocol: TCP
```

**Manual Endpoints object** - [external-api-endpoints.yaml](./specs/ckad/external-api-endpoints.yaml):

```yaml
apiVersion: v1
kind: Endpoints
metadata:
  name: external-api  # Must match the Service name
subsets:
  - addresses:
      - ip: 192.168.1.100  # External service IP address
    ports:
      - name: http
        port: 8080
        protocol: TCP
```

**Try it now:**

```
# Deploy the service without selector
kubectl apply -f labs/services/specs/ckad/external-api-service.yaml

# Check endpoints - none exist yet
kubectl get endpoints external-api

# Create manual endpoints
kubectl apply -f labs/services/specs/ckad/external-api-endpoints.yaml

# Now endpoints exist
kubectl get endpoints external-api
kubectl describe endpoints external-api

# Test connectivity (will fail if IP is not reachable)
kubectl exec sleep -- curl -s external-api
```

**Updating Endpoints:**

```
# Edit endpoints to change external IP
kubectl edit endpoints external-api

# Or update the YAML file and reapply
# Change the IP in external-api-endpoints.yaml, then:
kubectl apply -f labs/services/specs/ckad/external-api-endpoints.yaml
```

**Use cases:**
- **External database**: Reference on-premises database at `10.0.1.50:5432`
- **Migration**: Gradually move external service into cluster
- **Multi-cluster**: Route to services in another Kubernetes cluster
- **Legacy systems**: Access non-Kubernetes services via Kubernetes DNS

**CKAD exam tip**: This pattern is useful for scenarios involving external databases or APIs that need to be accessed via Service DNS names.

## ExternalName Services

**ExternalName** Services provide a DNS CNAME alias to an external service. They don't proxy traffic; they just return a DNS record.

Here's an ExternalName service - [external-database.yaml](./specs/ckad/external-database.yaml):

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-db
spec:
  type: ExternalName
  externalName: database.example.com
  # No ports needed - DNS CNAME alias only
```

**Try it now:**

```
# Deploy ExternalName service
kubectl apply -f labs/services/specs/ckad/external-database.yaml

# Check the service - notice TYPE is ExternalName
kubectl get svc external-db

# DNS lookup returns CNAME to external service
kubectl exec sleep -- nslookup external-db
```

**Expected output:**

```
Name:      external-db.default.svc.cluster.local
Address 1: database.example.com
```

**How it works:**
- **No ClusterIP**: ExternalName services don't get a ClusterIP
- **DNS CNAME**: DNS query returns a CNAME record pointing to the external name
- **No proxying**: Traffic goes directly from Pod to external service
- **No Endpoints**: Kubernetes doesn't create or manage Endpoints

**Use cases:**
- **Cloud services**: Reference AWS RDS, Azure SQL via internal DNS name
- **Migration path**: Use `mydb` internally, change `externalName` to move to Kubernetes
- **Environment differences**: Dev uses `dev-db.example.com`, Prod uses `prod-db.example.com`
- **Abstraction**: Hide external service details from application code

**Example migration scenario:**

```yaml
# Stage 1: Point to external database
apiVersion: v1
kind: Service
metadata:
  name: myapp-db
spec:
  type: ExternalName
  externalName: rds.amazonaws.com

---
# Stage 2: Migrate to internal Postgres, just change the Service
apiVersion: v1
kind: Service
metadata:
  name: myapp-db
spec:
  selector:
    app: postgres
  ports:
    - port: 5432
```

Application code always uses `myapp-db:5432` - no changes needed!

**CKAD exam tip**: ExternalName services are useful for scenarios where you need to reference external services by Kubernetes DNS names without creating manual Endpoints.

## Session Affinity

By default, Services load balance requests randomly across Pods. **Session affinity** ensures requests from the same client go to the same Pod.

Here's a service with session affinity - [whoami-sessionaffinity.yaml](./specs/ckad/whoami-sessionaffinity.yaml):

```yaml
apiVersion: v1
kind: Service
metadata:
  name: whoami-sticky
spec:
  selector:
    app: whoami
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 3600  # Session timeout: 1 hour
  type: ClusterIP
  ports:
    - port: 80
      targetPort: 80
      protocol: TCP
```

**Try it now:**

```
# First, test regular service without session affinity
# Make multiple requests and see different Pod responses
for i in {1..5}; do
  kubectl exec sleep -- curl -s whoami | grep HOSTNAME
done

# Deploy service with session affinity
kubectl apply -f labs/services/specs/ckad/whoami-sessionaffinity.yaml

# Make multiple requests - should all go to same Pod
for i in {1..5}; do
  kubectl exec sleep -- curl -s whoami-sticky | grep HOSTNAME
done

# Check the service configuration
kubectl describe svc whoami-sticky | grep -A 2 "Session Affinity"
```

**Expected behavior:**

```
# Without session affinity - different Pods
HOSTNAME: whoami-7c5b9f5d4b-abc12
HOSTNAME: whoami-7c5b9f5d4b-xyz34
HOSTNAME: whoami-7c5b9f5d4b-abc12
HOSTNAME: whoami-7c5b9f5d4b-def56
HOSTNAME: whoami-7c5b9f5d4b-xyz34

# With session affinity - same Pod every time
HOSTNAME: whoami-7c5b9f5d4b-abc12
HOSTNAME: whoami-7c5b9f5d4b-abc12
HOSTNAME: whoami-7c5b9f5d4b-abc12
HOSTNAME: whoami-7c5b9f5d4b-abc12
HOSTNAME: whoami-7c5b9f5d4b-abc12
```

**How it works:**
- **ClientIP affinity**: Based on client's source IP address
- **Hash-based**: Kubernetes hashes the client IP to select a Pod
- **Timeout**: Session expires after configured timeout (default: 10800 seconds / 3 hours)
- **No cookies**: Works at network level, no application changes needed

**Use cases:**
- **Web sessions**: Applications storing session data in memory
- **WebSockets**: Long-lived connections requiring same backend
- **Shopping carts**: Maintaining cart state without distributed cache
- **File uploads**: Multi-part uploads to same server

**Limitations:**
- Only `ClientIP` affinity is supported (no cookie-based affinity)
- Doesn't survive Pod restarts/rescheduling
- Less effective with NAT or proxies (multiple clients, same IP)
- For true session persistence, use external session store (Redis, etc.)

**CKAD exam tip**: Use `sessionAffinity: ClientIP` for scenarios requiring sticky sessions, especially for stateful web applications.

## DNS and Service Discovery

### DNS Names and Namespaces

Services are accessible via DNS in multiple formats:

- **Same namespace**: `<service-name>`
- **Cross-namespace**: `<service-name>.<namespace>`
- **Fully qualified**: `<service-name>.<namespace>.svc.cluster.local`

**Try it now:**

```
# Create a test namespace and resources
kubectl create namespace ckad-services-test

kubectl run test-pod -n ckad-services-test --image=curlimages/curl:latest \
  --command -- sleep 3600

# Wait for pod to be ready
kubectl wait --for=condition=ready pod/test-pod -n ckad-services-test --timeout=60s

# Ensure whoami service exists in default namespace
kubectl get svc whoami -n default

# Test DNS from a different namespace
# Short name doesn't work across namespaces
kubectl exec -n ckad-services-test test-pod -- curl -s -m 3 whoami || echo "Failed - expected"

# Cross-namespace format works
kubectl exec -n ckad-services-test test-pod -- curl -s whoami.default

# Fully qualified domain name also works
kubectl exec -n ckad-services-test test-pod -- curl -s whoami.default.svc.cluster.local

# From same namespace, short name works
kubectl exec sleep -- curl -s whoami | head -n 5
```

**DNS format breakdown:**

| Format | Works From | Example |
|--------|-----------|---------|
| `service-name` | Same namespace only | `whoami` |
| `service-name.namespace` | Any namespace | `whoami.default` |
| `service-name.namespace.svc` | Any namespace | `whoami.default.svc` |
| `service-name.namespace.svc.cluster.local` | Any namespace (FQDN) | `whoami.default.svc.cluster.local` |

**CKAD exam tip**: Use the shortest form that works. Within same namespace, use service name only. Cross-namespace, use `service.namespace`.

### SRV Records

Services also create SRV DNS records for port discovery. SRV records include port numbers and protocol information.

**Try it now:**

```
# Query SRV records for named ports
# Format: _port-name._protocol.service-name.namespace.svc.cluster.local
kubectl exec sleep -- nslookup -type=srv _http._tcp.whoami.default.svc.cluster.local

# For multi-port services, each port gets an SRV record
kubectl exec sleep -- nslookup -type=srv _metrics._tcp.whoami-multiport.default.svc.cluster.local
```

**Expected output:**

```
_http._tcp.whoami.default.svc.cluster.local service = 0 50 80 whoami.default.svc.cluster.local
```

The SRV record shows:
- **Priority**: 0 (lower is higher priority)
- **Weight**: 50 (for load balancing between equal priority records)
- **Port**: 80 (the service port)
- **Target**: whoami.default.svc.cluster.local (the service hostname)

**Use case**: Service discovery tools can query SRV records to discover which ports a service offers without hardcoding port numbers.

**Cleanup test namespace:**

```
kubectl delete namespace ckad-services-test
```

## Service Troubleshooting

### Common Issues and Debugging

**1. Service has no endpoints**

```
kubectl get endpoints <service-name>
```

Causes:
- No Pods match the label selector
- Pods are not ready (failing readiness probes)
- Label mismatch between Service selector and Pod labels

**Troubleshooting Exercise 1: Label Mismatch**

Deploy a broken service - [troubleshooting-broken-service.yaml](./specs/ckad/troubleshooting-broken-service.yaml):

```
# Deploy broken configuration
kubectl apply -f labs/services/specs/ckad/troubleshooting-broken-service.yaml

# Check the service - looks fine
kubectl get svc broken-service

# But no endpoints!
kubectl get endpoints broken-service

# Check what pods exist
kubectl get pods -l app=broken-app

# Compare service selector with pod labels
kubectl get svc broken-service -o jsonpath='{.spec.selector}'
kubectl get pods --show-labels | grep broken

# Fix: Update the service selector to match pod labels
kubectl patch svc broken-service -p '{"spec":{"selector":{"app":"broken-app"}}}'

# Now endpoints exist
kubectl get endpoints broken-service
```

**2. DNS resolution fails**

```
# Check DNS is working
kubectl exec sleep -- nslookup kubernetes.default

# Check service exists
kubectl get svc <service-name>

# Verify namespace
kubectl get svc <service-name> -n <namespace>

# Check CoreDNS is running
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

**3. Connection timeouts**

```
# Check endpoints exist
kubectl get endpoints <service-name>

# Check Pod status
kubectl get pods -l <service-selector>

# Test direct Pod connectivity
kubectl exec sleep -- curl <pod-ip>:<port>
```

**Troubleshooting Exercise 2: Port Mismatch**

Deploy a service with port mismatch - [troubleshooting-port-mismatch.yaml](./specs/ckad/troubleshooting-port-mismatch.yaml):

```
# Deploy configuration with port issue
kubectl apply -f labs/services/specs/ckad/troubleshooting-port-mismatch.yaml

# Service has endpoints
kubectl get endpoints port-mismatch-svc

# But connection fails
kubectl exec sleep -- curl -m 5 port-mismatch-svc || echo "Connection failed"

# Investigate: Check what port the pod is listening on
POD_NAME=$(kubectl get pod -l app=port-test -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod $POD_NAME | grep -A 5 "Containers:"

# Check what port the service is targeting
kubectl get svc port-mismatch-svc -o jsonpath='{.spec.ports[0].targetPort}'

# Test direct Pod connection on correct port
POD_IP=$(kubectl get pod $POD_NAME -o jsonpath='{.status.podIP}')
kubectl exec sleep -- curl -s $POD_IP:80

# Fix: Update service targetPort
kubectl patch svc port-mismatch-svc -p '{"spec":{"ports":[{"port":80,"targetPort":80,"protocol":"TCP","name":"http"}]}}'

# Now it works
kubectl exec sleep -- curl -s port-mismatch-svc | head -n 3
```

**Comprehensive Troubleshooting Checklist:**

| Issue | Check Command | Solution |
|-------|--------------|----------|
| **No Endpoints** | `kubectl get endpoints <svc>` | Fix label selectors, check pod readiness |
| **DNS fails** | `kubectl exec <pod> -- nslookup <svc>` | Check CoreDNS, verify service exists |
| **Wrong namespace** | `kubectl get svc -A \| grep <name>` | Use `<svc>.<namespace>` format |
| **Port mismatch** | `kubectl describe svc <svc>` | Match targetPort to containerPort |
| **Pods not ready** | `kubectl get pods -l <selector>` | Check readiness probes, logs |
| **Network policy** | `kubectl get networkpolicy` | Review ingress/egress rules |
| **Service type** | `kubectl get svc <svc>` | Verify ClusterIP/NodePort/LoadBalancer |

**Common exam debugging workflow:**

```
# 1. Verify service exists and has correct type
kubectl get svc <service-name>

# 2. Check if service has endpoints
kubectl get endpoints <service-name>

# 3. If no endpoints, check pods with matching labels
kubectl get pods -l <label-selector> --show-labels

# 4. Verify pod status and readiness
kubectl describe pod <pod-name>

# 5. Check service and pod port configuration
kubectl get svc <service-name> -o yaml | grep -A 5 ports
kubectl get pod <pod-name> -o yaml | grep -A 5 ports

# 6. Test DNS resolution
kubectl exec sleep -- nslookup <service-name>

# 7. Test direct connectivity to pod
kubectl exec sleep -- curl <pod-ip>:<container-port>

# 8. Test service connectivity
kubectl exec sleep -- curl <service-name>:<service-port>
```

### Using kubectl port-forward for Testing

You can bypass Services and connect directly to Pods for debugging. `port-forward` creates a tunnel from your local machine to a Pod or Service.

**Syntax:**

```
# Forward local port to Pod
kubectl port-forward pod/<pod-name> <local-port>:<pod-port>

# Forward to a Service (picks a random Pod)
kubectl port-forward service/<service-name> <local-port>:<service-port>

# Forward to a Deployment (picks a random Pod)
kubectl port-forward deployment/<deployment-name> <local-port>:<pod-port>
```

**Try it now:**

```
# Get a pod name
POD_NAME=$(kubectl get pod -l app=whoami -o jsonpath='{.items[0].metadata.name}')

# Forward local port 8080 to pod port 80
# This runs in foreground - use Ctrl+C to stop
kubectl port-forward pod/$POD_NAME 8080:80 &

# Test from your local machine (not from a pod)
curl http://localhost:8080

# Stop the port-forward
kill %1

# Port-forward to a Service
kubectl port-forward service/whoami 8080:80 &

curl http://localhost:8080

kill %1

# Forward to Deployment
kubectl port-forward deployment/whoami 8080:80 &

curl http://localhost:8080

kill %1
```

**When to use port-forward:**

| Scenario | Use port-forward | Use Service |
|----------|------------------|-------------|
| **Testing from local machine** | Yes | No (Services are cluster-internal) |
| **Debugging specific Pod** | Yes | No (Service load balances) |
| **Accessing admin interfaces** | Yes | Use with caution |
| **Production traffic** | No | Yes |
| **Load balancing** | No | Yes |
| **Persistent access** | No (manual tunnel) | Yes (automatic) |
| **Multiple clients** | No (single tunnel) | Yes |

**Use cases for port-forward:**
- **Development**: Access cluster services from local IDE/browser
- **Debugging**: Connect to specific Pod bypassing Service load balancing
- **Database access**: Temporary access to database pods for queries
- **Admin dashboards**: Access internal dashboards without exposing them

**Limitations:**
- Requires active kubectl connection
- Only works for single user (your machine)
- Breaks when Pod restarts or kubectl disconnects
- Not suitable for production traffic

**CKAD exam note:** port-forward is NOT typically needed in exam tasks (no local machine access), but understanding when to use it vs Services demonstrates good knowledge of Kubernetes networking concepts.

## Service Network Policies

Services work with Network Policies to control traffic flow. This is covered in detail in the [networkpolicy lab](../networkpolicy/README.md).

Key concepts:
- Network Policies control which Pods can connect to Services
- Policies use label selectors for both source and destination
- By default, all traffic is allowed (unless a NetworkPolicy exists)

**Quick example with NetworkPolicy:**

Here's a service with a NetworkPolicy restricting access - [service-with-networkpolicy.yaml](./specs/ckad/service-with-networkpolicy.yaml):

```yaml
apiVersion: v1
kind: Service
metadata:
  name: restricted-service
spec:
  selector:
    app: restricted-app
  ports:
    - name: http
      port: 80
      targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-frontend-only
spec:
  podSelector:
    matchLabels:
      app: restricted-app
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              role: frontend
      ports:
        - protocol: TCP
          port: 80
```

**Try it now:**

```
# Deploy the service and NetworkPolicy
kubectl apply -f labs/services/specs/ckad/service-with-networkpolicy.yaml

# Test from pod WITHOUT the "role=frontend" label - should fail
kubectl exec sleep -- curl -m 5 restricted-service || echo "Blocked by NetworkPolicy"

# Create a pod WITH the "role=frontend" label
kubectl run frontend-pod --image=curlimages/curl:latest --labels="role=frontend" \
  --command -- sleep 3600

kubectl wait --for=condition=ready pod/frontend-pod --timeout=60s

# Test from frontend pod - should succeed
kubectl exec frontend-pod -- curl -s restricted-service | head -n 3

# Cleanup
kubectl delete pod frontend-pod
```

**How it works:**
1. **NetworkPolicy** selects target Pods: `app=restricted-app`
2. **Ingress rules** allow traffic only from Pods with `role=frontend`
3. **Service** routes traffic to Pods, but NetworkPolicy filters connections
4. Pods without the `frontend` label are blocked at the network level

**Key points:**
- NetworkPolicies work at the Pod level, not the Service level
- The Service still routes traffic, but NetworkPolicy blocks unwanted connections
- Both source and destination labels are important
- Without a NetworkPolicy, all traffic is allowed by default

**For comprehensive NetworkPolicy coverage, see the [networkpolicy lab](../networkpolicy/README.md).**

## CKAD Exam Tips

### Quick Service Creation

You can create Services imperatively with kubectl:

```
# Create ClusterIP service
kubectl expose pod whoami --port=80 --name=whoami-svc

# Create NodePort service
kubectl expose pod whoami --type=NodePort --port=80 --name=whoami-np

# Create LoadBalancer service
kubectl expose pod whoami --type=LoadBalancer --port=80 --name=whoami-lb

# Expose deployment (common pattern)
kubectl expose deployment myapp --port=80 --target-port=8080
```

### Verify Service Configuration

Quick checks during the exam:

```
# Get service details
kubectl get svc <name>
kubectl describe svc <name>

# Check endpoints
kubectl get endpoints <name>

# Test connectivity
kubectl run test --rm -it --image=busybox -- wget -O- <service-name>:<port>

# Check DNS
kubectl run test --rm -it --image=busybox -- nslookup <service-name>
```

### Common Exam Scenarios

Here are practice scenarios that match CKAD exam format and difficulty:

#### Scenario 1: Create and Expose a Deployment

**Task:** Create a deployment named `webapp` with 3 replicas using the `nginx:1.21` image. Expose it with a ClusterIP service named `webapp-svc` on port 8080, targeting container port 80.

**Solution:**

```bash
# Create deployment
kubectl create deployment webapp --image=nginx:1.21 --replicas=3

# Expose with service
kubectl expose deployment webapp --name=webapp-svc --port=8080 --target-port=80

# Verify
kubectl get deployment webapp
kubectl get svc webapp-svc
kubectl get endpoints webapp-svc
```

#### Scenario 2: Create a NodePort Service

**Task:** Create a NodePort service named `api-nodeport` that exposes the existing deployment `whoami` on NodePort 30080, service port 80.

**Solution:**

```bash
# Create NodePort service
kubectl expose deployment whoami --name=api-nodeport --type=NodePort \
  --port=80 --target-port=80

# Edit to set specific NodePort
kubectl patch svc api-nodeport -p '{"spec":{"ports":[{"port":80,"nodePort":30080,"targetPort":80}]}}'

# Or create with YAML
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: api-nodeport
spec:
  type: NodePort
  selector:
    app: whoami
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30080
EOF

# Verify
kubectl get svc api-nodeport
```

#### Scenario 3: Debug Service with No Endpoints

**Task:** A service named `broken-service` has no endpoints. Identify and fix the issue.

**Solution:**

```bash
# Check service and endpoints
kubectl get svc broken-service
kubectl get endpoints broken-service

# Check what the service selector is looking for
kubectl describe svc broken-service | grep Selector

# Find pods and their labels
kubectl get pods --show-labels

# Compare labels - identify mismatch
# Option 1: Fix the service selector
kubectl patch svc broken-service -p '{"spec":{"selector":{"app":"correct-label"}}}'

# Option 2: Fix the pod labels
kubectl label pod <pod-name> app=expected-label --overwrite

# Verify endpoints now exist
kubectl get endpoints broken-service
```

#### Scenario 4: Create a Headless Service

**Task:** Create a headless service named `database-headless` for pods with label `app=database`, exposing port 5432.

**Solution:**

```bash
# Using kubectl
kubectl create service clusterip database-headless --tcp=5432:5432 \
  --clusterip="None" --dry-run=client -o yaml | \
  kubectl apply -f -

# Or with YAML
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: database-headless
spec:
  clusterIP: None
  selector:
    app: database
  ports:
    - port: 5432
      targetPort: 5432
EOF

# Verify - should show CLUSTER-IP as None
kubectl get svc database-headless
```

#### Scenario 5: Configure Session Affinity

**Task:** Modify the existing service `webapp-svc` to enable session affinity with a timeout of 1 hour (3600 seconds).

**Solution:**

```bash
# Patch the service
kubectl patch svc webapp-svc -p '{"spec":{"sessionAffinity":"ClientIP","sessionAffinityConfig":{"clientIP":{"timeoutSeconds":3600}}}}'

# Verify
kubectl describe svc webapp-svc | grep -A 3 "Session Affinity"

# Or edit directly
kubectl edit svc webapp-svc
# Add under spec:
#   sessionAffinity: ClientIP
#   sessionAffinityConfig:
#     clientIP:
#       timeoutSeconds: 3600
```

#### Scenario 6: Create Multi-Port Service

**Task:** Create a service named `multi-svc` exposing pods with label `app=api` on two ports: HTTP (80) and metrics (9090).

**Solution:**

```bash
# Create with YAML
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: multi-svc
spec:
  selector:
    app: api
  ports:
    - name: http
      port: 80
      targetPort: 80
      protocol: TCP
    - name: metrics
      port: 9090
      targetPort: 9090
      protocol: TCP
EOF

# Verify both ports
kubectl get svc multi-svc
kubectl describe svc multi-svc
```

#### Scenario 7: Create ExternalName Service

**Task:** Create an ExternalName service named `external-api` that points to `api.example.com`.

**Solution:**

```bash
# Using YAML
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: external-api
spec:
  type: ExternalName
  externalName: api.example.com
EOF

# Verify
kubectl get svc external-api
kubectl describe svc external-api

# Test DNS resolution
kubectl run test --rm -it --image=busybox -- nslookup external-api
```

#### Scenario 8: Fix DNS Resolution Between Namespaces

**Task:** A pod in namespace `app-ns` cannot connect to service `database` in namespace `db-ns`. Fix the connectivity issue.

**Solution:**

```bash
# Check if service exists in db-ns
kubectl get svc database -n db-ns

# The issue: Pod is using short name across namespaces
# Fix: Use namespace-qualified DNS name

# From pod in app-ns:
kubectl exec -n app-ns <pod-name> -- curl database.db-ns

# Or full FQDN:
kubectl exec -n app-ns <pod-name> -- curl database.db-ns.svc.cluster.local

# If updating application config/env:
kubectl set env deployment/<name> -n app-ns DATABASE_HOST=database.db-ns
```

**Exam Tips for These Scenarios:**

1. **Speed matters**: Use imperative commands when possible (`kubectl expose`, `kubectl create service`)
2. **Verify immediately**: Always check with `kubectl get` and `kubectl describe`
3. **Know your selectors**: Service issues are often label mismatches
4. **DNS shortcuts**: Use shortest DNS name that works (`service-name` in same namespace)
5. **YAML for complex configs**: Multi-port, session affinity, headless services are easier with YAML
6. **Check endpoints**: If service doesn't work, `kubectl get endpoints` is your first debug step

## Lab Challenge

Build a complete microservices application demonstrating all Service types. This challenge integrates all concepts from this lab.

### Challenge Overview

Deploy a three-tier application with:
- **Frontend**: Web tier with LoadBalancer and session affinity
- **Backend API**: Application tier with multi-port service
- **Database**: Data tier with StatefulSet and headless service
- **External Services**: Integration with external systems
- **Network Security**: NetworkPolicy restricting database access

### Step 1: Deploy the Frontend

```bash
# Deploy frontend with LoadBalancer and session affinity
kubectl apply -f labs/services/specs/ckad/lab-challenge-frontend.yaml

# Verify deployment and service
kubectl get deployment frontend
kubectl get svc frontend-lb
kubectl get endpoints frontend-lb

# Check session affinity is configured
kubectl describe svc frontend-lb | grep -A 3 "Session Affinity"
```

The frontend service uses:
- **Type**: LoadBalancer (external access)
- **Session affinity**: ClientIP with 3600s timeout
- **Replicas**: 3 for high availability

### Step 2: Deploy the Backend API

```bash
# Deploy backend with multi-port service
kubectl apply -f labs/services/specs/ckad/lab-challenge-backend.yaml

# Verify the multi-port configuration
kubectl get svc backend-api-svc
kubectl describe svc backend-api-svc

# Check both ports are exposed
kubectl get endpoints backend-api-svc
```

The backend service provides:
- **Port 8080**: Main API endpoint
- **Port 9090**: Metrics endpoint
- **Type**: ClusterIP (internal only)

### Step 3: Deploy the Database

```bash
# Deploy StatefulSet with headless and ClusterIP services
kubectl apply -f labs/services/specs/ckad/lab-challenge-database.yaml

# Verify StatefulSet and services
kubectl get statefulset database
kubectl get svc database-headless database-read

# Check headless service has no ClusterIP
kubectl get svc database-headless -o jsonpath='{.spec.clusterIP}'

# Verify Pod DNS names (StatefulSet + headless service)
kubectl run dns-test --rm -it --image=busybox -- \
  nslookup database-0.database-headless
```

The database tier provides:
- **Headless service**: Direct Pod access for writes
- **ClusterIP service**: Load-balanced reads
- **StatefulSet**: Stable network identity

### Step 4: Configure External Services

```bash
# Deploy ExternalName and manual endpoint services
kubectl apply -f labs/services/specs/ckad/lab-challenge-external.yaml

# Verify external services
kubectl get svc external-payment-api external-cache
kubectl get endpoints external-cache

# Test ExternalName DNS resolution
kubectl run dns-test --rm -it --image=busybox -- \
  nslookup external-payment-api
```

External service integration:
- **ExternalName**: DNS alias to external payment API
- **Manual Endpoints**: Connection to external Redis cache

### Step 5: Apply Network Security

```bash
# Apply NetworkPolicy restricting database access
kubectl apply -f labs/services/specs/ckad/lab-challenge-networkpolicy.yaml

# Verify the policy
kubectl get networkpolicy database-access-policy
kubectl describe networkpolicy database-access-policy
```

The NetworkPolicy ensures:
- Only Pods with `tier=api` label can access database
- All other connections are blocked
- Database is protected from unauthorized access

### Step 6: Test the Complete Application

```bash
# Test 1: Frontend accessibility (external)
kubectl get svc frontend-lb

# If LoadBalancer, get external IP
FRONTEND_IP=$(kubectl get svc frontend-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -s http://$FRONTEND_IP

# Test 2: Backend service connectivity from frontend
kubectl exec deployment/frontend -- curl -s backend-api-svc:8080 | head -n 3

# Test 3: Backend metrics port
kubectl exec deployment/frontend -- curl -s backend-api-svc:9090

# Test 4: Database connectivity from backend
# Backend can access database (has tier=api label)
kubectl exec deployment/backend-api -- curl -s database-read:5432 || echo "Postgres connection attempted"

# Test 5: Database blocked from frontend
# Frontend CANNOT access database (no tier=api label)
kubectl exec deployment/frontend -- timeout 5 curl database-read:5432 || echo "Blocked by NetworkPolicy - Expected"

# Test 6: Headless service DNS resolution
kubectl exec deployment/backend-api -- nslookup database-headless

# Test 7: Session affinity (make multiple requests from same source)
for i in {1..5}; do
  kubectl exec deployment/frontend -- curl -s frontend-lb | grep HOSTNAME
done

# Test 8: External service DNS
kubectl exec deployment/backend-api -- nslookup external-payment-api
kubectl exec deployment/backend-api -- nslookup external-cache
```

### Success Criteria Checklist

- [ ] Frontend deployment has 3 replicas running
- [ ] Frontend LoadBalancer service has external IP/port
- [ ] Session affinity keeps requests to same Pod
- [ ] Backend API service exposes ports 8080 and 9090
- [ ] Backend has endpoints for both ports
- [ ] Database StatefulSet is running
- [ ] Headless service returns all database Pod IPs
- [ ] ClusterIP service load-balances database reads
- [ ] ExternalName service resolves to external domain
- [ ] Manual endpoints service points to external IP
- [ ] NetworkPolicy allows backend → database
- [ ] NetworkPolicy blocks frontend → database
- [ ] DNS resolution works for all services
- [ ] Cross-tier communication works as designed

### Troubleshooting Common Issues

```bash
# No endpoints for a service
kubectl get endpoints <service-name>
kubectl get pods -l <label-selector> --show-labels

# NetworkPolicy blocking unexpected traffic
kubectl get networkpolicy
kubectl describe networkpolicy database-access-policy

# LoadBalancer pending (local cluster)
# Use NodePort instead or kubectl port-forward for testing

# DNS resolution failing
kubectl exec deployment/backend-api -- nslookup kubernetes.default
kubectl get pods -n kube-system -l k8s-app=kube-dns

# StatefulSet Pod not ready
kubectl get statefulset database
kubectl describe pod database-0
```

### Cleanup Challenge Resources

```bash
# Remove all lab challenge resources
kubectl delete -f labs/services/specs/ckad/lab-challenge-frontend.yaml
kubectl delete -f labs/services/specs/ckad/lab-challenge-backend.yaml
kubectl delete -f labs/services/specs/ckad/lab-challenge-database.yaml
kubectl delete -f labs/services/specs/ckad/lab-challenge-external.yaml
kubectl delete -f labs/services/specs/ckad/lab-challenge-networkpolicy.yaml

# Verify cleanup
kubectl get deployment,statefulset,service,networkpolicy -l kubernetes.courselabs.co=services
```

### Challenge Extensions

For additional practice, try:

1. **Add monitoring**: Deploy Prometheus to scrape backend metrics port
2. **Implement Ingress**: Replace LoadBalancer with Ingress for frontend
3. **Add init containers**: Database migration before app starts
4. **Configure resource limits**: Set CPU/memory for all Pods
5. **Add readiness probes**: Ensure Pods are ready before receiving traffic
6. **Implement canary deployment**: Roll out backend update to 25% of Pods
7. **Add PersistentVolume**: Persist database data across restarts
8. **Multi-namespace deployment**: Deploy tiers in separate namespaces

This challenge tests your understanding of:
- Service types and their use cases
- DNS service discovery
- Multi-port services
- Headless services with StatefulSets
- External service integration
- Session affinity
- NetworkPolicy for security
- Troubleshooting service connectivity

## Cleanup

Remove all CKAD practice resources:

```
kubectl delete pod,svc,deployment,statefulset -l kubernetes.courselabs.co=services

# If you created test namespaces
kubectl delete namespace ckad-services-test
```

## Further Reading

- [Service API Documentation](https://kubernetes.io/docs/concepts/services-networking/service/)
- [DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
- [EndpointSlices](https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/)
- [Service Topology](https://kubernetes.io/docs/concepts/services-networking/service-topology/) (advanced)

---

> Back to [basic Services lab](README.md) | [Course contents](../../README.md)
