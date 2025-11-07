# Pods - CKAD Exam Preparation Script

**Duration:** 25-30 minutes
**Format:** Screen recording with live demonstration
**Focus:** CKAD exam scenarios and requirements

---

Welcome to the CKAD-focused session on Pods. In this video, we'll go beyond the basics and cover everything you need to know about Pods for the Certified Kubernetes Application Developer exam. The CKAD exam tests your ability to work quickly and accurately with Kubernetes resources. For Pods specifically, you need to master multi-container patterns, resource management, health probes, security contexts, and scheduling. Let's dive into each of these areas with practical examples.

## CKAD Exam Requirements

The CKAD exam expects you to understand and implement several Pod-related concepts. You'll need to work with multi-container Pod patterns like sidecar, ambassador, and adapter. Init containers are commonly tested for setup tasks that need to run before your main application starts. Resource requests and limits are critical for managing cluster resources effectively. Health probes including liveness, readiness, and startup probes ensure your applications are monitored correctly. Environment variables and configuration management through ConfigMaps and Secrets come up frequently. Security contexts for running containers as non-root with restricted permissions are increasingly important. Pod scheduling using node selectors, affinity rules, and taints and tolerations control where your Pods run. Finally, understanding Pod lifecycle and restart policies helps you design resilient applications.

## Multi-Container Pods

Pods can run multiple containers that work together, sharing the same network namespace and storage volumes. This enables several powerful design patterns that you'll encounter in the exam.

### Sidecar Pattern

The sidecar pattern is one of the most common multi-container scenarios you'll see. A helper container runs alongside your main application container. Let me create a Pod with two containers sharing a volume. The main container is an nginx web server, and the sidecar generates content that nginx serves.

We define a volume called "html" using emptyDir, which creates an empty directory that exists as long as the Pod exists. The nginx container mounts this volume at /usr/share/nginx/html, where nginx serves files from. The content-generator container mounts the same volume at /html and runs a loop that writes the current date to index.html every 10 seconds. Both containers share the same volume, so the sidecar's output becomes nginx's content.

After deploying this, we can verify both containers are running. The ready column shows "2/2", meaning both containers are healthy. When we test it by executing curl in the nginx container, we get the current date. Wait 10 seconds and run it again, and the date updates. The sidecar is continuously updating content that nginx serves.

This pattern is incredibly useful for scenarios like log shipping sidecars that collect and forward logs, configuration reloaders that watch for config changes, or monitoring agents that collect metrics. For the exam, remember that containers in a Pod communicate over localhost and can share volumes.

### Ambassador Pattern

The ambassador pattern uses a proxy container to simplify connectivity for the main container. The ambassador acts as a proxy, allowing the main application to connect to localhost instead of knowing external service URLs. This is particularly useful when you want to abstract away complex networking or provide a consistent interface to varying backend services. The main container can always connect to localhost while the ambassador handles the actual routing to external services.

### Adapter Pattern

The adapter pattern transforms the output of the main container to match a standard format. The adapter container reads logs from the main application and transforms them into a standardized format, like converting custom logs to JSON. This is useful when you need to integrate applications that output data in non-standard formats with monitoring or logging systems that expect specific formats.

## Init Containers

Init containers run before your application containers and are commonly tested in the exam. These are perfect for setup tasks that need to complete before your main application starts. Let me demonstrate with an init container that waits for a service to be resolvable before the main container starts.

The Pod will be stuck in "Init:0/1" status because the service doesn't exist yet. When we check the details, the events show the init container is running and waiting. The main nginx container won't start until the init container completes successfully. This pattern is useful for waiting for dependencies to be ready, downloading configuration or data before the app starts, running database migrations, or setting up the environment.

Init containers run sequentially in the order defined, and each must complete successfully before the next starts. When I create the service to unblock it, the init container completes and the app container starts running. This sequential execution guarantee is what makes init containers so valuable for setup workflows.

## Resource Requests and Limits

