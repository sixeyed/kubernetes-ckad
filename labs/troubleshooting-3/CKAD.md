# Advanced Troubleshooting for CKAD

This document extends the [basic troubleshooting-3 lab](README.md) with advanced troubleshooting scenarios useful for CKAD preparation.

## CKAD Context

While marked as "Beyond CKAD," these advanced troubleshooting skills are valuable:
- Helm chart debugging (Helm is CKAD curriculum)
- Ingress troubleshooting (networking is core CKAD)
- StatefulSet issues (stateful apps are CKAD topics)

**Note:** The exam focuses on troubleshooting standard resources, but understanding Helm and Ingress issues helps with real-world CKAD scenarios.

## Advanced Troubleshooting Areas

### 1. Helm Chart Troubleshooting

Common Helm deployment issues:

#### Issue: Template Rendering Errors

**Symptom**: `helm install` fails with template error

```bash
# Error example
Error: template: mychart/templates/deployment.yaml:15:18:
executing "mychart/templates/deployment.yaml" at <.Values.image.tag>:
nil pointer evaluating interface {}.tag
```

**Diagnosis**:
```bash
# Check template rendering without installing
helm template myapp ./mychart

# Check with specific values
helm template myapp ./mychart --set image.tag=v1.0

# Validate chart
helm lint ./mychart
```

**Fix**:
```yaml
# In templates/deployment.yaml - add default
image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default "latest" }}"
```

#### Issue: Values Not Applied

**Symptom**: Deployment uses default values instead of custom values

**Diagnosis**:
```bash
# Check what values Helm used
helm get values myapp

# Check the manifest Helm generated
helm get manifest myapp

# Compare with values file
cat values.yaml
```

**Fix**:
```bash
# Ensure values file is specified
helm install myapp ./mychart -f custom-values.yaml

# Or use --set for specific overrides
helm install myapp ./mychart --set replicaCount=3
```

### 2. Ingress Troubleshooting

Common Ingress controller and routing issues:

#### Issue: Ingress Not Routing Traffic

**Symptom**: 404 Not Found when accessing Ingress host

**Diagnosis**:
```bash
# Check Ingress resource
kubectl get ingress
kubectl describe ingress myapp

# Check Ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Verify service exists and has endpoints
kubectl get svc myapp-service
kubectl get endpoints myapp-service

# Test service directly
kubectl port-forward svc/myapp-service 8080:80
curl localhost:8080
```

