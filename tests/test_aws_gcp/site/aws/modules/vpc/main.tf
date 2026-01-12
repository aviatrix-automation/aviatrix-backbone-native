# VPC Module: Creates an AWS VPC with VMs using vendor modules
#
# This module creates:
# - VPC with public and private subnets (via vendor/aws_vpc)
# - VMs (via vendor/mc-vm/aws)
#
# Aviatrix spoke gateway is created in backbone/ to connect this VPC

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# -----------------------------------------------------------------------------
# VPC using vendor/aws_vpc module
# -----------------------------------------------------------------------------
module "vpc" {
  source = "../../../../../vendor/aws_vpc"

  vpc_name            = "${var.name_prefix}-aws-${var.site_name}"
  vpc_cidr            = var.cidr
  subnet_size         = 24
  number_subnet_pairs = 1
}

# -----------------------------------------------------------------------------
# VMs using vendor/mc-vm-csp/aws module (supports Gatus health monitoring)
# -----------------------------------------------------------------------------
module "vm" {
  source = "../../../../../vendor/mc-vm-csp/aws"

  resource_name_label  = "${var.name_prefix}-aws-${var.site_name}"
  region               = var.region
  vpc_id               = module.vpc.vpc.vpc_id
  public_subnet_id     = module.vpc.vpc.public_subnet_ids[0]
  private_subnet_id    = module.vpc.vpc.private_subnet_ids[0]
  ingress_cidrs        = ["0.0.0.0/0"]
  use_existing_keypair = true
  public_key           = var.ssh_public_key
  deploy_private_vm    = true
  instance_size        = "t3.micro"

  # Gatus health monitoring
  enable_gatus  = var.enable_gatus
  gatus_config   = var.gatus_config
  gatus_password = var.gatus_password

  tags = {
    Environment = "e2e-test"
    Site        = var.site_name
  }
}
