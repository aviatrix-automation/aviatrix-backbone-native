# ============================================================================
# GCP Transit Module - Example Consumption
# ============================================================================
# This example shows how to consume the GCP transit module from a versioned
# Git source. Copy this file to your own Terraform root and customize.
#
# Usage:
#   terraform init
#   terraform plan -var-file=gcp.tfvars
#   terraform apply -var-file=gcp.tfvars
# ============================================================================

module "gcp_transit" {
  source = "git::https://github.com/aviatrix-automation/aviatrix-backbone-native.git//modules/control/gcp?ref=v0.8.0"

  aws_ssm_region   = var.aws_ssm_region
  project_id       = var.project_id
  transits         = var.transits
  ncc_hubs         = var.ncc_hubs
  spokes           = var.spokes
  aviatrix_spokes  = var.aviatrix_spokes
  external_devices = var.external_devices
}

# Re-export outputs
output "external_lb_ip_addresses" {
  description = "Map of transit gateway name to external Application LB public IP address."
  value       = module.gcp_transit.external_lb_ip_addresses
}
