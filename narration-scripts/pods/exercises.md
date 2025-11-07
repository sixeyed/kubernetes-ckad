# Pods - Exercises Narration Script

**Duration:** 15-20 minutes
**Format:** Screen recording with live demonstration
**Prerequisite:** Kubernetes cluster running (Docker Desktop, k3d, or similar)

---

Welcome back! In the previous video, we covered the concepts behind Kubernetes Pods. Now it's time to get hands-on. In this demo, we'll create Pods, interact with them, and explore their capabilities.

Make sure you have a Kubernetes cluster running and kubectl configured. I'm using Docker Desktop, but any Kubernetes distribution will work fine. Let's get started by making sure our cluster is ready and checking for any existing Pods in the default namespace. As expected, there are no resources yet, so we're starting with a clean slate.

## API specs

Kubernetes uses declarative configuration with YAML files. Let's look at the simplest possible Pod specification. I'll open the whoami-pod.yaml file in the labs/pods/specs directory. This is as simple as it gets. We're specifying the API version as v1 for Pods, the kind as Pod, and some basic metadata including just the name "whoami". The spec section defines one container named "app" running the whoami image. The whoami application is a simple web service that returns information about itself, which makes it perfect for demonstrations like this.

Every Kubernetes resource needs these four fields. The API version tells Kubernetes which version of the spec we're using, ensuring backwards compatibility as the platform evolves. The kind identifies what type of object we're creating. The metadata section contains additional object data, with the name being the most essential piece. Then the spec field has a format that differs for every object type, but for Pods the minimum you need is a containers list with at least one container, and for each container you need a name and an image to run. Indentation is important in YAML since object fields are nested with spaces, so we need to be careful about that.

## Run a simple Pod

Let's deploy this Pod using kubectl apply. We can apply from our local copy of the course repo, and we'll see the output says "pod/whoami created". Kubernetes has accepted our request and is now working to make it happen. Let's check the status and we can see the Pod is running. Notice the status shows "Running", the ready column shows "1/1" meaning one container out of one is ready, and restarts is zero.

Now here's something interesting about Kubernetes' declarative approach. The path to the YAML file can actually be a web address. Let me show you by applying the same configuration from a URL. See that? It says "pod/whoami unchanged". Kubernetes compared the desired state in the YAML with the current state and determined nothing needs to change. This is declarative configuration in action.

Let's get more information about our Pod. The "get pods" command has several useful options. When we use the wide output format, we can see additional columns including the IP address of the Pod, which is an internal cluster IP, and the node it's running on. We also see nominated node and readiness gates, which we'll discuss in more detail later.

For even more detail, we can use the describe command. Look at all this information! The describe output shows the full Pod specification, the node it's scheduled on, container details including image, ports, and state, conditions showing the Pod's health status, and events showing what Kubernetes did to create this Pod. The events section at the bottom is particularly useful for troubleshooting. You can see Kubernetes scheduled the Pod, pulled the image, and started the container. This is where you'd look first if something goes wrong during Pod creation.

## Working with Pods

In production Kubernetes clusters, you might have many nodes running workloads, and any given Pod could be running on any one of them. The beauty is that you manage everything using kubectl, so you don't need direct access to the servers. Let's view the container logs. The whoami application logs its startup, and you can see it's listening on port 80. The logs command works with any application because Kubernetes automatically captures stdout and stderr from your containers.

You can also run commands inside Pod containers using kubectl exec. The exec command connects to the Pod container and runs whatever command you specify after the double dashes. Here we're running the date command to print the current date and time inside the container. This is incredibly useful for troubleshooting. You can check configuration files, test network connectivity, or run diagnostic tools, all without SSH access to the node.

Let's deploy another Pod to explore multi-Pod networking. I'll look at the sleep Pod specification. This is very similar to our first Pod, just with a different name and image. The sleep container runs an application that does nothing except sleep forever. It's useful for testing because it has common Linux tools installed. After applying this spec, we can verify both Pods are running.

Now for something really useful. We can start an interactive shell inside a container. The flags we use mean interactive with a terminal, and now we're inside the container! Let's explore the container environment. The hostname matches the Pod name, which is "sleep". Every container thinks it's running on a computer with that name. When we check the environment variables, we see various Kubernetes information. Notice how the Kubernetes service host and port are automatically injected so applications can communicate with the Kubernetes API.

Now let's test network connectivity. The sleep container has nslookup installed for DNS lookups. This resolves the "kubernetes" service name to an IP address. This is the Kubernetes API server, automatically available to all Pods. We can try pinging it, though some Kubernetes installations don't support ICMP ping for internal addresses, so you might see packet loss. That's fine and doesn't mean networking is broken, just that ping isn't supported in this particular setup. Let me exit this shell session and we're back to our local terminal.

## Connecting from one Pod to another

Every Pod gets its own IP address. Let's see how Pods communicate with each other. First, we need to get the whoami Pod's IP address. There it is in the wide output, showing something like 10.1.0.13, though yours will be different.

We could manually use this IP, but let's use kubectl's powerful JSONPath output to extract it programmatically and store it in a variable. JSONPath lets us query specific fields from the Kubernetes API response. The .status.podIP field contains the Pod's IP address. Now we can make an HTTP request from the sleep Pod to the whoami Pod using that IP address.

Excellent! We got a response from the whoami application. The output shows the container hostname which is the Pod name, the IP addresses, the operating system, and other environment details. This demonstrates that Pods can communicate directly using their IP addresses within the cluster. This is fundamental to how Kubernetes networking works, though in practice we usually use Services rather than direct Pod IPs since Pod IPs can change.

## Lab

Now let's explore one of the key features of Pods: self-healing through automatic container restarts. The lab exercise asks us to create a Pod with a badly-configured container that keeps crashing. I'll create a Pod spec using the courselabs/bad-sleep image, which is intentionally broken and will exit almost immediately.

After deploying this Pod, let's watch what happens. Using the watch functionality, we can see the Pod status update in real-time. Watch the restarts column. The Pod keeps restarting the container! After about 30 seconds, you'll see it restart once. Wait a bit longer, and it restarts again. This count keeps climbing.

Let me stop watching and get detailed information with describe. Look at the state section under containers. You can see the container is in a waiting or crashed state, the restart count, the reason for the last termination, and the exit code. The events section shows all the restarts. Kubernetes keeps trying to run your container, implementing exponential backoff, which means it waits longer between each restart attempt.

This is the first layer of high availability that Kubernetes provides. If your application crashes, Kubernetes automatically restarts it. Of course, if the container keeps failing like this one, Kubernetes can't fix a broken application, but it will keep trying. This restart behavior is crucial for resilient systems, because temporary failures or crashes won't take down your application permanently.

## Cleanup

Before we finish, let's clean up the Pods we created. We can delete multiple Pods in one command by listing their names. Kubernetes will gracefully terminate each Pod, and then they're gone. Our namespace is clean again and ready for the next lab.

That wraps up our hands-on exploration of Pods. We've seen how to create them from YAML files, how to inspect them with various kubectl commands, how to execute commands inside containers, how Pods communicate over the network, and how they automatically restart failed containers. These are essential skills for working with Kubernetes day to day and for the CKAD exam. In the next video, we'll dive deeper into CKAD-specific scenarios including multi-container Pods, resource management, health probes, and security contexts.
