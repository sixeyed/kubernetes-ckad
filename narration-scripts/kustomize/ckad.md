# Kustomize - CKAD Exam Preparation

Welcome to the CKAD exam preparation session for Kustomize. Unlike Helm which is supplementary, Kustomize is a required topic for CKAD certification, and you will encounter Kustomize questions on the exam. The CKAD exam is performance-based with strict time limits, so your Kustomize skills must be fast and accurate. In this session, we'll focus on CKAD-specific skills, fast kustomization creation techniques, common exam scenarios, troubleshooting approaches, and timed practice exercises.

## Why Kustomize Matters for CKAD

Kustomize falls under the Application Deployment domain, which represents 20 percent of the exam. This is a critical topic because it's an explicit exam requirement. You will likely face at least one question requiring you to create or modify a kustomization.yaml file, deploy resources using kubectl apply -k, create overlays for different environments, or understand base and overlay patterns. Expect to spend 5 to 8 minutes per Kustomize question on the exam.

## Quick Reference for the Exam

Let's start with the essential commands you'll need. The most common command is kubectl apply -k pointing to a directory. For debugging, use kubectl kustomize to preview output without applying. To remove resources, use kubectl delete -k. You can also see changes before applying with kubectl diff -k.

The basic kustomization.yaml structure starts with apiVersion kustomize.config.k8s.io/v1beta1 and kind Kustomization. Under resources, you list the YAML files to include. Common labels can be added to all resources using commonLabels. Add prefixes to all resource names with namePrefix. Set the namespace for all resources with namespace. Modify replicas using the replicas field with name and count. Change images using the images field with name and newTag. Memorize this structure since you'll need to write it from memory during the exam.

## Exam Scenarios You'll Face

Let's walk through typical CKAD scenarios you'll encounter. The first scenario asks you to create a kustomization from existing YAML files. Given deployment.yaml and service.yaml, you need to create a kustomization.yaml that applies both resources with a prod- prefix and sets namespace to production. The solution is straightforward: include the resources, set namePrefix to prod-, and set namespace to production. Then apply with kubectl apply -k pointing to the current directory.

The second scenario involves creating environment-specific overlays. You might be asked to create a prod overlay that references the base directory and sets replicas to 5. This requires understanding the directory structure with base containing its kustomization and deployment, and overlays containing prod with its kustomization. The prod overlay references the base using a relative path, adds namePrefix prod-, sets namespace to production, and configures replicas with name and count.

The third scenario tests patching skills. You might need to add an environment variable to a deployment using a patch. Create a patch file that specifies the deployment's apiVersion, kind, and name, then adds the environment variable in the container spec. Update the kustomization to include this patch under the patches section.

The fourth scenario deals with changing image tags. When asked to deploy a staging environment with a different image tag, you use the images field in the kustomization, specifying the image name and newTag. This is simpler than creating a patch for something Kustomize has built-in support for.

## Common Kustomize Transformations

You need to know these transformations by heart. The namePrefix adds a prefix to all resources like dev-. The nameSuffix adds a suffix like -v2. The namespace field sets the namespace for all resources. Common labels adds labels to all resources using key-value pairs. Common annotations works similarly for annotations. The replicas field changes replica count with an array of name and count pairs. The images field changes image tags with an array of name and newTag pairs. Practice these until you can write them without looking them up.

## Exam Tips and Time Savers

Speed is critical on the CKAD exam. Always use kubectl kustomize first to preview output before applying. This catches errors early without affecting your cluster. Review the preview carefully, then apply with kubectl apply -k when everything looks correct.

Remember the -k flag works with many kubectl commands including apply, delete, diff, and get. This consistency makes it easy to remember. When creating overlays, always include the resources section that references the base. In overlays, the resource list typically contains just the path to your base directory. Use relative paths, not absolute paths, for portability.

Keep it simple by using built-in transformations before resorting to patches. For changing replicas, use the replicas field rather than a patch. For changing image tags, use the images field. For adding labels, use commonLabels. Patches should only be used when the built-in transformations don't cover your needs.

## Troubleshooting on the Exam

When you encounter errors, follow a systematic troubleshooting workflow. If you see "no matches for kind" errors, the problem is usually a missing apiVersion or kind in your kustomization.yaml. Make sure you included the header with apiVersion kustomize.config.k8s.io/v1beta1 and kind Kustomization.

When you see "unable to find one or more files" errors, check your paths in resources or patches. These should be relative paths from the kustomization file's location. Use ls to verify files actually exist at the paths you specified.

If you encounter "resource already exists" errors, resources may have been applied previously causing name collisions. Either delete the existing resources first or use a different namePrefix to avoid conflicts.

