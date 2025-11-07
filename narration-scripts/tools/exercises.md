# Tools - Exercises Narration Script

Welcome to the Tools lab, where we'll explore some of the most popular Kubernetes management tools beyond kubectl. While kubectl is powerful, sometimes you need different tools to navigate and visualize your cluster more effectively. This session is marked as advanced and goes beyond CKAD requirements, but the tools we cover can dramatically improve your productivity.

Before we dive into the tools themselves, I want to note that this lab includes several optional sections depending on what you want to explore. We'll look at the Kubernetes Dashboard for web-based cluster management, K9s for a terminal-based interface, Krew for kubectl plugins, and Kubewatch for Slack integration. Each tool serves different use cases, so feel free to focus on what interests you most.

## * **Do this first if you use Docker Desktop** *

If you're running Kubernetes in Docker Desktop, there's an important bug we need to address first. Docker Desktop has a known issue with the default RBAC setup where permissions aren't applied correctly. This will cause problems with the Dashboard and other tools we're about to use.

The fix is straightforward. On Docker Desktop for Mac or when using WSL2 on Windows, you'll need to make the fix script executable and then run it. On Docker Desktop for Windows using PowerShell, you'll need to adjust the execution policy first and then run the PowerShell version of the script. This RBAC fix ensures that the ServiceAccount permissions we'll be creating later actually work as expected.

## Dashboard

The Kubernetes Dashboard is the official web UI for the Kubernetes project. It provides a graphical interface for viewing and managing cluster resources, making it much easier to visualize what's happening in your cluster compared to working purely with kubectl.

Before we can see anything interesting in the Dashboard, we need to deploy the metrics server if it's not already running. Let me check if metrics are available by trying to view node metrics. If that command returns no response, we'll need to install the metrics server components.

Now let's deploy some resources so we have something interesting to look at in the Dashboard. I'll apply the random number generator application specs. This deploys a simple application that generates random numbers. Let me verify the app is working by accessing it on localhost port 30080. When you click the Go button, you should see a random number displayed.

With our sample application running, we can now deploy the Dashboard itself. This setup includes several components including a ServiceAccount that we can use to authenticate with the web UI. Let me examine this ServiceAccount to understand what permissions it has. When I describe the ServiceAccount, you can see it's been created in the kubernetes-dashboard namespace.

The authentication tokens for ServiceAccounts are stored in Secrets of the special type kubernetes.io/service-account-token. When you create these Secrets, Kubernetes automatically generates the token value. Let me check what secrets exist for our admin user.

Now I need to print the actual authentication token so we can use it to log in. This command extracts the token from the Secret and base64 decodes it. Copy this value to your clipboard because we'll need it in just a moment.

Open your browser and navigate to https://localhost:30043. You'll need to accept the security risk because this deployment uses a self-signed SSL certificate. When the login screen appears, paste in the token you copied. This token represents your admin credentials.

Once you're logged in, you might see some empty screens at first. The Dashboard is namespace-aware, so you'll need to browse around and change namespaces to see different resources. You can view Pods, Services, and other resources across all namespaces. Notice that you can't view Secrets because this ServiceAccount doesn't have full cluster admin permissions.

When you navigate to a Pod, you can check its logs and even exec into it directly from the web interface. This can be much more convenient than using kubectl, especially when you're troubleshooting and want to quickly jump between different resources.

The ServiceAccount we created has limited permissions by design. You can view all resources in all namespaces, but you can only edit resources in the rng namespace. This demonstrates how RBAC allows you to create restricted admin users who can manage specific parts of your cluster without having full cluster admin rights.

## K9s

K9s is a terminal-based GUI for navigating Kubernetes clusters. Unlike the Dashboard which runs in your browser, K9s gives you a powerful text-based interface that can be faster and more efficient for many operations. You can find installation instructions at the K9s GitHub repository.

Installation varies by platform. On Windows you'll need admin privileges and can use Chocolatey. On Mac you can use Homebrew. On Linux there's a convenient install script you can curl and run. The installation is quick and doesn't require any cluster configuration because K9s is just a client tool.

Let me run K9s in read-only mode to start with. This uses your default cluster admin context but prevents any modifications, which is a safe way to explore the interface. K9s will launch in your terminal and take over the full screen.

Navigation in K9s is entirely keyboard-driven. You can press numbers to switch between namespaces, with zero taking you to all namespaces. Use the up and down arrow keys to select a Pod, and press L to view its logs. Press Escape to go back to the previous screen. This navigation becomes very natural once you get used to it.

To switch between different resource types, you use colon commands. Type colon svc to view Services, colon cm for ConfigMaps, or colon secrets for Secrets. When viewing Secrets, you can press X to decode the base64 encoded values and see the actual secret data. This is much quicker than using kubectl to decode secrets manually.

