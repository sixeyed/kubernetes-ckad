# Troubleshooting for CKAD - Narration Script

**Duration:** 45-50 minutes
**Format:** Screen recording with live demonstration
**Prerequisite:** Completed basic Troubleshooting exercises

---

Welcome to the CKAD exam preparation module for Kubernetes troubleshooting. This is perhaps the most important skill you'll need for the exam, because troubleshooting isn't a separate domain - it's something you'll use across every single question. When something doesn't work on the exam, and trust me it will happen, you need to diagnose and fix it quickly.

The CKAD exam expects you to evaluate cluster and node logging, understand and debug application deployment issues, monitor applications, debug services and networking issues, and troubleshoot pod failures and application issues. That's a lot, but with systematic practice, you'll develop a troubleshooting workflow that becomes second nature.

## CKAD Troubleshooting Requirements

Let's start by understanding what the exam actually tests. You need to be comfortable with the essential kubectl commands that reveal what's happening in your cluster. The get commands give you an overview. The describe commands show detailed information and events. The logs commands let you see what your applications are saying. The exec commands let you run diagnostic tools inside containers. And the events commands show you the cluster-wide activity.

Time management is critical on the exam. For straightforward troubleshooting questions, you should aim for two to three minutes. More complex multi-resource issues might take five to seven minutes. But never spend more than ten minutes on a single problem - if you're stuck, move on and come back later. The exam is about points, not perfection.

## Core Troubleshooting Commands

Let me show you the essential commands you need to know cold. When I start troubleshooting, I always begin with get pods. The wide output format shows additional details like IP addresses and node assignments. The all namespaces flag helps when you're not sure where something is running. And the show labels flag reveals the labels that services use for selectors.

The describe command is where you'll spend most of your time. When I describe a pod, I get the complete picture - the pod's status, its conditions, container states, and most importantly, the events at the bottom. Those events tell you exactly what Kubernetes tried to do and where it failed. Image pull errors, probe failures, scheduling issues - they're all there in the events.

For logs, the basic command shows current output, but you'll often need the previous flag to see logs from a crashed container. The follow flag is useful for watching logs in real time, though be careful with it on the exam since it blocks your terminal. For multi-container pods, you need to specify which container's logs you want to see.

The exec command is powerful for interactive debugging. You can run commands inside containers to check configuration files, test network connectivity, or inspect the environment. The interactive terminal flags let you get a shell inside a container, which is incredibly useful for investigation.

## Common Pod Failure Scenarios

Now let's work through the most common pod failures you'll encounter on the exam. Each has characteristic symptoms and a standard diagnostic approach.

### ImagePullBackOff / ErrImagePull

ImagePullBackOff is one of the most common issues. The pod status shows ImagePullBackOff or ErrImagePull, the pod never reaches Running state, and the restart count stays at zero. This happens when Kubernetes can't pull the container image. Common causes include incorrect image names or tags, images that don't exist in the registry, private registry authentication failures, or network connectivity issues.

When I see ImagePullBackOff, I immediately describe the pod to check the events. The events will show the exact error - maybe the image name is wrong, maybe it can't authenticate to a private registry. For private registries, you need to create an image pull secret and reference it in the pod spec. Let me demonstrate by deploying a pod with a wrong image name.

The pod goes into ImagePullBackOff almost immediately. When I describe it, the events section shows that Kubernetes can't find the image. The fix is straightforward - correct the image name and reapply, or if it's a private registry, create the appropriate secret and add it to the pod's imagePullSecrets field.

### CrashLoopBackOff

CrashLoopBackOff means your container is starting but then immediately crashing, and Kubernetes keeps trying to restart it with increasing backoff delays. The pod status alternates between Running and CrashLoopBackOff, and the restart count continuously increases. This is usually an application error at startup, missing dependencies like environment variables or external services, an incorrect command or arguments, or a failed liveness probe that's too aggressive.

The key to diagnosing crashes is looking at the logs. But here's the catch - if the container already crashed, the current logs might be empty. That's when you need the previous flag to see what happened before the crash. Let me show you a pod with a missing environment variable.

