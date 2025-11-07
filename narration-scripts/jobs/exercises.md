# Running One-off Pods with Jobs and Recurring Pods with CronJobs

Welcome to our exploration of Jobs and CronJobs in Kubernetes. Sometimes you need a Pod to execute specific work and then stop, rather than running continuously. Deployments aren't appropriate for this because they'll replace a Pod when it exits, even if it completed successfully. This is where Jobs come in. They're a Pod controller designed specifically for work that needs to run to completion.

Jobs create a Pod and ensure it runs until the work finishes. If the Pod fails, the Job will start a replacement, but once the Pod succeeds, the Job is done. For recurring tasks, CronJobs act as a controller for Jobs themselves, creating new Jobs on a schedule. Think of it as Jobs for one-off tasks and CronJobs for scheduled recurring tasks.

## API specs

Let's look at the structure of a Job specification. Jobs are part of the batch API group, so they use the batch/v1 API version. The simplest Job spec contains metadata with a name and a template section with a standard Pod spec. One crucial requirement is the restart policy, which must be explicitly set to either Never or OnFailure. The default Pod restart policy of Always isn't allowed for Jobs.

The template spec is just like a regular Pod specification, supporting volumes, configuration, and all the standard Pod features. The key difference is that restart policy constraint. When you set it to Never, failed Pods won't be restarted, and the Job will create new Pods instead. With OnFailure, the container restarts within the same Pod.

CronJobs wrap the Job specification and add scheduling capabilities. They use a schedule field with a standard Unix cron expression to define when Jobs should be created. The concurrencyPolicy field controls what happens if a new Job is scheduled while the previous one is still running. You can Allow multiple Jobs to run concurrently, Forbid new Jobs while one is running, or Replace the old Job with the new one.

## Run a one-off task in a Job

For our first demonstration, we'll use the Pi calculation application. This app normally runs as a web service, but it can also perform one-off calculations, making it perfect for demonstrating Jobs. The Job spec uses the same Pi image but with a different command to run a single calculation.

When we create the Job, Kubernetes accepts it and starts working to fulfill it. Checking the status shows the Job with its completion count. Jobs automatically apply a label to the Pods they create, in addition to any labels defined in the template Pod spec. This label is called job-name and its value matches the Job's name.

We can use this label to find the Pods created by our Job and view their logs. The output shows Pi calculated to the specified number of decimal places. That's the entire output from this Pod - it did its work and exited. An important characteristic of Jobs is that they don't automatically clean up when complete. The Job remains in the cluster showing its completion status, and the Pods remain as well. This allows you to examine logs and debug issues even after the work is done.

Jobs don't manage Pod updates the way Deployments do. You can't update the Pod spec for an existing Job. If you try to apply a modified Job spec that changes the Pod template, you'll get an error saying the field is immutable. To change a Job, you would need to delete the old one first and then create a new one with your modifications.

## Run a Job with multiple concurrent tasks

Jobs aren't limited to running a single Pod. Sometimes you have a fixed amount of work to process and you want to run multiple Pods in parallel to complete it faster. The completions field specifies how many Pods need to successfully complete, and the parallelism field controls how many run concurrently.

When we create a Job configured to run three Pods concurrently, each calculating Pi to a random number of decimal places, we can watch it create all three Pods. The Job status shows the expected completions and tracks progress as Pods finish. Checking the Pod status shows all three Pods with the job-name label.

Viewing logs from all Pods associated with the Job gives us output from each one - in this case, pages and pages of Pi computed to different precisions. The Job's describe output provides detailed information about all the Pods it created, including Pod creation events and their final statuses. This gives you a complete view of the batch processing operation.

## Schedule tasks with CronJobs

Since Jobs don't automatically clean up, periodically running a cleanup task is a perfect scenario for CronJobs. We can create a CronJob that runs a shell script to delete old Jobs. The implementation uses kubectl inside a Pod, which requires appropriate RBAC permissions.

The CronJob spec includes the script in a ConfigMap so we don't need to build a custom container image. A ServiceAccount with RBAC rules grants the Pod permission to query and delete Jobs. The CronJob is configured to run every minute, so we'll quickly see it in action.

After deploying the CronJob, we can watch all Jobs to see them being managed. The cleanup Job appears automatically when the schedule triggers, and then we see our previous Pi Jobs disappearing from the list. The CronJob creates new Jobs according to its schedule, and these Jobs execute the cleanup logic.

The cleanup script's logs show exactly what it did - which Jobs it found and removed. The most recent cleanup Job remains in the cluster because CronJobs themselves don't delete the Jobs they create. Instead, they use history limits to control how many old Jobs are retained.

## Lab

Real CronJobs typically run much less frequently than every minute. They're used for maintenance tasks that run hourly, daily, weekly, or even monthly. Often you need to run a one-off Job from a CronJob's specification without waiting for the next scheduled execution.

The first lab task involves editing the cleanup CronJob to suspend it, preventing any new Jobs from being created. This should be done without using kubectl apply. One approach is using kubectl patch to set the suspend field to true. This command changes the CronJob's configuration directly without needing to apply a complete YAML file.

After suspending the cleanup CronJob, we deploy a new backup CronJob from the provided spec. This CronJob is scheduled to run at a specific time, like daily at 3 AM. Waiting that long to test it isn't practical, so the next task is to manually trigger a Job from this CronJob's specification.

The kubectl create job command has a from flag that accepts a CronJob as the source. This copies the CronJob's jobTemplate and creates an immediate Job from it. The Job name can be anything you choose, but it must be unique. This manually created Job is identical to what would run on schedule, just triggered immediately for testing purposes.

Checking the Job's status and logs confirms it ran successfully. This technique is invaluable for testing CronJobs without modifying their schedules or waiting for the next scheduled run. It's a common requirement in production environments and frequently appears in exam scenarios.

## **EXTRA** Manage failures in Jobs

Background tasks in Jobs could run for extended periods, and you need control over how failures are handled. The restart policy provides the first level of control. Setting it to OnFailure allows Pod restarts, so if the container fails, a new container starts in the same Pod.

We can demonstrate this with a Job that has a deliberate mistake in the container command. With the OnFailure restart policy, when the container fails, the Pod will restart it. Watching the Pods shows the container exiting with errors and restarting multiple times. Eventually, you'll see the restart count climbing and the Pod entering CrashLoopBackoff status.

An alternative approach is setting the restart policy to Never, which means the Pod won't restart when the container fails. Instead, the Job creates replacement Pods. The backoffLimit field controls how many times the Job will retry by creating new Pods. Setting it to 4 means the Job will try up to four times total.

After deleting the old Job and creating the new one with this configuration, watching the Pods shows a different pattern. Instead of one Pod restarting repeatedly, you see multiple Pods being created, each with zero restarts. Eventually you'll see four Pods total, all showing ContainerCannotRun status.

A consequence of Pods reaching ContainerCannotRun status is that logs may not be available since the container never successfully started. To find the error, you need to describe the Pods. The describe output shows the failure reason in the events section. In this case, it's just a typo in the command line, but this debugging process applies to any Job failure scenario.

## Cleanup

Cleaning up the resources we created uses a label-based deletion command. The kubernetes.courselabs.co label is applied to all resources in the lab, so we can delete Jobs, CronJobs, ConfigMaps, ServiceAccounts, ClusterRoles, and ClusterRoleBindings all at once with a single command. This efficient cleanup approach is a best practice for managing resources in Kubernetes.
