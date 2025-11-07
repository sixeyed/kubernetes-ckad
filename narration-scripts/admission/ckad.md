# Admission - CKAD Narration Script

**Duration:** 20-25 minutes
**Format:** CKAD exam preparation focus

---

Welcome to admission control for CKAD exam preparation. While admission control is an advanced topic beyond the core CKAD curriculum, you'll encounter it in exam scenarios, mainly when troubleshooting deployments that policies block.

## CKAD Exam Context and What Are Admission Controllers

Let's understand what admission controllers are and why they matter for the CKAD exam. Admission controllers are plugins that intercept requests to the Kubernetes API server after authentication and authorization but before objects are persisted to etcd. The request flow goes from the client through authentication, then authorization, then admission controllers, and finally persistence to etcd.

Admission control has two phases that happen in sequence. Mutating admission runs first and can modify the object before it's stored. Validating admission runs second and can accept or reject the object based on policy rules. Both phases can prevent your resources from being created, even if your YAML syntax is perfect.

Why does this matter for CKAD? Admission controllers enforce policies, set defaults, validate configurations, and can block deployment. Your perfectly valid YAML might be rejected by policy even though the syntax is correct. You won't write webhooks in the exam, but you must troubleshoot when they block you.

Key exam skills include recognizing admission controller errors in describe output, debugging Pods stuck due to admission policies, understanding Pod Security Standards, working with ResourceQuota and LimitRange objects, and reading Gatekeeper constraints to understand what's required. Essential commands include kubectl describe on ReplicaSets to see admission errors, checking events sorted by creation time, describing resource quotas and limit ranges to see usage, and checking namespace labels for Pod Security settings.

Let me show you the built-in admission controllers relevant to CKAD. NamespaceLifecycle prevents objects from being created in terminating or non-existent namespaces, which is a common error source. LimitRanger enforces LimitRange constraints for resource management. ResourceQuota enforces namespace quotas. ServiceAccount automates ServiceAccount injection into Pods. DefaultStorageClass adds a default storage class to PersistentVolumeClaims. PodSecurity enforces Pod Security Standards, which is increasingly important. And the webhook admission controllers call external webhooks for custom policy enforcement.

## Pod Security Standards

Pod Security Standards are enforced at the namespace level via labels, providing a standardized way to restrict Pod configurations. There are three policy levels that provide increasing levels of security.

Privileged is unrestricted and allows everything. This is intended for trusted system workloads that need elevated permissions. Baseline is minimally restrictive and prevents known privilege escalations, making it suitable for common applications. Restricted is heavily restricted and follows Pod hardening best practices for security-critical applications.

Pod Security Standards have three enforcement modes that you apply at the namespace level using labels. Enforce mode means policy violations will reject the Pod outright. Audit mode means violations are allowed but logged to the audit log for review. Warn mode means violations are allowed but a warning is returned to the user. You can use multiple modes together, for example enforcing baseline while auditing and warning for restricted violations.

The baseline level prevents several dangerous configurations. It blocks Pods where hostNetwork, hostPID, or hostIPC are set to true. It blocks privileged containers. It prevents the use of hostPath volumes. And it restricts capability additions to only safe ones. These restrictions prevent the most common privilege escalation paths.

Restricted mode goes further and additionally requires running as non-root, dropping ALL capabilities, setting a seccomp profile, and preventing privilege escalation. This level implements defense in depth for security-sensitive workloads.

Here's a common error you'll see in the exam. The message says the Pod violates PodSecurity baseline because hostNetwork is set to true. The fix is straightforward - remove hostNetwork from your spec or explicitly set it to false.

For restricted mode, you'll need a more comprehensive security context configuration. At the Pod level, you need to set runAsNonRoot to true, specify a user ID like one thousand, set a group and fsGroup, and configure a seccomp profile with type RuntimeDefault. In each container, you must set allowPrivilegeEscalation to false and drop ALL capabilities.

One important note for the exam - standard container images may not work with restricted policies. Many images run as root by default. You'll need non-root variants like nginx-unprivileged or redis alpine with appropriate user flags.

Let's practice the workflow. Create a namespace with restricted enforcement and try to run a basic nginx pod. The basic nginx will fail with multiple violations. The error message lists every requirement not met, including that allowPrivilegeEscalation must be false, capabilities must drop ALL, runAsNonRoot must be true, and seccompProfile must be set. This comprehensive error message tells you exactly what to fix. You can fix it by creating a Pod with the proper security context fields the error message specified and using a non-root image like nginx-unprivileged alpine.

## ResourceQuota Admission Control

