# Preparing for Production

Welcome back! In the previous videos, we covered the fundamentals of running applications in Kubernetes. Now it's time to discuss what it takes to make those applications production-ready. While it's straightforward to model your apps in Kubernetes and get them running, there's essential work to do before you can confidently deploy to production.

Kubernetes provides powerful capabilities to automatically fix apps that have temporary failures, scale up applications that are under load, and add security controls around containers. These are the production concerns we'll add to your application models to prepare them for real-world deployment. In this demonstration, we'll explore container probes for health monitoring, horizontal pod autoscaling for dynamic scaling, and security contexts for enhanced protection.

Make sure you have a Kubernetes cluster running and kubectl configured. I'm using Docker Desktop, but any Kubernetes distribution will work fine. Let's get started.

## API specs

Before we dive into the exercises, let's review the key API specifications we'll be working with today. Container probes are a crucial part of production readiness, and they're defined as part of the container specification inside the Pod spec. The most common probe you'll use is the readiness probe, which tells Kubernetes whether the application is ready to receive network traffic.

When you configure a readiness probe, you specify how Kubernetes should test your application. For HTTP-based applications, you'll typically use an httpGet probe that makes an HTTP call to a specific path and port. If the response code indicates success, the application is considered ready. You can control how frequently Kubernetes runs these checks using the periodSeconds field, which determines the interval between probe executions.

The other key resource we'll work with today is the HorizontalPodAutoscaler, or HPA. This is a separate object that interacts with a Pod controller like a Deployment and triggers scale events based on resource utilization. When you create an HPA, you specify a scaleTargetRef pointing to the Deployment or other controller you want to scale. You define minimum and maximum replica counts to establish boundaries for scaling, and you set a target CPU utilization percentage that determines when scaling should occur. If the average CPU usage across your Pods rises above this target, the HPA scales up. When usage falls below the target, it scales down to conserve resources.

## Self-healing apps with readiness probes

We know from previous lessons that Kubernetes will restart Pods when containers exit, but there's a more subtle problem that needs addressing. Sometimes the application process is running but not responding correctly, like a web application returning HTTP 503 errors. In this state, the container hasn't crashed so Kubernetes won't automatically restart it, but the application isn't functioning properly either.

The whoami application we'll use today has a convenient feature that lets us simulate this exact scenario. Let's start by deploying the basic application from the productionizing specs directory. When we apply this configuration, we get two whoami Pods running behind a NodePort service.

Now here's where it gets interesting. The whoami application has an endpoint that lets us deliberately put it into a failed state. When we make a POST request to the health endpoint with the value 503, one of the Pods will switch to returning HTTP 503 errors. Let me demonstrate this behavior. First, I'll make a regular GET request to confirm the application is working normally. Now I'll POST to the health endpoint to trigger the failure. When I make subsequent requests, you'll see that some succeed and some fail with 503 errors. The failed Pod isn't fixing itself, and Kubernetes doesn't know there's a problem because the container is still running.

This is exactly the scenario that readiness probes solve. A readiness probe tells Kubernetes how to test whether your application is healthy and ready to serve traffic. You define the action Kubernetes should take, and it runs that test repeatedly. For HTTP applications, the probe makes an HTTP GET request to a specific endpoint. Let's look at the updated deployment spec that includes a readiness probe configuration.

The probe specification tells Kubernetes to make an HTTP GET request to the slash health endpoint every five seconds. This is the same endpoint we just used manually, but now Kubernetes will check it automatically. When we deploy this updated configuration, we'll get new Pods with the readiness probe enabled. Let's wait for them to become ready.

These new Pods start in a healthy state, but we can test the probe behavior by deliberately triggering a failure again. When I POST the 503 value to the health endpoint, watch what happens to the Pod status. One Pod changes from showing one out of one containers ready to zero out of one. The readiness probe failed, and Kubernetes took action.

Here's the crucial behavior: when a readiness check fails, the Pod is removed from the Service endpoints. It's not restarted or terminated, just removed from the load balancer. Let's verify this by checking the Service endpoints. You'll see only one Pod IP address listed now instead of two. When we make requests to the Service, we consistently get successful responses because traffic only goes to the healthy Pod.

