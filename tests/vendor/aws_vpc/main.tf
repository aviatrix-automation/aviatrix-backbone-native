terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# Data source to fetch availability zones for the specified region
data "aws_availability_zones" "available" {
  state = "available"
}

# Parse prefix lengths and calculate additional bits for subnetting
locals {
  primary_prefix_len        = tonumber(split("/", var.vpc_cidr)[1])
  secondary_prefix_len      = var.secondary_vpc_cidr != "" ? tonumber(split("/", var.secondary_vpc_cidr)[1]) : 0
  primary_additional_bits   = var.subnet_size - local.primary_prefix_len
  secondary_additional_bits = local.secondary_prefix_len > 0 ? var.subnet_size - local.secondary_prefix_len : 0
  # Generate the list of /28 subnets
  vpc_pri_subnets           = [for i in range(var.number_subnet_pairs, (var.number_subnet_pairs * 2 - var.number_subnet_secondary)) : cidrsubnet(var.vpc_cidr, local.primary_additional_bits, i)]
  vpc_pub_subnets           = [for i in range(var.number_subnet_pairs) : cidrsubnet(var.vpc_cidr, local.primary_additional_bits, i)]
  vpc_pri_subnets_secondary = var.secondary_vpc_cidr != "" ? [for i in range(var.number_subnet_secondary) : cidrsubnet(var.secondary_vpc_cidr, local.secondary_additional_bits, i)] : []


  # Calculate the list of AZs to match the number of subnets
  azs             = data.aws_availability_zones.available.names
  azs_for_subnets = [for i in range(var.number_subnet_pairs) : local.azs[i % length(local.azs)]]
}

module "vpc" {
  source                = "terraform-aws-modules/vpc/aws"
  name                  = var.vpc_name
  cidr                  = var.vpc_cidr
  azs                   = local.azs_for_subnets
  public_subnets        = local.vpc_pub_subnets
  private_subnets       = concat(local.vpc_pri_subnets, local.vpc_pri_subnets_secondary)
  secondary_cidr_blocks = var.secondary_vpc_cidr != "" ? [var.secondary_vpc_cidr] : []
  enable_nat_gateway    = false
  enable_vpn_gateway    = false
}

# Data sources to fetch subnet details
data "aws_subnet" "private_subnets" {
  count = length(module.vpc.private_subnets)
  id    = module.vpc.private_subnets[count.index]
}

data "aws_subnet" "public_subnets" {
  count = length(module.vpc.public_subnets)
  id    = module.vpc.public_subnets[count.index]
}

locals {
  private_subnet_names = [for subnet in data.aws_subnet.private_subnets : subnet.tags["Name"]]
  public_subnet_names  = [for subnet in data.aws_subnet.public_subnets : subnet.tags["Name"]]
}

# Create EIPs for testing (optional, controlled by create_eips variable)
resource "aws_eip" "vpc_eips" {
  count  = var.create_eips
  domain = "vpc"

  tags = {
    Name = "${var.vpc_name}-eip-${count.index}"
  }
}