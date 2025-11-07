# Rollouts and Deployment Strategies for CKAD

Welcome to the CKAD exam preparation session for rollouts and deployment strategies. This topic extends the basic rollouts lab with CKAD exam-specific scenarios and deployment strategies that you need to master for the exam.

## CKAD Exam Context

Deployment strategies and rollouts are critical for CKAD success. You need to perform rolling updates to deployments, roll back failed deployments, understand rollout history and revisions, configure rollout strategies using maxSurge and maxUnavailable, pause and resume rollouts, check rollout status, and understand blue-green and canary deployment patterns.

This material falls under the Application Deployment domain which represents twenty percent of your exam score. Your time target should be four to six minutes per rollout question. Rolling updates are one of the most common deployment tasks you'll encounter, so practice until you can update, check status, and rollback in under five minutes.

## Understanding Deployment Rollouts

When you update a Deployment's Pod template, Kubernetes performs a rolling update through a specific process. First it creates a new ReplicaSet with the updated Pod template. Then it scales up the new ReplicaSet while scaling down the old ReplicaSet, repeating this process until all Pods are updated.

The key rollout commands you need to master start with triggering a rollout by updating the image. You check rollout status to monitor progress, view rollout history to see past revisions, pause a rollout when you need to make multiple changes, resume a paused rollout to continue, rollback to the previous version using undo, rollback to a specific revision by specifying the revision number, and restart a deployment to recreate all pods even without spec changes.

## Exercise 1: Basic Rolling Update

The task here is to deploy an application, update it to a new version, and verify the rollout. We start by creating an initial deployment with three replicas, then verify the deployment and check the pods. When we update to a new image version using the set image command, we watch the rollout with rollout status or by watching the pods update in real time.

After verifying the new version by checking the deployment description for the image, we check the rollout history which shows two revisions. We verify all pods updated by checking that all pods show the new image. The expected outcome is that old pods are gradually replaced, new pods are created, there's zero downtime during the update, and the rollout history shows both revisions.

## Exercise 2: Rollback a Deployment

This exercise has us update a deployment to a broken image and then roll back to the working version. We create a deployment with a working image, then update to a broken image tag. When we check the rollout status, it may hang or show errors, and checking the pods reveals ImagePullBackOff or ErrImagePull status.

We check the history which shows two revisions, then rollback to the previous version using rollout undo. We verify the rollback completed successfully by checking rollout status again, confirming all pods are running with the original image. When we verify in history, we see revision two and revision three, where revision three is the rollback to revision one. The key learning here is that rollback creates a new revision that's a copy of the target revision.

## Rollout Strategy Configuration

Control how rollouts happen with maxSurge and maxUnavailable settings. MaxSurge is the maximum number of pods above the desired count during rollout, and can be an absolute number or percentage with a default of twenty-five percent. Higher values mean faster rollouts but more resources needed. MaxUnavailable is the maximum number of pods that can be unavailable during rollout, also as a number or percentage with a default of twenty-five percent. Higher values mean faster rollouts but more risk.

Common configurations include fast rollout with maxSurge one hundred percent and maxUnavailable zero, which creates all new pods first then removes old pods, useful for critical services. Slow and safe rollout uses maxSurge one and maxUnavailable zero, updating one at a time for conservative updates. The balanced configuration uses the defaults of twenty-five percent for both, suitable for most applications. Fast and risky uses one hundred percent for both to achieve the fastest possible rollout, appropriate for dev environments.

## Exercise 3: Configure Rollout Strategy

The task is to create a deployment with a custom rollout strategy that updates two pods at a time. We create a deployment with ten replicas and explicitly set the strategy type to RollingUpdate with maxSurge two and maxUnavailable zero. This ensures zero-downtime updates.

After waiting for the deployment to be ready, we update the image and watch the rollout. In another terminal we watch the pods and observe that the maximum is twelve pods, which is ten desired plus two surge, and we never drop below ten pods. The expected behavior is that during rollout up to twelve pods exist temporarily, never fewer than ten pods are running, and the rollout happens in waves of two new pods.

