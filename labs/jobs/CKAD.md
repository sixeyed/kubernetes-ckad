# Jobs and CronJobs for CKAD

This document extends the [basic jobs lab](README.md) with CKAD exam-specific scenarios and requirements.

## CKAD Exam Context

Jobs and CronJobs are important CKAD topics. You'll need to:
- Create Jobs and CronJobs imperatively and declaratively
- Understand completion, parallelism, and restart policies
- Handle job failures with backoff limits
- Work with CronJob schedules and concurrency
- Trigger one-off Jobs from CronJobs
- Debug failed Jobs and view logs

**Exam Tip:** Jobs are immutable once created (you can't change the Pod template). Always delete and recreate rather than trying to edit.

## API specs

- [Job (batch/v1)](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.20/#job-v1-batch)
- [CronJob (batch/v1)](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.20/#cronjob-v1-batch) - Note: Graduated to stable in v1.21+
- [PodTemplate spec](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.20/#podtemplatespec-v1-core)

## Imperative Job Creation

Speed is critical in CKAD, so master imperative commands:

```
# Create a Job that runs a command once
kubectl create job hello --image=busybox -- echo "Hello World"

# Create a Job from a CronJob (trigger immediately)
kubectl create job manual-run --from=cronjob/my-cronjob

# Generate Job YAML without creating
kubectl create job test-job --image=nginx --dry-run=client -o yaml > job.yaml

# View Job status
kubectl get jobs
kubectl describe job hello

# View Pods created by Job
kubectl get pods --show-labels
kubectl get pods -l job-name=hello

# View Job logs
kubectl logs -l job-name=hello
kubectl logs job/hello  # shorthand

# Delete Job (also deletes its Pods)
kubectl delete job hello
```

📋 Create a Job called `date-job` that runs the `date` command using the `busybox` image, check its completion, view logs, then delete it.

<details>
  <summary>Solution</summary>

```
kubectl create job date-job --image=busybox -- date
kubectl get jobs
kubectl wait --for=condition=complete job/date-job --timeout=60s
kubectl logs job/date-job
kubectl delete job date-job
```

</details><br />

## Job Restart Policies

Jobs require a restart policy of `Never` or `OnFailure` - the default `Always` is not valid.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pi-job
spec:
  template:
    spec:
      containers:
      - name: pi
        image: perl:5.34
        command: ["perl", "-Mbignum=bpi", "-wle", "print bpi(100)"]
      restartPolicy: Never  # or OnFailure
```

**Key Differences:**

| Restart Policy | Behavior | Use Case |
|---------------|----------|----------|
| `Never` | Failed Pod is not restarted; Job creates new Pod | When failures need fresh Pod (network/node issues) |
| `OnFailure` | Container restarts in same Pod | Quick container failures, save Pod creation overhead |

📋 Create a Job with restart policy `OnFailure` that runs `exit 1` (will fail), watch the Pod restart multiple times.

<details>
  <summary>Solution</summary>

```
cat << EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: failing-job
spec:
  backoffLimit: 4
  template:
    spec:
      containers:
      - name: fail
        image: busybox
        command: ["sh", "-c", "echo Attempt failed; exit 1"]
      restartPolicy: OnFailure
EOF

# Watch the Pod restart (RESTARTS column increments)
kubectl get pods -l job-name=failing-job --watch

# After 4 failures, the Job stops trying
kubectl describe job failing-job
```

</details><br />

## Job Completions and Parallelism

Jobs can run multiple Pods to completion, either sequentially or in parallel:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: parallel-job
spec:
  completions: 5      # Total successful Pods required
  parallelism: 2      # Max Pods running concurrently
  template:
    spec:
      containers:
      - name: worker
        image: busybox
        command: ["sh", "-c", "echo Processing work; sleep 10; echo Done"]
      restartPolicy: Never
```

**Key Fields:**

- **`completions`**: How many Pods must successfully complete (default: 1)
- **`parallelism`**: How many Pods run simultaneously (default: 1)
- **`backoffLimit`**: Max retry attempts for failed Pods (default: 6)

### CKAD Scenario: Parallel Processing

Create a Job that processes 10 items with 3 workers in parallel:

```
cat << EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: process-items
spec:
  completions: 10
  parallelism: 3
  template:
    spec:
      containers:
      - name: processor
        image: busybox
        command: ["sh", "-c", "echo Processing item \$HOSTNAME; sleep 5"]
      restartPolicy: Never
EOF

# Watch Pods being created and completed
kubectl get pods -l job-name=process-items --watch

# Check Job progress
kubectl get job process-items
```

📋 Create a Job that completes 8 tasks with 4 running in parallel, and sets a backoff limit of 3.

<details>
  <summary>Solution</summary>

```
cat << EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: batch-job
spec:
  completions: 8
  parallelism: 4
  backoffLimit: 3
  template:
    spec:
      containers:
      - name: worker
        image: busybox
        command: ["sh", "-c", "echo Work completed; sleep 2"]
      restartPolicy: Never
EOF

kubectl get job batch-job --watch
```

</details><br />

## Imperative CronJob Creation

```
# Create a CronJob that runs every minute
kubectl create cronjob hello --image=busybox --schedule="*/1 * * * *" \
  -- echo "Hello from CronJob"

# Create CronJob that runs daily at 2am
kubectl create cronjob backup --image=backup-image --schedule="0 2 * * *" \
  -- /backup.sh

# Generate CronJob YAML
kubectl create cronjob test --image=nginx --schedule="0 */6 * * *" \
  --dry-run=client -o yaml > cronjob.yaml

# View CronJobs
kubectl get cronjobs
kubectl get cj  # shorthand

# View Jobs created by CronJob
kubectl get jobs --watch

# Create Job from CronJob (trigger now)
kubectl create job manual-backup --from=cronjob/backup

# Suspend a CronJob (stops creating new Jobs)
kubectl patch cronjob hello -p '{"spec":{"suspend":true}}'

# Resume a CronJob
kubectl patch cronjob hello -p '{"spec":{"suspend":false}}'

# Delete CronJob (doesn't delete existing Jobs)
kubectl delete cronjob hello
```

## Cron Schedule Expressions

CronJobs use standard cron syntax: `minute hour day-of-month month day-of-week`

```
┌───────────── minute (0 - 59)
│ ┌───────────── hour (0 - 23)
│ │ ┌───────────── day of month (1 - 31)
│ │ │ ┌───────────── month (1 - 12)
│ │ │ │ ┌───────────── day of week (0 - 6) (Sunday to Saturday)
│ │ │ │ │
* * * * *
```

### Common CKAD Schedule Patterns

```
*/5 * * * *      # Every 5 minutes
0 * * * *        # Every hour (on the hour)
0 */6 * * *      # Every 6 hours
0 9 * * *        # Daily at 9am
0 9 * * 1        # Every Monday at 9am
0 0 1 * *        # First day of every month at midnight
30 3 * * 0       # Every Sunday at 3:30am
0 2 * * 1-5      # Weekdays at 2am
*/15 9-17 * * *  # Every 15 minutes during business hours (9am-5pm)
```

📋 Create a CronJob called `report` that runs every day at midnight and prints "Daily report" using the busybox image.

<details>
  <summary>Solution</summary>

```
kubectl create cronjob report --image=busybox \
  --schedule="0 0 * * *" \
  -- echo "Daily report"

# Verify the schedule
kubectl get cronjob report
kubectl describe cronjob report | grep Schedule

# Trigger it manually to test
kubectl create job report-manual --from=cronjob/report
kubectl logs job/report-manual
```

</details><br />

## CronJob Concurrency Policies

The `concurrencyPolicy` controls what happens if a new Job is scheduled while the previous one is still running:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup
spec:
  schedule: "0 2 * * *"
  concurrencyPolicy: Forbid  # Allow | Forbid | Replace
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: backup-image
          restartPolicy: OnFailure
```

**Concurrency Options:**

| Policy | Behavior |
|--------|----------|
| `Allow` (default) | Multiple Jobs can run concurrently |
| `Forbid` | Skip new Job if previous still running |
| `Replace` | Cancel existing Job and start new one |

### CKAD Scenario: Long-Running Job Protection

```
cat << EOF | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: long-task
spec:
  schedule: "*/2 * * * *"  # Every 2 minutes
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: worker
            image: busybox
            command: ["sh", "-c", "echo Starting; sleep 180; echo Done"]
          restartPolicy: Never
EOF

# Watch Jobs - if one is still running when next is scheduled, it's skipped
kubectl get jobs --watch
```

## Job and CronJob Time Limits

Jobs and CronJobs support several time-based configurations for controlling execution duration and cleanup:

### activeDeadlineSeconds

Specifies the maximum duration a Job can run before being terminated:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: job-with-deadline
spec:
  activeDeadlineSeconds: 30  # Job killed after 30 seconds
  template:
    spec:
      containers:
      - name: long-task
        image: busybox
        command: ["sh", "-c", "sleep 60"]  # Tries to run 60s but killed at 30s
      restartPolicy: Never
```

**Key Points:**
- Job terminates after this time regardless of completion status
- Pod is killed and Job status shows `DeadlineExceeded`
- Applies to entire Job duration (not individual Pod attempts)
- Useful for preventing runaway Jobs

```
# Apply the example
kubectl apply -f labs/jobs/specs/ckad/time-limits.yaml

# Watch it get terminated
kubectl get job job-with-deadline --watch

# Check the reason
kubectl describe job job-with-deadline
# Look for: Type: Failed, Reason: DeadlineExceeded
```

### ttlSecondsAfterFinished

Automatically deletes Jobs after they complete or fail:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: job-with-ttl
spec:
  ttlSecondsAfterFinished: 100  # Delete 100s after completion/failure
  template:
    spec:
      containers:
      - name: task
        image: busybox
        command: ["sh", "-c", "echo 'Task done'; sleep 10"]
      restartPolicy: Never
```

**Key Points:**
- TTL controller automatically deletes Job and its Pods
- Countdown starts when Job reaches `Complete` or `Failed` state
- Helps prevent resource buildup from old Jobs
- If set to `0`, Job deleted immediately after completion
- Requires TTL controller enabled (default in most clusters)

**CKAD Tip:** Use TTL for exam cleanup - set low values (30-60s) for quick resource cleanup.

### startingDeadlineSeconds (CronJob)

Defines the deadline for starting a scheduled CronJob:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cronjob-with-deadline
spec:
  schedule: "*/1 * * * *"
  startingDeadlineSeconds: 200  # Must start within 200s of scheduled time
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: task
            image: busybox
            command: ["sh", "-c", "date"]
          restartPolicy: Never
```

**Key Points:**
- If CronJob can't start within this deadline, it's marked as missed
- Prevents accumulation of missed Jobs after controller downtime
- If unset, no deadline (unlimited missed Job history)
- Useful for handling controller/cluster restarts gracefully

**Scenario Example:**
```
CronJob scheduled: 10:00:00
Controller down: 10:00:00 - 10:05:00
startingDeadlineSeconds: 200 (3m 20s)

Result when controller recovers at 10:05:00:
- 10:00 job - 5 minutes old (300s) - MISSED (exceeds 200s)
- 10:01 job - 4 minutes old (240s) - MISSED (exceeds 200s)
- 10:02 job - 3 minutes old (180s) - RUNS (within 200s)
- 10:03 job - 2 minutes old (120s) - RUNS (within 200s)
- 10:04 job - 1 minute old (60s) - RUNS (within 200s)
```

### Combined Time Limits Example

You can use all time limits together for comprehensive control:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cronjob-comprehensive
spec:
  schedule: "*/5 * * * *"
  startingDeadlineSeconds: 300  # Start within 5 minutes
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  concurrencyPolicy: Forbid

  jobTemplate:
    spec:
      activeDeadlineSeconds: 240  # Each job max 4 minutes
      ttlSecondsAfterFinished: 600  # Jobs deleted after 10 minutes
      backoffLimit: 3

      template:
        spec:
          containers:
          - name: task
            image: busybox
            command: ["sh", "-c", "echo 'Running'; sleep 30; echo 'Done'"]
          restartPolicy: OnFailure
```

This configuration:
1. **startingDeadlineSeconds: 300** - Job must start within 5 minutes of schedule
2. **activeDeadlineSeconds: 240** - Each Job killed if runs over 4 minutes
3. **ttlSecondsAfterFinished: 600** - Jobs auto-deleted 10 minutes after finish
4. **backoffLimit: 3** - Retry up to 3 times on failure
5. **concurrencyPolicy: Forbid** - Don't start new Job if previous still running

### CKAD Scenario: Database Backup Job

Realistic example for database backup with timeouts:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: database-backup
spec:
  activeDeadlineSeconds: 1800  # 30 minute timeout
  backoffLimit: 1  # Only retry once
  ttlSecondsAfterFinished: 86400  # Keep for 24 hours

  template:
    spec:
      containers:
      - name: backup
        image: busybox
        command:
        - sh
        - -c
        - |
          echo "Starting database backup at $(date)"
          for i in $(seq 1 10); do
            echo "Backing up table $i of 10..."
            sleep 10
          done
          echo "Backup completed at $(date)"
      restartPolicy: Never
```

📋 Create a Job that must complete within 15 seconds, then auto-deletes after 30 seconds. Make it sleep for 10 seconds so it completes successfully.

<details>
  <summary>Solution</summary>

```
cat << EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: quick-task
spec:
  activeDeadlineSeconds: 15  # Max 15 seconds
  ttlSecondsAfterFinished: 30  # Clean up after 30 seconds
  backoffLimit: 0  # No retries

  template:
    spec:
      containers:
      - name: task
        image: busybox
        command: ['sh', '-c', 'echo "Starting"; sleep 10; echo "Done"']
      restartPolicy: Never
EOF

# Watch it complete
kubectl get job quick-task --watch

# Wait 30 seconds after completion
sleep 35

# Job should be gone
kubectl get job quick-task
# Should show: Error from server (NotFound)
```

</details><br />

### Time Limits Best Practices

1. **Set activeDeadlineSeconds** for Jobs that might hang indefinitely
2. **Use ttlSecondsAfterFinished** to prevent Job accumulation (exam cleanup!)
3. **Configure startingDeadlineSeconds** for non-critical CronJobs (prevents missed job buildup)
4. **Test timeouts** before production - ensure they're appropriate for workload
5. **Monitor DeadlineExceeded** events to identify Jobs that need more time
6. **Combine with backoffLimit** to control total retry behavior

### Common Time Limit Patterns

```yaml
# Quick cleanup (exam/testing)
ttlSecondsAfterFinished: 30

# Production batch job
activeDeadlineSeconds: 3600
ttlSecondsAfterFinished: 86400

# Critical CronJob (never miss)
startingDeadlineSeconds: 604800  # 1 week

# Non-critical CronJob (prevent buildup)
startingDeadlineSeconds: 300  # 5 minutes
```

## Successful Jobs History Limits

CronJobs keep history of completed and failed Jobs:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cleanup
spec:
  schedule: "0 3 * * *"
  successfulJobsHistoryLimit: 3  # Keep last 3 successful
  failedJobsHistoryLimit: 1      # Keep last 1 failed
  jobTemplate:
    # ... job spec
```

**Defaults:**
- `successfulJobsHistoryLimit`: 3
- `failedJobsHistoryLimit`: 1

📋 Create a CronJob that runs every minute, keeps 5 successful job histories and 2 failed ones.

<details>
  <summary>Solution</summary>

```
cat << EOF | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: frequent-task
spec:
  schedule: "*/1 * * * *"
  successfulJobsHistoryLimit: 5
  failedJobsHistoryLimit: 2
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: task
            image: busybox
            command: ["echo", "Task completed"]
          restartPolicy: Never
EOF

# Wait a few minutes and check history
kubectl get jobs
```

</details><br />

## Debugging Failed Jobs

### Check Job Status

```
# Get Job status
kubectl get job failing-job
# Shows COMPLETIONS column: 0/1 means 0 successful out of 1 required

# Detailed Job information
kubectl describe job failing-job
# Look for: Pods Statuses, Events, and "Failed" conditions

# Check Job conditions
kubectl get job failing-job -o jsonpath='{.status.conditions[*].type}'
```

### Check Pod Status and Logs

```
# Find Pods created by Job
kubectl get pods -l job-name=failing-job

# Check Pod events
kubectl describe pod <pod-name>
# Look for: State, Last State, Restart Count, Events

# View container logs
kubectl logs -l job-name=failing-job
kubectl logs -l job-name=failing-job --previous  # Previous container logs

# For multiple Pods, view all logs
kubectl logs -l job-name=my-job --all-containers=true
```

### Common Failure Patterns

1. **ImagePullBackOff**: Wrong image name or no pull access
2. **CrashLoopBackOff**: Container starts but immediately crashes
3. **Error/ContainerCannotRun**: Command not found or invalid
4. **Pending**: Resource constraints or scheduling issues

### CKAD Debug Scenario

```
# Create a failing Job
cat << EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: debug-me
spec:
  backoffLimit: 2
  template:
    spec:
      containers:
      - name: app
        image: busybox
        command: ["nonexistent-command"]
      restartPolicy: Never
EOF

# Debug it
kubectl get job debug-me
kubectl get pods -l job-name=debug-me
kubectl describe pod <pod-name>  # Check Events
kubectl logs <pod-name>  # May not work if container never started
```

📋 Create a Job that will fail due to wrong command, identify the error, fix it and recreate.

<details>
  <summary>Solution</summary>

```
# Create failing Job
kubectl create job broken --image=nginx -- /bin/wrong-command

# Check status
kubectl get job broken
kubectl get pods -l job-name=broken

# Describe to see error
kubectl describe pod <pod-name>
# You'll see: "executable file not found"

# Fix: delete and recreate with correct command
kubectl delete job broken
kubectl create job fixed --image=nginx -- /bin/sh -c "echo Success"

# Verify
kubectl logs job/fixed
```

</details><br />

## Suspending and Resuming CronJobs

CronJobs can be suspended to prevent new Jobs from being created:

```
# Suspend a CronJob (imperative)
kubectl patch cronjob my-cronjob -p '{"spec":{"suspend":true}}'

# Resume a CronJob
kubectl patch cronjob my-cronjob -p '{"spec":{"suspend":false}}'

# Or edit directly
kubectl edit cronjob my-cronjob
# Change spec.suspend: true

# Check suspension status
kubectl get cronjob my-cronjob
# SUSPEND column shows True/False
```

### CKAD Scenario: Suspend During Maintenance

```
# Create a CronJob
kubectl create cronjob backup --image=busybox \
  --schedule="*/5 * * * *" \
  -- echo "Backing up"

# Suspend it (e.g., during maintenance window)
kubectl patch cronjob backup -p '{"spec":{"suspend":true}}'

# Verify - no new Jobs created
kubectl get cronjobs backup
kubectl get jobs --watch

# Resume after maintenance
kubectl patch cronjob backup -p '{"spec":{"suspend":false}}'
```

## Creating Jobs from CronJobs

In the exam, you may need to trigger a CronJob immediately without waiting:

```
# Create Job from CronJob (copies the jobTemplate)
kubectl create job manual-run --from=cronjob/my-cronjob

# With custom name
kubectl create job backup-now --from=cronjob/backup

# Verify
kubectl get jobs
kubectl logs job/backup-now
```

📋 Create a CronJob that runs weekly, then manually trigger it twice with different job names.

<details>
  <summary>Solution</summary>

```
# Create weekly CronJob
kubectl create cronjob weekly-report --image=busybox \
  --schedule="0 0 * * 0" \
  -- echo "Weekly report generated"

# Manually trigger with custom names
kubectl create job report-jan --from=cronjob/weekly-report
kubectl create job report-feb --from=cronjob/weekly-report

# Check both Jobs
kubectl get jobs
kubectl logs job/report-jan
kubectl logs job/report-feb
```

</details><br />

## Job Label Selectors

Jobs automatically create a `job-name` label on their Pods:

```
# Get Pods from specific Job
kubectl get pods -l job-name=my-job

# Get all Job-created Pods
kubectl get pods -l job-name

# Delete all Pods from a Job (Job will recreate if not complete)
kubectl delete pods -l job-name=my-job

# View logs from all Pods in Job
kubectl logs -l job-name=my-job

# Get Jobs by custom label
kubectl get jobs -l app=batch-processor
```

You can also add your own labels to the Pod template for easier management.

## CKAD Exam Patterns and Tips

### Common Exam Tasks

1. **Create one-off Job**
   ```
   kubectl create job task --image=busybox -- <command>
   ```

2. **Create parallel Job**
   - Generate YAML with dry-run
   - Add `completions` and `parallelism`
   - Apply and verify

3. **Create CronJob with schedule**
   ```
   kubectl create cronjob name --image=img --schedule="* * * * *" -- cmd
   ```

4. **Trigger CronJob immediately**
   ```
   kubectl create job manual --from=cronjob/name
   ```

5. **Suspend/Resume CronJob**
   ```
   kubectl patch cronjob name -p '{"spec":{"suspend":true}}'
   ```

6. **Debug failed Job**
   - Check Job status
   - Describe Pods
   - View logs
   - Fix and recreate

### Time-Saving Tips

1. **Use imperative commands** for simple Jobs/CronJobs
2. **Use --from=cronjob/** to quickly test CronJobs
3. **Use -l job-name=** for Job-related operations
4. **Remember Jobs are immutable** - delete and recreate to fix
5. **Check backoffLimit** if Job keeps retrying
6. **Use describe** for debugging - shows clear error messages

### Exam Gotchas

1. **Restart policy** - Must be `Never` or `OnFailure` (not `Always`)
2. **Job immutability** - Can't update Pod template in existing Job
3. **CronJob timezone** - Schedules use controller's timezone (usually UTC)
4. **Job cleanup** - Jobs don't auto-delete; CronJobs keep history
5. **Completion vs Success** - Job shows completed but check if Pods succeeded
6. **Label selection** - Use `job-name` label automatically created by Jobs

## Practice Exercises

### Exercise 1: Parallel Batch Processing

Create a Job that:
- Runs 20 tasks total
- Runs 5 tasks in parallel
- Each task sleeps for 5 seconds then prints "Task complete"
- Has a backoff limit of 3
- Uses restart policy `Never`

Verify it completes successfully and check the total runtime.

<details>
  <summary>Solution</summary>

```
cat << EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: batch-processing
spec:
  completions: 20
  parallelism: 5
  backoffLimit: 3
  template:
    spec:
      containers:
      - name: worker
        image: busybox
        command: ["sh", "-c", "sleep 5; echo Task complete"]
      restartPolicy: Never
EOF

# Watch it run (should take ~20 seconds with 5 parallel)
kubectl get job batch-processing --watch
kubectl get pods -l job-name=batch-processing

# Check logs
kubectl logs -l job-name=batch-processing
```

</details><br />

### Exercise 2: CronJob with Suspend/Resume

Create a CronJob that:
- Runs every 2 minutes
- Prints the current date and hostname
- Keeps 5 successful and 3 failed job histories
- Uses concurrency policy `Forbid`

Then:
1. Let it run and create 2 jobs
2. Suspend it
3. Create a manual job from it
4. Resume it

<details>
  <summary>Solution</summary>

```
cat << EOF | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: date-reporter
spec:
  schedule: "*/2 * * * *"
  successfulJobsHistoryLimit: 5
  failedJobsHistoryLimit: 3
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: reporter
            image: busybox
            command: ["sh", "-c", "date; hostname"]
          restartPolicy: Never
EOF

# Wait for 2 Jobs to be created
kubectl get jobs --watch

# Suspend
kubectl patch cronjob date-reporter -p '{"spec":{"suspend":true}}'
kubectl get cronjob date-reporter

# Manual trigger
kubectl create job manual-report --from=cronjob/date-reporter
kubectl logs job/manual-report

# Resume
kubectl patch cronjob date-reporter -p '{"spec":{"suspend":false}}'
```

</details><br />

### Exercise 3: Job Failure and Recovery

Create a Job that will fail initially, then fix it:

1. Create a Job with wrong command that will fail
2. Set backoffLimit to 2
3. Watch it fail
4. Delete it
5. Create corrected version
6. Verify success

<details>
  <summary>Solution</summary>

```
# Step 1: Create a failing Job with wrong command
cat << EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: failing-processor
spec:
  backoffLimit: 2
  template:
    spec:
      containers:
      - name: processor
        image: busybox
        command: ["/usr/bin/nonexistent-command", "arg1", "arg2"]
      restartPolicy: Never
EOF

# Step 2 & 3: Watch it fail
kubectl get job failing-processor --watch
# Watch READY column stay at 0/1

# Check Job status
kubectl get job failing-processor
# Shows: COMPLETIONS 0/1

# Get the Pods created by the Job
kubectl get pods -l job-name=failing-processor

# Step 4: Describe one of the failed Pods to see the error
POD_NAME=$(kubectl get pods -l job-name=failing-processor -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod $POD_NAME
# Look for: Failed to start container: exec: "/usr/bin/nonexistent-command": stat /usr/bin/nonexistent-command: no such file or directory

# Check Job events
kubectl describe job failing-processor
# Look for: BackoffLimitExceeded, Job has reached the specified backoff limit

# Try to view logs (may be empty if container never started)
kubectl logs -l job-name=failing-processor

# Step 5: Delete the failed Job
kubectl delete job failing-processor

# Step 6: Create corrected version
cat << EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: working-processor
spec:
  backoffLimit: 2
  template:
    spec:
      containers:
      - name: processor
        image: busybox
        command: ["sh", "-c", "echo 'Processing data...'; sleep 5; echo 'Data processed successfully'"]
      restartPolicy: Never
EOF

# Verify it completes successfully
kubectl get job working-processor --watch

# Check completion
kubectl get job working-processor
# Should show: COMPLETIONS 1/1

# View logs to confirm success
kubectl logs job/working-processor

# Cleanup
kubectl delete job working-processor
```

**Key Learning Points:**

1. **Jobs are immutable** - You cannot edit the Pod template of an existing Job. Must delete and recreate.

2. **backoffLimit controls retry attempts** - With backoffLimit: 2 and restartPolicy: Never, Job creates up to 3 Pods total (initial + 2 retries).

3. **Debugging failed Jobs**:
   - Use `kubectl get job` to see completion status
   - Use `kubectl get pods -l job-name=NAME` to find Job's Pods
   - Use `kubectl describe pod` to see container errors
   - Use `kubectl describe job` to see Job-level events
   - Use `kubectl logs` to view container output (if it started)

4. **Common failure reasons**:
   - **ContainerCannotRun** - Command not found or invalid
   - **ImagePullBackOff** - Wrong image name or no access
   - **CrashLoopBackOff** - Container starts but crashes
   - **Pending** - Resource constraints or scheduling issues

5. **Never vs OnFailure restart policies**:
   - `Never` - Creates new Pod for each retry
   - `OnFailure` - Restarts container in same Pod

</details><br />

## Advanced CKAD Topics

### Job Completion Modes: Indexed vs NonIndexed

Kubernetes 1.21+ supports two completion modes for Jobs:

#### NonIndexed Mode (Default)

Pods run without specific identifiers - suitable for general parallel processing:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: non-indexed-job
spec:
  completions: 5
  parallelism: 2
  completionMode: NonIndexed  # Default, can be omitted
  template:
    spec:
      containers:
      - name: worker
        image: busybox
        command: ["sh", "-c", "echo 'Processing...'; sleep 5"]
      restartPolicy: Never
```

**Characteristics:**
- No unique index per Pod
- Pod names are random (e.g., `job-name-xxxxx`)
- Use for stateless parallel work
- Cannot identify which task each Pod processed

#### Indexed Mode (1.21+)

Each Pod gets a unique completion index via `JOB_COMPLETION_INDEX` environment variable:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: indexed-job
spec:
  completions: 5
  parallelism: 2
  completionMode: Indexed  # Pods get indexes 0-4
  template:
    spec:
      containers:
      - name: worker
        image: busybox
        command:
        - sh
        - -c
        - |
          echo "Processing task with index: $JOB_COMPLETION_INDEX"
          case $JOB_COMPLETION_INDEX in
            0) echo "Processing dataset A";;
            1) echo "Processing dataset B";;
            2) echo "Processing dataset C";;
            3) echo "Processing dataset D";;
            4) echo "Processing dataset E";;
          esac
      restartPolicy: Never
