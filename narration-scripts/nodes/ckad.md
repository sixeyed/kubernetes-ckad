# Nodes - CKAD Narration Script

**Duration:** 25-30 minutes
**Format:** Screen recording with live demonstration
**Prerequisite:** Completed basic Nodes exercises

---

Welcome to the CKAD exam preparation module for Kubernetes Nodes. While you won't manage node infrastructure directly on the exam, understanding nodes is foundational for many troubleshooting scenarios you'll encounter. This session covers the node-related skills and knowledge you need to succeed on the CKAD exam.

The CKAD exam expects you to understand node information and queries, node labels and their uses, node selectors for controlling pod placement, node capacity and resource allocation, troubleshooting pods that won't schedule due to node issues, node conditions and their impact on pods, and basic understanding of taints, tolerations, cordoning, and draining. Let's explore each of these topics in depth.

## CKAD Exam Context

Understanding nodes is fundamental for CKAD even though you won't manage the infrastructure directly. Node knowledge appears most frequently in troubleshooting scenarios. You'll see questions like "Why won't this pod schedule?" where the answer involves checking node capacity, labels, or taints. You need to be able to quickly query node information, understand what the output means, and apply that knowledge to solve problems.

The key skills you need are using kubectl to inspect nodes efficiently, understanding node labels both standard and custom, using node selectors to control pod placement, reading node capacity and resource allocation, diagnosing scheduling failures, and understanding node conditions like Ready, MemoryPressure, and DiskPressure. Your time target should be answering any node query in under thirty seconds. Speed matters on this exam, so these commands need to be reflexive.

## What Are Nodes?

Nodes are the worker machines in your Kubernetes cluster that run your containerized applications. Each node runs several critical components. The kubelet is an agent that manages pods on the node, communicating with the control plane and ensuring containers are running. The container runtime, which could be Docker, containerd, or CRI-O, actually runs the containers. And kube-proxy is the network proxy that handles service networking.

For basic node information, you'll use kubectl get nodes to list all nodes with their status, kubectl describe node followed by the node name for detailed information, kubectl get node with the node name and output yaml to see the complete node specification, and kubectl get nodes with output wide to see additional columns like IP addresses and container runtime. These are your bread-and-butter commands for node inspection.

## Understanding Node Labels

Nodes come with automatic labels that identify their characteristics, and understanding these is crucial for the exam. Standard node labels that every Kubernetes platform provides include kubernetes.io/arch for CPU architecture like amd64 or arm64, kubernetes.io/os for the operating system like linux or windows, kubernetes.io/hostname for the node hostname, topology.kubernetes.io/region and topology.kubernetes.io/zone for cloud location information, and node.kubernetes.io/instance-type for the cloud instance type.

Let me show you how to work with node labels. To see all labels on nodes, you run kubectl get nodes with the dash dash show-labels flag. This shows every label but can be overwhelming. For specific labels, use kubectl get nodes with capital L followed by the label key to show that label as a column. For example, capital L kubernetes.io/arch shows the architecture as its own column in the table output.

You can also add custom labels to nodes. The command is kubectl label node followed by the node name and the label in key equals value format. For example, kubectl label node worker-1 disktype equals ssd adds a custom label. If you need to update an existing label, you must add the dash dash overwrite flag. To remove a label, use kubectl label node followed by the node name and the label key with a trailing dash. To find nodes with a specific label, use kubectl get nodes with dash l and the label selector.

## Node Selectors for Pod Placement

The simplest way to control where pods run is using node selectors in your pod specification. In the pod spec, you add a nodeSelector field with label key-value pairs. The pod will only schedule on nodes that have all the specified labels. This is an AND relationship, meaning the node must match every label you specify.

Let me walk through an example scenario. First, you label a node with something like kubectl label node worker-1 workload equals compute-intensive. Then you create a pod with a nodeSelector specifying that same label. When Kubernetes tries to schedule this pod, it looks for nodes with the workload equals compute-intensive label. Only nodes with that exact label are candidates for running this pod.

