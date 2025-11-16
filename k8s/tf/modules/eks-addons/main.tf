module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.15.1"

  cluster_name      = var.cluster_name
  cluster_endpoint  = var.cluster_endpoint
  cluster_version   = var.cluster_version
  oidc_provider_arn = var.oidc_provider_arn

  enable_aws_load_balancer_controller = true
  enable_argocd = true  # ← Add this

  aws_load_balancer_controller = {
    set = [
      {
        name  = "vpcId"
        value = var.vpc_id
      }
    ]
  }

  # ArgoCD configuration
  argocd = {
    namespace = "argocd"
    values = [
      <<-EOT
      server:
        service:
          type: ClusterIP
        extraArgs:
          - --insecure  # Allow HTTP (ALB handles HTTPS if needed)
      EOT
    ]
  }

  tags = var.tags
}