```

**Characteristics:**
- `JOB_COMPLETION_INDEX` environment variable (0 to completions-1)
- Pod names include index: `job-name-0-xxxxx`, `job-name-1-xxxxx`
- Each index completes exactly once
- Perfect for processing specific data partitions
- If Pod fails, a new Pod is created with same index

**CKAD Use Cases:**
```
# Process 10 files with specific indexes
completions: 10
- Index 0 processes file-0.txt
- Index 1 processes file-1.txt
- etc.

# Batch ETL pipeline
- Index determines which database shard to process
- Index determines which date range to handle
```

📋 Create an Indexed Job with 4 completions that prints each index and processes different data based on the index.

<details>
  <summary>Solution</summary>

```
cat << EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: data-processor
spec:
  completions: 4
  parallelism: 2
  completionMode: Indexed
  template:
    spec:
      containers:
      - name: processor
        image: busybox
        command:
        - sh
        - -c
        - |
          echo "Worker with index: \$JOB_COMPLETION_INDEX"
          echo "Hostname: \$(hostname)"

          # Process different data based on index
          case \$JOB_COMPLETION_INDEX in
            0) echo "Processing Q1 data"; sleep 3;;
            1) echo "Processing Q2 data"; sleep 3;;
            2) echo "Processing Q3 data"; sleep 3;;
            3) echo "Processing Q4 data"; sleep 3;;
          esac

          echo "Index \$JOB_COMPLETION_INDEX completed"
      restartPolicy: Never
