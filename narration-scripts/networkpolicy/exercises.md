# Network Policy - Exercises Narration Script

Welcome to the practical Network Policy exercises. In this session, we'll work hands-on with Kubernetes Network Policy to secure a real distributed application. We'll see how network policies control traffic flow between Pods and learn to implement proper security boundaries in a Kubernetes cluster.

We'll be working with the APOD application, which stands for Astronomy Picture of the Day. This is a three-tier distributed application that demonstrates realistic communication patterns between components. It consists of a web frontend that users interact with, an API service that fetches astronomy data from NASA's public API, and a logging service that records user activity. Through securing this application, you'll learn the essential patterns for implementing network policies in production environments.

## Deploy the APOD application

Let's start by understanding what we're deploying. The application consists of three separate components, each with its own Deployment and Service. The specifications are straightforward Kubernetes manifests without any special networking configuration initially. The API component provides REST endpoints to fetch information about the astronomy picture. The log component is another REST API that records information about application usage. The web application consumes both of these REST APIs and presents the picture of the day to users. The web component is published externally using a NodePort Service on port thirty thousand sixteen.

When we deploy these resources, Kubernetes creates all three Deployments and their associated Services. We need to wait for all the Pods to become ready before testing the application. This usually takes about thirty seconds to a minute depending on whether the container images are already cached locally. Once all Pods show as running and ready, we can browse to the application on localhost port thirty thousand sixteen. The application should load successfully, showing the astronomy picture with its description. The web frontend is successfully communicating with both the API and log services. This demonstrates the default Kubernetes networking behavior where all Pods can freely communicate with each other.

Take note of this working state because we're about to change it dramatically. In a default Kubernetes cluster, networking is completely flat. Every Pod can reach every other Pod without any restrictions. This makes it easy to build and test applications, but it creates security gaps. There's no network segmentation, and applications can potentially access resources they shouldn't.

Now let's enforce a deny-all network policy. The specification uses an empty podSelector, which means it applies to all Pods in the namespace. There are no ingress or egress rules defined, which creates a complete traffic block. Understanding why this blocks everything is crucial. Network policies are additive, similar to RBAC rules. Subjects start with no permissions, and you explicitly grant what's needed. This policy specifies both ingress and egress in the policyTypes field, but provides no rules for either direction. The result is a policy that allows nothing, effectively blocking all incoming and outgoing communication for all Pods.

When we apply this deny-all policy and check the network policies, we see it was created successfully. We can use the shorthand "netpol" instead of typing out "networkpolicies" each time. This policy should block all traffic, preventing the web app from communicating with the APIs. However, something interesting happens when we refresh the application in the browser. In most cases, the app still works perfectly fine.

Why does the application continue functioning despite our deny-all policy? The answer is that most Kubernetes clusters don't actually enforce network policy. Docker Desktop, which many developers use, doesn't have a CNI plugin that supports network policy enforcement. The policy gets created and stored in the cluster's API server, but nothing is actually applying it to the network traffic. This is a critical distinction to understand. Network policy support requires a compatible CNI plugin like Calico, Cilium, or Weave. Without one of these plugins, policies are essentially decorative.

We can verify this by trying to communicate between Pods directly. If we execute a command from the web Pod to call the API Pod, it will still succeed if the CNI doesn't enforce policies. The network traffic flows freely despite the policy saying it shouldn't. This demonstrates why testing in the right environment is so important.

To really see network policies in action, we need a cluster with a CNI that enforces them. Let's remove the existing application to free up resources, and if you're already using k3d, stop your existing cluster to avoid port collisions when we create the new one.

## Install k3d CLI

We need k3d to create a cluster with proper network policy support. k3d is a tool for running Kubernetes clusters where each node runs inside a Docker container. It's not as user-friendly as Docker Desktop for everyday development, but it provides advanced configuration options that we need for this demonstration. Specifically, we can control which CNI plugin the cluster uses.

