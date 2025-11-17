# Nginx DevOps Project

This project demonstrates a complete DevOps pipeline for deploying an Nginx web server using Docker, Kubernetes, Terraform, and CI/CD automation.

## Table of Contents

- [Project Overview](#project-overview)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
  - [1. AWS Setup](#1-aws-setup)
  - [2. Docker Setup](#2-docker-setup)
  - [3. Kubernetes Deployment](#3-kubernetes-deployment)
  - [4. CI/CD Pipeline](#4-cicd-pipeline)
  - [5. Terraform Infrastructure](#5-terraform-infrastructure)
- [Bash Scripts](#bash-scripts)
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

## Quick Start

### Local Testing
```bash
# Build and run the Docker container (uses port 80 by default)
cd bash
./build_and_run.sh

# Or specify custom image name and port
./build_and_run.sh nginx 8080

# Check if the service is healthy (default port 80)
./check_health.sh http://localhost/healthz 30

# Or for custom port
./check_health.sh http://localhost:8080/healthz 30

# View the application
open http://localhost
```

### Deploy to Kubernetes (EKS)
```bash
# Navigate to EKS Terraform directory
cd k8s/tf

# Initialize and apply Terraform
terraform init
terraform plan
terraform apply

# Update kubeconfig
aws eks update-kubeconfig --region eu-north-1 --name <cluster-name>

# Verify deployment
kubectl get pods
kubectl get svc
kubectl get ingress
```

## Detailed Setup

### 1. AWS Setup

#### Create ECR Repository
```bash
# Create the ECR repository for storing Docker images
aws ecr create-repository \
  --repository-name nginx \
  --region eu-north-1

# Note the repository URI from the output
```

#### Setup GitHub OIDC Authentication

This allows GitHub Actions to authenticate with AWS without storing long-lived credentials.

**Step 1: Create OIDC Identity Provider**
```bash
# In AWS Console: IAM > Identity Providers > Add Provider
# Or use AWS CLI:
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

**Step 2: Create IAM Policy**

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

Replace `<YOUR-ACCOUNT-ID>` with your AWS account ID.
```bash
# Create the policy
aws iam create-policy \
  --policy-name github-actions-ecr-push-policy \
  --policy-document file://policy.json
```

**Step 3: Create IAM Role**

Create a role named `github-actions-ecr-role` with the following trust policy:
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

Replace:
- `<YOUR-ACCOUNT-ID>` with your AWS account ID
- `<YOUR-GITHUB-USERNAME>/<YOUR-REPO-NAME>` with your GitHub repository (e.g., `omerrevach/webtech`)
```bash
# Create the role
aws iam create-role \
  --role-name github-actions-ecr-role \
  --assume-role-policy-document file://trust-policy.json

# Attach the policy to the role
aws iam attach-role-policy \
  --role-name github-actions-ecr-role \
  --policy-arn arn:aws:iam::<YOUR-ACCOUNT-ID>:policy/github-actions-ecr-push-policy
```

**Step 4: Add GitHub Secret**

In your GitHub repository:

1. Go to Settings > Secrets and variables > Actions
2. Click "New repository secret"
3. Name: `AWS_ROLE_ARN`
4. Value: `arn:aws:iam::<YOUR-ACCOUNT-ID>:role/github-actions-ecr-role`

### 2. Docker Setup

#### Dockerfile Overview

The Dockerfile creates a secure Nginx image:

- Based on `nginx:1.27-alpine` for small image size
- Runs as non-root user (nginxuser) for security
- Uses `libcap` to allow non-root user to bind to port 80
- Copies custom nginx.conf and index.html

#### Build Locally
```bash
# Build the image
docker build -t nginx:local .

# Run the container
docker run -d -p 80:80 --name nginx-test nginx:local

# Test the endpoints
curl http://localhost           # Main page
curl http://localhost/healthz   # Health check

# Cleanup
docker stop nginx-test
docker rm nginx-test
```

### 3. Kubernetes Deployment

#### Helm Chart Structure

The Helm chart includes:

- **Deployment**: Runs 2 replicas with resource limits and health probes
- **Service**: ClusterIP service exposing port 80
- **Ingress**: AWS ALB ingress for external access
- **ArgoCD Ingress**: Separate ingress for ArgoCD UI on port 8080

#### Health Probes

Both liveness and readiness probes are configured:
```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 80
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /healthz
    port: 80
  initialDelaySeconds: 5
  periodSeconds: 5
```

#### Deploy with Helm (Manual)
```bash
# Install the chart
helm install nginx-app k8s/helm/ \
  --set image.repository=<ECR-REPO-URL> \
  --set image.tag=latest

# Upgrade the deployment
helm upgrade nginx-app k8s/helm/

# Check deployment status
kubectl get pods
kubectl get svc
kubectl get ingress

# Get ALB URL
kubectl get ingress nginx-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### 4. CI/CD Pipeline

#### Pipeline Overview

The GitHub Actions pipeline automates the entire deployment:

1. Triggers on changes to `nginx/index.html`, Dockerfile, or Helm charts
2. Authenticates with AWS using OIDC (no stored credentials)
3. Builds Docker image with unique tag based on build number
4. Pushes image to Amazon ECR
5. Updates Helm `values.yaml` with new image tag
6. Commits changes back to repository
7. ArgoCD detects the change and deploys automatically

#### Why CI and CD Are Combined Here

Normally, I would separate CI and CD into different pipelines for better control and separation of concerns. However, for this example project, they are combined to demonstrate the complete flow in a single pipeline. In production, you would typically:

- Have CI pipeline build and push images
- Have separate CD pipeline or tool (like ArgoCD) handle deployments
- Use different triggers and approval gates

#### Branch Strategy (Single Branch for Demo)

For this demonstration, I'm using only the `main` branch to keep things simple. However, in a real production environment, I would implement a proper branching strategy:

**Production Branch Strategy:**
```
feature/add-new-content  →  dev  →  staging  →  main (production)
```

**How it would work:**

1. **Feature branches**: Developer creates `feature/update-homepage` and modifies `index.html`
2. **Dev environment**: Merge to `dev` branch triggers deployment to dev cluster
3. **Staging environment**: After testing in dev, merge to `staging` branch for pre-production testing
4. **Production**: Only after staging approval, merge to `main` for production deployment

Each environment would have:
- Its own Kubernetes namespace or cluster
- Separate ArgoCD applications pointing to different branches
- Different resource allocations and configurations
- Approval gates between environments

**Why single branch here:**
This is purely for demonstration purposes to show the complete pipeline in action. The single branch approach makes it easier to understand the flow but should never be used in production where you need proper testing gates and rollback capabilities.

#### ArgoCD for GitOps

I chose ArgoCD for the CD portion because:

- **GitOps approach**: Your Git repository is the single source of truth
- **Reliability**: ArgoCD continuously monitors Git and ensures cluster state matches desired state
- **Rollback**: Easy to rollback by reverting Git commits
- **Visibility**: ArgoCD UI shows deployment status and history
- **Self-healing**: Automatically corrects drift between Git and cluster state

The pipeline updates `values.yaml`, and ArgoCD automatically syncs the changes to the cluster.

#### Testing the Pipeline

1. Edit `nginx/index.html` and change the text
2. Commit and push to main branch
3. GitHub Actions will:
   - Build new image as `build-<number>`
   - Push to ECR
   - Update values.yaml
4. ArgoCD will detect the change and deploy
5. Access the ALB URL to see updated content

### 5. Terraform Infrastructure

This project includes two Terraform setups demonstrating different deployment approaches.

#### Option 1: EKS Cluster (k8s/tf/)

Production-grade Kubernetes cluster with:

- EKS cluster with managed node groups (SPOT instances)
- VPC with public and private subnets across multiple AZs
- AWS Load Balancer Controller for ingress
- ArgoCD for GitOps deployments
- Proper IAM roles and OIDC provider
```bash
cd k8s/tf
terraform init
terraform plan
terraform apply

# Get cluster credentials
aws eks update-kubeconfig --region eu-north-1 --name <cluster-name>

# Access ArgoCD
kubectl get ingress -n argocd
```

#### Option 2: EC2 with ALB (tf/)

Traditional EC2-based deployment with:

- VPC with public and private subnets
- EC2 instance in private subnet running Docker
- Application Load Balancer in public subnet
- VPC Endpoints for private ECR access (no internet required)
- NAT instance for outbound connectivity
- Proper security groups with least-privilege access
```bash
cd tf
terraform init
terraform plan
terraform apply

# Get ALB DNS
terraform output alb_dns_name
```

**Key Features:**

- **Security**: EC2 in private subnet, no public IP
- **Cost optimization**: Uses VPC endpoints to avoid NAT Gateway costs
- **Encryption**: EBS volumes encrypted at rest
- **IAM roles**: EC2 can pull from ECR without credentials

## Bash Scripts

### build_and_run.sh

Builds and runs the Docker container locally.

**Usage:**
```bash
# Use defaults (nginx image, port 80)
./build_and_run.sh

# Custom image name and port
./build_and_run.sh my-nginx 8080
```

**Features:**

- Validates input parameters
- Stops and removes existing container if running
- Provides URL to access the application
- Clear error messages and logging

### check_health.sh

Polls a URL until it returns HTTP 200 or times out.

**Usage:**
```bash
# Check with default 20s timeout (port 80)
./check_health.sh http://localhost/healthz

# Custom timeout
./check_health.sh http://localhost/healthz 60

# For custom port
./check_health.sh http://localhost:8080/healthz 30
```

**Features:**

- Configurable timeout and interval
- Distinguishes between network errors and HTTP errors
- Returns exit code 0 for success, 1 for failure
- Useful in CI/CD pipelines to wait for service readiness

## Architecture Decisions

### Security

- **Non-root containers**: All containers run as unprivileged users
- **Private subnets**: Application servers have no direct internet access
- **OIDC authentication**: No long-lived AWS credentials in GitHub
- **Encryption**: EBS volumes and S3 state encrypted at rest
- **Security groups**: Least-privilege access, no 0.0.0.0/0 to apps
- **VPC endpoints**: Private ECR access without internet traversal

### Cost Optimization

**SPOT Instances**

I used SPOT instances for the EKS node groups to reduce costs by approximately 70% compared to On-Demand instances. However, this is purely for demonstration purposes.

**Production consideration**: In a real production environment, the decision to use SPOT instances depends heavily on the service type:
- **Not recommended for**: Critical services that require guaranteed uptime, stateful applications, databases
- **Suitable for**: Batch processing, CI/CD runners, fault-tolerant distributed systems
- **Best practice**: Use a mix of On-Demand and SPOT instances with proper pod disruption budgets

For production workloads requiring zero downtime, I would always use On-Demand or Reserved Instances.

**NAT Instance vs NAT Gateway**

I implemented a NAT instance in this project to minimize costs for the demonstration. However, in production, I would always choose NAT Gateway instead.

**Why NAT Gateway for production:**
- **High availability**: Managed service with automatic failover
- **Scalability**: Handles up to 45 Gbps without manual intervention
- **No maintenance**: AWS manages patches and updates
- **Better performance**: Optimized for production traffic

**Why I used NAT instance here:**
- **Cost savings**: NAT instance costs around $3-5/month vs NAT Gateway at $32+/month
- **Demonstration purposes**: Shows the concept without ongoing AWS charges
- **Learning opportunity**: Understanding both approaches

**Other cost optimizations:**
- **VPC endpoints**: Avoid NAT Gateway data transfer charges
- **Alpine images**: Smaller images reduce storage and transfer costs
- **Resource limits**: Prevent resource waste in Kubernetes

### Reliability

- **Health probes**: Liveness and readiness checks ensure availability
- **Multiple replicas**: 2 pods for high availability
- **GitOps with ArgoCD**: Declarative deployments with self-healing
- **ALB health checks**: Load balancer only sends traffic to healthy targets
- **Multi-AZ**: Resources spread across availability zones

### ArgoCD and ALB Placement

**Current setup (for demonstration):**
In this project, ArgoCD is exposed on the same ALB as the application (on port 8080) to simplify the setup and reduce costs.

**Production approach:**
In a production environment, I would never expose ArgoCD on the same ALB as the application. Instead:

- **Internal ALB for ArgoCD**: Deploy ArgoCD behind an internal-facing ALB accessible only from within the VPC or through VPN/bastion
- **Separate ALB for application**: Keep application traffic completely isolated
- **Additional security**: Add authentication (SSO, LDAP) and restrict access by IP/security group

**Why separate them:**
- **Security**: ArgoCD has access to deploy across your cluster and should not be publicly accessible
- **Blast radius**: Compromise of one service doesn't affect the other
- **Traffic isolation**: Application traffic spikes don't impact ArgoCD performance
- **Different access patterns**: Internal tools need different security controls than public-facing apps

The combined ALB approach here is purely to demonstrate the concepts without additional AWS costs.

### Best Practices

- **Infrastructure as Code**: All infrastructure in Terraform
- **Modular Terraform**: Reusable modules for different environments
- **Helm charts**: Templated Kubernetes manifests
- **Semantic versioning**: Image tags include build numbers
- **Automated deployments**: CI/CD pipeline for consistency
- **State management**: Terraform state in S3 with encryption

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

## License

This is a demonstration project for educational purposes.