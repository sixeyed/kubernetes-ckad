# Admission - Exercises Narration Script

**Duration:** 25-30 minutes
**Format:** Screen recording with live demonstration

---

Welcome back! In the previous video, we covered the concepts behind admission control in Kubernetes. This is an advanced topic where you can enforce custom rules before workloads run in the cluster. Today we'll deploy custom admission webhooks and then use OPA Gatekeeper for policy enforcement.

## Reference

Before we dive into the hands-on work, let me point you to the key resources for this lab. The Kubernetes documentation covers using admission controllers in detail, and you'll find information about creating self-signed SSL certificates for webhook servers in the cert-manager docs. We'll be working with OPA Gatekeeper, which has excellent documentation including a policy library with ready-to-use constraint templates.

## In-cluster webhook servers over HTTPS

Let's start by deploying cert-manager to handle TLS certificates for our webhooks. Admission webhooks require HTTPS with trusted certificates, and cert-manager automates certificate generation. This is a complex component, but it's definitely better than managing certificates yourself. We're deploying from the cert-manager docs, which includes all the custom resources, RBAC, Services and Deployments needed to run the manager.

Now we'll create a self-signed issuer. This is a custom resource that tells cert-manager how to generate certificates. You can configure this to use a real certificate provider like Let's Encrypt, but we're using a self-signed issuer for this lab. Even though it's a custom resource, the spec doesn't need any special configuration - we just apply it like any other YAML.

Let's deploy the webhook server. It's a Node.js application built to match the webhook API spec. There's no special RBAC or permissions needed - this is just a standalone web server. It does run under HTTPS though, expecting to find the TLS certificate in a Secret. The certificate resource we're deploying will create that certificate using the self-signed issuer and store it in the Secret the Pod expects to use. Cert-manager will take care of creating and rotating this certificate.

Watch how the certificate Secret gets created automatically. The certificate object shows it's ready, and the Secret contains the TLS certificate and key, plus the CA certificate for the issuer. This is just a standard web server, so we can test the HTTPS setup by running a sleep Pod and using curl to connect. You'll see a security error - that's expected because curl doesn't trust our self-signed issuer. The error actually confirms that the certificate has been applied correctly.

## Validating Webhooks

The admission controller is running, but it's not doing anything yet. We need to configure it as a webhook for the Kubernetes API server to call. This spec configures Kubernetes to call the webhook on the validate path when Pods are created or updated. The annotation here tells cert-manager to configure our self-signed certificate as trusted.

This is a validating webhook, which means the logic in the server will block any Pods from being created where the spec does not set the automountServiceAccountToken field to false. When we apply the validating webhook configuration and check the details, we'll see that cert-manager has applied the CA certificate from the certificate it generated.

Now the webhook is running, so Kubernetes won't run any Pods that don't meet the rules. Let's test this by deploying the whoami application. The Deployment gets created, but if we check the objects, we'll see that no Pods are running. When we describe the Deployment, we see the ReplicaSet has been created and scaled up, so there are no errors at the Deployment level.

The key is to check the ReplicaSet. Here you'll see the message from the admission controller saying that automountServiceAccountToken must be set to false. The webhook blocked Pod creation. This app won't fix itself - the ReplicaSet will keep trying to create Pods and they'll keep getting rejected by the admission controller.

To get it running, we need to change the Pod spec by applying a new spec which meets the validation rules. Now the Pods get created successfully. Validating webhooks are a powerful way of ensuring your apps meet your policies - any objects can be targeted and the whole spec is sent to the webhook, so you can use this for security, performance or reliability rules.

## Mutating Webhooks

Validating webhooks either allow an object to be created or they block it. The other type of admission control is to silently edit the incoming object spec using a mutating webhook. Our webhook server has mutation logic too, so let's deploy the mutating webhook configuration. This operates when Pods are created or updated, calling the mutate endpoint on the server.

The interesting thing about mutating webhooks is there's no information about what this policy actually does. Let's try running another app to see what happens. We're deploying the Pi website application, but this app won't run either. When we check the Pods, we'll see the status is CreateContainerConfigError. The Pod details show an error message in the events saying container has runAsNonRoot and image will run as root.

Here's the twist - the Pod spec in the Deployment doesn't say anything about non-root users. That security context has been applied by the mutating webhook. The webhook silently modified our specification to enforce non-root execution. We can get the app running by applying an updated spec that uses a non-root variant of the image, and now it runs successfully. This demonstrates how mutating webhooks can silently change your specifications, which can be helpful for enforcing defaults but also confusing when troubleshooting.

## OPA Gatekeeper

Custom webhooks have two significant drawbacks. First, you need to write the code yourself, which adds to your maintenance estate. Second, their rules are not discoverable through the cluster, so you'll need external documentation to know what policies are in place.

OPA Gatekeeper is an alternative which implements admission control using generic rule descriptions in a language called Rego. We'll deploy admission rules with Gatekeeper, but first we need to clean up by deleting all of the custom webhooks - both ours and cert-manager's. Gatekeeper is another complex component where you trade the overhead of managing it with the issues of running your own controllers. We're deploying custom resources to describe admission rules, RBAC for the controller, and a Service and Deployment to run it.

Let's check what custom resource types Gatekeeper installed. You'll see several CRDs, but the main one we work with is the ConstraintTemplate. There are two parts to applying rules with Gatekeeper. First, you create a ConstraintTemplate which defines a generic constraint - for example, containers in a given namespace can only use a given image registry. Second, you create a Constraint from the template - for example, containers in namespace apod can only use images from courselabs repos on Docker Hub.

The rule definition is done with the Rego generic policy language. We're creating two templates - one to require labels on objects, and another more complex template requiring container objects to have resources set. When we check the custom resources again after creating the templates, we'll see something interesting. Gatekeeper has created a CRD for each constraint template, so each constraint becomes a Kubernetes resource. This is how Gatekeeper stores constraints in a discoverable way.

Now let's deploy the constraints which use the templates. One requires app and version labels on Pods, and a kubernetes.courselabs.co label on namespaces. The other requires resources to be specified for any Pods in the apod namespace. When we print the details of the required labels namespace constraint, we'll see all the existing violations of the rule, and it should be clear what's required - the label on each namespace.

## Lab

Now we have OPA Gatekeeper in place, let's see how it works in practice. Try deploying the APOD app from the specs for this lab. It will fail because the resources don't meet the constraints we have in place. Your job is to fix up the specs and get the app running without making any changes to policies.

Think about what the constraints require. The namespace needs the kubernetes.courselabs.co label. Pods need app and version labels. And Pods in the apod namespace need resource limits specified. You'll need to edit the namespace and deployment YAML files to add the required labels and resource limits, then reapply them. Check the constraint descriptions to see exactly what's needed - Gatekeeper makes this discoverable.

## Cleanup

Time for cleanup. We need to remove all the lab's namespaces and delete the Gatekeeper CRDs. This cleans up all the custom resources and webhooks we've created during the lab.

We've seen how validating webhooks enforce policies by accepting or rejecting resources, how mutating webhooks modify resources before they're created, and how Gatekeeper provides declarative policy management with discoverable rules. The key takeaway is to always check ReplicaSet events when Deployments don't create Pods - that's where admission errors appear, not on the Deployment itself.
