data "aws_ssm_parameter" "aviatrix_ip" {
  name            = "/aviatrix/controller/ip"
  with_decryption = true
  provider        = aws.ssm
}

data "aws_ssm_parameter" "aviatrix_username" {
  name            = "/aviatrix/controller/username"
  with_decryption = true
  provider        = aws.ssm
}

data "aws_ssm_parameter" "aviatrix_password" {
  name            = "/aviatrix/controller/password"
  with_decryption = true
  provider        = aws.ssm
}

data "aviatrix_transit_gateway" "transit_gws" {
  for_each = { for transit in var.transits : transit.gw_name => transit if module.mc_transit[transit.gw_name].transit_gateway.gw_name != "" }

  gw_name = each.value.gw_name
}

data "google_compute_subnetwork" "lan_subnetwork" {
  for_each = { for t in var.transits : t.name => t }

  name    = "${each.key}-lan"
  region  = each.value.region
  project = each.value.project_id

  depends_on = [module.mc_transit]
}

# Data source for existing BGP LAN VPCs (when create = false)
data "google_compute_network" "existing_bgp_lan_vpcs" {
  for_each = { for hub in var.ncc_hubs : hub.name => hub if !hub.create }

  name    = each.value.existing_vpc_name
  project = coalesce(each.value.existing_vpc_project, var.project_id)
}

# Data source for existing BGP LAN subnets (when create = false)
data "google_compute_subnetwork" "existing_bgp_lan_subnets" {
  for_each = { for pair in flatten([
    for transit in var.transits : [
      for intf_type, subnet_config in transit.bgp_lan_subnets : {
        gw_name             = transit.gw_name
        project_id          = transit.project_id
        region              = transit.region
        existing_subnet_name = subnet_config.existing_subnet_name
        intf_type           = intf_type
      } if subnet_config.existing_subnet_name != null &&
           subnet_config.existing_subnet_name != "" &&
           !contains([for hub in var.ncc_hubs : hub.name if hub.create], intf_type)
    ]
  ]) : "${pair.gw_name}-bgp-lan-${pair.intf_type}" => pair }

  name    = each.value.existing_subnet_name
  region  = each.value.region
  project = each.value.project_id
}