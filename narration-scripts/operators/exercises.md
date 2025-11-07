# Operators - Exercises Narration Script

**Duration:** 20-25 minutes
**Format:** Screen recording with live demonstration
**Prerequisite:** Kubernetes cluster running, completed Deployments and StatefulSets labs

---

Welcome back! In the previous video, we covered the concepts behind Kubernetes Operators and how they extend Kubernetes capabilities. Now it's time to get hands-on and explore how Operators use Custom Resource Definitions to manage complex applications with operational knowledge built right in.

Before we dive in, I should mention that some operators don't support ARM64 processors, so if you're using Apple Silicon you may encounter issues with certain exercises. Don't worry though, the concepts remain the same regardless of your hardware.

Some applications need a lot of operational knowledge beyond just the complexity of modelling the app in Kubernetes. Think of a stateful application where you want to create backups of data. The application deployment is modelled in Kubernetes resources, and it would be great to model the operations in Kubernetes too. That's exactly what the operator pattern does. It's a loose definition for an approach where you install an application which extends Kubernetes. So in that stateful application, your operator would deploy the app, and it would also create a custom DataBackup resource in the cluster. Any time you want to take a backup, you deploy a backup object, the operator sees the object and performs all the backup tasks. This is automation that lives in the cluster itself.

## Reference

Let's start by understanding what we're working with. Operators typically work by adding Custom Resource Definitions to the cluster, which extend the Kubernetes API with your own object types. We'll be looking at a couple of real-world operators in this session. The NATS Operator helps deploy high-performance message queues, and the Bitpoke MySql Operator manages MySql databases with all the complexity of replication and backup built in. These are production-grade tools that demonstrate the power of the operator pattern.

## Custom Resources

Custom Resource Definitions are actually pretty simple in themselves. You deploy an object which describes the schema of your new resource type. Let me show you a straightforward example. I'll open the student-crd.yaml file. This defines a version one Student resource with email and company fields. The rest of the spec tells Kubernetes to store objects in its database and print out specific fields when objects are shown in kubectl.

You deploy CRDs in the usual way. When I apply this, Kubernetes now understands what a Student is. Let me list all the custom resources in the cluster and print the details of the new Student CRD. The CRD is just the object schema. Kubernetes only stores objects if it understands the type, which is what the CRD describes.

Now your Kubernetes cluster understands Student resources, you can define them with YAML. I have two student files here. One describes a student named Edwin who works at Microsoft, and another describes Priti who works at Google. Let me create all the Students by applying the students folder, then list them and print the details for Priti.

You'll see standard kubectl verbs like get, delete, and describe work for all objects including custom resources. The Student CRD specified additional printer columns, so when we list students we see the company field displayed right there. This is really convenient. If you try to apply this YAML in a cluster which doesn't have the Student CRD installed, you'll get an error because Kubernetes won't understand what a Student is.

## NATS Operator

A CRD itself doesn't do anything beyond letting you store resources in the cluster. Operators typically install CRDs and also run controllers in the cluster. A controller is just an app running in a Pod which connects to the Kubernetes API and watches for CRDs being created or updated. When you create a new custom resource, the controller sees that and takes action, which could mean creating Deployments, Services and ConfigMaps, or running any custom code you need.

NATS is a high-performance message queue which is very popular for asynchronous messaging in distributed apps. The NATS operator runs as a Deployment. Let me install the operator and look carefully at the output. You'll see the operator installs some RBAC objects and the Deployment.

Let me list the custom resource types in the cluster now. We see some NATS types in addition to our Student resource. How did these get created? There's no YAML for these CRDs, so the NATS controller running in the Pod must have created them by using the Kubernetes API in code. I can confirm the RBAC setup gives the controller ServiceAccount permission to do that by checking what the operator's service account can do.

We can use a NatsCluster object to create a clustered, highly-available message queue for applications to use. Let me look at the msgq.yaml file. This defines a cluster with three NATS servers running version two point five. When I create the cluster resource, a single object gets created.

