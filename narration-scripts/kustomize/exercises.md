# Kustomize - Exercises Narration Script

Welcome to the hands-on Kustomize exercises. In this session, we'll explore how to manage application configurations across multiple environments using Kustomize's base and overlay pattern. Kustomize is a template-free way to customize Kubernetes application configurations, and unlike Helm, it's built directly into kubectl, making it a native Kubernetes tool for managing configuration across multiple environments.

## Kustomize vs Helm

Before we dive into the exercises, let's quickly understand when to use Kustomize versus Helm. Kustomize works by applying overlays and patches to existing YAML files. There's no special template syntax to learn, just standard Kubernetes YAML. It's built into kubectl with the apply-k flag, so you don't need any separate tools installed. However, it doesn't have built-in package management or a registry system. Kustomize shines when you're deploying the same application across different environments like dev, staging, and production.

Helm takes a different approach with templates and variables. It has a steeper learning curve because you need to learn the Go template syntax, but it provides powerful package management through Helm repositories with chart versioning. Helm is better suited for creating distributable application packages that others can install. For the CKAD exam, you need to know both tools. Kustomize is perfect for environment-specific configs while Helm is better for packaging reusable applications.

## Create a Base Configuration

Let's start with a simple application that needs different configurations for dev, staging, and production environments. We'll begin by examining the base resources. The base directory contains three files: deployment.yaml with basic Deployment settings, service.yaml to expose the app, and kustomization.yaml that lists the resources to include.

Take a look at the base kustomization file. It's very simple, just listing YAML files to include. The deployment and service files are standard Kubernetes YAML with no special syntax or template variables. This is the power of Kustomize - the base configuration is pure, readable Kubernetes YAML that anyone can understand without learning a template language.

Let's apply the base configuration using kubectl apply with the -k flag. The -k flag tells kubectl to look for a kustomization.yaml file and process it. When we check what was created, we'll see a deployment with 2 replicas and a service. Notice the objects don't have any environment-specific naming or configuration.

Now let's delete this base deployment to prepare for using overlays. The -k flag works with delete too, removing everything defined in the kustomization.

## Using Overlays for Different Environments

Now we'll deploy environment-specific variants using overlays. Each overlay references the base and applies customizations for a particular environment.

### Development Environment

The development overlay is straightforward. Looking at the dev overlay kustomization, you'll see it references the base using a relative path to the parent directory, then applies simple customizations. It adds a dev- prefix to all resource names and sets the namespace to dev. This is a simple overlay that only changes names and namespace, so no patches are needed.

Let's create the dev namespace and deploy the overlay. When we check what was created, notice all resources have the dev- prefix. The replica count and image tag come from the base configuration. The overlay only changed the name prefix and namespace. This is exactly what we want - reuse the base, customize only what's different.

### Staging Environment

The staging environment needs different configuration. It requires more replicas and a different image tag. Looking at the staging overlay kustomization, it still references the base and adds a staging- prefix, but it also overrides replicas to 3 and changes the image tag using the images field. The images field is a Kustomize built-in feature for updating container image tags without needing a patch.

After deploying to staging, let's compare the two environments. Staging has 3 replicas compared to 2 in dev, and uses a different image tag. All of this came from a simple overlay that only specifies the differences. This demonstrates Kustomize's efficiency - the base contains common configuration, overlays contain only environment-specific changes. No duplication, easy to maintain.

### Production Environment

Production requires more substantial configuration changes including higher replica count, resource limits, and specific labels. This needs patches. Looking at the prod overlay structure, the kustomization references the base and two patch files, adds a prod- prefix, and sets the namespace to production.

The patches use strategic merge syntax. The replica-patch increases replicas to 5 by just specifying the fields to change. The resources-patch adds resource limits and requests. Strategic merge patches are intuitive - you write YAML for only the fields you want to modify, and Kustomize merges it with the base.

After deploying to production, we can inspect the deployment to see it has 5 replicas and resource limits applied through the patches. We can also view what Kustomize generated before it was applied, which is useful for debugging. This shows the complete YAML that was sent to kubectl with all the overlays and patches merged together with the base.

## Common Kustomize Features

Let's briefly explore some other Kustomize features that you might encounter. Kustomize can generate ConfigMaps from literals or files. This creates a ConfigMap with a hash suffix for versioning. When values change, a new ConfigMap is created, which triggers pod restarts automatically.

You can also add common labels that get applied to every resource in the kustomization, making filtering and management easier. We've already seen namePrefix in action. There's also nameSuffix that works the same way, allowing you to version your resources.

For complex modifications, you can use JSON patches for surgical precision, though they're more complex. Use strategic merge patches when possible. For CKAD, focus on strategic merge patches and built-in transformations since they cover most scenarios.

## Viewing Generated YAML

You can see what Kustomize will generate without actually applying it to your cluster. This is extremely useful for debugging and understanding what changes will be made. The kubectl kustomize command shows the final YAML after all transformations, letting you verify everything looks correct before applying.

## Lab Exercise

Now for the lab challenge. Create a new overlay for a QA environment with these requirements: namespace qa, name prefix qa-, replicas 4, custom label environment=qa, and image tag v1-alpine.

Start by creating the overlay directory structure, then create the kustomization.yaml file with all the required settings. Preview what this will generate to verify everything looks correct. You should see resources with the qa- prefix, namespace set to qa, labels including environment=qa, replicas set to 4, and image tag v1-alpine. After verifying the preview, deploy it and check that all requirements are met. This demonstrates how quickly you can create new environments with Kustomize. The entire overlay is about 15 lines of YAML.

## Common Kustomize Commands

Let's review the essential Kustomize commands you'll use regularly. Apply a kustomization with kubectl apply -k pointing to a directory. View generated YAML without applying using kubectl kustomize. Delete resources from a kustomization with kubectl delete -k. You can validate kustomization structure by piping the output to dev null and checking for errors. Compare differences between overlays using kubectl diff. The -k flag is the key to remember - it works with apply, delete, diff, and other kubectl commands.

## Best Practices

When working with Kustomize, keep your base generic and environment-agnostic so it can work for any environment. Make overlays small and focused on only the differences per environment. Use built-in features like replicas and images transformations before resorting to patches since they're simpler to maintain. Always preview with kubectl kustomize before applying to catch any errors early. Keep everything in version control, both base and overlays, for tracking changes over time. Use different namespaces for each environment to maintain isolation. Apply common labels consistently for easy filtering and management across your resources.

## Cleanup

When you're finished, clean up all the environments by deleting each overlay and removing the namespaces. This removes all Deployments, Services, and other resources we created in this session.

## Key Takeaways

Kustomize works with template-free configuration using standard YAML with no special syntax. It's built into kubectl with the apply -k flag, so no additional tools are needed. The base plus overlays pattern lets you reuse common configs and customize per environment. Patches allow both strategic merge and JSON patches for specific changes. Generators create ConfigMaps and Secrets declaratively with automatic versioning. For the CKAD exam, you must know how to use Kustomize effectively.

You now have hands-on experience with Kustomize across multiple environments. We've seen how to create base configurations, build overlays for different environments, use both simple transformations and complex patches, generate ConfigMaps with version hashing, and manage complete application configurations declaratively. In the next session, we'll focus on CKAD exam-specific scenarios and time-saving techniques to help you work efficiently under exam time pressure.
