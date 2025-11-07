# CKAD Ingress Lab Challenge

Build a production-ready ingress configuration for a multi-service application.

## Requirements

Deploy a three-tier application with the following specifications:

### 1. Application Services

- **Frontend**: Static web app (nginx) serving at `/`
- **Backend API**: REST API serving at `/api/*`
- **Admin Portal**: Management UI serving at `/admin/*`

All services must:
- Run at least 2 replicas (1 for admin)
- Have proper labels for service selection
- Use health checks (readiness and liveness probes)

### 2. Routing Configuration

- Single hostname: `myapp.example.com`
- Path-based routing to three services
- Default backend for unmatched paths (custom 404 page)
- Proper pathType selection (Prefix for most paths)

### 3. TLS Configuration

- HTTPS enabled with self-signed certificate
- HTTP automatically redirects to HTTPS
- Certificate covers `myapp.example.com`
- Use proper TLS secret type

### 4. Advanced Features

Implement the following using annotations:
- **API rate limiting**: 10 requests/second
- **Admin portal**: Basic authentication (use auth-secret)
- **Response caching**: Cache static assets for 5 minutes
- **CORS**: Enable CORS for API endpoints
- **Custom 404**: Deploy a custom 404 service as default backend

### 5. Multi-Environment Setup

Create separate configurations for three environments:
- **dev** namespace: `dev.myapp.example.com`
- **staging** namespace: `staging.myapp.example.com`
- **prod** namespace: `prod.myapp.example.com`

Each environment should:
- Have its own namespace
- Have all three services deployed
- Have separate Ingress resources
- Share the same TLS certificate (wildcard)

### 6. Troubleshooting Tasks

Fix the following broken configurations (in troubleshooting/ directory):
1. Ingress referencing service in wrong namespace
2. Service name typo causing 404 errors
3. Wrong pathType causing routing issues
4. Missing TLS secret
5. Service with no backend pods

## Success Criteria

- [ ] All paths route correctly (`/`, `/api/*`, `/admin/*`)
- [ ] HTTPS works with valid certificate (accept self-signed)
- [ ] HTTP requests redirect to HTTPS
- [ ] Rate limiting is active on API paths
- [ ] Admin portal requires authentication
- [ ] CORS headers present on API responses
- [ ] Can access app from each environment (dev/staging/prod)
- [ ] Custom 404 page appears for unmatched paths
- [ ] All troubleshooting issues identified and resolved

## Testing Commands

```bash
# Test routing
curl -H "Host: myapp.example.com" http://<ingress-ip>/
curl -H "Host: myapp.example.com" http://<ingress-ip>/api/users
curl -H "Host: myapp.example.com" http://<ingress-ip>/admin

# Test HTTPS
curl -k https://myapp.example.com/
openssl s_client -connect <ingress-ip>:443 -servername myapp.example.com

# Test rate limiting (should get 503 after 10 requests/second)
for i in {1..15}; do curl -H "Host: myapp.example.com" http://<ingress-ip>/api; done

# Test CORS
curl -H "Origin: https://external.com" -H "Host: myapp.example.com" \
  -v http://<ingress-ip>/api

# Test environments
curl -H "Host: dev.myapp.example.com" http://<ingress-ip>/
curl -H "Host: staging.myapp.example.com" http://<ingress-ip>/
curl -H "Host: prod.myapp.example.com" http://<ingress-ip>/
```

## Verification

```bash
# Check all Ingresses
kubectl get ingress --all-namespaces

# Check endpoints
kubectl get endpoints -n default
kubectl get endpoints -n dev
kubectl get endpoints -n staging
kubectl get endpoints -n prod

# Check TLS secrets
kubectl get secrets --all-namespaces | grep tls

# View Ingress details
kubectl describe ingress <name> -n <namespace>

# Check controller logs for errors
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

## Files to Create

Your solution should include:
- `frontend-deployment.yaml`
- `api-deployment.yaml`
- `admin-deployment.yaml`
- `default-backend-deployment.yaml`
- `services.yaml`
- `main-ingress.yaml`
- `tls-secret.yaml` (or script to generate)
- `auth-secret.yaml`
- `dev-namespace.yaml`
- `staging-namespace.yaml`
- `prod-namespace.yaml`
- `multi-env-ingress.yaml`

## Hints

- Use `kubectl create secret tls` for TLS secrets
- Use `kubectl create secret generic` with `--from-file=auth` for basic auth
- Generate auth file with: `htpasswd -c auth admin`
- Use nginx annotations reference: https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/
- Check Ingress controller logs for debugging: `kubectl logs -n ingress-nginx <controller-pod>`

## Time Expectation

This challenge should take 45-60 minutes for CKAD preparation.
