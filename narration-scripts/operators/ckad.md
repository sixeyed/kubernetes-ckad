# Operators - CKAD Narration Script

**Duration:** 30-35 minutes
**Format:** Screen recording with live demonstration
**Prerequisite:** Completed Operators exercises

---

Welcome to the CKAD exam preparation module for Kubernetes Operators and Custom Resources. This session covers the operator and CRD topics required for the Certified Kubernetes Application Developer exam, building on what we learned in the exercises lab.

The CKAD exam expects you to understand Custom Resource Definitions and their purpose, create and manage custom resources from existing CRDs, work with operator-managed applications, query and troubleshoot custom resources, and understand how operators extend Kubernetes. The key point here is that you're a user of operators, not a developer of operators. You won't be creating Custom Resource Definitions from scratch or building controllers, but you absolutely need to know how to work with existing CRDs and the resources they define. Let's focus on what matters for exam success.

## CKAD Exam Requirements

Let's clarify exactly what you need to know for the exam. Understanding what CRDs are and their purpose is required. Creating custom resources from existing CRDs is required. Listing and describing custom resources with kubectl is required. Understanding that operators extend Kubernetes and working with operator-managed applications are both required, as is basic troubleshooting of custom resources.

What's beyond CKAD scope? Creating Custom Resource Definitions from scratch, building operators or controllers, complex operator development, using the Operator SDK or Kubebuilder, writing validation webhooks, and advanced operator patterns. These are all important topics but they're not part of the CKAD exam.

The exam tests whether you can work with existing CRDs, create custom resources correctly, query and describe custom resources, troubleshoot operator-deployed applications, and understand the relationship between CRDs, custom resources, and operators. Think of yourself as a user who leverages operators built by others, not as someone who builds the operators themselves.

## Custom Resource Definitions (CRDs)

While you won't create CRDs on the exam, understanding their structure helps you work with them effectively. A Custom Resource Definition has the usual Kubernetes metadata, but the spec is where the interesting details live. The metadata name must follow a specific format combining the plural name with the group, like backends.stable.example.com. The spec defines the API group such as stable.example.com, the names section defining how you reference the resource with plural and singular forms plus the kind used in YAML manifests and optional short names for kubectl convenience, and the scope which is either Namespaced or Cluster.

The versions section is particularly important. Each version has a served flag indicating whether it's enabled, a storage flag indicating which version is used for storage where only one can be true, and a schema defining the OpenAPI v3 validation. This schema is what validates your custom resources before they're stored in etcd.

You can use kubectl explain to understand CRD structure just like with standard resources. This is extremely valuable during the exam when you're working with an unfamiliar CRD. Let me demonstrate by explaining a database CRD. You'll see the schema, the available fields, their types, and any validation rules. This is your documentation during the exam.

## Understanding the Operator Pattern

Operators combine Custom Resources with Controllers to provide automation. Think of it as CRDs plus Controllers equals Operators. The controller pattern is central to understanding how operators work. A controller watches Kubernetes resources and takes action to reconcile desired state with actual state through a continuous loop. It watches for resource changes like creates, updates, and deletes, compares desired state in the spec with actual state in the status, takes action to reconcile differences, updates the resource status, and repeats indefinitely.

The operator has three main components. First is the Custom Resource Definition which defines the schema for custom resources, is installed in the cluster, and extends the Kubernetes API. Second is the Custom Resource itself which is an instance of a CRD, defines desired state, and is created by users. Third is the Controller which watches custom resources, reconciles desired state, usually runs as a Deployment, and requires RBAC permissions to function.

Here's how the workflow looks in practice. During the installation phase, you install the operator which creates CRDs in the cluster and deploys the controller. During the runtime phase, a user uses kubectl to create a custom resource like a Database, and the controller watches for this event. The reconciliation loop then kicks in where the controller reads the custom resource spec, compares desired state versus actual state, and takes action to create or update resources. Finally there's a status update phase where the controller checks the health of created resources and updates the custom resource status with phase and replica information, then loops back continuously.

