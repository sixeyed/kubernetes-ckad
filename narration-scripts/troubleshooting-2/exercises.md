# Troubleshooting Application Modeling - Exercises Narration Script

**Duration:** 20-25 minutes
**Format:** Screen recording with live demonstration
**Prerequisite:** Kubernetes cluster running, completed basic troubleshooting exercises

---

Welcome to application modeling troubleshooting. This builds on what we learned in the basic troubleshooting lab, but now we're dealing with more complex scenarios. In real Kubernetes deployments, applications don't exist in isolation. They depend on configuration from ConfigMaps, credentials from Secrets, persistent storage from PersistentVolumes, and they're organized into namespaces. When any of these dependencies are misconfigured, your application breaks in interesting ways.

Today we're working with a broken web application that requires all these components working together. It needs configuration from a ConfigMap, database credentials from a Secret, persistent storage via a PersistentVolume, and it's deployed to a custom namespace. Your goal is to fix all the configuration issues so the application is healthy and accessible at localhost:8040 or localhost:30040, displaying its configuration correctly.

This mirrors real CKAD exam scenarios where multiple resources must work together correctly. The exam loves questions like this because they test whether you really understand how Kubernetes resources interact. You can't just memorize commands - you need to think systematically about dependencies and troubleshoot methodically.

## Lab

Let me deploy the broken application. I'm applying all the specs from the troubleshooting-2 directory. Kubernetes accepts the YAML files, which means the syntax is valid, but that doesn't mean the application will actually work. This is the nature of declarative configuration - Kubernetes validates the structure but can't predict whether your configuration makes sense for your application.

When I try to access the application, nothing responds. Let's start investigating. First, I need to understand what resources were created and in which namespaces. When I list all resources, I can see some things in the default namespace and some in a custom namespace. This is our first clue - resources might be scattered across namespaces when they need to be together.

Let's check the troubleshooting-2 namespace specifically. I can see a deployment, but what's the status? Are the pods running? When I look at the pods, the status tells me immediately if we have a problem. Maybe it's Pending, maybe it's CreateContainerConfigError, maybe it's CrashLoopBackOff. Each status points to a different category of problem.

The describe command is critical here. When I describe the pod, look at the events section. You'll often see messages about missing ConfigMaps, missing Secrets, or PersistentVolumeClaims that won't bind. These events are Kubernetes telling you exactly what's wrong - you just need to read them carefully and understand what they mean.

Let's say I see an event about a ConfigMap not being found. The first question is - does the ConfigMap exist at all? I can list ConfigMaps in the namespace to check. If it doesn't exist, I need to create it. If it exists, the next question is - am I looking in the right namespace? ConfigMaps are namespace-scoped, which means a pod can only reference ConfigMaps in its own namespace. If the ConfigMap is in the default namespace but the pod is in troubleshooting-2, the pod can't see it.

The same logic applies to Secrets. When the pod complains about a missing Secret, I need to verify the Secret exists in the correct namespace. Creating a Secret is straightforward with kubectl create secret, but remember you need to create it in the same namespace where the pod is running.

PersistentVolumeClaims add another layer of complexity. When a pod wants to use persistent storage, it references a PVC, which then needs to bind to a PV. If the PVC is stuck in Pending state, that means no PV matches its requirements. I need to check what the PVC is requesting - how much storage, what access mode, which storage class - and then verify that a matching PV exists. If not, I'll need to create one.

Here's where namespace boundaries matter again. PVCs are namespace-scoped, so the PVC must be in the same namespace as the pod. But PVs are cluster-scoped, meaning they're not in any namespace. So I create the PV without a namespace specification, but the PVC must be in the pod's namespace.

Service configuration is another common issue. Even if the pod is healthy, you might not be able to access it if the service is misconfigured. The service needs the correct selector to match the pod labels, the right ports to route traffic correctly, and the appropriate type to expose it how you want. When I check the service endpoints, if it shows none, that's a selector mismatch. The service selector doesn't match the pod labels.

Port configuration requires careful attention. The service has a port, which is what clients connect to, and a targetPort, which is where traffic gets forwarded on the pod. The targetPort must match the containerPort in the pod spec. If these don't align, the service routes traffic to the wrong port and nothing works.

Let me work through a complete diagnosis systematically. First, I check which namespaces have resources. Then I focus on the namespace where my application should be running. I check if all required resources exist - deployment, service, ConfigMap, Secret, PVC. For resources that exist, I verify they're in the correct namespace. For resources that don't exist, I create them.

When the pod is still not running after ensuring resources exist, I describe the pod to check for different errors. Maybe the ConfigMap key names don't match what the pod expects. The ConfigMap might have a key called database-url, but the pod is looking for database_url with an underscore. Kubernetes is exact about these things - the names must match character for character.

Volume mount paths need to match what the application expects. If the application looks for configuration at /app/config but the volume is mounted at /config, it won't find the files. I need to check the application's expectations and make sure the volumeMount path matches.

After fixing each issue, I watch what happens. Kubernetes might need a moment to reconcile the changes. New pods might be created. PVCs might bind. Configuration might be loaded. I verify at each step that the fix actually worked before moving to the next issue.

When working with ConfigMaps, I can verify the configuration was loaded correctly by checking the environment variables inside the pod or looking at the mounted files. The exec command lets me run commands inside the container to inspect what the application actually sees.

The systematic approach is essential. I don't try to fix everything at once. I identify one issue, fix it, verify it's resolved, then move to the next issue. This prevents confusion and ensures I'm actually making progress.

Once the pod is running and ready, I need to verify the service configuration. Does the service have endpoints? If yes, the selector is correct. Can I port-forward to the service and access the application? If yes, the ports are configured correctly. Can I access it via the NodePort or LoadBalancer? If yes, the service type is appropriate.

The final verification is accessing the application through its intended endpoint and confirming it displays correctly. Not just that it responds, but that it shows the configuration from the ConfigMap, it can access its persistent storage, and everything is working as designed.

This type of troubleshooting requires understanding how Kubernetes resources relate to each other. Pods depend on ConfigMaps and Secrets for configuration. They depend on PVCs for storage, which depend on PVs. Services depend on pod labels to know where to route traffic. Everything must be in the right namespace with the right names and the right configurations. It's a web of dependencies, and troubleshooting means understanding that web.

## Cleanup

When you're finished investigating and fixing the application, we need to clean up properly. Since we used a custom namespace, deleting that namespace removes most of the resources. However, some resources might have been created in other namespaces during troubleshooting, so we specifically delete ConfigMaps with the troubleshooting-2 label across all namespaces to ensure complete cleanup.

That completes our application modeling troubleshooting exercise. You've practiced diagnosing and fixing multi-resource applications with ConfigMaps, Secrets, PersistentVolumes, and namespace issues. These skills are essential for the CKAD exam where you'll frequently need to work with complex applications that depend on multiple resources working correctly together. In the next video, we'll cover CKAD-specific scenarios with more advanced patterns and time-saving techniques.
