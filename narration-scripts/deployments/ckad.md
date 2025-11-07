# Deployments - CKAD Narration Script

**Duration:** 25-30 minutes
**Format:** Screen recording with live demonstration
**Prerequisite:** Completed basic Deployments exercises

---

Welcome to the CKAD exam preparation module for Kubernetes Deployments. This session covers the advanced Deployment topics required for the Certified Kubernetes Application Developer exam, building on what we learned in the exercises lab.

The CKAD exam expects you to work with deployment strategies including RollingUpdate and Recreate, rolling update configuration with maxSurge and maxUnavailable, advanced rollout management including pause and resume, resource requests and limits, health checks with readiness, liveness, and startup probes, multi-container patterns, advanced deployment patterns like canary and blue-green, and production best practices. Let's dive deep into each topic.

## Deployment Strategies

Deployments support two strategies for replacing old Pods with new ones, and you need to know both for the exam.

The RollingUpdate strategy is the default. It gradually replaces old Pods with new ones, ensuring some Pods are always available during updates. Let me deploy an example with explicit RollingUpdate configuration. The spec includes the strategy type set to RollingUpdate, with maxSurge set to one and maxUnavailable set to zero. This ensures zero-downtime updates.

When I trigger an update by changing the image, watch what happens. The deployment creates one new pod due to maxSurge, waits for the readiness probe to pass, then terminates one old pod, and repeats until all pods are updated. At no point did we have fewer than the desired replica count because maxUnavailable is zero.

The Recreate strategy is different. It terminates all existing Pods before creating new ones. This causes downtime but ensures old and new versions never run simultaneously. Let me deploy an example with Recreate strategy. The strategy is simply type Recreate with no additional parameters needed.

When I trigger an update, notice what happens. All pods terminate immediately, there's a brief period with zero running pods showing downtime, then all new pods start together, and the service is unavailable until new pods are ready. This is necessary when your application can't handle multiple versions running simultaneously, when you need to perform database migrations, when resource constraints prevent running both versions, or when the old and new versions can't share the same database.

## Rolling Update Configuration

Control how rolling updates behave with maxSurge and maxUnavailable settings. These parameters are critical for the exam.

MaxSurge is the maximum number or percentage of Pods created above the desired replica count during an update. MaxUnavailable is the maximum number or percentage of Pods that can be unavailable during an update. Let me demonstrate different configurations.

With maxSurge set to one and maxUnavailable set to zero, we guarantee all Pods remain available during updates. We temporarily have extra Pods beyond the replica count, and only after a new Pod is ready does an old one terminate. This is your zero-downtime guarantee and a common exam scenario.

You can also use percentages instead of absolute numbers. With maxSurge set to fifty percent and maxUnavailable set to fifty percent, the rollout happens much faster but with less availability guarantee. For the CKAD exam, you may need to configure a zero-downtime deployment where maxUnavailable equals zero and maxSurge equals one.

## Advanced Rollout Management

Let's explore advanced rollout controls that appear in exam scenarios.

For recording changes, Kubernetes tracks why changes were made using annotations. The record flag is deprecated but may still appear on the exam. The better approach is using the kubernetes.io/change-cause annotation. Let me demonstrate by updating an image and setting the change-cause annotation. Now when I check the rollout history, you'll see the change cause in the output. This is valuable for tracking what changed and why.

For pausing and resuming rollouts, you can pause a Deployment to make multiple changes before rolling them out together. Let me pause this deployment, then make several changes including updating the image and setting resources. When I check the Pods, nothing changed because the Deployment is paused. Now I'll resume to apply all changes in one rollout. Watch as both changes apply in a single rollout. This is useful when you need to batch multiple updates.

Checking rollout status is important for automation. The rollout status command blocks until the rollout completes. When it says successfully rolled out, the update is complete and all Pods are ready. For exam scripts, this ensures commands wait for completion before proceeding.

For rolling back, you can rollback to any previous revision, not just the previous one. The undo command rolls back to the previous revision by default, but you can specify a particular revision with the to-revision flag. This jumps directly to that specific configuration, which is very useful when you need to skip over several bad releases.

