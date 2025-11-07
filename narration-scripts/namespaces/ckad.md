# Namespaces - CKAD Exam Preparation Script

Welcome to the CKAD-focused session on namespaces. In this video, we'll go beyond the basics and cover everything you need to know about namespaces for the Certified Kubernetes Application Developer exam. The CKAD exam tests your ability to work quickly and accurately with Kubernetes resources, and namespaces appear frequently throughout the exam, both directly and as requirements for other tasks. You'll switch namespaces many times during the exam, work with resource quotas and limits, and handle cross-namespace communication. Missing the namespace is one of the most common mistakes candidates make, so let's practice until it becomes second nature.

## CKAD Exam Context

In the CKAD exam, you'll frequently work with namespaces to isolate exam tasks from each other, demonstrate understanding of resource scoping, work with resource quotas and limits, and manage cross-namespace communication. Questions often specify which namespace to use, and you'll need to verify which namespace you're working in before running commands. Some questions explicitly test namespace isolation and resource quotas, while others assume you'll correctly use the specified namespace. Always verify which namespace you're working in before critical operations.

## API specs

The API resources we'll work with include the Namespace resource itself, ResourceQuota for limiting aggregate usage in a namespace, and LimitRange for setting defaults and boundaries per container. Understanding how these work together is essential for the exam.

## Imperative Namespace Management

The CKAD exam rewards speed, so you should be comfortable with imperative commands. The fastest way to create a namespace is with the create namespace command followed by the name. That's it! Much faster than writing YAML. You can generate YAML if needed using the dry-run flag with client mode and yaml output, but in the exam, imperative creation is almost always faster unless you need specific labels or annotations.

There are two methods to work in a namespace. The first method uses the minus n flag on every command. This is explicit and there's no confusion about which namespace you're targeting, but it requires more typing and is easy to forget. The second method changes the context to set a default namespace. This results in less typing and cleaner commands, but you can forget which namespace you're in if you're not careful.

My recommendation for exam strategy is to use context switching when a question focuses on one namespace, use the minus n flag when jumping between namespaces in a single question, and always verify your namespace before critical operations. You can quickly check your current namespace by viewing the context configuration. Practice both methods and use what feels natural under pressure.

## Resource Quotas in CKAD

Resource quotas limit the total resources that can be consumed in a namespace. This is a key CKAD topic. Critical exam knowledge: when a namespace has ResourceQuota for CPU or memory, every Pod must specify resource requests and limits. This catches many candidates off guard. Let's see what happens when we create a namespace with a quota and try to create a Pod without resources. After setting up the quota, attempting to create a Pod without resource specifications will fail. When we check the events, we'll see an error stating that we must specify limits and requests for CPU and memory.

The solution is to always specify resources when quotas exist. You can do this with kubectl run using the requests and limits flags, or with YAML by including the resources section with requests and limits fields. After creating a compliant Pod, we can verify the quota is being tracked by describing the quota. The output shows hard limits indicating the maximum allowed, used showing currently consumed resources, and the remaining capacity. An exam tip: if Pods won't start, check for quotas immediately. This saves minutes of debugging time.

## LimitRanges in CKAD

LimitRanges define default, minimum, and maximum resource constraints for containers and PVCs in a namespace. They're crucial for CKAD as they work alongside ResourceQuotas. Understanding the key differences is important. LimitRange applies per Pod or container and sets defaults and boundaries, being enforced at Pod creation time. ResourceQuota applies to the total for the namespace and limits aggregate usage, being accumulated across all resources. LimitRange can set default values while ResourceQuota requires explicit specifications. LimitRange rejects individual pods that violate constraints, while ResourceQuota rejects when the total is exceeded.

LimitRanges can automatically apply resource limits to containers that don't specify them. You define default limits that apply if not specified, and default requests that apply if not specified. The key exam tip here is that when a LimitRange with defaults exists, pods without resource specs will get these defaults automatically. This is different from ResourceQuota, which rejects pods without specs.

LimitRanges can also enforce boundaries with minimum and maximum constraints. You can set a maximum for CPU and memory that containers cannot exceed, and a minimum that containers must request. Testing this behavior shows that attempting to create a pod exceeding the max will fail with a clear error message. You can also enforce a maximum ratio between limits and requests, preventing users from setting very low requests but high limits, which could cause scheduling issues.

For the exam, you should be able to create a namespace with a LimitRange that sets defaults, then create a pod without resource specifications and verify the defaults are applied. You can check that defaults were applied by examining the pod's YAML output and looking at the resources section. Important for CKAD: when both ResourceQuota and LimitRange are present, pods must satisfy both. The LimitRange validates individual containers, while ResourceQuota tracks cumulative usage.

## ServiceAccounts and Namespaces

ServiceAccounts are namespace-scoped resources. Each namespace gets a default ServiceAccount automatically. You can list ServiceAccounts in a namespace, create a ServiceAccount with the create command, and create a pod using a specific ServiceAccount by specifying the serviceaccount flag. For the exam, you should be able to create a namespace, create a ServiceAccount in it, and run a pod using that ServiceAccount, then verify the configuration.

