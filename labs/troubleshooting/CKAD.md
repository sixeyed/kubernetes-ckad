# Troubleshooting for CKAD

This guide covers the troubleshooting skills and knowledge required for the Certified Kubernetes Application Developer (CKAD) exam.

## CKAD Troubleshooting Requirements

The CKAD exam expects you to be able to:
- Evaluate cluster and node logging
- Understand and debug application deployment issues
- Monitor applications
- Debug services and networking issues
- Troubleshoot Pod failures and application issues

## Core Troubleshooting Commands

### Essential kubectl Commands

```bash
# Get overview of resources
kubectl get pods
kubectl get pods -o wide
kubectl get pods --all-namespaces
kubectl get events --sort-by='.lastTimestamp'

# Detailed information about resources
kubectl describe pod <pod-name>
kubectl describe service <service-name>
kubectl describe node <node-name>

# View logs
kubectl logs <pod-name>
kubectl logs <pod-name> -c <container-name>  # for multi-container pods
kubectl logs <pod-name> --previous            # logs from previous container instance
kubectl logs <pod-name> --tail=50             # last 50 lines
kubectl logs <pod-name> -f                    # follow logs

# Execute commands in containers
kubectl exec <pod-name> -- <command>
kubectl exec -it <pod-name> -- /bin/sh
kubectl exec <pod-name> -c <container-name> -- <command>  # for multi-container pods

# Debug with a temporary pod
kubectl run debug --image=busybox -it --rm -- sh

# Port forwarding for testing
kubectl port-forward <pod-name> <local-port>:<pod-port>
kubectl port-forward service/<service-name> <local-port>:<service-port>
```

## Common Pod Failure Scenarios

### 1. ImagePullBackOff / ErrImagePull

**Symptoms:**
- Pod status shows `ImagePullBackOff` or `ErrImagePull`
- Pod cannot start

**Common Causes:**
- Incorrect image name or tag
- Image doesn't exist in the registry
- Private registry authentication issues
- Network connectivity to registry

**Diagnosis:**
```bash
kubectl describe pod <pod-name>
# Look for events showing image pull errors
```

**Hands-on Exercise:**

Try deploying a Pod with an incorrect image:

```bash
kubectl apply -f labs/troubleshooting/specs/ckad/imagepull-wrong-image.yaml

# Check the pod status
kubectl get pod wrong-image-pod

# Investigate the error
kubectl describe pod wrong-image-pod
```

You'll see `ImagePullBackOff` with events showing the image cannot be pulled. To fix:

```bash
kubectl apply -f labs/troubleshooting/solution/ckad/imagepull-wrong-image-fixed.yaml
```

**Private Registry Authentication:**

Deploy a Pod requiring private registry access:

```bash
kubectl apply -f labs/troubleshooting/specs/ckad/imagepull-private-registry.yaml

# Pod will fail to pull image
kubectl describe pod private-registry-pod
```

To fix, create an image pull secret and reference it:

```bash
# Create the secret (use real credentials for actual registries)
kubectl create secret docker-registry regcred \
  --docker-server=private.registry.io \
  --docker-username=myuser \
  --docker-password=mypassword \
  --docker-email=user@example.com

# Apply the fixed pod spec
kubectl apply -f labs/troubleshooting/solution/ckad/imagepull-private-registry-fixed.yaml
```

**Key Learning Points:**
- Always verify image names and tags are correct
- Check image pull events in `kubectl describe pod`
- For private registries, create and reference imagePullSecrets
- Use `kubectl get events` to see image pull failures

### 2. CrashLoopBackOff

**Symptoms:**
- Pod repeatedly crashes and restarts
- Status shows `CrashLoopBackOff`
- Restart count increases

**Common Causes:**
- Application error at startup
- Missing dependencies or configuration
- Incorrect command or arguments
- Failed liveness probe

**Diagnosis:**
```bash
kubectl logs <pod-name>
kubectl logs <pod-name> --previous
kubectl describe pod <pod-name>
```

**Hands-on Exercise:**

**Scenario 1: Missing Environment Variable**

Deploy a Pod that crashes due to missing configuration:

```bash
kubectl apply -f labs/troubleshooting/specs/ckad/crash-missing-env.yaml

# Watch the pod crash and restart
kubectl get pod crash-missing-env -w

# Check the logs to see the error
kubectl logs crash-missing-env

# See the restart count increasing
kubectl describe pod crash-missing-env
```

Fix by adding the required environment variable:

```bash
kubectl apply -f labs/troubleshooting/solution/ckad/crash-missing-env-fixed.yaml
kubectl get pod crash-missing-env-fixed
```

**Scenario 2: Incorrect Command**

Deploy a Pod with an invalid command:

```bash
kubectl apply -f labs/troubleshooting/specs/ckad/crash-wrong-command.yaml

# Check logs to see the command error
kubectl logs crash-wrong-command
kubectl describe pod crash-wrong-command
```

Fix by using the correct command or removing it to use defaults:

```bash
kubectl apply -f labs/troubleshooting/solution/ckad/crash-wrong-command-fixed.yaml
```

**Scenario 3: Failed Liveness Probe**

Deploy a Pod with an incorrect liveness probe:

```bash
kubectl apply -f labs/troubleshooting/specs/ckad/crash-failed-liveness.yaml

# Pod will start but then get killed by failed liveness checks
kubectl get pod crash-failed-liveness -w
kubectl describe pod crash-failed-liveness
```

Fix by correcting the probe configuration:

```bash
kubectl apply -f labs/troubleshooting/solution/ckad/crash-failed-liveness-fixed.yaml
```

