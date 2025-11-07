# Advanced Troubleshooting for CKAD - Narration Script

**Duration:** 30-35 minutes
**Format:** Screen recording with live demonstration
**Note:** CKAD core topics plus enrichment material
**Prerequisite:** Completed troubleshooting and troubleshooting-2 labs

---

Welcome to the CKAD perspective on advanced troubleshooting. This session clarifies what's essential for the CKAD exam versus what's valuable enrichment material. The key point is that while this lab covers advanced topics like Helm charts, the core CKAD exam focuses on basic Ingress and StatefulSet concepts using standard kubectl commands and YAML files.

Let me be direct about what matters for CKAD. The exam tests you on basic Ingress resources and how to create them, basic StatefulSet concepts and when to use them, and standard troubleshooting commands for all resources. You don't need to know Helm chart internals, advanced Ingress controller configuration, or complex StatefulSet update strategies. If you're studying specifically for CKAD certification, prioritize the core troubleshooting and troubleshooting-2 labs first, then return to this material afterward.

## Important Note

Understanding what's in scope versus out of scope saves you study time. For CKAD core topics, focus on what Ingress resources are and why you use them, how to create basic Ingress resources for HTTP routing, how Ingress routes traffic to Services, and basic troubleshooting when Ingress doesn't work. You don't need to understand Ingress controller internals, complex path rewriting rules, or advanced TLS certificate management.

For StatefulSets, know the difference between Deployments and StatefulSets, when to use StatefulSets for stateful applications like databases, how pod naming works with predictable names like pod-0 and pod-1, and basic volumeClaimTemplates for persistent storage. You probably don't need advanced update strategies, complex partition-based rollouts, or detailed understanding of PV reclaim policies.

The exam environment typically has an Ingress controller pre-installed, so you won't install one. You might need to create PVs manually if dynamic provisioning isn't configured. The focus is on using these resources correctly, not on the infrastructure that supports them.

## CKAD-Relevant Ingress Basics

Let me show you what the CKAD exam actually tests for Ingress. You need to know that Ingress provides HTTP and HTTPS routing to services based on hostnames and paths, acts as a layer seven load balancer unlike Services which are layer four, requires an Ingress controller to implement the routing rules, and routes traffic to Services which then route to Pods.

Creating a basic Ingress for the exam is straightforward. You specify the API version as networking.k8s.io/v1, the kind as Ingress, give it metadata including a name, and define the spec with rules. Each rule has a host for hostname-based routing and HTTP paths that specify which service receives traffic for that path. The backend service name must match an existing service exactly, and the port must match what the service exposes.

When troubleshooting Ingress on the exam, start by checking if the Ingress resource exists and its configuration. Use kubectl get ingress to see if it's created. Use kubectl describe ingress to see the detailed configuration and any events. Check if the backend service exists by listing services. Check if the service has endpoints, because even if everything else is configured correctly, if the service has no endpoints, traffic won't reach any pods.

Common Ingress issues on the exam include the backend service not existing or having the wrong name, the service having no endpoints because selectors don't match pod labels, wrong port numbers where the Ingress routes to a port the service doesn't expose, and in some cases the Ingress controller not being installed, though this is usually pre-configured in exam environments.

Let me demonstrate a typical exam scenario. I need to create an Ingress that routes traffic from app.example.com to a service called frontend on port 80. First, I verify the frontend service exists and has endpoints. Then I create the Ingress resource with the appropriate host rule and backend configuration. After creating it, I verify it was created successfully and check that it shows the correct backend in its describe output.

## CKAD-Relevant StatefulSet Basics

For StatefulSets, understand the fundamental differences from Deployments. Deployments are for stateless applications where any pod is interchangeable. StatefulSets are for stateful applications where each pod has a unique identity. StatefulSet pods get predictable names starting from zero, like postgres-0, postgres-1, postgres-2. They start in order and stop in reverse order. Each pod can have its own persistent storage through volumeClaimTemplates.

