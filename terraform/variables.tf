variable "aws_region" {
  description = "AWS region for GeoPipeline"
  type        = string
  default     = "us-east-1"
}

variable "rdp_allowed_cidr" {
  description = "IP range allowed to access the Windows workspace via RDP"
  type        = string
}

