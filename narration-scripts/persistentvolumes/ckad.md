# CKAD Practice: PersistentVolumes and Storage

Welcome to the CKAD exam preparation module for persistent storage in Kubernetes. This session covers the persistent volume and storage topics required for the Certified Kubernetes Application Developer exam, building on what we learned in the exercises lab.

The CKAD exam includes storage questions under the Application Environment, Configuration and Security domain, which represents twenty-five percent of the exam. The good news is that storage questions are usually straightforward and can be completed quickly, typically in three to six minutes per question. The challenge is working under time pressure with potential distractions.

## CKAD Exam Relevance

For the exam, you need to master creating and consuming PersistentVolumeClaims for storage. This includes understanding access modes, working with StorageClasses, troubleshooting pending PVCs, and integrating storage with Pods and Deployments. You'll also need to know when to use PVCs versus EmptyDir volumes and how to verify that volumes are properly mounted and functioning.

## Quick Reference

Let's start with the essential commands you'll use most often in the exam. For listing resources, you need to quickly check PersistentVolumes, PersistentVolumeClaims, and StorageClasses. For troubleshooting, the describe commands on PVCs and PVs are invaluable. When checking Pod volume mounts, you can describe the Pod and look at the volumes section, or exec into the Pod to check mounted filesystems. For deletion, remember that deleting a PVC may also delete the underlying PV depending on the reclaim policy.

Understanding access modes is critical for the exam. ReadWriteOnce abbreviated as RWO is your default choice, allowing read-write by a single node and working with most storage types. ReadOnlyMany as ROX allows read-only access by multiple nodes but is less common. ReadWriteMany as RWX allows read-write by multiple nodes but requires NFS or similar network storage. ReadWriteOncePod as RWOP provides single Pod exclusive access and is available in Kubernetes one point twenty-two and later.

The exam tip here is if the question doesn't specify an access mode, use ReadWriteOnce. It's supported by all default StorageClasses. ReadWriteMany is often a trap because it requires special storage that most clusters don't have by default. Also remember that access modes are case-sensitive in YAML. ReadWriteOnce is correct while readwriteonce will fail validation.

## CKAD Scenarios

Let's work through the most common exam scenarios you'll encounter. The first scenario is creating a PVC and mounting it in a Pod. You'll typically have three to four minutes to create a PVC requesting a specific amount of storage like five hundred megabytes with ReadWriteOnce access mode, then deploy a Pod that uses it. The key is speed and accuracy.

Start by creating the PVC with the appropriate access mode and storage request. Check the PVC status immediately to verify it's bound or pending. Then create your Pod using the PVC, ensuring the volume name in the volumes section matches the name in volumeMounts. Finally verify the Pod is running and the volume is properly mounted. The PVC should show Bound status, the Pod should be Running, and checking the mounted filesystem should show the requested capacity.

The second scenario involves shared volumes between containers in a multi-container Pod. This tests your understanding of how containers within the same Pod can share data. You might be asked to create a Pod where one container writes data and another reads it using a shared volume. This is a common sidecar pattern where the main application writes logs to a shared volume and a sidecar container processes or forwards those logs.

For this scenario, you'll create a Pod with multiple containers, define an EmptyDir volume in the Pod spec, and mount that volume in both containers. Each container can mount the same volume to different paths if needed. The key learning is that EmptyDir volumes are shared between all containers in a Pod, making them perfect for inter-container communication and data sharing.

The third scenario involves using a specific StorageClass. In clusters with multiple storage types, you need to specify which one to use. You'll first check available StorageClasses to see what's offered, then create a PVC specifying the storageClassName field. If no storageClassName is specified, the default StorageClass is used. This is important because different storage classes have different performance characteristics, costs, and capabilities.

Understanding cloud provider storage classes is valuable for the exam. On AWS EKS, you might work with gp3 for general purpose SSD or io2 for provisioned IOPS. On Azure AKS, you'd use managed-premium for premium SSD or managed for standard SSD, and azurefile for ReadWriteMany scenarios. On Google GKE, standard-rwo provides HDD storage while premium-rwo provides SSD.

The fourth scenario focuses on troubleshooting pending PVCs. This is a common exam question where you need to identify why a PVC stays in Pending state. The typical issues include unsupported access modes where you requested ReadWriteMany but the StorageClass only supports ReadWriteOnce, no available StorageClass, insufficient storage capacity, or missing node labels for local PVs.

Your troubleshooting workflow should start by checking PVC status, then describing the PVC to view events, checking available StorageClasses, verifying the StorageClass provisioner is running, and confirming the cluster has capacity for your requested size. The describe command is your best friend here, as eighty percent of issues are visible in the Events section.

The fifth scenario involves Pods with multiple volume types. Real applications often need different kinds of storage for different purposes. You might create a Pod with a PVC for persistent data, EmptyDir for cache, another EmptyDir for logs, and a ConfigMap for configuration files. This tests your ability to work with multiple volume types simultaneously and understanding that different volume types serve different purposes.

The sixth scenario demonstrates data persistence after Pod deletion. The exam may explicitly test whether you understand PVC lifecycle. You'll create a PVC and a Pod that writes data, delete the Pod, then create a new Pod that reads the same data and verify it persisted. This confirms that PVC lifecycle is independent of Pod lifecycle and that data in a PV persists across Pod deletions.

## Advanced CKAD Topics

Beyond the basic scenarios, there are advanced topics that appear on the exam. Volume subPaths allow you to mount specific files or subdirectories from a volume rather than the entire volume. This is useful when you want to mount a single config file without hiding other files in the target directory, or when organizing multiple applications on shared storage.

