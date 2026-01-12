# Backbone: AWS Transit + GCP Transit + Peering + Spoke Gateways
#
# Topology:
# site-aws-site-1 ---\
#                     \
#                      bb-aws-avx-transit <=== Peering ===> bb-gcp-avx-transit --- site-gcp-spoke
#                     /
# site-aws-site-2 ---/
#
# This creates the backbone infrastructure:
# - AWS Aviatrix Transit (with connected_transit enabled)
# - GCP Aviatrix Transit (with connected_transit enabled)
# - Transit Peering between AWS and GCP
# - AWS Spoke Gateways in site VPCs (from site/aws state)
# - GCP Spoke Gateway in VM VPC (from site/gcp state)
#
# Deployment order: site -> backbone

# -----------------------------------------------------------------------------
# Data Sources - Reference combined site state for VPC info
# -----------------------------------------------------------------------------
data "terraform_remote_state" "site" {
  backend = "local"
  config = {
    path = "${path.module}/../site/terraform.tfstate"
  }
}

locals {
  # AWS site VPCs from site module
  aws_site_vpcs = try(data.terraform_remote_state.site.outputs.aws_all_site_vpcs, {})

  # GCP VPC info from site module
  gcp_vpc_info = try(data.terraform_remote_state.site.outputs.gcp_vpc_info, null)
}

# -----------------------------------------------------------------------------
# AWS Transit Gateway (Aviatrix)
# -----------------------------------------------------------------------------
module "aws_transit" {
  source  = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version = "8.0.0"
  cloud   = "aws"
  name    = "${var.name_prefix}-aws-avx-transit"
  account = var.aviatrix_aws_access_account
  region  = var.aws_region
  cidr    = var.aws_transit_cidr
  ha_gw   = var.ha_gw

  local_as_number   = var.aws_transit_asn
  connected_transit = true
}

# -----------------------------------------------------------------------------
# GCP Transit Gateway (Aviatrix)
# -----------------------------------------------------------------------------
module "gcp_transit" {
  source  = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version = "8.0.0"
  cloud   = "gcp"
  name    = "${var.name_prefix}-gcp-avx-transit"
  account = var.aviatrix_gcp_access_account
  region  = var.gcp_region
  cidr    = var.gcp_transit_cidr
  ha_gw   = var.ha_gw

  local_as_number   = var.gcp_transit_asn
  connected_transit = true
}

# -----------------------------------------------------------------------------
# Transit Peering: AWS <-> GCP
# -----------------------------------------------------------------------------
module "transit_peering" {
  source  = "terraform-aviatrix-modules/mc-transit-peering/aviatrix"
  version = "1.0.9"

  transit_gateways = [
    module.aws_transit.transit_gateway.gw_name,
    module.gcp_transit.transit_gateway.gw_name,
  ]
}

# -----------------------------------------------------------------------------
# AWS Spoke Gateways - One per site VPC (from site/aws)
# -----------------------------------------------------------------------------
module "aws_spoke" {
  source   = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version  = "8.0.0"
  for_each = local.aws_site_vpcs

  cloud   = "aws"
  name    = "${var.name_prefix}-aws-${each.key}-spoke"
  account = var.aviatrix_aws_access_account
  region  = each.value.region
  ha_gw   = var.ha_gw

  # Use existing VPC created by site/aws
  use_existing_vpc = true
  vpc_id           = each.value.vpc_id
  gw_subnet        = each.value.gw_subnet
  hagw_subnet      = var.ha_gw ? each.value.gw_subnet : null

  # Attach to AWS Transit
  transit_gw = module.aws_transit.transit_gateway.gw_name
  attached   = true
}

# -----------------------------------------------------------------------------
# GCP Spoke Gateway in existing VM VPC (from site/gcp)
# -----------------------------------------------------------------------------
module "gcp_spoke" {
  count   = local.gcp_vpc_info != null ? 1 : 0
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version = "8.0.0"

  cloud   = "gcp"
  name    = "${var.name_prefix}-gcp-spoke"
  account = var.aviatrix_gcp_access_account
  region  = local.gcp_vpc_info.region
  ha_gw   = var.ha_gw

  # Use existing VPC created by site/gcp
  use_existing_vpc = true
  vpc_id           = local.gcp_vpc_info.vpc_name
  gw_subnet        = local.gcp_vpc_info.subnet_cidr
  hagw_subnet      = var.ha_gw ? local.gcp_vpc_info.subnet_cidr : null

  # Attach to GCP Transit
  transit_gw = module.gcp_transit.transit_gateway.gw_name
  attached   = true
}
