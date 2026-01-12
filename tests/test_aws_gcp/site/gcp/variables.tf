# GCP Configuration
variable "gcp_project_name" {
  description = "GCP project name/ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region for deployment"
  type        = string
  default     = "us-west1"
}

variable "gcp_credential_file_location" {
  description = "Path to GCP service account credentials JSON file"
  type        = string
}

# Network CIDR Configuration
variable "gcp_vm_cidr" {
  description = "CIDR for GCP VM VPC (VMs deployed here)"
  type        = string
  default     = "10.22.0.0/24"
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