**Key Learning Points:**
- Check logs with `kubectl logs` and `--previous` flag for crashed containers
- Look for restart count in `kubectl get pods`
- Examine events in `kubectl describe pod` for probe failures
- Verify environment variables and command configuration
- Ensure liveness probes target valid endpoints with appropriate timing

### 3. Pod Pending

**Symptoms:**
- Pod remains in `Pending` state
- Pod never gets scheduled to a node

**Common Causes:**
- Insufficient cluster resources (CPU/memory)
- Node selector or affinity rules can't be satisfied
- PersistentVolumeClaim not bound
- Taints and tolerations mismatch

**Diagnosis:**
```bash
kubectl describe pod <pod-name>
# Look for scheduling errors in events
kubectl get nodes
kubectl describe node <node-name>
kubectl top nodes  # check resource usage
```

**Hands-on Exercise:**

**Scenario 1: Excessive Resource Requests**

Deploy a Pod requesting more resources than available:

```bash
kubectl apply -f labs/troubleshooting/specs/ckad/pending-excessive-resources.yaml

# Pod will remain in Pending state
kubectl get pod pending-excessive-resources

# Check why it can't be scheduled
kubectl describe pod pending-excessive-resources
# Look for events like "0/1 nodes are available: 1 Insufficient cpu, 1 Insufficient memory"

# Check available node resources
kubectl describe nodes
kubectl top nodes
```

Fix by using realistic resource requests:

```bash
kubectl apply -f labs/troubleshooting/solution/ckad/pending-excessive-resources-fixed.yaml
```

**Scenario 2: Node Selector Mismatch**

Deploy a Pod with a node selector that doesn't match any node:

```bash
kubectl apply -f labs/troubleshooting/specs/ckad/pending-node-selector.yaml

# Pod stays pending
kubectl get pod pending-node-selector
kubectl describe pod pending-node-selector
# Events will show: "0/1 nodes are available: 1 node(s) didn't match Pod's node affinity/selector"

# Check actual node labels
kubectl get nodes --show-labels
```

Fix by removing or correcting the nodeSelector:

```bash
kubectl apply -f labs/troubleshooting/solution/ckad/pending-node-selector-fixed.yaml
```

**Scenario 3: PVC Binding Issues**

Deploy a Pod with a PVC that can't bind:

```bash
kubectl apply -f labs/troubleshooting/specs/ckad/pending-pvc.yaml

# Check PVC status
kubectl get pvc pending-pvc-claim
# Status will show "Pending"

# Check why PVC isn't binding
kubectl describe pvc pending-pvc-claim

# Pod will also be pending
kubectl describe pod pending-pvc-pod
```

Fix by using a valid storage class:

```bash
# First check available storage classes
kubectl get storageclass

# Then apply fixed version (edit to use your cluster's storage class if needed)
kubectl apply -f labs/troubleshooting/solution/ckad/pending-pvc-fixed.yaml
```

**Key Learning Points:**
- Use `kubectl describe pod` to see scheduling failure reasons
- Check node resources with `kubectl describe nodes` and `kubectl top nodes`
- Verify node labels match nodeSelector requirements
- Ensure PVCs are bound before pods can use them
- Review storage classes with `kubectl get storageclass`

### 4. Container Not Ready

**Symptoms:**
- Pod status shows `Running` but not `Ready`
- Container fails readiness checks

**Common Causes:**
- Readiness probe failing
- Application not ready to serve traffic
- Incorrect readiness probe configuration

**Diagnosis:**
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
# Check readiness probe configuration and failures
```

The basic lab already covers some of these scenarios - see the [main lab](README.md) for hands-on practice.

### 5. Init Container Issues

**Symptoms:**
- Pod stuck in `Init` state
- Init containers failing

**Common Causes:**
- Init container command failing
- Dependencies not available
- Network issues

**Diagnosis:**
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name> -c <init-container-name>
```

**Hands-on Exercise:**

**Scenario 1: Failing Init Container**

Deploy a Pod with an init container that always fails:

```bash
kubectl apply -f labs/troubleshooting/specs/ckad/init-container-failing.yaml

# Pod will be stuck in Init status
kubectl get pod init-container-failing

# Check init container logs
kubectl logs init-container-failing -c init-check
kubectl describe pod init-container-failing
```

Fix by correcting the init container logic:

```bash
kubectl apply -f labs/troubleshooting/solution/ckad/init-container-failing-fixed.yaml
```

**Scenario 2: Init Container Waiting for Dependency**

Deploy a Pod with an init container waiting for a service:

```bash
kubectl apply -f labs/troubleshooting/specs/ckad/init-container-waiting.yaml

# Pod will be stuck waiting for the service
kubectl get pod init-container-waiting
kubectl logs init-container-waiting -c wait-for-service -f
```

Fix by deploying the required service first:

```bash
# Deploy the database service
kubectl apply -f labs/troubleshooting/solution/ckad/init-container-database-service.yaml

# Wait for database to be ready
kubectl wait --for=condition=ready pod -l app=database --timeout=60s

# Now deploy the fixed pod
kubectl apply -f labs/troubleshooting/solution/ckad/init-container-waiting-fixed.yaml
```

**Key Learning Points:**
- Init containers run before main containers and must complete successfully
- Use `kubectl logs <pod> -c <init-container-name>` to check init container logs
- Pod status shows `Init:0/1`, `Init:Error`, or `Init:CrashLoopBackOff` for init issues
- Init containers are useful for setup tasks and dependency checks
- Always ensure dependencies exist before deploying pods that wait for them

