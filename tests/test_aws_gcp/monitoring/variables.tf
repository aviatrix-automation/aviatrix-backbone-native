# -----------------------------------------------------------------------------
# Monitoring Configuration Variables
# -----------------------------------------------------------------------------

variable "dashboard_site" {
  description = "Site name to use as main Gatus dashboard (e.g., 'site-1')"
  type        = string
  default     = "site-1"
}

variable "ssh_username" {
  description = "SSH username for VMs"
  type        = string
  default     = "ubuntu"
}

variable "gatus_port" {
  description = "Gatus HTTP port"
  type        = number
  default     = 8080
}