Let me print the details of the new message queue and look at the other objects running in the default namespace. You'll see the operator has created Pods and Services. The operator logs will show how the Pods were created. The output from the CRD doesn't show much detail, but the operator has created Pods and Services. There's no Deployment or ReplicaSet for the message queue Pods though. Let me check the logs and you'll see the operator is managing the Pods directly.

The NATS operator is unusual because it acts as a Pod controller. Typically operators build on top of Kubernetes resources, so they would use Deployments to manage Pods. When I print the details of one of the NATS Pods, you'll see it's controlled by the NatsCluster object, not by a ReplicaSet or StatefulSet.

The NATS operator still provides high availability even though it's managing Pods directly. Let me delete one of the message queue Pods and watch what happens. The operator detects the deletion and creates a new Pod to replace it, maintaining the desired state of three servers. The operator logs show it coming online, demonstrating continuous reconciliation in action.

## MySql Operator

There's not much more we can do with the NATS operator, so let's try one which has some more features. There's a Helm chart for the Presslabs MySql operator in this repository. The values.yaml file defines the default values for the operator, and there is a lot you can tweak here for production deployments.

Let me install the operator using Helm. You'll need the Helm CLI installed for this. The operator pod might restart and take a few minutes to be ready, so I'll watch the status until it's running. What resources do we need to create to deploy a MySql database cluster using the operator? The Helm output gives us an example of what we need. We need a MysqlCluster object, which is a CRD installed by the operator, and we need a Secret containing the admin user password for the database.

You can create a replicated database cluster using the specs I have here. There's a secret with the database password and a cluster definition set to use two MySql servers. Let me create the database and watch what happens. The database Pods take a while to start up. What controller does the operator use, and what's the container configuration in the Pods?

Let me list the Pods and you'll see one called db-mysql-0. That name should suggest that it's managed by a StatefulSet. When I print the Pod details, you'll see multiple containers. The container setup is pretty complex. There are two init containers which look like they set up the database environment and the MySql configuration, the main database container which runs MySql, and three sidecar containers which export database metrics and perform a heartbeat check between the database servers. This is all managed by the operator.

Let me check the logs of the primary database server in Pod zero. You'll see mysqld ready for connections showing the database server is running successfully. And the logs of the secondary database server in Pod one show replication started, indicating the secondary is replicating data from the primary. The operator provides a production-grade deployment of MySql, and it also sets up a CRD for creating database backups and sending them to cloud storage. All of this operational complexity is encoded in the operator.

## Lab

Now it's your turn to experiment with the operators. We'll make use of them to install infrastructure components for a demo app. Start by deleting the existing message queue and database clusters. The operators are watching for resources to be deleted, and will remove all the objects they created. This is proper cleanup through the operator pattern.

Now deploy a simple to-do list application using the specs in the todo-list folder. The app has a website listening on port 30028 which posts messages to a queue when you create a new to-do item. A message handler listens on the same queue and creates items in the database. Browse to the app now and you'll see an error because the components it needs don't exist yet.

The challenge is to create NatsCluster and MysqlCluster objects matching the config in the app to make everything work correctly. Look at the application configuration to understand what service names and settings it expects. You'll need to create a NATS cluster with the right name so the service gets created with the name the app expects, and similarly for the MySql cluster. Think about how the operators create Services based on the custom resource names, and how those Services need to match what the application is looking for.

## Cleanup

When you're finished with the lab, cleanup is important and the order matters. Delete the basic objects and CRDs first. Deleting CRDs deletes custom resources, so make sure the controller still exists to tidy up. Then delete the NATS operator. Finally delete the MySql CRD and operator using kubectl and Helm.

That wraps up our hands-on exploration of Operators. We've seen how Custom Resource Definitions extend Kubernetes with new resource types, how Operators combine CRDs with controllers to provide automation, how operators can manage complex applications like message queues and databases with all the operational knowledge built in, and how custom resources are managed just like standard Kubernetes resources. The operator pattern is powerful for encoding operational expertise into Kubernetes itself. In the next video, we'll focus on CKAD-specific requirements for working with Custom Resource Definitions and operator-managed applications, since understanding CRDs is part of the exam scope.
