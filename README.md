# Nginx DevOps Project

This project demonstrates a complete DevOps pipeline for deploying an Nginx web server using Docker, Kubernetes, Terraform, and CI/CD automation.

## Table of Contents

- [Project Overview](#project-overview)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Assignment Tasks](#assignment-tasks)
  - [Task 1 & 2: Nginx Setup and Docker](#task-1--2-nginx-setup-and-docker)
  - [Task 3 & 4: Kubernetes and CI/CD Pipeline](#task-3--4-kubernetes-and-cicd-pipeline)
  - [Task 5: Terraform Infrastructure](#task-5-terraform-infrastructure)
  - [Task 6: Bash Scripts](#task-6-bash-scripts)
- [Architecture Decisions](#architecture-decisions)
- [Production vs Demo Trade-offs](#production-vs-demo-trade-offs)

## Project Overview

This project includes:

- Custom Nginx Docker image with non-root user
- Kubernetes deployment using Helm charts
- Two complete Terraform infrastructures (EKS and EC2-based)
- GitHub Actions CI/CD pipeline with OIDC authentication
- ArgoCD for GitOps-based continuous deployment
- Bash automation scripts

## Project Structure
```
.
├── Dockerfile                    # Custom Nginx image
├── nginx/
│   ├── index.html               # Web page content
│   └── nginx.conf               # Nginx configuration with /healthz endpoint
├── k8s/
│   ├── helm/                    # Helm chart for Kubernetes
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       ├── deployment.yaml  # Nginx deployment with probes
│   │       ├── service.yaml     # ClusterIP service
│   │       ├── ingress.yaml     # ALB ingress for Nginx
│   │       └── argocd-ingress.yaml  # ArgoCD UI access
│   └── tf/                      # Terraform for EKS cluster
│       ├── main.tf
│       ├── modules/
│       │   ├── vpc/
│       │   ├── eks/
│       │   └── eks-addons/
│       └── ...
├── tf/                          # Terraform for EC2-based deployment
│   ├── main.tf
│   ├── modules/
│   │   ├── vpc/
│   │   ├── app/
│   │   ├── alb/
│   │   └── vpc_endpoints/
│   └── ...
├── bash/
│   ├── build_and_run.sh        # Build and run Docker container locally
│   └── check_health.sh         # Health check script with timeout
└── .github/
    └── workflows/
        └── ci-cd.yml            # GitHub Actions pipeline
```

## Prerequisites

- Docker (for local testing)
- AWS CLI configured with appropriate credentials
- kubectl (for Kubernetes deployments)
- Helm 3.x
- Terraform 1.0+
- GitHub account
- AWS account

## Assignment Tasks

### Task 1 & 2: Nginx Setup and Docker

This task creates a custom Nginx Docker image with a simple HTML page and health check endpoint.

#### What's Included:

**nginx.conf:**
- Listens on port 80
- Serves `index.html` from `/usr/share/nginx/html`
- Health check endpoint at `/healthz` that returns HTTP 200

**index.html:**
- Simple HTML page displaying "Nginx Test Environment"

**Dockerfile:**
- Based on `nginx:1.27-alpine` for small image size
- Runs as non-root user (nginxuser) for security
- Uses `libcap` to allow non-root user to bind to port 80
- Copies custom nginx.conf and index.html

#### Run Locally:
```bash
# Build the Docker image
docker build -t nginx .

# Run the container
docker run -d -p 80:80 nginx

# Test the main page
curl http://localhost

# Test the health check endpoint
curl http://localhost/healthz

# View in browser
open http://localhost

# Cleanup
docker stop nginx
docker rm nginx
```

**Expected Output:**
- Main page shows: "Nginx Test Environment"
- Health check returns: "ok" with HTTP 200 status

---

### Task 3 & 4: Kubernetes and CI/CD Pipeline

These tasks work together to deploy the Nginx application to Kubernetes with automated CI/CD.

#### What's Included:

**Kubernetes Resources (Helm Chart):**
- **Deployment**: 2 replicas with resource limits, liveness and readiness probes
- **Service**: ClusterIP service exposing port 80
- **Ingress**: AWS ALB for external access
- **Health Probes**: Both probes check `/healthz` endpoint

**CI/CD Pipeline (GitHub Actions):**
- Triggers on changes to `nginx/index.html`, Dockerfile, or Helm charts
- Builds Docker image with unique tag (build number)
- Pushes to Amazon ECR
- Updates Helm `values.yaml` with new image tag
- ArgoCD automatically deploys the changes

**Infrastructure (EKS via Terraform):**
- Complete EKS cluster with VPC, subnets, and routing
- AWS Load Balancer Controller for ALB provisioning
- ArgoCD for GitOps continuous deployment
- Nginx application automatically deployed via Helm

#### Prerequisites:

**1. Create S3 Bucket for Terraform State (Manual):**
```bash
# Create the S3 bucket
aws s3api create-bucket \
  --bucket nginx-test-env-tf-state-omer-1234 \
  --region eu-north-1 \
  --create-bucket-configuration LocationConstraint=eu-north-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket nginx-test-env-tf-state-omer-1234 \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket nginx-test-env-tf-state-omer-1234 \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket nginx-test-env-tf-state-omer-1234 \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

**2. Create ECR Repository:**
```bash
aws ecr create-repository \
  --repository-name nginx \
  --region eu-north-1
```

**3. Setup GitHub OIDC Authentication:**

**Step 3a: Create OIDC Identity Provider**

1. Log in to AWS Console and navigate to **IAM**
2. In the left sidebar, click on **Identity providers**
3. Click **Add provider** button
4. Configure the provider:
   - **Provider type**: Select "OpenID Connect"
   - **Provider URL**: Enter `https://token.actions.githubusercontent.com`
   - **Audience**: Enter `sts.amazonaws.com`
5. Click **Add provider**

**Step 3b: Create IAM Policy**

Create a policy named `github-actions-ecr-push-policy`:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:PutImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload"
            ],
            "Resource": "arn:aws:ecr:eu-north-1:<YOUR-ACCOUNT-ID>:repository/nginx"
        }
    ]
}
```
```bash
# Create the policy
aws iam create-policy \
  --policy-name github-actions-ecr-push-policy \
  --policy-document file://policy.json
```

**Step 3c: Create IAM Role**

Create a role named `github-actions-ecr-role` with trust policy:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::<YOUR-ACCOUNT-ID>:oidc-provider/token.actions.githubusercontent.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                },
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": "repo:<YOUR-GITHUB-USERNAME>/<YOUR-REPO-NAME>:*"
                }
            }
        }
    ]
}
```
```bash
# Create the role
aws iam create-role \
  --role-name github-actions-ecr-role \
  --assume-role-policy-document file://trust-policy.json

# Attach the policy
aws iam attach-role-policy \
  --role-name github-actions-ecr-role \
  --policy-arn arn:aws:iam::<YOUR-ACCOUNT-ID>:policy/github-actions-ecr-push-policy
```

**Step 3d: Add GitHub Secret**

1. Go to your GitHub repository
2. Navigate to Settings > Secrets and variables > Actions
3. Click "New repository secret"
4. Name: `AWS_ROLE_ARN`
5. Value: `arn:aws:iam::<YOUR-ACCOUNT-ID>:role/github-actions-ecr-role`

#### Deploy EKS Infrastructure:
```bash
# Navigate to EKS Terraform directory
cd k8s/tf

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy everything (takes ~15-20 minutes)
terraform apply

# Update kubeconfig to access the cluster
aws eks update-kubeconfig --region eu-north-1 --name <cluster-name>

# Verify the deployment
kubectl get pods -A
kubectl get svc -A
kubectl get ingress -A

# Get the application URL
kubectl get ingress nginx-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Get ArgoCD URL (port 8080)
kubectl get ingress argocd-ingress -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

**What Terraform Deploys:**
- Complete VPC with public/private subnets across multiple AZs
- EKS cluster with SPOT instance node groups
- AWS Load Balancer Controller
- ArgoCD configured for GitOps
- Nginx application deployed via Helm
- Ingress resources for both Nginx and ArgoCD

#### Testing the CI/CD Pipeline:

1. Edit `nginx/index.html` and change the text from "Test Environment" to "Environment2"
2. Commit and push to main branch:
```bash
   git add nginx/index.html
   git commit -m "Update environment text"
   git push origin main
```
3. GitHub Actions will automatically:
   - Build new Docker image with tag `build-<number>`
   - Push to ECR
   - Update `k8s/helm/values.yaml` with new tag
   - Commit changes back to repo
4. ArgoCD detects the change and deploys automatically
5. Access the ALB URL to see the updated text

**Expected Result:** The web page should now display "Environment2" instead of "Test Environment"

#### Architecture Notes:

**Why CI and CD Are Combined:**
For this demo, CI and CD are in one pipeline to show the complete flow. In production, I would separate them for better control.

**Branch Strategy:**
This demo uses only `main` branch for simplicity. In production, I would use:
```
feature/update-page → dev → staging → main
```
With separate environments and approval gates between each stage.

**ArgoCD for GitOps:**
ArgoCD continuously monitors the Git repository and automatically syncs changes to the cluster. This provides:
- Git as single source of truth
- Automatic deployment of changes
- Easy rollback via Git revert
- Drift detection and self-healing

**ArgoCD Access:**
In this demo, ArgoCD is exposed on the same ALB as the application (port 8080) to reduce costs. In production, I would place ArgoCD behind an internal ALB accessible only via VPN or bastion host for security.

---

### Task 5: Terraform Infrastructure

This task demonstrates an alternative EC2-based deployment approach with proper networking and security.

#### What's Included:

**Infrastructure Components:**
- **VPC**: Public and private subnets across availability zones
- **EC2 Instance**: In private subnet running Docker with Nginx
- **Application Load Balancer**: In public subnet for external access
- **VPC Endpoints**: For private ECR access without internet
  - ECR API endpoint
  - ECR DKR endpoint
  - S3 Gateway endpoint
- **NAT Instance**: For outbound connectivity from private subnet
- **Security Groups**: Least-privilege access rules
- **IAM Roles**: EC2 can pull from ECR without credentials

#### Deploy:
```bash
# Navigate to EC2 Terraform directory
cd tf

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy the infrastructure
terraform apply

# Get the ALB DNS name
terraform output alb_dns_name

# Access the application
curl http://<alb-dns-name>
```

**What Happens During Deployment:**

1. Terraform creates VPC with public/private subnets
2. Creates NAT instance for private subnet internet access
3. Creates VPC endpoints for private ECR communication
4. Launches EC2 instance in private subnet
5. EC2 user data script:
   - Installs Docker
   - Authenticates with ECR
   - Pulls Nginx image from ECR
   - Runs container on port 80
6. Creates ALB in public subnet
7. Configures health checks on `/healthz` endpoint
8. Routes traffic from ALB to EC2

#### Security Features:

- **Private EC2**: No public IP, isolated in private subnet
- **VPC Endpoints**: ECR access without internet traversal
- **Security Groups**: 
  - ALB accepts HTTP from anywhere
  - EC2 only accepts traffic from ALB
  - VPC endpoints only accept traffic from EC2
- **Encrypted Storage**: EBS volumes encrypted at rest
- **IAM Roles**: No hardcoded credentials

#### Cost Optimization Notes:

**NAT Instance vs NAT Gateway:**
- I used NAT instance ($3-5/month) instead of NAT Gateway ($32+/month)
- This is for demonstration/cost savings
- **Production**: Always use NAT Gateway for reliability and performance

**VPC Endpoints:**
- Avoid NAT Gateway data transfer charges
- Faster and more secure ECR access
- Free for interface endpoints (pay per GB transferred)
- S3 Gateway endpoint is completely free

---

### Task 6: Bash Scripts

These scripts automate common Docker operations for local development and testing.

#### build_and_run.sh

Automates building and running the Docker container locally.

**Features:**
- Builds Docker image from Dockerfile
- Stops and removes existing container if running
- Starts new container with specified port
- Validates exit codes
- Provides clear logging
- Shows URL to access application

**Usage:**
```bash
cd bash

# Use defaults (image: nginx, port: 80)
./build_and_run.sh

# Custom image name and port
./build_and_run.sh nginx 80
```

**Example Output:**
```
[INFO] Building Docker image: nginx (Dockerfile must be in this folder)
[INFO] Stopping existing container (if running)...
[INFO] Starting new container on port 80
[SUCCESS] Container is running.
[INFO] Open this in your browser: http://localhost:80
```

**How It Works:**
1. Accepts image name and port as parameters (with defaults)
2. Builds Docker image using `docker build`
3. Checks for existing container with same name
4. Removes old container if exists
5. Runs new container with `-d` (detached) and port mapping
6. Checks exit code and reports success/failure

---

#### check_health.sh

Polls a health check endpoint until it returns HTTP 200 or times out.

**Features:**
- Configurable URL and timeout
- Distinguishes between network errors and HTTP errors
- Retries with configurable interval
- Returns proper exit codes (0 for success, 1 for failure)
- Useful for CI/CD pipelines and scripts

**Usage:**
```bash
cd bash

# Check with default 20s timeout
./check_health.sh http://localhost/healthz

# Custom timeout (60 seconds)
./check_health.sh http://localhost/healthz 60

# For custom port
./check_health.sh http://localhost:80/healthz 30
```

**Example Output:**
```
[INFO] Checking health for: http://localhost/healthz
[INFO] Timeout: 20s, Interval: 2s
[WARN] Service not healthy yet (HTTP 000). Retrying...
[SUCCESS] Service is healthy (HTTP 200).
```

**How It Works:**
1. Validates URL parameter is provided
2. Loops until timeout is reached
3. Uses `curl` to check endpoint (silent mode)
4. Captures HTTP status code
5. Checks both curl exit code and HTTP status
6. Handles two failure modes:
   - Network/connection errors (curl fails)
   - HTTP errors (curl succeeds but status ≠ 200)
7. Returns exit code 0 if healthy, 1 if timeout

---

## Architecture Decisions

### Security

- **Non-root containers**: All containers run as unprivileged users
- **Private subnets**: Application servers have no direct internet access
- **OIDC authentication**: No long-lived AWS credentials in GitHub
- **Encryption**: EBS volumes and S3 state encrypted at rest
- **Security groups**: Least-privilege access, no 0.0.0.0/0 to apps
- **VPC endpoints**: Private ECR access without internet traversal

### Cost Optimization

**SPOT Instances:**
I used SPOT instances for the EKS node groups to reduce costs by approximately 70% compared to On-Demand instances. However, this is purely for demonstration purposes.

**Production consideration**: The decision to use SPOT instances depends heavily on the service type:
- **Not recommended for**: Critical services requiring guaranteed uptime, stateful applications, databases
- **Suitable for**: Batch processing, CI/CD runners, fault-tolerant distributed systems
- **Best practice**: Use a mix of On-Demand and SPOT instances with pod disruption budgets

For production workloads requiring zero downtime, I would always use On-Demand or Reserved Instances.

**NAT Instance vs NAT Gateway:**
I implemented a NAT instance to minimize costs for the demonstration. In production, I would always choose NAT Gateway.

**Why NAT Gateway for production:**
- High availability with automatic failover
- Handles up to 45 Gbps without manual intervention
- AWS manages patches and updates
- Better performance for production traffic

**Why NAT instance here:**
- Cost savings: $3-5/month vs $32+/month
- Demonstration purposes without ongoing AWS charges

**Other optimizations:**
- VPC endpoints avoid NAT Gateway data transfer charges
- Alpine images reduce storage and transfer costs
- Resource limits prevent waste in Kubernetes

### Reliability

- **Health probes**: Liveness and readiness checks ensure availability
- **Multiple replicas**: 2 pods for high availability
- **GitOps with ArgoCD**: Declarative deployments with self-healing
- **ALB health checks**: Load balancer only sends traffic to healthy targets
- **Multi-AZ**: Resources spread across availability zones

### Best Practices

- **Infrastructure as Code**: All infrastructure in Terraform
- **Modular Terraform**: Reusable modules for different environments
- **Helm charts**: Templated Kubernetes manifests
- **Semantic versioning**: Image tags include build numbers
- **Automated deployments**: CI/CD pipeline for consistency
- **State management**: Terraform state in S3 with encryption

## Production vs Demo Trade-offs

This project makes several trade-offs for demonstration and cost purposes that would be handled differently in production:

| Component | Demo Approach | Production Approach |
|-----------|--------------|---------------------|
| **Compute** | SPOT instances | On-Demand or Reserved Instances |
| **NAT** | NAT Instance | NAT Gateway (managed) |
| **ArgoCD Access** | Same ALB as app (port 8080) | Internal ALB, VPN/bastion access |
| **Branching** | Single `main` branch | feature → dev → staging → main |
| **CI/CD** | Combined pipeline | Separate CI and CD pipelines |
| **Environments** | Single environment | dev, staging, production clusters |
| **High Availability** | 2 replicas, single NAT | 3+ replicas, NAT per AZ |
| **Monitoring** | Basic health checks | Full observability stack |

## Troubleshooting

### Docker build fails
```bash
# Check Docker is running
docker info

# Check Dockerfile syntax
docker build --no-cache -t test .
```

### Health check fails
```bash
# Check if container is running
docker ps

# Check container logs
docker logs <container-name>

# Test health endpoint manually
curl -v http://localhost/healthz
```

### Kubernetes pod not starting
```bash
# Check pod status
kubectl get pods
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

### Cannot pull from ECR
```bash
# Verify ECR repository exists
aws ecr describe-repositories --region eu-north-1

# Test ECR login
aws ecr get-login-password --region eu-north-1 | \
  docker login --username AWS --password-stdin <account>.dkr.ecr.eu-north-1.amazonaws.com

# Check IAM permissions
aws sts get-caller-identity
```

### ArgoCD not syncing
```bash
# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Check application status
kubectl get applications -n argocd

# Manually sync
kubectl patch application nginx-app -n argocd -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}' --type=merge
```

![Architecture](image.png)