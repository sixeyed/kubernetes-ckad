# DaemonSets - Practical Demo
## Narration Script for Hands-On Exercises

### Section 1: Deploying a DaemonSet

Welcome to the hands-on DaemonSets demonstration. In this session, we'll explore how DaemonSets work, their update behavior, and how to control which nodes they run on.

Our first example deploys Nginx as a DaemonSet. While Nginx doesn't typically need to run on every node, this example demonstrates DaemonSet patterns without complex infrastructure code. The key features are that it uses a HostPath volume for Nginx logs written directly to the node's disk, creates exactly one Pod per node in the cluster, and includes Services for external access.

Let's look at the DaemonSet spec. Notice there's no replicas field - the number of Pods is automatically determined by the number of nodes.

The Pod spec includes a HostPath volume with DirectoryOrCreate type, which means Kubernetes will create the directory on the node if it doesn't exist. Nginx logs written to /var/log/nginx in the container are actually written to the node's filesystem.

Let's deploy everything.

Immediately check the DaemonSet status. Observe the output showing DESIRED which is the number of nodes in your cluster, CURRENT showing Pods currently running, READY showing Pods ready to serve traffic, UP-TO-DATE showing Pods with the latest spec, and AVAILABLE showing available Pods.

In a single-node cluster, you'll see all values as 1. In a 3-node cluster, you'll see 3.

Key observation: DaemonSets automatically scale with your cluster size. Add a node, get a Pod. Remove a node, lose its Pod.

Now let's check the Pods with wide output. Note the NODE column - each Pod is on a different node if you have multiple nodes.

DaemonSet Pods work with Services just like any other Pods. Let's verify. Check the Pod details and note the IP address. Now check the Service endpoints - the Service endpoint includes the DaemonSet Pod's IP address. Services don't care whether Pods come from Deployments, StatefulSets, or DaemonSets - they use labels to find Pods.

Test the application to see the Nginx welcome page.

---

### Section 2: Understanding DaemonSet Update Behavior

This is where DaemonSets differ significantly from Deployments. When you update a DaemonSet:

Deployment behavior: New Pods start, verify they're healthy, then delete old Pods.
DaemonSet behavior: Delete old Pods, then start new Pods.

This means DaemonSet updates can cause temporary service interruption per node. Let's see this in action with a broken update.

We have a spec that intentionally breaks the DaemonSet to demonstrate update behavior. It changes the container command to something that will immediately exit.

Deploy the bad update and watch what happens to the Pods.

Observe the sequence: First, the existing Pod goes into Terminating status. Then the Pod is fully terminated and disappears. Next, a new Pod is created. Finally, the new Pod starts but enters CrashLoopBackOff or Error status.

Critical point: The old working Pod was deleted before Kubernetes verified the new Pod worked. Your application is now broken.

Try accessing the app - it will fail.

Contrast with Deployment: With a Deployment, the old Pod would still be running because Kubernetes wouldn't delete it until the new Pod was Ready. DaemonSets can't do this because there can only be one Pod per node.

---

### Section 3: Fixing with Init Containers

The proper way to do what that bad update attempted is to use an init container. Init containers run before the main application container and are perfect for setup tasks.

Let's look at the updated spec. The init container writes a custom HTML page, then exits. Then the Nginx container starts and serves that page.

Deploy the fix and watch the rollout.

Observe the new statuses: Init:0/1 means the init container is running, PodInitializing means the init container completed and the main container is starting, and Running means all containers are running.

Verify the init container output by checking the logs. Check the HTML content.

Test the application to see it working again with the new content.

Key learning: Use init containers for setup tasks, not by modifying the main application's command.

---

### Section 4: Node Selection with Labels

One of DaemonSet's most powerful features is the ability to target specific nodes. This is done using node labels and selectors.

The pattern: Label nodes with specific criteria, DaemonSet uses nodeSelector to target those labels, and Pods only run on matching nodes.

Let's see this in practice with our Nginx DaemonSet. The updated spec adds a nodeSelector that targets nodes with a specific label.

Deploy this update and watch what happens.

Observe: The existing Pods are terminated and no new Pods are created!

Check the DaemonSet status. You'll see DESIRED: 0 because no nodes match the selector criteria. The DaemonSet controller calculated that zero Pods should exist, so it deleted the existing ones.

Now let's label a node to match the selector. First, find your node name, then label the node. Watch the Pods immediately.