When resources don't appear in the expected namespace, you likely forgot to set the namespace field in your overlay. Add namespace with the appropriate namespace name to your kustomization.

The most important debugging technique is always using kubectl kustomize to preview what will be applied. This shows you the complete generated YAML before it goes to the cluster, letting you spot problems immediately.

## Kustomize vs Helm

Both tools are in the CKAD curriculum, so you need to know when to use each. For the exam, think Kustomize when you see mentions of environment configs like dev, staging, and prod. Kustomize is applied with kubectl apply -k and uses standard YAML without templates. It's built into kubectl from version 1.14 onwards. It's best suited for deploying the same app across multiple environments.

Helm is installed with helm install and uses Go templates for configuration. It's not built-in and requires a separate tool. It's best suited for distributing reusable applications. If the question mentions dev, staging, and prod environments, you want Kustomize. If it's about installing packaged apps from a repository, you want Helm.

## Practice Scenarios

Let's work through some timed practice scenarios. Time yourself for 7 minutes on each one. The first practice involves creating a basic kustomization that includes deployment.yaml and service.yaml, sets namespace to test, adds prefix test-, and sets replicas to 3. Create the kustomization.yaml with all required fields, then apply with kubectl apply -k.

The second practice uses the overlay pattern. Given a base directory with resources, create an overlay in overlays/dev with namespace development, prefix dev-, and image tag v1-dev. The kustomization references the base, sets the namespace and prefix, and uses the images field to change the tag. Apply with kubectl apply -k pointing to the overlay directory.

The third practice is about quick deployment changes. Change the image tag of an existing kustomization from v1 to v2 and reapply. Add or update the images section in the kustomization with the new tag, then reapply with kubectl apply -k.

## Exam Day Checklist

Before attempting a Kustomize question, follow this checklist. Read the question carefully and note the environment like dev, staging, or prod. Check if a specific namespace is required and needs to be created first. Verify you're in the right directory before creating files. Preview first with kubectl kustomize to check the output looks correct. Apply using kubectl apply -k pointing to the appropriate directory. Verify that resources were created correctly using kubectl get.

## Key Points to Remember

Kustomize is built into kubectl, so you use kubectl apply -k rather than a separate tool. The base plus overlays pattern is fundamental for environment management. Unlike Helm, there's no templating involved - Kustomize works with standard YAML. Common transformations include namePrefix, namespace, replicas, and images. Always use relative paths in resources and patches for portability. Preview with kubectl kustomize before applying to catch errors early. Know the difference between Kustomize and Helm and when to use each.

## Time Management

A typical Kustomize exam question should take 6 to 8 minutes. Budget 1 minute to read and understand the requirements. Spend 3 to 4 minutes creating or modifying the kustomization.yaml file. Use the remaining 2 to 3 minutes to apply and verify the configuration works correctly. If you're stuck beyond 8 minutes, flag the question and move on. You can come back later if time permits.

## Additional Resources

During the exam, you have access to the Kubernetes documentation. The Kustomization documentation at kubernetes.io and the Kustomization reference at kubectl.docs.kubernetes.io are particularly useful. Bookmark these pages before the exam so you can find them quickly if needed.

## Summary

For CKAD success, you must master creating kustomization.yaml files from scratch, understanding the base and overlay pattern, using kubectl apply -k effectively, knowing common transformations like namespace, namePrefix, replicas, and images, and understanding when to use Kustomize versus Helm. This material falls under the Application Deployment domain worth 20 percent of your total score. Expect to spend 6 to 8 minutes per question. With practice, the difficulty level is medium and very manageable.

## Deep Dive: Base and Overlay Pattern

The base and overlay pattern is fundamental to Kustomize and commonly appears on the CKAD exam. Understanding this pattern thoroughly is essential. The base contains your core application manifests that are common across all environments. This typically includes the kustomization.yaml file that lists resources, deployment.yaml defining your workload, service.yaml for networking, and configmap.yaml for configuration data. These files represent what's shared across all environments.

The overlay contains environment-specific customizations that build on the base. You typically have separate directories for development, staging, and production, each with their own kustomization.yaml and any environment-specific patches. Each overlay references the base and applies only the changes needed for that particular environment.

## Exercise 1: Create Development Overlay

Let's work through creating a development overlay step by step. The task is to create a development overlay that references the base configuration, sets namespace to development, adds prefix dev-, changes replicas to 2, changes image tag to 1.22, and adds label environment dev.

