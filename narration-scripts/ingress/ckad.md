# Ingress - CKAD Narration Script

**Duration:** 25-30 minutes
**Format:** Screen recording with live demonstration
**Prerequisite:** Completed basic Ingress exercises

---

Welcome to the CKAD exam preparation module for Kubernetes Ingress. This session covers the advanced Ingress topics you'll encounter on the exam, building on what we learned in the exercises lab.

The CKAD exam expects you to understand and work with Ingress resource structure and rules, path types including Prefix and Exact matching, host-based and path-based routing, multiple paths and backends in a single Ingress, IngressClass and controller selection, TLS and HTTPS configuration, default backends, annotations for controller-specific features, cross-namespace considerations, and troubleshooting Ingress issues. These topics separate basic understanding from exam-ready competence, so let's dive deep into each one.

## CKAD Ingress Requirements

Ingress is classified as supplementary content for CKAD, meaning it may appear on the exam but isn't guaranteed. However, when it does appear, it's often combined with other topics like Services, Deployments, and troubleshooting, making it a high-value skill to master. In the CKAD exam, you'll work under time pressure with limited access to external resources, but the good news is that kubernetes.io documentation is available, including Ingress examples and API references.

We'll cover exactly what you need to know for the exam in this session. You need to understand how Ingress resources define routing rules, how path types determine which requests match your rules, how to route traffic based on hostnames and URL paths, how to work with multiple backends in a single Ingress, how to select the right IngressClass when multiple controllers exist, how to configure TLS certificates for HTTPS, how default backends provide fallback behavior, how annotations enable controller-specific features, how to handle services across multiple namespaces, and how to systematically troubleshoot broken Ingress configurations.

## API Specs

Before we dive into the practical work, let's review the API resources you'll work with. The Ingress resource is part of the networking.k8s.io/v1 API group and defines routing rules for HTTP and HTTPS traffic. The IngressClass resource, also in networking.k8s.io/v1, allows multiple Ingress controllers to coexist in the same cluster by identifying which controller should handle which Ingress resources. You should be comfortable looking up both of these in the Kubernetes documentation during the exam.

## Ingress Architecture Review

Let's quickly review the architecture from the basic lab to make sure we're on the same page. The Ingress Controller is a reverse proxy, typically Nginx, Traefik, or Contour, that runs as Pods in your cluster and watches for Ingress resources. Ingress Resources are Kubernetes objects that define routing rules, telling the controller how to route traffic to your services. Services are the backends that Ingress routes to, and they must be ClusterIP or NodePort type. The controller watches for Ingress resources and automatically reconfigures itself when rules change.

## Path Types

Path types are critical for the CKAD exam because they determine exactly which requests match your Ingress rules. There are three path types, but you'll primarily use two. Understanding how path matching works will help you solve routing problems quickly during the exam.

### Prefix Path Type

Prefix is the most common path type. It matches the beginning of the URL path, including everything after it. Think of it as starts-with matching. If your path is /app, it matches /app, /app/, /app/page, and /app/admin/dashboard. However, it does not match /application or /apps because those don't start with exactly /app followed by a separator. Let me deploy an example to demonstrate this behavior.

Notice how I used the kubectl create ingress command. This is much faster than writing YAML from scratch during the exam. The asterisk in the rule indicates Prefix matching. When I check the created Ingress, you can see the pathType is set to Prefix. This Ingress will match the base path and anything under it.

### Exact Path Type

Exact requires an exact match with no trailing content. If your path is /api/health, it matches only /api/health, not /api/health/ or /api/health/check. Use Exact when you need precise control over specific endpoints like health checks or metrics endpoints. Unfortunately, kubectl create ingress doesn't have a flag for Exact paths, so you need to write the YAML directly. In the exam, you might use kubectl create to generate a template, then edit it to change the pathType to Exact.

### ImplementationSpecific Path Type

There's also ImplementationSpecific, which depends on your Ingress Controller. The behavior varies between controllers, so you should avoid this in the exam unless specifically instructed. Stick with Prefix and Exact for predictable behavior.

### Understanding Path Matching

Let me create a practical example with overlapping paths to show you how priority works. When multiple paths could match the same request, understanding priority is essential. The rules are straightforward. Exact matches always win over Prefix matches. Among Prefix matches, longer paths take priority over shorter ones. Some controllers also consider the order of rules in your spec, so it's good practice to put more specific rules first.