Real-world use cases for subPaths include mounting a single configuration file without hiding other files in the directory, sharing a PVC between multiple applications where each uses a different subdirectory, separating database data and logs on the same volume, and isolating tenant data using subdirectories in multi-tenant applications. You can even use subPathExpr with environment variables to create dynamic paths like tenant-specific directories.

Volume expansion is another advanced topic where some StorageClasses support increasing PVC size without recreating resources. You can verify if a StorageClass supports expansion by checking the allowVolumeExpansion field. To expand a volume, you patch the PVC to increase the storage request, monitor the expansion progress, and for some volume types you may need to restart the Pod to complete the filesystem resize.

Different volume types have different expansion support. AWS EBS, Azure Disk, GCP Persistent Disk, and Ceph RBD support online expansion where no Pod restart is required. Azure Files and GlusterFS support offline expansion requiring a Pod restart. HostPath, Local Volumes, and EmptyDir don't support expansion at all. Remember you can only increase volume size never decrease, and expansion is a one-way operation.

ReadWriteMany volumes require network-based storage and appear in exam scenarios involving shared storage across multiple Pods. The default StorageClasses like AWS EBS and Azure Disk typically only support ReadWriteOnce. For ReadWriteMany, you need network storage like NFS, CephFS, or cloud provider file services. On AWS you'd use EFS, on Azure you'd use Azure Files, and on GCP you'd use Filestore.

## CKAD Practice Exercises

The practice exercises combine multiple concepts in realistic scenarios. The first exercise focuses on quick PVC creation under time pressure. You'll create a PVC, create a Deployment with multiple replicas, mount the PVC to all Pods, and verify everything is running and has the volume mounted. The time limit is five minutes, simulating exam pressure.

The second exercise is debugging storage issues. You're given a Pod that won't start due to storage problems and need to identify why it's failing, create the missing PVC, and verify the Pod starts successfully. This tests troubleshooting skills with a three-minute time limit.

The third exercise implements a multi-container shared storage pattern. You'll create a Pod with a main container serving files and a sidecar container writing content, both sharing an EmptyDir volume. You'll verify both containers can access the shared volume and see updated content in real-time. This is a six-minute exercise testing sidecar patterns.

The fourth exercise involves StatefulSets with PVC templates. This is an advanced topic for stateful applications. StatefulSets use volumeClaimTemplates to automatically create a dedicated PVC for each Pod. These PVCs persist even when Pods are deleted or the StatefulSet is scaled down. You'll deploy a StatefulSet, verify automatic PVC creation, write unique data to each Pod, test PVC retention after Pod deletion, and understand that PVCs remain even when scaling down.

## Common Exam Pitfalls

Let's talk about the top mistakes candidates make with storage questions. The first is creating PVCs in the wrong namespace. PVCs are namespaced resources, so you must ensure you're in the correct namespace before creating resources. Always verify your namespace context before starting.

The second pitfall is access mode incompatibility. Requesting ReadWriteMany when the StorageClass only supports ReadWriteOnce is a common trap. Most default StorageClasses don't support ReadWriteMany, so use ReadWriteOnce unless specifically required.

The third mistake is forgetting to wait for PVC binding. Always verify the PVC is Bound before using it in a Pod. You can wait explicitly using kubectl wait commands to ensure the PVC is ready.

The fourth pitfall is volume name mismatches. The volume name must match exactly between the volumes definition and the volumeMounts section. Copy-paste the volume name to avoid typos that will cause mount failures.

The fifth mistake is case sensitivity in access modes. Using readwriteonce instead of ReadWriteOnce will fail validation. Always use PascalCase for access modes.

## Exam Tips

For time management, budget three to five minutes per storage question. If you're stuck after two minutes, mark the question for review and move on. Come back to difficult questions with remaining time.

Use kubectl create to generate YAML quickly rather than writing from scratch. The dry-run pattern is invaluable for creating template YAML that you can modify. Practice without autocomplete since the exam environment may have limited autocomplete support.

Bookmark the Kubernetes documentation and know how to quickly find PVC examples. The exam allows access to kubernetes.io, so use it to find examples rather than memorizing everything. Copy-paste examples and modify them for your specific needs.

Learn the kubectl commands by heart. You should be able to type common commands without thinking, including creating PVCs, describing resources, checking status, and verifying mounts. Practice these until they're muscle memory.

Know the key concepts deeply. Zero downtime with volumes means using PVCs with proper access modes. Understanding that PVC lifecycle is independent of Pod lifecycle is critical. Know when to use PVCs versus EmptyDir versus ConfigMaps for different types of data.

## Quick Command Reference Card

For the exam, remember that there's no direct kubectl create pvc command, so you'll use kubectl apply with YAML. You can list all storage resources together with a single command. Use describe for troubleshooting to see events and status. Check Pod volume mounts by describing the Pod or executing mount commands inside. Be careful when deleting PVCs as it may delete data depending on the reclaim policy.

## Additional Resources

To continue your preparation, study the official Kubernetes PV and PVC documentation, review StorageClass documentation, and understand different volume types. The CKAD exam curriculum on the CNCF GitHub provides the official scope of topics.

## Next Steps

After completing these exercises, practice creating PVCs and Pods under time pressure. Experiment with different StorageClasses in your cluster if available. Learn about StatefulSets and volume claim templates for advanced persistent storage patterns. The StatefulSets lab provides deeper coverage of stateful applications with persistent storage.

That completes our CKAD preparation for persistent volumes and storage. You now have the knowledge and hands-on experience needed for storage questions on the CKAD exam. Practice these scenarios multiple times until they become muscle memory. Set yourself time-based challenges to build speed. Use kubectl explain during practice since it's available during the exam. Master these concepts and you'll be well-prepared for the storage portion of the CKAD exam.
