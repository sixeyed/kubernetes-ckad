# StatefulSets - CKAD Narration Script

**Duration:** 25-30 minutes
**Format:** Screen recording with live demonstration
**Prerequisite:** Completed basic StatefulSets exercises

---

Welcome to the CKAD exam preparation module for Kubernetes StatefulSets. This session covers the advanced StatefulSet topics required for the Certified Kubernetes Application Developer exam, building on what we learned in the exercises lab.

While StatefulSets are considered supplementary material for CKAD, they do appear on the exam, and understanding them demonstrates comprehensive Kubernetes knowledge. You might encounter one or two questions involving StatefulSets, often combined with topics like persistent storage, init containers, multi-container patterns, or service networking. Because StatefulSet questions take longer to complete due to sequential Pod creation, efficiency and preparation are critical.

Let's dive into the CKAD-specific aspects of StatefulSets, focusing on exam strategies, common patterns, and time-saving techniques.

## CKAD Exam Relevance

StatefulSets fall under the Application Deployment domain, which represents twenty percent of the CKAD exam. The exam tests your understanding of Deployments and rolling updates, ConfigMaps and Secrets for application configuration, multi-container Pod design patterns including sidecars and init containers, and how to use PersistentVolumeClaims for storage. StatefulSets often appear in scenarios requiring stable network identities, ordered deployment and scaling, persistent storage per Pod, or applications like databases and message queues that need these features.

On the CKAD exam, you have approximately two hours for fifteen to twenty questions. That's six to eight minutes per question. StatefulSet questions take longer because Pods are created sequentially, so you need to be efficient. You can't just sit and watch Pods starting one by one. You need to kick off the creation, verify the first Pod starts correctly, then move on to other questions and come back later to verify completion.

## Quick Reference

Let me walk you through the essential kubectl commands you must know by heart for the exam. For creating and managing StatefulSets, you'll use kubectl apply with YAML files since there's no imperative command to create a StatefulSet from scratch. You'll use kubectl get statefulsets, which can be shortened to kubectl get sts because every second counts on the exam. You'll describe StatefulSets for troubleshooting, scale them with kubectl scale, and delete them with kubectl delete.

For monitoring StatefulSet operations, you'll watch Pods being created with kubectl get pods with a label selector and the watch flag to see the ordered creation in real time. You'll check rollout status with kubectl rollout status, view history with kubectl rollout history, and access specific Pods with kubectl exec using the predictable Pod names.

Understanding the differences between StatefulSets and Deployments is crucial for the exam. The exam may test whether you know when to use each controller. StatefulSet indicators include requirements for stable network identity, ordered deployment, persistent storage per replica, primary-secondary architecture, or mentions of databases and message queues. Deployment indicators include stateless applications, web servers, API services, fast scaling requirements, or no mention of per-Pod storage.

Here's a memory aid: if the question mentions specific Pod names or DNS names for individual Pods, it's likely a StatefulSet scenario. The question will often explicitly state to create a StatefulSet, so you won't always need to choose, but understanding the difference helps with troubleshooting questions.

## CKAD Scenarios

Let's work through several realistic exam scenarios with time targets. These scenarios reflect the types of questions you'll encounter on the actual exam.

### Scenario 1: Create Basic StatefulSet with Headless Service

Your first scenario has a time target of five to six minutes. The exam question might read something like: create a StatefulSet named web with three replicas running nginx:alpine, each Pod should expose port 80, create the necessary Service to enable stable network identities for each Pod, and verify that you can resolve individual Pod DNS names. The namespace is default, you must use imperative commands where possible, and you must verify the solution works.

Start by creating the headless Service, which is mandatory for StatefulSets. You must create this first using kubectl apply with a heredoc or a YAML file. The critical points are that clusterIP must be set to None to make it headless, which is easily forgotten. The Service name will be referenced in the StatefulSet, and the selector must match Pod labels.

Next, create the StatefulSet. The serviceName field must match the Service name, the selector must match the Pod template labels, and you need to explicitly set replicas to three since the default would be one. After creating the StatefulSet, verify Pod creation by watching the Pods. Don't just run kubectl get pods once; use kubectl get pods with the watch flag and wait for confirmation. Points are often lost for incomplete solutions.

Finally, verify DNS resolution works by deploying a temporary test Pod and running nslookup against a specific Pod's DNS name. This should return the IP of that Pod. If it works, your solution is complete. This entire scenario should take five to six minutes. If you're over seven minutes, you need more practice.

Common mistakes to avoid include forgetting clusterIP: None, mismatched names between the serviceName field and actual Service name, label selector mismatches where Service, StatefulSet, and Pod labels don't align, and not waiting for Pods to be Ready before moving to the next question. Your success criteria are three Pods with predictable names in Running status and working DNS resolution.

### Scenario 2: StatefulSet with PersistentVolumeClaims

