# Services - CKAD Narration Script

**Duration:** 25-30 minutes
**Format:** Screen recording with live demonstration
**Prerequisite:** Completed basic Services exercises

---

Welcome to the CKAD exam preparation module for Kubernetes Services. This session covers the advanced Service topics you'll encounter on the exam, building on what we learned in the exercises lab.

The CKAD exam expects you to understand and work with Service types and use cases, Endpoints and EndpointSlices, multi-port Services, headless Services, Services without selectors, ExternalName Services, session affinity, DNS and service discovery, and Service troubleshooting. These topics separate basic understanding from exam-ready competence, so let's dive deep into each one.

## Understanding Endpoints

When a Service is created with a selector, Kubernetes automatically creates an Endpoints object. This object tracks which Pod IP addresses match the Service selector. Let me show you by checking the endpoints for the whoami service we deployed earlier.

The Endpoints object lists all the IP addresses of Pods that match the Service selector. This is how the Service knows where to route traffic. When you see a Service that isn't working, the first thing to check is whether it has endpoints. No endpoints means no Pods are being found by the label selector.

Let me demonstrate how this works dynamically. I'll delete the whoami Pod and watch what happens to the endpoints. See how the endpoints disappeared immediately? Kubernetes saw the Pod was deleted and updated the Endpoints object automatically. Now when I recreate the Pod, watch the endpoints come back with the new Pod IP. This automatic management is what makes Services so powerful.

## Endpoints vs EndpointSlices

EndpointSlices are a newer API that scales better for Services with many endpoints. Let me show you the difference by looking at both. The traditional Endpoints API stores all Pod IPs for a Service in a single object. If you have a Service with a thousand Pods, that's a thousand IPs in one object, and every update to any endpoint requires updating this large object.

EndpointSlices split large endpoint lists into multiple objects, improving performance in large clusters. Each EndpointSlice contains up to one hundred endpoints by default. This dramatically reduces the size of individual objects and the load on the API server.

The key differences are important to understand. Endpoints can handle about a thousand endpoints before performance degrades, and updates require replacing the entire object. EndpointSlices create multiple slices with one hundred endpoints each, and updates only affect the changed slices. EndpointSlices also support network topology awareness and full dual-stack IPv4 and IPv6 support.

For CKAD, you should be familiar with both, but you'll primarily interact with Endpoints objects since they're simpler and sufficient for most exam scenarios.

## Multi-Port Services

Services can expose multiple ports for applications that listen on different ports. For example, an application might serve HTTP on port 8080 and expose metrics on port 9090. Let me deploy a multi-port Service to demonstrate.

Looking at this Service spec, you can see it has multiple port definitions. Each port must have a unique name within the Service. Port names must be lowercase alphanumeric or dash, with a maximum of fifteen characters. Notice how different Service ports can target the same container port if needed. Clients can reference ports by name in some contexts like SRV records.

Let me test connectivity to the different ports from the sleep Pod. As you can see, each Service port works correctly, routing to the appropriate container port.

## Named Ports in Pods

You can name ports in Pod specs and reference them in Services. This is especially useful when port numbers change between versions. Let me show you a Deployment with named ports. Notice how the containerPort has a name field set to http-web.

Now in the Service spec, instead of using a numeric targetPort, we reference the port name http-web. This provides version flexibility because you can change container port numbers without updating Services. It's also clearer and more self-documenting. Named ports work great when you have multiple versions of an application that might use different port numbers but the same name.

For the CKAD exam, using numeric ports is usually faster unless the scenario specifically requires named ports. But understanding this capability is important for real-world scenarios.

## Headless Services

A headless Service has no ClusterIP. You set clusterIP to None in the spec. Instead of load balancing, DNS returns all Pod IP addresses directly. Let me create a headless service and demonstrate.

Notice the get service output shows None for the ClusterIP. Now when I do a DNS lookup, instead of getting a single Service IP, I get multiple A records, one for each Pod. This is completely different from a regular Service, which returns just one ClusterIP.

Headless Services are used with StatefulSets for stable network identities, for client-side load balancing, and for service discovery without load balancing. Each Pod gets its own DNS A record, allowing applications to choose which Pod to connect to. This is particularly useful for databases and other stateful applications that need to know about all replicas.

## Services Without Selectors

Services don't always target Pods. You can create a Service without a selector to route to external services like databases or APIs outside the cluster, to manually manage endpoints, or to migrate services gradually. When you create a Service without a selector, Kubernetes doesn't create Endpoints automatically. You must create them manually.

