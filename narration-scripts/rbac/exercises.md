# Role-Based Access Control - Exercises Narration Script

Welcome to the hands-on portion of our RBAC training. In this demonstration, we'll work through practical scenarios that show Role-Based Access Control in action. We'll deploy applications, grant them API access, troubleshoot permission issues, and implement security best practices.

Kubernetes supports fine-grained access control, allowing you to decide who has permission to work with resources in your cluster and what they can do with them. There are two parts to RBAC that work together to provide this flexibility. Roles define access permissions for resources like Pods and Secrets, allowing specific actions like create and delete. RoleBindings grant the permissions in a Role to a subject, which could be a kubectl user or an application running in a Pod. This decoupling of permissions from subjects lets you model security with a manageable number of objects.

By the end of this session, you'll have seen real examples of creating ServiceAccounts, Roles, and RoleBindings, and you'll understand how to verify that permissions are working correctly.

## Do this first if you use Docker Desktop

Before we begin, there's an important note for those using Docker Desktop. Older versions have a bug in the default RBAC setup that prevents permissions from being applied correctly. If you're using Docker Desktop version 4.2 or earlier, you'll need to run a fix script first before any of the RBAC demonstrations will work properly.

The fix involves running a shell script on Mac or WSL2, or a PowerShell script on Windows. Docker Desktop version 4.3.0 and later fixed this issue, so if you see an error about the docker-for-desktop-binding not being found, that's actually good news because it means your version doesn't have the bug and you're ready to proceed.

## Securing API access with Service Accounts

Authentication for end-user access is managed outside of Kubernetes, so we'll focus on RBAC for internal cluster access, specifically for applications running inside Kubernetes. We'll work with a simple web application that connects to the Kubernetes API server to get a list of Pods, display them, and allow you to delete them.

First, we need something to display, so we'll create a sleep Deployment to give us a Pod to view in the application. This sleep Pod will just run continuously, giving us a stable target for our demonstrations. Now let's look at the initial specification for the web app. It doesn't include any RBAC rules yet, but it does include a specific security account for the Pod. The deployment YAML creates a ServiceAccount and sets the Pod spec to use that ServiceAccount rather than the default one.

This is an important pattern to understand. By creating a dedicated ServiceAccount, we're establishing a unique identity for this application. Each application should have its own ServiceAccount rather than sharing the default one, which is a security best practice. When we deploy the resources in the kube-explorer directory, Kubernetes creates the ServiceAccount, starts the Deployment with one Pod, and sets up Services for accessing the app.

Let's browse to the application and see what happens. We immediately see an error message. The app is trying to connect to the Kubernetes REST API to get a list of Pods, but it's getting a 403 Forbidden error. This is RBAC in action, demonstrating the difference between authentication and authorization.

Kubernetes automatically populates an authentication token in the Pod, which the app uses to connect to the API server. When we print all the details about the kube-explorer Pod, we can see a volume mounted at the standard path for service account information. This volume mount isn't in our Pod spec explicitly because it's a Kubernetes default behavior to add it automatically. Every Pod gets this mount unless we explicitly disable it.

When we look at the actual token file inside the container, we see a JWT token. This is the authentication token for the Service Account, so Kubernetes knows the identity of the API user. The app is authenticated, meaning the API server knows who it is, but the account is not authorized to list Pods. This is a crucial security principle in Kubernetes: all security principals, whether ServiceAccounts, Groups, or Users, start off with no permissions and need to be explicitly granted access to resources.

We can check the permissions of any user or ServiceAccount with the auth can-i command. When we check whether the kube-explorer ServiceAccount can get pods in the default namespace, the command returns no. The ServiceAccount ID in these commands includes both the namespace and name, following the format system:serviceaccount:namespace:name.

RBAC rules are applied when a request is made to the API server, so we can fix this app by deploying a Role and RoleBinding. The Role specification creates permissions to list and delete Pods in the default namespace. Looking at the YAML, we see it contains rules that define what actions are allowed. Each rule secures access to one or more types of resources, specifying the API groups, the resource types, and the verbs or actions allowed.

The RoleBinding applies the new Role to the app's Service Account, connecting the permissions we defined to the identity we created. When we deploy these rules and verify the Service Account permissions again, we now get a yes response. Refreshing the website, we can now see the Pod list. We can even delete the sleep Pod, and when we return to the main page, we see a replacement Pod created by the ReplicaSet. This demonstrates that our RBAC configuration is working correctly and the application has the permissions it needs.

## Granting cluster-wide permissions

The role binding we created restricts access to the default namespace. The same ServiceAccount can't see Pods in other namespaces like kube-system. When we check if the kube-explorer account can get Pods in the kube-system namespace, it returns no as expected.

We could grant access to Pods in each namespace with more Roles and RoleBindings, but if we want permissions to apply across all namespaces, we can use a ClusterRole and ClusterRoleBinding instead. These work similarly to namespace-scoped resources but operate at the cluster level.

The ClusterRole sets Pod permissions for the entire cluster, and you'll notice there's no namespace in the metadata section because it's cluster-scoped. The ClusterRoleBinding applies the role to the app's ServiceAccount. An important security consideration here is that we're only granting read permissions at the cluster level. The verb list includes get, list, and watch, but not delete. This follows the principle of least privilege, where we give broader read access but keep write and delete operations restricted to specific namespaces.

After deploying the cluster rules, we can verify that the ServiceAccount can now get Pods in the system namespace, but when we check delete permissions, it still returns no. This demonstrates how we can have different permission levels in different scopes. The app has full management capabilities in the default namespace but read-only access cluster-wide.

When we browse to the app with a namespace parameter in the query string, pointing to kube-system, the app can now see Pods in that namespace. RBAC permissions are finely controlled at the resource type level, so even though the app can see Pods, if we click the Service Accounts link, we get the 403 Forbidden error again because we haven't granted permissions for that resource type.

