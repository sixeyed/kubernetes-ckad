# Container Images - Practical Demo
## Narration Script for Hands-On Exercises (15-18 minutes)

### Section 1: Simple Multi-Stage Build (3 min)

Disable BuildKit to see all stages:

```powershell
$env:DOCKER_BUILDKIT=0

docker build -t courselabs/docker:simple ./labs/docker/simple
```

Output shows base and build stage content, but not test stage.

Enable BuildKit:

```powershell
$env:DOCKER_BUILDKIT=1

docker build -t courselabs/docker:simple ./labs/docker/simple
```

BuildKit skips unused test stage. Build specific stage:

```powershell
docker build -t courselabs/docker:simple-test --target test ./labs/docker/simple
```

### Section 2: Real Multi-Stage Go App (4 min)

Examine multi-stage Dockerfile:

```powershell
cat ./labs/docker/whoami/Dockerfile.v1
```

Build whoami app:

```powershell
docker build -t courselabs/whoami:v1 -f ./labs/docker/whoami/Dockerfile.v1 ./labs/docker/whoami
```

Compare image sizes:

```powershell
docker image ls courselabs/whoami
docker image ls golang
```

SDK image: 300MB+, App image: <10MB. Run the app:

```powershell
docker run -d -p 8080:80 --name whoami courselabs/whoami:v1

curl http://localhost:8080
```

### Section 3: Build, Tag, and Deploy (4 min)

Build with multiple tags:

```powershell
docker build -t courselabs/whoami:v2 -t courselabs/whoami:latest -f ./labs/docker/whoami/Dockerfile.v2 ./labs/docker/whoami

docker image ls courselabs/whoami
```

Deploy to Kubernetes:

```powershell
kubectl create deployment whoami --image=courselabs/whoami:v2

kubectl get pods -l app=whoami
```

Expose service:

```powershell
kubectl expose deployment whoami --port=8080 --target-port=80 --type=LoadBalancer

kubectl get svc whoami
```

### Section 4: Update and Rollback (3 min)

Build new version:

```powershell
docker build -t courselabs/whoami:v3 -f ./labs/docker/whoami/Dockerfile.v3 ./labs/docker/whoami
```

Update deployment:

```powershell
kubectl set image deployment/whoami whoami=courselabs/whoami:v3

kubectl rollout status deployment/whoami
```

Rollback:

```powershell
kubectl rollout undo deployment/whoami

kubectl rollout status deployment/whoami
```

### Section 5: ImagePullPolicy and Troubleshooting (3 min)

For local images with Docker Desktop, images are automatically available. For Kind/Minikube, load images:

```powershell
# For Kind:
kind load docker-image courselabs/whoami:v2

# For Minikube:
minikube image load courselabs/whoami:v2
```

Common issues:

```powershell
# Test ImagePullBackOff scenario
kubectl run test-pull --image=courselabs/whoami:nonexistent

kubectl get pods
kubectl describe pod test-pull
```

Cleanup:

```powershell
docker rm -f whoami

kubectl delete deployment,svc whoami
kubectl delete pod test-pull
```

Key takeaways: Multi-stage builds create small images, proper tagging for versions, imagePullPolicy for local images, troubleshoot with describe and events.