## Resource Management

Production Deployments must include resource requests and limits. This is critical for the exam. The requests section guarantees minimum resources like CPU and memory. The limits section caps maximum usage.

Let me deploy an example with resources configured. The requests specify sixty-four megabytes of memory and one hundred millicores of CPU, which is 0.1 CPU cores. The limits cap at one hundred twenty-eight megabytes and two hundred millicores.

For the exam, you can set resources imperatively to save time using kubectl set resources. This is much faster than editing YAML during the exam. Let me demonstrate by setting both requests and limits in one command.

Understanding QoS classes is also exam material. When I describe a Pod and check its QoS class, it shows Burstable because requests are less than limits. For Guaranteed QoS, requests must equal limits for all resources. Know the difference between requests, which are scheduler guarantees, and limits, which are enforcement boundaries.

## Health Checks

Production deployments need health checks to ensure reliable updates. There are three types of probes you need to master.

Readiness probes determine when a Pod is ready to accept traffic. Let me deploy an example with a readiness probe configured. The probe does an HTTP GET to the root path on port 80, waits five seconds before the first check, then checks every five seconds. If the probe fails, the Pod is removed from Service endpoints.

Watch the Pods during creation. Notice they show zero out of one ready initially, then switch to one out of one after the readiness probe succeeds. This is crucial. Without readiness probes, Pods receive traffic immediately even if they're not ready.

Liveness probes determine when to restart a container. They use a similar HTTP check but with a longer initial delay, typically fifteen seconds, and check every ten seconds. If the liveness probe fails, Kubernetes restarts the container.

Startup probes are for slow-starting containers. They have the same format but run before readiness and liveness probes. Once the startup probe succeeds, it hands off to the other probes. This prevents liveness probes from killing containers that are just slow to start.

For the exam, know all three probe types. HTTP GET probes check an HTTP endpoint, TCP Socket probes check if a port is open, and Exec probes run a command inside the container. Practice creating all three quickly.

## Multi-Container Patterns

Multi-container Pods are common in CKAD scenarios. The two main patterns are init containers and sidecar containers.

Init containers run to completion before app containers start. They're perfect for setup tasks. Let me show you an example where an init container downloads configuration before the main application starts. The init container runs, completes successfully, then the main container starts with the prepared configuration.

Sidecar containers run alongside the main container. Common use cases include log shipping, metrics collection, and proxies. Let me deploy an example with a sidecar that streams logs. Both containers run simultaneously, and the sidecar can access the main container's log files through a shared volume.

You can combine init containers and sidecars in the same Pod. Init containers run first in sequence, then all regular containers including sidecars start together. This pattern is powerful for complex application setups.

## Advanced Deployment Patterns

Beyond basic rolling updates, you need to understand canary and blue-green deployments for the exam.

Canary deployments run a small percentage of traffic on the new version to test it. The strategy is to create two Deployments with different replica counts, both selected by the same Service. Let me demonstrate with a main Deployment running three replicas and a canary Deployment with one replica. Both use the same app label but different version labels. The Service selects only the app label, not the version, so it distributes traffic proportionally, about seventy-five percent to main and twenty-five percent to canary.

When I make requests, you'll see mostly responses from the main version with occasional responses from the canary. If the canary performs well, promote it by scaling up the canary and scaling down the main. If there are issues, quickly scale back the canary.

Blue-green deployments run both versions fully but only one receives traffic at a time. You use Service label selectors to control which version receives traffic. The pattern involves creating two complete Deployments and switching the Service selector between them. This provides instant cutover with instant rollback capability.

## Production Best Practices

Let me show you a complete production-ready Deployment that would pass any exam scenario. This Deployment has everything. It includes an appropriate replica count for high availability, zero-downtime rolling update strategy with maxUnavailable zero, resource requests and limits properly configured, readiness probe for traffic management, liveness probe for auto-healing, named ports for clarity, pinned image version not using latest, change-cause annotation for tracking, and meaningful labels for management.

This is your template for exam questions asking for production-ready Deployments. Know this pattern by heart and be able to create it quickly.

## CKAD Lab Exercises

