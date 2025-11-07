# DaemonSets - CKAD Exam Preparation
## Narration Script for Exam-Focused Training

### Section 1: CKAD Exam Context and What Are DaemonSets?

Welcome to CKAD exam preparation for DaemonSets. While DaemonSets are supplementary material for CKAD, they can appear on the exam, and understanding them demonstrates solid Kubernetes knowledge.

First, let's understand what DaemonSets are and why they matter for CKAD. A DaemonSet ensures that a copy of a Pod runs on all (or some) nodes in the cluster. As nodes are added to the cluster, Pods are added to them. As nodes are removed, those Pods are garbage collected.

Key exam scenarios include creating DaemonSets with the correct structure, configuring HostPath volumes for node-level access, using nodeSelector to target specific nodes, working with init containers in DaemonSets, understanding update strategies (RollingUpdate vs OnDelete), and troubleshooting why Pods aren't scheduled.

DaemonSets are part of the Application Deployment domain (20% of exam). You might see 1-2 questions involving DaemonSets, often combined with node selection, init containers, HostPath volumes, or update strategies.

Time management: Target 3-5 minutes per DaemonSet question. They're simpler than StatefulSets (no headless Service, no volumeClaimTemplates) so they should be faster.

Essential commands to memorize: kubectl get daemonsets or ds for listing, kubectl describe daemonset for details, kubectl apply for creating or updating, kubectl delete for removal, kubectl get pods -o wide to verify Pod placement on nodes, and kubectl label node for adding node labels.

Key differences from Deployments: DaemonSets have no replicas field - Pod count is automatic based on nodes. Scaling is done by adding/removing nodes or changing nodeSelector, not by changing replica count. Update strategy deletes old Pods before creating new ones (opposite of Deployments). Use cases are for node-level services like log collectors, monitoring agents, or storage daemons. HostPath volumes are common with DaemonSets for accessing node resources.

---

### Section 2: Creating Basic DaemonSets

Let's start with creating a basic DaemonSet. The structure is simpler than you might think.

Here's the basic DaemonSet structure. Critical points: Use apiVersion apps/v1, kind is DaemonSet, there's NO replicas field, spec.selector must match spec.template.metadata.labels, and the template contains a standard Pod spec.

Common mistake: Don't try to add a replicas field. DaemonSets don't have one - the number of Pods is determined automatically by the number of matching nodes.

Quick creation pattern: Start with kubectl create deployment dry-run to get basic structure, change kind to DaemonSet, remove the replicas field, adjust as needed, then apply.

To verify your DaemonSet, check that DESIRED matches your node count, all Pods are in Running status, and each Pod is on a different node using kubectl get pods -o wide.

Decision tree for the exam: If the question mentions "every node" or "each node", use a DaemonSet. If it mentions "log collector" or "monitoring agent", likely a DaemonSet. If it specifies "3 replicas", use a Deployment. If it mentions "node resources" or HostPath, likely a DaemonSet.

---

### Section 3: HostPath Volumes with DaemonSets

HostPath volumes are commonly used with DaemonSets to access node-level resources.

Here's a DaemonSet with HostPath volume configuration. The volumes section defines the HostPath at the Pod spec level. The volumeMounts section in the container references the volume. The name must match between volumes and volumeMounts. The path is where it mounts in the container, the hostPath.path is the path on the node, and the hostPath.type validates the path exists.

Common HostPath types you should know: Directory means must exist as a directory (most common for exam), DirectoryOrCreate means create if doesn't exist, File means must exist as a file, and Socket is for Unix sockets like /var/run/docker.sock.

The pattern for mounting host directories: Define volume with hostPath at Pod spec level, specify the type for validation, mount the volume in container with desired mountPath, and use readOnly: true if you only need read access.

Troubleshooting HostPath issues: If Pods are in CrashLoopBackOff, check the Pod events with describe. Common causes include path doesn't exist on node (wrong type specified), permission denied (may need securityContext), or wrong volumeMount name reference. Quick fix: If path validation fails, use DirectoryOrCreate instead of Directory.

---

### Section 4: Node Selection with nodeSelector

One of DaemonSet's most powerful features is targeting specific nodes using nodeSelector.

Here's how to use nodeSelector. The nodeSelector field goes in spec.template.spec (the Pod spec), not in the DaemonSet spec. It uses simple key-value matching.

Dynamic behavior: When you label a node that matches the selector, the DaemonSet creates a Pod there. When you remove a matching label, the DaemonSet deletes that Pod. This is dynamic - DaemonSets watch for node label changes.

To label nodes, use kubectl label node node-name key=value to add a label, kubectl label node node-name key=value --overwrite to update, and kubectl label node node-name key- to remove a label.

