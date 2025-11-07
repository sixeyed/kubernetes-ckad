# Secrets - CKAD Narration Script

**Duration:** 20-25 minutes
**Format:** Screen recording with live demonstration
**Prerequisite:** Completed basic Secrets exercises

---

Welcome to the CKAD exam preparation module for Kubernetes Secrets. This session covers the advanced Secret topics and techniques required for the Certified Kubernetes Application Developer exam, building on what we learned in the exercises lab.

The CKAD exam tests Secrets heavily because they're fundamental to real-world Kubernetes deployments. You'll encounter Secret questions both standalone and integrated into larger application scenarios. With time constraints on the exam, you need to master imperative creation methods, understand all Secret types, and know troubleshooting workflows cold.

## Imperative Secret Creation

For the exam, imperative commands are your fastest option. You need to master all the creation methods.

Creating from literal values uses kubectl create secret generic with the from-literal flag. You can chain multiple from-literal flags to create multiple keys in one command. This is perfect for simple credentials with just a few values. Creating three key-value pairs takes about fifteen seconds with this method.

Creating from environment files works when you have many values. Put the key equals value pairs in a file, then use from-env-file. This instantly creates a Secret with all those keys. If the exam question provides multiple values in that format, this is your fastest approach.

Creating from files uses the from-file flag. The file contents are automatically base64-encoded and stored as the value. The filename becomes the key name unless you specify a custom key with equals syntax. This is essential for certificates and credential files.

Using dry-run for YAML generation lets you see exactly what will be created before applying it. Add dry-run equals client and output yaml to generate the YAML without creating the Secret. You can pipe this to a file for editing or review. This technique is valuable when you need to verify the Secret structure or when the question asks for YAML output.

## Secret Types

Kubernetes provides several built-in Secret types, each optimized for specific use cases.

Opaque Secrets are the default type. They can store arbitrary key-value pairs with no validation. This is what you get when you don't specify a type. Use these for general credentials, API keys, and configuration that needs encoding.

Docker registry Secrets store credentials for private container registries. Use kubectl create secret docker-registry with server, username, password, and email flags. The Secret is automatically formatted correctly for use as an image pull secret in Pod specs. This is a common exam scenario for pulling images from private registries.

TLS Secrets store certificate and private key pairs. Use kubectl create secret tls with the cert and key flags pointing to your files. The keys are automatically named tls.crt and tls.key, which is what Ingress resources expect. Know how to create these quickly for HTTPS scenarios.

ServiceAccount token Secrets are automatically created for ServiceAccounts. You typically don't create these manually, but you should understand that they exist and provide the tokens used for authenticating to the Kubernetes API.

Basic auth Secrets store username and password for basic authentication. SSH auth Secrets store SSH private keys. These are less common but knowing they exist shows comprehensive understanding.

For the exam, focus on Opaque, docker-registry, and TLS types as these appear most frequently.

## Using Secrets in Pods

Secrets can be consumed as environment variables or volume mounts, just like ConfigMaps.

For environment variables using envFrom with secretRef, all keys in the Secret become environment variables. This is clean and simple when you want everything loaded. You can add a prefix to avoid naming conflicts. Using env with valueFrom gives fine-grained control over which Secret keys become which environment variables. You can mix values from different Secrets, combine Secret values with ConfigMap values and literals, and make references optional so Pods start even if the Secret is missing.

For volume mounts, the entire Secret can be mounted where each key becomes a file. You define the Secret as a volume source and mount it in the container. All Secret values are decoded automatically. For mounting specific keys only, use the items field in the volume definition to select which keys to mount and optionally rename them. This is useful when you only need certain credentials from a larger Secret or when the key name doesn't match the desired filename.

The usage patterns are identical to ConfigMaps. If you know how to use ConfigMaps, you know how to use Secrets. Just swap the resource type in your Pod spec.

## Managing Secret Updates

Understanding Secret update behavior is critical for the exam.

When you update a Secret consumed as environment variables, existing Pods don't see the change. Environment variables are set at container start and never update. You must restart Pods to pick up new values, typically with kubectl rollout restart.

For Secrets mounted as volumes, Kubernetes automatically propagates updates to the mounted files in running Pods. The update isn't instant and can take up to a minute. Applications must actively re-read the files to see changes.

One pattern for handling updates is using annotation-based triggers. Add a hash of the Secret content as an annotation on the Deployment. When the Secret changes, update the annotation to trigger a rollout. This ensures Pods restart automatically when credentials change.

Another pattern is using immutable Secrets with versioned names. Create a new Secret with a version number when credentials change, like database-password-v2. Update the Deployment to reference the new Secret name. This triggers a rollout automatically and keeps the old Secret around for easy rollback.

