# Affinity - CKAD Narration Script

**Duration:** 25-30 minutes
**Format:** CKAD exam preparation focus

---

Welcome to CKAD exam preparation for Pod scheduling and affinity. While affinity is marked as advanced and beyond core CKAD requirements, understanding these concepts will help you deploy high-availability applications and optimize performance in real-world scenarios.

## Node Affinity Basics

Let's start with node affinity basics. Node affinity allows you to constrain which nodes your Pods can be scheduled on based on node labels. There are two key concepts you need to understand. Required affinity is a hard constraint, meaning the Pod won't schedule if the requirement is not met. Preferred affinity is a soft preference, meaning the Pod schedules anyway if the preference can't be met, but the scheduler will try to honor it.

The full name for required affinity is requiredDuringSchedulingIgnoredDuringExecution, which tells you exactly how it works. The required part means it must be satisfied for the Pod to schedule. The IgnoredDuringExecution part means running Pods won't be evicted if the rules change later.

Let me show you a required node affinity example. The Pod must run on nodes with label disktype equals ssd. The structure follows a specific nesting pattern: affinity, then nodeAffinity, then requiredDuringSchedulingIgnoredDuringExecution, then nodeSelectorTerms, and finally matchExpressions. Each match expression has three parts: a key for the label name, an operator that defines how to match, and values to match against.

The operators are critical for CKAD, so let's review them. In means the label value must be in the provided list. NotIn means the label value must not be in the list. Exists means the label key must exist, and the value doesn't matter. DoesNotExist means the label key must not exist. Gt means greater than for numeric comparison. Lt means less than for numeric comparison.

Now let's look at preferred node affinity. This is a soft preference with a weight from 1 to 100. Higher weight means higher priority. When you have multiple preferred terms, the scheduler calculates scores for each node based on how well it matches all preferences, then picks the node with the highest total score.

You can combine required and preferred affinity, which is the most common pattern in production. Use required for must-haves like running on Linux nodes. Use preferred for nice-to-haves like nodes with SSD storage. This gives you both hard constraints and soft preferences in the same Pod spec.

Let me explain match expression logic, which can be confusing. Multiple expressions within a single nodeSelectorTerm use AND logic, meaning the node must match all of them. For example, a node must have disktype equals ssd AND zone in us-west-1a or us-west-1b. Multiple nodeSelectorTerms use OR logic, meaning any one term can match. For example, disktype equals ssd AND zone equals zone-a, OR disktype equals hdd AND zone equals zone-b. Understanding AND/OR logic is critical for complex affinity rules in the exam.

## Standard Node Labels

Kubernetes automatically adds standard labels to all nodes, and these are crucial for affinity rules. You can check node labels with kubectl get nodes show-labels to see all the labels applied. Common standard labels include kubernetes.io/arch for CPU architecture like amd64, kubernetes.io/os for operating system like linux, kubernetes.io/hostname for node hostname, topology.kubernetes.io/region for cloud region, topology.kubernetes.io/zone for availability zone, node-role.kubernetes.io/control-plane for control plane nodes, and node.kubernetes.io/instance-type for instance type in cloud environments. You should use these labels for common affinity scenarios rather than creating custom labels.

Here's a common pattern for avoiding control plane nodes. Use nodeAffinity with requiredDuringScheduling, nodeSelectorTerms, matchExpressions, with key node-role.kubernetes.io/control-plane and operator DoesNotExist. This ensures your workload Pods only run on worker nodes.

To target a specific region and zone, you use matchExpressions for both region and zone labels with the In operator and your desired values. This is common for geo-distributed applications where you want to ensure Pods run in specific locations.

## Pod Affinity and Anti-Affinity

Pod affinity basics involve scheduling Pods near other Pods for co-location. Here's an example where a Pod must run on a node where Pods with label app equals cache are running. The topologyKey kubernetes.io/hostname means same node, so the Pod will be scheduled on the exact same node as the cache Pods.

Pod anti-affinity basics involve scheduling Pods away from other Pods for spreading. An example would be ensuring this Pod doesn't schedule on nodes where Pods with label app equals web are running. This ensures each web Pod runs on a different node for high availability.