## Common Pod-to-API-Server Access Patterns

Understanding how Pods access the Kubernetes API is critical for working with Kubernetes day to day. There are several common patterns you'll encounter repeatedly. The first pattern involves creating a ServiceAccount for an application using imperative commands, which is the fastest approach. You create the ServiceAccount, create a Role with the needed permissions, bind the Role to the ServiceAccount, and then reference the ServiceAccount when creating the Pod or Deployment.

The second pattern addresses apps that need to read configuration dynamically. Many applications need to access ConfigMaps and Secrets at runtime through the API rather than having them mounted as volumes or environment variables. For these cases, you create a Role that grants get and list permissions on configmaps and secrets, then bind it to your application's ServiceAccount.

The third pattern actually involves disabling ServiceAccount functionality for security. Most apps don't need API access at all, so mounting the token unnecessarily increases your attack surface. If an attacker compromises your container, they could potentially use that token to query or modify cluster resources. You can disable automatic token mounting either at the Pod level or at the ServiceAccount level, with the ServiceAccount level being preferred because it applies to all Pods using that account.

The fourth pattern handles cross-namespace access, where apps sometimes need to access resources in other namespaces. You create the Role in the target namespace with the required permissions, then create a RoleBinding in that same target namespace, but specify the ServiceAccount from the different namespace in the subjects section. This gives precise control over which applications can access resources in which namespaces.

## RBAC Troubleshooting

Troubleshooting RBAC issues is a common task in Kubernetes operations. When you encounter 403 Forbidden errors in Pod logs, you need a systematic approach to diagnose and fix the problem. The first step is checking if the ServiceAccount exists and identifying which one the Pod is actually using. Many times, Pods are inadvertently using the default ServiceAccount which has no permissions.

Next, you check what the ServiceAccount can actually do using the auth can-i command. This tells you immediately whether the permissions are missing entirely or just misconfigured. Then you list all roles and rolebindings in the namespace to see what RBAC resources exist. Once you identify the gap, the solution typically involves creating the missing Role with appropriate permissions or creating the missing RoleBinding to connect the Role to the ServiceAccount.

Another common symptom is when a Pod is using the wrong ServiceAccount. You might think the Pod has permissions, but when you check which ServiceAccount it's actually using, you find it's not the one you configured. The describe command shows this clearly in the Service Account field. The fix involves updating the Deployment to use the correct ServiceAccount, which you can do with the set serviceaccount command. This is much faster than editing YAML and waiting for the rollout.

When permissions work in one namespace but not another, you need to check whether you're using namespace-scoped or cluster-scoped RBAC resources. The auth can-i command with different namespace flags quickly reveals whether permissions are namespace-specific. You have two solution options depending on your security requirements. For limited access, create Role and RoleBinding resources in each target namespace. For broader access, use ClusterRole and ClusterRoleBinding to grant cluster-wide permissions, though this should be done carefully following the principle of least privilege.

Sometimes the ServiceAccount token isn't mounted in the Pod at all, causing connection failures to the API server. This can happen if token mounting was disabled either at the ServiceAccount level or the Pod level. You can check the automountServiceAccountToken field on both resources to diagnose this. If your application legitimately needs API access, you need to enable token mounting, though for most applications, you actually want it disabled for security.

A subtle issue that catches many people is using the wrong API group in Role specifications. If you grant permissions but they still don't work, checking whether the API group matches the resource type is crucial. The api-resources command shows you the correct API group for each resource type. Core resources like Pods, Services, ConfigMaps, and Secrets use an empty string for the API group. Deployments, StatefulSets, and DaemonSets use the apps group. Jobs and CronJobs use the batch group. Ingress resources use the networking.k8s.io group. Getting this wrong means your Role permissions won't match the actual API requests.

## Lab

Now you'll get some practice working with RBAC yourself. You need to be familiar with these concepts because you'll certainly have restricted permissions in production clusters, and if you need new access, you'll get it more quickly if you can provide the admin with the exact Role and RoleBinding specifications you need.

Your first challenge is to deploy new RBAC rules so the ServiceAccount view in the kube-explorer app works correctly for objects in the default namespace. Currently, when you click the Service Accounts link, you get a 403 error because the kube-explorer ServiceAccount doesn't have permissions to view ServiceAccounts. You need to create a Role that grants the appropriate permissions and bind it to the kube-explorer ServiceAccount.

The second part of the lab addresses a security best practice. Mounting the ServiceAccount token in Pods is default behavior, but most apps don't actually use the Kubernetes API server. Having the token mounted is a potential security issue because if an attacker compromises your container, they could use that token. Your task is to amend the sleep Pod so it doesn't have a token mounted. This involves setting the automountServiceAccountToken field to false in the Pod specification.

## Cleanup

Before finishing, we need to clean up all the resources we created during this demonstration. We can delete Pods, Deployments, Services, ServiceAccounts, Roles, RoleBindings, ClusterRoles, and ClusterRoleBindings all in one command by using labels. Since all our lab resources are labeled with kubernetes.courselabs.co equals rbac, we can select them all with a label filter. This removes everything associated with this lab, leaving our cluster in a clean state ready for the next exercise.

These patterns form the foundation of application security in Kubernetes. You've seen how to create dedicated ServiceAccounts for applications, how to grant namespace-scoped permissions with Roles and RoleBindings, how to extend access cluster-wide with ClusterRoles and ClusterRoleBindings, how to troubleshoot RBAC issues using the auth can-i command, and how to improve security by disabling token mounting for applications that don't need API access. Practice creating these resources both declaratively with YAML and imperatively with kubectl commands, as both approaches are valuable in different situations.