Watch what happens when I create an Ingress with both /api and /api/v2 paths. A request to /api/users goes to the /api backend because it matches the /api Prefix. But /api/v2/users goes to the /api/v2 backend because /api/v2 is a longer, more specific match. Even though both paths match as Prefixes, the longer one takes priority. This is exactly the kind of question you might see on the CKAD exam. You're given an Ingress with overlapping rules and asked which service handles a specific request. Always remember that more specific matches win.

## Host-Based Routing

Route traffic based on the HTTP Host header. This is how you can host multiple applications on the same cluster, each with its own domain name, all routing through the same Ingress controller.

### Single Host

The simplest case is routing a single hostname to a service. When you specify a host in your Ingress rule, requests must include that exact hostname in the Host header, or the rule won't match. Let me deploy an example with a single host configured. The host field is app.example.com, and all requests to that hostname route to app-service on port 80.

### Multiple Hosts

You can configure multiple hosts in a single Ingress resource, each routing to different services. This is common when you have related applications that should be managed together. Let me show you an Ingress with three different hosts. Each host has its own rule section with its own paths and backends. When a request comes in, the Ingress controller looks at the Host header first to determine which rule section to use, then looks at the path to determine which backend to route to.

### Wildcard Hosts

Some controllers support wildcard domains like *.example.com, which matches any subdomain. This is useful for multi-tenant applications or development environments where you want to dynamically create subdomains. However, not all controllers support wildcards, so check your controller documentation. Specific hosts take precedence over wildcards, so if you have both app.example.com and *.example.com defined, requests to app.example.com use the specific rule.

For local testing without DNS, you can add entries to /etc/hosts. This maps hostnames to IP addresses locally, allowing you to test host-based routing without setting up actual DNS records. This is particularly useful during exam preparation.

## Path-Based Routing

Route to different backends based on URL path. This is how you typically structure a three-tier application, with the frontend at the root path, the API under /api, and the admin interface under /admin, all behind a single hostname.

Let me deploy a multi-path Ingress to demonstrate. The Ingress has three path rules under a single host. The /api path routes to api-service on port 8080, the /web path routes to web-service on port 80, and the /admin path routes to admin-service on port 3000. Notice the order. I put the most specific paths first, then the broader catch-all paths. While Kubernetes should handle priority correctly, this is good practice and matches how you'd configure most web servers.

### Path Priority and Ordering

Understanding path priority prevents routing bugs. When multiple paths could match, Kubernetes uses a clear priority system. Exact matches take priority over Prefix matches. Among Prefix matches, longer paths take priority over shorter ones. The order in the spec may matter depending on your controller implementation, so always list more specific paths before more general ones.

Let me demonstrate with overlapping paths. If I have /api/v2 and /api both defined as Prefix paths, a request to /api/v2/users matches both. However, Kubernetes routes it to the /api/v2 backend because that's the longer, more specific match. This priority system ensures that you can have both general and specific rules without conflicts.

## Combining Host and Path Routing

Complex routing scenarios combine both host and path rules. This is a typical CKAD exam question where you need to create an Ingress that routes different hosts and different paths to different services. Let me build a realistic example showing a three-tier application with multiple hostnames.

The Ingress has multiple host sections. Under api.example.com, we have /v1 routing to api-v1 and /v2 routing to api-v2. Under admin.example.com, the root path routes to admin-portal. This pattern is extremely common in real-world applications and frequently appears in CKAD exam questions. You might be asked to expose multiple services through a single Ingress or to combine host and path-based routing.

When testing, remember to include the Host header in your curl commands. The Host header determines which rule section matches, then the path determines which backend within that section receives the traffic.

## IngressClass

IngressClass is important when you have multiple Ingress Controllers in a cluster. For example, you might have both Nginx and Traefik running, and you need to tell Kubernetes which controller should handle which Ingress resources. The IngressClass object provides this separation.

Let me check what IngressClasses exist in our cluster. You'll typically see at least one IngressClass, and one might be marked as default with an annotation. Ingress resources without an ingressClassName specified automatically use the default class. This is convenient but can be confusing if you're not aware which controller is handling your Ingress.

When creating an Ingress, you can explicitly specify which IngressClass to use with the ingressClassName field in the spec. In the exam, if you're asked to create an Ingress for a specific controller, make sure to include the ingressClassName field. However, if there's only one controller or one is marked as default, you can omit this field and it will work correctly. Always check what's in the cluster with kubectl get ingressclass before making assumptions.

## TLS/HTTPS Configuration

