module "transit" {
  source = "./modules/transit"

  aws_ssm_region   = var.aws_ssm_region
  project_id       = var.project_id
  transits         = var.transits
  ncc_hubs         = var.ncc_hubs
  spokes           = var.spokes
  aviatrix_spokes  = var.aviatrix_spokes
  external_devices = var.external_devices
}