Let me walk through a concrete example. When a user creates a Database custom resource specifying postgres engine with three replicas, the controller watches and creates a StatefulSet with three postgres pods, a Service for both headless and loadbalancer access, a ConfigMap containing postgres configuration, a Secret for passwords, three persistent volume claims for storage volumes, and a CronJob for automated backups. The controller then updates the status showing phase as Running, three ready replicas, and conditions indicating the Ready state.

## Working with Operators

Most operators are installed via manifests or Helm charts. When installing via manifests, you apply the CRDs first, then apply the operator deployment, verify the installation by checking CRDs and pods, and examine the operator logs. When installing via Helm, you add the Helm repository, update it, install the operator using helm install, and verify by listing helm releases, checking CRDs, and checking pods.

Operators need permissions to watch and manage resources, which means RBAC is critical. The operator uses a ServiceAccount with a ClusterRole defining what it can do. The role needs permissions to watch custom resources with get, list, watch, update, and patch verbs. It needs separate permissions for the status subresource. It needs permissions to manage Kubernetes resources like deployments, statefulsets, services, configmaps, and secrets with get, list, create, update, and delete verbs. All of this is tied together with a ClusterRoleBinding connecting the ServiceAccount to the ClusterRole.

The operator deployment itself is straightforward. It's a standard Deployment with one replica, using the operator's ServiceAccount, running a container image with environment variables like WATCH_NAMESPACE, and having appropriate resource requests and limits. You can check what permissions an operator's service account has by finding the ServiceAccount from the deployment, identifying associated ClusterRoles through ClusterRoleBindings, examining the ClusterRole permissions, and using kubectl auth can-i to test specific permissions impersonating the service account.

## Common Operator Use Cases

Operators excel at managing complex stateful applications. Database operators handle PostgreSQL, MySQL, MongoDB, and Redis clusters with automated backup and recovery, replication configuration, version upgrades, scaling, and monitoring integration. Messaging operators manage Kafka, RabbitMQ, and NATS with cluster formation, topic management, security configuration, and monitoring. Storage operators handle Ceph, Rook, and MinIO with volume provisioning, replication, and snapshot management.

Application lifecycle operators are another common category. They deploy complex multi-component applications, manage configuration and secrets, handle rolling updates and rollbacks, provide health monitoring, and scale applications. Certificate management operators like cert-manager automate certificate issuance and renewal, integrate with Let's Encrypt and other CAs, handle certificate rotation, and support multiple DNS providers.

Backup and disaster recovery operators create scheduled backups, support point-in-time recovery, handle cross-region replication, and automate restore procedures. Monitoring and observability operators deploy Prometheus, Grafana, Jaeger, and the ELK stack while configuring dashboards and alerts, managing metrics collection, and handling log aggregation.

## Querying Custom Resources

Basic querying of custom resources uses the same kubectl commands as standard resources. You can list all custom resources of a type, list across all namespaces, list in a specific namespace, get output in different formats like wide, yaml, or json, use short names for convenience, describe specific resources, and get specific fields using jsonpath or custom-columns.

Advanced queries build on these basics. You can filter by labels, filter by field selectors, watch for changes in real time, get events for a custom resource, and use JSONPath queries to find specific items or filter based on spec values.

Many operators update the status subresource, and checking this status is important for understanding the state of your resources. You can get the full status, check specific status fields, and wait for conditions which is particularly useful in automation scripts. Status conditions follow a standard Kubernetes pattern with a type like Ready, a status of True, False, or Unknown, a lastTransitionTime timestamp, a machine-readable reason, and a human-readable message. Common condition types include Ready indicating the resource is operational, Progressing showing creation or update in progress, Degraded indicating partial functionality, and Available showing the resource can serve traffic.

## Troubleshooting Operators

When troubleshooting operators, start by checking the custom resource itself with get and describe commands. Check the resource status and conditions looking for error messages or phases. View events related to the resource. Verify the spec is valid by using kubectl explain to check required fields and validation rules.

Next check the operator pod. Find the operator deployment or pod, check that the operator pod is running, examine operator logs for errors or reconciliation messages, and look for permission denied errors indicating RBAC issues. Check managed resources by listing what the operator should have created like deployments, statefulsets, services, and pvcs. Describe these resources to find issues and check their events.

