# Kubernetes Clusters - Practical Demo
## Narration Script for Hands-On Exercises

### Section 1: Creating Multi-Node Cluster

Welcome to the Kubernetes clusters hands-on demonstration. In this session, we'll explore node operations, taints and tolerations, and node maintenance workflows.

Let's create a 3-node cluster with k3d.

We have one control plane (server) and two workers (agents). Let's check the node details to see capacity, allocatable resources, and conditions.

The node information shows us the resources available, the current conditions like Ready status, and various details about the node's configuration. Understanding node capacity and allocatable resources is essential for planning workload placement.

---

### Section 2: Taints and Tolerations

Let's deploy the whoami app across all nodes to see the default behavior.

Pods are distributed across all nodes using the default scheduler logic. Now let's taint a node with NoSchedule. This prevents new Pods from being scheduled there but doesn't affect existing Pods.

Let's restart the deployment to force rescheduling.

No new Pods schedule on agent-1 due to the taint. The taint acts as a barrier that only Pods with matching tolerations can cross.

Now let's taint the control plane with NoExecute, which is more aggressive.

Pods on the server get evicted immediately with NoExecute. This is different from NoSchedule, which only prevents new scheduling. NoExecute actively removes non-tolerating Pods that are already running.

Now let's update the deployment with a toleration that allows Pods to schedule on the tainted node.

Now Pods can schedule on agent-1 because they tolerate the taint. This demonstrates how tolerations give specific Pods permission to run on tainted nodes. Tolerations must match the taint's key, value, and effect.

---

### Section 3: Node Labels and Scheduling

Let's add topology labels to simulate a real cloud environment with regions and zones.

These topology labels are used for zone-aware scheduling and can influence Pod placement decisions. They're also used by features like topology spread constraints.

Now let's deploy a DaemonSet with a node selector.

The DaemonSet respects both taints and node selectors, so it only runs on nodes that match its criteria. Notice it creates Pods only on nodes in the west zone, and even then, only if those nodes can tolerate any taints.

---

### Section 4: Node Maintenance

Let's practice node maintenance operations. First, we'll cordon a node, which marks it as unschedulable.

The status now shows SchedulingDisabled. New Pods won't be scheduled here, but existing Pods continue running. Cordoning is the first step before draining.

Now let's drain the node, which evicts all Pods.

Pods are evicted and rescheduled to other nodes. Draining is essential before performing maintenance on a node. You'll typically need flags like ignore-daemonsets because DaemonSet Pods can't be evicted normally.

Now let's uncordon the node to make it available again.

The node is available again for scheduling. Note that Pods don't automatically move back - they stay where they were rescheduled. You'd need to manually reschedule or recreate them if you want them back on this node.

---

### Section 5: Lab

Now it's time to practice what you've learned. Your challenge involves node operations and Pod scheduling.

Tasks:
- Label nodes with specific environment tags (dev, staging, production)
- Deploy applications that target specific node labels
- Taint a node to dedicate it for specific workloads
- Create Pods with appropriate tolerations
- Practice the cordon/drain/uncordon workflow

Solution approach: Start by labeling nodes with kubectl label node, then create Deployments with nodeSelector matching those labels. Add taints to nodes using kubectl taint with NoSchedule effect. Update Pod specs to include tolerations matching the taints. Finally, practice cordoning and draining a node, then uncordoning it.

---

### Section 6: Cleanup

Time for cleanup. Let's remove all the resources and delete the cluster.

Summary: We created a multi-node cluster and explored node operations. We learned about taints and tolerations - how NoSchedule prevents new scheduling while NoExecute actively evicts Pods. We saw how node labels and selectors control Pod placement, and we practiced the cordon/drain/uncordon workflow for node maintenance.

Key takeaways: Taints repel Pods unless they have matching tolerations. The NoExecute taint effect is more aggressive than NoSchedule. DaemonSets respect both taints and node selectors. Always cordon before draining, and remember that Pods don't automatically return after uncordoning.

---

## Recording Notes

**Key Points:**
- Emphasize the difference between NoSchedule and NoExecute taint effects
- Show how tolerations work with taints - they must match key, value, and effect
- Demonstrate the complete cordon/drain/uncordon workflow for maintenance
- Highlight that DaemonSets respect both taints and selectors
- Note that Pods don't automatically return after uncordoning a node
- Stress the importance of the ignore-daemonsets flag when draining

**Visual Focus:**
- Show Pod distribution across nodes clearly using wide output
- Highlight taint effects on Pod scheduling with before/after comparisons
- Display node status changes during cordon/drain operations
- Keep node names visible for clarity throughout demonstrations
- Show the events when Pods are evicted during drain operations
