# ConfigMaps - CKAD Narration Script

**Duration:** 20-25 minutes
**Format:** Screen recording with live demonstration
**Prerequisite:** Completed basic ConfigMaps exercises

---

Welcome to the CKAD exam preparation module for Kubernetes ConfigMaps. This session covers the advanced ConfigMap topics and techniques you'll encounter on the Certified Kubernetes Application Developer exam, building on what we learned in the exercises lab.

The CKAD exam is time-constrained, and ConfigMaps appear in multiple questions both as standalone topics and as part of larger application deployment scenarios. You need to know all ConfigMap creation methods, advanced consumption patterns, update strategies, and troubleshooting techniques.

## Creating ConfigMaps - Multiple Methods

Kubernetes provides four different ways to create ConfigMaps, and you need to know when to use each one for the exam. Speed matters during the exam, so choosing the right method saves valuable time.

The first method is from YAML using declarative configuration. This is the standard Kubernetes approach where you define the ConfigMap structure in a YAML file and apply it with kubectl. The data section contains key-value pairs, and for multi-line values you use the pipe symbol for literal blocks or the greater-than symbol for folded blocks. This method is best when you need version control, when the ConfigMap is complex, or when you're building reusable templates.

The second method is from literal values using imperative commands. You use kubectl create configmap with the from-literal flag to specify key-value pairs directly on the command line. You can chain multiple from-literal flags to create multiple keys in one command. This is the fastest method for simple configuration with a few values, perfect for exam scenarios with just two or three settings.

The third method is from files. You use the from-file flag to create ConfigMap keys from file contents. The filename becomes the key name unless you specify a different key with equals syntax. You can also use from-env-file for files in key equals value format, which creates individual keys rather than a single file-content key. This method is ideal when you have existing configuration files or when you need to preserve file structure.

The fourth method is from directories. You use from-file pointing to a directory, and kubectl creates a key for each file in that directory. This is useful when you have multiple related configuration files that should all be loaded together.

For the exam, practice switching between methods quickly. If the question provides values inline, use from-literal. If they give you a file path, use from-file. Understanding which method fits each scenario saves critical time.

## Consuming ConfigMaps as Environment Variables

There are multiple ways to inject ConfigMap data as environment variables, each with specific use cases.

The most common pattern is loading all keys as environment variables using envFrom with configMapRef. This takes every key in the ConfigMap and creates a corresponding environment variable. It's simple and clean, perfect when you want all the configuration loaded. You can also add a prefix to all the environment variable names using the prefix field, which helps avoid naming conflicts when loading from multiple ConfigMaps.

For selective loading, use the env section with valueFrom referencing specific ConfigMap keys. This gives you fine-grained control over which values get loaded and lets you rename them as environment variables. You can mix values from different ConfigMaps, combine ConfigMap values with literal values and other sources, and set up optional references that don't fail if the key is missing.

For the exam, know when to use each approach. If the question asks to load all configuration, use envFrom. If it specifies certain values only, use env with valueFrom. Practice both patterns until they're automatic.

## Consuming ConfigMaps as Volume Mounts

ConfigMaps can also be mounted as files in the container filesystem, which is more powerful for complex configuration.

Mounting the entire ConfigMap creates a file for each key in the ConfigMap, with the key name as the filename and the value as the file contents. You define the ConfigMap as a volume in the Pod spec and use volumeMounts to specify where it appears in the container. All files appear as read-only by default.

For mounting specific keys, use the items field in the volume definition to select which keys to mount and optionally rename them using the path field. This is useful when you only need certain configuration files from a larger ConfigMap or when the key name doesn't match the desired filename.

An important technique is using subPath to mount individual files without replacing entire directories. Without subPath, mounting a volume replaces all contents of the target directory. With subPath, you can add individual files to an existing directory, preserving other files that were there. This is critical when you need to inject one configuration file into a directory that already contains other important files.

For the exam, understand the difference between these mounting strategies. Questions often require preserving existing directory contents, so subPath is essential knowledge.

## File Permissions for ConfigMap Volumes

When ConfigMaps are mounted as volumes, the file permissions default to six hundred forty-four, readable by all users but writable only by the owner. You can customize this using the defaultMode field in the volume definition, specifying permissions in octal format.

This is important when applications require specific file permissions. Some applications refuse to read configuration files that are world-readable for security reasons. Others need execute permissions on files. Know how to set defaultMode to match application requirements.

## ConfigMap Updates and Propagation

Understanding how ConfigMap updates work is critical for the exam. When you update a ConfigMap that's consumed as environment variables, existing Pods don't see the change. Environment variables are set when the container starts and never change. You need to restart Pods to pick up the new values, typically by doing a rollout restart of the Deployment.

For ConfigMaps mounted as volumes, Kubernetes automatically propagates updates to the mounted files in running Pods. The update isn't instant. It can take up to a minute for changes to appear due to the kubelet sync period. Applications need to actively re-read the files to see changes, as most applications only read configuration at startup.

You can also create immutable ConfigMaps by setting the immutable field to true. Immutable ConfigMaps cannot be modified after creation. This improves performance for ConfigMaps that should never change and protects critical configuration from accidental modification. Once a ConfigMap is immutable, the only way to change configuration is to create a new ConfigMap and update Pods to use it.

For the exam, know that env variable updates require Pod restarts, volume mount updates propagate automatically but applications must re-read, and immutable ConfigMaps cannot be changed after creation.

## Binary Data in ConfigMaps

ConfigMaps can store binary data using the binaryData field instead of the data field. Values must be base64-encoded. This is useful for certificates, images, or other non-text files. The binaryData field works with volume mounts but not with environment variables, since environment variables must be strings.

