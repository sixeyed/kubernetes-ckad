# Ingress - CKAD Exam Topics

This document covers the CKAD exam requirements for Kubernetes Ingress. Make sure you've completed the [basic Ingress lab](README.md) first, as it covers fundamental concepts of Ingress controllers and routing.

## CKAD Ingress Requirements

The CKAD exam expects you to understand and work with:

- Ingress resource structure and rules
- Path types (Prefix, Exact, ImplementationSpecific)
- Host-based and path-based routing
- Multiple paths and backends in a single Ingress
- IngressClass and controller selection
- TLS/HTTPS configuration
- Default backends
- Annotations for controller-specific features
- Cross-namespace considerations
- Troubleshooting Ingress issues

## API Specs

- [Ingress (networking.k8s.io/v1)](https://kubernetes.io/docs/reference/kubernetes-api/service-resources/ingress-v1/)
- [IngressClass (networking.k8s.io/v1)](https://kubernetes.io/docs/reference/kubernetes-api/service-resources/ingress-class-v1/)

## Ingress Architecture Review

**Reminder from basic lab:**
- **Ingress Controller** - Reverse proxy (Nginx, Traefik, Contour, etc.)
- **Ingress Resources** - Kubernetes objects defining routing rules
- **Services** - Backends that Ingress routes to (must be ClusterIP or NodePort)

The controller watches for Ingress resources and configures itself accordingly.

## Path Types

Ingress supports three path matching types, critical for the exam:

### Prefix Path Type

Matches URL paths by prefix (most common):

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
spec:
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /app
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 8080
```

**Matches:**
- `/app` ✅
- `/app/` ✅
- `/app/page` ✅
- `/app/admin/dashboard` ✅

**Does NOT match:**
- `/application` ❌
- `/apps` ❌

### Exact Path Type

Matches only the exact path:

```yaml
paths:
- path: /api/health
  pathType: Exact
  backend:
    service:
      name: health-service
      port:
        number: 8080
```

**Matches:**
- `/api/health` ✅

**Does NOT match:**
- `/api/health/` ❌
- `/api/health/check` ❌
- `/api/healthcheck` ❌

### ImplementationSpecific Path Type

Matching depends on the Ingress controller implementation:

```yaml
paths:
- path: /admin
  pathType: ImplementationSpecific
  backend:
    service:
      name: admin-service
      port:
        number: 80
```

> Avoid using this in the exam unless specifically instructed

### Exercise: Understanding Path Types

Deploy applications and test different pathType behaviors:

```bash
# Deploy Prefix pathType example
kubectl apply -f labs/ingress/specs/ckad/path-types/prefix-ingress.yaml

# Test Prefix matching
kubectl get ingress -n path-types
INGRESS_IP=$(kubectl get ingress -n path-types prefix-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# These should all work with Prefix
curl -H "Host: pathtest.local" http://$INGRESS_IP/app
curl -H "Host: pathtest.local" http://$INGRESS_IP/app/
curl -H "Host: pathtest.local" http://$INGRESS_IP/app/page
curl -H "Host: pathtest.local" http://$INGRESS_IP/app/admin/dashboard

# These should NOT match
curl -H "Host: pathtest.local" http://$INGRESS_IP/application  # 404
curl -H "Host: pathtest.local" http://$INGRESS_IP/apps        # 404

# Deploy Exact pathType example
kubectl apply -f labs/ingress/specs/ckad/path-types/exact-ingress.yaml

# Test Exact matching
curl -H "Host: exactpath.local" http://$INGRESS_IP/api/health        # Works
curl -H "Host: exactpath.local" http://$INGRESS_IP/api/health/       # 404
curl -H "Host: exactpath.local" http://$INGRESS_IP/api/health/check  # 404 or works if defined

# Deploy mixed paths to see priority
kubectl apply -f labs/ingress/specs/ckad/path-types/mixed-paths.yaml

# Test path priority
curl -H "Host: mixedpaths.local" http://$INGRESS_IP/api/health  # Exact match -> health-svc
curl -H "Host: mixedpaths.local" http://$INGRESS_IP/api/v2/users  # Longer prefix -> api-v2-svc
curl -H "Host: mixedpaths.local" http://$INGRESS_IP/api/users     # Shorter prefix -> api-svc
```

**Key takeaways:**
- Prefix matches the path and anything under it
- Exact matches only that specific path
- Longer prefixes take priority over shorter ones
- Exact matches take priority over Prefix matches

## Host-Based Routing

Route traffic based on the HTTP Host header:

### Single Host

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: single-host
spec:
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 80
```

### Multiple Hosts

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-host
spec:
  rules:
  - host: app1.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app1-service
            port:
              number: 80
  - host: app2.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app2-service
            port:
              number: 80
```

### Wildcard Hosts

Some controllers support wildcard domains:

```yaml
rules:
- host: "*.example.com"
  http:
    paths:
    - path: /
      pathType: Prefix
      backend:
        service:
          name: wildcard-service
          port:
            number: 80
```

> Check your controller documentation - not all support wildcards

### Exercise: Host-Based Routing

Deploy applications and configure host-based routing:

```bash
# Deploy single host example
kubectl apply -f labs/ingress/specs/ckad/host-routing/single-host.yaml

# Test single host
INGRESS_IP=$(kubectl get ingress -n single-host single-host-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -H "Host: app.example.com" http://$INGRESS_IP/

# Deploy multi-host example
kubectl apply -f labs/ingress/specs/ckad/host-routing/multi-host.yaml

# Test different hosts routing to different backends
curl -H "Host: app1.example.com" http://$INGRESS_IP/
curl -H "Host: app2.example.com" http://$INGRESS_IP/
curl -H "Host: app3.example.com" http://$INGRESS_IP/

# Each should return different backend responses (check WHOAMI_ENVIRONMENT)

# For local testing, add entries to /etc/hosts (requires sudo)
echo "$INGRESS_IP app1.example.com app2.example.com app3.example.com" | sudo tee -a /etc/hosts

# Now you can test without Host header
curl http://app1.example.com/
curl http://app2.example.com/

# Deploy wildcard host example (if supported by your controller)
kubectl apply -f labs/ingress/specs/ckad/host-routing/wildcard-host.yaml

# Test wildcard matching
curl -H "Host: test.example.com" http://$INGRESS_IP/
curl -H "Host: anything.example.com" http://$INGRESS_IP/
```

**Key takeaways:**
- Host header determines which rule matches
- Multiple hosts can route to different backends
- Wildcard hosts (*.example.com) match any subdomain
- Use /etc/hosts for local testing without DNS
- Specific hosts take precedence over wildcards

## Path-Based Routing

Route to different backends based on URL path:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-routing
spec:
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
      - path: /web
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
      - path: /admin
        pathType: Prefix
        backend:
          service:
            name: admin-service
            port:
              number: 3000
```

**Routing behavior:**
- `myapp.example.com/api/users` → api-service:8080
- `myapp.example.com/web/dashboard` → web-service:80
- `myapp.example.com/admin/settings` → admin-service:3000

### Path Priority and Ordering

When multiple paths could match:
1. Exact matches take priority over Prefix
2. Longer Prefix paths take priority over shorter ones
3. Order in the spec may matter (controller-specific)

**Example:**

```yaml
paths:
- path: /api/v2
  pathType: Prefix
  backend:
    service:
      name: api-v2-service
      port:
        number: 8080
- path: /api
  pathType: Prefix
  backend:
    service:
      name: api-v1-service
      port:
        number: 8080
```

Request `/api/v2/users` matches both, but goes to api-v2-service (longer prefix).

### Exercise: Path-Based Routing

Deploy multiple services and route based on path:

```bash
# Deploy multi-path example
kubectl apply -f labs/ingress/specs/ckad/path-routing/multi-path.yaml

# Test different paths routing to different services
INGRESS_IP=$(kubectl get ingress -n multi-path multi-path-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

curl -H "Host: myapp.example.com" http://$INGRESS_IP/api/users      # -> api-svc:8080
curl -H "Host: myapp.example.com" http://$INGRESS_IP/web/dashboard  # -> web-svc:80
curl -H "Host: myapp.example.com" http://$INGRESS_IP/admin/settings # -> admin-svc:3000

# Check which backend responded (look for WHOAMI_ENVIRONMENT)

# Deploy path priority example
kubectl apply -f labs/ingress/specs/ckad/path-routing/path-priority.yaml

# Test path priority with overlapping paths
curl -H "Host: priority.example.com" http://$INGRESS_IP/api/v2/admin/users  # -> api-v2-admin-svc
curl -H "Host: priority.example.com" http://$INGRESS_IP/api/v2/users        # -> api-v2-svc
curl -H "Host: priority.example.com" http://$INGRESS_IP/api/users           # -> api-v1-svc

# Deploy combined host and path routing
kubectl apply -f labs/ingress/specs/ckad/path-routing/combined-host-path.yaml

# Test combinations
curl -H "Host: api.example.com" http://$INGRESS_IP/v1/users      # -> api-v1-svc
curl -H "Host: api.example.com" http://$INGRESS_IP/v2/users      # -> api-v2-svc
curl -H "Host: admin.example.com" http://$INGRESS_IP/            # -> admin-svc
curl -H "Host: web.example.com" http://$INGRESS_IP/              # -> web-svc
```

**Key takeaways:**
- Single Ingress can route multiple paths to different services
- Path priority: longer prefixes match before shorter ones
- Combine host and path rules for complex routing
- Order in spec matters when paths could overlap
- Services can use different port numbers

## Combining Host and Path Routing

Complex routing combining both host and path rules:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: complex-routing
spec:
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /v1
        pathType: Prefix
        backend:
          service:
            name: api-v1
            port:
              number: 8080
      - path: /v2
        pathType: Prefix
        backend:
          service:
            name: api-v2
            port:
              number: 8080
  - host: admin.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: admin-portal
            port:
              number: 80
```

**Example deployment:** See `labs/ingress/specs/ckad/path-routing/combined-host-path.yaml` for a complete implementation combining multiple hosts with path-based routing to different service versions.

## IngressClass

IngressClass allows multiple Ingress controllers in a cluster:

### Defining IngressClass

```yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: nginx
spec:
  controller: k8s.io/ingress-nginx
```

### Using IngressClass in Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
spec:
  ingressClassName: nginx  # Specifies which controller to use
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 80
```

### Default IngressClass

Mark one IngressClass as default:

```yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: nginx
  annotations:
    ingressclass.kubernetes.io/is-default-class: "true"
spec:
  controller: k8s.io/ingress-nginx
```

Ingresses without `ingressClassName` use the default.

### Exercise: Working with IngressClass

Understand IngressClass and controller selection:

```bash
# View existing IngressClasses
kubectl get ingressclass

# Check which is default (look for ingressclass.kubernetes.io/is-default-class annotation)
kubectl get ingressclass -o yaml

# View example IngressClass definitions
cat labs/ingress/specs/ckad/ingressclass/nginx-class.yaml
cat labs/ingress/specs/ckad/ingressclass/traefik-class.yaml

# Deploy example with explicit IngressClass
kubectl apply -f labs/ingress/specs/ckad/ingressclass/ingress-with-class.yaml

# Check both Ingresses
kubectl get ingress -n ingressclass-demo

# Describe to see which controller is handling each
kubectl describe ingress ingress-with-class -n ingressclass-demo
kubectl describe ingress ingress-default-class -n ingressclass-demo

# Change IngressClass for an existing Ingress
kubectl edit ingress ingress-with-class -n ingressclass-demo
# Modify spec.ingressClassName to different value

# Verify controller reassignment
kubectl describe ingress ingress-with-class -n ingressclass-demo
```

**Key takeaways:**
- IngressClass separates which controller handles which Ingress
- One IngressClass can be marked as default
- Explicitly specify `ingressClassName` for predictable behavior
- Multiple controllers can coexist in same cluster
- Changing IngressClass moves Ingress to different controller

## TLS/HTTPS Configuration

Configure TLS certificates for HTTPS traffic:

### Creating TLS Secret

From the basic lab's [ingress-https.md](ingress-https.md):

```
kubectl create secret tls my-tls-secret \
  --cert=path/to/cert.pem \
  --key=path/to/key.pem
```

### Using TLS in Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
spec:
  tls:
  - hosts:
    - myapp.example.com
    secretName: my-tls-secret
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 80
```

**Behavior:**
- HTTPS traffic uses the TLS certificate
- HTTP traffic may be redirected to HTTPS (controller-dependent)
- Certificate must match the hostname

### Multiple TLS Certificates

Different certs for different hosts:

```yaml
spec:
  tls:
  - hosts:
    - app1.example.com
    secretName: app1-tls
  - hosts:
    - app2.example.com
    secretName: app2-tls
  rules:
  - host: app1.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app1-service
            port:
              number: 80
  - host: app2.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app2-service
            port:
              number: 80
```

### Wildcard TLS Certificates

Single cert for multiple subdomains:

```yaml
spec:
  tls:
  - hosts:
    - "*.example.com"
    secretName: wildcard-tls
  rules:
  - host: app1.example.com
    # ... rules ...
  - host: app2.example.com
    # ... rules ...
```

### Exercise: Configuring TLS/HTTPS

Set up HTTPS with TLS certificates:

```bash
# Step 1: Generate self-signed certificates
cd labs/ingress/specs/ckad/tls
./self-signed-cert-script.sh

# This creates:
# - myapp.crt and myapp.key (single domain)
# - multi-app.crt and multi-app.key (multiple domains)
# - wildcard.crt and wildcard.key (wildcard cert)

# Step 2: Create TLS secret
kubectl create secret tls myapp-tls \
  --cert=myapp.crt \
  --key=myapp.key \
  -n tls-demo

# Verify secret type
kubectl get secret myapp-tls -n tls-demo -o yaml

# Step 3: Deploy app with HTTPS Ingress
kubectl apply -f labs/ingress/specs/ckad/tls/ingress-with-tls.yaml

# Step 4: Test HTTPS connection
INGRESS_IP=$(kubectl get ingress -n tls-demo tls-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test HTTPS (use -k for self-signed cert)
curl -k -H "Host: myapp.example.com" https://$INGRESS_IP/

# Test HTTP redirect to HTTPS
curl -v -H "Host: myapp.example.com" http://$INGRESS_IP/
# Should see 308 redirect to HTTPS

# Step 5: View certificate details
openssl s_client -connect $INGRESS_IP:443 -servername myapp.example.com < /dev/null 2>/dev/null | openssl x509 -text -noout

# Or from secret
kubectl get secret myapp-tls -n tls-demo -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout

# Step 6: Deploy multi-cert example
kubectl create secret tls app1-tls --cert=multi-app.crt --key=multi-app.key -n multi-cert
kubectl create secret tls app2-tls --cert=multi-app.crt --key=multi-app.key -n multi-cert

kubectl apply -f labs/ingress/specs/ckad/tls/multi-cert-ingress.yaml

# Test different hosts with different certs
curl -k -H "Host: app1.example.com" https://$INGRESS_IP/
curl -k -H "Host: app2.example.com" https://$INGRESS_IP/

# Cleanup
cd -
```

**Key takeaways:**
- TLS secrets must be type `kubernetes.io/tls`
- Secrets must be in same namespace as Ingress
- Certificate must match hostname in Host header
- Most controllers redirect HTTP to HTTPS automatically
- Wildcard certs cover multiple subdomains
- Each host can have different certificate

## Default Backend

Fallback service when no rules match:

### Controller Default Backend

Most controllers have built-in default backends (404 page).

### Custom Default Backend in Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-with-default
spec:
  defaultBackend:
    service:
      name: default-service
      port:
        number: 80
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
```

**Behavior:**
- Requests to `app.example.com/other` → default-service
- Requests to unknown hosts → default-service
- Requests to `app.example.com/api` → api-service

**Example:** See `labs/ingress/specs/ckad/default-backend-example.yaml` for a complete demonstration of default backend behavior with test scenarios.

## Annotations

Controller-specific features via annotations:

### Common Nginx Annotations

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: annotated-ingress
  annotations:
    # Rewrite target path
    nginx.ingress.kubernetes.io/rewrite-target: /

    # Enable CORS
    nginx.ingress.kubernetes.io/enable-cors: "true"

    # SSL redirect
    nginx.ingress.kubernetes.io/ssl-redirect: "true"

    # Rate limiting
    nginx.ingress.kubernetes.io/limit-rps: "10"

    # Client body size
    nginx.ingress.kubernetes.io/proxy-body-size: "8m"

    # Response caching (from basic lab)
    nginx.ingress.kubernetes.io/proxy-cache-valid: "200 30m"
spec:
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 80
```

### Rewrite Target

Transform request paths before sending to backend:

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /api(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
```

**Request transformation:**
- Client requests: `/api/users`
- Backend receives: `/users`

### HTTP to HTTPS Redirect

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
```

### Custom Timeouts

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "60"
```

### Exercise: Using Annotations

Configure advanced features using annotations:

```bash
# 1. Deploy rewrite-target example
kubectl apply -f labs/ingress/specs/ckad/annotations/rewrite-target.yaml

# Test path rewriting
INGRESS_IP=$(kubectl get ingress -n rewrite-demo rewrite-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Request to /backend/api/users is rewritten to /api/users by backend
curl -H "Host: rewrite.example.com" http://$INGRESS_IP/backend/api/users

# Simple rewrite - all paths rewritten to /
curl -H "Host: simple-rewrite.example.com" http://$INGRESS_IP/api/anything

# 2. Deploy CORS-enabled example
kubectl apply -f labs/ingress/specs/ckad/annotations/cors-enabled.yaml

# Test CORS headers
curl -v -H "Origin: https://external.com" -H "Host: api.example.com" http://$INGRESS_IP/
# Look for Access-Control-Allow-Origin header in response

# 3. Deploy rate limiting example
kubectl apply -f labs/ingress/specs/ckad/annotations/rate-limiting.yaml

# Test rate limit (should succeed first 10, then 503 errors)
for i in {1..15}; do
  curl -s -o /dev/null -w "%{http_code}\n" -H "Host: rps-limited.example.com" http://$INGRESS_IP/
  sleep 0.1
done

# 4. Deploy custom timeouts example
kubectl apply -f labs/ingress/specs/ckad/annotations/custom-timeouts.yaml

# Check annotations in Ingress
kubectl get ingress -n timeouts-demo custom-timeouts -o yaml | grep annotations -A 10
```

**Key takeaways:**
- Annotations enable controller-specific features
- `rewrite-target` transforms request paths
- CORS annotations control cross-origin access
- Rate limiting protects against abuse
- Timeout settings handle slow backends
- Different controllers support different annotations
- Check your controller's documentation for available annotations

## Cross-Namespace Considerations

### Ingress and Service Namespaces

**Important:** Ingress can only reference Services in the **same namespace**.

```yaml
# In namespace: app-namespace
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
  namespace: app-namespace  # Must match Service namespace
spec:
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service  # Must exist in app-namespace
            port:
              number: 80
```

### Multi-Namespace Routing Pattern

Create separate Ingresses in each namespace:

```yaml
# Namespace: frontend
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: frontend-ingress
  namespace: frontend
spec:
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
---
# Namespace: api
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-ingress
  namespace: api
spec:
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
```

**Result:** Single host routes to services in different namespaces.

### ExternalName Service Workaround

To reference services across namespaces (advanced pattern):

```yaml
# In namespace: app-namespace
apiVersion: v1
kind: Service
metadata:
  name: cross-ns-service
  namespace: app-namespace
spec:
  type: ExternalName
  externalName: service-name.other-namespace.svc.cluster.local
```

Then reference `cross-ns-service` in your Ingress.

### Exercise: Cross-Namespace Routing

Work with Ingress across multiple namespaces:

```bash
# Deploy services in multiple namespaces
kubectl apply -f labs/ingress/specs/ckad/namespaces/multi-namespace-setup.yaml

# Verify services in each namespace
kubectl get svc -n frontend
kubectl get svc -n api
kubectl get svc -n admin

# Deploy Ingress resources in each namespace
kubectl apply -f labs/ingress/specs/ckad/namespaces/cross-namespace-routing.yaml

# Verify Ingresses created in each namespace
kubectl get ingress -n frontend
kubectl get ingress -n api
kubectl get ingress -n admin

# Test routing to same host from different namespaces
INGRESS_IP=$(kubectl get ingress -n frontend frontend-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

curl -H "Host: app.example.com" http://$INGRESS_IP/           # -> frontend namespace
curl -H "Host: app.example.com" http://$INGRESS_IP/api        # -> api namespace
curl -H "Host: app.example.com" http://$INGRESS_IP/admin      # -> admin namespace

# Test host-based routing per namespace
curl -H "Host: web.example.com" http://$INGRESS_IP/           # -> frontend namespace
curl -H "Host: api.example.com" http://$INGRESS_IP/           # -> api namespace
curl -H "Host: admin.example.com" http://$INGRESS_IP/         # -> admin namespace

# Try to create Ingress referencing service in different namespace (will fail)
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: broken-cross-ns
  namespace: frontend
spec:
  rules:
  - host: broken.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-svc  # This service is in 'api' namespace, not 'frontend'
            port:
              number: 8080
EOF

# Check - it creates but won't work
kubectl get endpoints -n frontend
# No endpoints for api-svc because it's in different namespace
```

**Key takeaways:**
- Ingress can only reference Services in same namespace
- Create separate Ingresses per namespace for isolation
- Same hostname can be used across namespaces with different paths
- ExternalName Services can work around namespace limitation (advanced)
- Namespace isolation is important for security

## Troubleshooting Ingress

### Common Issues

**1. Ingress Created But Not Working**

```
# Check Ingress status
kubectl get ingress
kubectl describe ingress <name>

# Look for:
# - Address field populated
# - Events showing controller processing
# - Backend service exists
```

**Common causes:**
- Ingress controller not installed
- Wrong IngressClass specified
- Service doesn't exist
- Service in different namespace

**2. 404 Not Found**

```
# Verify Service exists
kubectl get svc <service-name>

# Check Service endpoints
kubectl get endpoints <service-name>

# Verify path and pathType
kubectl describe ingress <name>
```

**Common causes:**
- Path doesn't match request
- PathType incorrect (Exact vs Prefix)
- No Pods backing the Service
- Service selector doesn't match Pods

**3. 502 Bad Gateway / 503 Service Unavailable**

```
# Check Pod status
kubectl get pods -l <service-selector>

# Check Pod readiness
kubectl describe pod <pod-name>

# Test Service directly
kubectl port-forward svc/<service-name> 8080:80
curl localhost:8080
```

**Common causes:**
- Pods not ready
- Service port mismatch
- Application not listening on expected port
- Readiness probe failing

**4. TLS/HTTPS Issues**

```
# Verify TLS Secret exists
kubectl get secret <tls-secret>

# Check Secret type
kubectl get secret <tls-secret> -o yaml

# Verify certificate
kubectl get secret <tls-secret> -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
```

**Common causes:**
- Secret doesn't exist
- Secret wrong type (not `kubernetes.io/tls`)
- Certificate expired
- Hostname doesn't match certificate

**5. Host Header Not Matching**

```
# Test with curl specifying Host header
curl -H "Host: app.example.com" http://<ingress-ip>

# Check exact hostname in Ingress
kubectl get ingress <name> -o yaml
```

**Common causes:**
- DNS not configured
- /etc/hosts not updated
- Typo in hostname
- Wildcard not supported

### Exercise: Troubleshooting Broken Ingress

Practice debugging common Ingress issues:

```bash
# Deploy broken configurations
kubectl apply -f labs/ingress/specs/ckad/troubleshooting/broken-ingress-1.yaml
kubectl apply -f labs/ingress/specs/ckad/troubleshooting/broken-ingress-2.yaml
kubectl apply -f labs/ingress/specs/ckad/troubleshooting/broken-ingress-3.yaml
kubectl apply -f labs/ingress/specs/ckad/troubleshooting/broken-ingress-4.yaml
kubectl apply -f labs/ingress/specs/ckad/troubleshooting/broken-ingress-5.yaml

# Problem 1: Wrong namespace
kubectl get ingress broken-namespace-ingress
kubectl describe ingress broken-namespace-ingress
# Issue: Service 'web-svc' doesn't exist in default namespace
kubectl get svc -n default | grep web-svc  # Not found
kubectl get svc -n apps | grep web-svc     # Found here!
# Solution: Move Ingress to 'apps' namespace or use fixed version

# Problem 2: Service doesn't exist
kubectl describe ingress broken-service-ingress -n troubleshoot-2
kubectl get svc -n troubleshoot-2
# Issue: Ingress references 'api-svc' but service is named 'api-service'
# Solution: Fix service name in Ingress spec

# Problem 3: Wrong pathType
kubectl get ingress -n troubleshoot-3
INGRESS_IP=$(kubectl get ingress -n troubleshoot-3 -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')
curl -H "Host: broken3.example.com" http://$INGRESS_IP/api        # Works
curl -H "Host: broken3.example.com" http://$INGRESS_IP/api/users  # 404!
# Issue: pathType is Exact, should be Prefix
# Solution: Change pathType to Prefix for /api path

# Problem 4: TLS secret missing
kubectl describe ingress broken-tls-missing -n troubleshoot-4
kubectl get secret -n troubleshoot-4
# Issue: Secret 'missing-tls-secret' doesn't exist
# Solution: Create TLS secret or reference existing one

# Problem 5: No backend pods
kubectl get ingress -n troubleshoot-5
kubectl get endpoints broken-svc -n troubleshoot-5
# Endpoints is empty!
kubectl get pods -n troubleshoot-5 -l app=api-service
# Pods exist but don't match service selector
kubectl describe svc broken-svc -n troubleshoot-5
# Service selector: app=api-service
kubectl get pods -n troubleshoot-5 --show-labels
# Pod labels: app=broken-app (mismatch!)
# Solution: Fix service selector or pod labels

# Cleanup broken examples
kubectl delete namespace troubleshoot-2 troubleshoot-3 troubleshoot-4 troubleshoot-5
kubectl delete ingress broken-namespace-ingress
kubectl delete namespace apps
```

### Troubleshooting Decision Tree

```
Ingress not working?
│
├─ Can't create Ingress?
│  ├─ Check Ingress controller installed
│  └─ Check IngressClass exists
│
├─ Ingress created but no IP/address?
│  ├─ Check controller pods running
│  ├─ Check IngressClass matches controller
│  └─ Wait (may take 30-60 seconds)
│
├─ 404 Not Found?
│  ├─ Check service exists: kubectl get svc
│  ├─ Check same namespace
│  ├─ Check path matches (Exact vs Prefix)
│  ├─ Check endpoints exist: kubectl get endpoints
│  └─ Check Host header matches
│
├─ 502/503 Error?
│  ├─ Check pods running: kubectl get pods
│  ├─ Check pods ready
│  ├─ Check service selector matches pods
│  ├─ Check service port matches container port
│  └─ Test service directly: kubectl port-forward
│
├─ TLS/HTTPS not working?
│  ├─ Check secret exists: kubectl get secret
│  ├─ Check secret type is kubernetes.io/tls
│  ├─ Check certificate valid: openssl x509 -in cert -text
│  ├─ Check hostname matches certificate
│  └─ Check secret in same namespace as Ingress
│
└─ Right backend but wrong response?
   ├─ Check annotations (rewrite-target, etc)
   ├─ Check multiple Ingress rules
   └─ Check path priority
```

## Port References

You can reference Service ports by name or number:

### By Port Number

```yaml
backend:
  service:
    name: app-service
    port:
      number: 8080
```

### By Port Name

```yaml
backend:
  service:
    name: app-service
    port:
      name: http
```

**Service must have named port:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: app-service
spec:
  selector:
    app: myapp
  ports:
  - name: http
    port: 8080
    targetPort: 8080
```

**Benefits of named ports:**
- More readable
- Port number can change without updating Ingress

**Example:** See `labs/ingress/specs/ckad/port-name-example.yaml` for complete examples comparing port number and name references in various scenarios.

## CKAD Exam Tips

### Speed Commands

```bash
# Generate Ingress YAML (Kubernetes 1.19+)
kubectl create ingress my-ingress \
  --rule="host.example.com/path*=service:port" \
  --dry-run=client -o yaml > ingress.yaml

# Examples:
kubectl create ingress simple \
  --rule="app.example.com/=app-svc:80"

kubectl create ingress multi-path \
  --rule="app.example.com/api/*=api-svc:8080" \
  --rule="app.example.com/web/*=web-svc:80"

# With TLS
kubectl create ingress tls-ingress \
  --rule="secure.example.com/=app-svc:443,tls=my-tls-secret"
```

### Quick Verification

```bash
# Check Ingress
kubectl get ingress
kubectl describe ingress <name>

# Test with curl
curl -H "Host: app.example.com" http://<ingress-ip>

# Check controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# Verify backend service
kubectl get svc <service-name>
kubectl get endpoints <service-name>
```

### Common Exam Patterns

**Pattern 1: Expose existing deployment**
```bash
# Create deployment and service
kubectl create deployment web --image=nginx
kubectl expose deployment web --port=80

# Create Ingress
kubectl create ingress web \
  --rule="web.example.com/=web:80" \
  --dry-run=client -o yaml | kubectl apply -f -
```

**Pattern 2: Fix broken Ingress**
```bash
# Check Ingress definition
kubectl get ingress <name> -o yaml

# Verify service exists in same namespace
kubectl get svc -n <namespace>

# Check events
kubectl describe ingress <name>
```

**Pattern 3: Add TLS to existing Ingress**
```bash
# Create TLS secret
kubectl create secret tls my-tls --cert=tls.crt --key=tls.key

# Edit Ingress to add TLS section
kubectl edit ingress <name>
```

### Rapid-Fire CKAD Practice Scenarios

Quick practice scenarios for exam preparation:

**Scenario 1:** Create Ingress for existing service
```bash
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80
kubectl create ingress nginx --rule="web.example.com/=nginx:80"
```

**Scenario 2:** Add TLS to Ingress
```bash
kubectl create secret tls web-tls --cert=cert.pem --key=key.pem
kubectl edit ingress nginx  # Add spec.tls section
```

**Scenario 3:** Route /api to api-svc and /web to web-svc
```bash
kubectl create ingress multi-path \
  --rule="app.example.com/api*=api-svc:8080" \
  --rule="app.example.com/web*=web-svc:80"
```

**Scenario 4:** Fix Ingress with wrong service name
```bash
kubectl get ingress broken -o yaml | sed 's/wrong-svc/correct-svc/' | kubectl apply -f -
```

**Scenario 5:** Check why Ingress returns 503
```bash
kubectl get endpoints <service-name>  # Check if empty
kubectl get pods -l <service-selector>  # Check if pods exist
kubectl describe svc <service-name>  # Check selector
```

**Scenario 6:** Enable CORS on API Ingress
```bash
kubectl annotate ingress api-ingress \
  nginx.ingress.kubernetes.io/enable-cors="true" \
  nginx.ingress.kubernetes.io/cors-allow-origin="*"
```

**Scenario 7:** Add rate limiting (100 req/min)
```bash
kubectl annotate ingress api-ingress \
  nginx.ingress.kubernetes.io/limit-rpm="100"
```

**Scenario 8:** Rewrite /backend/api to /api
```bash
kubectl annotate ingress api-ingress \
  nginx.ingress.kubernetes.io/rewrite-target='/$2'
# Change path to: /backend(/|$)(.*)
```

**Scenario 9:** Force HTTPS redirect
```bash
kubectl annotate ingress web-ingress \
  nginx.ingress.kubernetes.io/ssl-redirect="true" \
  nginx.ingress.kubernetes.io/force-ssl-redirect="true"
```

**Scenario 10:** Change Ingress to use different IngressClass
```bash
kubectl patch ingress my-ingress -p '{"spec":{"ingressClassName":"nginx"}}'
```

## Lab Challenge: Complete Multi-Service Application

Build a production-ready ingress configuration with multiple advanced features.

### Challenge Overview

Deploy a complete three-tier application with sophisticated routing, TLS, authentication, and multi-environment support. This challenge tests all CKAD Ingress skills.

### Requirements

1. **Three-Tier Application**
   - Frontend: Static web app (nginx) serving at `/`
   - Backend API: REST API serving at `/api/*`
   - Admin Portal: Management UI serving at `/admin/*`
   - All services with health checks and multiple replicas

2. **Routing Requirements**
   - Single hostname: `myapp.example.com`
   - Path-based routing to three services
   - Custom default backend with 404 page
   - Proper pathType selection

3. **TLS Configuration**
   - HTTPS enabled with self-signed certificate
   - HTTP automatically redirects to HTTPS
   - Certificate covers `myapp.example.com`
   - Valid TLS secret configuration

4. **Advanced Features (Annotations)**
   - API rate limiting: 10 requests/second
   - Admin portal: Basic authentication
   - Response caching: 5 minutes for static assets
   - CORS enabled for API endpoints
   - Custom 404 service as default backend

5. **Multi-Environment Setup**
   - Three namespaces: `dev`, `staging`, `prod`
   - Different hostnames: `dev.myapp.example.com`, etc.
   - Separate Ingress resources per environment
   - Wildcard TLS certificate shared across environments
   - Environment-specific configurations

6. **Troubleshooting Tasks**
   - Fix five intentionally broken Ingress configurations
   - Practice systematic debugging approach
   - Document issues and solutions

### Getting Started

```bash
# Setup secrets first
cd labs/ingress/specs/ckad/challenge
./setup-secrets.sh

# This creates:
# - TLS secrets (myapp-tls, wildcard-tls in each namespace)
# - Basic auth secret (admin-auth)
# - Admin credentials: admin / password

# Deploy the complete solution
kubectl apply -f solution.yaml

# Verify deployment
kubectl get all,ingress --all-namespaces | grep courselabs

# Test the application
INGRESS_IP=$(kubectl get ingress main-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test main routes
curl -k -H "Host: myapp.example.com" https://$INGRESS_IP/
curl -k -H "Host: myapp.example.com" https://$INGRESS_IP/api
curl -k -H "Host: myapp.example.com" https://$INGRESS_IP/admin

# Test HTTP redirect
curl -v -H "Host: myapp.example.com" http://$INGRESS_IP/

# Test rate limiting (should get 503 after 10 req/sec)
for i in {1..15}; do curl -s -o /dev/null -w "%{http_code}\n" -k -H "Host: myapp.example.com" https://$INGRESS_IP/api; sleep 0.1; done

# Test CORS
curl -v -k -H "Origin: https://external.com" -H "Host: myapp.example.com" https://$INGRESS_IP/api

# Test admin authentication (separate host with basic auth)
curl -k -H "Host: admin.myapp.example.com" https://$INGRESS_IP/  # Should get 401
curl -k -u admin:password -H "Host: admin.myapp.example.com" https://$INGRESS_IP/  # Should work

# Test environments
curl -k -H "Host: dev.myapp.example.com" https://$INGRESS_IP/
curl -k -H "Host: staging.myapp.example.com" https://$INGRESS_IP/
curl -k -H "Host: prod.myapp.example.com" https://$INGRESS_IP/

# Test custom 404
curl -k -H "Host: myapp.example.com" https://$INGRESS_IP/nonexistent
```

### Success Criteria

- [ ] All paths route to correct services (`/`, `/api/*`, `/admin/*`)
- [ ] HTTPS works with self-signed certificate
- [ ] HTTP requests redirect to HTTPS (308 status)
- [ ] Rate limiting returns 503 after 10 requests/second
- [ ] Admin portal requires authentication (401 without credentials)
- [ ] CORS headers present in API responses
- [ ] All three environments accessible (dev, staging, prod)
- [ ] Custom 404 page displays for unmatched paths
- [ ] TLS certificates valid for all hostnames
- [ ] No endpoint errors (all services have backend pods)

### Troubleshooting Practice

After completing the main challenge, practice debugging:

```bash
# Deploy broken configurations
kubectl apply -f labs/ingress/specs/ckad/troubleshooting/broken-ingress-1.yaml
kubectl apply -f labs/ingress/specs/ckad/troubleshooting/broken-ingress-2.yaml
kubectl apply -f labs/ingress/specs/ckad/troubleshooting/broken-ingress-3.yaml
kubectl apply -f labs/ingress/specs/ckad/troubleshooting/broken-ingress-4.yaml
kubectl apply -f labs/ingress/specs/ckad/troubleshooting/broken-ingress-5.yaml

# Debug each issue systematically
# See troubleshooting section for hints
```

### Challenge Resources

Complete specifications available in:
- `labs/ingress/specs/ckad/challenge/README.md` - Full challenge instructions
- `labs/ingress/specs/ckad/challenge/solution.yaml` - Complete working solution
- `labs/ingress/specs/ckad/challenge/setup-secrets.sh` - Secret generation script

### Time Expectation

- **Setup**: 10 minutes
- **Main challenge**: 30-45 minutes
- **Troubleshooting**: 15-20 minutes
- **Total**: 60-75 minutes for complete CKAD preparation

## Quick Reference Card

### Basic Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: basic-ingress
spec:
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 80
```

### With TLS

```yaml
spec:
  tls:
  - hosts:
    - app.example.com
    secretName: app-tls
  rules:
  # ... rules ...
```

### With IngressClass

```yaml
spec:
  ingressClassName: nginx
  rules:
  # ... rules ...
```

### Multiple Paths

```yaml
spec:
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-svc
            port:
              number: 8080
      - path: /web
        pathType: Prefix
        backend:
          service:
            name: web-svc
            port:
              number: 80
```

### Common Annotations

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/limit-rps: "10"
```

## Cleanup

```
kubectl delete all,secret,ingress,ingressclass -l kubernetes.courselabs.co=ingress

# If you created test namespaces
kubectl delete namespace dev staging prod
```

## Further Reading

- [Ingress Documentation](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [Ingress Controllers](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/)
- [Nginx Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [Nginx Annotations](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/)
- [TLS Certificates with cert-manager](https://cert-manager.io/docs/)

---

> Back to [basic Ingress lab](README.md) | [HTTPS setup](ingress-https.md) | [Course contents](../../README.md)
