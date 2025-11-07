# Services - Exercises Narration Script

**Duration:** 15-20 minutes
**Format:** Screen recording with live demonstration
**Prerequisite:** Kubernetes cluster running (Docker Desktop, k3d, or similar)

---

Welcome back! In the previous video, we covered the concepts behind Kubernetes Services. Now it's time to get hands-on and explore how Services provide stable networking for Pods.

Services solve a fundamental problem in Kubernetes. Every Pod has an IP address, but that IP address only applies for the life of the Pod. Replace the Pod and the new one will have a different IP address. Services provide a consistent IP address linked to a DNS name, so you can send traffic to a name rather than an IP address. You'll always use Services for routing internal and external traffic into Pods.

## API specs

Let's start by looking at the YAML structure for Services. I'll open the whoami-clusterip.yaml file in the labs/services/specs directory. This Service definition has the usual metadata with a name, and the spec needs to include the network ports and the label selector.

The selector is a list of labels to find target Pods. In this case, it's looking for Pods with the label app equals whoami. The ports section is a list of ports to listen on, with each port having a name within Kubernetes, a port that the Service listens on, and a targetPort where traffic gets sent on the Pod.

Now let's look at how Pods need to be configured to work with Services. I'll open the whoami Pod YAML. Pods need to include matching labels to receive traffic from the Service. Labels are specified in the object metadata, right here where you see the labels section with app colon whoami. Labels are arbitrary key-value pairs used for storing small pieces of useful data. You can use any keys you like, though app, component, and version are typically used for application Pods.

## Run sample Pods

Let's start by creating some simple Pods from definitions which contain labels. We have two Pod specs here, whoami and sleep, both in the labs/services/specs/pods directory. I'll deploy both at once by applying the entire directory. You can work with multiple objects and deploy multiple YAML manifests with kubectl by pointing to a directory.

Now let's check the status for all Pods, printing all the IP addresses and labels. I'll use the wide output and show-labels flags. See how each Pod has its own IP address and the whoami Pod has the label app equals whoami? This label is crucial for Service selection.

Here's something interesting about Pod networking. The Pod name has no effect on networking. Pods can't find each other by name. Let me demonstrate by running a DNS lookup inside the sleep Pod to find the whoami Pod. As you can see, it fails. The whoami name doesn't resolve because Pods don't automatically get DNS entries.

## Deploy an internal Service

Kubernetes provides different types of Service for internal and external access to Pods. ClusterIP is the default and it means the Service gets an IP address which is only accessible within the cluster. It's for components to communicate internally.

Let's deploy the Service from the whoami-clusterip.yaml file. The Service is created successfully. Now let's print its details with get service and describe. The get and describe commands are the same for all objects. Services have the alias svc if you want to save some typing.

Look at the output. The Service has its own IP address, and that is static for the life of the Service. This IP won't change unless we delete the Service itself.

## Use DNS to find the Service

Kubernetes runs a DNS server inside the cluster and every Service gets an entry, linking the IP address to the Service name. Now if I do the same DNS lookup from the sleep Pod, looking up whoami, you'll get a response! This gets the IP address of the Service from its DNS name. Notice the first IP address shown is the Kubernetes DNS server itself.

Now the Pods can communicate using DNS names. Let me curl the whoami Service from the sleep Pod. Beautiful! The sleep Pod successfully contacted the whoami application through the Service.

Let's demonstrate why this is so powerful. I'll recreate the whoami Pod and the replacement will have a new IP address, but the Service resolution with DNS will still work. First, let me check the current IP address, then delete the Pod using a label selector. You can use label selectors in kubectl too, which makes labels a powerful management tool.

Now I'll create a replacement Pod and check its IP address. See that? Different IP address. But watch what happens when I do that DNS lookup and curl again. The Service IP address doesn't change, so if clients cache that IP they'll still work. The Service automatically routes traffic to the new Pod, even though the Pod IP changed.

## Understanding external Services

There are two types of Service which can be accessed outside of the cluster: LoadBalancer and NodePort. They both listen for traffic coming into the cluster and route it to Pods, but they work in different ways.

LoadBalancers are easier to work with, but not every Kubernetes cluster supports them. LoadBalancer Services integrate with the platform they're running on to get a real IP address. In a managed Kubernetes service in the cloud, you'll get a unique public IP address for every Service, integrated with a cloud load balancer to direct traffic to your nodes. In Docker Desktop the IP address will be localhost, and in k3d it will be a local network address.

NodePorts don't need any external setup so they work in the same way on all Kubernetes clusters. Every node in the cluster listens on the specified port and forwards traffic to Pods. The external port number must be at least thirty thousand, which is a security feature so Kubernetes components don't need to run with elevated privileges on the node.

In this course we deploy both LoadBalancers and NodePorts for all our sample apps so you can follow along whichever Kubernetes distribution you're using.

## Deploy an external Service

Let's deploy both Service types. Here are two Service definitions to make the whoami app available outside the cluster. The whoami-nodeport.yaml is for clusters which don't support LoadBalancer Services, and whoami-loadbalancer.yaml is for clusters which do. I can deploy both at once by specifying multiple files with the -f flag.

Now let me print the details for both Services. I'll use a label selector since both have the label app equals whoami. If your cluster doesn't have LoadBalancer support, the external IP field will stay at pending forever. That's completely normal.

External Services also create a ClusterIP, so you can access them internally from Pods. You always need to use the Service port for communication. Let me demonstrate by calling the LoadBalancer Service on port 8080 and the NodePort Service on port 8010 from the sleep Pod. Both work! The Services all have the same label selector, so they all direct traffic to the same Pod.

Now you can call the whoami app from your local machine. Depending on whether your cluster supports LoadBalancers, you can either curl localhost on port 8080 for the LoadBalancer, or localhost on port 30010 for the NodePort. If you're not running Kubernetes on your local machine then you'll need to use a different address. Use the node's IP address for NodePort access or the external IP address field for the LoadBalancer.

## Lab

Now it's your turn to experiment. Services are a networking abstraction. They're like routers which listen for incoming traffic and direct it to Pods. Target Pods are identified with a label selector, and there could be zero or more matches.

The lab challenge asks you to create new Services and whoami Pods to test these scenarios. First, create a scenario where zero Pods match the label spec. Second, create a scenario where multiple Pods match the label spec. What happens in each case? How can you check if a Service has found any matching Pods to use as targets?

This is critical knowledge for troubleshooting Services in the real world and on the CKAD exam. Take your time and explore both scenarios thoroughly.

## Cleanup

When you're finished with the lab, cleanup is straightforward. Every YAML spec for this lab adds a label kubernetes.courselabs.co equals services. That makes it super easy to clean up by deleting all those resources. Just delete all pods and services with that label selector, and everything from this lab is removed.

That wraps up our hands-on exploration of Services. We've seen how to create ClusterIP Services for internal communication, how DNS makes Services discoverable, how external Services work with NodePort and LoadBalancer types, and how to think about Service endpoints. These are essential skills for working with Kubernetes. In the next video, we'll dive deeper into CKAD-specific scenarios including multi-port Services, headless Services, session affinity, and advanced troubleshooting techniques.
