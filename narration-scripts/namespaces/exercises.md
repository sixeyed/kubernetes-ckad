# Namespaces - Exercises Narration Script

Welcome back! In the previous video, we covered the concepts behind Kubernetes namespaces. Now it's time to get hands-on and explore how namespaces work in practice. In this demo, we'll explore system namespaces, learn context switching, create our own namespaces, and see how they provide resource isolation and quotas.

Make sure you have a Kubernetes cluster running and kubectl configured. I'm using Docker Desktop, but any Kubernetes distribution will work fine. Let's dive in and see how namespaces organize and isolate workloads in a cluster.

## API specs

Before we start creating namespaces, let's understand what they are. Kubernetes uses declarative configuration with YAML files. The basic YAML for a namespace is extremely simple. We specify the API version as v1, the kind as Namespace, and metadata with just a name. That's really all you need for a basic namespace. It needs a name, and then for every resource you want to create inside the namespace, you add the namespace name to that object's metadata. Namespaces can't be nested, so it's a single-level hierarchy used to partition the cluster.

## Creating and using namespaces

The core components of Kubernetes itself run in Pods and Services, but you don't see them in kubectl because they're in a separate namespace. Let's start by checking what Pods exist in our default namespace. As expected, nothing is there yet. Now let's list all namespaces. You'll see several system namespaces that every Kubernetes cluster has. There's the default namespace where we've been working, the kube-system namespace containing system components, kube-public for publicly accessible resources, and kube-node-lease for node heartbeat data.

Let's explore what's running in the kube-system namespace. The minus n flag tells kubectl which namespace to use. If you don't include it, commands use the default namespace. You'll see various system components depending on your Kubernetes distribution, but it should include a DNS server Pod. You can work with system resources in the same way as your own apps, but you need to include the namespace in the kubectl command.

Let's try printing the logs of the system DNS server. First, I'll try without specifying the namespace. That failed! The DNS server is in kube-system, not default. Now let's fix it by adding the namespace flag. There we go, we can see the DNS server logs. The namespace flag is essential when working across namespaces.

Adding a namespace to every command gets tedious. Kubernetes has contexts to let you set the default namespace for commands. Let's look at our current context. The context includes which cluster to connect to, authentication credentials, and the default namespace for commands. Contexts are how you switch between clusters too, and the cluster API server details are stored in your kubeconfig file.

You can update the settings for your context to change the namespace. Let's switch our default namespace to kube-system. All kubectl commands now work against the cluster and namespace in the current context. Let's print some Pod details. Notice we didn't specify minus n, but we see system Pods. Our context now defaults to kube-system. We can also print the logs without the namespace flag. It's dangerous to work in system namespaces though, so we should always switch back. Develop this habit: switch context for focused work, but always return to default when done.

## Deploying objects to namespaces

Object specs can include the target namespace in the YAML, but if it's not specified, kubectl decides the namespace using the default for the context or an explicit namespace flag. Let's look at the sleep Pod specification. This defines a Pod with no namespace, so kubectl decides where it goes. We can deploy this Pod spec to the default namespace and then to the system namespace using different namespace flags. Now when we list Pods across all namespaces with the all-namespaces flag, we see both sleep Pods in different namespaces. Same Pod name, same labels, but they don't conflict because namespaces provide isolation.

Namespace access can be restricted with access controls, but in your dev environment you'll have cluster admin permissions so you can see everything. If you're using namespaces to isolate applications, you'll include the namespace spec with the model and specify the namespace in all the objects. Let's look at the whoami application specs. There's a namespace definition file, a deployment for the namespace, and services where the label selectors only apply to Pods in the same namespace as the Service.

Kubectl can deploy all the YAML in a folder, but it doesn't check the objects for dependencies and create them in the correct order. Mostly that's fine because of the loosely-coupled architecture. Services can be created before a Deployment and vice-versa. But namespaces need to exist before any objects can be created in them, so the namespace YAML is called zero one underscore namespace.yaml to ensure it gets created first. Kubectl processes files in order by filename. After applying the whoami specs, we can see the services in the whoami namespace.

Using namespaces to group applications or environments means your top-level objects don't need so many labels. You'll work with them inside a namespace, so you don't need labels for filtering. Let's deploy another app where all the components will be isolated in their own namespace. The configurable app has a namespace definition, a ConfigMap with app settings, and a Deployment which references the ConfigMap. Config objects need to be in the same namespace as the Pod. After deploying the app, we can list Deployments in all namespaces showing labels. The show-labels flag displays all labels for each resource.

