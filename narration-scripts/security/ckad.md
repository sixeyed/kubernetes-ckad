# CKAD Exam Guide: Application Security & SecurityContexts

Welcome to the CKAD exam preparation session focused on Security Contexts. This is one of the most critical topics for the exam, and you'll definitely face questions about it. Security falls under the Application Environment, Configuration and Security domain, which represents 25 percent of your total score, making it the highest-weighted domain on the exam. You absolutely must master this material to pass.

## Why Security Matters for CKAD

In the CKAD exam, you will be tested on your ability to add SecurityContext to Pods or containers, configure runAsUser, runAsGroup, and runAsNonRoot settings, work with capabilities by adding and dropping them, set readOnlyRootFilesystem, configure allowPrivilegeEscalation, and use fsGroup for volume permissions. These aren't theoretical questions. You'll need to actually implement these configurations under time pressure, typically spending between five and eight minutes per security question.

The exam emphasizes security because it's fundamental to production Kubernetes deployments. You need to know not just what these fields do, but how to apply them quickly and accurately when given requirements like making an existing deployment secure or troubleshooting why a Pod with security restrictions won't start.

## Quick Reference for the Exam

Let me walk you through the essential YAML structures you need to have memorized. At the Pod level, the securityContext field applies to all containers in the Pod. You can set runAsUser to specify which user ID the containers should run as, runAsGroup to set the primary group, fsGroup to control volume ownership, supplementalGroups for additional group memberships, and seccompProfile to apply seccomp filtering. These settings provide baseline security for all containers in your Pod.

At the container level, the securityContext provides more specific controls that can override Pod-level settings. Container-level settings include runAsUser which can override the Pod-level value, runAsNonRoot to enforce that the container can't run as root, readOnlyRootFilesystem to make the container immutable, allowPrivilegeEscalation to prevent privilege gains, privileged to control full host access, and capabilities to add or drop specific Linux capabilities. Understanding which fields belong at which level is crucial for the exam.

When both Pod and container levels have the same field, the container-level setting takes precedence. For example, if the Pod specifies runAsUser as 1000 but a container specifies runAsUser as 2000, that container will run as user 2000. However, some fields only exist at certain levels. Fields like fsGroup and supplementalGroups only exist at the Pod level. Fields like capabilities, privileged, and readOnlyRootFilesystem only exist at the container level. Fields like runAsUser and runAsGroup exist at both levels, with the container value winning when both are specified.

## Exam Scenarios You'll Face

Let me walk you through the most common exam scenarios and how to approach them. The first scenario is being asked to create a Pod that runs as a non-root user. The question might say something like "Create a Pod named secure-app with image nginx that runs as user ID 1000." The solution is straightforward: you set the securityContext at the Pod level with runAsUser specified as 1000. To verify your work, you would exec into the Pod and run the id command, which should show uid equals 1000.

The second scenario involves enforcing non-root execution more strictly. The question might say "Ensure the container fails to start if the image tries to run as root." For this, you use the runAsNonRoot field set to true at the container level. This tells Kubernetes to validate that the container process isn't running as root, and if it is, the container won't start at all. This provides defense-in-depth by catching configuration errors or image changes that might reintroduce root execution.

The third scenario is implementing read-only root filesystems. You'll be asked something like "Make the container's root filesystem read-only but allow writes to /tmp." The solution requires setting readOnlyRootFilesystem to true at the container level, then adding a volumeMount for /tmp that points to an emptyDir volume. This pattern comes up frequently in the exam, so you need to be able to add volumes and volume mounts quickly.

The fourth scenario involves managing capabilities. A typical question would be "Run a container with all Linux capabilities dropped except NET_BIND_SERVICE." You accomplish this by setting the capabilities field with drop set to an array containing ALL, then add set to an array containing NET_BIND_SERVICE. Remember that capabilities is a container-level field, and you should always drop ALL first before adding specific capabilities.

The fifth scenario deals with volume permissions. The question might state "Create a Pod with a volume that's owned by group ID 2000." You would set fsGroup to 2000 at the Pod level, which causes Kubernetes to set the group ownership of mounted volumes. You can verify this worked by execing into the Pod and checking the permissions on the mount point with ls -ld.

## Essential SecurityContext Fields (Memorize These!)

You need to have certain field names and their purposes memorized for the exam. The runAsUser field sets the user ID and can be specified at either Pod or container level with an integer value like 1000. The runAsGroup field sets the primary group and similarly exists at both levels. The runAsNonRoot field enforces non-root execution and only exists at the container level, taking a boolean value of true. The fsGroup field controls volume ownership, exists only at the Pod level, and takes an integer like 2000. The readOnlyRootFilesystem field makes containers immutable, exists only at the container level, and uses a boolean value of true. The allowPrivilegeEscalation field blocks privilege gains, is container-level only, and should be set to false. The privileged field controls full host access, is container-level, and should almost always be false. The capabilities.drop field removes capabilities and typically uses an array with ALL. The capabilities.add field adds specific capabilities using an array with values like NET_BIND_SERVICE.

