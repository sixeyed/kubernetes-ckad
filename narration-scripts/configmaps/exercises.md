# ConfigMaps - Exercises Narration Script

**Duration:** 15-18 minutes
**Format:** Screen recording with live demonstration
**Prerequisite:** Kubernetes cluster running, completed Pods lab

---

Welcome back! In the previous video, we covered the concepts behind ConfigMaps in Kubernetes. Now it's time to get hands-on and see how ConfigMaps work with real applications.

ConfigMaps allow you to separate configuration from container images, making your applications more portable and easier to manage. Instead of hard-coding settings or rebuilding images for every configuration change, you can inject configuration at runtime using ConfigMaps.

## API specs

Let's start by understanding how ConfigMaps work with Pods. There are two main ways to consume ConfigMaps. You can use them as environment variables or you can mount them as files in the container filesystem. Let me show you both approaches.

For environment variables, the ConfigMap YAML contains simple key-value pairs in the data section. The Pod spec then references the ConfigMap using envFrom with a configMapRef. This loads all the ConfigMap data as environment variables in the container.

For the filesystem approach, the ConfigMap data can contain file contents. The Pod spec uses volumes to mount the ConfigMap, and volumeMounts to specify where in the container filesystem those files should appear. This is particularly useful for configuration files like JSON, properties files, or other structured data.

## Run the configurable demo app

Let's start with a practical demo using the configurable application. This app is specifically designed to display its active configuration settings through a web interface, making it easy to see exactly how ConfigMaps affect running applications.

First, I'll deploy the basic version without any ConfigMaps. This uses the default configuration that's baked into the container image. When I access the application through port-forward, you can see the configuration display showing the default release version and various environment variables that Kubernetes automatically sets. Every application has default configuration like this. ConfigMaps let us override these defaults without rebuilding the image.

## Setting config with environment variables in the Pod spec

Now let's see how to add configuration through the Pod spec itself using environment variables defined directly in the YAML. I'll deploy the app with an env section in the container spec that defines environment variables.

Looking at the deployment spec, you can see the env section defines a Configurable__Release variable with a specific version. When I exec into the container and check the environment, that variable is set. When I access the application through its Service, the displayed configuration shows the overridden release version.

This approach works for simple cases, but it has limitations. For multiple settings, you'd need multiple environment variable definitions, which makes the YAML verbose and harder to maintain. That's where ConfigMaps become powerful.

## Setting config with environment variables in ConfigMaps

Let's create a ConfigMap to hold multiple environment variables. The ConfigMap YAML has multiple key-value pairs in the data section. Each pair will become an environment variable in our container.

The updated Deployment spec uses envFrom with a configMapRef instead of listing individual environment variables. This loads all key-value pairs from the ConfigMap as environment variables in one step. It's much cleaner than defining environment variables directly in the Pod spec.

When I apply these changes, Kubernetes creates the ConfigMap and updates the Deployment. Remember, when you update a Deployment's Pod template, it triggers a rolling update with a new ReplicaSet. The new Pods automatically have all the ConfigMap values as environment variables.

This approach has several advantages. You can reuse the same ConfigMap across multiple Deployments. Updating configuration is as simple as editing the ConfigMap YAML and redeploying. All related environment variables are grouped together logically rather than scattered through the Deployment spec.

## Setting config with files in ConfigMaps

Environment variables are useful, but files are even better for complex configuration. Let's see how to load configuration from a JSON file stored in a ConfigMap.

Looking at the ConfigMap spec, the data section contains a key called override.json. The value after the pipe symbol is the entire JSON file contents. Notice how the JSON is indented - it needs to be one level deeper than the filename. This is standard YAML multiline string syntax.

The updated Deployment has two important sections. First, the volumes section defines a volume sourced from the ConfigMap. Second, the volumeMounts section mounts that volume into the container at a specific path. The application can now read the configuration file just like any other file in its filesystem.

When I apply these changes and check inside the container, the file exists at the mount path with the exact contents from the ConfigMap. The application reads this file on startup and merges it with its default configuration. File-based configuration is more powerful than environment variables because it supports complex nested structures, can be re-read by the application if it supports hot-reloading, and follows familiar configuration file patterns.

One important consideration with volume mounts is that they replace the entire directory contents by default. If your application expects other files in that directory, they'll be gone after mounting the ConfigMap. There are ways to handle this with subPath mounts, but that's a more advanced topic.

## Lab

Now it's your turn to experiment. The lab challenge asks you to use a ConfigMap to load files into the application's configuration folder without overwriting all the default files that are already there. Specifically, you need to add a specific configuration file while keeping the existing appsettings.json intact.

This is a common real-world scenario. Applications often have multiple configuration files, and you want to override some while keeping others. Think about how volume mounts work and how you might mount a ConfigMap to a specific file path rather than replacing an entire directory. The hints and solution are available if you need guidance.

## Cleanup

When you're finished with the lab, cleanup by removing all resources with the kubernetes.courselabs.co equals configmaps label. This removes the Deployments, Services, and ConfigMaps we created.

That wraps up our hands-on exploration of ConfigMaps. We've seen how to inject configuration as environment variables and as files, how ConfigMaps keep configuration separate from application code, and how they make applications more portable across environments. These are essential skills for real-world Kubernetes usage and for the CKAD exam. In the next video, we'll dive deeper into CKAD-specific scenarios including advanced ConfigMap creation methods, update propagation, troubleshooting, and exam-style challenges.