ResourceQuota is an admission controller that enforces namespace quotas by tracking cumulative resource usage across all pods in a namespace. This prevents any single namespace from consuming too many cluster resources.

Here's an example ResourceQuota with compute limits. It sets hard limits for requests CPU, requests memory, limits CPU, limits memory, and the total number of pods. When these quotas are in place, the admission controller checks every Pod creation against the current usage.

When quota is exceeded, you'll see a clear error message. It might say exceeded quota compute-quota, requested limits memory 4Gi, used limits memory 6Gi, limited limits memory 8Gi. This tells you exactly what resource is over quota, how much you requested, how much is currently used, and what the limit is.

To debug quota issues, describe the resource quota in the namespace. The output shows Used versus Hard limits for each resource, making it clear which resources are at their limits. You have three fix strategies. Option one is to reduce resource requests or limits in your Pod spec. Option two is to scale down other workloads in the namespace to free up quota. Option three is to increase the quota if you have permission, though this may not be allowed in the exam environment.

Let me walk through a practical scenario. Create a namespace with a quota of 2 pods. Try to create 3 pods via a Deployment or manually. The third pod fails with exceeded quota showing requested pods 1, used pods 2, limited pods 2. When you check the quota status, you can clearly see you're at the limit.

Important points about ResourceQuota for the exam. It's enforced at Pod creation time, not retroactively, so existing pods keep running even if you later reduce quota. The admission controller blocks Pods that exceed quota, not Deployments, so the Deployment gets created successfully but its ReplicaSet can't create all the Pods. Quota tracks cumulative usage, meaning all pods in the namespace count toward quota regardless of which Deployment or controller created them.

## LimitRange Admission Control

LimitRange enforces default limits and minimum maximum constraints at the namespace level, operating on individual Pods and containers rather than namespace-wide totals like ResourceQuota.

Here's an example LimitRange specification. It defines default limits that apply if you don't specify them, like memory 512Mi and CPU 500m. It defines default requests like memory 256Mi and CPU 100m. It sets maximum allowed values that you cannot exceed. And it sets minimum required values that you must meet. These rules are enforced by the admission controller.

When you exceed the maximum, you'll see an error message saying something like maximum memory usage per Container is 1Gi, but limit is 2Gi. When you don't specify resources and a LimitRange exists, the defaults are automatically applied to your container.

To debug LimitRange issues, describe the LimitRange in the namespace. The output shows defaults, min, and max for resources, making it clear what constraints are in place. Two key behaviors to understand. If your container doesn't specify resources, LimitRange applies defaults automatically and your Pod gets created with those values. If you exceed the maximum or don't meet the minimum, your requests are rejected by the admission controller.

This is different from ResourceQuota in important ways. LimitRange operates on individual containers and pods, while ResourceQuota operates on namespace-wide totals. LimitRange can set defaults that get applied automatically, while ResourceQuota cannot set defaults. LimitRange prevents individual large resource requests, while ResourceQuota prevents the aggregate from being too large.

## OPA Gatekeeper

In CKAD, you won't create Gatekeeper policies, but you may need to work with existing ones when they block your deployments. Gatekeeper provides a way to enforce custom policies using constraint templates and constraints.

To understand Gatekeeper constraints, you need to know how to query them. List constraint templates to see the policy definitions available. List specific constraints to see policy instances that are actually enforced. Describe constraints to see violations and requirements, which is particularly helpful when debugging.

Gatekeeper error messages have a specific format. They typically say admission webhook validation.gatekeeper.sh denied the request, followed by a message showing the constraint name and what's missing, like you must provide labels app and owner. This tells you exactly what needs to be fixed.

Here's the debugging workflow for Gatekeeper issues in the exam. First, check which constraints exist in the cluster by getting all constraints across namespaces. Second, describe the constraint to understand requirements. Look for the Match section showing which resources it applies to, the Parameters showing what's required or restricted, and the Violations showing current violations which can be very helpful. Third, fix your YAML to meet the requirements shown in the constraint.

Let's practice the workflow. Given a Gatekeeper constraint requiring app and version labels, you would check the constraint to understand requirements, create a compliant pod with both labels in the metadata section, and apply to verify it's accepted.

Common Gatekeeper ConstraintTemplates you might encounter include K8sRequiredLabels which enforces required labels like app, owner, and version. K8sAllowedRepos restricts image registries to only pull from an internal registry. K8sContainerLimits enforces that all containers must have resource limits. K8sBlockNodePort blocks NodePort services for security. And K8sNoHostNamespace blocks host network, PID, and IPC to prevent privilege escalation.