### 6. Multi-Container Pod Issues

**Symptoms:**
- Some containers running, others failing
- Sidecar containers not working correctly

**Common Causes:**
- Container-specific configuration errors
- Volume mount issues between containers
- Network communication issues between containers

**Diagnosis:**
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name> -c <container-name>
kubectl exec <pod-name> -c <container-name> -- <command>
```

**Hands-on Exercise:**

**Scenario 1: Sidecar Container Failure**

Deploy a Pod with a failing sidecar container:

```bash
kubectl apply -f labs/troubleshooting/specs/ckad/multicontainer-sidecar-fail.yaml

# Check pod status - one container running, one crashing
kubectl get pod multicontainer-sidecar-fail

# Check which container is failing
kubectl describe pod multicontainer-sidecar-fail

# Check sidecar logs
kubectl logs multicontainer-sidecar-fail -c log-sidecar
```

Fix by correcting the sidecar's volume mount path:

```bash
kubectl apply -f labs/troubleshooting/solution/ckad/multicontainer-sidecar-fail-fixed.yaml

# Verify both containers are running
kubectl get pod multicontainer-sidecar-fail-fixed
```

**Scenario 2: Volume Access Conflict**

Deploy a Pod where containers have conflicting volume access:

```bash
kubectl apply -f labs/troubleshooting/specs/ckad/multicontainer-volume-conflict.yaml

# Writer container will fail due to readOnly volume
kubectl logs multicontainer-volume-conflict -c writer
kubectl describe pod multicontainer-volume-conflict
```

Fix by removing readOnly from the writer container:

```bash
kubectl apply -f labs/troubleshooting/solution/ckad/multicontainer-volume-conflict-fixed.yaml

# Verify writer can write and reader can read
kubectl logs multicontainer-volume-conflict-fixed -c writer
kubectl logs multicontainer-volume-conflict-fixed -c reader
```

**Key Learning Points:**
- Use `kubectl get pod <name>` to see READY count (e.g., 1/2 means one of two containers ready)
- Check individual container logs with `-c <container-name>`
- Verify volume mount paths match between containers sharing data
- Use `readOnly: true` only for containers that don't need to write
- In multi-container pods, all containers must be running for pod to be Ready

## Service and Networking Troubleshooting

### Service Not Routing to Pods

**Common Issues:**
1. **Selector Mismatch** - Service selector doesn't match Pod labels
2. **Port Mismatch** - Service targetPort doesn't match container port
3. **Named Port Mismatch** - Port names don't match between Service and Pod
4. **No Endpoints** - No pods match the service selector

**Diagnosis:**
```bash
kubectl get service <service-name>
kubectl describe service <service-name>
kubectl get endpoints <service-name>
kubectl get pods -l <label-selector>
```

The basic lab covers these scenarios - see the [main lab](README.md).

### Network Policy Blocking Traffic

**Hands-on Exercise:**

Deploy an application with a NetworkPolicy that blocks traffic:

```bash
# Deploy backend, frontend, and a blocking NetworkPolicy
kubectl apply -f labs/troubleshooting/specs/ckad/netpol-blocking-app.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=backend -n netpol-test --timeout=30s
kubectl wait --for=condition=ready pod -l app=frontend -n netpol-test --timeout=30s

# Try to access backend from frontend - will fail due to NetworkPolicy
kubectl exec -n netpol-test frontend -- wget -qO- --timeout=5 backend
# This will timeout because all ingress is denied
```

**Debugging NetworkPolicy Issues:**

```bash
# Check if NetworkPolicy exists
kubectl get networkpolicy -n netpol-test

# Examine the policy
kubectl describe networkpolicy deny-all-ingress -n netpol-test

# Deploy a debug pod for network testing
kubectl apply -f labs/troubleshooting/solution/ckad/netpol-debug-pod.yaml

# Test connectivity from debug pod
kubectl exec -n netpol-test netpol-debug -- curl -m 5 backend
```

Fix by applying a NetworkPolicy that allows the required traffic:

```bash
# Delete the blocking policy
kubectl delete networkpolicy deny-all-ingress -n netpol-test

# Apply policy that allows frontend to access backend
kubectl apply -f labs/troubleshooting/solution/ckad/netpol-blocking-app-fixed.yaml

# Test again - should work now
kubectl exec -n netpol-test frontend -- wget -qO- --timeout=5 backend
```

**Key Learning Points:**
- NetworkPolicies are namespace-scoped
- An empty ingress rule list means deny all ingress
- Use debug pods with network tools (curl, wget, nc) to test connectivity
- Check both source and destination pod labels when debugging policies
- Remember: if no NetworkPolicy selects a pod, all traffic is allowed
- Use `kubectl get networkpolicy` to list all policies affecting a namespace

### DNS Resolution Issues

**Hands-on Exercise:**

Deploy a service and client pod to test DNS resolution:

```bash
kubectl apply -f labs/troubleshooting/specs/ckad/dns-test-app.yaml

# Check if service exists
kubectl get service my-backend-service

# Check service endpoints (will be empty - no matching pods)
kubectl get endpoints my-backend-service

# Check client pod logs
kubectl logs dns-test-client
```

**Testing DNS Resolution:**

Deploy a debug pod and test DNS:

```bash
kubectl apply -f labs/troubleshooting/solution/ckad/dns-debug-pod.yaml

# Test DNS resolution for the service
kubectl exec dns-debug -- nslookup my-backend-service
kubectl exec dns-debug -- nslookup my-backend-service.default
kubectl exec dns-debug -- nslookup my-backend-service.default.svc.cluster.local