What happens if you specify a nodeSelector that doesn't match any node? The pod stays in the Pending state indefinitely. When you describe the pod, you'll see events saying something like "zero out of X nodes are available: X node(s) didn't match Pod's node affinity/selector". This is a common troubleshooting scenario on the exam. When you see a pending pod, always check if it has a nodeSelector and whether any nodes match that selector.

## Exercise 1: Node Selectors

Let's work through a complete exercise with node selectors. The task is to deploy a pod to a specific type of node using labels, then see what happens when we use a non-existent label. Start by getting the list of nodes with kubectl get nodes. Pick one node and label it with kubectl label node followed by your node name and workload equals compute-intensive. Verify the label is applied with kubectl get nodes with capital L workload, which shows the workload label as a column.

Now create a pod with a node selector. You can use kubectl run or create a YAML specification. The key part is adding nodeSelector under spec with workload colon compute-intensive. After you apply this pod, check where it was scheduled with kubectl get pod followed by the pod name and output wide. The NODE column should show your labeled node. You can also describe the pod and look at the Node-Selectors section to confirm it matches.

Next, try creating a pod with a nodeSelector that references a non-existent label, something like workload equals non-existent-type. Apply this pod and check its status. It shows Pending. When you describe it, the events show "zero out of X nodes are available" with the reason that no nodes matched the pod's node selector. This is the key learning point: pods with node selectors that don't match any node will remain pending forever. You must either create a node with the required label or modify the pod's nodeSelector to match existing nodes.

## Node Capacity and Resource Allocation

Every node has finite CPU and memory, and understanding capacity is crucial for troubleshooting why pods won't schedule. When you describe a node, you see three important sections. Capacity shows the total resources the node has. Allocatable shows what's available for pods after system reserves are subtracted. Some resources are reserved for system components like kubelet and the container runtime. Then Allocated resources shows what pods are currently requesting, displayed as both absolute values and percentages.

For example, you might see capacity of four CPU cores and 16 gigabytes of memory, allocatable of four CPU and 15.5 gigabytes because system components need some memory, and allocated resources showing that pods are requesting 1000 millicores which is 25 percent of CPU and 2 gigabytes which is 13 percent of memory. This tells you the node has plenty of capacity available.

Nodes can experience resource pressure when resources are low. MemoryPressure means the node is low on memory. DiskPressure means the node is low on disk space. PIDPressure means too many processes are running. You check node conditions with kubectl describe node followed by the node name and piping to grep Conditions. The output shows each condition type, whether it's True or False, and the reason. For a healthy node, you want to see MemoryPressure False, DiskPressure False, PIDPressure False, and Ready True.

## Exercise 2: Troubleshoot Node Resource Issues

Let's troubleshoot a scenario where a pod won't schedule due to insufficient resources. Create a pod with huge resource requests, something like 100 gigabytes of memory and 50 CPU cores, which no node can satisfy. After you apply this pod, check its status with kubectl get pod, and it shows Pending. Describe the pod and look at the events. You'll see something like "zero out of 3 nodes are available: 3 Insufficient cpu, 3 Insufficient memory". This tells you exactly why the pod can't schedule.

To verify this, check the node capacity with kubectl describe nodes and look at the Allocatable section. Compare the pod's resource requests against what the node can provide. The pod is asking for more than any node has available. The fix is to reduce the pod's resource requests to something reasonable. Create a new pod requesting 100 megabytes of memory and 100 millicores of CPU. This pod schedules successfully because the requests fit within node capacity.

The key learning here is always check pod resource requests against node allocatable resources when troubleshooting scheduling issues. The describe output for both the pod and the nodes will tell you exactly what's happening.

## Node Conditions and Status