HTTPS support is a common exam requirement. The process involves two steps. First, create a TLS secret containing your certificate and private key. Second, reference that secret in your Ingress resource. For the exam, you'll either be given pre-existing certificate files or asked to create self-signed certificates for testing.

### Creating a TLS Secret

Let me create a self-signed certificate for demonstration. The openssl command generates a private key and certificate in one step, valid for 365 days, covering myapp.example.com. Now I'll create the TLS secret using kubectl create secret tls. The secret type must be kubernetes.io/tls, which the kubectl create secret tls command handles automatically. The secret must contain two keys, tls.crt for the certificate and tls.key for the private key. If you're troubleshooting a broken TLS setup in the exam, verify these keys exist with kubectl describe.

### Creating an HTTPS Ingress

Now let's create an Ingress that uses this TLS certificate for HTTPS. The TLS section comes before the rules section in the spec. Each TLS entry specifies which hosts it covers and which secret contains the certificate. The hosts in the TLS section should match the hosts in your rules. I've also added an annotation for automatic HTTP to HTTPS redirection. This is Nginx-specific but very common in production. Most Ingress controllers have similar annotations for SSL redirect.

When I test the HTTP endpoint, the request returns a 308 Permanent Redirect to HTTPS. The HTTPS request works correctly. The -k flag tells curl to accept our self-signed certificate. In production, you'd use certificates from a trusted CA like Let's Encrypt.

### Multiple TLS Certificates

You can configure different certificates for different hosts. Each entry in the tls section can specify different hosts and different secrets. This is useful when you have multiple domains, each with its own certificate. Let me show you an example where app1.example.com uses app1-tls and app2.example.com uses app2-tls.

### Wildcard TLS Certificates

A wildcard certificate like *.example.com covers multiple subdomains with a single certificate. This simplifies certificate management when you have many subdomains. Just create one certificate, one secret, and list all the hosts it should cover in the tls section.

## Default Backend

Fallback service when no rules match. Most controllers have built-in default backends that return a 404 page, but you can customize this with your own service.

When you specify a defaultBackend in your Ingress spec, requests that don't match any rules route to that service. This includes requests to unknown hosts, requests to paths that don't match any defined paths, and requests that would otherwise return 404. Let me deploy an example with a custom default backend. The defaultBackend section specifies a service name and port, just like regular backend definitions.

Now when I make a request that doesn't match any rules, it routes to the default service instead of getting the controller's built-in 404 page. This is useful for providing custom error pages, handling legacy URLs with redirects, catching typos in URLs, or providing a branded experience for all unmatched requests.

## Annotations

Controller-specific features via annotations. Annotations enable advanced functionality that's not part of the core Ingress specification. Different controllers support different annotations, so always check your controller's documentation.

### Common Nginx Annotations

Let me show you the most common Nginx annotations you'll encounter. The rewrite-target annotation transforms request paths before sending them to the backend. The enable-cors annotation adds CORS headers to responses. The ssl-redirect annotation forces HTTPS. The limit-rps annotation provides rate limiting. The proxy-body-size annotation controls maximum upload size. These annotations go in the metadata.annotations section of your Ingress.

### Rewrite Target

Rewrite target is particularly important for the exam. It transforms request paths before sending them to the backend service. For example, if clients request /api/users but your backend expects just /users, you can use rewrite-target to strip the /api prefix. Let me deploy an example showing how this works. The path uses a regex with capture groups, and the rewrite-target references those groups with $1 and $2. Understanding this pattern is crucial for exam scenarios involving path transformation.

### HTTP to HTTPS Redirect

Most production applications require HTTPS. The ssl-redirect annotation automatically redirects HTTP requests to HTTPS. Combined with force-ssl-redirect, this ensures all traffic uses encryption. Let me add these annotations to an Ingress. Now when I make an HTTP request, I get a redirect to HTTPS instead of serving content over HTTP.

### Custom Timeouts

Some backends are slow to respond. Custom timeout annotations prevent premature connection failures. The proxy-connect-timeout controls connection establishment time. The proxy-send-timeout controls sending the request. The proxy-read-timeout controls reading the response. These are particularly useful for long-running API calls or file uploads.

For the CKAD exam, you don't need to memorize all annotations. The kubernetes.io documentation includes annotation references you can look up during the exam. However, knowing the common ones like rewrite-target and ssl-redirect will save you time.

## Cross-Namespace Considerations

An important limitation to understand is that Ingress resources can only reference Services in the same namespace. This is a fundamental architectural constraint that affects how you design multi-namespace applications.