Start by creating the directory structure with mkdir. Then create the kustomization file in the development overlay directory. The kustomization references the base using a relative path, sets the namespace to development, adds the namePrefix dev-, includes commonLabels with environment dev, configures replicas for the webapp with count 2, and sets the image tag to 1.22 using the images field.

Preview the output using kubectl kustomize to see what will be created. Review the generated YAML carefully. You should see the deployment named dev-webapp in the development namespace, with 2 replicas, image nginx version 1.22, and all resources labeled with environment dev.

Create the namespace first, then apply the kustomization. Verify the deployment was created correctly by checking all resources in the namespace, examining the deployment details for replicas and image, checking that pods are running with the correct labels, and testing that the service is accessible.

## Exercise 2: Create Production Overlay with Patches

Now let's tackle a production overlay that requires patches. The task is to create a production overlay that references the base, sets namespace to production, adds prefix prod-, sets replicas to 5, adds resource limits and requests, adds environment variable ENVIRONMENT=production, and uses a strategic merge patch for the environment variable.

Start by creating the production directory structure. Create a patch file for the environment variable that specifies the deployment's apiVersion, kind, and name, then adds the environment variable and resource constraints in the container spec. The resources section includes requests for memory and CPU, and limits for maximum usage.

Create the kustomization file that references the base, sets namespace to production, adds namePrefix prod-, includes production-specific labels, sets high replica count for production, uses a stable image tag, and applies the strategic merge patch you created.

Create the production namespace, preview the kustomization output, then apply it. Verify all customizations were applied correctly by checking replicas, checking the image version, checking the environment variable, checking resource limits and requests, and confirming all labels are present.

## Exercise 3: Multi-Environment Deployment

This scenario tests your ability to deploy to multiple environments simultaneously with different configurations. You need to deploy to development with 1 replica, staging with 3 replicas, and production with 5 replicas, each with environment-specific settings for image tags and service types.

Create all directory structures first for development, staging, and production. The development overlay uses the latest image tag and ClusterIP service type. The staging overlay uses version 2.0 and ClusterIP. Production uses version 2.0 but requires a NodePort service on port 30080.

For production, you'll need a service patch to change the service type to NodePort and specify the node port. The patch file modifies just the service type and port configuration without repeating the entire service definition.

Create all namespaces, then deploy to all environments using kubectl apply -k for each overlay directory. Verify all deployments across all namespaces, compare configurations between environments, and check that services have the correct types and ports. This demonstrates how the same base configuration can be deployed to multiple environments with each having unique customizations.

## Advanced Kustomize Features

Beyond the basics, you should understand ConfigMap and Secret generators for the exam. Kustomize can generate ConfigMaps and Secrets from files or literals. When generating from files, it reads the file contents. When generating from literals, you provide key-value pairs directly. The generator creates these resources with a hash suffix automatically. This hash suffix is crucial because it ensures that when ConfigMap or Secret content changes, the hash changes, which triggers pod restarts automatically.

For Secret generation, you can specify the type as Opaque or other Kubernetes secret types. The generator works similarly to ConfigMap generation, adding hash suffixes for versioning. This automatic versioning is a significant advantage because pods will restart when configuration changes, ensuring they always use the latest configuration.

JSON patches provide another advanced feature for complex modifications. While strategic merge patches work well for most scenarios, JSON patches give you surgical precision for specific changes. You specify the target resource by kind and name, then provide the patch operations. These operations include add to add new fields, replace to change existing fields, and remove to delete fields. The path uses JSON pointer notation to specify exactly where in the resource to make changes.

## Troubleshooting Advanced Scenarios

When patches aren't being applied, start by checking if the patch is listed in your kustomization file. Preview the output to see if your changes appear. Verify the patch syntax is correct. Common causes include wrong resource names in the patch that don't match the base resource, incorrect paths in the patch file reference, and typos in the kustomization file. Ensure names match exactly between your base deployment and your patch file.

When working with multiple bases or resources, you can include multiple base directories, reference external resources from URLs, and include local files for additional resources. This flexibility allows you to compose complex applications from multiple sources.

When ConfigMap changes aren't triggering pod restarts, the solution is to use ConfigMap generators instead of manual ConfigMap resources. The generator adds a hash suffix, so when values change, a new ConfigMap with a different name is created. This name change updates the pod template, which triggers a rollout with new pods.

Name collisions after applying prefixes or suffixes can be problematic. Always preview exact names that will be created and check existing resources in the namespace. Be careful that namePrefix doesn't create unexpected results, especially if your base resources already have prefixes in their names. Choose prefixes that won't cause collisions.

## Common CKAD Kustomize Patterns

