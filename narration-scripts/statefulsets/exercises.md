# StatefulSets - Exercises Narration Script

**Duration:** 18-20 minutes
**Format:** Screen recording with live demonstration
**Prerequisite:** Kubernetes cluster running, completed Pods, Services, and Deployments labs

---

Welcome back! In the previous video, we covered the concepts behind Kubernetes StatefulSets. Now it's time to get hands-on and explore how StatefulSets manage stateful applications with stable network identities and persistent storage.

Most workloads run happily in Deployments where Pods are interchangeable and can start in any order with random names. But some applications need stability. Think about a replicated database where you have a primary node and several secondaries. The secondaries need to know exactly how to find the primary by name, and they need to wait until the primary is ready before they start. That's where StatefulSets come in, providing ordered startup with predictable names and stable DNS entries for each Pod.

Let's dive into the practical side of StatefulSets and see how they manage this stability in a real Kubernetes cluster.

## When to Use StatefulSets vs Deployments

Before we start deploying, it's worth taking a moment to understand when you actually need a StatefulSet versus a regular Deployment. This matters because StatefulSets are more complex and slower to work with than Deployments.

You'll want a StatefulSet when your application needs stable, predictable Pod names like app-zero, app-one, app-two instead of random hash-based names. You'll need one when Pods must start in a specific order, waiting for previous Pods to be ready before the next one begins. StatefulSets become essential when you need stable network identities where each Pod has its own DNS entry, or when you need persistent storage that's tied to a specific Pod replica. They shine in primary-secondary architectures where there's a leader Pod that followers need to connect to by name.

On the other hand, you'll stick with Deployments when Pod names can be random and all instances are identical. Deployments work great when all Pods can start in parallel without dependencies, when simple load-balanced access through a Service is sufficient, and when your application is stateless or uses shared storage. Common examples include web applications, API services, and frontend applications where any Pod can handle any request.

The key insight is that databases like MySQL or PostgreSQL, distributed databases like Cassandra or MongoDB, message queues like RabbitMQ or Kafka, and coordination services like Zookeeper typically need StatefulSets. Meanwhile, web servers, REST APIs, microservices, and background workers are perfectly happy in Deployments.

## API specs

Let's start by looking at a StatefulSet YAML file. I'll open the statefulset.yaml file from the simple specs directory. StatefulSet definitions have the usual metadata with a name, but the spec has some unique requirements compared to Deployments.

The spec includes a selector with matchLabels, just like a Deployment, and it has a template section for the Pod spec. However, there's one critical addition called serviceName. This field references a headless Service that must exist before the StatefulSet can function properly. The headless Service is what enables the stable network identities for each Pod.

Speaking of headless Services, let me show you what makes them special. Looking at the services.yaml file, you'll see a standard Service definition but with one crucial difference. The clusterIP field is set to None. This is mandatory for StatefulSets. A headless Service doesn't get a ClusterIP for load balancing. Instead, it manages DNS entries for individual Pods, which is exactly what we need for stable network identities.

The selector in the headless Service must match the Pod labels in the StatefulSet template. This is how Kubernetes knows which Pods belong to this StatefulSet and should get individual DNS entries. Unlike regular Services that provide a single DNS name that load balances to all Pods, a headless Service provides DNS entries for each individual Pod using a predictable pattern.

## Deploy a simple StatefulSet

Let's deploy our first StatefulSet and watch how it behaves differently from a Deployment. Your cluster should be empty if you cleared down from the last lab. We'll start with a StatefulSet running Nginx. While Nginx doesn't truly need the features of a StatefulSet, it makes a great example because we can focus on the StatefulSet behavior without getting distracted by complex database logic.

This deployment includes several components working together. There's a headless Service for stable network identities, external Services using LoadBalancer and NodePort for access from outside the cluster, a ConfigMap containing shell scripts that the Pods will use during initialization, and the StatefulSet itself which uses init containers to model a stable startup workflow.

The pattern we're demonstrating here simulates a primary-secondary architecture. Pod-zero will act as the primary, while Pod-one and Pod-two act as secondaries. The init containers implement logic where the secondaries wait for the primary to be ready before they proceed with their own initialization.

When I apply this StatefulSet, something interesting happens that's completely different from Deployments. Immediately watch the Pod creation and you'll notice a deliberate sequence. Pod-zero appears first and goes through its initialization stages. The StatefulSet controller waits until Pod-zero reaches Running and Ready status before it even creates Pod-one. Once Pod-one is Running and Ready, only then does Pod-two get created. This sequential pattern is the key distinguishing behavior of StatefulSets.

