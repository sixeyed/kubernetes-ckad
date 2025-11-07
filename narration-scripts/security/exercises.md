# Application Security with SecurityContexts

Welcome back to our hands-on exploration of Kubernetes security. In this session, we're going to work through practical examples that demonstrate how to properly secure your containers using SecurityContexts. We'll start by understanding the default security posture of containers and why that's problematic, then progressively build up layers of security controls.

## Understanding Security Contexts

Before we dive into the solutions, let's understand the problem we're trying to solve. By default, containers often run as root, and that poses serious security risks. Let me show you what I mean by creating a simple pod without any security context and checking what user it's running as. We'll deploy a basic nginx container and then execute the whoami command inside it to see which user the process is running as.

The output shows root, which means the container is running as the root user. If we check the full identity information with the id command, we can see UID 0 which is root, GID 0 which is also root, and full group memberships. This is concerning because if an attacker compromises this container, they have root privileges within that container environment. They could potentially install packages, modify application code, create files, or access sensitive information. This demonstrates exactly why we need security contexts to restrict what containers can do.

## Pod-level SecurityContext

Now let's create a Pod with security settings applied at the Pod level. These settings will affect all containers in the Pod, which makes it a good place to establish baseline security requirements. The pod-security-context YAML file in the specs directory shows how to configure this. When you look at the spec, you'll see a securityContext field at the pod level that specifies runAsUser as 1000, runAsGroup as 3000, and fsGroup as 2000. These settings mean the container will run as user ID 1000, the primary group will be 3000, and any volumes will have group ownership set to 2000.

Let's deploy this Pod and check what user it's running as. After applying the spec, we can execute the id command inside the pod to verify the security settings. The output shows the container is now running as user 1000 with group 3000, and includes supplemental group 2000 in its group memberships. This is exactly what we wanted, and there's no root access anymore.

To really understand the impact of these restrictions, let's try to perform a privileged operation like updating the package manager. When we attempt to run apt-get update inside the container, it fails because the container no longer has root privileges. This is the desired behavior because it means that even if an attacker compromises the application, they can't install additional tools or modify the system in destructive ways. This concept of limiting the blast radius of a potential security breach is fundamental to container security.

## Container-level SecurityContext

While Pod-level settings provide baseline security, container-level settings give us more granular control and can override Pod-level configurations. The container-security-context spec demonstrates this by adding security settings specifically at the container level. These settings include readOnlyRootFilesystem set to true, which makes the entire container filesystem immutable, and allowPrivilegeEscalation set to false, which prevents processes from gaining more privileges than they started with.

Let's deploy this Pod and test the read-only filesystem restriction. When we try to create a file anywhere in the root filesystem using touch, the operation fails with a read-only file system error. This is exactly what we want because it means an attacker cannot install malware, modify application binaries, create backdoor scripts, or persist any changes to the filesystem. The container's filesystem is completely immutable, which is a powerful security practice for production workloads.

## Running as Non-Root

One of the most important security practices is ensuring containers don't run as root. The non-root spec shows how to enforce this requirement. The key field here is runAsNonRoot set to true, which tells Kubernetes to validate that the container process isn't running as root. If the image tries to start a process as root, Kubernetes will prevent the container from starting at all.

After deploying this Pod, we can check its status to confirm it's running successfully. The runAsNonRoot setting provides an extra layer of protection by ensuring that even if someone changes the runAsUser value or if there's a configuration error, the container absolutely cannot run as root. When we verify the user ID with the exec command, we can see it's running as a non-root user just as we specified.

## Working with Read-Only Filesystems

When you set readOnlyRootFilesystem to true, you need to think about where your application needs to write data. Most applications need at least some writable locations for temporary files, cache data, or runtime state. The readonly-with-volume spec shows the pattern for handling this. The spec defines a read-only root filesystem but mounts an emptyDir volume at the /tmp directory, providing a writable location for temporary files while keeping everything else immutable.