Nodes report various conditions that affect scheduling. The Ready condition means the node is healthy and ready to accept pods. When Ready is True, pods can schedule. MemoryPressure means the node is low on memory, and new pods may not schedule. DiskPressure means the node is low on disk, again preventing new pods. PIDPressure indicates too many processes, which also blocks scheduling. NetworkUnavailable means the network isn't configured properly, so pods won't have network access.

For a quick health check, run kubectl get nodes and look at the STATUS column. It should show Ready for all nodes. For detailed conditions, use kubectl describe node and look at the Conditions section. You can also extract just the Ready condition with JSONPath using kubectl get nodes with output jsonpath and a query for the Ready condition.

When a node shows NotReady, it has serious implications. First, check the node conditions with kubectl describe to understand why. Common causes include kubelet not running, network issues, insufficient resources, or the node being shut down. For pods on NotReady nodes, existing pods continue running if the node comes back online, but after about five minutes Kubernetes starts evicting them. New pods definitely won't schedule to NotReady nodes.

## Taints and Tolerations (Brief Overview)

Taints prevent pods from scheduling on nodes unless the pods have matching tolerations. This is the opposite of node selectors, which are an opt-in mechanism. Taints are opt-out, meaning by default pods can't schedule on tainted nodes. To add a taint, you use kubectl taint nodes followed by the node name, the key equals value, and the effect like NoSchedule. To view taints, describe the node and look at the Taints field. To remove a taint, use the same command but with a trailing dash after the effect.

There are three taint effects. NoSchedule means pods won't schedule unless they tolerate the taint. PreferNoSchedule is a soft preference, meaning Kubernetes avoids the node if possible but will use it if necessary. NoExecute is the strictest, evicting existing pods that don't tolerate the taint.

For pods to schedule on tainted nodes, they need tolerations in their spec. The tolerations field is an array where each entry specifies the key, operator, value, and effect to tolerate. The operator can be Equal to match a specific value or Exists to match any value for that key. The key and effect must match the node's taint. For comprehensive coverage of taints and tolerations, refer to the clusters lab, and for advanced pod placement including affinity and anti-affinity, see the affinity lab.

## Exercise 3: Working with Taints

Let's practice with taints and tolerations. Taint a node with kubectl taint nodes followed by your node name, dedicated equals special-workload with the NoSchedule effect. Verify it with kubectl describe node and grep for Taints. Now try creating a pod without any toleration using kubectl run no-toleration dash dash image equals nginx. Check where it schedules with kubectl get pod and output wide. If you have multiple nodes, it schedules on an untainted node. If this is your only node, it stays Pending.

Describe the pod to see why. The events show "zero out of X nodes are available: 1 node(s) had taints that the pod didn't tolerate". Now create a pod with a toleration. In the pod spec, add a tolerations array with an entry matching your taint's key, value, and effect. When you apply this pod and check its status, it successfully schedules on the tainted node. The toleration allows it to ignore the taint.

The key learning is that taints and tolerations work together. Taints repel pods by default, and tolerations allow specific pods through. This is useful for dedicating nodes to specific workloads or keeping system components separate from user applications.

## Draining and Cordoning Nodes

For node maintenance, you need to safely remove workloads. Cordoning marks a node as unschedulable but leaves existing pods running. The command is kubectl cordon followed by the node name. When you run kubectl get nodes, cordoned nodes show SchedulingDisabled. To allow scheduling again, use kubectl uncordon.

Draining goes further by evicting existing pods from the node. The command is kubectl drain followed by the node name. You'll typically add the dash dash ignore-daemonsets flag because DaemonSet pods are managed at the cluster level and can't be deleted from individual nodes. You might also need dash dash delete-emptydir-data to confirm deletion of emptyDir volumes, and dash dash force for pods not managed by ReplicationControllers, ReplicaSets, Jobs, DaemonSets, or StatefulSets.

