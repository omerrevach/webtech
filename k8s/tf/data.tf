data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "kubernetes_secret_v1" "argocd_admin_password" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = "argocd"
  }

  depends_on = [time_sleep.wait_for_alb_controller]
}

# Output Ingress URL
data "kubernetes_ingress_v1" "nginx" {
  metadata {
    name      = "nginx-ingress"
    namespace = "default"
  }

  depends_on = [helm_release.nginx_app]
}