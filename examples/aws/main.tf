# ============================================================================
# AWS Transit Module - Example Consumption
# ============================================================================
# This example shows how to consume the AWS transit module from a versioned
# Git source. Copy this file to your own Terraform root and customize.
#
# Usage:
#   terraform init
#   terraform plan -var-file=aws.tfvars
#   terraform apply -var-file=aws.tfvars
# ============================================================================

module "aws_transit" {
  source = "git::https://github.com/aviatrix-automation/aviatrix-backbone-native.git//modules/control/aws?ref=v0.8.0"

  aws_ssm_region   = var.aws_ssm_region
  region           = var.region
  tags             = var.tags
  transits         = var.transits
  tgws             = var.tgws
  external_devices = var.external_devices
  spokes           = var.spokes
}

# Re-export outputs
output "mgmt_subnet_ids" {
  description = "Map of transit key to management subnet ID."
  value       = module.aws_transit.mgmt_subnet_ids
}