After draining, the node is cordoned automatically, so no new pods schedule. Existing pods are gracefully terminated and rescheduled on other nodes. After you complete maintenance, run kubectl uncordon to make the node schedulable again. You might see CKAD scenarios like "Move all pods from node-1 to node-2" which requires draining node-1 and ensuring node-2 can accept the workloads.

## Exercise 4: Cordon and Drain

Let's walk through a complete cordon and drain workflow. Start by creating a deployment with kubectl create deployment test-app with the nginx image and three replicas. Check which nodes the pods are on with kubectl get pods output wide. Now cordon one of your nodes with kubectl cordon followed by the node name. Verify it with kubectl get nodes, which shows SchedulingDisabled.

Scale up the deployment to six replicas with kubectl scale deployment. Watch where the new pods go with kubectl get pods output wide. The new pods only schedule on uncordoned nodes. Pods on the cordoned node still run, but it won't accept new ones. Now drain the node with kubectl drain, the node name, and dash dash ignore-daemonsets dash dash force. Watch the pods with kubectl get pods output wide and you'll see pods on the drained node terminate and new pods appear on other nodes.

After your maintenance is complete, uncordon the node with kubectl uncordon followed by the node name. Verify it's schedulable again with kubectl get nodes. The key learning is cordon prevents new pods while drain evicts existing ones. Always uncordon after maintenance so the node returns to service.

## Common CKAD Troubleshooting Scenarios

Let's work through common scenarios you'll encounter on the exam. Scenario one is a pod stuck in Pending. The symptom is the pod status shows Pending indefinitely. To diagnose, run kubectl describe pod and examine the events. Common causes include insufficient resources where the node doesn't have enough CPU or memory, no matching node selector where labels don't match any node, node taints that the pod doesn't tolerate, or all nodes being unschedulable because they're cordoned.

For solutions, check node resources with kubectl describe nodes and look at Allocated resources. Check the pod's node selectors with kubectl get pod output yaml and grep for nodeSelector. Check for taints with kubectl describe nodes and grep for Taints. Check if nodes are ready with kubectl get nodes and look for the Ready status.

Scenario two is a node showing NotReady status. Diagnose this with kubectl describe node. Common causes include kubelet being stopped, network connectivity issues, disk being full, or memory exhausted. The impact is pods won't schedule to NotReady nodes, and after about five minutes, existing pods are evicted and rescheduled elsewhere.

Scenario three is pods evicted from a node. The symptom is pods showing Evicted status. Describe the pod to see the reason. Common reasons include node pressure from memory, disk, or PID limits, node drain operations, or the node being NotReady for an extended period. Check node conditions with kubectl describe node and look at the Conditions section to see if there's MemoryPressure, DiskPressure, or other issues.

## Quick Command Reference

Let me summarize the essential commands you need for the exam. For node information, use kubectl get nodes to list them, kubectl get nodes output wide for more details, kubectl describe node followed by the name for complete information, and kubectl top nodes for resource usage if metrics-server is available.

For node labels, use kubectl get nodes dash dash show-labels to see all labels, kubectl get nodes capital L followed by label-key to show specific labels as columns, kubectl label node followed by the name and key equals value to add a label, and kubectl label node followed by the name and key with a trailing dash to remove a label.

For node selection, use kubectl get nodes with dash l and a selector to filter by label, and kubectl get pods with dash dash field-selector spec.nodeName equals node-name to see pods on a specific node.

For node management, use kubectl cordon to make a node unschedulable, kubectl uncordon to make it schedulable, and kubectl drain with dash dash ignore-daemonsets to evict pods for maintenance.

For checking capacity, use kubectl describe node and grep for Capacity, Allocatable, or Allocated resources to see what resources are available and in use.

For node conditions, use kubectl describe node and grep for Conditions to see health status, or use JSONPath to extract the Ready condition specifically.

## Exam Tips