# Check if CoreDNS is running
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check CoreDNS logs if needed
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50
```

**Understanding DNS Formats:**

```bash
# Short form (same namespace)
<service-name>

# With namespace
<service-name>.<namespace>

# Fully qualified domain name (FQDN)
<service-name>.<namespace>.svc.cluster.local
```

Fix by deploying pods that match the service selector:

```bash
# Deploy backend pod and fixed service
kubectl apply -f labs/troubleshooting/solution/ckad/dns-test-app-fixed.yaml

# Verify endpoints are now populated
kubectl get endpoints my-backend-service-fixed

# Check client logs - DNS resolution should work now
kubectl logs dns-test-client-fixed
```

**Key Learning Points:**
- DNS resolves service names, not pod names (unless using headless service)
- Use `nslookup` or `dig` in debug pods to test DNS
- Check service endpoints with `kubectl get endpoints <service-name>`
- Verify CoreDNS pods are running in kube-system namespace
- Services need matching pod selectors to have endpoints
- DNS works even if service has no endpoints (but connections will fail)

## Configuration Issues

### ConfigMap and Secret Problems

**Common Issues:**
- ConfigMap or Secret doesn't exist
- Incorrect key references in Pod spec
- Volume mount path conflicts
- Environment variable name conflicts

**Diagnosis:**
```bash
kubectl get configmap
kubectl describe configmap <configmap-name>
kubectl get secret
kubectl describe secret <secret-name>
kubectl describe pod <pod-name>
```

**Hands-on Exercise:**

**Scenario 1: Missing ConfigMap**

Deploy a Pod referencing a non-existent ConfigMap:

```bash
kubectl apply -f labs/troubleshooting/specs/ckad/configmap-missing.yaml

# Pod will fail to create
kubectl get pod configmap-missing
kubectl describe pod configmap-missing
# Look for event: "configmap "app-config" not found"
```

Fix by creating the required ConfigMap:

```bash
kubectl apply -f labs/troubleshooting/solution/ckad/configmap-missing-fixed.yaml
kubectl logs configmap-missing-fixed
```

**Scenario 2: ConfigMap Key Mismatch**

Deploy a Pod with incorrect ConfigMap key references:

```bash
kubectl apply -f labs/troubleshooting/specs/ckad/configmap-wrong-key.yaml

# Check available keys in ConfigMap
kubectl describe configmap app-settings

# Pod will fail to start
kubectl describe pod configmap-wrong-key
# Events will show: "key "db_host" not found in ConfigMap app-settings"
```

Fix by using the correct key names:

```bash
kubectl apply -f labs/troubleshooting/solution/ckad/configmap-wrong-key-fixed.yaml
kubectl logs configmap-wrong-key-fixed
```

**Scenario 3: Volume Mount Conflict**

Deploy a Pod with conflicting mount paths:

```bash
kubectl apply -f labs/troubleshooting/specs/ckad/secret-mount-fail.yaml

# Pod creation will be rejected
kubectl describe pod secret-mount-fail
# Look for error about duplicate mount paths
```

Fix by using unique mount paths:

```bash
kubectl apply -f labs/troubleshooting/solution/ckad/secret-mount-fail-fixed.yaml

# Verify secrets are mounted correctly
kubectl exec secret-mount-fail-fixed -- ls -la /etc/credentials
kubectl exec secret-mount-fail-fixed -- ls -la /etc/config
```

**Key Learning Points:**
- Use `kubectl describe configmap <name>` to see available keys
- Pods won't start if ConfigMaps/Secrets are missing (unless optional: true)
- ConfigMap and Secret keys are case-sensitive
- Volume mount paths must be unique within a container
- Use `kubectl get configmap` and `kubectl get secret` to list available resources
- Environment variables from missing ConfigMaps cause pod creation to fail

### Volume Mounting Issues

**Common Issues:**
- Volume not mounting to container
- PersistentVolumeClaim not binding
- Mount path conflicts
- Permission issues with mounted volumes

**Hands-on Exercise:**

**Scenario 1: PVC in Pending State**

Deploy a Pod with a PVC that can't bind:

```bash
kubectl apply -f labs/troubleshooting/specs/ckad/volume-pvc-pending.yaml

# Check PVC status
kubectl get pvc pvc-pending
# Status will be "Pending"

# Investigate why PVC isn't binding
kubectl describe pvc pvc-pending
# Look for events about storageclass not found

# Pod will also be pending
kubectl get pod volume-pvc-pending
kubectl describe pod volume-pvc-pending
```

Fix by using a valid storage class:

```bash
# Check available storage classes
kubectl get storageclass

# Apply fixed version with default storage class
kubectl apply -f labs/troubleshooting/solution/ckad/volume-pvc-pending-fixed.yaml

# Verify PVC is bound
kubectl get pvc pvc-pending-fixed
kubectl get pod volume-pvc-pending-fixed
```

**Scenario 2: Volume Permission Issues**

Deploy a Pod with potential permission issues:

```bash
kubectl apply -f labs/troubleshooting/specs/ckad/volume-permission-issue.yaml

# Pod might have permission issues with hostPath
kubectl logs volume-permission-issue
kubectl describe pod volume-permission-issue
```

Fix by using appropriate volume types:

```bash
# Use emptyDir which automatically handles permissions
kubectl apply -f labs/troubleshooting/solution/ckad/volume-permission-issue-fixed.yaml