For Linux capabilities specifically, you need to know when you need them. NET_BIND_SERVICE is required for binding to ports below 1024, which web servers need for port 80 or 443. NET_ADMIN allows network configuration for network tools or VPNs. SYS_TIME allows changing the system clock for time synchronization services. CHOWN allows changing file ownership for file management applications. SETUID and SETGID allow setting user and group IDs for applications that switch users.

## Exam Tips & Time Savers

Let me share some critical exam strategies. First, when working with capabilities, always drop ALL capabilities first, then add specific ones. This ensures you start from a secure baseline. When you combine this with runAsNonRoot, you get both enforcement of non-root execution and an extra safety check that fails if the image somehow ignores the runAsUser setting.

Second, when setting readOnlyRootFilesystem, you almost always need to add volumes for writable directories. The pattern is to set readOnlyRootFilesystem to true at the container level, identify which paths need write access like /tmp, and mount emptyDir volumes at those paths. This is such a common pattern that you should practice it until you can type it without thinking.

Third, always verify your work using kubectl exec. Check that the user ID is correct by running the id command. Check that the filesystem is read-only by trying to touch a file in the root directory. If you have time, check capabilities by examining /proc/1/status and grepping for Cap, though this is less critical in the exam.

Fourth, don't confuse Pod and container levels. Some fields only work at one level, and putting them at the wrong level means they'll be ignored. For example, putting fsGroup at the container level does nothing, it must be at the Pod level. Similarly, capabilities only work at the container level.

Fifth, never use privileged set to true unless the question explicitly requires it. Instead, use specific capabilities to grant only the privileges actually needed. Privileged containers are dangerous and almost never the right answer for application workloads.

Sixth, don't forget to mount volumes when using readOnlyRootFilesystem. Applications often need to write temporary files, cache data, or runtime state. Without writable volumes at the right paths, your application will fail with read-only filesystem errors.

## Troubleshooting on the Exam

You'll likely encounter security-related failures that you need to debug and fix. The most common error is "container has runAsNonRoot and image will run as root." This happens when the image is configured to run as root but you set runAsNonRoot to true. The fix is to add runAsUser with a non-zero value like 1000 to override the image's default user. This overrides what the image specifies and satisfies the runAsNonRoot requirement.

Another common error is "read-only file system" when the application tries to write files. This occurs when you set readOnlyRootFilesystem to true but the application needs to write somewhere. The fix is to mount an emptyDir volume for writable locations like /tmp. You add the volume definition at the Pod level and add a volumeMount at the container level pointing to the path that needs to be writable.

A third common error is "operation not permitted" when the application tries to perform privileged operations. This happens when you've dropped capabilities that the application actually needs or blocked privilege escalation. The fix is to add the specific capability required. For example, if a web server needs to bind to port 80, you need to add the NET_BIND_SERVICE capability after dropping ALL.

A fourth error is "permission denied" when accessing volumes. This occurs when the volume has wrong ownership and the container's user can't access it. The fix is to set fsGroup at the Pod level to a group ID that the container's user belongs to. This causes Kubernetes to set the volume's group ownership, allowing the container to read and write.

## Production Security Best Practices (Exam Favorite!)

The exam loves to ask you to make a deployment "production-ready" from a security perspective. Every production Pod should have a minimum security baseline. Set runAsUser to a non-zero value like 1000 to avoid running as root. Set runAsGroup and fsGroup for proper group ownership. At the container level, set runAsNonRoot to true to enforce the requirement, set readOnlyRootFilesystem to true to make the container immutable, set allowPrivilegeEscalation to false to prevent escalation, and drop ALL capabilities in the capabilities field. Mount an emptyDir volume at /tmp for temporary file writes.

For maximum security in hardened production environments, you would add even more controls. Include seccompProfile with type RuntimeDefault at both Pod and container levels. Never use the latest tag for images, always use specific versions. Set resource requests and limits for both memory and CPU to prevent resource exhaustion. Mount emptyDir volumes for any paths that need write access, identifying these by understanding your application's requirements.

## Practice Scenarios (Time Yourself: 6 minutes each)

Let me walk you through some practice exercises you should time yourself on. For the first exercise, create a Pod that runs as user 1000, enforces non-root with runAsNonRoot set to true, has a read-only root filesystem, and has a writable /tmp directory. You should be able to complete this in about six minutes including verification.

