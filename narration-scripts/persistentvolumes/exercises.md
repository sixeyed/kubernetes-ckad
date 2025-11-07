# Storing Application Data with PersistentVolumes

Welcome back! In this session we'll explore persistent storage in Kubernetes through hands-on examples using a Pi calculation web application fronted by an Nginx caching proxy. This is a perfect demonstration because the cache needs to persist to improve performance, and we'll see how different storage choices affect the application's behavior.

You should have your Kubernetes cluster ready, whether that's Docker Desktop, k3d, or any local cluster. Let's dive into the world of persistent volumes.

## API specs

Before we get hands-on, let's understand what we're working with. A PersistentVolumeClaim is the simplest way to request storage in Kubernetes. Looking at a basic PVC YAML, you'll see it includes access modes that describe whether the storage is read-only or read-write and whether it's exclusive to one node or can be accessed by many. The resources section specifies how much storage the PVC needs.

In the Pod spec, you include a PVC volume to mount in the container filesystem, referencing it by the claim name. The beauty of this abstraction is that your application doesn't need to know whether it's using local disk, network storage, or cloud volumes. The PVC handles all those details.

## Data in the container's writeable layer

Let's start with the simplest storage option and understand why it's insufficient for most real applications. Every container has a writeable layer which can be used to create and update files. We'll deploy our Pi-calculating website fronted by an Nginx proxy that caches responses to improve performance.

When you first browse to the application and request thirty thousand digits of Pi, you'll notice it takes over a second to calculate the response and send it. The proxy caches this response in the temp directory. When you refresh, the response is instant because it's served from the cache. You can verify the cache exists by checking the temp folder in the container and seeing the cache files created by Nginx.

Now here's where things get interesting. When you stop the Nginx process, the container exits and Kubernetes immediately starts a replacement. The Pod shows an increased restart count. But when you check the temp directory again, it's empty. The cache is gone. If you refresh your browser now, you'll see it takes over a second again because the calculation has to run from scratch.

This demonstrates an important lesson about container storage. Data in the container writeable layer has the same lifecycle as the container. When the container is replaced, the data is lost. This is the default behavior and unsuitable for any data you need to preserve.

## Pod storage in EmptyDir volumes

Let's improve this situation using volumes. The simplest type of volume is called EmptyDir, which creates an empty directory at the Pod level that Pod containers can mount. You can use it for data which is not permanent, but which you'd like to survive a restart. It's perfect for keeping a local cache of data.

The updated deployment specification uses an EmptyDir volume, mounting it to the temp directory. This is a change to the Pod spec, so you'll get a new Pod with a new empty directory volume. When you refresh your page, the Pi calculation happens again and the result gets cached. You can see the temp folder filling up with cache files.

The container sees the same filesystem structure, but now the temp folder is mounted from the EmptyDir volume rather than being part of the container's writeable layer. When you stop the Nginx process again, the Pod restarts. The critical difference now is that the temp folder still contains all the cache files. This is because the EmptyDir volume exists at the Pod level. When the container restarted, the Pod remained the same, so the volume and its data persisted.

When you refresh your browser, the response is still instant because the cache survived the container restart. However, EmptyDir is better than the container writeable layer but it still has limitations. If you delete the Pod itself, the Deployment creates a replacement with a brand new EmptyDir volume which starts empty. The cache is lost again. Data in EmptyDir volumes has the same lifecycle as the Pod. When the Pod is replaced, the data is lost.

## External storage with PersistentVolumeClaims

Now let's tackle real persistence with storage that survives both container and Pod replacements. This is where PersistentVolumes and PersistentVolumeClaims come in. Persistent storage is about using volumes which have a separate lifecycle from the app, so the data persists when containers and Pods get replaced.

Storage in Kubernetes is pluggable, and production clusters will usually have multiple types on offer, defined as Storage Classes. When you check the available storage classes, you'll see a single StorageClass in Docker Desktop and k3d, but in a cloud service like Azure you'd see many, each with different properties such as a fast SSD that can be attached to one node, or a shared network storage location which can be used by many nodes.

You can create a PersistentVolumeClaim with a named StorageClass, or omit the class to use the default. Looking at the PVC specification, it requests one hundred megabytes of storage which a single node can mount for read-write access. When you apply this PVC, each StorageClass has a provisioner which can create the storage unit on demand.

After creating the PVC, you can list the persistent volumes and claims to see what happened. Some provisioners create storage as soon as the PVC is created, while others wait for the PVC to be claimed by a Pod. This behavior varies by storage system.

When you deploy the updated Nginx proxy configured to use the PVC, the deployment specification references the PVC by name in the volume definition. After the Pod is ready, checking the PVC and PV status again shows the PVC in Bound status and a PV that was created automatically, also Bound to your PVC. The PV shows the requested size and access mode from the PVC.

The PVC starts off empty, so you'll populate it by accessing your application. When you refresh the app, the response gets cached and you can see the temp folder getting filled. Now let's test persistence properly. When you restart the container by killing the process, after the Pod restarts you'll see the cache files are still there. Refreshing the browser shows the response is still instant. But we already achieved this with EmptyDir, so the real test is Pod replacement.

When you force a complete Pod replacement by triggering a rollout restart, you'll see the old Pod terminating and a new Pod starting. Once the new Pod is ready, the cache files are still there. This is the power of PersistentVolumes. The data persisted through the complete Pod replacement. When you try the app again, the new Pod still serves the response from the cache, so it will be super fast.

Understanding what makes this possible is key. You created a PVC requesting persistent storage, and Kubernetes via the storage provisioner created a PV backed by actual storage. The PVC was bound to the PV, and your Pod mounted the PVC. When the Pod was deleted, the PVC and PV remained. The new Pod mounted the same PVC, accessing the same data. The key is that the PV has a lifecycle independent of any Pod. It persists until explicitly deleted. Data in PersistentVolumes has its own lifecycle and survives until the PV is removed.

## Lab

Now it's your turn to explore another storage option. There's an easier way to get persistent storage, but it's not as flexible as using a PVC, and it comes with some security concerns. The challenge is to run a simple sleep Pod with a different type of volume that gives you access to the root drive on the host node where the Pod runs. Can you use the sleep Pod to find the cache files from the Nginx Pod?

Think about HostPath volumes and how they work. These volumes mount a directory from the host node directly into the Pod, which is simpler than PVCs because no claim is needed, but they come with security concerns because Pods can access the host filesystem. You'll need to create a Pod specification with a container that doesn't exit immediately and a HostPath volume pointing to the root directory of the host. Consider what security context might be needed for full access.

## Cleanup

When you're finished with the lab, cleanup by removing all objects with the kubernetes.courselabs.co equals persistentvolumes label. This removes all Deployments, Services, ConfigMaps, PVCs, and PVs we created in this session.

That wraps up our hands-on exploration of PersistentVolumes. We've seen three levels of data persistence, from the container writeable layer that loses data on container restart, to EmptyDir volumes that survive container restarts within a Pod, to PersistentVolumes via PVCs where data survives everything including Pod deletions. We've learned how to create and use PVCs, how to verify volume mounting and data persistence, and the relationship between StorageClasses, PVs, and PVCs. These are essential skills for production Kubernetes work and for the CKAD exam. In the next video, we'll dive deeper into CKAD-specific scenarios including advanced storage patterns, troubleshooting, and exam preparation techniques.