Resource management is critical for the CKAD exam. You need to understand requests, limits, and Quality of Service classes. When we create a Pod with resource constraints, the requests specify the minimum guaranteed resources. For example, we might request 64 MiB of memory and 250 millicores of CPU, which is 0.25 cores or 25% of one CPU. The limits specify the maximum, like 128 MiB of memory and 500 millicores, which is 0.5 cores or 50% of one CPU.

When we check the Quality of Service class using describe, we see it's "Burstable" because we have requests that are less than limits. This means the Pod is guaranteed the requested resources, can burst up to the limits if resources are available, and during resource pressure, BestEffort Pods are evicted first, then Burstable, then Guaranteed. For a Guaranteed QoS class, requests must equal limits for all containers and all resources.

### Quality of Service (QoS) Classes

Let me show you what happens when a container exceeds its memory limit. I'll create a Pod that tries to allocate more memory than allowed. This Pod tries to allocate 150MB when the limit is 100MB. After a few seconds, the status changes to "OOMKilled", which means Out Of Memory Killed. The container exceeded its memory limit and was terminated. In the events, you'll see "Container was OOMKilled". This is exactly what happens when you misconfigure memory limits, and it's a common exam scenario where you need to troubleshoot failing Pods.

## Health Probes

Health probes are essential for production workloads and frequent exam topics. Let's implement liveness and readiness probes to understand how they work.

### Liveness Probe

The liveness probe determines whether a container is healthy and restarts it if the probe fails. When we configure a liveness probe, it might make an HTTP GET request to a specific path and port, wait a certain number of seconds after container start before the first check, then check every few seconds. If the probe fails, Kubernetes restarts the container. This is crucial for recovering from deadlocks or other conditions where the process is running but not functioning properly.

Probes can use different mechanisms. HTTP GET probes make a request and expect a success status code. TCP socket probes check if a port is accepting connections. Exec probes run a command inside the container, and if the command returns 0 for success, the probe passes.

### Readiness Probe

The readiness probe determines whether a container is ready to serve traffic. Unlike the liveness probe, if a readiness probe fails, Kubernetes removes the Pod from Service endpoints but doesn't restart the container. This is useful during startup when the application is loading data or warming up caches, or during temporary overload situations where the app is healthy but temporarily can't accept more requests.

The configuration is similar to liveness probes, with HTTP GET, TCP socket, or exec options. The key difference is the behavior: liveness restarts the container, readiness removes it from load balancing.

### Startup Probe

Startup probes allow slow-starting containers more time before liveness checks begin. The liveness probe doesn't start checking until the startup probe succeeds. This is particularly useful for legacy applications or those with long initialization times. Without a startup probe, you'd have to set a very long initial delay on the liveness probe, which delays detection of actual failures in subsequent restarts.

For the exam, you should be comfortable creating all three types of probes quickly and understanding when to use each one.

## Environment Variables and Configuration

The exam often requires you to configure Pods with environment variables from various sources. Let's create a ConfigMap first, then a Pod that uses it. There are three ways to set environment variables in a Pod. Static values use name and value fields directly in the Pod spec. Single values from ConfigMap use valueFrom with configMapKeyRef to reference a specific key. All keys from a ConfigMap can be loaded at once using envFrom with configMapRef.

When we check the environment variables in the running Pod, we see all of them populated correctly. The envFrom loaded all keys from the ConfigMap, which is convenient when you have many configuration values. The same patterns work with Secrets, you just replace configMapKeyRef with secretKeyRef. This is important for sensitive data like passwords or API keys.

## Security Contexts

Security contexts define privilege and access control settings. This is increasingly important for the CKAD exam as security becomes more emphasized. Let's create a Pod that runs as a non-root user with security constraints.

We can configure the Pod to run as a specific user ID and group, set the file system group for volume ownership, prevent privilege escalation, and drop all Linux capabilities. When we verify the security settings by checking the running process, we see it's running with the exact user and group IDs we specified.

