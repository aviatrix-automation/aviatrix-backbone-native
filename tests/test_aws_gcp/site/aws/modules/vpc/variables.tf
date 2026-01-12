# Required variables
variable "site_name" {
  description = "Name of this site (e.g., 'site-1', 'site-2')"
  type        = string
}

variable "region" {
  description = "AWS region for this VPC"
  type        = string
}

variable "cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

# -----------------------------------------------------------------------------
# Gatus Health Monitoring
# -----------------------------------------------------------------------------
variable "enable_gatus" {
  description = "Install Gatus health monitoring on public VM"
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