Press Ctrl-C when you're ready to exit K9s and return to your normal terminal.

Now let me show you something powerful with K9s. We can create a context for our RNG admin user and then launch K9s using that restricted context. First I'll get the ServiceAccount token again and create user credentials in kubectl. Then I'll create a new context that uses these credentials.

When I launch K9s with this restricted context and specify the rng namespace, K9s respects the RBAC permissions. I can navigate to Pods and see them, but I can only shell into Pods in the rng namespace. If I try to view Secrets, I get an error because this ServiceAccount doesn't have permission. However, if I go back to Pods and select the rng namespace, I can then view Secrets in that namespace because the ServiceAccount has namespace-specific permissions.

This demonstrates how K9s integrates seamlessly with Kubernetes RBAC, making it safe to use even with restricted permissions.

## Kubectl plugins - Krew

Kubectl supports a plugin system that allows you to extend its functionality with custom commands. Krew is a plugin manager that makes it easy to discover and install kubectl plugins.

The installation process for Krew varies by operating system, so you'll need to follow the specific instructions for your platform from the Krew website. After installing, you'll need to add Krew to your PATH and restart your shell or restart VS Code if you're working in an integrated terminal.

Once Krew is installed, you can use it like any other kubectl command. Let me search for RBAC-related plugins to see what's available. Krew maintains a registry of hundreds of plugins covering everything from RBAC visualization to resource management to cluster diagnostics.

Let me install the rbac-view plugin. Note that you'll likely need admin permissions for installing plugins. Once installed, you can run the plugin using kubectl rbac-view. This launches a web server that visualizes all the RBAC relationships in your cluster. While comprehensive, the visualization can be overwhelming in a real cluster with many roles and bindings.

Another useful plugin is who-can, which answers questions about permissions. Let me install it and then query who can get secrets in the rng namespace. The output shows which ServiceAccounts and users have permission to access secrets. However, this plugin isn't always complete because RBAC can be complex with inherited permissions from cluster roles.

You can verify permissions directly using kubectl's built-in auth can-i command. This is often more reliable than plugin-based checks because it queries the actual API server authorization.

The access-matrix plugin provides a different view of permissions. Let me install it and run it for our RNG admin ServiceAccount. This shows a matrix of all resource types and which actions the ServiceAccount can perform. When I specify the rng namespace, you can see that the permissions are much broader within that specific namespace.

## Kubewatch (Slack integration)

Kubewatch is a tool that sends notifications about cluster events to Slack. This is incredibly useful for monitoring production environments because you get real-time alerts about Pod crashes, deployment updates, and other cluster changes directly in your team's Slack channels.

To set up Kubewatch, you'll need admin access to a Slack workspace. You can create a new workspace specifically for testing if you don't want to use your production Slack. Start by creating a workspace and setting up a channel for the notifications.

Next, you need to add a bot app to your Slack workspace to get an API token. Go to the Slack app directory, search for the Bots app, and install it. Give your bot a name like kubewatch. Once created, Slack will provide you with an API token.

In your Slack channel, invite the bot using the slash invite command. This gives the bot permission to post messages to that channel.

Now we can install the Kubewatch server components using Helm. Kubewatch is packaged as a Helm chart which makes installation straightforward. Let me add the Bitnami Helm repository and then install Kubewatch with our configuration. The values file specifies which events to watch, and we pass the Slack channel and token as command line parameters.

After installation, check the Kubewatch logs to verify it's running. You might see an RBAC warning in some environments, but this can usually be ignored as long as the bot connects to Slack successfully.

Now comes the fun part. Let me delete a Pod in the rng namespace and watch what happens in Slack. Within seconds, you should see a notification in your Slack channel showing that the Pod was deleted and that Kubernetes created a new Pod to replace it. This real-time visibility into cluster events is invaluable for operations teams.

## Cleanup

When you're finished experimenting with these tools, it's time to clean up. Delete the namespaces and RBAC resources we created using the kubernetes.courselabs.co equals tools label. This removes the Dashboard, the RNG application, and all associated ServiceAccounts and RoleBindings.

If you deployed the metrics server earlier, you can remove it as well. And if you installed Kubewatch, uninstall it using Helm.

That wraps up our exploration of Kubernetes tools beyond kubectl. We've seen how the Dashboard provides a web-based interface for cluster management, how K9s offers a powerful terminal-based alternative, how Krew and kubectl plugins can extend kubectl's functionality, and how Kubewatch can integrate your cluster with Slack for real-time notifications. While these tools aren't required for CKAD certification, they're extremely valuable in real-world Kubernetes operations and can significantly improve your productivity.