# Verify pod is running
kubectl get pod volume-permission-issue-fixed
kubectl exec volume-permission-issue-fixed -- ls -la /usr/share/nginx/html
```

**Alternative: EmptyDir with Options**

```bash
# Deploy pod with emptyDir variations
kubectl apply -f labs/troubleshooting/solution/ckad/volume-emptydir-alternative.yaml

# Check volumes are mounted
kubectl exec volume-emptydir-alternative -- df -h
```

**Key Learning Points:**
- PVCs must bind to a PV before pods can use them
- Use `kubectl get pvc` to check claim status (Pending/Bound)
- Check available storage classes with `kubectl get storageclass`
- emptyDir volumes are created with correct permissions automatically
- hostPath volumes can have permission issues and aren't portable
- fsGroup in securityContext sets group ownership for volumes
- Volume mount failures keep pods in ContainerCreating state

## Advanced Troubleshooting Techniques

### Using Ephemeral Debug Containers

```bash
# Create a debug container in an existing pod (Kubernetes 1.23+)
kubectl debug <pod-name> -it --image=busybox --target=<container-name>

# Create a copy of a pod with modified settings
kubectl debug <pod-name> -it --copy-to=debug-pod --container=debug --image=busybox
```

**Practical Examples:**

Ephemeral debug containers allow you to debug running pods without modifying the pod spec (Kubernetes 1.23+).

**Debug a Distroless Container:**

Many production images are minimal (distroless) and don't include debugging tools:

```bash
# Create a minimal pod without shell
kubectl run minimal-app --image=gcr.io/distroless/static:nonroot

# Try to exec - will fail (no shell)
kubectl exec minimal-app -- sh
# Error: container has no shell

# Add an ephemeral debug container
kubectl debug minimal-app -it --image=busybox --target=minimal-app

# Now you can inspect the filesystem and processes
ls /
ps aux
```

**Debug with a Copy:**

Create a copy of a pod with debugging capabilities:

```bash
# Create a copy of the pod with modified settings
kubectl debug minimal-app -it --copy-to=minimal-app-debug \
  --container=debug --image=busybox

# The copy runs alongside the original
kubectl get pods
```

**Debug Node Issues:**

Debug directly on a node:

```bash
# Create a debug container on a specific node
kubectl debug node/<node-name> -it --image=ubuntu

# You'll have access to the node's filesystem at /host
chroot /host
ps aux
df -h
```

**Using Specialized Debug Images:**

```bash
# Use nicolaka/netshoot for network debugging
kubectl debug -it problematic-pod --image=nicolaka/netshoot --target=problematic-pod

# Now you have access to network tools
nslookup kubernetes.default
curl http://service-name
tcpdump -i any port 80

# Use alpine for general debugging
kubectl debug -it stuck-pod --image=alpine --target=stuck-pod
```

**Key Learning Points:**
- Ephemeral containers are temporary and disappear when removed
- Use `--target` to share the same namespace (network, PID) as the target container
- Debug containers can't be removed once added (until pod is deleted)
- Useful for debugging distroless or minimal images
- `kubectl debug node/<node>` provides node-level debugging
- Ephemeral containers don't persist across pod restarts

### Resource Quotas and Limit Ranges

**Hands-on Exercise:**

**Scenario 1: ResourceQuota Exceeded**

Deploy a namespace with a ResourceQuota and try to exceed it:

```bash
kubectl apply -f labs/troubleshooting/specs/ckad/quota-namespace.yaml

# Try to create a pod that exceeds the quota
# This will fail with an error
kubectl apply -f labs/troubleshooting/specs/ckad/quota-namespace.yaml
# Look for error: "exceeded quota: compute-quota"

# Check the quota status
kubectl get resourcequota -n quota-test
kubectl describe resourcequota compute-quota -n quota-test
```

Fix by using resources within quota limits:

```bash
kubectl apply -f labs/troubleshooting/solution/ckad/quota-namespace-fixed.yaml

# Verify pod was created
kubectl get pods -n quota-test

# Check quota usage
kubectl describe resourcequota compute-quota -n quota-test
```

**Scenario 2: LimitRange Violations**

Deploy a namespace with LimitRange constraints:

```bash
kubectl apply -f labs/troubleshooting/specs/ckad/limitrange-namespace.yaml

# The pod will be rejected - exceeds LimitRange max
# Error will mention LimitRange validation

# Check the LimitRange
kubectl get limitrange -n limitrange-test
kubectl describe limitrange resource-limits -n limitrange-test
```

Fix by staying within LimitRange bounds:

```bash
kubectl apply -f labs/troubleshooting/solution/ckad/limitrange-namespace-fixed.yaml

# Pod should be created successfully
kubectl get pods -n limitrange-test
```

**Checking Quota Usage:**

```bash
# Deploy multiple pods to see quota consumption
kubectl apply -f labs/troubleshooting/solution/ckad/quota-check-usage.yaml

# Check current quota usage vs limits
kubectl describe resourcequota compute-quota -n quota-test
# Shows: Used, Hard (limit), and remaining capacity
```

**Key Learning Points:**
- ResourceQuota limits total resource usage in a namespace
- LimitRange constrains individual pod/container resources
- Pod creation fails immediately if quota/limits are exceeded
- Use `kubectl describe resourcequota` to see current usage
- Use `kubectl describe limitrange` to see constraints
- ResourceQuota requires requests/limits to be specified on all pods
- LimitRange can provide default requests/limits if not specified

### Debugging Performance Issues

**Hands-on Exercise:**

**Prerequisites: Metrics Server**

Ensure metrics-server is installed for resource monitoring:

```bash
# Check if metrics-server is running
kubectl get deployment metrics-server -n kube-system

