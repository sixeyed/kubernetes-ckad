# Kubernetes Clusters - CKAD Exam Preparation
## Narration Script for Exam-Focused Training

### Section 1: CKAD Exam Context and What Are Node Operations?

Welcome to CKAD exam preparation for Kubernetes node operations. While you won't create clusters in the exam, you will need to work with nodes - querying them, understanding their state, and performing basic maintenance.

First, let's understand what node operations matter for CKAD. In the exam, you'll work with an existing cluster and need to understand nodes, their capacity, labels, taints, and how they affect Pod scheduling. You won't install Kubernetes or configure the cluster itself.

Key exam scenarios include scheduling Pods to specific nodes using labels, understanding why Pods won't schedule due to taints, performing node maintenance with cordon and drain, troubleshooting node capacity issues, and working with node selectors and tolerations.

Essential commands to memorize: kubectl get nodes for listing all nodes, kubectl describe node for detailed node information, kubectl label node for adding or updating labels, kubectl taint node for managing taints, kubectl cordon for marking nodes unschedulable, kubectl drain for evicting Pods, and kubectl uncordon for making nodes schedulable again.

Node information you need includes capacity showing total resources, allocatable showing available resources after system reservations, conditions showing node health status, labels for scheduling decisions, and taints for repelling Pods.

---

### Section 2: Querying and Understanding Nodes

Let's start with the basics of node discovery and inspection.

To list all nodes in your cluster, use kubectl get nodes. The output shows node names, status (Ready or NotReady), roles, age, and Kubernetes version.

For detailed information, describe a node with kubectl describe node. This shows capacity and allocatable resources, conditions like Ready, MemoryPressure, DiskPressure, and PIDPressure, all labels, all taints, and currently running Pods with their resource requests.

To see node labels, use kubectl get nodes with show-labels. This displays all labels as key-value pairs.

For specific labels, use kubectl get nodes with -L flag followed by label keys. For example, -L kubernetes.io/hostname,topology.kubernetes.io/zone shows only those labels in columns.

To check resource usage, use kubectl top nodes. This requires metrics-server and shows current CPU and memory usage. This helps identify resource pressure before scheduling new workloads.

Standard node labels you should know: kubernetes.io/hostname contains the node's hostname, kubernetes.io/os shows the operating system (linux or windows), kubernetes.io/arch shows the architecture (amd64, arm64), topology.kubernetes.io/zone identifies the availability zone, and topology.kubernetes.io/region identifies the cloud region.

---

### Section 3: Taints and Tolerations

Taints and tolerations work together to control Pod scheduling. Taints are applied to nodes to repel Pods. Tolerations are applied to Pods to allow scheduling on tainted nodes.

To add a taint to a node, use kubectl taint node with the node name, then the taint in format key=value:effect. For example, dedicated=gpu:NoSchedule taints the node.

Taint effects include NoSchedule which prevents scheduling new Pods but doesn't affect existing ones, PreferNoSchedule which tries to avoid scheduling but isn't strict, and NoExecute which prevents new Pods and evicts existing ones without tolerations.

To remove a taint, add a minus sign after the taint specification. For example, dedicated=gpu:NoSchedule- removes that taint.

To list all taints on nodes, describe the node and look for the Taints section.

In Pod specs, you add tolerations in the spec section. A toleration has key, operator (Equal or Exists), value (when using Equal operator), and effect matching the taint.

Here's an example toleration: key dedicated, operator Equal, value gpu, effect NoSchedule. This allows the Pod to schedule on nodes with the dedicated=gpu:NoSchedule taint.

To tolerate any value for a key, use operator Exists which only checks for the key presence, not specific values. For example, key dedicated, operator Exists, effect NoSchedule tolerates any value for the dedicated key.

To tolerate all taints with a specific effect, omit the key and use operator Exists. This is a wildcard toleration.

Common taint scenarios: Dedicated nodes for specific workloads like node-role.kubernetes.io/master with NoSchedule effect keeps regular workloads off control plane nodes. Nodes under maintenance use node.kubernetes.io/unschedulable with NoSchedule to prevent new scheduling. Problem nodes use node.kubernetes.io/not-ready with NoExecute to evict Pods from failing nodes.