The lab exercises combine multiple concepts in realistic scenarios. Each exercise tests your ability to work quickly and accurately.

The zero-downtime deployment exercise asks you to configure a deployment ensuring no downtime during updates. You need to set maxUnavailable to zero, configure readiness probes, verify the rollout, and test that the service remains available throughout the update.

The failed deployment recovery exercise simulates a broken deployment. You identify the failure using rollout status and describe pod, fix it with rollout undo, verify recovery with rollout status again, and check the updated history.

The canary release exercise asks you to deploy a new version to a subset of pods. You create the main deployment, add a canary deployment with the same labels, verify traffic distribution, and promote or rollback as needed.

The multi-container pattern exercise requires a pod with init container and sidecar. You configure the init container for setup, add a sidecar for monitoring, verify both run correctly, and test the interaction between containers.

The production deployment exercise combines everything. You need proper replica count, rolling update strategy, resource limits, all three probe types, appropriate labels, and change tracking annotations.

## Quick Command Reference for CKAD

Let me show you time-saving imperative commands for the exam. Create a deployment quickly with kubectl create deployment. Update the image with kubectl set image. Scale with kubectl scale. Set resources with kubectl set resources. Expose as a service with kubectl expose. Check rollout status, view history, and rollback with the kubectl rollout commands. Restart all Pods with kubectl rollout restart. Patch specific fields with kubectl patch.

These commands are much faster than editing YAML during the exam. Practice them until they're muscle memory.

## Common CKAD Exam Scenarios

Let me walk through typical exam scenarios with solutions.

For updating an application version, you use kubectl set image and check the rollout status. For fixing a failed deployment, you check the status, describe pods to find the issue, rollback with undo, and verify recovery. For scaling applications, use kubectl scale and verify all pods are ready. For adding resource limits, use kubectl set resources on the specific container.

For configuring rolling updates, you patch the deployment with the strategy configuration. For adding probes to existing deployments, you can patch or edit to add the probe configurations. For changing deployment strategy, patch the spec strategy type field. For updating multiple configurations, pause the deployment, make all changes, then resume.

These patterns appear repeatedly on the exam. Practice each one multiple times.

## Troubleshooting Deployments

Quick debugging steps for exam scenarios start with checking deployment status, then checking ReplicaSets to see if new ones were created, checking Pods to see their status, and examining events for error messages.

Common failure reasons include ImagePullBackOff from wrong image names or registry authentication issues, CrashLoopBackOff when containers keep failing, Pending state from resource constraints or scheduling issues, and rollout stuck from failing readiness probes.

When you need to force a new rollout, use kubectl rollout restart. This recreates all pods even if the spec hasn't changed.

## Study Tips for CKAD

For time management, use kubectl create to generate YAML quickly, use imperative commands when possible, practice typing resource limits and probes from memory, and set your preferred editor with the KUBE_EDITOR environment variable.

Must-know commands include kubectl create deployment, kubectl set image, kubectl scale, kubectl set resources, kubectl rollout status, history, and undo, and kubectl expose. Practice these until you can type them without thinking.

Key concepts to memorize are that zero downtime requires maxUnavailable zero, readiness probes prevent traffic to unready Pods, liveness probes restart unhealthy containers, requests guarantee resources while limits cap them, ReplicaSets implement updates, and rollbacks just scale old ReplicaSets back up.

Common requirements to recognize are that production-ready means replicas of at least two, resources set, probes configured, and rolling update strategy. Zero downtime means maxUnavailable zero and readiness probes. Canary means two Deployments with the same Service selector. Blue-green means two Deployments where the Service selector controls traffic.

## Cleanup

When you're finished, remove all CKAD practice resources using the label selector. This deletes all Deployments, ReplicaSets, and Pods we created during this session.

That completes our CKAD preparation for Kubernetes Deployments. You now have the knowledge and hands-on experience needed for Deployments on the CKAD exam. Practice these scenarios multiple times until they become muscle memory. Set yourself time-based challenges to build speed. Use kubectl explain during practice since it's available during the exam. Master these concepts, and you'll be well-prepared for this portion of the CKAD exam.