Topology keys define the scope of affinity, and understanding them is critical. Common topology keys include kubernetes.io/hostname for same node, which means co-locate on the exact same host. topology.kubernetes.io/zone means same zone, keeping Pods within the same availability zone. topology.kubernetes.io/region means same region, keeping Pods within the same cloud region.

For CKAD, the pattern is to use hostname for strict co-location or anti-co-location where you want Pods on the same or different nodes. Use zone for availability zone spreading to improve availability. Use region for regional grouping when you want to keep traffic within a region.

Preferred pod affinity gives you soft preferences with weights, similar to node affinity. This says prefer to run near Pods with app equals cache, but it's okay if we can't. The weight determines how strongly the scheduler tries to honor the preference.

## Common Affinity Patterns

Let me walk through common patterns you'll see in the exam. Pattern one is High Availability, spreading across zones. Ensure pods run in different availability zones using podAntiAffinity with preferredDuringScheduling. The labelSelector matches the app label, and topologyKey is topology.kubernetes.io/zone. This is essential for multi-zone deployments for high availability.

Pattern two is co-locating app with cache. Run application pods near cache pods for performance using podAffinity with requiredDuringScheduling, labelSelector matching app equals redis-cache, and topologyKey kubernetes.io/hostname. This ensures low latency between the app and cache.

Pattern three is spreading replicas across nodes. Ensure no two replicas run on same node using podAntiAffinity with requiredDuringScheduling, labelSelector matching the app label, and topologyKey hostname. Warning: with required anti-affinity, pods may stay pending if there aren't enough nodes to satisfy the constraint.

Pattern four is regional affinity with zone spreading. Stay in one region but spread across zones by using nodeAffinity to require the us-west region, and podAntiAffinity with preferred scheduling to spread across zones within that region. This demonstrates combining node and pod affinity for complex requirements.

Pattern five is avoiding noisy neighbors. Keep your app away from resource-intensive apps using podAntiAffinity with required scheduling. The labelSelector matches workload-type in batch or ml-training, and topologyKey is hostname. This ensures your latency-sensitive app doesn't share nodes with batch workloads.

## Troubleshooting Affinity Issues

Now let's focus on troubleshooting, which is critical for the exam. Issue one is Pods stuck in Pending. First, check pod status with kubectl get pod. Describe the pod and look for scheduling failures in events. Look for messages like zero of three nodes are available, three nodes didn't match Pod's node affinity selector.

Common causes include no nodes matching required affinity. Check node labels to verify they exist. If no nodes have the required labels, either add the label to a node or change the affinity rule. Anti-affinity might be preventing scheduling. Check how many replicas are running and if they're on all available nodes. If you have 5 replicas, 3 nodes, and required anti-affinity, 2 pods will stay pending because there aren't enough nodes.

Solutions include adding the required label to a node with kubectl label, changing required to preferred by editing the deployment YAML, or removing affinity rules temporarily to get things working while you debug.

Issue two is uneven Pod distribution where all pods are on one node despite spread preferences. The cause is usually using preferred not required anti-affinity. The solution is to change from preferred to required for strict spreading, though remember this might leave Pods pending if you don't have enough nodes.

Issue three is Pods not co-locating when they should be together but are on different nodes. Debug by checking if target pods exist, which nodes they're on with wide output, and the affinity rules with kubectl get pod yaml and grep. Common mistakes include wrong label selector, wrong topology key, or target pods don't exist yet when the affinity rule is evaluated.

Issue four is node affinity not working. Verify the node has the required label. Check the exact label value because it's case-sensitive. Common issues include label value mismatch, using the wrong operator like In versus Exists, or a label key typo.

## Common CKAD Exam Scenarios

Let's walk through common exam scenarios. Scenario one is scheduling on specific node type. The question might be create a deployment web with 3 replicas that only runs on nodes with label node-type equals compute. Quick imperative approach is to generate base deployment with dry-run, then edit to add nodeAffinity with required scheduling, nodeSelectorTerms, matchExpressions for key node-type, operator In, values compute.

Scenario two is spread across zones. Configure deployment api so replicas prefer to run in different availability zones. Add podAntiAffinity with preferred scheduling, weight 100, podAffinityTerm with labelSelector matching app=api, topologyKey topology.kubernetes.io/zone.

