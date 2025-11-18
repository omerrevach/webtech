variable "name" {
  description = "Project/name prefix for tagging"
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

variable "private_cidrs" {}

variable "instance_type" {
  description = "Instance type for NAT instance"
  type        = string
  default     = "t3.micro"
}