This scenario has a time target of six to seven minutes. The exam question might read: create a StatefulSet named data-app with three replicas using nginx:alpine, each Pod should have its own PersistentVolumeClaim requesting 100Mi of storage mounted at /usr/share/nginx/html, and create the necessary headless Service. The key challenge is that the volumeClaimTemplates syntax is complex and easy to get wrong under pressure.

Start by creating the headless Service quickly. Then create the StatefulSet with volumeClaimTemplates. This is the most time-consuming part, so take care with the indentation. The volumeClaimTemplates field is at the same indentation level as template, not inside it. The name in volumeClaimTemplates must match the name in the container's volumeMounts. accessModes is an array, so note the square brackets. Storage size uses the format like 100Mi.

Common syntax errors include wrong indentation since YAML is sensitive, forgetting the array brackets for accessModes, and typos in volumeClaimTemplates where it's templates plural, not template singular.

After applying the YAML, verify PVCs were created. You should see three PVCs with names following the pattern: volume-name-statefulset-name-ordinal. Wait for all PVCs to reach Bound status. Then verify Pods and mounts by describing a Pod and checking the volume mount configuration. This scenario should take six to seven minutes maximum. The volumeClaimTemplates section is where most time is spent.

If PVCs don't bind, common causes include no default StorageClass being available, insufficient storage capacity in the cluster, or access modes not supported by the StorageClass. If PVCs are stuck in Pending for more than thirty seconds, check the events with kubectl describe pvc. Don't waste time waiting; investigate and fix the issue.

### Scenario 3: Accessing Individual Pods via DNS

This scenario has a time target of four to five minutes. The exam question might read: you have a StatefulSet named database running in the default namespace, verify that each Pod can be accessed individually using DNS names, and document the DNS name pattern.

Start by identifying the Service name associated with the StatefulSet using kubectl get statefulset with output showing the serviceName field. Then deploy a test Pod like busybox with the run command and the interactive flag. From inside the test Pod, test DNS resolution by running nslookup against both the Service name, which should return all Pod IPs, and specific Pod DNS names, which should return individual Pod IPs.

Finally, document the pattern. The DNS format is pod-name.service-name.namespace.svc.cluster.local. The exam might ask you to write this in a text file, so be prepared to use kubectl exec with echo to redirect output to a file.

You should also know the shorthand forms that work within the same namespace. The full form works everywhere, but the short form pod-name.service-name works within the same namespace. This knowledge is essential for questions about connecting one Pod to a specific StatefulSet Pod.

### Scenario 4: Parallel Pod Management

This scenario has a time target of four to five minutes. The exam question might read: create a StatefulSet named cache with five replicas using nginx:alpine, the Pods should be created simultaneously not sequentially, and verify that all Pods start at the same time.

The key concept is using podManagementPolicy set to Parallel for faster startup. Create the headless Service first, then create the StatefulSet with the podManagementPolicy field set to Parallel. This tells Kubernetes to create all Pods simultaneously instead of waiting for each to be Ready.

Watch the Pods as they're created. All five Pods should appear and enter ContainerCreating or Running status at approximately the same time, not sequentially. The question might ask you to confirm the behavior by checking Pod creation timestamps. All timestamps should be within a few seconds of each other.

Understanding when to use Parallel versus OrderedReady is important. Use OrderedReady, which is the default, when Pods depend on previous Pods being ready, in database primary-replica setups, or for leader election scenarios. Use Parallel when Pods are independent, faster startup is beneficial, or you still need stable names but not ordered startup. If the question says Pods should start simultaneously or mentions fastest possible startup, use podManagementPolicy: Parallel.

### Scenario 5: Scaling and PVC Retention

This scenario has a time target of five to six minutes. The exam question might read: a StatefulSet named app is running with three replicas, each with a PVC, scale it down to one replica, then back up to three replicas, and verify that the data in the PVCs is preserved.

Assuming the StatefulSet already exists, start by writing test data to one of the Pods using kubectl exec. Then scale down the StatefulSet to one replica. Observe that Pods are removed in reverse order, highest ordinal first. Verify PVCs still exist even though only one Pod is running. This is the critical observation: all three PVCs remain even though two Pods are gone. This is StatefulSet's safety mechanism.

Scale back up to three replicas and observe that the removed Pods are recreated in order. Finally, verify data persistence by checking the file you created earlier. It should still contain the original data because the Pod reattached to its original PVC.

The key exam point is that when you delete a StatefulSet, PVCs are not deleted. To clean up completely, you must delete PVCs explicitly. You might be asked to clean up all resources, so remember to delete PVCs separately using label selectors.

## Advanced CKAD Topics

Let's explore advanced topics that occasionally appear in CKAD scenarios, particularly around update strategies and init containers.

### OnDelete Update Strategy