---

### Section 4: Node Labels and Selectors

Node labels enable you to target specific nodes for Pod scheduling.

To add a label to a node, use kubectl label node with the node name and key=value. For example, disktype=ssd labels the node.

To update an existing label, add the overwrite flag.

To remove a label, add a minus sign after the key name. For example, disktype- removes the disktype label.

In Pod specs, use nodeSelector in the spec section with key-value pairs. For example, nodeSelector with disktype: ssd schedules the Pod only on nodes with that label.

NodeSelector is simple but limited - it only does equality matching. For more complex scheduling, you'd use node affinity, but that's covered in a separate topic.

Common label patterns for the exam: Environment labels like env=production or env=dev, hardware labels like disktype=ssd or gpu=true, location labels like zone=us-west-1a, and workload type labels like workload=database.

Best practice: Always verify labels exist on nodes before using them in nodeSelector. Use kubectl get nodes -l disktype=ssd to check.

---

### Section 5: Node Maintenance Workflow

Node maintenance is a common exam scenario. You need to safely remove a node from service, perform maintenance, then return it to service.

The complete workflow has five steps:

Step 1: Cordon the node with kubectl cordon node-name. This marks it as unschedulable. New Pods won't be placed there, but existing Pods keep running.

Step 2: Check what will be evicted by getting Pods across all namespaces and filtering by node. Use kubectl get pods --all-namespaces -o wide and grep for the node name. This shows what will be affected.

Step 3: Drain the node with kubectl drain node-name. This evicts Pods and prevents new ones. You'll typically need flags.

Step 4: Perform your maintenance work. The node is now safe to work on with no workloads running.

Step 5: Uncordon the node with kubectl uncordon node-name. This makes it schedulable again. Note that Pods don't automatically return - they stay where they were rescheduled.

Common drain flags you must know: ignore-daemonsets is required because DaemonSet Pods can't be evicted normally. They're designed to run on every node. delete-emptydir-data allows deletion of Pods using emptyDir volumes. Without this, drain fails if any Pod has emptyDir. force enables force deletion when Pods are not managed by a controller. Use carefully. grace-period sets the wait time in seconds before force killing Pods.

A typical drain command looks like: kubectl drain node-name --ignore-daemonsets --delete-emptydir-data.

If drain fails, common reasons include Pods not managed by controllers need the force flag, Pods with emptyDir volumes need delete-emptydir-data, and Pods with local storage may need manual intervention.

---

### Section 6: Troubleshooting Node-Related Pod Issues

When Pods won't schedule or are evicted, node issues are often the cause.

When a Pod is Pending, describe the Pod with kubectl describe pod. Look at the Events section for scheduling failures.

Common messages include "0/3 nodes are available: 3 node(s) didn't match node selector" which means your nodeSelector doesn't match any nodes. Check node labels with kubectl get nodes --show-labels.

Another message is "0/3 nodes are available: 1 Insufficient cpu, 2 Insufficient memory" which means no nodes have enough resources. Check node capacity with kubectl describe node and look at Allocated resources.

You might see "0/3 nodes are available: 3 node(s) had taints that the pod didn't tolerate". This means taints are blocking scheduling. Check taints with kubectl describe node and add appropriate tolerations to your Pod.

Another issue is "node(s) were unschedulable" which means nodes are cordoned. Check with kubectl get nodes and look for SchedulingDisabled status.

Debug workflow: First, describe the Pod to see the error message. Second, get nodes to check their status and count. Third, describe nodes to check capacity, conditions, taints. Fourth, check node labels if using nodeSelector with kubectl get nodes -l your-selector. Fifth, check resource requests in your Pod against available capacity. Sixth, fix the issue by adding tolerations, updating nodeSelector, requesting fewer resources, or uncordoning nodes.

---

### Section 7: Common CKAD Scenarios and Practice

Let's walk through practical scenarios you'll encounter in the exam.

Scenario 1: Schedule a Pod on a specific node. Task: Deploy an nginx Pod on the node with label disktype=ssd.