For the second exercise, create a Pod that drops all capabilities except NET_BIND_SERVICE. This tests your knowledge of the capabilities syntax and the pattern of dropping everything then adding back only what's needed. Practice until you can write the YAML correctly without references.

For the third exercise, create a Pod with fsGroup set to 2000 and verify volume ownership. This tests your understanding of how fsGroup works and how to verify it's applied correctly.

For the fourth exercise, take an existing Deployment and add security context to make it production-ready. This is probably the most realistic exam scenario, where you need to edit an existing resource rather than create one from scratch. Practice using kubectl edit efficiently and knowing exactly where to add the security fields in the YAML structure.

## Common Exam Patterns

Certain patterns appear repeatedly in the exam. One pattern is being given an insecure Pod and asked to secure it. You should systematically check whether it's running as root and add runAsUser and runAsNonRoot if so. Check if it can write to the filesystem and add readOnlyRootFilesystem with necessary volumes if not secured. Check if it has all capabilities and drop ALL then add specific ones. Check if it can escalate privileges and add allowPrivilegeEscalation set to false.

Another pattern is fixing permission errors where an app can't access files on a volume. The solution is to add fsGroup at the Pod level and ensure the runAsUser is compatible with that group ownership.

A third pattern is troubleshooting why a Pod won't start. Common causes include runAsNonRoot set to true but the image runs as root, which you fix by adding runAsUser. Another cause is readOnlyRootFilesystem set to true but the app writes logs, which you fix by adding a writable volume mount. A third cause is missing capabilities, which you fix by adding the specific capability needed.

## Exam Day Checklist

Before you consider a security question complete, run through this verification checklist. Did you put fields at the correct level, Pod versus container? Did you set both runAsUser and runAsNonRoot? If you set readOnlyRootFilesystem, did you add writable volumes where needed? When working with capabilities, did you drop ALL first, then add? If you're using volumes, do you need fsGroup for permissions? Finally, did you verify everything works by testing with kubectl exec before moving on? This last step is critical because points come from working configurations, not close attempts.

## Key Points to Remember

Let me summarize the absolute essentials. Kubernetes provides SecurityContext at two levels: Pod-level and container-level. When the same field exists at both levels, container-level wins. Always drop ALL capabilities first, then add specific ones to follow least privilege. When using readOnlyRootFilesystem, you need volumes for writable locations, this is not optional. The fsGroup field only exists at the Pod level and sets volume ownership. The runAsNonRoot field enforces non-root execution and will fail the container if the image tries to run as root. Never use privileged set to true unless the question explicitly requires it, and even then question if there's a better approach. Always test your work with kubectl exec, running commands like id to verify user, touch /test.txt to verify filesystem restrictions, and checking that your application actually works.

## Time Management

Understanding time management for security questions is crucial. A typical security question should take between six and eight minutes total. Spend about one minute reading and understanding the requirements. Spend three to four minutes adding the securityContext YAML, either creating a new file or editing an existing resource. Spend two to three minutes applying and verifying that everything works. If you're stuck beyond eight minutes, flag the question and move on. You can return to it later if time permits, but don't let one question consume too much of your exam time.

## Additional Resources

During the exam, you have access to the official Kubernetes documentation. Make sure you know how to quickly navigate to the security context documentation at kubernetes.io/docs/tasks/configure-pod-container/security-context/ and the Pod Security Standards at kubernetes.io/docs/concepts/security/pod-security-standards/. Bookmark these pages before the exam so you can find them quickly if you need to verify syntax or field names. Additionally, kubectl explain is available during the exam and can be a lifesaver. Use kubectl explain pod.spec.securityContext or kubectl explain pod.spec.containers.securityContext to see field names and types without leaving your terminal.

## Summary

To succeed with SecurityContext questions on the CKAD exam, you must master several key areas. Understand Pod-level versus container-level SecurityContext and know which fields exist at which level. Be comfortable with runAsUser, runAsGroup, and runAsNonRoot for controlling user identity. Know how to implement readOnlyRootFilesystem with volumes for writable paths. Master the capabilities pattern of dropping ALL and adding specific ones. Understand fsGroup for volume permissions. Remember that allowPrivilegeEscalation should be set to false for production workloads. Have a production security baseline template memorized that you can type quickly.

SecurityContext carries significant weight on the exam because it's part of the Application Environment, Configuration and Security domain which represents 25 percent of your total score. This is the highest-weighted domain on the exam. Questions have medium difficulty because there are many fields to remember, but they're manageable with practice. Time yourself at six to eight minutes per question and practice until you can implement security contexts without referring to documentation. The key to success is making these patterns second nature through repeated practice.
