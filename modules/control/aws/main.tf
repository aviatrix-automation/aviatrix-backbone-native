module "transit" {
  source = "./modules/transit"

  aws_ssm_region   = var.aws_ssm_region
  region           = var.region
  tags             = var.tags
  transits         = var.transits
  tgws             = var.tgws
  external_devices = var.external_devices
  spokes           = var.spokes
}
