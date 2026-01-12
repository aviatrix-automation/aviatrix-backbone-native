# Site: Combined AWS + GCP deployment
#
# This parent module deploys both AWS and GCP sites in a single terraform apply.
# - aws/: Creates N AWS VPCs + VMs
# - gcp/: Creates GCP VPC + VMs
#
# Backbone then reads from this single state file to create spoke gateways.

# -----------------------------------------------------------------------------
# AWS Sites Module
# -----------------------------------------------------------------------------
module "aws" {
  source = "./aws"

  providers = {
    aws.us-west-2      = aws.us-west-2
    aws.us-east-1      = aws.us-east-1
    aws.eu-west-1      = aws.eu-west-1
    aws.ap-southeast-1 = aws.ap-southeast-1
  }

  aws_access_key = var.aws_access_key
  aws_secret_key = var.aws_secret_key
  sites          = var.sites
  name_prefix    = var.name_prefix

  # Gatus health monitoring
  enable_gatus  = var.enable_gatus
  gatus_config   = var.gatus_config
  gatus_password = var.gatus_password
}

# -----------------------------------------------------------------------------
# GCP Site Module
# -----------------------------------------------------------------------------
module "gcp" {
  source = "./gcp"

  gcp_project_name             = var.gcp_project_name
  gcp_region                   = var.gcp_region
  gcp_credential_file_location = var.gcp_credential_file_location
  gcp_vm_cidr                  = var.gcp_vm_cidr
  name_prefix                  = var.name_prefix

  # Gatus health monitoring
  enable_gatus  = var.enable_gatus
  gatus_config   = var.gatus_config
  gatus_password = var.gatus_password
}
