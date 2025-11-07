# Troubleshooting Application Modeling for CKAD - Narration Script

**Duration:** 35-40 minutes
**Format:** Screen recording with live demonstration
**Prerequisite:** Completed basic troubleshooting and troubleshooting-2 exercises

---

Welcome to the CKAD exam preparation for application modeling troubleshooting. This session focuses on the scenarios that combine multiple CKAD domains - configuration management with ConfigMaps and Secrets, storage with PersistentVolumes, and namespace management. These topics appear across several exam domains, accounting for a significant portion of your score.

Application modeling troubleshooting is critical for CKAD because it's not just about creating resources - it's about making sure they work together correctly. The exam will give you scenarios where ConfigMaps have wrong keys, Secrets are missing, volumes won't mount, or resources are in the wrong namespaces. You need to diagnose and fix these issues quickly and systematically.

## CKAD Exam Context

Let's understand what the exam expects. Application modeling troubleshooting spans multiple domains. In Application Design and Build, you're tested on ConfigMaps, Secrets, and multi-container pods. In Application Deployment, you deploy applications with proper configuration. In Application Environment, Configuration and Security, you manage the configuration resources themselves. All of these come together in troubleshooting scenarios.

The exam loves these questions because they test real understanding. Anyone can memorize how to create a ConfigMap, but can you diagnose why a pod can't find a ConfigMap key? Can you figure out why a PVC won't bind? Can you spot when resources are in different namespaces? This is where practical experience separates those who pass from those who don't.

Time management is essential. Simple ConfigMap or Secret issues should take one to two minutes. PVC problems might take two to three minutes. Full multi-resource scenarios can take five to seven minutes. Never spend more than ten minutes on a single question. The exam is about completing enough questions correctly, not perfecting every answer.

## Common Application Modeling Issues

Let's work through the most common failure patterns you'll encounter.

### ConfigMap Key Mismatch

This is perhaps the most common application modeling issue on the exam. Your pod goes into CreateContainerConfigError state. When you describe it, the events tell you that a specific key wasn't found in the ConfigMap. But the ConfigMap exists, so what's wrong? The key names don't match exactly.

Let me demonstrate. I'll create a ConfigMap with a key called database_url. Now I'll create a pod that references database-url with a hyphen instead of an underscore. The pod immediately goes into CreateContainerConfigError. When I describe the pod, the events clearly state which key it's looking for and which ConfigMap it checked.

The diagnostic process is straightforward. First, verify the ConfigMap exists in the pod's namespace. Second, check what keys actually exist in the ConfigMap. Third, compare those keys to what the pod is requesting. The mismatch will be obvious once you look.

The fix is either updating the ConfigMap to add the key the pod expects, or updating the pod to reference the key that actually exists. Either approach works, depending on whether the ConfigMap or the pod has the correct name. For the exam, choose whichever is faster to change.

### ConfigMap or Secret in Wrong Namespace

Namespace issues are incredibly common because ConfigMaps and Secrets are namespace-scoped. A pod can only reference ConfigMaps and Secrets in its own namespace. If your pod is in the production namespace but the ConfigMap is in default, the pod can't access it.

The symptoms are the same as a missing ConfigMap - CreateContainerConfigError. The difference is when you list ConfigMaps, you do see one with the right name, but it's in a different namespace than the pod. This is easy to miss if you don't check namespaces carefully.

Let me show you by creating a ConfigMap in the default namespace and a pod in a custom namespace that tries to use it. The pod fails to start. When I list ConfigMaps without specifying a namespace, I might not even see the problem. But when I list them with the all-namespaces flag, I can see the ConfigMap exists but in the wrong namespace.

The fix is moving the ConfigMap to the correct namespace. You can do this by getting the ConfigMap YAML, deleting it from the old namespace, and creating it in the new namespace. Or for simple ConfigMaps, just recreate it directly in the correct namespace with kubectl create configmap.

### Secret Not Found

Secrets work exactly like ConfigMaps from a troubleshooting perspective. Missing Secrets cause CreateContainerConfigError. Wrong key names cause CreateContainerConfigError. Wrong namespace causes CreateContainerConfigError. The diagnostic process is identical - verify the Secret exists, check the keys, confirm the namespace matches.

