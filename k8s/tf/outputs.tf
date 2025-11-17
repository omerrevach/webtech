output "nginx_url" {
  description = "URL to access the Nginx application (port 80)"
  value       = try("http://${data.kubernetes_ingress_v1.nginx.status[0].load_balancer[0].ingress[0].hostname}", "ALB is being provisioned...")
}

output "argocd_url" {
  description = "URL to access ArgoCD UI (port 8080)"
  value       = try("http://${data.kubernetes_ingress_v1.nginx.status[0].load_balancer[0].ingress[0].hostname}:8080", "ALB is being provisioned...")
}

output "argocd_admin_password" {
  description = "ArgoCD admin password (username: admin)"
  value       = try(data.kubernetes_secret_v1.argocd_admin_password.data["password"], "ArgoCD not ready yet")
  sensitive   = true
}

output "git_repo" {
  description = "Git repository configured for ArgoCD"
  value       = var.git_repo_url
}