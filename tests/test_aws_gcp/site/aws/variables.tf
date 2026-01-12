# AWS Configuration
variable "aws_access_key" {
  description = "AWS access key"
  type        = string
}

variable "aws_secret_key" {
  description = "AWS secret key"
  type        = string
  sensitive   = true
}

# Site Configuration
variable "sites" {
  description = "Map of site configurations"
  type = map(object({
    region = string
    cidr   = string
  }))
  default = {
    "site-1" = {
      region = "us-west-2"
      cidr   = "10.11.0.0/16"
    }
    "site-2" = {
      region = "us-west-2"
      cidr   = "10.12.0.0/16"
    }
  }
}

# Resource naming
variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "site"
}

# -----------------------------------------------------------------------------
# Gatus Health Monitoring
# -----------------------------------------------------------------------------
variable "enable_gatus" {
  description = "Install Gatus health monitoring on public VMs"
  type        = bool
  default     = false
}

variable "gatus_config" {
  description = "Gatus configuration YAML content (see https://github.com/TwiN/gatus)"
  type        = string
  default     = ""
}

variable "gatus_password" {
  description = "Password for Gatus basic authentication"
  type        = string
  default     = ""
  sensitive   = true
}