Let me deploy a Service without a selector. Notice there's no selector field in the spec. When I check for endpoints, none exist yet because Kubernetes doesn't know where to route traffic.

Now I'll create a manual Endpoints object. The Endpoints object must have the same name as the Service, and I manually specify the IP address and port. After applying this, the Service now has endpoints pointing to the external IP address.

This pattern is useful for external databases, migration scenarios where you gradually move an external service into the cluster, multi-cluster routing, and accessing legacy systems. Applications can use the Service DNS name, and it routes to wherever you've pointed the endpoints.

## ExternalName Services

ExternalName Services provide a DNS CNAME alias to an external service. They don't proxy traffic; they just return a DNS record. Let me deploy an ExternalName service and demonstrate.

The Service type is ExternalName, and the externalName field specifies the external DNS name. When I do a DNS lookup for this Service, DNS returns a CNAME record pointing to the external name. No traffic routing happens in Kubernetes. The client resolves the CNAME and connects directly to the external service.

This is useful for referencing cloud services like AWS RDS or Azure SQL via internal DNS names, for creating a migration path where you can later change the ExternalName to a regular ClusterIP Service, for handling environment differences where dev and prod use different external services, and for abstracting external service details from application code.

The beauty is that application code always uses the internal Service name, so when you migrate that external service into Kubernetes, you just change the Service type without changing any application configuration.

## Session Affinity

By default, Services load balance requests randomly across Pods. Session affinity ensures requests from the same client go to the same Pod. Let me create a service with session affinity configured.

The key setting is sessionAffinity set to ClientIP. The sessionAffinityConfig allows you to set a timeout in seconds. The default is three hours, but here I've set it to one hour.

Let me test this by making multiple requests to the Service. You should see the same hostname in all responses because session affinity routes all requests from the same source to the same backend Pod. Compare this to a Service without session affinity, where responses will likely show different hostnames as traffic is distributed across different Pods.

Session affinity works based on the client's source IP address. Kubernetes hashes the client IP to select a Pod consistently. The session expires after the configured timeout, and this works at the network level so no application changes are needed.

This is useful for web applications storing session data in memory, for WebSockets and other long-lived connections, for shopping carts maintaining state without distributed cache, and for file uploads that need to go to the same server. However, it only supports ClientIP affinity, doesn't survive Pod restarts, and is less effective with NAT or proxies. For true session persistence, use an external session store like Redis.

## DNS and Service Discovery

Services are accessible via DNS in multiple formats. Within the same namespace, you can use just the service name. For cross-namespace access, you need to use the format service-name dot namespace. The fully qualified domain name is service-name dot namespace dot svc dot cluster dot local.

Let me demonstrate by creating a Service in a different namespace. When I try to access it using just the short name from a Pod in another namespace, it fails. The Service is in a different namespace, so I need to include the namespace in the DNS name. Using the service dot namespace format works from any namespace.

For the CKAD exam, use the shortest form that works. Within the same namespace, use the service name only. For cross-namespace access, use service dot namespace. You rarely need the fully qualified domain name, but it's good to know it exists.

Services also create SRV records for port discovery. SRV records include port numbers and protocol information. The format is underscore port-name dot underscore protocol dot service-name dot namespace dot svc dot cluster dot local. This returns the priority, weight, port number, and target hostname. Service discovery tools can query SRV records to discover which ports a service offers without hardcoding port numbers.

## Service Troubleshooting

Service troubleshooting is a critical CKAD skill. Let's work through common issues and debugging workflows.

The most common issue is a Service with no endpoints. This happens when no Pods match the label selector, when Pods are not ready due to failing readiness probes, or when there's a label mismatch between the Service selector and Pod labels. Let me create a broken Service to demonstrate.

When I check the endpoints, none exist. The selector doesn't match any Pods. To debug this, first check what selector the Service is using, then check what labels your Pods actually have. The fix is either to change the Service selector or add the correct labels to the Pods.

Another common issue is port mismatch. The Service might be forwarding to the wrong targetPort. When testing connectivity fails with timeouts, check the Service targetPort and verify it matches the containerPort in the Pod spec.

Pods not being ready is another frequent problem. Services only route to Pods that are in the Ready state. If Pods are failing readiness probes, they won't receive traffic. Check the Pod status and look at the Conditions section and Events to understand why the Pod isn't ready.

DNS resolution failures require checking whether DNS itself is working by testing a known Service like kubernetes dot default. If that fails, the problem is with DNS, not your specific Service. Check that the kube-dns or CoreDNS Pods are running.