Creating a basic StatefulSet for the exam involves specifying the StatefulSet kind, giving it a name and replica count, defining the pod template including the container specs, and optionally defining volumeClaimTemplates for persistent storage. The serviceName field is required and references a headless service, which is a service with clusterIP set to None.

Let me show you a typical exam scenario for StatefulSets. I need to create a StatefulSet for a database with three replicas, each with one gigabyte of persistent storage mounted at /data. First, I create the StatefulSet with the volumeClaimTemplates specifying the storage requirements. Kubernetes automatically creates a PVC for each pod. Then I verify the StatefulSet was created and check that pods are starting in order. I check the PVC status to ensure they're binding to available PVs.

When troubleshooting StatefulSets on the exam, the most common issue is pods stuck in Pending state because PVCs can't bind. Check the PVC status first. If they're pending, no PVs match their requirements. Either create matching PVs or adjust the PVC requirements. Remember that PVs are cluster-scoped while PVCs are namespace-scoped, so create PVs without namespace specification.

Another common issue is the headless service being missing or misconfigured. StatefulSets require a headless service to provide stable network identities. If the service specified in serviceName doesn't exist or isn't headless, the StatefulSet won't work correctly. Create the service with clusterIP set to None and ensure the name matches what the StatefulSet references.

## Multi-Resource Debugging

The most valuable skill from this advanced lab is systematic multi-resource debugging, which absolutely applies to CKAD. When you have an application with multiple interconnected resources, follow a methodical approach.

Start by checking if all expected resources exist. List pods, services, ingresses, statefulsets, pvcs, and configmaps to see what's actually deployed. For resources that exist, verify their status. Are pods running? Are PVCs bound? Do services have endpoints? For resources with problems, use describe to see events and detailed status.

Follow the dependency chain. If a pod won't start, check if it needs ConfigMaps or Secrets and whether they exist. If a service has no endpoints, check if pod labels match the service selector. If an Ingress doesn't route traffic, verify the backend service exists and has endpoints. Each check narrows down where the problem is.

Let me walk through a complete exam-style scenario. I have a StatefulSet database that won't start, a Deployment application that's crash-looping, a Service with no endpoints, and an Ingress that returns 404. This looks overwhelming, but systematic debugging makes it manageable.

First, I check the StatefulSet. The pods are pending because PVCs aren't bound. I check the PVCs and see they're requesting storage that doesn't match any available PVs. I create appropriate PVs. The PVCs bind and the StatefulSet pods start running.

Second, I check the application Deployment. Pods are crash-looping. I check logs and see they're trying to connect to the database but can't resolve the hostname. I check if the database service exists - it does, but the application is using the wrong hostname. I fix the application configuration, and the pods start successfully.

Third, I check why the service has no endpoints. I compare the service selector to the pod labels and find a mismatch. I fix the service selector, and endpoints appear immediately.

Fourth, I check the Ingress. It exists and references the service, but the service name doesn't match exactly - there's a typo. I fix the Ingress backend service name, and traffic starts routing correctly.

This systematic approach - checking each resource, understanding its dependencies, fixing issues one at a time, and verifying each fix - works for any complexity level on the CKAD exam.

## What to Skip for CKAD

Let me be explicit about what you can safely skip if you're focused purely on passing CKAD. For Helm, skip chart creation and Go template syntax. Skip helm template debugging commands. Skip helm-specific troubleshooting. Focus instead on kubectl and YAML. The CKAD exam doesn't use Helm - everything is done with standard Kubernetes manifests.

For advanced Ingress, skip complex path rewriting and regular expressions in paths. Skip Ingress controller installation and configuration. Skip advanced TLS setup including certificate management. Focus on basic HTTP routing to services, which is what the exam tests.

