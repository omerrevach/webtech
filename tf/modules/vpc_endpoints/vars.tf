variable "name" {
  description = "Name prefix"
  type        = string
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs"
}

variable "private_route_table_id" {
  type        = string
  description = "Private route table ID"
}

variable "app_sg_id" {
  type        = string
  description = "Security group ID of the app EC2"
}