For a more secure configuration, we can add a read-only root filesystem. The readOnlyRootFilesystem setting makes the container's root filesystem read-only, preventing any modifications. Your application can still write to mounted volumes, which is where you'd configure writable directories for things that need write access like temporary files or logs. The runAsNonRoot setting ensures Kubernetes rejects the Pod if the image tries to run as root, providing an additional safety check.

## Service Accounts

Every Pod runs with a service account that determines API access permissions. By default, Pods use the default service account in their namespace, but you can create custom service accounts with specific permissions. When we assign a custom service account to a Pod using the serviceAccountName field, that Pod's containers can access the Kubernetes API with the permissions granted to that service account.

The service account token is automatically mounted at /var/run/secrets/kubernetes.io/serviceaccount/ inside the container. Applications can read this token to make authenticated API calls. For increased security, you can disable automatic token mounting if your application doesn't need API access. Combined with RBAC roles and role bindings, service accounts provide fine-grained control over what Pods can do in the cluster.

## Pod Scheduling

Understanding how to control where Pods run is essential for the CKAD exam. There are several mechanisms with increasing levels of sophistication.

### Node Selectors

The simplest approach is node selectors. First, we label a node with something like disktype equals ssd. Then we create a Pod spec with a nodeSelector field specifying that label. The Pod will only schedule on nodes with the matching label. When we check where it scheduled, it should be on the node we labeled. Node selectors are straightforward but limited to simple equality checks.

### Node Affinity

Node affinity provides more expressive node selection with required and preferred rules. Required affinity means the Pod will only schedule on nodes matching the criteria. You use requiredDuringSchedulingIgnoredDuringExecution with nodeSelectorTerms and matchExpressions. This supports operators like In, NotIn, Exists, DoesNotExist, Gt, and Lt, giving you much more flexibility than simple node selectors.

Preferred affinity means the Pod prefers matching nodes but can schedule elsewhere if needed. You use preferredDuringSchedulingIgnoredDuringExecution with weights that indicate how strongly you prefer certain characteristics. Kubernetes tries to find the best match but won't leave the Pod unscheduled if no node meets the preferences. You can combine both required and preferred rules for precise control, like requiring SSD storage but preferring a specific region.

### Pod Affinity and Anti-Affinity

Pod affinity and anti-affinity control Pod placement relative to other Pods. Pod affinity schedules Pods near other pods, like on the same node or in the same zone. This is useful for co-locating an app with its cache for low latency. You specify a label selector to identify the Pods to be near, and a topology key like kubernetes.io/hostname for the same node.

Pod anti-affinity schedules Pods away from other pods on different nodes or zones. This is crucial for high availability, spreading replicas across nodes so a node failure doesn't take down your entire application. The configuration is similar but uses podAntiAffinity instead. For zone-level distribution, you use topology.kubernetes.io/zone as the topology key.

### Taints and Tolerations

Taints on nodes repel pods, while tolerations allow pods to schedule on tainted nodes. This is the opposite approach from affinity. You taint a node with a key, value, and effect. The NoSchedule effect means Pods won't be scheduled unless they tolerate the taint. PreferNoSchedule means Kubernetes tries to avoid scheduling but it's not guaranteed. NoExecute means Pods are evicted if they don't tolerate the taint, and you can even set tolerationSeconds for temporary toleration.

In the Pod spec, you add tolerations that match the taints. The Equal operator matches specific key and value, while Exists matches any value for the key. You can combine multiple tolerations in one Pod and even combine them with node affinity for very precise placement control.

## Pod Lifecycle and Restart Policies

Kubernetes supports three restart policies: Always, OnFailure, and Never. Always is the default and restarts the container regardless of exit status. OnFailure restarts only if the container exits with an error code. Never means Kubernetes won't restart the container at all. The choice depends on your workload type. Long-running services typically use Always, batch jobs use OnFailure, and one-time tasks use Never.

### Container Lifecycle Commands

Lifecycle hooks allow you to run code at specific points in a container's lifecycle. The postStart hook runs immediately after the container starts, though it runs asynchronously with the container's main process. This is useful for initialization tasks like warming up caches or registering the service. If postStart fails, the container is killed.