The installation is straightforward using package managers. On Windows with Chocolatey, on macOS with Homebrew, or on Linux with a simple curl command. After installation, we can verify it's working by checking the version. The exercises use k3d version five, and this is important because options have changed significantly since older versions. If you're on version four or earlier, you'll need to upgrade to follow along. k3d requires Docker as its container runtime, so it works with Docker Engine on Linux or Docker Desktop on Mac and Windows. You can't use it with other container runtimes.

## Try a new cluster with NetworkPolicy support

With k3d installed, we can create specialized clusters to represent different environments or projects, then start and stop them as needed. The cluster creation command has numerous options for customizing the setup. By default, k3d clusters use the Flannel CNI plugin, which is common in many Kubernetes distributions. However, Flannel doesn't enforce network policies. We can configure a new cluster to start with no network plugin at all, then install Calico ourselves.

The cluster creation command looks complex at first, but each part serves a specific purpose. We're creating a single-node cluster without the Flannel CNI installed. The port publishing flag makes ports thirty thousand through thirty thousand forty available on localhost, so we can access NodePort Services just like we would with Docker Desktop. The additional k3s arguments disable various default features we don't need for this demonstration. The cluster gets created without networking capabilities initially.

After creation, k3d automatically changes your kubectl context to point to the new cluster. We can verify this by checking the cluster nodes. The node appears in the list, but if we look at its status, it's NotReady. The cluster isn't functional yet because there's no network plugin installed. If we dig deeper and check the Deployments in the kube-system namespace, we'll see that the DNS server isn't running either. CoreDNS requires networking to function, so it can't start without a CNI plugin.

Calico is a popular open-source network plugin that supports network policy enforcement. It's very commonly used in production environments where network policy is required. The network plugin runs as a DaemonSet, meaning one Pod runs on each node in the cluster. Calico uses privileged init containers to modify the network configuration of the operating system on each node. This is why we're using k3d for this exercise. Running Calico modifies network settings in ways that could interfere with your main cluster, but since k3d nodes are just containers, the changes are isolated and safe.

The Calico manifest comes from the official Calico documentation. It includes the network plugin components and all the necessary RBAC rules for Calico to operate within the cluster. When we install Calico and watch the Pods in kube-system, we'll see various Calico components starting up. This takes a minute or two as the Pods pull images and initialize. The calico-node Pods configure networking on each node, while calico-kube-controllers manages the Calico resources cluster-wide.

Once Calico is running, we can check the node status again. The node should now show as Ready, indicating the cluster is fully functional. The CoreDNS Deployment should also scale up and become available. We now have a working Kubernetes cluster with a CNI that will actually enforce our network policies.

Let's deploy the APOD application again, this time on our policy-enforcing cluster. We apply the same manifests as before, and the Pods start up normally. Once they're running, we can verify the application works by browsing to localhost port thirty thousand sixteen. The application loads successfully, showing that basic networking functions correctly.

Now we'll apply the same deny-all policy as before. When we check that the policy was created, it appears in the list just like it did on our previous cluster. But this time, something different happens. When we refresh the browser, the application times out and fails to load. This is what proper network policy enforcement looks like. The web Pod genuinely cannot communicate with the API or log Pods because all traffic is blocked by the policy.

The blocking is even more comprehensive than you might initially realize. The Pods cannot even resolve DNS names to IP addresses. If we try to access the API by service name from the web Pod, it fails with a "bad address" message. The Pod can't resolve the service name because DNS traffic is also egress traffic, and our policy blocks all egress. Let's confirm this isn't just a DNS issue by testing with the Pod IP address directly. When we find the API Pod's IP using the wide output format and try to access it directly, this also times out. Both the egress policy blocking traffic from the web Pod and the ingress policy blocking traffic to the API Pod are preventing communication.

## Deploy policies for application components

Now we need to explicitly model the communication paths between our application components. We'll often see a default deny-all policy in production environments to prevent any accidental network communication. When you take this approach, you must explicitly define all the communication lines between components. This makes your security requirements visible and auditable in your cluster configuration.