EOF

# Watch Pods being created with indexes
kubectl get pods -l job-name=data-processor --watch

# View logs from all Pods
kubectl logs -l job-name=data-processor

# Cleanup
kubectl delete job data-processor
```

</details><br />

### Using Jobs with PersistentVolumeClaims

Jobs can use PersistentVolumes for storing results or sharing data between Job runs:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: job-storage
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: batch/v1
kind: Job
metadata:
  name: job-with-pvc
spec:
  template:
    spec:
      containers:
      - name: processor
        image: busybox
        command:
        - sh
        - -c
        - |
          echo "Writing results to persistent storage..."
          date > /data/job-$(hostname).txt
          echo "Results saved"
          cat /data/job-$(hostname).txt
        volumeMounts:
        - name: storage
          mountPath: /data
      volumes:
      - name: storage
        persistentVolumeClaim:
          claimName: job-storage
      restartPolicy: Never
```

**CKAD Scenario: Multi-Step Pipeline**

Multiple Jobs can share a PVC to pass data between stages:

```yaml
# Job 1: Extract data
apiVersion: batch/v1
kind: Job
metadata:
  name: extract-job
spec:
  template:
    spec:
      containers:
      - name: extractor
        image: busybox
        command: ["sh", "-c", "echo 'data1,data2,data3' > /shared/data.csv"]
        volumeMounts:
        - name: shared
          mountPath: /shared
      volumes:
      - name: shared
        persistentVolumeClaim:
          claimName: job-storage
      restartPolicy: Never
---
# Job 2: Transform data (run after Job 1 completes)
apiVersion: batch/v1
kind: Job
metadata:
  name: transform-job
spec:
  template:
    spec:
      containers:
      - name: transformer
        image: busybox
        command:
        - sh
        - -c
        - |
          if [ -f /shared/data.csv ]; then
            cat /shared/data.csv | tr ',' '\n' > /shared/transformed.txt
            echo "Transformation complete"
          else
            echo "ERROR: Input file not found"
            exit 1
          fi
        volumeMounts:
        - name: shared
          mountPath: /shared
      volumes:
      - name: shared
        persistentVolumeClaim:
          claimName: job-storage
      restartPolicy: Never
```

