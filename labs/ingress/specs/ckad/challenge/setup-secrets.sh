#!/bin/bash
# Setup script for challenge secrets

set -e

echo "Setting up secrets for CKAD Ingress Challenge..."

# Generate TLS certificates
echo ""
echo "1. Generating TLS certificates..."

# Single domain certificate
openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -nodes \
  -keyout myapp.key -out myapp.crt \
  -subj "/CN=myapp.example.com" \
  -addext "subjectAltName=DNS:myapp.example.com,DNS:admin.myapp.example.com" \
  2>/dev/null

echo "   Created: myapp.crt and myapp.key"

# Wildcard certificate for multi-env
openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -nodes \
  -keyout wildcard.key -out wildcard.crt \
  -subj "/CN=*.myapp.example.com" \
  -addext "subjectAltName=DNS:*.myapp.example.com,DNS:myapp.example.com" \
  2>/dev/null

echo "   Created: wildcard.crt and wildcard.key"

# Create TLS secrets
echo ""
echo "2. Creating TLS secrets in Kubernetes..."

kubectl create secret tls myapp-tls \
  --cert=myapp.crt \
  --key=myapp.key \
  --dry-run=client -o yaml | \
  kubectl label -f- --local=true kubernetes.courselabs.co=ingress -o yaml | \
  kubectl apply -f -

echo "   Created: myapp-tls secret in default namespace"

# Create wildcard secret in each environment namespace
for ns in dev staging prod; do
  kubectl create namespace $ns --dry-run=client -o yaml | kubectl apply -f -
  kubectl create secret tls wildcard-tls \
    --cert=wildcard.crt \
    --key=wildcard.key \
    --namespace=$ns \
    --dry-run=client -o yaml | \
    kubectl label -f- --local=true kubernetes.courselabs.co=ingress -o yaml | \
    kubectl apply -f -
  echo "   Created: wildcard-tls secret in $ns namespace"
done

# Create basic auth secret for admin
echo ""
echo "3. Creating basic auth secret..."

# Generate auth file (username: admin, password: password)
# Using htpasswd if available, otherwise openssl
if command -v htpasswd &> /dev/null; then
  htpasswd -bc auth admin password 2>/dev/null
else
  # Fallback: generate using openssl
  echo "admin:$(openssl passwd -apr1 password)" > auth
fi

kubectl create secret generic admin-auth \
  --from-file=auth \
  --dry-run=client -o yaml | \
  kubectl label -f- --local=true kubernetes.courselabs.co=ingress -o yaml | \
  kubectl apply -f -

echo "   Created: admin-auth secret (username: admin, password: password)"

# Clean up generated files
echo ""
echo "4. Cleaning up temporary files..."
rm -f myapp.key myapp.crt wildcard.key wildcard.crt auth
echo "   Cleaned up certificate and auth files"

echo ""
echo "Setup complete!"
echo ""
echo "Created secrets:"
echo "  - myapp-tls (default namespace)"
echo "  - wildcard-tls (dev, staging, prod namespaces)"
echo "  - admin-auth (default namespace)"
echo ""
echo "Admin credentials: admin / password"
echo ""
echo "You can now apply the challenge solution:"
echo "  kubectl apply -f solution.yaml"
