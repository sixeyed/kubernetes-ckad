# Deployments - Exercises Narration Script

**Duration:** 15-20 minutes
**Format:** Screen recording with live demonstration
**Prerequisite:** Kubernetes cluster running, completed Pods and Services labs

---

Welcome back! In the previous video, we covered the concepts behind Kubernetes Deployments. Now it's time to get hands-on and explore how Deployments manage Pods at scale with updates and rollbacks.

You don't usually create Pods directly because that isn't flexible. You can't change a Pod to release application updates, and you can only scale them by manually deploying new Pods. Instead you'll use a controller, which is a Kubernetes object that manages other objects. The controller you'll use most for Pods is the Deployment, which has features to support upgrades and scale.

Deployments use a template to create Pods, and a label selector to identify the Pods they own. Let's see how this works in practice.

## API specs

Let's start by looking at a Deployment YAML file. I'll open the whoami-v1.yaml file from the labs/deployments/specs directory. Deployment definitions have the usual metadata with a name, but the spec is more interesting. It includes a label selector and also a Pod spec.

The selector uses matchLabels with app equals whoami to find Pods. The template section is the template to use to create Pods. Notice the template metadata has labels that include app equals whoami, matching our selector. This is required or you'll get an error when you try to apply the YAML.

The template spec is a full Pod spec with containers, just like we've seen before. However, you don't include a name field in the Pod metadata because the Deployment will generate names automatically. The labels in the Pod metadata must include the labels in the selector for the Deployment, or Kubernetes will reject it.

## Create a Deployment for the whoami app

Let's create our first Deployment. Your cluster should be empty if you cleared down the last lab. This spec describes a Deployment to create a whoami Pod. It's essentially the same Pod spec we've seen before, just wrapped in a Deployment.

When I apply this Deployment, it will create the Pod for us. Notice how the Pod name is generated. Deployments apply their own naming system when they create Pods. They end with a random string to ensure uniqueness.

Deployments are first-class objects, so we work with them in kubectl in the usual way. Let me print the details of the Deployment with get and describe. The output shows useful information including the replica count, the selector, the Pod template, and events showing what the Deployment controller has done. Notice the events talk about another object called a ReplicaSet. We'll get to that concept soon.

## Scaling Deployments

The Deployment knows how to create Pods from the template in the spec. You can create as many replicas as your cluster can handle. Replicas are different Pods created from the same Pod spec.

You can scale imperatively with kubectl. Let me scale our Deployment to three replicas. The Pods are created quickly, and now we have three instances of our application running. But here's the problem with imperative commands. The running Deployment object is now different from the spec we have in source control. This is bad because source control should be the true description of the application. In a production environment all your deployments will be automated from the YAML in source control, and any changes someone makes manually with kubectl will get overwritten.

It's better to make changes declaratively in YAML. Let me show you the whoami-v1-scale.yaml file which sets a replica level of two. When I apply this spec, let's check the Pods again. The Deployment removes one Pod, because the current state of three replicas does not match the desired state in the YAML of two replicas. This is declarative configuration ensuring the actual state matches the desired state.

## Working with managed Pods

Because Pod names are random, the easiest way to manage them with kubectl is to use labels. We've done that with get, and it works for logs too. I can view logs from all Pods with the app equals whoami label, and kubectl streams logs from all matching Pods.

If you need to run commands in the Pod, you can use exec at the Deployment level. Let me try running the whoami application command. This fails because you can't run two copies of the app in one container as they both try to bind to the same port. But it demonstrates that exec works with Deployments, and Kubernetes just picks one of the Pods to run the command in.

The Pod spec in the Deployment template applies labels automatically. Let me print details including IP address and labels for all Pods with the app equals whoami label. The label selector in Services can match these labels too. Let me deploy some Services for our application.

Now I can check the Pod IP endpoints for the Services. The Services have found our Pods using their labels. I can access the app from my local machine using either the LoadBalancer on port 8080 or the NodePort on port 30010. Making multiple requests shows load balancing across the two Pods as the responses show different hostnames.

## Understanding ReplicaSets

Before we look at updates, let me explain an important detail about how Deployments work. Deployments don't actually create Pods directly. They delegate that responsibility to another object called a ReplicaSet.

When I list ReplicaSets, you'll see one with a name that's the Deployment name plus a hash. The hash is generated from the Pod template spec. Deployments manage updates by creating ReplicaSets and managing the number of desired Pods for each ReplicaSet.

This might seem like unnecessary complexity, but it's what enables rolling updates and rollbacks. When you update a Deployment, it creates a new ReplicaSet with the new Pod template. The old ReplicaSet is scaled down to zero but kept around for rollback purposes. If you later apply an update that matches an old spec, the original ReplicaSet gets reused instead of creating a new one.

## Updating the application

Application updates usually mean a change to the Pod spec, such as a new container image or a configuration change. You can't change the spec of a running Pod, but you can change the Pod spec in a Deployment. It makes the change by starting up new Pods and terminating the old ones.

Let me show you the whoami-v2.yaml file. This changes a configuration setting for the app by adding an environment variable. Environment variables are fixed for the life of a Pod container, so this change means we need new Pods.

I'll open a watch window to monitor the Pods during the update, then apply the change. Watch what happens. You'll see new Pods created, and when they're running the old Pods are terminated. This is a rolling update. At every point during the update, at least some Pods are available to handle traffic.

Let me try the app again. You'll see smaller output because the environment variable changed the application's behavior. If I repeat my requests, you can see they're load-balanced across the new Pods.

Now let's look at the ReplicaSets again. We have two ReplicaSets now. The old one is scaled to zero replicas, and the new one has two replicas. The Deployment keeps the old ReplicaSet around so we can easily rollback if needed.

Deployments store previous specifications in the Kubernetes database, and you can easily rollback if your release is broken. Let me check the rollout history. We can see two revisions in the history. Now I'll undo the rollout to go back to the previous version.

Watch the Pods as the rollback happens. It's another rolling update, but this time in reverse. The old ReplicaSet is scaled back up, and the new one is scaled down to zero. When I try the app again, we're back to the full output. The rollback worked perfectly.

## Lab

Now it's your turn to experiment. Rolling updates aren't always what you want because they mean the old and new versions of your app are running at the same time, both processing requests. You may want a blue-green deployment instead, where you have both versions running but only one is receiving traffic.

The lab challenge asks you to write your own Deployment and Service YAMLs to create a blue-green update for the whoami app. Start by running two replicas for v1 and two for v2, but only the v1 Pods should receive traffic. Then make your update to switch traffic to the v2 Pods without any changes to Deployments.

Think about how labels and selectors work. How can you use different version labels to control which Pods receive traffic through the Service? This pattern is extremely useful in production for controlled releases with instant rollback capability.

## Cleanup

When you're finished with the lab, cleanup by removing objects with the kubernetes.courselabs.co equals deployments label. This removes all Deployments and Services we created in this session.

That wraps up our hands-on exploration of Deployments. We've seen how to create Deployments from YAML, how to scale applications both imperatively and declaratively, how rolling updates work with ReplicaSets, how to rollback failed updates, and how to think about different deployment patterns like blue-green. These are essential skills for production Kubernetes work and for the CKAD exam. In the next video, we'll dive deeper into CKAD-specific scenarios including deployment strategies, health checks, resource management, and advanced rollout techniques.