**Exam Tip:** For sequential Jobs with PVC, wait for first Job to complete before creating the second.

### Init Containers in Jobs

Init containers can prepare the environment before the main Job container runs:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: job-with-init
spec:
  template:
    spec:
      initContainers:
      - name: setup
        image: busybox
        command:
        - sh
        - -c
        - |
          echo "Downloading configuration..."
          sleep 2
          echo "config_key=value123" > /config/app.conf
          echo "Setup complete"
        volumeMounts:
        - name: config
          mountPath: /config

      containers:
      - name: worker
        image: busybox
        command:
        - sh
        - -c
        - |
          echo "Reading configuration..."
          cat /config/app.conf
          echo "Processing job with config..."
          sleep 5
          echo "Job complete"
        volumeMounts:
        - name: config
          mountPath: /config

      volumes:
      - name: config
        emptyDir: {}

      restartPolicy: Never
```

**Common Init Container Use Cases:**
1. Download configuration files
2. Wait for dependencies (databases, services)
3. Clone git repositories
4. Pre-populate shared volumes
5. Validate prerequisites before Job starts

### Sidecar Patterns in Jobs

While not recommended for Jobs (meant for finite tasks), sidecars are possible:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: job-with-sidecar
spec:
  template:
    spec:
      containers:
      - name: main
        image: busybox
        command:
        - sh
        - -c
        - |
          echo "Main job starting"
          for i in 1 2 3 4 5; do
            echo "Processing item $i" >> /logs/app.log
            sleep 2
          done
          echo "Main job complete"
        volumeMounts:
        - name: logs
          mountPath: /logs

      - name: log-shipper
        image: busybox
        command:
        - sh
        - -c
        - |
          while true; do
            if [ -f /logs/app.log ]; then
              echo "Shipping logs..."
              cat /logs/app.log
            fi
            sleep 3
          done
        volumeMounts:
        - name: logs
          mountPath: /logs

      volumes:
      - name: logs
        emptyDir: {}

      restartPolicy: Never
```