When I check the logs with the previous flag, I can see the application tried to start but complained about a missing configuration. The events in describe show the container keeps exiting with a non-zero code. The fix depends on the specific error - maybe add the missing environment variable, correct the command, adjust the liveness probe timing, or fix the application configuration.

### Pod Pending

A pod stuck in Pending state means it was accepted by the API server but hasn't been scheduled to a node yet. Common causes are insufficient cluster resources like CPU or memory, node selector or affinity rules that can't be satisfied, a PersistentVolumeClaim that isn't bound, or taints and tolerations mismatches.

When I describe a pending pod, the events tell me exactly why it can't be scheduled. Maybe it says insufficient CPU, or no nodes match the node selector, or waiting for volume to be bound. Let me create a pod with excessive resource requests that the cluster can't satisfy.

The pod stays pending, and the events explain that no nodes have enough resources. To check available resources, I can describe the nodes or use the top nodes command if metrics server is installed. The fix might be reducing resource requests, changing node selectors, creating required persistent volumes, or adding appropriate tolerations.

### Container Not Ready

Sometimes a pod shows Running status, but the Ready column shows zero out of one instead of one out of one. This means the container is running but hasn't passed its readiness probe yet. Services won't route traffic to pods that aren't ready, so this effectively removes the pod from the load balancer.

Common causes are readiness probes failing, applications being slow to start, or incorrect readiness probe configuration. When I describe the pod, I look for readiness probe failure events. Maybe the probe is checking too early before the application is actually ready, or maybe the probe configuration is wrong - checking the wrong port or path.

The fix usually involves adjusting the readiness probe timing. Increase the initial delay to give the application more time to start, or adjust the period and timeout values. Make sure the probe is checking the right endpoint that actually indicates the application is ready to serve traffic.

### Init Container Issues

Init containers run before your main application containers and must complete successfully. When they fail, the pod status shows Init with a fraction like zero out of one, or Init:Error, or Init:CrashLoopBackOff. The main containers never start until all init containers complete.

To check init container logs, I specify the init container name when using the logs command. Let me deploy a pod with a failing init container. The pod stays in Init:Error state. When I check the logs for the init container specifically, I can see what went wrong. Maybe it's trying to connect to a service that doesn't exist yet, or it's running a command that fails.

The solution depends on what the init container is trying to do. If it's waiting for a dependency, make sure that dependency exists first. If it's running a setup script, fix the script or the conditions it expects.

### Multi-Container Pod Issues

Multi-container pods show their ready count as a fraction - like one out of two when one container is ready but another isn't. Each container in the pod needs to be investigated separately. When I describe the pod, I look at each container's status individually. Then I check logs for each container by name.

Let me show you a pod with a main application and a sidecar where the sidecar is failing. The pod shows one out of two ready. When I describe it, I can see the main container is fine but the sidecar is crash-looping. I check the sidecar logs specifically and find it's trying to access a volume path that doesn't exist. The fix is correcting the volume mount configuration for that specific container.

## Service and Networking Troubleshooting

Service issues are extremely common because they involve the interaction between multiple resources. The number one most common problem is services not routing to pods.

### Service Not Routing to Pods

When a service can't route to pods, you'll see symptoms like connection timeouts, connection refused errors, or the service works with pod IPs but not the service name. There are three main root causes - selector mismatch, port mismatch, and named port mismatch.

Selector mismatch is the most common. The service selector doesn't match the pod labels. When I check the endpoints for the service, if it shows none, that's a selector problem. Let me demonstrate by creating a service with the wrong selector.

The service is created successfully, but when I check its endpoints, there are none. That immediately tells me the selector doesn't match any pods. I compare the service selector to the actual pod labels, find the mismatch, and fix it. As soon as I update the service with the correct selector, Kubernetes automatically populates the endpoints.

Port mismatch is the second common issue. The service's target port must match the container port. If they don't align, the service routes traffic to the wrong port on the pod. Let me show you a pod running on port 8080 but a service configured to route to port 80. The service has endpoints, so the selector is right, but when I try to access it, nothing responds. Checking the service describe and the pod describe shows the port mismatch. Fix the target port on the service to match the container port.

Named ports add another layer. If your service references a named port, that name must exist in the pod spec. Otherwise, Kubernetes doesn't know which port to use. The fix is ensuring port names match exactly between the pod and service.

