# Site AWS: AWS VPCs with VMs
#
# This creates N VPCs with VMs using for_each.
# Each VPC includes:
# - VPC with public and private subnets
# - Internet Gateway and route tables
# - Test VMs (public bastion + private)
#
# Aviatrix spoke gateways are created in backbone/ to connect these VPCs.

# -----------------------------------------------------------------------------
# Locals - Combine VPC outputs for backbone to read
# -----------------------------------------------------------------------------
locals {
  # Combine all VPC outputs for spoke gateway creation by backbone
  all_site_vpcs = merge(
    { for k, v in module.vpc_us_west_2 : k => {
      vpc_id    = v.vpc_id
      vpc_cidr  = v.vpc_cidr
      region    = v.region
      gw_subnet = v.public_subnet_cidr
    } },
    { for k, v in module.vpc_us_east_1 : k => {
      vpc_id    = v.vpc_id
      vpc_cidr  = v.vpc_cidr
      region    = v.region
      gw_subnet = v.public_subnet_cidr
    } },
    { for k, v in module.vpc_eu_west_1 : k => {
      vpc_id    = v.vpc_id
      vpc_cidr  = v.vpc_cidr
      region    = v.region
      gw_subnet = v.public_subnet_cidr
    } },
    { for k, v in module.vpc_ap_southeast_1 : k => {
      vpc_id    = v.vpc_id
      vpc_cidr  = v.vpc_cidr
      region    = v.region
      gw_subnet = v.public_subnet_cidr
    } },
  )
}

# -----------------------------------------------------------------------------
# SSH Key (shared across all VPCs)
# -----------------------------------------------------------------------------
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  filename        = "${path.module}/ssh_key.pem"
  content         = tls_private_key.ssh_key.private_key_pem
  file_permission = "0600"
}

# -----------------------------------------------------------------------------
# VPC Modules - one per site configuration
# Due to Terraform provider limitations, we create separate module calls per region
# -----------------------------------------------------------------------------

# us-west-2 sites
module "vpc_us_west_2" {
  source   = "./modules/vpc"
  for_each = { for k, v in var.sites : k => v if v.region == "us-west-2" }

  providers = {
    aws = aws.us-west-2
  }

  site_name      = each.key
  region         = each.value.region
  cidr           = each.value.cidr
  ssh_public_key = tls_private_key.ssh_key.public_key_openssh
  name_prefix    = var.name_prefix

  # Gatus health monitoring
  enable_gatus  = var.enable_gatus
  gatus_config   = var.gatus_config
  gatus_password = var.gatus_password
}

# us-east-1 sites
module "vpc_us_east_1" {
  source   = "./modules/vpc"
  for_each = { for k, v in var.sites : k => v if v.region == "us-east-1" }

  providers = {
    aws = aws.us-east-1
  }

  site_name      = each.key
  region         = each.value.region
  cidr           = each.value.cidr
  ssh_public_key = tls_private_key.ssh_key.public_key_openssh
  name_prefix    = var.name_prefix

  # Gatus health monitoring
  enable_gatus  = var.enable_gatus
  gatus_config   = var.gatus_config
  gatus_password = var.gatus_password
}

# eu-west-1 sites
module "vpc_eu_west_1" {
  source   = "./modules/vpc"
  for_each = { for k, v in var.sites : k => v if v.region == "eu-west-1" }

  providers = {
    aws = aws.eu-west-1
  }

  site_name      = each.key
  region         = each.value.region
  cidr           = each.value.cidr
  ssh_public_key = tls_private_key.ssh_key.public_key_openssh
  name_prefix    = var.name_prefix

  # Gatus health monitoring
  enable_gatus  = var.enable_gatus
  gatus_config   = var.gatus_config
  gatus_password = var.gatus_password
}

# ap-southeast-1 sites
module "vpc_ap_southeast_1" {
  source   = "./modules/vpc"
  for_each = { for k, v in var.sites : k => v if v.region == "ap-southeast-1" }

  providers = {
    aws = aws.ap-southeast-1
  }

  site_name      = each.key
  region         = each.value.region
  cidr           = each.value.cidr
  ssh_public_key = tls_private_key.ssh_key.public_key_openssh
  name_prefix    = var.name_prefix

  # Gatus health monitoring
  enable_gatus  = var.enable_gatus
  gatus_config   = var.gatus_config
  gatus_password = var.gatus_password
}