The comprehensive troubleshooting workflow starts by verifying the Service exists and has the correct type, checking if the Service has endpoints, finding Pods with matching labels if there are no endpoints, verifying Pod status and readiness, checking Service and Pod port configuration, testing DNS resolution, testing direct connectivity to a Pod, and finally testing Service connectivity.

Using kubectl port-forward for testing is another useful technique. Port-forward creates a tunnel from your local machine to a Pod or Service. You can forward to a Pod, to a Service which picks a random Pod, or to a Deployment which also picks a random Pod. This is useful for testing from your local machine, for debugging specific Pods by bypassing Service load balancing, for temporary database access, and for accessing admin dashboards. However, it requires an active kubectl connection, only works for a single user, breaks when Pods restart, and isn't suitable for production traffic.

## Service Network Policies

Services work with Network Policies to control traffic flow. Network Policies control which Pods can connect to Services using label selectors for both source and destination. By default, all traffic is allowed unless a NetworkPolicy exists.

Let me deploy a Service with a NetworkPolicy restricting access. The NetworkPolicy selects target Pods with a specific label and has ingress rules that allow traffic only from Pods with another label. The Service routes traffic to Pods, but the NetworkPolicy filters connections at the network level.

When I test from a Pod without the required label, the connection is blocked. But when I create a Pod with the correct label and test again, the connection succeeds. NetworkPolicies work at the Pod level, not the Service level, but both source and destination labels are important for controlling traffic flow.

## CKAD Exam Tips

For the exam, you can create Services imperatively with kubectl for speed. Use kubectl expose to create a ClusterIP service, specify the type for NodePort or LoadBalancer, and expose Deployments which is a common pattern.

Quick verification during the exam involves getting service details, checking endpoints, testing connectivity with a test Pod, and checking DNS resolution.

Let me walk through some common exam scenarios. For creating and exposing a Deployment, you create the deployment with replicas, then expose it with a Service specifying the ports. For creating a NodePort Service, you expose the deployment with the NodePort type, then either patch to set a specific NodePort or create with YAML.

For debugging a Service with no endpoints, check the service and endpoints, identify what selector the service is looking for, find Pods and their labels, compare labels to identify the mismatch, and either fix the Service selector or fix the Pod labels.

For creating a headless Service, you set clusterIP to None in the spec. This is commonly used with StatefulSets and returns all Pod IPs via DNS.

For configuring session affinity, you patch the Service to set sessionAffinity to ClientIP with a timeout configuration.

For creating a multi-port Service, you define multiple named ports in the Service spec, each with its own port and targetPort.

For creating an ExternalName Service, you set the type to ExternalName and specify the external DNS name.

For fixing DNS resolution between namespaces, the issue is usually using a short name across namespaces. Use the namespace-qualified DNS name instead.

Key exam strategies include using imperative commands when possible for speed, knowing how to write multi-port Service YAML quickly, memorizing the troubleshooting workflow, practicing cross-namespace scenarios, understanding when to use each Service type, and being able to quickly verify Service configuration.

## Lab Challenge

The lab challenge asks you to build a complete microservices application demonstrating all Service types. This integrates all the concepts we've covered. You'll deploy a three-tier application with a frontend web tier using LoadBalancer and session affinity, a backend API tier with a multi-port service, a database tier with StatefulSet and headless service, external service integration, and network security with NetworkPolicy restricting database access.

The challenge walks you through deploying the frontend with session affinity, the backend with multiple ports, the database with both headless and ClusterIP services, configuring external services with ExternalName and manual endpoints, and applying network security to restrict which Pods can access the database.

You'll test the complete application by verifying frontend accessibility externally, backend service connectivity from the frontend, the backend metrics port, database connectivity from the backend which is allowed, database blocking from the frontend which should be blocked by NetworkPolicy, headless service DNS resolution, session affinity behavior, and external service DNS resolution.

This comprehensive challenge tests your understanding of all the Service concepts in a realistic application architecture.

## Cleanup

When you're finished, remove all CKAD practice resources using the label selector. This deletes all Pods, Services, Deployments, and StatefulSets with the kubernetes.courselabs.co equals services label. If you created test namespaces, delete those as well.

That completes our CKAD preparation for Kubernetes Services. You now have the knowledge and hands-on experience you need for Services on the CKAD exam. Practice these scenarios multiple times until they become muscle memory. Set yourself time-based challenges to build speed. Review the official Kubernetes documentation on Services since you can use the docs during the exam. Master these concepts, and you'll be well-prepared for this portion of the CKAD exam.