The difference with Secrets is creation. When you create a Secret, remember that values must be base64 encoded if you're writing the YAML directly. But kubectl create secret handles the encoding automatically, so it's usually easier and faster to use the imperative command.

For docker registry Secrets specifically, you need the docker-server, docker-username, docker-password, and docker-email fields. Then the pod references this Secret in its imagePullSecrets field. This is common on the exam for pulling images from private registries.

TLS Secrets are another special type, used with Ingress resources. They need a tls.crt and tls.key. The kubectl create secret tls command handles creating these from certificate and key files.

### Volume Mount Path Mismatch

Volume mount issues are more subtle. The pod might start successfully, but the application doesn't work because it can't find its configuration files. The volume is mounted, just not where the application expects.

Let me demonstrate by mounting a ConfigMap as a volume at /config, but the application looks for configuration at /app/config. The pod shows Running status, but when I check the application logs, it complains about missing configuration files. The fix is updating the volume mount path to match where the application actually looks.

You can verify mount paths by using kubectl exec to get a shell in the container and checking where files actually are. List the directories to see what's mounted where, then compare that to what the application expects.

## PersistentVolume Troubleshooting

PersistentVolumes add complexity because they involve two resources - the PVC that the pod requests and the PV that provides the storage. Both need to be configured correctly for binding to work.

### PVC Stuck in Pending

When a PVC stays in Pending state, it means no PersistentVolume matches its requirements. The PVC specifies how much storage it needs, what access mode it requires, and optionally which storage class to use. A PV must match or exceed all these requirements for binding to occur.

Let me create a PVC requesting 10 gigabytes with ReadWriteOnce access mode. If no PV has at least 10 gigabytes and supports ReadWriteOnce, the PVC stays pending. When I describe the PVC, it might show events about no volumes available or no volumes matching the requirements.

The fix is creating a PV that satisfies the PVC's requirements. The PV capacity must be at least what the PVC requests. The access modes must be compatible - if the PVC wants ReadWriteOnce, the PV must offer ReadWriteOnce. If a storage class is specified, they must match.

Storage classes matter on the exam. Many Kubernetes distributions have a default storage class that automatically provisions PVs. But in exam scenarios, you might need to create PVs manually. Check what storage classes are available, and if the PVC specifies one, make sure your PV matches.

Access modes are important to understand. ReadWriteOnce means one node can mount the volume for reading and writing. ReadOnlyMany means multiple nodes can mount it read-only. ReadWriteMany means multiple nodes can mount it for reading and writing. Not all storage types support all access modes.

### PVC Bound to Wrong PV

Sometimes a PVC binds but to the wrong PV. Maybe it requested 10 gigabytes but bound to a 1 gigabyte PV. This happens when the PV technically matches the requirements but isn't ideal. Once a PVC binds, it stays bound until you delete and recreate it.

To fix this, delete the PVC, which releases the PV, then recreate the PVC. Make sure the correct PV is available and configured to be the best match. You might need to adjust the PV's capacity, access modes, or storage class to ensure the PVC binds to it.

## Namespace Troubleshooting

Understanding namespace scope is critical for the exam. Resources fall into two categories - namespace-scoped and cluster-scoped.

Namespace-scoped resources include Pods, Deployments, Services, ConfigMaps, Secrets, PersistentVolumeClaims, ServiceAccounts, Roles, and RoleBindings. These exist within a namespace, and references between them must be within the same namespace.

Cluster-scoped resources include PersistentVolumes, Nodes, StorageClasses, ClusterRoles, ClusterRoleBindings, and Namespaces themselves. These aren't in any namespace and are visible cluster-wide.

The key rule is that namespace-scoped resources can only reference other resources in the same namespace, with rare exceptions. A pod in namespace-a cannot reference a ConfigMap in namespace-b. You must move one or the other to make them match.

Services have an interesting exception. You can access a service in another namespace by using its fully qualified domain name - servicename.namespace.svc.cluster.local. This is useful for cross-namespace communication but doesn't work for ConfigMaps or Secrets.

