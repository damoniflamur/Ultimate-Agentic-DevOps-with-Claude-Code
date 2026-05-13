variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Name of the project, used in resource names and tags"
  type        = string
  default     = "portfolio-site"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}

variable "domain_name" {
  description = "Custom domain name for the CloudFront distribution (optional). Leave empty when using the default CloudFront certificate."
  type        = string
  default     = ""

  validation {
    condition = (
      var.domain_name == "" ||
      can(regex("^([a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?\\.)+[a-zA-Z]{2,}$", var.domain_name))
    )
    error_message = "domain_name must be an empty string or a valid fully-qualified domain name (e.g. example.com)."
  }
}