Also notice the Pod names. Unlike Deployments where you get random suffixes like whoami-7f8b9c-x4k2p, StatefulSets give you predictable names: simple-statefulset-zero, simple-statefulset-one, simple-statefulset-two. These names are stable across Pod restarts and rescheduling.

Let's verify the init container logic worked correctly by examining the logs. Looking at the wait-service init container logs from Pod-zero, you should see output indicating this Pod recognizes itself as the primary because its hostname ends in -0. The init container checks the hostname and says essentially, I'm Pod-zero so I must be the primary, no need to wait for anything.

Now look at Pod-one's wait-service init container logs. This Pod knows it's a secondary because its hostname doesn't end in -0. The script tries to resolve the DNS entry for simple-statefulset-zero.simple-statefulset in the cluster DNS. If the DNS entry doesn't exist yet, the init container waits and keeps checking. Once the primary is ready and has a DNS entry, the secondary's init container completes and allows the main container to start.

This demonstrates a powerful pattern. Init containers can use the Pod's own hostname combined with DNS lookups to implement conditional startup logic. This is a common approach in StatefulSet deployments where followers need to wait for leaders.

## Communication with StatefulSet Pods

Now let's explore how networking works differently with StatefulSets. The StatefulSet registers all Pod IPs with the associated Service, just like a Deployment would. When you check the Service endpoints, you should see three IP addresses listed, one for each Pod. The headless Service knows about all Pods even though it doesn't provide load-balancing at the network level.

What makes StatefulSets special is DNS resolution. Let me deploy a sleep Pod that we can use for testing DNS from inside the cluster. From this sleep Pod, we can perform DNS lookups using nslookup.

First, try looking up the Service name without any Pod-specific information. This returns all three Pod IP addresses. The Service name resolves to the complete set of Pods, which is similar to how regular Services work.

Now here's where it gets interesting. Lookup a specific Pod using its full DNS name. When you query simple-statefulset-two.simple-statefulset.default.svc.cluster.local, you get back only the IP address for Pod-two. This is unique to StatefulSets. Each Pod gets its own DNS entry following a predictable pattern.

The DNS naming follows a specific format: pod-name.service-name.namespace.svc.cluster.local. For our example, Pod-two has the DNS name simple-statefulset-two.simple-statefulset.default.svc.cluster.local. If you're working within the same namespace, you can use the shorter form simple-statefulset-two.simple-statefulset.

This capability is transformative for stateful applications. For databases, it means secondary replicas can reliably connect to the primary at a known DNS name like postgres-zero.postgres.default.svc.cluster.local. For message queues, it means nodes can form clusters using stable addresses. For distributed systems, it means each instance can be individually addressable.

The example also includes LoadBalancer and NodePort Services for external access. These Services behave like normal Services, providing load-balanced access to all the Pods. When you access the application through the LoadBalancer on port 8010 or NodePort on port 30010 and refresh multiple times, you'll see responses from different Pods as requests are load-balanced across the replicas.

Here's an interesting technique. StatefulSets automatically add the Pod name as a label on each Pod. This means you can update the external Service selector to target a specific Pod by adding the statefulset.kubernetes.io/pod-name label. When you update the Service to select only Pod-one, all traffic now goes to that specific Pod. This is useful in database scenarios where you might want to route read-only queries specifically to secondary replicas while keeping write traffic on the primary.

## Deploy a replicated SQL database

Now we're ready for a real stateful application: PostgreSQL with primary-replica replication. This example truly requires StatefulSet features because Pod-zero needs to be the primary database while Pod-one needs to be a replica that streams changes from the primary. Each Pod needs its own PersistentVolumeClaim for database storage that persists even if the Pod is rescheduled.

The complexity of setting up PostgreSQL replication is handled by a custom Docker image with initialization scripts, so we can focus on the StatefulSet configuration rather than database administration details.

Here's where StatefulSets really shine: volumeClaimTemplates. This is a feature that Deployments don't have. In the StatefulSet spec, you define a volumeClaimTemplates section that works like a template for creating PersistentVolumeClaims. When the StatefulSet creates Pod-zero, Kubernetes automatically creates a PVC named data-products-db-zero. When Pod-one is created, Kubernetes creates data-products-db-one. Each PVC is bound to a PersistentVolume from the default StorageClass.