You can only use kubectl with one namespace or all namespaces, so you might want additional labels for objects like Services so you can list across all namespaces and filter by label. Let's query Services across all namespaces that match the lab label. This shows Services from multiple namespaces that share the same label. Labels work across namespace boundaries, but label selectors within resources only work within the same namespace. This is an important distinction: a Service in the whoami namespace can only select Pods in the whoami namespace, even if matching Pods exist in other namespaces.

## Namespaces and Service DNS

Networking in Kubernetes is flat, so any Pod in any namespace can access another Pod by its IP address. Services are namespace-scoped, so if you want to resolve the IP address for a Service using its DNS name, you can include the namespace. A local domain name like whoami-np will only look for the Service in the same namespace where the lookup runs. A fully-qualified domain name like whoami-np.whoami.svc.cluster.local will look for the Service in the whoami namespace regardless of where you run the lookup.

Let's run some DNS queries inside the sleep Pod. First, let's try looking up whoami-np without the namespace. That won't return an address because the Service is in a different namespace. Now let's include the namespace in the lookup. This includes the namespace, so it returns an IP address. As a best practice, you should use fully-qualified domain names to communicate between components. It makes your deployment less flexible because you can't change the namespace without also changing app config, but it removes a potentially confusing failure point.

## Applying resource limits

Namespaces aren't just for logically grouping components, you can also enforce quotas on a namespace to limit the resources available. This ensures apps don't use all the processing power of the cluster, starving other apps. Resource quotas and limit ranges at the namespace level work together with resource limits and requests at the Pod level. Let's deploy the Pi-calculating web app, which is compute-intensive. To keep our cluster usable for other apps, we'll deploy it in a new namespace with a CPU quota applied.

The specs include a quota which sets a total limit of four CPU cores across all Pods in the namespace, and a Deployment with one Pod that has a limit of one hundred twenty-five millicores, which is zero point one two five of one core. Resource requests specify how much memory or CPU the Pod would like allocated when it is created. Resource limits specify the maximum memory or CPU the Pod can access. There's no Nginx proxy for this release of the Pi app and the CPU allocation is very small, so the calculations will be slow.

After deploying, we can check the quota and verify the Pod is running. When we try the app at the NodePort URL, on my machine it takes about ten and a half seconds to respond. Not every dev Kubernetes setup enforces CPU limitations. You might not see the app responding slowly if you're using Kind or Minikube. Docker Desktop and k3d do enforce them, and so do all the production Kubernetes platforms.

Let's speed it up by bumping the processing power to two and a half CPU cores. After updating the app, we can check the resources set in the Pod using describe. When we refresh the app, on my machine it now takes about one point two seconds to respond. Much faster! Now let's try to go to the max. We'll set a limit of four and a half CPU cores, which is greater than the quota for the namespace. After applying the update, let's check the ReplicaSets. The new ReplicaSet never scales up to the desired count. When we describe it, you'll see a nice, clear error telling you that the quota has been exceeded. Kubernetes will keep trying, in case the quota changes or resources are freed up.

## Lab

That Pi service takes too long to run, and it performs better when you run it with a reverse proxy to cache the responses. The lab asks us to add a caching proxy in front of the Pi app, and the ops team wants all proxies in a namespace called front-end. You can use the reverse proxy setup from the specs as a starting point, but those specs don't include a namespace. We need to create the front-end namespace, add namespace references to all resources, and fix the proxy configuration to point to the Pi service in the pi namespace using a fully-qualified domain name. When you browse to the proxy endpoint, you'll find an error because the configuration needs to be fixed. The proxy configuration needs to point to the correct service URL using the FQDN pattern. Remember that ConfigMaps must be in the same namespace as the Pods that use them, and service URLs must use fully-qualified domain names for cross-namespace access.

## Cleanup

Namespaces make cleanup easy. Just delete the namespace and all its resources are removed. We can delete the labeled namespaces, and they're gone, along with all their resources. Don't forget the sleep Pods we created in multiple namespaces. We can delete those across all namespaces using the all-namespaces flag with the label selector. Our cluster is clean again and ready for the next lab.

That wraps up our hands-on exploration of namespaces. We've seen how to create and switch between namespaces, how namespace isolation works, how to access services across namespaces using DNS, and how resource quotas limit consumption at the namespace level. These patterns are essential for multi-tenant clusters, environment separation, resource management, and team isolation. In the next video, we'll dive deeper into CKAD-specific scenarios including imperative namespace commands, working with ResourceQuotas under time pressure, quick context switching techniques, and common exam patterns with namespaces.
