variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "name" {
  description = "Project/name prefix"
  type        = string
  default     = "nginx-test-env"
}