This is incredibly valuable for real applications. If an app becomes overloaded and starts returning errors, removing it from the Service might give it time to recover. The Pod stays running, the readiness probe keeps checking, and when the app recovers, it's automatically added back to the Service. This is self-healing in action.

## Self-repairing apps with liveness probes

Readiness probes handle the case where an app is temporarily unhealthy, but sometimes you need a more aggressive approach. If an application is truly broken and won't recover on its own, keeping the Pod running doesn't help. This is where liveness probes come in.

A liveness probe determines whether Kubernetes should restart a Pod. If the liveness check fails repeatedly, Kubernetes kills the container and starts a fresh one. Let's look at a deployment configuration that adds a liveness probe alongside the readiness probe.

You'll often use the same test for both readiness and liveness probes, but the consequences are quite different. The liveness check has more significant implications since it results in a container restart, so you might want it to run less frequently and have a higher failure threshold before taking action. This helps avoid unnecessary restarts due to temporary issues.

When we deploy this updated configuration and wait for the new Pods to be ready, we'll have both probe types active. Now let's trigger a failure and observe the difference in behavior. When I send the 503 to trigger the failure, the Pod first fails the readiness check and is removed from the Service as before. But watch what happens next. After the liveness probe fails its configured number of times, you'll see the Pod restart. The restart count increments, the container is recreated with a clean state, and once it passes the readiness check again, it rejoins the Service.

This automatic restart is incredibly powerful for applications that can get into bad states they can't recover from on their own. Deadlocks, memory leaks, or corrupted internal state can all be resolved by restarting the container. Let's check the endpoints again, and you'll see both Pod IPs are back in the Service list because both Pods are healthy after the restart.

Container probes aren't limited to HTTP applications either. The Postgres database specification demonstrates two other probe types. It uses a TCP socket probe for readiness, which simply checks whether Postgres is listening on its port. For the liveness check, it uses an exec probe that runs a command inside the container to verify the database is actually usable, not just listening. These different probe mechanisms give you flexibility to monitor all types of applications appropriately.

## Autoscaling compute-intensive workloads

A Kubernetes cluster represents a pool of CPU and memory resources shared across all your workloads. If you have different applications with varying demand patterns, you can use a HorizontalPodAutoscaler to automatically scale Pods up and down as load changes, as long as your cluster has sufficient capacity to accommodate the scaling.

The basic HPA implementation uses CPU metrics, which requires the metrics-server component. Not all clusters have it installed by default, but it's straightforward to add. Let's check if our cluster has metrics available by running kubectl top nodes. If you see actual CPU and memory metrics, you're all set. If you get an error about the Metrics API not being available, you'll need to deploy the metrics-server from the provided specs.

The Pi application is compute-intensive, making it an ideal candidate for autoscaling. Let's examine the deployment specification. Notice that it includes CPU resource requests, which are essential for the HPA to calculate utilization percentages. The HPA spec references this deployment and configures scaling parameters. It will maintain between one and five replicas, scaling up when CPU utilization exceeds seventy-five percent of the requested amount.

After deploying both the application and the HPA, let's check the current state. The Pod metrics should show minimal CPU usage initially since there's no load. When we check the HPA status, you'll see current utilization at zero percent compared to the seventy-five percent target.

Now let's generate some load. Opening a couple of browser tabs to the Pi calculation endpoint with a high number of decimal places will max out the Pod's CPU. This is where the magic happens. The HPA monitors the CPU metrics, sees utilization rising well above the target threshold, and starts additional Pods to handle the load. As the new Pods come online and share the work, the average CPU across all Pods drops back below the threshold.

It's worth noting that some Kubernetes distributions, particularly recent versions of Docker Desktop, have issues with metrics reporting that can prevent the HPA from triggering. If you run kubectl top pod and see errors about metrics not being available for specific Pods, the HPA won't scale. This is a known issue, though the concepts we're demonstrating remain valid.

