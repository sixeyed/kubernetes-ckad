# Affinity - Exercises Narration Script

**Duration:** 25-30 minutes
**Format:** Screen recording with live demonstration

---

Welcome back! In the previous video, we covered the concepts behind Pod and node affinity in Kubernetes. Affinity is an advanced feature that lets you control where Pods run based on node properties or relationships to other Pods. This lab is marked as beyond CKAD, but understanding these patterns will make you a more effective Kubernetes developer.

## Reference

Before we dive into the hands-on work, let me point you to the key resources for this lab. The Kubernetes documentation covers affinity and anti-affinity in detail, showing how to apply rules to both nodes and Pods. The affinity API spec is part of the Pod specification, and you'll find documentation about standard node labels and taints that you can use for node affinity rules.

## Node affinity

Let's get started with node affinity by setting up a multi-node cluster so we can see how Pods get placed. We're using k3d, which is a great tool for running lightweight Kubernetes clusters locally. If you don't have k3d installed, you can get it through your package manager like Chocolatey on Windows, brew on MacOS, or via a curl script on Linux.

Let's create a three-node cluster specifically for this affinity lab. We'll create one control plane node and two worker nodes, with a Pod limit of 5 per worker node to make our demonstrations more visible. We're also disabling some extra k3d components like metrics-server and traefik to keep things simple.

Now let's verify our cluster is ready. Perfect. We have three nodes - one server which is the control plane and two agents which are the workers. When we describe one of the agent nodes, we can see the capacity is set to 5 Pods as we specified. The control plane node doesn't have a specific Pod capacity set, so it uses the default of 110 Pods, which is one of the best practice recommendations for large clusters.

Let's deploy a simple application without any affinity rules to see the default behavior. This creates a Deployment with six replicas of the whoami application. When we check where these Pods landed, we'll see they're distributed across all three nodes. The scheduler spreads them automatically for basic load balancing.

In the clusters lab we saw how to use taints and tolerations, and node selectors to schedule Pods, but those options are not as flexible as affinity. If we want to run all the Pods on nodes which have been verified as CIS compliant, we could add a label to the nodes and use a node selector, but if we wanted to restrict to worker nodes and not the control plane, we would have to use taints and tolerations. Node affinity lets us set both requirements in one place.

Now let's add our first node affinity rule. This updated spec requires Pods to run on nodes that don't have the control plane role label, and also requires a custom CIS compliance label. This is a requiredDuringSchedulingIgnoredDuringExecution rule, which means it must be met when Pods are scheduled, but existing Pods won't be removed if they don't meet the requirements.

When we apply the update and watch the ReplicaSets, we'll see the existing ReplicaSet gets scaled down by one Pod and a new ReplicaSet gets created, but it never scales up to full capacity. The affinity rule doesn't affect existing Pods, but the rule is part of the Pod spec and a change to the Pod spec is rolled out by the Deployment as a new ReplicaSet.

List the Pods now and you'll see the app is not at full capacity. There are 5 Pods from the original Pod spec - only one was terminated in the update. The new Pods are all in the Pending state. Let's investigate why by describing one of the new Pods.

The scheduler is telling us zero of three nodes are available, three nodes didn't match Pod's node affinity selector. This is because our affinity rule requires a label cis-compliance equals verified, but we haven't added that label to any nodes yet. Let's fix this by labeling the agent-1 node with that label.

Now some Pods start scheduling on agent-1, and we can see the new ReplicaSet scaling up and the old one scaling down. But the rollout can't complete. When we describe the new Pods again, we'll see a different problem. Now the message says zero of three nodes are available, one Too many pods, two nodes didn't match Pod's node affinity selector. Only one node matches the affinity requirements, and it's configured to run a maximum of 5 Pods. It has no capacity to run more Pods, so new ones can't be started to replace the old ones. This demonstrates how node capacity constraints interact with affinity rules.

## Node topology

Before we continue with Pod affinity, we need to set up node topology labels. A more typical use for affinity is to enforce a spread of Pods across the nodes in a cluster. This depends on the cluster's topology, where the location of the nodes is represented in labels.

In a real cloud environment, these labels are automatically applied to represent the geography of nodes. Regions identify datacenters, zones identify failure domains within regions. In our k3d cluster, we need to add them manually. Let's check the current topology labels by looking at the hostname label.

Every cluster adds a hostname label which uniquely identifies each node. This is the lowest level of topology where every node has a different label value. Clusters usually add more labels to represent the geography of the nodes. Cloud services typically add region labels to identify the datacenter where the node is running, and also zone labels to identify the failure zone within the region.

Now let's simulate that in our cluster to give us regions and zones to work with. We'll label all nodes with region lab, then put the server and agent-0 in zone lab-a and agent-1 in zone lab-b. Now all nodes are in the lab region, the control plane and agent-0 are both in zone lab-a, and agent-1 is in zone lab-b. These topology labels will be crucial for our Pod affinity demonstrations.

## Pod affinity & anti-affinity