Several patterns appear frequently on the exam. For quick replica changes, when asked to scale the deployment in a production overlay, edit the kustomization file to add or update the replicas field, then apply the changes. This is faster than creating a patch.

For environment variable injection, when you need to add environment variables to a production deployment, create a patch file specifying just the deployment metadata and the environment variable in the container spec, then reference this patch in the kustomization. This keeps the change isolated and clear.

For changing service types, when you need to expose a staging service as NodePort on a specific port, create a service patch that changes just the type and port configuration. Reference this patch in the staging kustomization. This avoids duplicating the entire service definition.

For multiple image tags, when updating multiple images in a single deployment, use the images array in the kustomization with multiple entries. Each entry specifies the image name and new tag. This handles all image updates in one place without needing patches.

## Real-World CKAD Scenario

Let's work through a complete exam question. You have a base application in a specific directory with a Deployment and Service. Create a production overlay that deploys to the production namespace, uses prefix prod-, sets 3 replicas, changes the image from latest to version 1.0.0, adds label tier critical, changes Service type to NodePort on port 30100, applies the configuration, and verifies everything works correctly.

Start by examining the base to understand what resources exist. Check the kustomization, deployment, and service files. Create the production overlay directory, then create the service patch to change the type to NodePort with the specified port. The patch must use the exact service name from the base.

Create the production kustomization that references the base, sets the namespace and prefix, configures replicas, sets the image tag, adds the tier label, and applies the service patch. Preview the output to verify it looks correct before applying.

Create the production namespace if it doesn't exist, then apply the kustomization. Verify by checking all resources in the namespace, examining the deployment for correct replicas and image, checking the service for NodePort configuration, and testing that you can access the service on the NodePort. This complete scenario should take 6 to 8 minutes on the exam.

## Exam Strategy for Kustomize

Follow this strategy for exam questions. Read the question twice to ensure you understand all requirements. Check if a base already exists - don't create a new base if one is provided. Create the overlay directory in the correct location. Start with the kustomization.yaml file to get the structure right first. Use built-in fields like replicas, images, namespace, and namePrefix whenever possible. Only create patches for complex changes like environment variables, resources, or service type modifications. Preview before applying using kubectl kustomize. Don't forget to create the namespace before applying the kustomization. Apply and verify using kubectl apply -k followed by kubectl get. Finally, check that all requirements have been met before moving on.

## Kustomize Cheat Sheet for CKAD

Keep these essential commands in mind. kubectl apply -k applies a kustomization from a directory. kubectl kustomize previews the output without applying. kubectl delete -k deletes all resources. kubectl diff -k shows what would change. For common transformations, namespace sets the namespace for all resources. namePrefix and nameSuffix add prefixes and suffixes to names. commonLabels adds labels to all resources. replicas changes replica counts with an array. images changes image tags with an array. The directory structure typically has base containing kustomization and resource files, and overlays containing environment-specific directories, each with their own kustomization and patches.

## Final Practice Exercise

Test your readiness with this complete exercise without looking at solutions. Create a complete Kustomize setup for a web application. Start by creating a base with a Deployment running nginx version 1.21 with 1 replica, and a Service of type ClusterIP. Create a dev overlay with namespace dev, prefix dev-, 1 replica, and image tag latest. Create a prod overlay with namespace prod, prefix prod-, 5 replicas, image tag 1.21.6, and NodePort on port 30200. Deploy both environments, verify all configurations are correct, and clean up when finished. Set a time limit of 10 minutes.

If you completed this in under 10 minutes with all requirements met, you're ready for the CKAD exam Kustomize questions. Verify that both overlays reference the base correctly using relative paths, replica counts are correct for each environment, image tags are correct, service types are correct, resources deployed to correct namespaces, and all resources have correct prefixes.

## Summary

Kustomize is a powerful, template-free way to manage Kubernetes configurations across environments. For CKAD success, you must know the base and overlay pattern for environment management, creating kustomization.yaml files from scratch, using kubectl apply -k effectively, common transformations including replicas, images, namespace, and namePrefix, strategic merge patches for complex modifications, and debugging kustomization output before applying.

For exam tips, always preview with kubectl kustomize before applying to catch errors early. Use relative paths in resources for portability. Prefer built-in transformations over patches when possible. Verify all requirements are met before moving on to the next question. Practice until you can complete exercises in under 10 minutes consistently.

With solid practice on the exercises we've covered, you'll be well-prepared for any Kustomize question on the CKAD exam. Practice these scenarios multiple times until they become muscle memory. Set yourself time-based challenges to build speed. Remember that kubectl explain is available during the exam for looking up field definitions. Master these concepts, and you'll confidently handle the Kustomize portion of the CKAD exam.