Verify RBAC permissions by finding the ServiceAccount the operator uses, checking ClusterRole permissions, verifying ClusterRoleBinding exists, and testing permissions with kubectl auth can-i impersonating the service account. Check the CRD itself by listing CRDs, describing the CRD to verify schema, checking if the CRD has validation rules, and verifying the resource version matches what your custom resource uses.

Common failure reasons include ImagePullBackOff from wrong image names or missing registry authentication, CrashLoopBackOff when the operator container keeps failing usually from configuration errors or missing dependencies, Pending state when the operator can't be scheduled due to resource constraints or node selectors, custom resource validation errors from invalid spec fields or missing required fields, RBAC permission denied errors when the operator lacks permissions for required operations, missing CRD issues when trying to create a custom resource before the CRD is installed, and operator not watching when the WATCH_NAMESPACE environment variable is misconfigured or the operator isn't running.

## Updating Custom Resources

You can update custom resources using several approaches. You can edit interactively with kubectl edit, use kubectl apply with updated YAML files, patch specific fields with kubectl patch using merge or json patches, or use kubectl scale if the CRD has the scale subresource enabled.

When patching is particularly useful during the exam because it's faster than editing full YAML, you can update specific fields, change multiple fields at once, use strategic merge patches for simple updates, use JSON patches for complex updates, or update the status subresource separately if enabled. Just make sure you verify updates completed successfully by checking the resource again, verifying the status, confirming managed resources updated, and watching for errors in the operator logs.

## Deleting Custom Resources and CRDs

Deleting custom resources is straightforward using kubectl delete with the resource type and name. The operator watches for deletion and cleans up managed resources like deployments, services, configmaps, and pvcs. You should verify cleanup by checking that managed resources are removed. Some operators use finalizers which may delay deletion while cleanup occurs.

Deleting CRDs is more involved and order matters. First delete all custom resources of that type because deleting the CRD will delete all instances. Make sure the operator is still running to handle cleanup, then delete the CRD itself and verify managed resources are cleaned up. Finally delete the operator deployment and associated RBAC resources. If you delete the CRD before deleting custom resources, Kubernetes immediately deletes all custom resource instances, but if the operator isn't running they won't be cleaned up properly, and you may have orphaned resources.

When operators use finalizers, the custom resource enters a terminating state, the operator performs cleanup tasks, the operator removes its finalizer from the resource metadata, and Kubernetes completes the deletion. If an operator is not running, resources with finalizers will hang in terminating state. You can force deletion by removing finalizers manually, but be aware this may leave orphaned resources.

## Lab Exercises

The lab exercises combine multiple concepts in realistic scenarios testing your ability to work quickly and accurately. The first exercise asks you to create a complete CRD for a Website resource including proper metadata and group naming, a schema with domain, replicas, and SSL fields, validation rules for domain format and replica limits, additional printer columns showing key information, and both plural and singular names plus short names. After creating the CRD, you create multiple website resources, query them with various methods, test the validation by trying invalid values, update existing websites, and finally cleanup by deleting resources and the CRD.

The second exercise asks you to inspect an operator by deploying it, identifying all CRDs it installs, checking its RBAC permissions thoroughly, examining its deployment configuration, viewing its logs, and creating a custom resource to watch what happens. This tests your ability to understand an unfamiliar operator.

The third exercise focuses on troubleshooting a broken custom resource. You deploy a CRD and attempt to create a resource that fails validation. You must investigate the error, use kubectl explain to understand requirements, fix the validation issues, verify the corrected version works, and understand what was wrong. The fourth exercise has you upgrade an application via an operator by creating an initial cluster, verifying the current version, performing an upgrade by patching the custom resource, watching the operator perform the upgrade, verifying completion, and understanding how to rollback if needed.

## Common CKAD Scenarios

Let me walk through typical exam scenarios with solutions. For listing and describing CRDs, the task might be to list all CRDs in the cluster and describe a specific one. You use kubectl get crd, kubectl describe crd with the full name, kubectl explain to understand the schema, and kubectl api-resources to see available versions.

