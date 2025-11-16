output "app_instance_id" {
  value = aws_instance.nginx_app.id
}

output "app_security_group_id" {
  value = aws_security_group.app_sg.id
}