# If not installed, install it (for most clusters)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

**Scenario 1: CPU Throttling**

Deploy a CPU-intensive pod with low limits:

```bash
kubectl apply -f labs/troubleshooting/specs/ckad/performance-cpu-throttle.yaml

# Wait for pod to start
kubectl wait --for=condition=ready pod/cpu-throttled --timeout=30s

# Check resource usage
kubectl top pod cpu-throttled

# Describe pod to see throttling
kubectl describe pod cpu-throttled
# Look at resource usage vs limits

# Check if container is being throttled (advanced)
# Throttling shows as high CPU usage near limit
```

Fix by increasing CPU limits:

```bash
kubectl apply -f labs/troubleshooting/solution/ckad/performance-cpu-throttle-fixed.yaml

# Compare resource usage
kubectl top pod cpu-throttled-fixed
```

**Scenario 2: Memory Issues (OOMKilled)**

Deploy a pod that will run out of memory:

```bash
kubectl apply -f labs/troubleshooting/specs/ckad/performance-memory-leak.yaml

# Watch pod status - it will eventually be OOMKilled
kubectl get pod memory-leak -w

# Check why it was killed
kubectl describe pod memory-leak
# Look for "OOMKilled" in Last State

# Check logs before it was killed
kubectl logs memory-leak --previous
```

Fix by allocating sufficient memory:

```bash
kubectl apply -f labs/troubleshooting/solution/ckad/performance-memory-leak-fixed.yaml

# Monitor memory usage
kubectl top pod memory-optimized
```

**Identifying Resource Bottlenecks:**

```bash
# Check node resource usage
kubectl top nodes

# Check all pod resource usage
kubectl top pods --all-namespaces --sort-by=memory
kubectl top pods --all-namespaces --sort-by=cpu

# Check specific namespace
kubectl top pods -n <namespace>

# Identify pods near their limits
kubectl get pods -o json | jq '.items[] | {
  name: .metadata.name,
  cpu_limit: .spec.containers[0].resources.limits.cpu,
  memory_limit: .spec.containers[0].resources.limits.memory
}'
```

**Common Performance Anti-Patterns:**

1. **No resource limits** - Can starve other pods
2. **Too-low CPU limits** - Causes throttling and slow performance
3. **Requests = Limits** - No burst capacity
4. **Too-high requests** - Wastes node resources
5. **No monitoring** - Can't identify bottlenecks

