# Troubleshooting Advanced Kubernetes Components - Exercises Narration Script

**Duration:** 25-30 minutes
**Format:** Screen recording with live demonstration
**Note:** Advanced content beyond core CKAD requirements
**Prerequisite:** Ingress controller installed, Helm available

---

Welcome to advanced Kubernetes troubleshooting. This lab focuses on troubleshooting a broken Helm chart that deploys a complex application with Ingress routing and a StatefulSet database. This represents real-world complexity that goes beyond the core CKAD exam requirements, but the troubleshooting skills you'll practice here are valuable for understanding how enterprise applications work in Kubernetes.

This lab is marked as beyond CKAD because Helm chart creation and advanced Ingress patterns aren't core exam topics. However, basic Ingress and StatefulSet concepts are relevant, and the systematic troubleshooting approach applies to everything. If you're preparing specifically for CKAD, focus on the basic troubleshooting and troubleshooting-2 labs first, then come back to this material.

Today we're working with a Helm chart that's deliberately broken in multiple ways. The chart deploys a web frontend accessible through Ingress and a PostgreSQL database using a StatefulSet. Your goal is to fix the Helm deployment so it installs successfully and the application is accessible at whoami.local:8000.

## Lab

Before we can deploy the broken application, we need an Ingress controller. Ingress resources don't do anything by themselves - they need an Ingress controller running in the cluster to implement the routing rules. Let me deploy the Ingress controller from the ingress lab specs.

The Ingress controller creates several pods and services in a dedicated namespace. It's watching for Ingress resources across the cluster and configuring itself to route traffic according to those Ingress rules. We'll need this running before our application Ingress can work.

Now let's attempt to install the broken Helm chart. I'm using helm upgrade with the install flag, pointing to the chart directory in troubleshooting-3/specs/app-chart. The create-namespace flag will create the namespace if it doesn't exist. Watch what happens when I run this.

The installation fails with errors. This is common with Helm charts - template errors prevent the chart from even being installed. Helm templates are Go templates that generate Kubernetes YAML. If the template syntax is wrong or references undefined values, the installation fails immediately. Read the error message carefully - it usually tells you exactly which template has a problem and what's wrong with it.

Let me use helm template to render the templates without actually installing them. This dry-run mode shows you what YAML would be generated. It's incredibly useful for debugging template errors because you can see the rendered output and spot problems. If the template command fails, the error message points to the specific template file and line number where the issue is.

Common Helm template issues include missing closing braces in variable references, undefined values being referenced, invalid YAML indentation in the templates, and missing required fields in the generated resources. Let me check the chart structure to see what templates exist and examine them for syntax errors.

When I find template errors, I fix them in the template files. This might mean adding default values, fixing brace syntax, correcting indentation, or adjusting how values are referenced. After fixing template errors, I try the install again.

Once the Helm chart installs successfully, that doesn't mean the application works. Helm just creates the Kubernetes resources - those resources still need to be configured correctly. Now we move into troubleshooting the actual deployed resources, which is the same systematic approach we've been practicing.

Let me check what resources were created. I can see pods, services, an Ingress, and likely a StatefulSet. The pod status tells me immediately if we have problems. Are pods running? Are they ready? Any crashes or errors?

For Ingress troubleshooting, start by checking if the Ingress resource exists and is configured correctly. When I describe the Ingress, I look at the host rules, the service backends, and the port numbers. The Ingress needs to route traffic to a service that actually exists. The service name in the Ingress must match a real service name exactly.

Common Ingress issues include service name mismatches where the Ingress references a service that doesn't exist or has a slightly different name, wrong port numbers where the Ingress routes to a port the service doesn't expose, missing host configuration where requests don't match any host rule, and missing Ingress controller where no controller is watching for Ingress resources.

Let me test Ingress routing. I can use curl with a Host header to simulate a request to the Ingress host. If that doesn't work, I check each layer - does the service exist? Does it have endpoints? Are the pods actually running? Is the Ingress controller healthy?

StatefulSets add another dimension of complexity. StatefulSets are for applications that need stable identities and persistent storage. Each pod gets a consistent name and its own PersistentVolumeClaim. When I check the StatefulSet status, I look at how many replicas are ready versus desired. If they're not all ready, I need to investigate why.

Common StatefulSet issues include PVCs not binding because no matching PVs are available, missing headless service which StatefulSets require for stable network identities, pods stuck in pending or init state preventing the ordered startup, and ordered startup blocking where StatefulSets start pods sequentially and a problem with one pod blocks all subsequent pods.

For PVC issues with StatefulSets, remember that StatefulSets use volumeClaimTemplates to automatically create PVCs for each pod. If these PVCs can't bind, the pods stay pending. I need to check what the volumeClaimTemplates request and ensure matching PVs exist.

Let me work through the systematic fix process. First, I fix any Helm template syntax errors so the chart actually installs. Second, I check if all expected resources were created. Third, I verify pod status and investigate any that aren't running. Fourth, I check if the Ingress routes to the correct service. Fifth, I ensure StatefulSet PVCs can bind to PVs. Sixth, I verify services have endpoints and selectors match.

After each fix, I watch what happens. Kubernetes reconciles the changes, which might take a moment. Pods might restart. PVCs might bind. Services might populate endpoints. I verify each fix worked before moving to the next issue.

When debugging Helm deployments specifically, the helm status command shows the overall status of the release. Helm get manifest shows all the Kubernetes resources that were created. Helm get values shows what values were used during installation. These commands help you understand what Helm actually did.

If I need to make changes and reinstall, I can use helm upgrade again. Helm tracks the release history and can apply changes incrementally. If I need to completely start over, helm uninstall removes everything and I can install fresh.

The final verification is accessing the application through the Ingress. I need to make sure my request includes the correct Host header matching the Ingress rule. When using curl, I specify the Host header explicitly. When using a browser, I might need to configure local DNS or edit my hosts file to resolve the hostname.

When everything works, the pods should all be running and ready, the StatefulSet should have all replicas ready, PVCs should be bound to PVs, services should have endpoints, the Ingress should route traffic to the backend service, and the application should respond at the configured hostname.

This type of advanced troubleshooting combines everything we've learned - understanding resource dependencies, reading error messages carefully, checking configurations systematically, and verifying fixes at each layer. The complexity comes from having more moving parts, but the approach remains the same.

## Cleanup

When you're finished, clean up the Helm release and associated resources. Helm uninstall removes the release, but StatefulSet PVCs persist by design to prevent data loss. You need to explicitly delete them if you want a complete cleanup. Then delete the namespace to remove anything else.

That completes our advanced troubleshooting exercise. You've practiced debugging Helm templates, troubleshooting Ingress routing, and fixing StatefulSet storage issues. While this material goes beyond core CKAD requirements, the systematic troubleshooting approach applies to all Kubernetes resources. The skills you've developed here - reading error messages, checking dependencies, verifying configurations, and testing systematically - are essential for working with any Kubernetes deployment, whether simple or complex.