Let's deploy this Pod and test writing to different locations. First, we'll try to create a file in the root filesystem, which should fail because of the read-only restriction. As expected, it fails with a read-only file system error. Now let's try creating a file in /tmp, and this succeeds because /tmp is mounted as a writable volume. This pattern of combining read-only root filesystems with targeted writable volumes gives us the best of both worlds: strong security guarantees with practical usability for applications that need temporary storage.

This approach is commonly used in production systems. You identify the specific paths where your application needs write access, like /tmp for temporary files, /var/cache for application caches, /var/run for runtime files like PID files, or application-specific directories for logs. For each of these, you mount an emptyDir volume at that path while keeping the rest of the filesystem read-only.

## Linux Capabilities

Linux capabilities provide fine-grained control over privileges without giving processes full root access. The most secure approach is to start by dropping all capabilities, then only adding back the specific ones your application needs. The drop-all-capabilities spec demonstrates this by using the capabilities field with drop set to ALL. This removes every Linux capability from the container, giving it minimal privileges.

When we deploy this Pod and try to use network operations like ping, it might fail because we've dropped all capabilities including network-related ones. The specific behavior depends on the implementation, but the key point is that the container has no special privileges at all. For most applications, this is too restrictive, which is why we have the ability to add specific capabilities back.

The add-capabilities spec shows how to grant specific privileges. It still drops all capabilities first, which is the security best practice, but then adds back NET_ADMIN which allows network administration tasks. This pattern of dropping everything and adding only what's necessary follows the principle of least privilege. Your container gets exactly the capabilities it needs and nothing more.

When you're working with capabilities in the CKAD exam, you should know the common ones. NET_BIND_SERVICE allows binding to ports below 1024, which is necessary for web servers running on port 80 or 443. NET_ADMIN allows network configuration changes. SYS_TIME allows setting the system clock for time synchronization services. CHOWN allows changing file ownership, and DAC_OVERRIDE allows bypassing file permission checks.

## Preventing Privilege Escalation

Even when running as a non-root user, certain mechanisms could allow a process to gain additional privileges. The allowPrivilegeEscalation field controls this behavior. The no-privilege-escalation spec sets this to false, which prevents the process from gaining more privileges through mechanisms like setuid binaries or other privilege escalation techniques.

When we deploy this Pod and try to run a setuid binary like su, it fails because the setuid mechanism is blocked. This is critical defense-in-depth security. Even if an attacker finds a setuid binary or discovers some other way to attempt privilege escalation, the kernel will block these attempts. You should always set allowPrivilegeEscalation to false when running containers as non-root users. It's essentially a free security improvement with no downsides for properly designed applications.

## Privileged Containers

I want to briefly mention privileged containers, though you should avoid them in almost all cases. The privileged-pod spec shows how to create a privileged container with the privileged field set to true. Privileged containers have access to all host devices and run with elevated privileges. When you deploy one and list the devices in /dev, you'll see all the host devices available to the container. This is dangerous and should only be used for very specific system-level tasks like container runtime management or hardware access. For the CKAD exam, you should know these exist but understand they're an anti-pattern for application workloads.

## Filesystem Group (fsGroup)

The fsGroup field controls ownership for mounted volumes, which is particularly important when non-root containers need to access shared storage. The fsgroup-demo spec shows how this works by setting fsGroup to 2000 at the Pod level. When the Pod starts, Kubernetes sets the group ownership of mounted volumes to this group ID, and the container process automatically includes this group in its group memberships.

After deploying this Pod, we can check the permissions on the mounted volume at /data. The directory shows group ownership of 2000, which matches our fsGroup setting. When we check the container's identity with the id command, we can see group 2000 is included in the supplemental groups. This means the container can write to the volume even though it's running as a non-root user.

Let's test this by creating a file in the /data directory. The file is created successfully, and when we list the permissions, we can see it has group ownership of 2000. This pattern is essential when you have multiple containers in a Pod that need to share data through volumes. By setting fsGroup at the Pod level, all containers can access the shared volumes regardless of their individual user IDs.