Here are strategies to maximize your speed on the exam. Know the core node commands: get, describe, label, cordon, uncordon, and drain. When a pod is Pending, immediately check if nodes have available resources with kubectl describe nodes. Verify node selectors match node labels by checking both the pod spec and node labels. Check taints which can prevent scheduling even when resources are available. Use output wide to quickly see which node each pod is running on. Check node Ready status because NotReady nodes won't accept new pods.

Remember the difference between drain and cordon. Cordon prevents new pods but leaves existing ones. Drain evicts existing pods and also cordons the node. Always use dash dash ignore-daemonsets when draining because DaemonSet pods can't be drained. Check events in the describe output because scheduling failures are clearly explained there. Practice JSONPath queries for quickly extracting specific node fields without parsing large outputs.

Common mistakes to avoid include forgetting to uncordon after maintenance, which leaves the node unschedulable permanently. Not using dash dash ignore-daemonsets when draining, which causes the drain command to fail. Confusing node selector with node affinity, where node selector is simpler with just key-value matches. Not checking node capacity when pods won't schedule, missing the obvious resource constraint. Assuming tainted nodes are broken when they're intentionally restricted for specific workloads. Forgetting that NotReady pods are evicted after about five minutes. Not understanding the difference between Capacity and Allocatable resources. Labeling pods instead of nodes for nodeSelector, which doesn't work because nodeSelector matches node labels. Using absolute node names instead of checking what nodes exist in your cluster. And not reading describe output carefully where scheduling events provide clear explanations.

Your practice drill should include listing nodes in under five seconds, finding CPU capacity in under fifteen seconds, checking node labels in under ten seconds, labeling a node in under ten seconds, and finding nodes with a specific label in under fifteen seconds. You should be able to complete all these operations in under sixty seconds total.

## Study Checklist

Make sure you can list and describe nodes quickly, show node labels, add and remove custom labels from nodes, create pods with nodeSelector, understand node capacity versus allocatable resources, check node conditions like Ready and MemoryPressure, diagnose why pods won't schedule, use kubectl get pods output wide to see node placement, cordon and uncordon nodes, drain nodes for maintenance, understand node taints and pod tolerations, check resource allocation on nodes, troubleshoot Pending pods efficiently, and use JSONPath to query node information.

## Practice Exercises

Here are exercises you should complete until they're automatic. Label a node with kubectl label node followed by the node name and env equals production. Create a pod with a node selector by running kubectl run web with dash dash image equals nginx and dash dash dry-run equals client with output yaml redirected to a file. Edit the YAML to add nodeSelector under spec with env colon production, then apply it. Check node capacity with kubectl describe nodes and grep for Allocatable. Cordon a node with kubectl cordon, verify it shows SchedulingDisabled in kubectl get nodes, drain the node with kubectl drain and the required flags, then uncordon it with kubectl uncordon. Time yourself on these operations and aim to reduce the time with each repetition.

## Next Steps

After mastering nodes for CKAD, you should study affinity for advanced pod placement including node affinity and pod affinity and anti-affinity rules. Review clusters for in-depth coverage of taints, tolerations, and multi-node scenarios. Practice troubleshooting for diagnosing complex scheduling issues that combine multiple constraints. And learn productionizing for resource limits, requests, quality of service classes, and how they interact with node capacity.

## Summary

Nodes are the foundation of your Kubernetes cluster, and understanding them is essential for CKAD success. You need to master querying node information and labels, using nodeSelector for pod placement, understanding node capacity and resource allocation, troubleshooting pods that won't schedule, checking node conditions and health status, and cordoning and draining nodes for maintenance.

The exam relevance is high because node understanding is foundational. Many troubleshooting questions involve node capacity, labels, taints, or scheduling constraints. You should be able to handle node-related tasks in three to five minutes per question. The difficulty level is easy to medium, mostly requiring command knowledge and understanding of the outputs. Practice node commands until they're automatic because they're fundamental to many CKAD tasks. With the skills from this module, you'll be well-prepared for node-related scenarios on the CKAD exam!