The log policy allows ingress from the web Pod to the API port. Notice it doesn't include any egress rules because the log component doesn't make any outgoing network calls. It only receives requests from the web application. The web policy is more complex because the web component needs both to receive traffic and to make outgoing calls. It allows ingress from any location because it's the public-facing component of our application. For egress, it must be able to reach both API Pods and the DNS server. Without DNS, the web Pod couldn't resolve the API service names to IP addresses.

The API policy allows ingress from the web Pod since only the web application should be calling the API directly. The egress rules are particularly interesting. The API needs to reach the DNS server like all other components, but it also needs to make external calls to NASA's API to fetch astronomy data. If we want to restrict access to specific IP blocks like this, the services we use need to have static addresses. We can find these using DNS lookup tools like dig.

When we apply these component-specific policies, we can verify them with the get networkpolicies command. We now have four policies total: the default deny-all and three component-specific policies. Let's test that the web Pod can now use the API. When we execute a wget command from the web Pod to the API service, it should succeed and return JSON data. The API is able to fetch data from the NASA APIs because the egress rules include the appropriate CIDR blocks. If we describe the API policy, we can see these IP blocks in the egress rules.

Refreshing the application in the browser shows that everything is working again. The application functions normally, but this time with proper network security in place. Only the explicitly allowed communication paths are permitted, and everything else is blocked.

## Lab

We've successfully deployed the APOD application with network policies, but our security isn't as tight as it could be. There's a vulnerability in our current approach that's important to understand. Our policies use label selectors to control access. For example, the API policy allows ingress from Pods labeled with the apod-web label. But what happens if someone deploys a malicious Pod with that same label?

Let me demonstrate this security gap. We can deploy a basic sleep Pod that has the apod-web label, even though it's not the legitimate web application. Once this Pod is running, we can use it to access the API, and it works. The sleep Pod successfully calls the API endpoint because it has the correct label. The network policy has no way to distinguish between the legitimate web Pod and this impostor Pod. This is a label-based access control vulnerability that exists whenever you rely solely on Pod labels for security.

The solution is to deploy the application to a dedicated namespace and use namespace selectors in the policies to restrict access. This provides an additional layer of security because namespace access can be controlled with RBAC. Your challenge is to fix this security issue with two tasks. First, change the application to use a custom namespace called "apod" instead of the default namespace. Second, modify the network policies to restrict ingress traffic to only allow Pods from the apod namespace.

You'll want to delete the existing APOD deployment to start fresh. Then recreate everything in the new namespace with updated policies. The namespace selector in your policies should check for a namespace label, and you'll need to ensure the apod namespace has that label. This prevents Pods in other namespaces from accessing the application components, even if they somehow get the matching Pod labels.

Take some time to work through this challenge. The hints file provides guidance if you get stuck, and the solution shows one complete approach. The key insight is combining both Pod selectors and namespace selectors to create layered security.

## Cleanup

When you're finished with the exercises, you have a few cleanup options depending on what you want to do next. If you want to reuse your k3d cluster for other experiments, you can delete just the exercise resources. Deleting the apod namespace will remove all the application components in one command, and then cleaning up any resources in the default namespace using the label selector removes the test Pods we created.

If instead you want to delete the entire cluster and switch back to your original Kubernetes setup, you can use the k3d cluster delete command for the labs-netpol cluster. Then switch your kubectl context back to your previous cluster, whether that's docker-desktop or another cluster name. You'll still want to clean up any exercise resources in that cluster using the label selector.

If you were originally using a k3d cluster that you stopped at the beginning of this session, remember to start it again so your environment is back to its normal state. The k3d cluster start command will bring back your previous cluster.

That completes our hands-on exploration of network policies. We've seen how flat networking works by default, how to implement default deny policies, why CNI plugins matter for policy enforcement, how to model component communication explicitly, and how to use namespace selectors for stronger security. These patterns form the foundation of network security in Kubernetes environments.
