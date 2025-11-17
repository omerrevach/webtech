locals {
  addon_timeouts = {
    after_eks = "20s"
  }
}

module "vpc" {
  source = "./modules/vpc"

  name          = var.name
  cidr_block    = "10.0.0.0/16"
  public_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
}

module "eks" {
  source = "./modules/eks"

  cluster_name    = "${var.name}-cluster"
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
  region          = var.region

  depends_on = [module.vpc]
}

# Wait after EKS is created
resource "time_sleep" "after_eks" {
  depends_on      = [module.eks]
  create_duration = local.addon_timeouts["after_eks"]
}

module "eks_addons" {
  source = "./modules/eks-addons"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn
  vpc_id            = module.vpc.vpc_id

  tags = {
    Environment = "test"
    Terraform   = "true"
  }

  depends_on = [time_sleep.after_eks]
}

# Wait for ALB Controller webhook to be ready
resource "time_sleep" "wait_for_alb_controller" {
  depends_on      = [module.eks_addons]
  create_duration = "120s"
}

# Deploy Nginx using Helm
resource "helm_release" "nginx_app" {
  name       = "nginx-app"
  chart      = "./helm"
  namespace  = "default"

  set {
    name  = "image.repository"
    value = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/nginx"
  }

  set {
    name  = "image.tag"
    value = "latest"
  }

  depends_on = [time_sleep.wait_for_alb_controller]
}

resource "kubectl_manifest" "argocd_ingress" {
  yaml_body = <<-YAML
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: argocd-ingress
      namespace: argocd
      annotations:
        alb.ingress.kubernetes.io/scheme: internet-facing
        alb.ingress.kubernetes.io/target-type: ip
        alb.ingress.kubernetes.io/group.name: nginx-group
        alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 8080}]'
        alb.ingress.kubernetes.io/backend-protocol: HTTP
        alb.ingress.kubernetes.io/healthcheck-path: /
        alb.ingress.kubernetes.io/healthcheck-port: "8080"
        alb.ingress.kubernetes.io/success-codes: "200,301,302"
    spec:
      ingressClassName: alb
      rules:
      - http:
          paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argo-cd-argocd-server  # ← Changed from argocd-server
                port:
                  number: 80
  YAML

  depends_on = [time_sleep.wait_for_alb_controller]
}

resource "kubectl_manifest" "argocd_nginx_app" {
  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: nginx-app
      namespace: argocd
    spec:
      project: default
      source:
        repoURL: ${var.git_repo_url}
        targetRevision: HEAD
        path: k8s/helm
      destination:
        server: https://kubernetes.default.svc
        namespace: default
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
  YAML

  depends_on = [time_sleep.wait_for_alb_controller]
}
