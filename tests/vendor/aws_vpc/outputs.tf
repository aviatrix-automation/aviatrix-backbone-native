output "vpc" {
  value = {
    vpc_id               = module.vpc.vpc_id
    vpc_name             = var.vpc_name
    vpc_cidr             = module.vpc.vpc_cidr_block
    secondary_vpc_cidr   = var.secondary_vpc_cidr
    public_subnet_cidrs  = module.vpc.public_subnets_cidr_blocks
    private_subnet_cidrs = module.vpc.private_subnets_cidr_blocks
    public_subnet_ids    = module.vpc.public_subnets
    private_subnet_ids   = module.vpc.private_subnets
    public_subnet_names  = local.public_subnet_names
    private_subnet_names = local.private_subnet_names
    azs_for_subnets      = local.azs_for_subnets
    eips = [
      for eip in aws_eip.vpc_eips : {
        allocationId = eip.allocation_id
        address      = eip.public_ip
      }
    ]
  }
}