## Common CKAD Scenarios and Troubleshooting

Let me walk through common scenarios you'll encounter in the exam involving admission control.

Scenario one is a Deployment not creating Pods. The symptom is that the deployment exists and the ReplicaSet exists, but no Pods appear. When you get the deployment, it shows 0 of 3 ready. The key is to check the ReplicaSet events by describing the ReplicaSet, where you'll see the admission webhook denied the request message. Common causes include validating webhooks rejecting Pods, ResourceQuota exceeded, LimitRange violations, or Pod Security Standard violations.

Scenario two is a Pod Security Standard error. The error says violates PodSecurity baseline, hostNetwork pod must not set spec.securityContext.hostNetwork true. The fix is straightforward - remove hostNetwork or set it to false in your spec.

Scenario three is ResourceQuota exceeded. The error says exceeded quota compute-quota, requested limits CPU 2, used limits CPU 3, limited limits CPU 4. Your fix options are to reduce resource requests in your Pods, delete other Pods in the namespace to free quota, or increase the quota if you have permission. Always check current usage with describe resourcequota to see what's consuming the quota.

Scenario four is missing required labels from Gatekeeper. The error says admission webhook validation.gatekeeper.sh denied the request, you must provide labels app. The fix is adding the app label to your metadata labels section.

Here's your troubleshooting checklist for admission issues in the exam. When a resource won't create, start by checking the object status with get and describe. For Deployments specifically, check ReplicaSets with describe rs since that's where admission errors appear. Look for admission webhook errors in events - they have the format admission webhook denied the request. Check namespace labels for Pod Security Standards with get namespace show-labels. Check ResourceQuotas with describe resourcequota. Check LimitRanges with describe limitrange. Check Gatekeeper constraints by getting and describing them. And always read the error message carefully - it usually tells you exactly what's wrong and what needs to be fixed.

## Practice Exercises and Exam Tips

Let's review the practice exercises from the CKAD material and discuss strategies for the exam.

Exercise one is debugging an admission failure. You're given a Deployment that creates a ReplicaSet but no Pods, with an unknown admission policy in place. Your tasks are to identify the admission controller blocking the Pods, read the error message to understand requirements, and fix the Deployment to pass admission. The approach is to deploy the application, check why Pods aren't created with describe rs, understand the requirement by describing the Gatekeeper constraint if one exists, and fix the Deployment by adding the missing labels or other required fields.

Exercise two focuses on Pod Security Standards. Your tasks are to create a namespace with baseline enforcement, try to deploy a pod with hostNetwork true which should fail, deploy a compliant pod, change to restricted enforcement, and fix the pod to meet restricted requirements. Key learnings include that Pod Security Standards are namespace-scoped and set via labels, baseline prevents hostNetwork, privileged, and hostPath, restricted requires runAsNonRoot, drop ALL capabilities, and seccomp profile, and standard images may not work because you need non-root variants.

Exercise three is ResourceQuota troubleshooting. Given a namespace with ResourceQuota and a Deployment that partially scales, your tasks are to identify why only some pods are created, check quota usage, and fix by adjusting resources or quota. The approach is to check the ReplicaSet for quota errors, describe resourcequota to see usage, calculate total resources needed, and either reduce per-pod resources or scale down other workloads to free quota.

Now for exam tips and strategy. Read error messages carefully because they tell you exactly what's wrong. Check ReplicaSet events for Deployments since admission errors appear there, not on the Deployment itself. Know the Pod Security Standard levels of privileged, baseline, and restricted. Understand that ResourceQuota is namespace-scoped. Practice without admission controllers first, then add policies to understand the difference. Use dry-run to test because kubectl apply dry-run server catches admission errors before creating objects. Check namespace labels since Pod Security Standards are set there. Don't try to write webhook code - focus on using and debugging existing policies.

Time-saving commands for the exam include describing ReplicaSets with describe rs -l app=label, getting namespace labels with get namespace show-labels, describing resource quotas, listing all constraints across namespaces, and checking events sorted by timestamp.

Common mistakes to avoid include checking the Deployment instead of the ReplicaSet for admission errors, not reading the full error message, forgetting about namespace-scoped policies like Pod Security Standards and ResourceQuota, not verifying quota after making changes, missing securityContext fields for restricted policies, and debugging the wrong object - for Deployments check ReplicaSet, for StatefulSets check Pods directly.

Practice identifying admission errors in under two minutes. Move on quickly if stuck - don't let admission questions consume more than five minutes in the exam. Good luck with your CKAD certification!