The OnDelete update strategy is useful when you need manual control over when Pods are updated. Imagine updating a PostgreSQL cluster where you need to update the first replica, run and verify schema migration, check replication lag, and only then proceed to the next instance. With OnDelete strategy, Pods only update when manually deleted.

Deploy a PostgreSQL cluster with OnDelete strategy in the updateStrategy section. Update the StatefulSet image, and notice nothing happens. Pods stay on the old version because OnDelete requires manual intervention. The manual update process involves deleting a Pod, waiting for it to recreate with the new version, verifying the updated Pod with queries, running any necessary migrations, verifying data integrity, and then proceeding to the next Pod.

This strategy is useful for database clusters requiring manual schema migration per instance, stateful services where you need to verify each instance before proceeding, blue-green deployments at the Pod level, manual coordination with external systems or monitoring, or zero-downtime requirements with custom validation steps.

### Partition Updates

Partition updates enable canary deployments for stateful applications. Imagine deploying a new API version but testing it on forty percent of instances before full rollout. With partition updates, you can update only Pods with ordinal numbers greater than or equal to the partition value.

Deploy an initial version with five replicas all running version one. Update the StatefulSet with a partition value set to three, which means only Pods with ordinal three and higher will update. Watch as only Pods three and four update while Pods zero, one, and two remain on the old version. This protects critical Pods like the primary or leader while testing the new version on higher-ordinal Pods.

You can expand the canary by lowering the partition value to two, which updates Pod two as well. For a full rollout, set partition to zero, which updates all remaining Pods. This strategy is useful for canary deployments of stateful applications, gradual rollouts with validation at each stage, A/B testing different versions in production, risk mitigation by keeping critical Pods on stable versions, or performance testing new versions with a subset of traffic.

### StatefulSet with Init Containers

Init containers are commonly combined with StatefulSets for stateful applications requiring initialization. Common use cases include database schema initialization before the app starts, permission fixes on volumes especially with UID/GID mismatches, waiting for dependencies like primary instances or external services, configuration generation based on Pod ordinal or hostname, data migration or seeding for new instances, and network prerequisites like DNS resolution or connectivity checks.

A typical pattern involves an init container that checks the Pod's hostname to determine its role. If the hostname ends in -0, it's the primary and doesn't need to wait. Otherwise, it's a secondary and must wait for the primary's DNS entry to exist before proceeding. Other common patterns include fixing permissions on mounted volumes, generating instance-specific configuration files based on the Pod's ordinal number, and seeding data or running migrations before the application starts.

Init containers run sequentially in order before the main container starts. They can check the Pod's hostname or ordinal to implement role-based logic. They're perfect for stateful applications needing instance-specific initialization. Failed init containers prevent the main container from starting, ensuring prerequisites are met. Each Pod in a StatefulSet can have different init behavior based on its ordinal number.

## CKAD Practice Exercises

Let me walk you through several practice exercises that combine multiple concepts in realistic exam scenarios.

The first exercise asks you to create a StatefulSet from scratch under time pressure. The objective is to quickly create a functional StatefulSet with specific requirements including a headless Service, three replicas, environment variables, PVCs for each Pod, and verification that everything works. The time limit is seven minutes. This exercise tests your ability to write complete YAML with proper indentation, configure volumeClaimTemplates correctly, and verify all components work together.

The second exercise focuses on accessing specific Pods via DNS. Using a StatefulSet you've already created, you deploy a test Pod with a client, connect to a specific StatefulSet Pod using its DNS name, and verify the connection by running queries. The time limit is four minutes. This tests your understanding of StatefulSet networking and DNS patterns.

The third exercise explores scaling and PVC retention. You create a StatefulSet with PVCs, write data to a file in one Pod, scale down to one replica, verify PVCs still exist, scale back up to three replicas, and verify the data still exists in the original Pod. The time limit is eight minutes. This demonstrates the critical concept that PVCs persist when scaling down and reattach when scaling back up.

The fourth exercise asks you to convert a Deployment to a StatefulSet. You're given a Deployment using emptyDir volumes, and you need to convert it to a StatefulSet with PVCs for each Pod. The time limit is six minutes. This tests your understanding of the structural differences between Deployments and StatefulSets and how to migrate between them.

The fifth exercise focuses on parallel Pod creation. You create a StatefulSet with five replicas that all start simultaneously using the Parallel pod management policy. The time limit is five minutes. This reinforces the concept that not all StatefulSets need sequential startup.

## Common Exam Pitfalls

Let me highlight the most common mistakes that cost candidates points on the exam.

The first pitfall is forgetting the headless Service. StatefulSets will not work correctly without a headless Service, so always create the Service first. The second pitfall is using the wrong Service name where the serviceName field in the StatefulSet doesn't match the actual Service name. These must match exactly.