**Problem:** Sidecar doesn't know when to stop; Job won't complete until all containers finish.

**Better Approach:** Use init containers or let main container handle all work.

### Job Pod Failure Policy (Kubernetes 1.25+)

Provides fine-grained control over how Job reacts to Pod failures:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: job-with-failure-policy
spec:
  backoffLimit: 6
  podFailurePolicy:
    rules:
    - action: FailJob  # Fail entire Job immediately
      onExitCodes:
        containerName: main
        operator: In
        values: [42]  # Exit code 42 fails Job immediately

    - action: Ignore  # Ignore this failure, don't count against backoffLimit
      onExitCodes:
        containerName: main
        operator: In
        values: [1]  # Exit code 1 is ignorable

    - action: Count  # Count against backoffLimit (default behavior)
      onExitCodes:
        containerName: main
        operator: NotIn
        values: [1, 42]

  template:
    spec:
      containers:
      - name: main
        image: busybox
        command: ["sh", "-c", "exit 0"]  # Change to test different exit codes
      restartPolicy: Never
```

**Actions:**
- **FailJob** - Terminate Job immediately
- **Ignore** - Don't count failure against backoffLimit
- **Count** - Count against backoffLimit (default)

**CKAD Note:** This feature is beta in 1.25+. Check exam Kubernetes version.

### CronJob Timezone Support (Kubernetes 1.25+)

Specify timezone for CronJob schedules:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cronjob-with-timezone
spec:
  schedule: "0 9 * * *"  # 9:00 AM
  timeZone: "America/New_York"  # Eastern Time
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: task
            image: busybox
            command: ["sh", "-c", "date; echo 'Morning task'"]
          restartPolicy: Never
```

