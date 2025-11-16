variable "name" {
  description = "Name prefix for VPC resources"
  type        = string
}

variable "cidr_block" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_cidrs" {
  description = "List of public subnet CIDRs"
  type        = list(string)
}

variable "private_cidrs" {
  description = "List of private subnet CIDRs"
  type        = list(string)
}

variable "instance_type" {
  description = "Instance type for NAT instance"
  type        = string
  default     = "t3.micro"
}