When troubleshooting namespace issues, always check which namespace each resource is in. Use the namespace flag explicitly when creating resources. Use the all-namespaces flag when listing resources to see everything. The default namespace is default, but exam questions often use custom namespaces to test whether you're paying attention.

## Multi-Resource Debugging

Complex applications involve many resources working together. Systematic debugging is essential.

Start by mapping the dependencies. What does the pod need? ConfigMaps for configuration, Secrets for credentials, PVCs for storage, Services for networking. List all these resources and verify each exists in the correct namespace.

Check each layer systematically. First, do the resources exist? Second, are they in the right namespace? Third, do the names match what's referenced? Fourth, do the keys or fields match? Fifth, do ports align? Each check narrows down the problem.

Follow the error trail. When a pod fails, the events tell you the immediate problem - maybe a missing ConfigMap. Fix that, and a new error might appear - maybe a missing Secret. Fix that, and another issue surfaces - maybe the PVC won't bind. Work through them one by one.

Let me walk through a complete scenario. I'm deploying an application with a Deployment, ConfigMap, Secret, PVC, and Service. The application won't start. First, I check if all resources exist. The ConfigMap is missing - I create it. Now the pod complains about a Secret - I create that. Now it complains about a PVC - that exists but is pending. I check for PVs and find none match. I create a PV. The PVC binds. The pod starts. But I still can't access it. I check the service endpoints - none. The service selector doesn't match the pod labels. I fix the selector. Now endpoints appear. I can access the application.

This systematic approach works for any complexity level. Don't try to see everything at once. Work layer by layer, verifying each fix before moving to the next issue.

## Quick Troubleshooting Commands

For the exam, speed matters. Use efficient commands to diagnose quickly.

To check all resources in a namespace at once, use kubectl get all, configmap, secret, pvc with the namespace flag. This shows you in one command what exists.

To find resources in wrong namespaces, use the all-namespaces flag with grep or just scan the output for the names you're looking for.

To quickly create ConfigMaps and Secrets, use the imperative commands. Creating from literals is faster than writing YAML, especially for simple configurations.

To copy resources between namespaces, get the YAML of the resource, change the namespace field, and apply it. Or for simple resources, just recreate them in the target namespace.

For verification, check pods are running and ready, check PVCs are bound, check services have endpoints, and test that applications actually respond. Don't assume fixes worked - always verify.

## CKAD Exam Checklist

Before leaving any troubleshooting question, verify everything works.

All resources must exist in the correct namespace. Use kubectl get to confirm each resource is where it should be.

ConfigMaps and Secrets must have the correct keys. Get the YAML to verify the keys match what pods reference.

Key names must match exactly. Kubernetes is case-sensitive and exact about underscores versus hyphens.

PVCs must be bound, not pending. Check PVC status explicitly.

Pods must be running and ready, showing one out of one in the ready column.

Services must have endpoints. No endpoints means selector problems.

Applications must actually respond. Test with curl or port-forward to verify functionality.

This checklist prevents the common mistake of thinking you fixed something when you only partially fixed it. The exam doesn't give partial credit - the solution must completely work.

## Summary

Application modeling troubleshooting combines multiple CKAD domains and is critical for exam success. Master the essential commands for working with ConfigMaps, Secrets, PVCs, and namespaces. Understand the common failure patterns - CreateContainerConfigError usually means ConfigMap or Secret issues, Pending PVCs mean no matching PV, no service endpoints means selector problems.

Time management is crucial. Simple ConfigMap or Secret fixes should take one to two minutes. PVC issues might take two to three minutes. Full multi-resource scenarios should take five to seven minutes maximum.

Always work systematically. Check if resources exist, verify they're in the correct namespace, confirm names and keys match exactly, and test that fixes actually work. Don't skip steps or make assumptions.

Practice these scenarios repeatedly until the diagnostic process is automatic. Set yourself time limits and try to beat them. The more you practice, the faster you'll spot common patterns. Master application modeling troubleshooting and you'll handle a significant portion of the CKAD exam confidently and efficiently.