Now let's explore Pod affinity. You use node topology in Pod affinity rules, expressing that Pods should run on nodes where other Pods are running or not running. Let's start fresh by deleting our previous deployment so we have a fresh set of Pods to work with.

This new spec uses Pod affinity to require all Pods to run in the same region. The spec has two affinity rules - node affinity to prevent Pods running on control plane nodes, and Pod affinity to require all Pods to run on nodes in the same region. Pod affinity uses the topology key to state the level where the grouping happens. We could use our cluster labels to put all Pods in the same region, zone or node.

When we deploy it and check where the Pods land, we'll see all Pods are running on worker nodes in the same region. The Pod affinity rule states they must be in the same region as each other. Pods will be scheduled on both agent nodes, which are both in the same region.

Zones are used to define different failure areas within a region. Each zone may have dedicated power and networking, so if one zone fails the servers in another zone keep running. In a cluster with zones you may want to ensure Pods run on nodes in different zones, for high availability. You do that with anti-affinity.

This spec removes the node affinity so Pods can run on the control plane, and uses Pod affinity to keep Pods all in one region and Pod anti-affinity to keep Pods away from other Pods in the same zone. Let's clear down the existing Deployment and create the new one.

When we check how many Pods are running and which nodes they're on, we'll see two Pods running, one on agent-1 and the other on agent-0 or the server. The rest will all stay as Pending. If we describe a Pending Pod, we'll see there are no available nodes which match the affinity rules.

These are required affinity rules, and they state Pods shouldn't run on a node if there's another Pod from this Deployment already running on a node in the same zone. So when a Pod is running on agent-1, no more Pods will be scheduled for nodes in zone lab-b. And when a Pod is running on agent-0 or the server, no more Pods will be scheduled for zone lab-a.

This is probably not what you want. The rule might instead be that all Pods must run in the same region, and within the region Pods should be spread across zones, but it's okay to run multiple Pods in the same zone. This spec expresses that rule using a required affinity rule at the region level, and a preferred rule at the zone level.

When we replace the Deployment with this spec, we should find all six replicas running, with at least one Pod on each node. This rule is a soft preference so you may find all Pods on one node, but more likely the scheduler will try to spread them. The key difference is that preferred affinity gives guidance to the scheduler without creating impossible constraints.

## Lab

Preferred affinity rules have a weighting, so you can express the priority of your preferences. For this lab we want to use that to express affinity rules for the whoami app. Create a new Deployment spec configured so that Pods only run on worker nodes which have a cis-compliance label applied, Pods prefer to run on nodes labelled with cis-compliance equals verified, but Pods can run on nodes labelled with cis-compliance equals in-progress.

Start by deleting the existing Deployment so you don't have to wrestle with a rollout. You'll need to flag that agent-0 is in the process of getting CIS compliance, so Pods can run on it. Can you configure your Deployment to run five Pods on agent-1, which is CIS verified, and only one on agent-0?

The solution uses a required node affinity with the Exists operator to ensure any node with a cis-compliance label can be used, and also excludes control plane nodes. Then it uses preferred affinity with different weights - high weight like 80 for verified nodes and low weight like 20 for in-progress nodes. This strongly guides the scheduler toward verified nodes while still allowing in-progress nodes as a fallback. When you deploy it and check the distribution, most Pods should land on agent-1 with only one or two on agent-0.

## **EXTRA** Node affinity for multi-arch images

Docker images can be published with multi-architecture support, so one image tag actually has several variants which work on different CPU architectures or operating systems. You can check the OS and CPU architecture for your nodes to see what platforms your cluster supports. Yours will probably all be Linux on amd64 Intel, but a Kubernetes cluster can contain a mix of platforms.

You can use affinity rules to get the most out of your cluster if you have multi-arch images. Maybe your production cluster has 20 Linux nodes and 5 Windows nodes. The Windows nodes are mainly for legacy apps, but you want to use their capacity too. The multi-arch spec expresses that requirement - Pods must run on Linux or Windows nodes, but with a 10-1 preference for Linux, so there will only be Pods on the Windows nodes if the Linux nodes are full.

The spec has many affinity rules because the OS and architecture labels have changed between Kubernetes versions. Older versions used beta.kubernetes.io/os and beta.kubernetes.io/arch, while newer versions use kubernetes.io/os and kubernetes.io/arch. The rules use both so the same spec can be used on old and new clusters.

Your cluster is Linux-only, but you should still get all the Pods running. When you check, you'll see Pods on the server and both agents because there are no affinity rules for node roles.

## Cleanup

If you want to continue using your k3d cluster, clean up the lab resources by deleting the Services and Deployments with the lab label. Or remove your k3d cluster entirely and switch back to your previous cluster like Docker Desktop. You can use kubectl config get-contexts to find your previous context if you don't know the name.

That completes our practical demonstration of Pod scheduling with affinity. We saw how required node affinity creates hard constraints that must be met. We explored Pod affinity and anti-affinity using topology keys to control whether Pods should be co-located or spread apart. And we looked at preferred affinity rules with weights to provide guidance without creating impossible constraints. These affinity patterns are powerful tools for optimizing your Kubernetes deployments.
