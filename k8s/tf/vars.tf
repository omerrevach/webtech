variable "name" {
  description = "Name prefix for all resources"
  type        = string
  default = "webtech"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "git_repo_url" {
  description = "Git repository URL for ArgoCD to sync from"
  type        = string
  default     = "https://github.com/omerrevach/webtech.git"
}