The third pitfall is forgetting clusterIP: None in the Service spec. Without this, the Service isn't headless and individual Pod DNS won't work. The fourth pitfall is wrong volumeClaimTemplates indentation. The volumeClaimTemplates field must be at the same level as template, not inside it.

The fifth pitfall is not verifying PVCs are bound. Always check that PVCs show Bound status before assuming the deployment is complete. The sixth pitfall is mismatched serviceName where the StatefulSet's serviceName doesn't exactly match the Service's metadata name.

The seventh pitfall is expecting instant Pod creation. StatefulSets create Pods sequentially, so budget time for this in your answer. Don't sit and watch; verify the first Pod starts correctly, then move to another question. The eighth pitfall is not cleaning up PVCs when asked to clean up all resources. Remember to delete PVCs separately. The ninth pitfall is using the wrong DNS format. Memorize the pattern: pod-name.service-name.namespace.svc.cluster.local.

## Exam Tips

Let me share time-saving strategies for the exam. First, memorize the headless Service pattern so you can type it in under thirty seconds. Second, use kubectl apply with heredocs for faster YAML creation without needing separate files. Third, don't wait for sequential creation in timed mode. If you create a StatefulSet with five replicas, verify Pod-zero starts, then move to the next task and come back later to verify completion.

Fourth, use kubectl watch efficiently by pressing Ctrl+C as soon as you see the expected state. Don't waste time watching. Fifth, leverage kubectl scale for scaling operations, which is faster than editing YAML.

Must-know commands for the exam include kubectl get sts for listing StatefulSets, kubectl scale sts for scaling, kubectl set image sts for updating images, kubectl rollout commands for managing rollouts, kubectl exec for accessing specific Pods by name, and kubectl get pvc with label selectors for checking PVCs.

Key concepts to memorize include that headless Services require clusterIP: None, volumeClaimTemplates create PVCs automatically following the naming pattern, sequential creation means budgeting time appropriately, PVCs persist after StatefulSet deletion, the DNS pattern for individual Pods, and when to use Parallel versus OrderedReady pod management policies.

Practice recommendations include completing the exercises in under the time targets, writing volumeClaimTemplates from memory until it becomes automatic, practicing DNS name formats, and working through troubleshooting scenarios until diagnosis is instant.

## Quick Command Reference Card

Let me give you the essential commands in rapid-fire format. For creating and viewing, use kubectl apply for StatefulSets, kubectl get sts for listing, and kubectl describe sts for detailed information. For scaling, use kubectl scale sts with the replicas flag. For updating, use kubectl set image sts and kubectl patch sts for specific field changes.

For rollout management, use kubectl rollout status, history, and undo commands. For Pod access, use kubectl exec with the predictable Pod names and kubectl logs with Pod names. For PVC management, check PVCs with label selectors and verify binding status.

For DNS testing, deploy temporary Pods with nslookup capability. For cleanup, delete StatefulSets with kubectl delete sts, then separately delete PVCs with kubectl delete pvc using label selectors. For combined cleanup, you need separate commands since PVCs don't cascade delete.

## Additional Resources

The official Kubernetes documentation is allowed during the exam, so familiarize yourself with the StatefulSet documentation pages. Know how to quickly navigate to the StatefulSet concepts page, the basic StatefulSet tutorial, and the replicated stateful application guide.

Practice labs include completing the full StatefulSets lab from the README, working through all exercises in the CKAD guide, and trying the lab challenge without looking at the solution. Related topics to review include PersistentVolumes and PersistentVolumeClaims, Services and DNS, init containers, and multi-container Pod patterns.

## Next Steps

After completing these exercises and understanding the concepts, your next steps are to practice creating StatefulSets under time pressure with a target of under five minutes, study the PersistentVolumes CKAD guide since storage and StatefulSets often appear together, learn about Helm for managing complex StatefulSet deployments in production, and review DaemonSets to understand another Pod controller pattern.

Set yourself time-based challenges to build speed. Use kubectl explain during practice since it's available during the exam. Practice each scenario multiple times until they become muscle memory. Master the volumeClaimTemplates syntax by writing it from memory repeatedly. Know the difference between when to use StatefulSets versus Deployments without hesitation.

Remember that StatefulSets are only one to two questions on the exam. Master the basics, practice until you're confident, but don't over-invest time at the expense of core topics like Deployments, Services, and ConfigMaps. The exam tests breadth across many topics, so balanced preparation is key.

That completes our CKAD preparation for Kubernetes StatefulSets. You now have the knowledge and hands-on experience needed for StatefulSets on the CKAD exam. Practice these scenarios multiple times until they become second nature. Focus on speed and accuracy. Use imperative commands whenever possible to save time. And most importantly, remember that StatefulSets are just one piece of the CKAD puzzle. Master these concepts, and you'll be well-prepared for this portion of the exam. Good luck with your CKAD preparation!
