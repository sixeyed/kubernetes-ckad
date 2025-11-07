# Updates with Staged Rollouts

Welcome to the hands-on portion where we explore deployment strategies with Kubernetes. We've already covered the concepts, so now it's time to see how rolling updates, recreate strategies, and advanced deployment patterns work in practice.

Pod controllers manage Pods for you, and when you update the Pod spec the controller rolls out the change by removing old Pods and creating new ones. You'll do this all the time because every OS patch, library update and new feature will be an update. Depending on your app, config changes might need a rollout too. You can configure the controller to tweak how the rollout happens, so you might choose a slow but safe update for a critical component. Deployment objects are the typical Pod controller, but all the controllers have rollout options.

## Fast staged rollouts

Let's start with a simple web application. We'll open a watch window so you can see Pods come online in real time. The deployment spec defines a Deployment with three replicas of the v1 application image, and there's also an init container set to sleep so it takes a few seconds for Pods to start.

When we deploy the app from the vweb folder, you'll see the Pods start appearing in the watch window. Initially no pods exist, then three pods are created with names like vweb followed by a hash and a random string. The init containers run first, and you'll see them in the status. Then the Pods transition to Running state, and eventually all three pods become Ready showing one out of one.

After we check the Services, we can make an HTTP request to the version endpoint. The output from the app is just the text v1, which confirms our initial version is running.

Now we'll apply a fast rollout to v2. The update deployment spec sets maxSurge to one hundred percent, which means Kubernetes will create three new Pods straight away. MaxUnavailable is set to zero so no old Pods will be removed until new ones come online. When we deploy this update, watch what happens in the watch window. Three new pods are created immediately because we have a new ReplicaSet created with the v2 spec and desired count of three. The three existing Pods remain until new Pods are ready, then they're terminated. The v1 ReplicaSet is gradually scaled down to zero.

You can see the update happening in the ReplicaSets if you list them by the app label. We can try the app while the rollout is happening and you'll get responses from both v1 and v2. All the v1 and v2 Pods match the Service selector so you'll get load-balanced responses from both versions. This means staged rollouts require the app to support multiple versions running concurrently, and a fast rollout like this needs spare capacity in the cluster.

## Slow staged rollouts

Rollouts aren't a separate Kubernetes object, but you can manage the rollouts for a Pod controller with kubectl. When we check the rollouts for the Deployment with rollout history, we can see our revisions. The rollout command has several subcommands available, and we can use undo to roll back to the previous Pod spec without applying any YAML.

The rollback uses the new custom rollout strategy we configured earlier, so three v1 Pods come online and v2 Pods are replaced when v1 Pods are running. If we describe the Deployment, we'll see that the rolling update strategy hasn't changed. A rollback reverts to the previous Pod spec, not to the previous spec of the Deployment itself.

Now we're back at v1, we can see what happens with a slower rollout strategy. The slow update deployment spec updates the image to v2, still with maxUnavailable of zero so no Pods get replaced until new ones are ready. But now maxSurge is set to one so only one new Pod is created at a time.

When we apply the new update, this rollout updates one Pod at a time. A v2 Pod is created, and a v1 Pod is removed when the v2 Pod comes online. This is a much slower rollout because Pods are replaced consecutively. Both app versions are running while the rollout happens, but for a much longer period compared to the fast rollout we saw earlier.

## Big-bang rollouts

Not all apps support running different versions during a rollout. In that case you can configure a big-bang update where all Pods are replaced immediately instead of using a staged rollout. The broken update deployment spec uses the Recreate update strategy and removes the init container so there's no delay in the rollout.

With this strategy the existing ReplicaSet will be scaled down to zero and then a new ReplicaSet will be created with a desired scale of three. This is not good if there's a problem with the new release, which there is with this app. When we deploy the update and check on the Pod status in the watch window, all the existing Pods are terminated and then new ones are created. There's a problem with those Pods because the image is broken due to a bad startup command, which you'll see in the Pod logs. The new Pods will never enter the running state and they'll go into CrashLoopBackOff after a while. With zero Pods ready, there are no endpoints in the Service and the app is unavailable.

Be careful using the Recreate strategy because a bad update will take your application offline. When we try to curl the application, we get connection errors. There is no automatic rollback in Kubernetes, so updates need to be monitored and failed releases manually rolled back.

When we check the history and roll back to the previous version, all the failing Pods are terminated and then the new Pods are started. They use the previous Pod spec so the app doesn't come online until the init containers have run. The rollback doesn't change the update strategy, so the Deployment is still set to use Recreate.

## Blue/Green Deployments

Blue-green deployments minimize risk by running two complete environments side-by-side. Only one version, the blue environment for example, serves production traffic while the other, the green environment, is idle or being prepared. To deploy, you switch traffic from blue to green instantly.

The way blue-green works is straightforward. You deploy the green version alongside the existing blue version, then test the green version thoroughly without affecting users. When you're ready, you switch traffic from blue to green by updating the Service selector. You keep blue running as a rollback option, and eventually decommission blue once green is stable.

Let's implement a blue-green deployment manually. When we create the blue version from the blue-green specs folder, we can check what was created. We'll see deployments and services with the blue-green strategy label, along with pods for the blue-green app. When we check which version is currently live by accessing the service, we'll see the service selector is set to version blue so we get responses from the blue deployment.

