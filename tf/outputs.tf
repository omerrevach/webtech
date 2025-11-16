output "alb_dns_name" {
  description = "URL of the Nginx test environment via ALB"
  value       = module.alb.alb_dns_name
}