## Rollout History and Change Tracking

Kubernetes tracks why changes were made using annotations. The record flag is deprecated but may still appear on the exam, though the better approach is using the kubernetes.io/change-cause annotation. When we update an image and set the change-cause annotation, checking the rollout history shows the change cause in the output. This is valuable for tracking what changed and why.

We can view basic history or get detailed history for a specific revision which shows the full deployment spec for that revision. Rolling back to a specific revision is straightforward. We list revisions with rollout history, then rollback to a specific revision number with the to-revision flag. This jumps directly to that specific configuration, very useful when you need to skip over several bad releases.

## Pausing and Resuming Rollouts

You can pause a deployment to make multiple changes before rolling them out together. When we pause a deployment, we can make multiple changes like updating the image and setting resources. When we check the pods while paused, nothing has changed because the deployment is paused. When we resume to apply all changes, both changes apply in a single rollout. This is useful when you need to batch multiple updates.

The use case is when you need to update multiple fields such as image, resources, and environment variables, and you want one atomic rollout instead of multiple sequential rollouts.

## Exercise 5: Pause and Resume

The task asks us to pause a deployment, make multiple changes, then resume and verify one rollout occurs. We create a deployment and check the initial history showing revision one. After pausing the deployment, we make multiple changes including updating the image, setting an environment variable, and scaling to more replicas.

We verify no rollout happened yet by checking the history, which still shows only revision one, and checking the pods which still show the old configuration. When we resume the rollout and watch it complete, we verify all changes applied including the new replica count, new image, and environment variable. The history now shows revision two, which is one rollout for all changes. The key learning is that pausing allows batching multiple changes into a single rollout.

## Blue/Green Deployment Pattern

Blue-green deployment runs two complete environments and switches traffic between them. The implementation uses Services to control traffic flow. We create a blue deployment as the current version with its own version label, a green deployment as the new version with a different version label, and a service that initially points to blue through its selector.

The switching process is simple. We deploy both versions, have the service point to blue initially, test the green deployment separately using port-forwarding, then switch traffic to green by patching the service selector. The instant switch happens without any gradual rollout or pod restarts. Rollback is equally instant by patching back to blue.

## Exercise 6: Blue/Green Deployment

The task is to implement a blue-green deployment and switch traffic between versions. We create the blue deployment with appropriate labels, create the service pointing to blue initially, and test the blue deployment. Then we create the green deployment with its own version label and verify both deployments are running.

We switch traffic to green by patching the service and verify the traffic switched by checking the service selector and testing the new version. To rollback to blue, we patch the service selector back and test again. We can cleanup the old version when no longer needed. The advantages are instant switch between versions, instant rollback, and easy testing of the new version before switching. The disadvantages are requiring double the resources and complexity with database migrations.

## Canary Deployment Pattern

Canary deployment rolls out to a small subset of users first and then gradually to everyone. The implementation uses two deployments with the same app label but different version labels. The service load-balances across all pods from both deployments. You control traffic percentage by adjusting replica counts, using the formula that canary traffic percentage equals canary replicas divided by total replicas.

For example, one canary plus four stable gives twenty percent canary traffic. We deploy the stable version with four replicas, then deploy the canary with one replica for twenty percent of traffic. When we test the application multiple times, approximately twenty percent of requests hit the canary because the service load-balances across all five pods.

For gradual rollout, if the canary is healthy we increase its percentage by adjusting replica counts. To move to fifty percent canary we scale both to three replicas. To complete the rollout to one hundred percent canary we scale canary up to four and stable down to zero. For rollback if issues are detected, we immediately scale canary to zero and scale stable back up. The advantages are minimal user impact, gradual rollout with monitoring at each stage, and easy rollback. The disadvantages are more complexity, requiring good monitoring to detect issues, and load balancing that may not give perfectly equal distribution.