Now we deploy the green version without affecting users. When we deploy green and verify both versions are running, we can see both blue and green Pods are running, but traffic still goes to blue because the Service selector hasn't changed. We can test the green version directly using Pod port-forwarding. We get a green pod name and forward a port to test green directly, confirming that green works before we switch production traffic.

To switch production traffic to green, we patch the service to point to green instead of blue. When we patch the service and verify the switch, now all traffic goes to green. The blue deployment is still running as a rollback option. To rollback, we simply switch the selector back to blue and verify that traffic returns to blue immediately.

Blue-green gives you instant switchover by just updating the Service selector, easy rollback by switching back immediately, and full testing in the production environment before going live. The drawbacks are that it requires double the resources since both versions are running, database migrations can be complex, and it's not suitable for stateful applications without careful planning.

## Canary Deployments

Canary deployments reduce risk by rolling out changes to a small subset of users first. If the canary version works well, you gradually increase traffic to it. If issues arise, only a small percentage of users are affected.

The way canary deployments work is that you deploy a canary with a small percentage of pods, perhaps one out of five which equals twenty percent. You monitor metrics for errors and performance issues, then gradually increase canary pods while decreasing stable pods. You complete the rollout when canary becomes one hundred percent, and you can rollback easily by scaling canary to zero if issues are found.

Let's implement a canary deployment using two Deployments with the same labels. We deploy the stable version with four replicas first, check it's running, and apply the service. When we test the stable version, all requests should show v1.

Now we deploy the canary with just one replica, which gives us twenty percent of traffic. When we check both deployments, we have a total of five pods. We can test the application multiple times to see what percentage shows v2. When we make multiple requests and count them, we should see approximately eighty percent v1 from stable and twenty percent v2 from canary responses, because traffic is load-balanced across all five pods with four stable plus one canary.

If the canary is healthy, we increase its percentage. We can increase canary to fifty percent by scaling to three canary and three stable pods. We test the distribution again to verify it's roughly fifty-fifty. To complete the rollout to one hundred percent canary, we scale canary up and stable down until canary has all four pods and stable has zero. Now we can verify all traffic goes to v2, and we could delete the stable deployment since it's scaled to zero and no longer needed.

If issues are detected during canary testing, an immediate rollback is simple. We just scale canary to zero and scale stable back up if needed. Then we verify all traffic is back to v1. Canary deployments offer minimal user impact since only a small percentage is exposed to issues, gradual rollout allows monitoring at each stage, and it's easy to rollback by scaling down canary. The drawbacks are that it's more complex than rolling updates, it requires good monitoring and metrics to detect issues, and load balancing must be traffic-based since it won't always give equal distribution.

## Lab

An alternative update strategy is a blue-green deployment where you have two versions of your app running but only one receives traffic. It's simple to do that with two Deployments and one Service. You change the label selector on the Service to switch between the blue and green releases.

This lab uses Helm for a blue-green update. We start by deploying the Helm chart for the simple web app. When we browse to the app and refresh, we see it flickers between the blue and green releases. The goal is to fix that so you can switch releases with a simple Helm upgrade command setting the active slot to green or blue.

To make that work you'll need to fix the chart templates. The problem is that both blue and green releases are receiving traffic simultaneously. Your goals are to fix the chart so only one version receives traffic at a time, enable switching releases with the Helm upgrade command and activeSlot value, and implement automatic rollback so that if updating blue to a broken v3 image, it rolls back after thirty seconds if unsuccessful.

Check the Service template selector and look at deployment templates and labels. Use Helm values to control the active slot and research the helm upgrade wait and timeout flags for automatic rollback. The key fixes needed include making the Service selector use the slot value from activeSlot, ensuring deployments have proper slot labels, and using helm upgrade atomic with a timeout for automatic rollback.

## Cleanup

Remove the Helm chart from the lab when you're finished. And remove all the other resources from the exercises by deleting daemonsets, statefulsets, deployments, and services with the kubernetes.courselabs.co equals rollouts label.

## EXTRA Rollouts for other Pod controllers

DaemonSets and StatefulSets also use staged rollouts, but they have different configuration options. We'll use a new app for this demonstration. DaemonSets are upgraded one node at a time, so by default Pods are taken down and replaced individually.

When we create the DaemonSet with default update settings, the v1.20 update bumps the image version and switches the update strategy to OnDelete. When we apply this update, nothing happens immediately. The original Pod is not replaced. The update strategy means Pods won't be replaced until they're explicitly deleted. When we delete the pods with the app label, the old Pod terminates and then the new one is created. The OnDelete strategy lets you control when Pods are replaced but still have the replacement rolled out automatically.

StatefulSets have another variation on update strategies. By default the Pods are replaced consecutively starting from the last Pod in the set and working backwards to the first. When we remove the DaemonSet and create the StatefulSet, if the watch is still running we'll see the old Pod removed and three new Pods created. This is a StatefulSet so the Pods have predictable names like nginx-0, nginx-1 and nginx-2.

The v1.20 update uses a partitioned update. When we deploy the update, only certain Pods get updated. The partitioned update stops the rollout at the specified Pod index, so only Pod 2 gets replaced. To continue the rollout you would need to update the partition in the YAML spec and deploy the change, or update the object directly with a patch to change the partition value. This gives you fine-grained control over which StatefulSet Pods get updated and when.