For the exam, always start troubleshooting services by checking if they have endpoints. No endpoints means selector problem. Has endpoints but doesn't work means port problem. This simple check saves you minutes of investigation.

### DNS Resolution Issues

DNS issues manifest as pods not being able to resolve service names. First, verify that CoreDNS pods are running in the kube-system namespace. They're essential for service discovery in the cluster. If they're not running or crash-looping, nothing will be able to resolve service names.

When testing DNS, remember the different formats. Within the same namespace, you can just use the service name. Across namespaces, you need the service name dot namespace. The fully qualified domain name is service name dot namespace dot svc dot cluster dot local. Let me show you by running a test pod and checking DNS resolution for a service.

From the test pod, I can use nslookup to check if DNS is working. If it resolves correctly, DNS is fine and the problem is elsewhere. If it doesn't resolve, check if CoreDNS is healthy, verify the service actually exists, and check for network policies that might be blocking DNS traffic.

### Network Policy Blocking Traffic

Network policies can silently block pod communication, which is confusing because everything looks fine - pods are running, services have endpoints, but connections timeout. When you suspect network policies, check if any exist in the namespace. If they do, examine their pod selectors and rules carefully.

An empty ingress rules list means deny all ingress traffic. To allow traffic, you need to explicitly define what's permitted. This includes specifying which pods can send traffic and optionally which namespaces they're in. Let me deploy a network policy that blocks all traffic, then show you how to fix it.

After applying the deny-all policy, existing connections fail. When I try to access a pod from another pod, it times out. The fix is creating a network policy that allows the required traffic patterns, being specific about pod selectors and port numbers.

## Configuration Issues

ConfigMaps and Secrets are involved in almost every CKAD question, and they're a frequent source of errors.

### ConfigMap and Secret Problems

The most common issue is a ConfigMap or Secret that doesn't exist. Your pod goes into CreateContainerConfigError state. When you describe the pod, the events clearly state which ConfigMap or Secret is missing. The fix is creating the missing resource in the correct namespace.

Key name mismatches are equally common. The ConfigMap exists, but your pod references a key that isn't in the ConfigMap. Again, CreateContainerConfigError status. When I describe the pod, it tells me specifically which key it can't find. I check the ConfigMap to see what keys actually exist, and either fix the ConfigMap to add the missing key or fix the pod to reference the correct key.

Remember that ConfigMaps and Secrets must be in the same namespace as the pods that use them. You can't reference a ConfigMap from another namespace. If your pod is in the default namespace but the ConfigMap is in the production namespace, it won't work. The solution is either moving the ConfigMap to the correct namespace or moving the pod.

Volume mount conflicts happen when you try to mount to the same path twice or when mount paths overlap. Kubernetes rejects the pod creation with an error about duplicate mount paths. The fix is using unique mount paths for each volume.

### Volume Mounting Issues

PersistentVolumeClaim issues usually show as pods stuck in Pending or ContainerCreating state. When a PVC is in Pending state, it means no PersistentVolume matches its requirements. Check the PVC status, then check if any PVs are available. The PV needs to have at least the requested storage capacity, matching access modes, and if a storage class is specified, it must match.

For the exam environment, you might need to create PVs manually if dynamic provisioning isn't available. Make sure the capacity, access modes, and storage class all align with what the PVC requests. Once a matching PV exists, the PVC binds automatically and the pod can proceed.

## Advanced Troubleshooting Techniques

For Kubernetes 1.23 and later, ephemeral debug containers are a game-changer for troubleshooting. They let you attach a debugging container to a running pod without modifying the pod spec. This is especially useful for minimal or distroless images that don't include debugging tools.

Let me show you debugging a pod that has no shell. Normal exec fails because there's no shell in the image. But I can use the debug command to attach a busybox container with all the standard Linux tools. Now I can inspect the filesystem, check processes, test network connectivity, all without stopping or modifying the original pod.

You can also create a copy of a pod with debugging capabilities, which is useful when you need to change something about the pod configuration to debug it. The debug node command is helpful for node-level issues, giving you access to the node's filesystem through a container.

### Resource Quotas and Limit Ranges

