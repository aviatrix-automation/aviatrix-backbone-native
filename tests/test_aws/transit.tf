module "aws_transit" {
  source  = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version = "8.0.0"
  cloud   = "aws"
  name    = "test-aws-transit"
  account = var.aviatrix_aws_access_account
  region  = var.aws_region
  cidr    = "10.10.0.0/16"
  ha_gw   = false
}