Solution steps: Verify the label exists with kubectl get nodes -l disktype=ssd. Create a Pod YAML with nodeSelector disktype: ssd. Apply and verify it's scheduled to the correct node.

Scenario 2: Drain a node for maintenance. Task: Safely drain a node named worker-1, perform maintenance, then return it to service.

Solution steps: Cordon the node with kubectl cordon worker-1. Check what's running with kubectl get pods --all-namespaces -o wide and grep worker-1. Drain with kubectl drain worker-1 --ignore-daemonsets --delete-emptydir-data. Perform maintenance. Uncordon with kubectl uncordon worker-1.

Scenario 3: Fix Pod that won't schedule due to taint. Task: A Pod is Pending. Investigation shows the node has taint dedicated=gpu:NoSchedule.

Solution steps: Describe the Pod to confirm the taint error. Edit the Pod YAML to add toleration with key dedicated, operator Equal, value gpu, effect NoSchedule. Apply and verify the Pod schedules.

Scenario 4: Deploy to nodes in a specific zone. Task: Create a Deployment with 3 replicas in zone us-west-2a.

Solution steps: Check nodes in that zone with kubectl get nodes -L topology.kubernetes.io/zone. Create Deployment YAML with nodeSelector topology.kubernetes.io/zone: us-west-2a. Apply and verify all Pods are in the target zone.

---

### Section 8: Exam Tips and Strategy

Time management: Node operations should take less than 3 minutes. Don't overthink node selection - if you need a specific node, use nodeSelector. If you need to drain, use the standard flags and move on.

Quick reference commands: For node info, use kubectl get nodes for listing and kubectl describe node for details. For labels, use kubectl label node key=value to add, kubectl label node key=value --overwrite to update, and kubectl label node key- to remove. For taints, use kubectl taint node key=value:effect to add and kubectl taint node key=value:effect- to remove. For maintenance, use kubectl cordon to prevent scheduling, kubectl drain with --ignore-daemonsets --delete-emptydir-data to evict Pods, and kubectl uncordon to enable scheduling.

Memory aids: Cordon before drain - think "cordon off the area before draining the pool". Taints repel, tolerations permit - nodes push away, Pods ask permission. NoSchedule blocks new, NoExecute evicts all - execution is more severe than scheduling.

Common mistakes to avoid: Forgetting --ignore-daemonsets when draining will cause the command to fail. Not checking nodes before troubleshooting Pods wastes time - always verify node state first. Confusing taints and tolerations - taints go on nodes, tolerations go on Pods. Expecting Pods to move back after uncordoning - they don't, they stay where rescheduled. Using nodeSelector without verifying labels exist - always check with kubectl get nodes -l.

Time-saving tips for the exam: Use kubectl get nodes -o wide to see more info in one command. Use kubectl describe node and grep for Taints to quickly find taints. Create Pod with dry-run and save to file, add nodeSelector, then apply. Use kubectl get pods -o wide to verify Pod node placement quickly.

Practice drills: Label a node and deploy a Pod there in under 90 seconds. Drain a node with proper flags in under 60 seconds. Add a toleration to a Pod YAML in under 30 seconds. These should become muscle memory.

Node operations are straightforward points in CKAD. Master the basic commands and workflows, and you'll handle these questions quickly and confidently.

Good luck with your CKAD exam!

---

## Recording Notes

**Key Points:**
- Focus on practical node operations, not cluster setup or architecture
- Emphasize the cordon/drain/uncordon workflow as a complete pattern
- Show the relationship between taints on nodes and tolerations on Pods
- Demonstrate troubleshooting workflow when Pods won't schedule
- Highlight that you need --ignore-daemonsets flag for drain in most cases
- Note that Pods don't automatically return after uncordoning

**Visual Focus:**
- Show node status changes clearly during cordon/drain/uncordon
- Display taint information in describe node output
- Highlight Pod events showing scheduling failures and reasons
- Show before/after Pod distribution when draining nodes
- Display the relationship between nodeSelector in Pods and labels on nodes
- Demonstrate verification steps after each operation