**Without timezone field:** CronJob uses kube-controller-manager timezone (usually UTC)

**With timezone field:** Schedule interprets in specified timezone

**Common Timezones:**
- `America/New_York` - Eastern Time
- `America/Los_Angeles` - Pacific Time
- `America/Chicago` - Central Time
- `Europe/London` - GMT/BST
- `Europe/Paris` - Central European Time
- `Asia/Tokyo` - Japan Time
- `UTC` - Coordinated Universal Time

**CKAD Note:** Available in Kubernetes 1.25+. Check exam version.

### Pod Failure Cost and Backoff Strategies

Jobs use exponential backoff for failed Pods:

**Backoff Calculation:**
```
Delay = min(2^(failures-1) * 10s, maxBackoff)
maxBackoff = 6 minutes

Attempt  | Delay Before Retry
---------|-------------------
1 (init) | 0s
2        | 10s   (2^0 * 10s)
3        | 20s   (2^1 * 10s)
4        | 40s   (2^2 * 10s)
5        | 80s   (2^3 * 10s)
6        | 160s  (2^4 * 10s)
7        | 320s  (2^5 * 10s)
8+       | 360s  (max 6 minutes)
```

**Example:**
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: backoff-demo
spec:
  backoffLimit: 5
  template:
    spec:
      containers:
      - name: flaky
        image: busybox
        command: ["sh", "-c", "echo Attempt; exit 1"]
      restartPolicy: Never