### Ingress and Service Namespaces

When you create an Ingress in a namespace, it can only route to Services in that same namespace. If you try to reference a Service in a different namespace, the Ingress will create but won't work. There will be no endpoints, and requests will fail with 503 errors. Let me demonstrate this limitation by trying to create a cross-namespace reference. The Ingress creates successfully, but when I check endpoints, there are none because the Service is in a different namespace.

### Multi-Namespace Routing Pattern

If you need to route traffic to Services in different namespaces, you create separate Ingress resources in each namespace. Let me show you the correct pattern. I'll create an Ingress in the frontend namespace routing to frontend-service, and another Ingress in the api namespace routing to api-service. Both Ingresses can use the same hostname but with different paths. The frontend Ingress handles the root path, and the api Ingress handles /api. The Ingress Controller merges these rules and routes requests correctly based on the path.

This pattern is the standard approach for multi-namespace applications. Each namespace has its own Ingress, and the controller coordinates them. This provides namespace isolation while still allowing unified routing.

### ExternalName Service Workaround

For advanced scenarios, you can use ExternalName Services to work around the namespace limitation. Create an ExternalName Service in your namespace that points to a service in another namespace using the internal DNS name. Then reference that ExternalName Service in your Ingress. This is a more complex pattern and not commonly needed in CKAD scenarios, but it's good to know it exists.

## Troubleshooting Ingress

Troubleshooting is a critical CKAD skill. Let's work through common issues and debugging workflows. The exam frequently includes broken configurations that you need to fix quickly.

### Common Issues

The most common issue is an Ingress that creates successfully but doesn't work. When this happens, first check if the Ingress has an address assigned. If the Address field is empty, the controller might not be running or the IngressClass might be wrong. Next, check the Service exists in the same namespace. A common mistake is referencing a Service in a different namespace. Then check the Service has endpoints. No endpoints means no Pods are backing the Service.

404 errors usually indicate path or host matching problems. Verify the path in your request matches the path in your Ingress, and check the pathType is correct. Exact paths are very strict, while Prefix paths are more forgiving. Also verify the Host header matches the host in your Ingress rules.

502 Bad Gateway or 503 Service Unavailable errors mean the Ingress found the Service but can't connect to Pods. Check if Pods exist and are ready. Check if the Service selector matches the Pod labels. Check if the Service port matches the container port. Test the Service directly with kubectl port-forward to isolate whether the problem is with the Ingress or the Service.

TLS issues usually involve missing or incorrect secrets. Check the secret exists in the same namespace as the Ingress. Check the secret type is kubernetes.io/tls. Check the certificate is valid and matches the hostname. Use openssl commands to inspect the certificate contents.

### Troubleshooting Decision Tree

The systematic approach for the exam starts with checking if the Ingress exists and has an address assigned. If there's no address, the controller might not be running or the IngressClass might be wrong. Next, describe the Ingress and look for Events or warnings. Then verify the Service exists in the same namespace with kubectl get svc. Check the Service has endpoints with kubectl get endpoints. If there are no endpoints, check if Pods exist with the right labels. Finally, test the Service directly with kubectl port-forward to isolate Ingress-specific issues.

Let me walk through debugging a broken Ingress. First I describe the Ingress and look at the Events section at the bottom. I might see warnings about the Service not existing. Next I verify the Service name with kubectl get svc and check I'm in the correct namespace. I compare the Service name in the Ingress to the actual Service name. If they don't match, I fix the Ingress to reference the correct Service name. This systematic approach will help you quickly identify and fix Ingress issues under exam time pressure.

## Port References

You can reference Service ports by name or number in Ingress backends. Both approaches work, but they have different use cases.

Referencing by port number is the most straightforward. You specify the port number directly in the backend configuration. This is clear and unambiguous. However, if the port number changes, you need to update the Ingress.

Referencing by port name provides more flexibility. You define a name for each port in the Service, then reference that name in the Ingress. This means the port number can change without updating the Ingress, as long as the name stays the same. Named ports are particularly useful when you have multiple versions of an application that might use different port numbers but the same name.

For the CKAD exam, using numeric ports is usually faster unless the scenario specifically requires named ports. But understanding this capability is important for real-world scenarios where you need flexibility.

## CKAD Exam Tips

Let's talk about strategies and techniques for working efficiently with Ingress during the exam.

### Speed Commands