Understanding ServiceAccount tokens and mounting is important for CKAD. Every ServiceAccount automatically gets a token that can be used to authenticate to the Kubernetes API. The default behavior is that each namespace has a default ServiceAccount, Pods automatically use the default ServiceAccount unless specified, the token is mounted at a standard path inside the container, and the token provides identity for API authentication. You can verify this by creating a pod and checking the mounted token location, where you'll find the CA certificate, namespace file, and JWT token.

For security, you might want to disable automatic token mounting. You can do this in the Pod spec with the automountServiceAccountToken field set to false, or at the ServiceAccount level to disable it for all pods using that account. ServiceAccounts are subjects in RBAC bindings, which is a key CKAD pattern for controlling pod permissions. You can create a complete RBAC example by creating a namespace, creating a ServiceAccount, creating a Role with specific permissions, binding the Role to the ServiceAccount, and creating a pod using the ServiceAccount.

Testing ServiceAccount permissions is important. You can check if a ServiceAccount can perform actions using the auth can-i command with the as flag to impersonate the ServiceAccount. This shows whether the ServiceAccount can list pods, delete pods, or perform other operations. The CKAD exam tip is that ServiceAccounts are commonly combined with RBAC to demonstrate understanding of pod-level permissions. Practice creating the full chain: ServiceAccount, then Role, then RoleBinding, then Pod.

## Cross-Namespace Communication

This is critical for CKAD because you need to understand how pods in different namespaces communicate. Services are namespace-scoped, and DNS follows a specific pattern. The short name only works within the same namespace. The namespace-qualified name works across namespaces. The fully-qualified domain name is the complete format. Understanding these patterns is essential.

Let's create services in different namespaces and test connectivity. After creating two namespaces and deploying backend and frontend services, we can test DNS resolution from the frontend namespace. Using just the short service name will fail because the service is in a different namespace. Using the namespace-qualified name will work, and using the FQDN will also work. Testing actual connectivity shows that you can successfully reach services across namespaces using the proper DNS format.

An important limitation is that ConfigMaps and Secrets cannot be referenced across namespaces. If the exam asks you to configure cross-namespace communication, you need to create the ConfigMap in the same namespace as the Pod, store the FQDN service name in the ConfigMap, have the Pod reference the local ConfigMap, and have the service name point to the other namespace. The ConfigMap is in the frontend namespace where the Pod is, but the URL it contains points to the backend namespace. Note that ConfigMaps and Secrets are namespace-scoped and cannot be directly referenced across namespaces.

ConfigMaps and Secrets cannot be referenced directly across namespaces, so you need strategies for CKAD. The simplest approach is to duplicate resources by creating the same ConfigMap or Secret in each namespace. This is simple and secure because namespace isolation is maintained, though it's harder to manage updates and involves duplication. Another strategy is to use Service DNS names in ConfigMaps, where you store cross-namespace service URLs in ConfigMaps within each namespace. This is the most common pattern in the exam where each namespace has its own ConfigMap with FQDNs for cross-namespace services.

NetworkPolicies can control traffic between namespaces using namespace selectors, which is a key CKAD skill. You can create basic namespace isolation by allowing traffic only from specific namespaces. The namespace must have the label for this to work. For three-tier application isolation with frontend, backend, and database tiers, you would label namespaces appropriately, apply NetworkPolicies that control which namespaces can communicate, and test connectivity to verify the policies work correctly. You can combine pod and namespace selectors for fine-grained control, allowing only specific pods in specific namespaces to communicate with target pods.

Best practices for multi-namespace applications include using consistent naming across namespaces, applying consistent labels to namespaces and resources, creating resources in the correct order starting with namespaces and ending with services, always using FQDNs in cross-namespace communication, and testing cross-namespace communication with quick test patterns. For the exam, you should be able to create three namespaces with appropriate labels, deploy a pod in each, create services, and configure NetworkPolicies so that specific communication paths are allowed while others are blocked.

## Namespace-Scoped vs Cluster-Scoped Resources

Understanding resource scope is important for CKAD. Namespace-scoped resources include Pods, Deployments, ReplicaSets, StatefulSets, DaemonSets, Services, Endpoints, ConfigMaps, Secrets, ServiceAccounts, PersistentVolumeClaims, ResourceQuotas, LimitRanges, NetworkPolicies, and Ingresses. Cluster-scoped resources include Nodes, Namespaces themselves, PersistentVolumes, StorageClasses, ClusterRoles, ClusterRoleBindings, and CustomResourceDefinitions. You can list all API resources with their scope using the namespaced flag to filter for namespace-scoped or cluster-scoped resources. When getting cluster-scoped resources, you don't need the minus n flag.

## CKAD Exam Patterns and Tips