## Common CKAD Rollout Scenarios

Several scenarios appear repeatedly on the exam. For updating an application version, you use set image and check the rollout status. For fixing a failed deployment, you check the status, describe pods to find the issue, rollback with undo, and verify recovery. For scaling applications, you use scale and verify all pods are ready. For adding resource limits, you use set resources on the specific container.

For configuring rolling updates, you patch the deployment with the strategy configuration. For adding probes to existing deployments, you can patch or edit to add the probe configurations. For changing deployment strategy, you patch the spec strategy type field. For updating multiple configurations, you pause the deployment, make all changes, then resume.

## Quick Command Reference

Several time-saving imperative commands will speed up your exam work. Create a deployment quickly with kubectl create deployment. Update the image with kubectl set image. Scale with kubectl scale. Set resources with kubectl set resources. Expose as a service with kubectl expose. Check rollout status, view history, and rollback with the kubectl rollout commands. Restart all pods with kubectl rollout restart. Patch specific fields with kubectl patch. These commands are much faster than editing YAML during the exam, so practice them until they're muscle memory.

## Troubleshooting Rollouts

Quick debugging steps for exam scenarios start with checking deployment status to see the overall state. Then check ReplicaSets to see if new ones were created. Check pods to see their status and look for problems. Examine events with describe deployment for error messages.

Common failure reasons include ImagePullBackOff from wrong image names or registry authentication issues, CrashLoopBackOff when containers keep failing to start, Pending state from resource constraints or scheduling issues, and rollout stuck from failing readiness probes. When you need to force a new rollout even without spec changes, use kubectl rollout restart which recreates all pods.

## Exam Tips

For time management, use kubectl create to generate YAML quickly rather than writing from scratch. Use imperative commands when possible to save typing. Practice typing resource limits and probes from memory so you don't waste time looking them up. Set your preferred editor with the KUBE_EDITOR environment variable to streamline YAML editing.

The must-know commands are kubectl create deployment, kubectl set image, kubectl scale, kubectl set resources, kubectl rollout status, history and undo, and kubectl expose. Practice these until you can type them without thinking. Key concepts to memorize include that zero downtime requires maxUnavailable zero, readiness probes prevent traffic to unready pods, liveness probes restart unhealthy containers, requests guarantee resources while limits cap them, ReplicaSets implement the actual updates, and rollbacks just scale old ReplicaSets back up.

Common requirements to recognize include that production-ready means at least two replicas, resources set, probes configured, and rolling update strategy. Zero downtime means maxUnavailable zero and readiness probes configured. Canary means two deployments with the same service selector. Blue-green means two deployments where the service selector controls which receives traffic.

## Study Checklist

Make sure you can perform rolling updates with kubectl set image, check rollout status and history, rollback to previous version, rollback to specific revision, configure maxSurge and maxUnavailable, pause and resume rollouts, batch multiple changes with pause and resume, implement blue-green deployment, implement canary deployment, troubleshoot failed rollouts, understand rollout strategies, use rollout restart to recreate pods, and track changes with annotations.

## Summary

Rollouts and deployment strategies are crucial for CKAD success. Master the core commands including kubectl set image to update images, kubectl rollout status to check progress, kubectl rollout history to view revisions, kubectl rollout undo to rollback, and kubectl rollout pause and resume to batch changes.

Understand the strategies. Rolling Update is the default with zero downtime. Blue-Green provides instant switching but requires double the resources. Canary enables gradual rollout to test with a subset of users. Know the configuration where maxSurge controls extra pods during rollout and maxUnavailable controls pods below desired during rollout.

This material represents twenty percent of the exam in the Application Deployment domain. Your time target should be four to six minutes per question. The difficulty is medium but requires practice to build speed. Practice until rollout operations are automatic, and you'll be well-prepared for this portion of the CKAD exam.