For advanced StatefulSet topics, skip update strategies like OnDelete and partition-based rolling updates. Skip persistent volume reclaim policies and their implications. Skip advanced storage class configuration. Focus on basic StatefulSet creation, understanding pod naming and ordering, and ensuring PVCs bind correctly.

Your study time is limited. Spend it on topics that actually appear on the exam. Master pod troubleshooting, service debugging, ConfigMap and Secret issues, basic Ingress creation, and basic StatefulSet usage. These core skills will handle the vast majority of exam questions.

## Core CKAD Troubleshooting Review

Let me review the priority topics that truly matter for CKAD success. Priority one is mastering the essential commands. Know kubectl get, describe, logs, exec, and events cold. Practice until you can type them without thinking. Set up aliases if that helps you. These commands are the foundation of all troubleshooting.

Priority two is understanding the common failure scenarios. ImagePullBackOff means fix the image name or add registry credentials. CrashLoopBackOff means check logs with the previous flag to see why the container crashed. Pending means check resource constraints or PVC binding. CreateContainerConfigError means check ConfigMap or Secret configuration. Service with no endpoints means fix the selector. These patterns repeat constantly.

Priority three is practicing rapid diagnosis. Simple issues like wrong image names should take two to three minutes. Multi-resource problems should take five to seven minutes. Complex scenarios should take eight to ten minutes maximum. Time yourself during practice. Build speed through repetition until the diagnostic workflow is automatic.

Always verify your fixes before moving on. Don't just check that pods are running - verify they're ready, have no recent restarts, services have endpoints, and applications actually respond. The exam doesn't give partial credit. Your solution must completely work.

## Final CKAD Guidance

Here's your study path for maximum CKAD effectiveness. First, master basic troubleshooting from the troubleshooting lab - pod failures, service issues, basic debugging commands. Second, master multi-resource troubleshooting from the troubleshooting-2 lab - ConfigMaps, Secrets, PVCs, namespaces. Third, learn basic Ingress and StatefulSet troubleshooting from the relevant parts of this lab. Fourth and only after passing CKAD, explore Helm and advanced patterns for real-world application.

For exam focus, do memorize kubectl troubleshooting commands until they're muscle memory. Do practice fixing broken YAML until you can spot common errors immediately. Do master the describe and logs commands since they reveal most problems. Do understand resource dependencies and how they affect troubleshooting. Do time yourself on practice scenarios to build speed.

Don't worry about Helm chart syntax and template debugging. Don't worry about Ingress controller internals and configuration. Don't worry about advanced StatefulSet patterns beyond basic creation and storage. Don't waste time on topics explicitly marked as beyond CKAD. Focus your energy where it counts.

The success formula is simple. Focus on core topics, and you'll pass CKAD. Add advanced topics afterward, and you'll excel in real-world work. Practice both, and you'll achieve Kubernetes mastery. But for exam preparation, discipline yourself to master the fundamentals before exploring advanced material. The core troubleshooting skills from the first two labs are infinitely more valuable for CKAD than Helm expertise.

## Summary

This lab covered advanced troubleshooting topics, but the most important takeaway for CKAD is the systematic approach. Whether you're debugging a simple pod or a complex Helm deployment, the process is the same - check if resources exist, verify their status, understand their dependencies, fix issues methodically, and verify each fix worked.

For CKAD specifically, focus on basic Ingress creation and troubleshooting, basic StatefulSet concepts and PVC binding, systematic multi-resource debugging, and the core troubleshooting commands you've practiced throughout all three troubleshooting labs. Master these fundamentals, practice until the workflow is automatic, time yourself to build speed, and you'll be thoroughly prepared for the troubleshooting aspects of the CKAD exam.

Remember that troubleshooting appears across all CKAD domains. It's not a separate section - it's a skill you'll use in almost every question. When you create a deployment and it doesn't work, you troubleshoot. When you configure a service and can't access it, you troubleshoot. When you set up storage and pods won't start, you troubleshoot. Master these troubleshooting skills and you master the CKAD exam.