Common exam tasks include creating a namespace and setting context, which is done with the create namespace command followed by setting the context. Deploying applications with quotas requires creating the namespace, applying the ResourceQuota, deploying pods with resource requests and limits, and verifying quota usage. Cross-namespace service discovery involves deploying services in different namespaces, configuring pods to communicate using FQDNs, and testing connectivity. Resource isolation requires deploying similar apps in different namespaces, applying different quotas and limits, and verifying isolation.

Time-saving tips include using aliases for common commands, always verifying the namespace before running commands, and deciding whether to use the minus n flag versus changing context. Using minus n is faster but requires discipline, while changing context is safer but slower. In the exam, use what you're comfortable with. Imperative commands with dry-run let you generate YAML quickly for complex resources.

## Practice Exercises

The practice exercises combine multiple concepts into realistic scenarios. A multi-namespace application exercise has you deploy a three-tier application across namespaces with databases, APIs, and web frontends in separate namespaces. Requirements include applying ResourceQuota to each namespace, ensuring all pods have resource requests and limits, testing cross-namespace communication, and using ConfigMaps for service discovery. The complete solution involves creating all namespaces, applying quotas, deploying the applications, verifying environment variables, checking quota usage, and testing connectivity between tiers.

A quota enforcement exercise creates a namespace with constraints on maximum pods, CPU, and memory. You try to exceed limits and observe the behavior, seeing how Kubernetes rejects pods that would violate the quota. The exercise demonstrates creating pods within limits, attempting to exceed pod count limits, attempting to exceed resource limits, and understanding quota enforcement behavior.

A namespace migration exercise moves an application from a dev namespace to a prod namespace. You export existing resources, modify namespace references, apply to the new namespace, verify functionality, and clean up the old namespace. This teaches you how to work with namespace-scoped resources and migrate applications between environments.

## Advanced CKAD Topics

Pod Security Standards define different isolation levels that can be applied per namespace. The three security levels are Privileged for unrestricted workloads, Baseline for minimally restrictive policies, and Restricted for heavily restricted security-sensitive applications. Applying security standards to namespaces is done with labels that enforce, audit, and warn about policy violations. Testing security enforcement shows that non-compliant pods are rejected while compliant pods are accepted.

Resource quotas with priority classes allow you to assign importance to pods and create separate quotas for different priority levels. You create PriorityClasses with different values, then create quotas with scope selectors that apply only to pods with specific priority classes. This lets you allocate more resources to high-priority workloads and fewer to low-priority ones.

Understanding namespace lifecycle and finalizers is important when resources aren't cleaning up properly. Namespaces can be in Active or Terminating phases. If a namespace gets stuck in Terminating state, it's usually because finalizers are preventing deletion. You can view the finalizers and potentially force deletion if necessary, though this should be done with caution.

Automating namespace creation with templates helps you quickly create namespaces with standard configurations. You can create scripts that generate namespaces with quotas and limits using parameters, making it easy to create consistent environments quickly. For the exam, having a function or script ready can save valuable time.

## Common Pitfalls

Several common pitfalls can cost you points on the exam. Forgetting to set the namespace means you create resources in the wrong place, so always verify with a context check. Resource requirements with quotas is critical because when ResourceQuota exists, all containers need requests and limits. ConfigMap and Secret scope limitations mean they cannot be referenced across namespaces directly. Service DNS short names only work within the same namespace, so use FQDNs for cross-namespace communication. Label selectors don't span namespaces, so Services only select pods in the same namespace. Never assume the default namespace in the exam; always specify explicitly.

## Cleanup

Clean up all practice namespaces by deleting them, which removes all resources inside them. You can delete multiple namespaces at once by listing them. This keeps your cluster clean and ready for the next exercise.

## Next Steps

After mastering namespaces for CKAD, continue with other topics like RBAC for namespace-level access control, NetworkPolicy for namespace isolation, Resource Management for production patterns, and Multi-tenancy patterns for advanced scenarios. These build on your namespace knowledge and complete your CKAD preparation.

## Study Checklist for CKAD

Before your exam, make sure you can create namespaces imperatively, set and switch namespace context, apply ResourceQuotas, create LimitRanges, deploy pods with resource requests and limits, create and use ServiceAccounts in namespaces, resolve services across namespaces using DNS, list resources across all namespaces, understand namespace-scoped versus cluster-scoped resources, handle ConfigMap and Secret namespace scoping, and clean up resources by deleting namespaces. Practice these skills until you can perform them quickly and confidently without references. Namespaces appear in almost every CKAD exam question, either explicitly or implicitly. Get comfortable with them, and you'll save time throughout the entire exam.

That wraps up our CKAD-focused exploration of namespaces. We've covered imperative commands for speed, resource quotas and limits for resource management, cross-namespace communication patterns, ServiceAccounts and RBAC integration, and all the common exam scenarios you'll encounter. Practice these patterns until they become automatic, and you'll be well-prepared for namespace-related questions on the CKAD exam.