Common label patterns for the exam: Environment labels like env=production, hardware labels like disktype=ssd or gpu=true, location labels like topology.kubernetes.io/zone=us-west-1a, and workload type labels like workload=database.

Verification workflow: Create DaemonSet with nodeSelector, check DESIRED equals 0 if no nodes match, label a node to match the selector, watch as Pod is created immediately, verify Pod is on the labeled node with kubectl get pods -o wide.

Best practice: Always verify labels exist on nodes before expecting Pods to schedule. Use kubectl get nodes -l key=value to check.

---

### Section 5: Update Strategies

DaemonSets support two update strategies: RollingUpdate and OnDelete.

RollingUpdate is the default strategy. When you update the DaemonSet spec, Pods are automatically updated. The update process deletes the old Pod first, then creates the new Pod (opposite of Deployments). This can cause temporary service interruption per node. Use this when you want automatic updates.

OnDelete strategy means updates are manual. When you update the DaemonSet spec, existing Pods are NOT updated. Pods only update when you manually delete them. New nodes get the new spec immediately. Use this when you need complete control over rollout timing.

Here's how to configure OnDelete strategy. Set spec.updateStrategy.type to OnDelete in your DaemonSet spec.

The update workflow with OnDelete: Update the DaemonSet spec, verify existing Pods are still running with old spec, manually delete a Pod to trigger update with kubectl delete pod, the new Pod gets the updated spec, repeat for each node at your own pace.