```

With backoffLimit: 5, if all fail:
- Total time: 0s + 10s + 20s + 40s + 80s + 160s = 310 seconds (~5 minutes)
- Total attempts: 6 (initial + 5 retries)

**Best Practices:**
1. Set appropriate backoffLimit (default 6 might be too many)
2. Combine with activeDeadlineSeconds for total time limit
3. Use OnFailure restart policy for fast failures (no backoff between container restarts)
4. Monitor Job events to understand failure patterns

### Advanced Patterns Summary

The advanced-patterns.yaml file in `labs/jobs/specs/ckad/` contains working examples:

```
kubectl apply -f labs/jobs/specs/ckad/advanced-patterns.yaml
```

**File Contents:**
- Indexed vs NonIndexed completion examples
- Job with PersistentVolumeClaim
- Multi-step pipeline using shared PVC
- Job with init containers
- Job with resource limits
- Job with node selectors and affinity
- Job with ServiceAccount for API access

**Practice Command:**
```
# Apply all advanced patterns
kubectl apply -f labs/jobs/specs/ckad/advanced-patterns.yaml

# Watch Jobs complete
kubectl get jobs --watch

# View logs from indexed job
kubectl logs -l job-name=indexed-job

# Check PVC usage
kubectl describe pvc job-storage