The critical benefit is persistence across Pod lifecycles. If Pod-one is deleted for any reason and recreated, the new Pod-one reattaches to the exact same data-products-db-one PVC. The data persists even though the Pod itself is new. You don't need to manually create PVCs for each replica; the StatefulSet controller handles this automatically.

When you deploy the complete database stack and watch the PVC creation, you'll see a clear sequence. First, data-products-db-zero PVC is created and becomes Bound to a PersistentVolume. Then Pod-zero starts and uses this PVC to store its database files. Once Pod-zero reaches Running and Ready status, data-products-db-one PVC is created. Finally, Pod-one starts and uses the second PVC. This tight coupling between StatefulSet Pod creation and PVC provisioning ensures each Pod has storage ready before it tries to start the database.

Let's verify the database replication worked correctly by examining the logs. Pod-zero's logs should show PostgreSQL initializing as a primary database, going through startup procedures, and eventually logging that the database system is ready to accept connections. This Pod detected its hostname ends in -0 and configured itself as the primary.

Pod-one's logs tell a different story. This Pod started in replica mode, connected to the primary for replication using the stable DNS name products-db-zero.products-db.default.svc.cluster.local, started a replication stream, and then became ready to accept read-only connections. The stable DNS names make this automatic discovery possible without any manual configuration.

## Lab

StatefulSets are complex and less common than Deployments, but they have one significant advantage: the ability to dynamically provision a PVC for each Pod using volumeClaimTemplates. Deployments can use ephemeral volumes for similar functionality, but StatefulSets make it more straightforward.

For this lab challenge, you'll work with a Deployment that runs an Nginx proxy over the StatefulSet website we have running. The deployment spec uses an emptyDir volume for cache files at /var/cache/nginx. EmptyDir volumes are temporary; they're lost when a Pod is deleted.

Deploy the proxy and test that it works by accessing the application through the proxy's LoadBalancer or NodePort Service. You should see the proxied content from the StatefulSet web application.

Your task is to replace this Deployment with a StatefulSet that uses persistent storage via volumeClaimTemplates for the cache. Each Pod should have its own PVC so cache data persists across Pod restarts. The proxy doesn't need Pods to be managed consecutively since they don't depend on each other, so your spec should set podManagementPolicy to Parallel for faster startup.

Think about what needs to change. You'll need to create a headless Service since StatefulSets require one. You'll need to change the kind from Deployment to StatefulSet and add the serviceName field. You'll need to replace the volumes section with volumeClaimTemplates. And you'll want to set podManagementPolicy to Parallel so all Pods start simultaneously rather than waiting for each other.

## **EXTRA** Testing the replicated database

For those interested in exploring further, the lab includes extra material on deploying a SQL client in the cluster to interact with the database. This demonstrates a common production pattern where databases aren't publicly exposed, but you can deploy client Pods within the cluster for administration and testing.

The approach involves deploying a Pod with a PostgreSQL client, connecting to specific database Pods using their stable DNS names, and running queries to verify replication is working correctly. You can connect to the primary to run write queries and connect to the replica to run read queries, confirming that data written to the primary appears on the replica.

This pattern is useful in production for database maintenance, running migrations, or troubleshooting issues without exposing the database to external networks. The detailed walkthrough is available in the statefulsets-sql-client.md file if you want to explore this further.

## Cleanup

When you're finished with the lab, let's clean up the resources. Remove all Deployments, StatefulSets, Services, ConfigMaps, Secrets, and Pods with the kubernetes.courselabs.co label set to statefulsets.

Now check the PVCs and you'll notice something important: they're still there. This is a safety mechanism built into StatefulSets. PVCs are not automatically deleted when you delete a StatefulSet or scale it down. This design prevents accidental data loss.

To completely clean up, you need to explicitly delete the PVCs. You can delete them by label to remove all PVCs associated with the StatefulSet. This manual deletion requirement is intentional. In production, you'd need explicit policies for PVC cleanup when StatefulSets are removed to ensure data isn't lost unintentionally.

That wraps up our hands-on exploration of StatefulSets. We've seen how StatefulSets create Pods sequentially with stable names, how each Pod gets its own DNS entry for direct access, how volumeClaimTemplates automatically provision persistent storage for each Pod, how primary-secondary patterns work with stable network identities, and why PVCs persist even after StatefulSet deletion. These are powerful features for stateful applications but come with added complexity compared to Deployments. In the next video, we'll dive deeper into CKAD-specific scenarios including exam strategies, troubleshooting techniques, and advanced StatefulSet patterns like parallel Pod management and partition updates.