The HPA uses conservative default timings to avoid rapid scaling oscillations. It waits a few minutes before scaling up and a few more before scaling down. This prevents the system from thrashing in response to brief spikes or dips in load. When the load subsides, you'll eventually see the HPA scale back down to the minimum replica count, efficiently using cluster resources only when needed.

## Lab

Adding production concerns is typically something you'll do after the initial application modeling and deployment. The lab exercise puts this workflow into practice with the configurable application. Start by deploying the basic spec, which runs the app without any production features.

When you test the application, you'll discover it has an intentional flaw. After three refreshes, it fails and never recovers. There's a healthz endpoint you can check to verify this behavior. Your task is to enhance this deployment with production-ready configurations.

First, increase the replica count to five to ensure adequate capacity and fault tolerance. Then add a readiness probe that checks the healthz endpoint so traffic only routes to healthy Pods. Configure a liveness probe as well to restart Pods when the application fails unrecoverably. Finally, add an HPA as a safety net that can scale up to ten Pods if CPU usage exceeds fifty percent.

This particular application isn't CPU-intensive, so you won't be able to trigger the HPA through normal HTTP requests. Think creatively about how you could test that the HPA is configured correctly and will scale when needed. Could you generate artificial CPU load inside the containers? Could you set an artificially low CPU request to make the threshold easier to reach? Testing your configurations thoroughly is an important production skill.

## **EXTRA** Pod security

Container resource limits aren't just necessary for HPAs. They're an essential security feature you should include in all your Pod specs. Applying CPU and memory limits protects your nodes from resource exhaustion and prevents any single workload from starving others of resources.

Security is a vast topic in container orchestration, but there are several features you should aim to include in all your production specifications. Running containers as a non-root user ensures the container process doesn't have elevated privileges. Avoiding automatic mounting of the Service Account API token prevents unnecessary access to the Kubernetes API. Adding a security context with restricted OS capabilities limits what the application can do even if it's compromised.

Kubernetes doesn't apply these restrictions by default because they can cause breaking changes in applications that weren't designed with these constraints in mind. Let's explore what the defaults allow by examining a running Pod. When we check what user the process runs as, we'll likely see root. We can view the Service Account token that's automatically mounted, giving the Pod access to the Kubernetes API. We can even change file ownership of application files, demonstrating the broad permissions available by default.

These permissive defaults create security risks. An alternative specification can address these issues by running as a non-root user, disabling the Service Account token mount, and dropping Linux capabilities. However, implementing these restrictions often reveals assumptions in the application.

When we deploy the more secure configuration, the Pod fails to start. Checking the logs reveals the application doesn't have permission to listen on port eighty. This is because port eighty is a privileged port inside the container, and our least-privilege user without capabilities can't bind to it.

The solution depends on the application's flexibility. For this .NET application, we can configure it to listen on a non-privileged port like five thousand and one. When we deploy this updated configuration, the Pod starts successfully. Now when we verify the security settings, we see the process runs as the specified non-root user. Attempts to read the Service Account token fail because it's not mounted. Trying to change file ownership fails due to the dropped capabilities. The application functions correctly while operating with minimal privileges.

This layered security approach is just the beginning. Comprehensive container security starts with securing your images, continues through runtime restrictions, and extends to network policies and admission controls. But the configurations we've demonstrated today represent a significant improvement over the defaults and should be your baseline for production deployments.

## Cleanup

When you're finished with these exercises, you can clean up all the resources we created using a single command with the label selector. This removes all Pods, Services, Deployments, and HPAs that were part of this lab, leaving your cluster ready for the next topic.

That wraps up our practical exploration of production readiness. We've seen how readiness probes remove unhealthy Pods from Services without restarting them, how liveness probes restart Pods that can't recover on their own, how HPAs automatically scale applications based on CPU load, and how security contexts restrict container capabilities for defense in depth. These production features transform basic deployments into robust, scalable, secure applications ready for real-world use. In the next video, we'll explore these concepts in more depth with a focus on the CKAD exam requirements.