For creating a custom resource, you might need to create a Backend resource with specific properties. You first explain the backend spec, create YAML with proper apiVersion including the group, verify with dry-run, then apply and confirm creation. For updating a custom resource, use kubectl patch for single field changes, kubectl edit for interactive editing, or kubectl apply for full updates, then verify the change took effect.

For troubleshooting an operator-managed application, you check the custom resource status, verify the operator pod is running, check operator logs for errors, list managed resources the operator should have created, and check RBAC if you see permission errors. For finding resources managed by an operator, you describe the custom resource to see owner references, check for labels applied by the operator, use kubectl get all with label selectors, and verify finalizers if resources aren't deleting.

For scaling an operator-managed application, check if the CRD has scale subresource enabled, use kubectl scale if available, otherwise patch the replicas field, then verify the operator updates managed resources accordingly. For querying custom resources, use label selectors to filter, use jsonpath to extract specific fields, wait for conditions in automation, and check status subresource for current state.

## Best Practices for CKAD

For time management during the exam, use kubectl explain to understand CRD structure quickly, use kubectl get with custom-columns to view specific fields, leverage short names to save typing, use patch instead of edit for simple changes, and practice creating custom resources from memory.

Must-know commands include kubectl get crd to list definitions, kubectl explain to understand schemas, kubectl get with resource type for custom resources, kubectl describe for detailed information, kubectl patch for updates, kubectl wait for conditions, and kubectl auth can-i to check permissions. You should be comfortable with jsonpath for extracting fields, label selectors for filtering, and checking status subresources.

Key concepts to memorize are that CRDs extend the Kubernetes API with new resource types, custom resources are instances of CRDs, operators equal CRDs plus controllers, controllers watch resources and reconcile state continuously, status subresources separate desired state from observed state, validation rules are enforced by the API server before storage, operators need RBAC permissions to manage resources, finalizers delay deletion until cleanup completes, and scale subresources enable kubectl scale and HPA integration.

Common requirements to recognize include CRD names must be plural.group format, apiVersion in custom resources must include the group, required fields must be present or validation fails, operators run as deployments with service accounts, custom resources use standard kubectl commands, and deleting CRDs deletes all custom resource instances.

## Quick Reference Commands

Let me show you the essential commands for the exam. For CRDs, list them with kubectl get crd, describe with kubectl describe crd, check the schema with kubectl explain, and view API resources with kubectl api-resources. For custom resources, list with kubectl get using the resource type, describe with kubectl describe, create with kubectl apply, update with kubectl patch, delete with kubectl delete, and scale with kubectl scale if the subresource is enabled.

For querying, filter by labels, use jsonpath for field extraction, output to yaml or json for full details, use custom-columns for specific fields, and watch for changes with the watch flag. For troubleshooting, check resource status, view operator logs, describe the resource for events, verify RBAC permissions, and check if managed resources exist. For operators specifically, find the operator pod, check its logs, verify RBAC configuration, and test permissions with kubectl auth can-i.

## Cleanup

When you're finished with the exercises, cleanup in the proper order. Delete all custom resources first so operators can clean up managed resources. Verify managed resources are removed. Then delete the CRDs which will remove any remaining custom resource instances. Finally delete the operator deployments and RBAC resources.

## Next Steps

That completes our CKAD preparation for Kubernetes Operators and Custom Resources. You now have the knowledge and hands-on experience needed for this topic on the CKAD exam. The key is understanding that you're working with operators as a user, not building them as a developer. Focus on creating and managing custom resources, querying them effectively, understanding operator-managed applications, and troubleshooting when things go wrong.

Practice these scenarios multiple times until they become muscle memory. Set yourself time-based challenges to build speed. Remember that kubectl explain is your friend during the exam since it's available and provides documentation about CRD schemas. Work with different operators to get comfortable with the pattern. Master the troubleshooting workflow because you'll need it when dealing with unfamiliar CRDs. Understand the relationship between CRDs, custom resources, operators, and the resources they manage. Most importantly, get comfortable with the kubectl commands for working with custom resources because they're the same as for standard resources but with custom types.

The operator pattern is one of Kubernetes' most powerful extensibility mechanisms. While building operators is beyond CKAD scope, using them effectively is a required skill. With practice, working with custom resources will become as natural as working with pods and deployments.
