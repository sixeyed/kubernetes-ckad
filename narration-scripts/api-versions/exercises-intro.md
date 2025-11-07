Welcome back! Now that we've covered the fundamental concepts of Kubernetes API versioning and the deprecation policy, it's time to work with these concepts in a real cluster. In the upcoming exercises video, we're going to practice discovering API versions, identifying deprecated APIs, and migrating resources to current versions. You'll learn the essential kubectl commands that help you navigate API changes confidently.

Let me walk you through what you'll be learning in the hands-on exercises. We'll start by exploring how to discover API versions in your cluster. You'll learn the difference between checking available API versions and listing all API resources, and you'll see when to use each command. This foundation is critical because understanding what your cluster supports is the first step in managing API deprecations effectively.

From there, we'll dive into identifying deprecated APIs in your running resources. You'll learn how to scan through deployments and other workloads to see which API versions they're using, and more importantly, how to recognize when those versions are deprecated or approaching removal. We'll also cover how to interpret the deprecation warnings that Kubernetes displays when you apply manifests with older API versions.

One of the most powerful tools you'll work with is kubectl convert. This utility helps you migrate YAML manifests from deprecated API versions to current stable versions automatically. You'll see both its capabilities and its limitations, and you'll learn the complete workflow for converting old manifests to new ones. We'll walk through practical examples showing how Ingress resources migrated from the networking v1beta1 API to v1, and how CronJobs moved from batch v1beta1 to the stable batch v1 API.

Beyond the convert tool, you'll also practice using kubectl explain for API information. This command provides instant documentation about resource structures, showing you which fields are required, what values are valid, and how the schema is organized. It's faster than searching online documentation and works even without internet access, making it invaluable both during the exam and in production environments.

We'll develop a systematic version migration strategy that you can apply to any cluster upgrade scenario. You'll learn how to check your current resources against the Kubernetes deprecation guide, how to identify which manifests need updating before a cluster upgrade, and how to test those updates safely. This systematic approach ensures you won't be caught off guard when APIs are removed in new Kubernetes versions.

The exercises include a practical lab exercise on version migration where you'll deploy legacy resources, identify their deprecated APIs, convert them to current versions, and verify everything still works correctly. This hands-on practice reinforces the entire workflow from discovery through remediation.

We'll also touch on automated deprecation checking using tools like kubent and Pluto. While these tools aren't required for the CKAD exam, understanding that they exist and how they work gives you additional options for managing large-scale cluster upgrades in production environments.

Throughout the exercises, you'll see the best practices for managing API versions: always using stable APIs in production, checking release notes before cluster upgrades, testing in development environments before production updates, and using kubectl convert for bulk migrations. You'll also learn what not to do, like ignoring deprecation warnings or using alpha APIs in production workloads.

Before starting the exercises video, make sure you have a running Kubernetes cluster. Any distribution works, whether that's Docker Desktop, Minikube, Kind, or a cloud provider cluster. You'll need kubectl installed and configured, a terminal and text editor ready, and permission to deploy and delete test resources in your cluster. The exercises move at a comfortable pace with clear explanations, so you can follow along on your own cluster or watch first and practice afterward using the lab materials.

Here's why this matters for your CKAD preparation: API version knowledge is critical for exam success. The exam may present you with manifests using deprecated APIs, or you might encounter "no matches for kind" errors that you must fix quickly. Knowing how to use kubectl api-resources, kubectl explain, and understanding API version structure will save you valuable time during the exam when every minute counts.

Beyond the exam, these skills are essential in production environments. Cluster upgrades can break applications if manifests use removed API versions. The skills you'll practice in these exercises will help you proactively identify and fix these issues before they cause downtime, making you more effective as a Kubernetes application developer.

Let's get started with the hands-on exercises and put these API version concepts into practice!
