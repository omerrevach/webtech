variable "name" {
  description = "Name prefix"
  type        = string
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs for ALB"
}

variable "app_sg_id" {
  type        = string
  description = "App EC2 security group ID"
}

variable "app_instance_id" {
  type        = string
  description = "App EC2 instance ID"
}