ResourceQuotas limit total resource usage in a namespace. If you try to create a pod that would exceed the quota, it's rejected immediately. The error message tells you which quota was exceeded. Check the current quota usage by describing the ResourceQuota, which shows what's used versus the limit.

LimitRanges constrain individual pod or container resources. They can set minimum and maximum values, and they can provide defaults if you don't specify requests and limits. If your pod violates a LimitRange, creation fails with a clear error about which limit was exceeded.

The fix is adjusting your pod's resource requests and limits to fit within the constraints, or if appropriate, adjusting the ResourceQuota or LimitRange itself.

### Debugging Performance Issues

Performance problems are harder to spot but equally important. CPU throttling happens when containers hit their CPU limits. The container runs slowly but doesn't crash. You need metrics-server installed to see resource usage. The top pods command shows current CPU and memory consumption.

Memory issues are more dramatic. When a container exceeds its memory limit, Kubernetes kills it with OOMKilled - out of memory killed. The pod restarts, and when you describe it, you'll see OOMKilled in the last termination reason. The fix is increasing the memory limit to something realistic for your application.

For the exam, if you see OOMKilled, increase memory limits. If an application is slow, check if it's hitting CPU limits and adjust accordingly. Use realistic resource requests based on what your application actually needs.

## CKAD Exam Tips

Let me walk you through an efficient troubleshooting workflow for the exam. Start with a quick assessment - use get pods to see the high-level status. This takes seconds and immediately tells you if you have a ImagePullBackOff, CrashLoopBackOff, Pending, or ready pod.

Next, detailed diagnosis with describe pod. Read the events carefully - they usually point directly to the problem. For crashes, check logs with the previous flag. For service issues, check if the service has endpoints. This entire diagnosis phase should take one to two minutes.

Then verify the configuration by comparing what the pod expects versus what actually exists. Do the ConfigMap keys match? Do the labels match the selector? Do the ports align? This systematic check catches most issues.

Finally, fix and verify. Make your changes, watch the pod status, and test that it actually works. Don't just check that the pod is Running - verify it's Ready, has no restarts, and actually responds to requests. This entire workflow should take three to five minutes for straightforward issues.

For the exam, know these command shortcuts cold. Set up aliases if you're comfortable with them. Practice until you can type kubectl describe pod without thinking. The time you save on typing lets you spend more time solving problems.

## Practice Exercises

The CKAD guide includes comprehensive practice exercises that combine multiple troubleshooting scenarios. Work through them systematically, timing yourself. Try to complete each scenario within the target time. When you get stuck, resist the urge to look at the solution immediately - that's not helping you learn. Force yourself to investigate and try different approaches.

Practice the multi-layer troubleshooting exercise where deployment selectors don't match pod labels, ConfigMap keys are wrong, service ports don't match, and ResourceQuotas are exceeded. This mirrors real exam complexity where multiple things are broken simultaneously.

The end-to-end application debugging with database, backend, and frontend tiers teaches you to trace problems through connected services. When the frontend can't reach the backend, you need to verify each layer - are the pods running? Do services have endpoints? Are network policies blocking traffic? Is DNS resolution working?

The performance troubleshooting scenarios teach you to identify memory constraints causing OOMKilled containers and CPU limits causing throttling. These issues are subtle but common in real deployments.

## Summary

Troubleshooting is tested in every CKAD domain because it's essential to actually using Kubernetes. Master the core commands - get, describe, logs, exec. Learn the common failure patterns - ImagePullBackOff means image problems, CrashLoopBackOff means application errors, Pending means scheduling issues, CreateContainerConfigError means configuration problems.

Always follow a systematic workflow. Start broad with high-level status, narrow down with detailed information, verify configuration details, fix the issues, and always verify your fixes worked. Practice until this becomes automatic.

Time management is crucial. Simple issues should take two to three minutes. Complex multi-resource problems might take five to seven minutes. Never exceed ten minutes on a single problem. Remember, partial credit doesn't exist - the solution either works or it doesn't.

Set up your exam environment efficiently with aliases and your preferred editor. Know how to use kubectl explain since it's available during the exam. Practice these scenarios dozens of times until you can diagnose any common issue in under three minutes. Master troubleshooting and you'll excel on the CKAD exam.