**Common Causes**:
1. Ingress controller not installed
2. Wrong host in Ingress spec
3. Service name mismatch
4. Service has no endpoints (pod labels don't match)

**Fix Example**:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
spec:
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-service  # Must match Service name exactly
            port:
              number: 80
```

#### Issue: Ingress TLS Certificate Errors

**Symptom**: Certificate errors when accessing HTTPS

**Diagnosis**:
```bash
# Check if secret exists
kubectl get secret myapp-tls

# Verify certificate in secret
kubectl get secret myapp-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text

# Check Ingress references correct secret
kubectl describe ingress myapp | grep -A5 TLS
```

### 3. StatefulSet Troubleshooting

Common StatefulSet and persistent storage issues:

#### Issue: Pods Stuck in Pending

**Symptom**: StatefulSet pods don't start, remain Pending

**Diagnosis**:
```bash
# Check pod status
kubectl get pods -l app=database

# Describe pod
kubectl describe pod database-0

# Common causes in events:
# - "no persistent volumes available"
# - "Insufficient cpu/memory"
# - "node(s) had taint that the pod didn't tolerate"

# Check PVC status
kubectl get pvc
# If Pending, PV doesn't exist or doesn't match
```

**Fix**:
```bash
# For local dev, create PVs manually
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-0
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  hostPath:
    path: /data/pv-0
EOF

# Or use dynamic provisioning with StorageClass
kubectl get storageclass
```

#### Issue: StatefulSet Pods Not Updating

**Symptom**: After updating StatefulSet, pods still run old version

**Diagnosis**:
```bash
# Check update strategy
kubectl get statefulset database -o yaml | grep -A5 updateStrategy

# If OnDelete, pods must be manually deleted
# If RollingUpdate, check partition setting

# Check pod image version
kubectl get pods -l app=database -o jsonpath='{.items[*].spec.containers[*].image}'
```

**Fix**:
```bash
# For OnDelete strategy, delete pods to trigger update
kubectl delete pod database-0

# For RollingUpdate with partition, update partition
kubectl patch statefulset database -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":0}}}}'
```

## CKAD-Relevant Troubleshooting Patterns

### Pattern 1: Systematic Resource Check

When troubleshooting any deployment:

```bash
# 1. Check top-level resource
kubectl get deployment/statefulset/pod <name>

# 2. Get detailed info
kubectl describe <resource> <name>

# 3. Check related resources
kubectl get svc,endpoints -l app=<name>
kubectl get pvc -l app=<name>
kubectl get ingress -l app=<name>

# 4. Check pod logs
kubectl logs <pod-name>
kubectl logs <pod-name> --previous  # If crash-looping

# 5. Exec into pod to test
kubectl exec -it <pod-name> -- sh
```

### Pattern 2: Networking Troubleshooting

```bash
# Test Service from another pod
kubectl run test --rm -it --image=busybox -- sh
wget -O- http://myapp-service:80

# Test DNS resolution
nslookup myapp-service

# Check endpoints
kubectl get endpoints myapp-service

# Test Ingress
curl -H "Host: myapp.local" http://<ingress-ip>
```

### Pattern 3: Storage Troubleshooting

```bash
# Check PVC status
kubectl get pvc
# Look for: Bound, Pending, Lost

# Check PV details
kubectl describe pv <pv-name>

# Check what's using the PVC
kubectl get pods -o json | jq '.items[] | select(.spec.volumes[]?.persistentVolumeClaim.claimName=="<pvc-name>") | .metadata.name'

# Check mount inside pod
kubectl exec <pod> -- df -h
kubectl exec <pod> -- ls -la /mount/path
```

## Real-World CKAD Scenario

**Exam Question Style:**
"An application has been deployed with Helm but is not accessible. The Ingress is configured but returns 404. Debug and fix the issues."

<details>
  <summary>Troubleshooting Approach</summary>

```bash
# Step 1: Check Helm release status
helm list
helm status myapp

# Step 2: Check all deployed resources
kubectl get all -l app.kubernetes.io/instance=myapp

# Step 3: Check Ingress
kubectl get ingress
kubectl describe ingress myapp

# Look for:
# - Correct host
# - Service backend exists
# - Endpoints present

# Step 4: Check Service
kubectl get svc myapp
kubectl describe svc myapp

# Verify:
# - Selector matches pod labels
# - Port configuration correct

# Step 5: Check Service Endpoints
kubectl get endpoints myapp

# If empty:
# - Pod labels don't match service selector
# - Pods not ready

# Step 6: Check Pods
kubectl get pods -l app=myapp
kubectl describe pod <pod-name>

# Step 7: Check pod logs
kubectl logs <pod-name>

# Step 8: Test Service directly
kubectl port-forward svc/myapp 8080:80
curl localhost:8080

# Step 9: If Service works but Ingress doesn't
# Check Ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# Step 10: Fix identified issues
# Common fixes:
# - Update Ingress to use correct service name
# - Fix service selector to match pod labels
# - Ensure Ingress controller is installed and running
```

</details><br />

## Quick Reference: Common Issues

### Helm Issues

| Issue | Check | Fix |
|-------|-------|-----|
| Install fails | `helm lint` | Fix template syntax errors |
| Wrong values | `helm get values` | Reinstall with correct values file |
| Template error | `helm template` | Add defaults or fix value references |
| Can't find chart | `helm repo list` | Add repository or fix chart path |

### Ingress Issues

| Issue | Check | Fix |
|-------|-------|-----|
| 404 Not Found | `kubectl describe ingress` | Fix service name or path |
| No Ingress IP | `kubectl get ingress` | Install Ingress controller |
| TLS errors | `kubectl get secret` | Create/fix TLS secret |
| Wrong host | Ingress spec | Update host in Ingress rules |

### StatefulSet Issues

| Issue | Check | Fix |
|-------|-------|-----|
| Pods Pending | `kubectl describe pod` | Create PVs or fix storage |
| Not updating | `updateStrategy` | Delete pods or fix partition |
| PVC not bound | `kubectl get pvc,pv` | Create matching PV |
| Ordering issues | Pod names | Check headless service |

## Exam Tips

1. **Use systematic approach**: Always check resources in order (Pod → Service → Ingress)
2. **Read error messages**: They usually tell you exactly what's wrong
3. **Check logs**: Both application logs and controller logs
4. **Test incrementally**: Verify each layer works (pod → service → ingress)
5. **Know the tools**: helm, kubectl describe, kubectl logs, kubectl exec
6. **Understand dependencies**: Ingress needs controller, StatefulSet needs PVs
7. **Check names match**: Service names in Ingress, selectors in Services
8. **Verify namespaces**: All resources must be in correct namespace
9. **Use port-forward**: Test services directly, bypassing Ingress
10. **Practice Helm**: Know helm template, helm get, helm status

## Summary

Advanced troubleshooting builds on CKAD fundamentals:

✅ **Key Skills:**
- Helm chart debugging
- Ingress routing verification
- StatefulSet and PVC troubleshooting
- Systematic problem diagnosis
- Testing at each layer

✅ **CKAD Relevance:**
- Helm is in CKAD curriculum
- Ingress troubleshooting uses service/pod skills
- StatefulSet debugging applies to all controllers

🎯 **Exam focus**: Core troubleshooting (pods, services, configs) is more critical
⏱️ **Time**: Don't spend too long on complex scenarios
📊 **Difficulty**: Advanced (but builds on basics)

Master the basics first, then tackle advanced scenarios!
