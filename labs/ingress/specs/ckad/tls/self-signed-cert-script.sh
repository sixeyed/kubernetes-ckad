#!/bin/bash
# Script to generate self-signed TLS certificates for testing Ingress HTTPS

set -e

echo "Generating self-signed TLS certificates..."

# Single domain certificate
echo ""
echo "1. Generating certificate for myapp.example.com..."
openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -nodes \
  -keyout myapp.key -out myapp.crt \
  -subj "/CN=myapp.example.com" \
  -addext "subjectAltName=DNS:myapp.example.com"

echo "   Created: myapp.crt and myapp.key"

# Multiple domain certificate
echo ""
echo "2. Generating certificate for app1.example.com and app2.example.com..."
openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -nodes \
  -keyout multi-app.key -out multi-app.crt \
  -subj "/CN=app1.example.com" \
  -addext "subjectAltName=DNS:app1.example.com,DNS:app2.example.com"

echo "   Created: multi-app.crt and multi-app.key"

# Wildcard certificate
echo ""
echo "3. Generating wildcard certificate for *.example.com..."
openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -nodes \
  -keyout wildcard.key -out wildcard.crt \
  -subj "/CN=*.example.com" \
  -addext "subjectAltName=DNS:*.example.com,DNS:example.com"

echo "   Created: wildcard.crt and wildcard.key"

echo ""
echo "Certificate generation complete!"
echo ""
echo "To create Kubernetes TLS secrets:"
echo "  kubectl create secret tls myapp-tls --cert=myapp.crt --key=myapp.key"
echo "  kubectl create secret tls multi-app-tls --cert=multi-app.crt --key=multi-app.key"
echo "  kubectl create secret tls wildcard-tls --cert=wildcard.crt --key=wildcard.key"
echo ""
echo "To view certificate details:"
echo "  openssl x509 -in myapp.crt -text -noout"