Observe: A new Pod is created almost immediately! The DaemonSet controller detected that a node now matches the criteria and created a Pod for it.

Test the application again - it's working again.

Key insight: DaemonSets are dynamic. Change node labels, and the DaemonSet automatically adjusts. This is powerful for different DaemonSets on different node types like GPU vs CPU, environment-specific agents for production vs development nodes, and gradually rolling out new infrastructure components.

---

### Section 5: Lab Challenge

Now it's time to practice advanced DaemonSet features. The lab includes two challenges:

Challenge 1: Configure manual update control - update the DaemonSet spec but have Pods only update when you manually delete them.

Challenge 2: Delete the DaemonSet but keep the Pods running.

These demonstrate advanced DaemonSet capabilities.

For Challenge 1, the solution involves changing the updateStrategy to OnDelete. This gives you complete control over when updates happen by requiring manual Pod deletion to trigger updates.

Apply the OnDelete spec, then make a change to test it like adding an environment variable. Check the Pods - they're still running with the old spec! The update didn't trigger a rollout.

Now manually delete a Pod and watch the new Pod come up with the updated spec.

Key learning: OnDelete gives you complete control over when updates happen. This is useful for critical infrastructure where you want to test updates on one node before proceeding.

For Challenge 2, the solution uses the cascade=orphan flag when deleting. This deletes the DaemonSet object but leaves Pods running. The Pods are now "orphaned" - they continue running but have no controller managing them.

Use case: This is useful when migrating from a DaemonSet to another controller type, performing cluster maintenance that requires removing the DaemonSet object temporarily, or debugging without disrupting running services.

Important: Orphaned Pods won't be recreated if they fail or are deleted. They have no controller watching them.

---

### Section 6: Advanced Pattern - Pod Affinity with DaemonSets

The lab includes an advanced pattern: deploying a Pod that must land on the same node as a DaemonSet Pod. This is useful for debugging.

The scenario: Your DaemonSet writes logs to a HostPath volume. You want to deploy a debug Pod that can access those same logs.

The solution: Use Pod affinity to co-locate the debug Pod. The spec uses podAffinity to schedule the Pod on the same node as a Pod with a specific label.

The spec also includes the same HostPath volume as the Nginx DaemonSet, allowing both Pods to access the same node directory.

First, ensure the Nginx DaemonSet is running, then deploy the sleep Pod with affinity. Verify they're on the same node using wide output.

Access the shared logs from both the Nginx Pod and the sleep Pod. Both Pods see the same files because they're accessing the same node directory via HostPath.

Practical use: This pattern is useful for debugging DaemonSets that use HostPath volumes. You can deploy a debug Pod with tools and access the same node resources.

---

### Section 7: Cleanup

Let's clean up all the lab resources. Delete all resources labeled with the lab label. This includes Services, DaemonSets, and Pods.

Verify everything is cleaned up.

Summary: We learned that DaemonSets automatically adjust to cluster size with one Pod per node. Unlike Deployments, DaemonSets delete old Pods before creating new ones, which can cause service interruption. Init containers are the proper way to perform setup tasks. Using nodeSelector, DaemonSets dynamically respond to node labels. OnDelete strategy gives complete control over when updates happen. Using cascade=orphan allows removing the DaemonSet without affecting running Pods. HostPath volumes are commonly used to access node-level resources. Pod affinity allows debug Pods to be co-located with DaemonSet Pods.

Key skills for CKAD: Know how to create a DaemonSet from YAML, understand there's no replicas field, remember update behavior differs from Deployments, know how to use nodeSelector for targeting, and understand OnDelete vs RollingUpdate strategies.

---

## Recording Notes

**Key Points:**
- Emphasize the "one Pod per node" concept throughout
- Show the difference between DaemonSet and Deployment update behavior
- Demonstrate that DaemonSets automatically scale with cluster size
- Highlight how node labels dynamically control DaemonSet Pod placement
- Note that OnDelete strategy requires manual Pod deletion for updates
- Stress the use case for init containers vs modifying main container commands
- Explain orphan Pods and when to use cascade=orphan

**Visual Focus:**
- Show kubectl get pods -o wide frequently to highlight the NODE column
- Use watch commands to show dynamic behavior during updates
- Display DaemonSet status showing DESIRED matching node count
- Highlight the sequence during bad updates (terminate then create vs create then terminate)
- Show before/after when adding node labels
- Demonstrate Pod affinity by showing both Pods on the same node
- Keep terminal output visible for key observations