# Cleanup
kubectl delete -f labs/jobs/specs/ckad/advanced-patterns.yaml
```

## Common Pitfalls

1. **Forgetting restart policy** - Default `Always` is invalid for Jobs
2. **Trying to update Job** - Jobs are immutable; must delete and recreate
3. **Wrong cron syntax** - Test expressions, remember it's UTC typically
4. **Job not cleaning up** - Jobs don't auto-delete; use TTL or manual cleanup
5. **Backoff limit reached** - Job stops retrying; check Pod events for reason
6. **CronJob timezone** - Schedules are in controller timezone, not local
7. **Concurrent Jobs** - Default `Allow` may cause resource issues
8. **Missing job-name label** - Use `-l job-name=` not generic labels
9. **Logs disappear** - Old Jobs/Pods deleted by history limit
10. **OnFailure vs Never** - OnFailure restarts container, Never creates new Pod

## Quick Reference

### Job Commands
```bash
# Create
kubectl create job NAME --image=IMAGE -- CMD

# Get status
kubectl get jobs
kubectl describe job NAME

# Logs
kubectl logs job/NAME
kubectl logs -l job-name=NAME

# Delete (deletes Pods too)
kubectl delete job NAME
```

### CronJob Commands
```bash
# Create
kubectl create cronjob NAME --image=IMAGE --schedule="CRON" -- CMD

# Get status
kubectl get cronjobs
kubectl describe cronjob NAME

# Trigger manually
kubectl create job MANUAL-NAME --from=cronjob/NAME

# Suspend/Resume
kubectl patch cronjob NAME -p '{"spec":{"suspend":true}}'
kubectl patch cronjob NAME -p '{"spec":{"suspend":false}}'

# Delete
kubectl delete cronjob NAME
```

### Common Cron Schedules
```
*/5 * * * *      Every 5 minutes
0 * * * *        Every hour
0 0 * * *        Daily at midnight
0 0 * * 0        Weekly on Sunday
0 0 1 * *        Monthly on 1st
```

## Cleanup

```
# Delete specific Job
kubectl delete job my-job

# Delete all Jobs with label
kubectl delete jobs -l app=batch

# Delete CronJob (keeps existing Jobs)
kubectl delete cronjob my-cronjob

# Delete CronJob and all its Jobs
kubectl delete cronjob my-cronjob
kubectl delete jobs -l parent-cronjob=my-cronjob  # if labeled

# Delete completed Jobs
kubectl delete jobs --field-selector status.successful=1

# Delete all Jobs in namespace
kubectl delete jobs --all
```

## Next Steps

After mastering Jobs and CronJobs for CKAD:
1. Practice [ConfigMaps](../configmaps/) - Often used with Jobs
2. Study [Secrets](../secrets/) - For sensitive Job data
3. Review [Resource Management](../productionizing/) - Limits for Jobs
4. Explore [ServiceAccounts](../rbac/) - Jobs often need specific permissions

---

## Study Checklist for CKAD

- [ ] Create Jobs imperatively with kubectl create
- [ ] Set restart policies (Never vs OnFailure)
- [ ] Configure completions and parallelism
- [ ] Set and understand backoffLimit
- [ ] Create CronJobs with various schedules
- [ ] Understand cron expression syntax
- [ ] Trigger Jobs manually from CronJobs
- [ ] Suspend and resume CronJobs
- [ ] Set concurrencyPolicy appropriately
- [ ] Configure history limits
- [ ] Debug failed Jobs using describe and logs
- [ ] Use job-name label for Pod selection
- [ ] Delete and recreate Jobs (remember immutability)
- [ ] Generate Job/CronJob YAML with --dry-run
- [ ] Understand when Jobs complete vs fail
