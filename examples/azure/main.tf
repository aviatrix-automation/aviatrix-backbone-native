# ============================================================================
# Azure Transit Module - Example Consumption
# ============================================================================
# This example shows how to consume the Azure transit module from a versioned
# Git source. Copy this file to your own Terraform root and customize.
#
# Usage:
#   terraform init
#   terraform plan -var-file=azure.tfvars
#   terraform apply -var-file=azure.tfvars
# ============================================================================

module "azure_transit" {
  source = "git::https://github.com/aviatrix-automation/aviatrix-backbone-native.git//modules/control/azure?ref=v0.8.0"

  aws_ssm_region   = var.aws_ssm_region
  region           = var.region
  subscription_id  = var.subscription_id
  tags             = var.tags
  transits         = var.transits
  spokes           = var.spokes
  vwan_configs     = var.vwan_configs
  vwan_hubs        = var.vwan_hubs
  vnets            = var.vnets
  panorama_config  = var.panorama_config
  external_devices = var.external_devices
}