For the exam, if you see binary files or base64-encoded content, use binaryData rather than data. Mount them as volumes, not environment variables.

## ConfigMap Size Limits

ConfigMaps are stored in etcd and have a size limit. Each ConfigMap can be at most one megabyte. This includes all keys and values combined. If your configuration is larger, you need to split it into multiple ConfigMaps or use other storage solutions like Secrets for sensitive data or PersistentVolumes for large files.

For the exam, be aware that extremely large configuration files might exceed ConfigMap limits. The exam questions typically use realistic sizes, but knowing the limit shows deeper understanding.

## Optional ConfigMaps

When referencing a ConfigMap in a Pod, it normally fails if the ConfigMap doesn't exist. You can make ConfigMap references optional so Pods start even if the ConfigMap is missing. Use the optional field set to true in the configMapRef or configMapKeyRef. The Pod will start, but the environment variables or mounted files won't be present.

This is useful for optional configuration that might not exist in all environments. For the exam, look for scenarios where Pods should start even if configuration is missing, and add the optional field.

## Using ConfigMaps with Command Arguments

ConfigMap values can be used in container commands and arguments using environment variable expansion. First, load the ConfigMap key as an environment variable, then reference that variable in the command or args fields using standard shell syntax with dollar sign and parentheses.

This is powerful for passing configuration-driven parameters to applications. For the exam, practice combining ConfigMaps with container commands to create dynamic application startup.

## Troubleshooting ConfigMaps

Common issues include ConfigMap not found errors when the ConfigMap name is misspelled or the ConfigMap is in a different namespace. Check that the ConfigMap exists and matches the name in the Pod spec exactly.

Key not found errors happen when a specific ConfigMap key referenced in valueFrom doesn't exist in the ConfigMap. Verify the key name matches exactly, including case sensitivity.

Pod pending when a required ConfigMap doesn't exist, the Pod stays in pending state. Check describe pod output to see the missing ConfigMap issue.

For environment variable issues, remember that environment variables are set at container start and never update. If you change a ConfigMap, restart the Pods to see new values.

For file mount issues, check that the mount path doesn't conflict with existing application files unless you're using subPath, verify file permissions with defaultMode, and remember that updates to mounted ConfigMap files take up to a minute to propagate.

The debugging workflow starts with checking if the ConfigMap exists, verifying the keys and values are correct, checking the Pod spec references the right ConfigMap and keys, describing the Pod to see detailed error messages, and exec into the container to verify environment variables or mounted files.

## Lab Exercises

The lab exercises combine multiple ConfigMap concepts in realistic scenarios.

The multi-method creation exercise asks you to create the same ConfigMap using all four methods and compare the results. This builds muscle memory for choosing the right creation method.

The mixed environment variable sources exercise requires loading values from multiple ConfigMaps and combining them with literal values and other sources. This tests your understanding of env versus envFrom and value precedence.

The selective key mounting exercise asks you to mount specific keys from a ConfigMap with custom filenames. This tests the items field usage and path remapping.

The update propagation exercise has you update ConfigMaps and observe the behavior difference between environment variables and volume mounts. This reinforces that env updates require restarts while volume updates propagate automatically.

## Quick Command Reference for CKAD

Let me summarize the time-saving commands you need for the exam. Create from literals with kubectl create configmap using from-literal flags. Create from files with from-file pointing to the file path. Create from env files with from-env-file for key equals value format. Create from directories with from-file pointing to a directory.

Edit ConfigMaps with kubectl edit configmap. View ConfigMaps with kubectl get configmap and kubectl describe configmap. Delete ConfigMaps with kubectl delete configmap. For dry-run and yaml output, add dry-run equals client and output yaml to generate YAML without applying it.

Practice these commands until you can type them without thinking. Speed during the exam comes from command familiarity.

## Common CKAD Exam Scenarios

Typical exam scenarios include creating a ConfigMap from specific values and using it in a Deployment, updating an existing application to use ConfigMap for configuration instead of hardcoded values, mounting configuration files from a ConfigMap while preserving existing directory contents, and troubleshooting Pods that won't start due to missing ConfigMap references.

For each scenario, there's a specific approach. For creation and usage, decide on the creation method based on what's provided, create the ConfigMap imperatively if it's simple, and modify the Deployment to reference it with envFrom or volumes. For updating applications, create the ConfigMap first, then edit the Deployment to add ConfigMap references, and use rollout status to verify the update.

For file mounting with preservation, use volume with items to select specific keys, add volumeMount with subPath to mount individual files, and verify the original files are still present. For troubleshooting, check that the ConfigMap exists in the correct namespace, verify the keys match what the Pod expects, make ConfigMap references optional if appropriate, and recreate the ConfigMap if it's missing.

## Study Tips for CKAD

For ConfigMaps on the CKAD exam, memorize the four creation methods and when to use each. Practice creating ConfigMaps imperatively in under ten seconds. Know the difference between env and envFrom cold. Understand that subPath preserves directory contents. Remember that environment variable updates need Pod restarts while file mount updates propagate automatically.

Set up quick practice drills. Can you create a ConfigMap from literals in five seconds? Can you add it to a Deployment in ten seconds? Can you troubleshoot a missing ConfigMap in thirty seconds? These timed drills build the speed you need.

## Cleanup

When you're finished, remove all CKAD practice resources using the label selector. This deletes all ConfigMaps, Deployments, and Pods we created during this session.

That completes our CKAD preparation for Kubernetes ConfigMaps. You now have the comprehensive knowledge needed for ConfigMaps on the CKAD exam. Practice these scenarios until they're muscle memory. Build speed through repetition. Use kubectl explain during practice since it's available during the exam. Master these patterns, and you'll handle any ConfigMap question confidently on exam day.
