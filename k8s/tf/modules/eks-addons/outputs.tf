output "aws_load_balancer_controller" {
  description = "Map of attributes of the AWS Load Balancer Controller"
  value       = module.eks_blueprints_addons.aws_load_balancer_controller
}

output "gitops_metadata" {
  description = "GitOps Bridge metadata"
  value       = module.eks_blueprints_addons.gitops_metadata
}