Decision for the exam: If question says "automatic updates", use RollingUpdate (or just omit the field, it's default). If question says "manual control" or "one at a time", use OnDelete.

Critical difference from Deployments: Deployment RollingUpdate creates new Pods first, then deletes old ones (maintains availability). DaemonSet RollingUpdate deletes old Pods first, then creates new ones (can't have two on one node). This means DaemonSet updates can cause brief downtime per node.

---

### Section 6: Init Containers with DaemonSets

Init containers are commonly used with DaemonSets for setup tasks before the main container starts.

Here's the structure for init containers. The initContainers field is an array in spec.template.spec (the Pod spec). Init containers run in order before the main containers. They must complete successfully before the main container starts. They can share volumes with the main container.

Common init container patterns for the exam: Wait for dependency like checking if a service is available, download config like fetching configuration files, set permissions like chmod operations on shared volumes, or prepare data like generating initial content.

The emptyDir volume pattern: Init container writes data to the shared volume, volume persists during Pod lifetime, main container reads from the shared volume. The volume is specific to that Pod instance and is lost when the Pod is deleted.

Pod status during init: Init:0/1 means init container is running (0 of 1 complete). PodInitializing means init container completed, main container starting. Running means all containers (init and main) completed their lifecycle.

To debug init containers, use kubectl describe pod to see init container status and events, kubectl logs pod-name -c init-container-name to view init container logs, and check if the init container completed successfully before troubleshooting main container.

---

### Section 7: Common CKAD Scenarios and Practice

Let's walk through practical scenarios you'll encounter in the exam.

Scenario 1: Create a basic DaemonSet. Task: Create a DaemonSet named log-collector running busybox with label app=logging. Verify one Pod per node.

Solution steps: Create YAML with apps/v1 and kind DaemonSet, no replicas field, selector matches template labels, apply and verify with kubectl get daemonset and kubectl get pods -o wide. Time target: 3-4 minutes.

Scenario 2: DaemonSet with HostPath. Task: Create DaemonSet mounting host's /var/log at /host-logs as read-only.

Solution steps: Add volumes section with hostPath, specify type Directory, add volumeMount in container with readOnly true, verify Pods can access the path. Time target: 3-4 minutes.

Scenario 3: Target specific nodes. Task: Create DaemonSet that only runs on nodes with label disktype=ssd.

Solution steps: Add nodeSelector in Pod spec, verify DESIRED=0 initially, label one node with disktype=ssd, watch Pod creation, verify Pod is on correct node. Time target: 3-4 minutes.

Scenario 4: Manual update control. Task: Configure DaemonSet to use OnDelete strategy.

Solution steps: Set updateStrategy.type to OnDelete, update the DaemonSet spec (like changing image), verify Pods don't automatically update, manually delete a Pod, verify new Pod has updated spec. Time target: 2-3 minutes.

Scenario 5: Init container setup. Task: Create DaemonSet with init container that prepares configuration before main container starts.

Solution steps: Add initContainers section, share volume with emptyDir, init container writes to volume, main container reads from volume, verify with kubectl logs. Time target: 3-4 minutes.

---

### Section 8: Troubleshooting DaemonSet Issues

Let's cover common issues and how to diagnose them quickly.

Issue 1: Pods not scheduling. Symptoms: DaemonSet shows DESIRED=0 or Pods are Pending.

Diagnosis: Check DaemonSet spec with kubectl describe daemonset. Check node labels with kubectl get nodes --show-labels. Check if nodeSelector matches any nodes. Check for taints on nodes with kubectl describe node.

Common causes: nodeSelector doesn't match any nodes, nodes have taints without corresponding tolerations, or all nodes are cordoned.

Fixes: Verify and fix node labels, add tolerations to Pod spec if nodes are tainted, or remove nodeSelector to run on all nodes.

Issue 2: Update not happening. Symptoms: Updated DaemonSet but Pods still have old spec.

Diagnosis: Check update strategy with kubectl get daemonset -o yaml and grep for updateStrategy.

If it shows OnDelete: This is expected behavior. You must manually delete Pods for updates.

Fix: Either change to RollingUpdate or manually delete Pods one by one to trigger updates.

Issue 3: HostPath volume failures. Symptoms: Pods in CrashLoopBackOff or Error state.

Diagnosis: Check Pod events with kubectl describe pod. Check Pod logs with kubectl logs. Look for path-related errors.

Common causes: Path doesn't exist on node, wrong type specified (like Directory when it should be DirectoryOrCreate), or permission denied errors.

Fixes: Use DirectoryOrCreate if path doesn't exist, add securityContext if permissions are needed, verify the hostPath.path is correct, or use kubectl exec to test path access from within Pod.

Issue 4: One Pod per node violation. Symptoms: Multiple DaemonSet Pods on one node or no Pod on a node.

This shouldn't happen normally, but if it does: Check if nodeSelector or tolerations changed, verify node labels haven't changed, check for multiple DaemonSets with same selector (conflict), or look for manual Pod creation with same labels.

---

### Section 9: Exam Tips and Strategy

Time management: DaemonSets are quicker than StatefulSets. No headless Service needed, no volumeClaimTemplates. Target 3-5 minutes per DaemonSet question.

Memory aids: No replicas - remember "DaemonSet determines replicas automatically by node count". Delete first - DaemonSets delete old before creating new (opposite of Deployments). OnePerNode - only one DaemonSet Pod can run per node (enforced by name).

Common mistakes to avoid: Adding a replicas field will cause the YAML to be invalid. Expecting Deployment-style updates where new Pods start before old ones terminate. Using wrong HostPath type - always specify the type field. Not verifying that nodeSelector labels exist on nodes. Forgetting that OnDelete requires manual Pod deletion. Wrong API version - use apps/v1, not extensions/v1beta1.

Time-saving tips for the exam: Use kubectl create deployment with dry-run, change to DaemonSet, remove replicas. Use heredoc for multi-line YAML to avoid editor issues. Verify with kubectl get ds and kubectl get pods -o wide quickly. Don't watch Pods unnecessarily - check status and move on. Label nodes efficiently with kubectl label node $(kubectl get nodes -o name | head -1) key=value.

Quick reference commands: kubectl get ds for listing, kubectl describe ds name for details, kubectl get ds name -o yaml for full spec, kubectl get pods -o wide to see node placement, kubectl label node for node labels, and kubectl delete ds name for removal.

Practice recommendations: Create 2-3 DaemonSets from scratch daily until you can do it in under 4 minutes. Practice the difference between RollingUpdate and OnDelete. Memorize HostPath volume syntax. Practice nodeSelector patterns. Time yourself on complete scenarios.

DaemonSets are less common than Deployments but easier than StatefulSets. Master the basics, remember there's no replicas field, understand the update behavior, and these should be confidence-building questions on exam day.

Good luck with your CKAD exam!

---

## Recording Notes

**Key Points:**
- Focus on the "no replicas field" concept - this is the most common mistake
- Emphasize the difference between DaemonSet and Deployment update behavior
- Show that DaemonSets are simpler than StatefulSets (no headless service, no PVC templates)
- Demonstrate nodeSelector as the primary way to control DaemonSet placement
- Highlight OnDelete strategy for manual control
- Note that HostPath volumes are common with DaemonSets
- Stress time management - DaemonSets should be quick wins

**Visual Focus:**
- Show kubectl get ds output with DESIRED matching node count
- Display kubectl get pods -o wide to show one Pod per node
- Highlight the update sequence (delete then create vs create then delete)
- Show nodeSelector effect with before/after node labeling
- Demonstrate init container Pod status progression
- Display HostPath volume mounting in Pod spec
- Keep verification steps visible and quick
