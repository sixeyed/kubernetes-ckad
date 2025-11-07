# Container Images - CKAD Exam Preparation
## Narration Script for Exam-Focused Training (15-20 minutes)

### Section 1: CKAD Image Building Requirements (2 min)
**[00:00-02:00]**

CKAD "Application Design and Build" domain (20%) includes container image creation.

Exam tasks include:
- Write or modify a Dockerfile
- Build an image from Dockerfile
- Use multi-stage builds
- Tag images correctly
- Reference images in Pod/Deployment specs
- Troubleshoot image pull issues

Essential commands:

```bash
# Build with tag
docker build -t myapp:v1.0 .

# Create additional tags
docker tag myapp:v1.0 myapp:latest

# List images
docker image ls

# Update deployment image
kubectl set image deployment/myapp myapp=myapp:v1.1
```

### Section 2: Quick Dockerfile Patterns (3 min)
**[02:00-05:00]**

Basic Node.js Dockerfile:

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]
```

Multi-stage Go build:

```dockerfile
# Stage 1: Build
FROM golang:1.21 AS builder
WORKDIR /app
COPY go.* ./
RUN go mod download
COPY . .
RUN go build -o app

# Stage 2: Run
FROM alpine:3.18
COPY --from=builder /app/app /app
CMD ["/app"]
```

Multi-stage Node.js build:

```dockerfile
# Stage 1: Build
FROM node:18 AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: Run
FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY package*.json ./
RUN npm ci --production
CMD ["node", "dist/server.js"]
```

### Section 3: Build and Tag Efficiently (3 min)
**[05:00-08:00]**

Build with multiple tags:

```bash
docker build -t myapp:v1.0.0 -t myapp:v1.0 -t myapp:latest .
```

Tag existing image:

```bash
docker tag myapp:v1.0.0 myregistry.io/myapp:v1.0.0
```

Quick patterns:

```bash
# Build from specific directory
docker build -t myapp:v1 ./app

# Build with specific Dockerfile
docker build -t myapp:v1 -f Dockerfile.prod .

# Build specific stage
docker build -t myapp:test --target test .
```

Time-saving tip:

```bash
# Generate YAML with image already specified
kubectl create deployment myapp --image=myapp:v1.0 --dry-run=client -o yaml > deployment.yaml
```

### Section 4: Using Images in Kubernetes (3 min)
**[08:00-11:00]**

Pod spec with image:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  containers:
  - name: app
    image: myapp:v1.0
    imagePullPolicy: IfNotPresent
```

ImagePullPolicy decision tree:
- `Always` - always pull (use for :latest)
- `IfNotPresent` - only pull if not cached (use for specific versions)
- `Never` - only use local images

Update image imperatively:

```bash
kubectl set image deployment/myapp app=myapp:v1.1
kubectl rollout status deployment/myapp
```

Check current image:

```bash
# Using describe
kubectl describe deployment myapp | grep Image

# Using jsonpath
kubectl get deployment myapp -o jsonpath='{.spec.template.spec.containers[0].image}'
```

### Section 5: Troubleshooting Image Issues (3 min)
**[11:00-14:00]**

ImagePullBackOff diagnosis:

```bash
kubectl get pods
# Shows: ImagePullBackOff or ErrImagePull

kubectl describe pod myapp-xyz
# Check Events section for error details
```

Common causes:
- Wrong image name or tag
- Image doesn't exist in registry
- Missing registry credentials
- Network/registry issues

Troubleshooting steps:

```bash
# Verify image exists locally
docker image ls myapp

# Check pull secrets
kubectl get secrets
kubectl describe secret regcred

# Fix image reference
kubectl set image deployment/myapp app=myapp:v1.0
```

ErrImagePull vs ImagePullBackOff:
- `ErrImagePull` - first attempt failed
- `ImagePullBackOff` - multiple failures, backing off retries

### Section 6: Exam Scenarios (3 min)
**[14:00-17:00]**

Scenario 1: Build and deploy (complete in under 3 minutes):

```bash
# Build image
docker build -t myapp:v1.0 .

# Create deployment
kubectl create deployment myapp --image=myapp:v1.0

# Expose as service
kubectl expose deployment myapp --port=80 --type=NodePort
```

Scenario 2: Update Dockerfile and rebuild:

```bash
# Edit Dockerfile
vi Dockerfile

# Rebuild with new tag
docker build -t myapp:v2.0 .

# Update deployment
kubectl set image deployment/myapp myapp=myapp:v2.0

# Verify rollout
kubectl rollout status deployment/myapp
```

Scenario 3: Fix ImagePullBackOff:

```bash
# Describe pod to see error
kubectl describe pod myapp-xyz

# Fix image reference
kubectl set image deployment/myapp myapp=myapp:v1.0
# OR
kubectl edit deployment myapp
```

### Section 7: Exam Tips (2 min)
**[17:00-19:00]**

Speed tips:
- Use imperative commands to generate YAML
- Know common Dockerfile patterns by heart
- Practice typing `docker build` commands quickly
- Use `describe` for troubleshooting efficiently

Common mistakes to avoid:
- Typos in image name or tag
- Wrong build context path
- Forgetting to specify tag (defaults to :latest)
- Using Always pull policy with local images
- Not checking if build succeeded before proceeding

Quick checklist:
- [ ] Can you write a basic Dockerfile?
- [ ] Can you write a multi-stage Dockerfile?
- [ ] Do you know `docker build -t` syntax?
- [ ] Can you tag images multiple ways?
- [ ] Do you know imagePullPolicy options?
- [ ] Can you update deployment images?
- [ ] Can you troubleshoot ImagePullBackOff?

Practice until these operations take less than 3 minutes each.

Essential exam commands:

```bash
# Build and tag
docker build -t myapp:v1.0 .

# Multiple tags
docker build -t myapp:v1.0 -t myapp:latest .

# Build specific stage
docker build -t myapp:test --target test .

# Create deployment
kubectl create deployment myapp --image=myapp:v1.0

# Update image
kubectl set image deployment/myapp myapp=myapp:v2.0

# Troubleshoot
kubectl describe pod myapp-xyz
```
