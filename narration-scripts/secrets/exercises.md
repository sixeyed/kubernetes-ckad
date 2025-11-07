# Secrets - Exercises Narration Script

**Duration:** 15-18 minutes
**Format:** Screen recording with live demonstration
**Prerequisite:** Kubernetes cluster running, completed ConfigMaps lab

---

Welcome back! In the previous ConfigMaps lab, we saw how to externalize configuration from container images. Now we'll explore Secrets, which are designed specifically for sensitive data like passwords, API keys, and certificates.

Secrets work very similarly to ConfigMaps, but with important differences around how the data is stored and accessed. We'll use the same configurable demo application from the ConfigMaps lab, which makes it easy to compare the two approaches and see how they work together.

## API specs

Let's start by understanding how Secrets differ from ConfigMaps in their YAML structure. Secrets have a data section just like ConfigMaps, but the values must be base64-encoded. There's also a stringData field that accepts plain text values and automatically converts them to base64 when applied. This makes Secrets much easier to work with.

The Pod spec for consuming Secrets looks almost identical to ConfigMaps. Instead of configMapRef, you use secretRef. Instead of configMapKeyRef, you use secretKeyRef. The pattern is the same, just swapping the resource type. This consistency makes it easy to switch between ConfigMaps and Secrets when you realize certain configuration should be protected.

For volume mounts, Secrets use the same pattern as ConfigMaps. You define a volume with a secret source instead of a configMap source, then mount it in the container. The Secret values appear as files in the container filesystem, decoded from base64 automatically.

## Creating Secrets from encoded YAML

Let's create our first Secret using base64-encoded values in YAML. The Secret definition has a data field containing keys with base64-encoded values. This encoding is reversible, so anyone can decode it. It's important to understand that encoding is not encryption. The encoding simply prevents values from being visible at a glance.

Looking at the Deployment that uses this Secret, the syntax is almost identical to ConfigMaps. The envFrom section uses secretRef instead of configMapRef. That's the only difference in the Pod spec.

When I apply the Secret and Deployment, then check how the Secret appears in the cluster, the value is base64-encoded in storage and when you retrieve it with kubectl. This provides minimal protection. It's not visible at a glance, but anyone with kubectl access can decode it. Inside the running container, the Secret value is surfaced as a plain text environment variable. The application doesn't need to know anything about base64 encoding.

## Creating Secrets from plaintext YAML

Base64 encoding is awkward when writing YAML by hand. You need to encode values before putting them in your files, and it gives a false sense of security. Kubernetes provides a better option called stringData.

With stringData instead of data, the values are in plain text in your YAML file. When you apply this YAML, Kubernetes automatically converts the values to base64 for storage. This is much more convenient for manual YAML authoring. The security is identical because both approaches result in base64-encoded values in etcd.

When I deploy a Secret using stringData and check it with kubectl get, the output shows the data field with base64-encoded values, not stringData. Kubernetes converted it during creation. This makes Secret files more readable while maintaining the same storage format.

## Working with base-64 Secret values

Sometimes you need to work directly with the base64 values. Let me demonstrate the encoding and decoding process. To encode a value for a Secret data field, you use the base64 command with the string piped to it. To decode a value retrieved from kubectl, you pipe it through base64 with the decode flag.

This is useful when you need to quickly create Secret YAML from existing values or when troubleshooting to see what values are actually stored in a Secret. For the CKAD exam, being comfortable with base64 encoding and decoding saves time when working with Secrets imperatively.

## Creating Secrets from files

For file-based secrets like TLS certificates or SSH keys, creating Secrets from files is the most practical approach. The kubectl create secret command with the from-file flag reads the file contents and base64-encodes them automatically.

When you use from-file, the filename becomes the key name in the Secret by default. You can specify a custom key name using equals syntax. This is the same pattern as ConfigMaps from files.

When you mount a file-based Secret as a volume, each key becomes a file in the mount path, with the decoded contents as the file data. The application reads these files just like any other files in the filesystem. This is perfect for certificates, SSH keys, and other credential files that applications expect to read from disk.

## Lab

Now it's your turn to experiment. The lab challenge involves working with Secret data to configure an application. You'll need to create Secrets from different sources, use them in Pods through both environment variables and volume mounts, and understand how Secret updates affect running Pods.

This lab helps solidify the patterns you'll use in real applications. Secrets for database credentials, Secrets for API tokens, Secrets for TLS certificates. These are all common scenarios you'll encounter in production Kubernetes deployments and on the CKAD exam.

## Cleanup

When you're finished with the lab, cleanup by removing all resources with the kubernetes.courselabs.co equals secrets label. This removes the Deployments, Services, ConfigMaps, and Secrets we created.

That wraps up our hands-on exploration of Secrets. We've seen how Secrets provide base64 encoding for sensitive data, how they integrate seamlessly with Pods using the same patterns as ConfigMaps, how to create Secrets from encoded YAML, plaintext YAML, and files, and how Secret values are decoded automatically when consumed by applications. These skills are essential for securing applications in Kubernetes. In the next video, we'll explore CKAD-specific scenarios including different Secret types, imperative creation methods, update strategies, and security best practices.
