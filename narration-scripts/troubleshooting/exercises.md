# Troubleshooting Apps in Kubernetes - Exercises Narration Script

**Duration:** 15-20 minutes
**Format:** Screen recording with live demonstration
**Prerequisite:** Kubernetes cluster running (Docker Desktop, k3d, or similar)

---

Welcome to hands-on Kubernetes troubleshooting. This is where theory meets reality, and you'll learn to diagnose and fix real problems in Kubernetes applications. Troubleshooting is a critical skill for the CKAD exam and for working with Kubernetes in general, because things will go wrong, and you need to know how to find and fix the issues quickly.

Make sure you have a Kubernetes cluster running and kubectl configured. I'm using Docker Desktop, but any Kubernetes distribution will work fine. Unlike our previous labs where we built things step by step, today we're jumping straight into a broken application. This is the reality of troubleshooting - you don't know what's wrong until you investigate.

## Lab

This lab is all about hands-on problem-solving. We have a deliberately broken Pi calculation application that should be accessible at localhost:8020 or localhost:30020, but it isn't working. Your job is to figure out what's wrong and fix it. Let me deploy the broken application from the troubleshooting specs directory.

When I run kubectl apply on the pi-failing directory, Kubernetes accepts the deployment. That's important to understand - Kubernetes validates the YAML syntax and structure, but it doesn't check whether your application will actually work. The specs could be perfectly valid Kubernetes YAML but completely broken from an application perspective.

Let's see what we have. When I check the resources, I can see we have some deployments, pods, and services created. But are they working? That's what we need to investigate. The pod status is our first clue. Is it Running? Is it Ready? Check the Ready column - it should show one out of one if everything is healthy. Look at the Restarts column too - a high number there means the container keeps crashing.

Now comes the systematic investigation. The describe command is your best friend in troubleshooting. When I describe the pod, look at all this information. The Events section at the bottom is gold - it shows you exactly what Kubernetes tried to do and where things went wrong. You might see image pull errors, probe failures, or container crashes. Each event has a timestamp and a message, so you can follow the story of what happened.

The pod logs are equally important. When I check the logs, I can see what the application itself is saying. Sometimes the application starts but has configuration problems. Sometimes it crashes immediately with an error message. If a container is crash-looping, you'll want to use the previous flag to see the logs from before it crashed.

Let's look at the service configuration next. Services need three things to work correctly - the right type, the right port configuration, and the right selector. The selector is crucial - it tells the service which pods to route traffic to. When I check the service endpoints, if I see none listed, that means the service selector doesn't match any pod labels. That's a common mistake and easy to fix once you spot it.

Here's where it gets interesting. You might find multiple problems. Maybe the image name is wrong, causing an ImagePullBackOff. Maybe the service selector doesn't match the pod labels, so there are no endpoints. Maybe the container port doesn't match the target port in the service. Real-world troubleshooting often involves fixing several issues in sequence.

Let me work through the systematic diagnostic process. First, I check the high-level status with get all. Then I describe the pods to see the events. I check the logs to see application output. I verify the service has endpoints. I check that port numbers match up between the container, the pod spec, and the service. Each step narrows down the possibilities.

When I find an issue, I can fix it in different ways. If it's in the YAML file, I can edit the file and reapply it. If it's a quick fix like changing an image or scaling replicas, I can use imperative commands. Kubernetes will detect the change and reconcile the actual state to match the desired state. That might mean creating new pods, terminating old ones, or updating configurations.

After each fix, watch what Kubernetes does. Pods might take a moment to start. Images need to be pulled. Readiness probes need to pass. Don't assume your fix worked - verify it. Check the pod status again. Look at the events to see if new errors appeared. Test the service endpoint. Try accessing the application.

When everything is working, you should be able to curl or browse to the Pi application and see it respond. The pod should be Running with a Ready status of one out of one. The service should have endpoints listed. There should be no recent restarts, and the events should show normal operations like image pulled successfully and container started.

This systematic approach is essential for the CKAD exam. You'll face similar scenarios where something is broken and you need to fix it. The exam doesn't tell you what's wrong - you have to investigate. Practice this diagnostic workflow until it becomes second nature. Start broad with get commands, narrow down with describe, dive deep with logs, and verify everything after making changes.

## Cleanup

When you're done investigating and fixing the application, let's clean up the resources. We can delete everything with the troubleshooting label, which removes all the pods, services, and deployments we created. This keeps your cluster clean for the next lab.

That completes our troubleshooting exercise. You've practiced the essential skills of investigating failed deployments, reading pod events, checking service configurations, and systematically fixing issues. These skills are fundamental for both the CKAD exam and real-world Kubernetes work. In the next video, we'll cover CKAD-specific troubleshooting scenarios with more complex failures and time-saving techniques for the exam.