The preStop hook runs before the container stops, implementing graceful shutdown. You might use this to drain connections, save state, or perform cleanup. The hook runs before the TERM signal is sent, and the Pod's terminationGracePeriodSeconds includes the preStop time. Both hooks can use exec to run commands or httpGet to make HTTP requests. A well-designed preStop hook ensures your application shuts down cleanly without dropping requests or losing data.

## Labels and Annotations

Labels are used for organization and selection, while annotations store non-identifying metadata. Labels are key-value pairs that you can use to select groups of resources. Common labels include app for the application name, tier for the architecture tier like frontend or backend, environment for production or staging, and version for release tracking.

Annotations store arbitrary metadata that isn't used for selection. You might put a description of the resource, contact information like an owner email, or links to documentation. The key difference is that labels are indexed and used by selectors, while annotations are just for information. When querying Pods, you use label selectors to filter by label values, match multiple conditions, or check for label existence.

## Lab Exercises

The lab exercises combine multiple concepts into realistic scenarios. A multi-container Pod exercise might have you create an nginx web server with a sidecar container that fetches content every 30 seconds. They share a volume where the sidecar writes content and nginx serves it.

A resource management exercise demonstrates resource limits by setting a memory limit and having the container attempt to allocate more memory than allowed, so you can observe the OOMKilled behavior. Health check exercises have you create Pods with startup, liveness, and readiness probes using different methods like httpGet, exec, and tcpSocket.

Security hardening exercises combine multiple best practices: running as a non-root user, using a read-only root filesystem, dropping capabilities except what's needed, using a custom service account, and including resource limits. These comprehensive exercises prepare you for the multi-requirement questions common in the exam.

## Common CKAD Scenarios

Several scenarios come up repeatedly in the exam. Debugging a failing Pod involves checking the status and restart count, looking for probe failures in events, checking the probe configuration, testing probes manually by executing the same commands the probe uses, and viewing logs from previous instances if the container is restarting.

Updating environment variables in a running Pod isn't possible because Pods are immutable in most ways. You must recreate the Pod with the new configuration. For production workloads, you'd use a Deployment which handles rolling updates automatically. If you use ConfigMaps as volume mounts instead of environment variables, changes sync automatically within about 60 seconds, though the application must watch the file and reload its config.

Fixing resource issues requires understanding the symptoms. OOMKilled status means memory limit is too low or there's a memory leak. High restart counts indicate resource or application issues. CPU at 100% of the limit suggests throttling that's affecting performance. Pending status means there aren't sufficient node resources to schedule the Pod. You can monitor resource usage with kubectl top and adjust requests and limits based on actual usage patterns.

## Quick Reference Commands

Several kubectl commands are essential for working efficiently with Pods. Creating from YAML uses apply. Getting Pods with labels shown uses the show-labels flag. Filtering by label uses the selector flag. Getting Pod YAML output uses the yaml output format. Editing a Pod is limited to certain fields because Pods are mostly immutable. For significant changes, you delete and recreate.

Describing a Pod shows events, conditions, and status, which is invaluable for troubleshooting. Getting logs uses the logs command, optionally specifying a container name in multi-container Pods. Executing commands uses exec, with the it flags for interactive sessions. You can customize output with custom columns to show exactly the fields you need. Watching Pod status in real-time uses the watch flag. Monitoring resource usage uses kubectl top. Port forwarding makes a Pod accessible on localhost. Copying files to and from Pods uses the cp command.

## Cleanup

Remove all Pods created in these exercises by deleting them all at once, or use label selectors to remove specific Pods that match certain labels. This keeps your cluster clean and ready for the next exercise.

## Next Steps

After mastering Pods, continue with other CKAD topics like ConfigMaps for configuration management, Secrets for secure configuration, Deployments for application deployment and scaling, and Services for networking and load balancing. The patterns and concepts you've learned with Pods form the foundation for all higher-level Kubernetes resources. Practice these scenarios until you can create them quickly without references, and you'll be well-prepared for the Pod-related questions on the CKAD exam.