**Key Learning Points:**
- Use `kubectl top` to monitor real-time resource usage
- OOMKilled means container exceeded memory limit
- CPU throttling occurs when hitting CPU limits (doesn't kill pod)
- Set requests based on average usage, limits with headroom for spikes
- Monitor resource usage patterns before setting limits
- Use metrics-server for resource monitoring in troubleshooting

### Application-Specific Debugging

**Java Applications:**

Debug Java applications running in Kubernetes:

```bash
# Get heap dump from running Java application
kubectl exec <java-pod> -- jmap -dump:format=b,file=/tmp/heap.bin 1

# Copy heap dump for analysis
kubectl cp <java-pod>:/tmp/heap.bin ./heap.bin

# Get thread dump
kubectl exec <java-pod> -- jstack 1

# Check Java process details
kubectl exec <java-pod> -- jps -v

# Monitor JVM metrics
kubectl exec <java-pod> -- jstat -gc 1 1000
```

**Java Debug Pod Example:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: java-debug-app
spec:
  containers:
  - name: java-app
    image: openjdk:11
    command: ["java"]
    args:
    - "-XX:+HeapDumpOnOutOfMemoryError"
    - "-XX:HeapDumpPath=/dumps"
    - "-Xmx512m"
    - "-jar"
    - "/app/application.jar"
    env:
    - name: JAVA_TOOL_OPTIONS
      value: "-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005"
    ports:
    - containerPort: 5005  # Debug port
      name: debug
```

**Node.js Applications:**

Debug Node.js applications:

```bash
# Check Node.js version and process
kubectl exec <node-pod> -- node --version
kubectl exec <node-pod> -- ps aux | grep node

# Get heap snapshot (if app supports it)
kubectl exec <node-pod> -- kill -USR2 <pid>

# View console logs with timestamps
kubectl logs <node-pod> --timestamps=true

# Enable debug mode (restart with debug flag)
# Add to pod spec: args: ["--inspect=0.0.0.0:9229", "app.js"]
```

**Node.js Debug Example:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nodejs-debug-app
spec:
  containers:
  - name: nodejs-app
    image: node:18
    command: ["node"]
    args: ["--inspect=0.0.0.0:9229", "/app/server.js"]
    ports:
    - containerPort: 9229
      name: debug
    env:
    - name: NODE_ENV
      value: "development"
    - name: DEBUG
      value: "*"  # Enable all debug logs
```

**Python Applications:**

Debug Python applications:

```bash
# Check Python version
kubectl exec <python-pod> -- python --version

# Run Python debugger (pdb) interactively
kubectl exec -it <python-pod> -- python -m pdb /app/main.py

# Get Python traceback for running process
kubectl exec <python-pod> -- python -c "import sys; sys.settrace(lambda *args: print(args))"

# Install debugging tools in running pod
kubectl exec <python-pod> -- pip install py-spy
kubectl exec <python-pod> -- py-spy top --pid 1

# Check installed packages
kubectl exec <python-pod> -- pip list
```

**Python Debug Example:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: python-debug-app
spec:
  containers:
  - name: python-app
    image: python:3.11
    command: ["python"]
    args: ["-u", "-m", "debugpy", "--listen", "0.0.0.0:5678", "/app/main.py"]
    ports:
    - containerPort: 5678
      name: debug
    env:
    - name: PYTHONUNBUFFERED
      value: "1"
    - name: PYTHONDEBUG
      value: "1"
```

**Using Specialized Debug Images:**

```bash
# Use nicolaka/netshoot for network debugging
kubectl run netshoot --image=nicolaka/netshoot -it --rm -- bash

# Use ubuntu with common tools
kubectl run ubuntu-debug --image=ubuntu -it --rm -- bash
apt-get update && apt-get install -y curl wget netcat dnsutils

# Use busybox for minimal debugging
kubectl run busybox-debug --image=busybox -it --rm -- sh

# Use alpine with additional tools
kubectl run alpine-debug --image=alpine -it --rm -- sh
apk add --no-cache curl wget bind-tools
```

**Key Learning Points:**
- Different languages require different debugging approaches
- Use language-specific debug flags and ports
- Debug images should match or be compatible with app image
- Install debugging tools via exec for temporary troubleshooting
- Use port-forward to connect local debuggers to remote pods
- Set appropriate environment variables for debug mode
- Consider security implications of debug ports in production

## CKAD Exam Tips

### Efficient Troubleshooting Workflow

1. **Start with high-level view**: `kubectl get pods -o wide`
2. **Check events**: `kubectl describe pod <pod-name>`
3. **Review logs**: `kubectl logs <pod-name>`
4. **Verify configuration**: Check selectors, labels, ports
5. **Test directly**: Use `kubectl port-forward` or `kubectl exec`
6. **Fix and reapply**: Edit YAML and redeploy

### Quick Reference: Pod Status Meanings

| Status | Meaning | Common Causes |
|--------|---------|---------------|
| `Pending` | Pod accepted but not scheduled | Resource constraints, node selector, PVC not bound |
| `ContainerCreating` | Pod scheduled, container being created | Pulling image, mounting volumes |
| `Running` | Pod is running | Normal state (check readiness) |
| `CrashLoopBackOff` | Container repeatedly crashing | Application error, failed probe, incorrect command |
| `ImagePullBackOff` | Can't pull container image | Wrong image name, auth failure, network issue |
| `Error` | Pod terminated with error | Container command failed |
| `Completed` | Pod ran to completion | Normal for Jobs |
| `Terminating` | Pod is being deleted | Normal during deletion |

### Time-Saving kubectl Commands

```bash
# Quick aliases for exam
alias k=kubectl
alias kgp='kubectl get pods'
alias kd='kubectl describe'
alias kl='kubectl logs'

# Get all resource types in namespace
kubectl get all

# Watch resources in real-time
kubectl get pods -w

# Quick pod creation for testing
kubectl run test --image=busybox -it --rm -- sh

# Generate YAML quickly
kubectl run test --image=nginx --dry-run=client -o yaml > pod.yaml
```

## Practice Exercises

### Exercise 1: Multi-Layer Troubleshooting

This exercise combines multiple common issues in a single scenario.

**Deploy the broken application:**

```bash
kubectl apply -f labs/troubleshooting/specs/ckad/exercise1-multi-layer.yaml
```

**Problems to identify and fix:**

1. **Deployment replica selector mismatch** - Pods won't be managed by deployment
2. **ConfigMap key reference error** - Environment variable won't populate
3. **Service port mismatch** - Service can't route to pods
4. **ResourceQuota exceeded** - Not enough quota for all replicas

**Troubleshooting steps:**

```bash
# Check deployment status
kubectl get deployment -n exercise1
kubectl describe deployment web-app -n exercise1

# Check pods
kubectl get pods -n exercise1
kubectl describe pods -n exercise1

# Check service endpoints
kubectl get endpoints -n exercise1
kubectl describe service web-service -n exercise1

# Check ConfigMap
kubectl describe configmap app-config -n exercise1

# Check ResourceQuota
kubectl describe resourcequota compute-quota -n exercise1
```

**Apply the fixes:**

```bash
kubectl apply -f labs/troubleshooting/solution/ckad/exercise1-multi-layer-fixed.yaml

# Verify everything works
kubectl get all -n exercise1-fixed
kubectl get endpoints -n exercise1-fixed
```

**Learning objectives:**
- Identify selector mismatches between deployments and pods
- Debug ConfigMap key references
- Troubleshoot service port configuration
- Understand ResourceQuota constraints

### Exercise 2: End-to-End Application Debugging

This exercise simulates a full three-tier application with multiple connectivity issues.

**Deploy the broken stack:**

```bash
kubectl apply -f labs/troubleshooting/specs/ckad/exercise2-full-stack.yaml
```

**Problems to identify:**

1. **Database pod missing required environment variables** - Won't start properly
2. **Database service selector mismatch** - No endpoints
3. **Backend using wrong DNS name** - Can't connect to database
4. **NetworkPolicy blocking all traffic** - Frontend can't reach backend

**Troubleshooting workflow:**

```bash
# Check all resources
kubectl get all -n exercise2

# Check database pod
kubectl describe pod database -n exercise2
kubectl logs database -n exercise2

# Check service endpoints
kubectl get endpoints -n exercise2
kubectl describe service database-service -n exercise2

# Test connectivity
kubectl run test-pod --image=busybox -n exercise2 -it --rm -- sh
# Inside pod: wget -qO- --timeout=5 backend-service

# Check NetworkPolicy
kubectl get networkpolicy -n exercise2
kubectl describe networkpolicy deny-all -n exercise2
```

**Apply the fixes:**

```bash
kubectl apply -f labs/troubleshooting/solution/ckad/exercise2-full-stack-fixed.yaml

# Verify connectivity
kubectl exec -n exercise2-fixed frontend -- wget -qO- backend-service
```

**Learning objectives:**
- Debug multi-tier application connectivity
- Identify service selector mismatches
- Troubleshoot DNS resolution
- Fix NetworkPolicy blocking issues

### Exercise 3: Performance Troubleshooting

This exercise focuses on resource-related performance issues.

**Deploy resource-constrained applications:**

```bash
kubectl apply -f labs/troubleshooting/specs/ckad/exercise3-performance.yaml
```

**Problems to identify:**

1. **Memory-constrained pod** - Will be OOMKilled
2. **CPU-throttled pod** - Severe performance degradation
3. **Deployment without resource limits** - No resource management

**Troubleshooting steps:**

```bash
# Monitor resource usage (requires metrics-server)
kubectl top nodes
kubectl top pods -n exercise3

# Check pod status
kubectl get pods -n exercise3 -w

# Check for OOMKilled
kubectl describe pod memory-constrained -n exercise3
# Look for "OOMKilled" in Last State

# Check previous logs
kubectl logs memory-constrained -n exercise3 --previous

# Monitor CPU usage
kubectl top pod cpu-constrained -n exercise3

# Check deployment resources
kubectl describe deployment no-limits -n exercise3
```

**Apply performance fixes:**

```bash
kubectl apply -f labs/troubleshooting/solution/ckad/exercise3-performance-fixed.yaml

# Compare resource usage
kubectl top pods -n exercise3-fixed
```

**Learning objectives:**
- Identify OOMKilled containers
- Recognize CPU throttling symptoms
- Set appropriate resource requests and limits
- Use metrics to diagnose performance issues

### Exercise 4: Storage Troubleshooting

This exercise covers persistent volume and storage issues.

**Deploy the storage application:**

```bash
kubectl apply -f labs/troubleshooting/specs/ckad/exercise4-storage.yaml
```

**Problems to identify:**

1. **PVC with non-existent storage class** - Won't bind
2. **StatefulSet with overlapping mount paths** - Volume conflict
3. **Pod with readonly volume mount** - Application can't write

**Troubleshooting steps:**

```bash
# Check PVC status
kubectl get pvc -n exercise4
kubectl describe pvc data-claim -n exercise4

# Check available storage classes
kubectl get storageclass

# Check StatefulSet status
kubectl get statefulset -n exercise4
kubectl describe statefulset data-app -n exercise4

# Check pod volume mounts
kubectl describe pod volume-permission-pod -n exercise4

# Try to write to readonly volume
kubectl exec -n exercise4 volume-permission-pod -- touch /usr/share/nginx/html/test.txt
# Will fail due to readonly mount
```

**Apply storage fixes:**

```bash
kubectl apply -f labs/troubleshooting/solution/ckad/exercise4-storage-fixed.yaml

# Verify PVC is bound
kubectl get pvc -n exercise4-fixed

# Verify StatefulSet is running
kubectl get statefulset -n exercise4-fixed
kubectl get pods -n exercise4-fixed

# Test volume write access
kubectl exec -n exercise4-fixed volume-permission-pod-fixed -- \
  sh -c 'echo "test" > /usr/share/nginx/html/test.txt'
kubectl exec -n exercise4-fixed volume-permission-pod-fixed -- \
  cat /usr/share/nginx/html/test.txt
```

**Learning objectives:**
- Troubleshoot PVC binding issues
- Identify storage class problems
- Fix volume mount conflicts
- Understand volume permission issues

## Additional Resources

- [Kubernetes Troubleshooting Documentation](https://kubernetes.io/docs/tasks/debug/)
- [CKAD Curriculum](https://github.com/cncf/curriculum)
- [Debug Running Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/)
- [Debug Services](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/)

## Summary

This comprehensive guide covers all CKAD troubleshooting requirements with hands-on exercises:

### Scenarios Covered

1. **ImagePullBackOff** - Wrong images and private registry authentication
2. **CrashLoopBackOff** - Application crashes, missing configs, and probe failures
3. **Pod Pending** - Resource constraints, node selectors, and PVC issues
4. **Init Containers** - Failed init containers and dependency management
5. **Multi-Container Pods** - Sidecar failures and volume sharing between containers
6. **NetworkPolicy** - Blocked traffic and connectivity testing
7. **DNS Resolution** - Service DNS and CoreDNS debugging
8. **ConfigMap/Secret** - Missing configurations and key mismatches
9. **Volume Mounting** - PVC binding, permissions, and storage classes
10. **Ephemeral Debug Containers** - Advanced debugging techniques (K8s 1.23+)
11. **Resource Quotas** - Quota limits and LimitRange constraints
12. **Performance** - CPU throttling, OOMKilled, and resource bottlenecks
13. **Application-Specific** - Java, Node.js, and Python debugging

### Practice Exercises

Four comprehensive exercises combining multiple troubleshooting scenarios:
- **Exercise 1**: Multi-layer issues (deployment, service, ConfigMap, quota)
- **Exercise 2**: Full-stack debugging (database, backend, frontend, NetworkPolicy)
- **Exercise 3**: Performance issues (OOM, CPU throttling, resource limits)
- **Exercise 4**: Storage troubleshooting (PVC, StatefulSet, volume permissions)

All exercises include:
- Broken specs in `specs/ckad/` directory
- Step-by-step troubleshooting guides
- Fixed solutions in `solution/ckad/` directory
- Real-world scenarios reflecting CKAD exam requirements