## Lab Exercise: Secure a Web Application

Now it's time to put everything together in a comprehensive exercise. The challenge is to create a secure nginx deployment that meets several requirements. The container must not run as root, and we need to enforce this with runAsNonRoot. The root filesystem must be read-only, but nginx needs specific directories to be writable, specifically /var/cache/nginx for its cache and /var/run for its PID file. We need to drop all capabilities except NET_BIND_SERVICE since nginx needs to bind to port 80. We should prevent privilege escalation, and the container should run as user ID 101, which is the nginx user in the official image.

This is exactly the type of question you'll encounter in the CKAD exam. You need to combine multiple security features into a single cohesive configuration. I encourage you to attempt this yourself before checking the solution. The solution will show how to configure the security context at both Pod and container levels, mount the necessary volumes for writable directories, and properly configure capabilities. When you test your deployment, you should verify that the Pod is running, check that it's running as user 101, and confirm that nginx is actually working by making a request to it.

## Security Best Practices

Let me summarize the security practices you should follow for every production Pod. Always run as non-root by setting runAsNonRoot to true and specifying a non-zero runAsUser value. Use read-only root filesystems by setting readOnlyRootFilesystem to true and mounting volumes for paths that need write access. Drop all capabilities by default and only add the specific ones you need. Prevent privilege escalation by setting allowPrivilegeEscalation to false. Use specific user IDs rather than relying on image defaults. Set resource limits to prevent resource exhaustion attacks. Apply RuntimeDefault seccomp profiles for additional system call filtering.

Equally important is knowing what not to do. Don't run privileged containers unless absolutely necessary, and even then, question whether there's a better approach. Don't run as root, especially in production environments. Don't add unnecessary capabilities just because they might be useful someday. Almost never use privileged set to true. And don't skip security contexts entirely, because the default settings are inherently insecure.

## CKAD Exam Tips

For the CKAD exam, you need to have certain topics at your fingertips. You must know the SecurityContext syntax for both Pod and container levels and understand when to use each. Be comfortable with runAsUser, runAsGroup, and fsGroup for managing user and group identities. Understand readOnlyRootFilesystem and how to combine it with volume mounts. Know how to work with capabilities, especially the pattern of dropping ALL and adding specific ones. Remember allowPrivilegeEscalation for preventing escalation attacks. And understand runAsNonRoot for enforcing non-root execution.

Common exam tasks include adding a security context to an existing Deployment, making a container run as non-root, setting read-only root filesystem with writable volumes, dropping all capabilities from a container, and configuring fsGroup for shared volumes. The key is being able to do these tasks quickly and accurately under time pressure.

Know the field names exactly because typos will cause failures. Remember that both Pod and container levels use the securityContext field name. Practice adding emptyDir volumes for writable directories until it's automatic. Use kubectl explain pod.spec.securityContext and kubectl explain pod.spec.containers.securityContext as quick references during the exam when you need to verify field names or structure.

## Cleanup

Before we finish, let's clean up all the demo Pods we created. We can delete multiple pods in one command by listing their names. If you completed the exercise, don't forget to delete that Pod as well. Kubernetes will gracefully terminate each Pod, and then our namespace is clean again.

## Key Takeaways

Let's recap the essential concepts. Kubernetes provides security contexts at two levels: Pod-level and container-level. Container-level settings take precedence over Pod-level settings for the same field. Running as non-root is critical for production security. Read-only root filesystems make containers more secure by preventing modifications. The pattern of dropping ALL capabilities and adding only what you need follows least privilege principles. Setting allowPrivilegeEscalation to false prevents escalation attacks. The fsGroup field is essential for multi-user volume access. And privileged containers should be avoided unless absolutely necessary.

Security is increasingly emphasized in the CKAD exam, so mastering these concepts isn't just about passing the test. It's about building the skills to deploy applications securely in production Kubernetes environments. In the next section, we'll focus specifically on CKAD exam scenarios and time-saving techniques for working with security contexts under pressure.
