# Nodes - Exercises Narration Script

**Duration:** 12-15 minutes
**Format:** Screen recording with live demonstration
**Prerequisite:** Kubernetes cluster running (Docker Desktop, k3d, or similar)

---

Welcome to the Nodes lab! While you might not manage node infrastructure directly on the CKAD exam, understanding how to query and work with nodes is fundamental. Nodes are the machines in your cluster that actually run containers, and Kubernetes stores comprehensive information about them that you can access with kubectl. In this lab, we'll explore how to examine nodes and extract useful information from them.

Make sure you have a Kubernetes cluster running. I'm using Docker Desktop, which typically has a single node, but everything we cover here applies equally to multi-node clusters. Let's dive in and see what Kubernetes knows about our cluster infrastructure.

## Working with Nodes

The two most essential kubectl commands you'll use every day are get and describe. These commands work with any Kubernetes object type, and we'll start by using them with nodes. Let me run kubectl get nodes and you'll see a table showing all the servers in the cluster. For Docker Desktop, you'll typically see one node called docker-desktop. The output shows us the node name, its status, any roles it has, how long it's been running, and which version of Kubernetes it's running.

This is the get command in action. It prints a concise table with basic information, perfect for getting a quick overview of what objects exist in your cluster. But when you need more detail, that's where describe comes in. Let me run kubectl describe nodes and you'll see significantly more information. There's a lot here! We get labels that identify the node, any taints that might affect scheduling, the node's capacity showing total CPU and memory, the allocatable resources available for pods after system overhead, conditions showing the node's health, information about allocated resources showing what's currently being used, and a list of events showing recent activities on the node.

If you have a multi-node cluster, describing all nodes at once can be overwhelming. You can get details for just one node by adding its name to the command. The command format would be kubectl describe node followed by the node name. On Docker Desktop, that would be kubectl describe node docker-desktop. This is much more manageable when you're troubleshooting a specific node.

Here's something really useful that you can do with the describe output. Can you tell how hard your node is working? Kubernetes knows the compute capacity of each node, meaning how many CPU cores and how much memory it has available. That's shown in the Capacity section. You'll also see the Allocatable section, which is slightly less because some resources are reserved for system components like the kubelet and container runtime. Then in the Allocated Resources section, you can see what workloads are currently requesting. It shows you both the absolute amounts and percentages for CPU requests, CPU limits, memory requests, and memory limits. This is incredibly valuable when you're trying to figure out if a pod won't schedule because the node is full.

## Working with Kubectl

Before we go further, let's talk about kubectl itself. Kubectl has extensive built-in help that you should get comfortable using. You can run kubectl dash dash help to see all available commands, or kubectl get dash dash help to see detailed help for a specific command. This is available during the CKAD exam, so get into the habit of using it.

You can also learn about resource types directly from kubectl using the explain command. Try kubectl explain node and you'll get a brief description of what a node resource is. This might not seem very useful at first, but it tells you something important: nodes are just like any other Kubernetes resource. They have a fixed data schema, their status is monitored and stored in etcd, and you interact with them the same way you interact with pods or services.

The explain command can drill into specific fields too. If you run kubectl explain node.status, you'll see all the fields in the status section. You can even go deeper with kubectl explain node.status.capacity to see what the capacity field contains. This is immensely helpful when you're trying to understand what information is available about a resource and how it's structured.

## Querying and formatting

You'll spend a lot of time with kubectl, especially when studying for the CKAD exam, so it's worth learning some powerful features early on. One of the most useful is the ability to format output in different ways. Try running kubectl get node followed by your node name and the output flag set to json. You'll see the complete node object in JSON format. This is the actual data structure that Kubernetes stores internally.

Now let's check the help for the get command to see what other output formats are available. When you run kubectl get dash dash help, look for the output option. You'll see something like "Output format. One of: json, yaml, name, go-template, template, jsonpath, custom-columns, wide" and more. That's a lot of options! The most commonly used are json, yaml, wide for extended table output, and jsonpath for querying specific fields.

JSONPath is particularly powerful because it lets you extract specific fields from the JSON output, which is perfect for automation and scripting. Let's say you want to know how many CPU cores your node has. You could run kubectl get node followed by your node name, then use the output flag with jsonpath and specify the query '.status.capacity.cpu'. The query starts with a dot for the root object, then navigates through status to capacity to cpu. When you run this, you get just the number of CPU cores, nothing else. This is incredibly useful when you need a specific piece of information quickly.

Here's an exercise for you. Can you write a similar command to show which container runtime your node is using? Pause the video and give it a try. The information is somewhere in that JSON output we saw earlier. You'll need to figure out the right path through the JSON structure.

Ready? Here's the solution. You would run kubectl get node followed by your node name, with the output set to jsonpath and the query '.status.nodeInfo.containerRuntimeVersion'. The node information is stored under status dot nodeInfo, and the container runtime version is one of the fields there. The output will show something like containerd://1.6.6 or docker://20.10.17, depending on what your cluster is using. This demonstrates how JSONPath lets you pinpoint exactly the data you need without parsing through pages of output.

## Lab

Now let's tackle the lab challenge. Every Kubernetes object can have labels attached to it. Labels are key-value pairs that record additional information about the object. They're heavily used for organizing and selecting resources. Nodes get a standard set of labels provisioned automatically by Kubernetes, and these labels include useful information about the node's characteristics.

Your task is to find the labels on your node that tell you the CPU architecture and operating system it's running. There are several ways to approach this. You could use kubectl describe and look through the output for the labels section. You could use kubectl get nodes with the dash dash show-labels flag to see all labels in the table output. Or you could output the node as YAML or JSON and look for the labels in the metadata section.

Let me show you one approach. If I run kubectl get nodes with the dash dash show-labels flag, I see all the labels in a long comma-separated list. It's a bit hard to read, but you can spot some standard labels like kubernetes.io/arch which shows the architecture, something like amd64 or arm64. You'll also see kubernetes.io/os which shows the operating system, typically linux or windows.

There's an even better way to view specific labels. You can use the capital L flag followed by the label key to show that label as a column in the table output. For example, kubectl get nodes with capital L kubernetes.io/arch shows the architecture as its own column, and you can chain multiple label columns by adding more capital L flags. This is a really clean way to view specific labels without the clutter of showing all of them.

These standard labels are important because they're used by pod specifications to control where pods get scheduled. If you have a mixed cluster with both Linux and Windows nodes, or with different architectures like amd64 and arm64, you can use node selectors in your pod specs to ensure pods only run on compatible nodes. We'll explore node selectors more in future labs, but understanding node labels is the foundation for that capability.

That wraps up our exploration of nodes. We've seen how to query node information with get and describe, how to use kubectl's built-in help and explain commands, how to format output in different ways including using JSONPath for precise queries, and how to work with node labels to understand node characteristics. These kubectl skills are essential not just for working with nodes, but for working with any Kubernetes resource. You'll use these commands constantly, both in day-to-day operations and during the CKAD exam. Practice them until they become second nature!