Immutable Secrets, available since Kubernetes 1.21, cannot be modified after creation. Set the immutable field to true. This improves performance for Secrets that should never change and protects critical credentials from accidental modification. Once immutable, the only way to change the Secret is to delete and recreate it or create a new versioned Secret.

For the exam, remember that env updates require Pod restarts, volume updates propagate automatically, and immutable Secrets provide safety and performance benefits.

## Security Best Practices

It's important to understand that base64 encoding is not encryption. Anyone with kubectl access can decode Secret values. This is just obfuscation.

For real security, enable encryption at rest in etcd. This requires cluster administrator access and is typically handled at the platform level. Secrets are encrypted on disk but still decoded when accessed through kubectl.

Use RBAC to control who can access Secrets. Create roles that limit Secret access to only the namespaces and names needed. Never give broad Secret permissions across all namespaces.

For production environments, consider external secret management systems like HashiCorp Vault, AWS Secrets Manager, or Azure Key Vault. These provide true encryption, audit logging, automatic rotation, and fine-grained access control.

Never commit Secrets to git repositories, even if they're base64-encoded. Use encrypted secret management tools or separate secret repositories with restricted access. The stringData field makes it tempting to check in Secret YAML, but don't do it.

For the exam, you won't configure encryption or external systems, but knowing these best practices shows production-ready thinking.

## Troubleshooting Secrets

Common issues include Secret not found errors when the Secret name is misspelled or the Secret is in a different namespace. Check that the Secret exists using kubectl get secret and matches the name in the Pod spec exactly.

Key not found errors happen when a specific Secret key referenced in secretKeyRef doesn't exist. Verify the key name matches exactly, including case sensitivity.

Pod pending occurs when a required Secret doesn't exist. The Pod stays pending until the Secret is created. Check kubectl describe pod output for the missing Secret message.

For base64 encoding issues, remember to encode values for the data field and leave values plain for the stringData field. Incorrect encoding causes Pod startup failures.

For image pull errors with docker-registry Secrets, verify the Secret is referenced in imagePullSecrets, check that the Secret contains the right registry credentials, and ensure the Secret is in the same namespace as the Pod.

The debugging workflow is checking if the Secret exists, verifying keys and values are correct, checking that the Pod spec references the right Secret and keys, describing the Pod for detailed error messages, and exec into the container to verify environment variables or mounted files if the Pod is running.

## Using Secrets with ServiceAccounts

Every Pod runs with a ServiceAccount, and ServiceAccounts can have associated Secrets for image pulling. To use a private registry Secret, add it to the ServiceAccount's imagePullSecrets field. Then all Pods using that ServiceAccount automatically get the image pull secret without specifying it in each Pod spec.

This pattern centralizes credential management. You set the image pull secret once on the ServiceAccount, and it applies to all Pods using that account.

## CKAD Exam Tips

For speed commands, create generic Secrets with kubectl create secret generic using from-literal for simple values. Create docker-registry Secrets with kubectl create secret docker-registry for private registries. Create TLS Secrets with kubectl create secret tls for certificates. Edit Secrets with kubectl edit secret. View Secrets with kubectl get secret and kubectl describe secret. Decode Secret values by extracting with jsonpath and piping through base64 decode.

Common patterns include adding Secrets to Deployments with envFrom or env, mounting Secrets as volumes for file-based credentials, creating image pull secrets and adding them to ServiceAccounts or Pods, and making Secret references optional so Pods start without them.

Practice these patterns until you can execute them in under thirty seconds each. Exam success comes from speed and accuracy.

## Lab Challenge: Multi-Tier Application with Secrets

The lab challenge asks you to deploy a complete application using multiple Secret types. You'll create database credentials as an Opaque Secret, create TLS certificates as a TLS Secret, create image pull credentials as a docker-registry Secret, configure a frontend Deployment using the database Secret, configure a backend Deployment using the TLS Secret, and configure both to use the registry Secret for pulling images.

This integrates all Secret concepts in a realistic application architecture and tests your ability to work with multiple Secret types simultaneously.

## Quick Reference

For creation, use kubectl create secret generic for Opaque Secrets, kubectl create secret docker-registry for registry credentials, and kubectl create secret tls for certificates. For usage in Pods, use envFrom for loading all keys, env with valueFrom for specific keys, and volumes with secret source for file mounting. For viewing, use kubectl get secret to list Secrets, kubectl describe secret for details, and kubectl get secret with jsonpath and base64 decode for values.

## Cleanup

When you're finished, remove all CKAD practice resources using the label selector. This deletes all Secrets, Deployments, and Pods we created.

That completes our CKAD preparation for Kubernetes Secrets. You now have comprehensive knowledge of Secret creation, consumption, and troubleshooting. Practice these scenarios until they're muscle memory. Build speed through timed drills. Master the imperative commands since they're fastest for the exam. Understand the security limitations and best practices. With this foundation, you'll confidently handle any Secret question on the CKAD exam.
