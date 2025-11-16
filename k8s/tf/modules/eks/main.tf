data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.cluster_name
  cluster_version = "1.31"

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnets

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  enable_irsa                              = true
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns            = { most_recent = true }
    kube-proxy         = { most_recent = true }
    vpc-cni            = { most_recent = true }
    # aws-ebs-csi-driver = { most_recent = true }
  }

  eks_managed_node_groups = {
    spot_nodes = {
      desired_size = 2
      min_size     = 1
      max_size     = 5

      instance_types = ["t3.medium"]
      capacity_type  = "SPOT"

      force_update_version = true

      labels = {
        role = "spot"
      }

      tags = {
        Name = "spot-nodes"
      }
    }
  }

  tags = {
    Environment = "test"
    Terraform   = "true"
  }
}