Scenario three is co-locate Pods. Run pod worker on the same node as pods with label app equals database. Use podAffinity with required scheduling, labelSelector matching app=database, topologyKey kubernetes.io/hostname.

Scenario four is avoid control plane. Ensure deployment app never runs on control plane nodes. Use nodeAffinity with required scheduling, nodeSelectorTerms, matchExpressions, key node-role.kubernetes.io/control-plane, operator DoesNotExist.

Scenario five is debug pending pod. A pod is stuck in Pending state, debug and fix the affinity issue. Check status with describe pod, look for scheduling errors in events, check node labels with show-labels, then fix by either adding required label to node, modifying affinity rule, or changing required to preferred.

## Quick Command Reference and Exam Tips

Let me show you essential kubectl commands for working with affinity in the exam. Check node labels by showing all with kubectl get nodes show-labels. Show specific labels as columns with -L flag. Show nodes with specific label with -l selector.

Add or remove node labels by adding with kubectl label node. Remove by adding minus suffix. Update existing label with overwrite flag.

Check pod placement to see which node each pod is on with wide output. Show pods on specific node with field-selector. Check pod affinity rules with yaml output and grep.

Generate YAML template by creating deployment and outputting YAML with dry-run, then edit to add affinity rules.

For debugging, check why pod isn't scheduling with describe and grep Events. Get pod scheduling info from events sorted by timestamp. Check node capacity with describe node. Count pods per node with custom formatting.

For exam tips, speed tip one is to use imperative commands to generate base YAML with dry-run. Speed tip two is to use kubectl explain for syntax like explain pod.spec.affinity or explain pod.spec.affinity.nodeAffinity. Speed tip three is to copy-paste affinity blocks from existing resources to save time.

Common mistakes to avoid include forgetting the nodeSelectorTerms wrapper, as matchExpressions must be inside nodeSelectorTerms. Don't use matchLabels with In operator, it's redundant - use matchLabels for single values. Watch out for wrong topology key - use kubernetes.io/hostname for same node, not zone. Remember case sensitivity in labels, diskType is not the same as disktype. Beware of required anti-affinity with too many replicas - if you have 5 replicas and 3 nodes with required anti-affinity, 2 pods will stay pending.

Time-saving patterns include quickly labeling a node with overwrite, quickly checking if a pod can schedule with describe and tail, generating and editing in one command with pipe, and finding nodes with label using name output.

## Practice Exercises and Exam Strategy

Let's review practice exercises from the CKAD material. Exercise one is basic node affinity. Create a deployment that must run on Linux nodes, prefers nodes with disktype=ssd label, and has 3 replicas. The approach is to generate base deployment, edit to add nodeAffinity with required for Linux and preferred for SSD with weights.

Exercise two is pod anti-affinity for HA. Create a deployment that runs 5 replicas where each replica must run on a different node. If fewer than 5 nodes, some pods should stay pending. Use required anti-affinity with topologyKey hostname.

Exercise three is co-locate with cache. Given a redis cache deployment with label app=cache, create an application deployment that runs on the same nodes as redis pods with 3 replicas. Use podAffinity with required scheduling and topologyKey hostname.

Exercise four is zone spreading. Create a deployment that must stay in region us-west, prefers spreading across zones, and has 6 replicas. Use nodeAffinity for region and podAntiAffinity preferred for zone spreading.

Exercise five is troubleshoot pending pods. Given a broken deployment with pods in pending state, identify why pods aren't scheduling, fix the affinity rules, and verify pods start running. Debug with describe pod, check node labels, fix by adding labels or changing affinity.

For exam strategy, prefer simpler mechanisms. If the question can be solved with nodeSelector, use it instead of node affinity. Use kubectl explain for syntax help when you need it. Generate and modify by starting with imperative commands, save to YAML with dry-run, then edit to add affinity.

Time management is critical. Read carefully to understand if the question is asking you to create or debug. For creation, use the simplest mechanism that works. For debugging, describe pod, check events, look at labels. Don't spend more than 5 minutes on any single question.

Practice these patterns until they're second nature. The exam is time-pressured, so muscle memory with these commands is crucial. Good luck with your CKAD exam preparation!
