Welcome back! Now that we've covered the architecture of Kubernetes clusters, the control plane and worker node components, and the mechanisms for controlling Pod placement, it's time to work with these concepts in a multi-node environment.

In the upcoming exercises video, we're going to explore multi-node cluster operations hands-on. You'll work with cluster versions and API support, create multi-node clusters, and practice the essential node operations that form the foundation of cluster management.

First, we'll address cluster versions and API support. Kubernetes moves fast with three releases per year, and different versions support different API versions. You'll use k3d to spin up clusters running specific Kubernetes versions and see how API compatibility changes between releases. We'll demonstrate why a beta Ingress spec works on older clusters but fails on newer ones, and you'll understand the importance of keeping your YAML manifests aligned with your cluster's capabilities.

Then we'll create a multi-node cluster with k3d, building an environment with one control plane node and two worker nodes. This gives us the foundation we need to explore how Kubernetes distributes workloads across nodes and how node-level controls affect Pod scheduling decisions. You'll see the nodes as Docker containers and understand how k3d provides a realistic multi-node environment on your local machine.

Next comes taints and tolerations, one of the most powerful scheduling mechanisms in Kubernetes. You'll apply a NoSchedule taint to a node and watch how it prevents new Pods from being scheduled there while existing Pods continue running undisturbed. Then you'll see the more aggressive NoExecute taint that immediately evicts running Pods and prevents new ones from scheduling. Finally, you'll add tolerations to your Pod specs so they can schedule on tainted nodes, understanding that tolerations grant permission but don't guarantee placement.

We'll then move to scheduling with node selectors. You'll deploy a DaemonSet for the Nginx Ingress Controller and observe how it interacts with node selectors and tolerations. DaemonSets are special because they ensure a Pod runs on every node, but they still respect scheduling constraints. You'll see how combining node selectors with tolerations gives you precise control over where DaemonSet Pods run, whether that's only on worker nodes, only on the control plane, or on nodes with specific characteristics.

The lab section challenges you to perform node maintenance operations. You'll prepare a node for maintenance by cordoning it to prevent new scheduling and draining it to evict existing Pods gracefully. Then you'll bring the node back online and discover that Pods don't automatically rebalance, leading you to find strategies for spreading workloads evenly across nodes again.

For those interested in deeper exploration, the extra section on adding and removing nodes lets you simulate real cluster operations. You'll stop nodes to see how Kubernetes detects failures and reschedules Pods, delete nodes from the cluster, create replacement nodes, and even experience what happens when your control plane goes offline. These scenarios build intuition about cluster resilience and high availability.

Before starting the exercises video, make sure you have k3d installed for creating multi-node clusters, kubectl configured and ready, and the ability to create and delete clusters on your machine. The exercises will create a dedicated k3d cluster for this lab, so you can follow along in real time or watch first and practice afterward.

While cluster setup and administration are beyond core CKAD requirements, understanding node operations is essential. The exam may ask you to troubleshoot why Pods won't schedule, label nodes for specific workloads, or perform basic node maintenance. More importantly, understanding how the cluster distributes Pods, how taints prevent scheduling, and how to safely drain nodes for maintenance are skills you'll use constantly in production Kubernetes environments.

For CKAD preparation, focus on the kubectl commands for querying node information, managing labels and taints, and performing cordon, drain, and uncordon operations. These are practical skills that appear in exam scenarios and represent the intersection of cluster knowledge and application deployment.

Let's get started with the hands-on exercises and see these multi-node concepts in action!