The kubectl create ingress command generates YAML quickly. The syntax is rule equals hostname/path asterisk equals service colon port. Let me show you some examples. For a simple ingress, the command is kubectl create ingress simple --rule="app.example.com/=app-svc:80". For multiple paths, you add multiple --rule flags. For TLS, you add tls=secret-name to the rule. Use --dry-run=client -o yaml to preview the generated YAML, then pipe it to a file or directly to kubectl apply. This saves minutes compared to writing YAML from scratch.

### Quick Verification

During the exam, you need to verify your work quickly. Use kubectl get ingress to check basic status. Use kubectl describe ingress to see detailed configuration and events. Test with curl using the -H flag to set the Host header. Check controller logs if nothing else works. These quick checks will help you catch mistakes before moving to the next question.

### Common Exam Patterns

The exam loves certain patterns that appear repeatedly. You might need to expose an existing Deployment, which means creating a Service first, then an Ingress. You might need to fix a broken Ingress by checking the definition, verifying the Service exists, and looking at events. You might need to add TLS to an existing Ingress by creating a TLS secret and editing the Ingress to add the tls section. Practice these patterns until they become muscle memory.

### Using Documentation Effectively

In the exam, you have access to kubernetes.io documentation. Know where to find Ingress examples quickly. Navigate to the API reference for Ingress, or search for Ingress on kubernetes.io. The documentation includes complete examples you can copy and modify. Pay attention to the version and make sure you're looking at documentation matching your cluster version. Use kubectl version to check your cluster version. Also remember how to find annotation documentation for your Ingress Controller. For Nginx, the annotations page lists every available feature with examples.

### Rapid-Fire CKAD Practice Scenarios

Let me walk through some rapid-fire scenarios that mimic exam questions. Create an Ingress for a deployment called store exposed on port 8080, accessible at store.example.com/shop. You have 2 minutes. The solution is to create the service first, then use kubectl create ingress with the appropriate rule.

Add HTTPS to an existing Ingress called webapp using a TLS secret called webapp-tls for the host webapp.example.com. You have 3 minutes. The solution is to edit the Ingress and add the tls section referencing the secret and host.

An Ingress called broken returns 404 errors. The Service exists. Find and fix the issue. You have 3 minutes. The solution is to describe the Ingress, check the path and pathType, compare to what the application actually serves, and fix the mismatch.

These rapid-fire scenarios train your muscle memory for common exam tasks. Practice creating Ingress resources until you can do it without thinking about the syntax.

## Lab Challenge: Complete Multi-Service Application

The lab challenge asks you to build a production-ready Ingress configuration with multiple advanced features. This integrates all the concepts we've covered. You'll deploy a complete three-tier application with sophisticated routing, TLS, authentication, and multi-environment support.

The requirements include a three-tier application with frontend, backend API, and admin portal, all with multiple replicas. Path-based routing to three services with a custom default backend. TLS configuration with HTTPS enabled and HTTP redirecting automatically. Advanced features using annotations including rate limiting on the API, basic authentication on the admin portal, response caching for static assets, and CORS enabled for API endpoints. Multi-environment setup with dev, staging, and prod namespaces, each with different hostnames. And troubleshooting tasks where you fix five intentionally broken Ingress configurations.

This comprehensive challenge tests your understanding of all the Ingress concepts in a realistic application architecture. Work through it methodically, testing each component as you build it. The challenge provides a complete solution you can reference if you get stuck, but try to solve it yourself first.

## Quick Reference Card

For quick reference during practice and the exam, here are the essential patterns. A basic Ingress has the networking.k8s.io/v1 API version, a rules section with host and paths, and backends referencing services. With TLS, you add a tls section with hosts and secretName before the rules. With IngressClass, you specify ingressClassName in the spec. Multiple paths go in the paths array under a single host. Common annotations go in metadata.annotations.

Keep these patterns handy during practice. They cover the vast majority of exam scenarios. Focus on being able to write them quickly from memory.

## Cleanup

When you're finished practicing, remove all resources with kubectl delete all,secret,ingress,ingressclass -l kubernetes.courselabs.co=ingress. If you created test namespaces, delete those with kubectl delete namespace dev staging prod.

That completes our CKAD preparation for Kubernetes Ingress. You now have the knowledge and hands-on experience required for Ingress on the CKAD exam. Practice these scenarios multiple times until they become muscle memory. Set yourself time-based challenges to build speed. Use the kubernetes.io documentation during practice since it's available during the exam. Master these concepts, and you'll be well-prepared for this portion of the CKAD exam.
