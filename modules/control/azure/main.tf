module "transit" {
  source = "./modules/transit"

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
  dns_primary      = var.dns_primary
  dns_secondary    = var.dns_secondary
}
