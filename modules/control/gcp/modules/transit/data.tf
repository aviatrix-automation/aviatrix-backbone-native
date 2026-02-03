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

# Note: There is no data source for google_network_connectivity_hub
# When create = false, the hub is assumed to already exist with all its
# groups and spokes configured. We only create Aviatrix resources.

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

# Data source for existing Cloud Routers (when create = false)
data "google_compute_router" "existing_bgp_lan_routers" {
  for_each = { for pair in flatten([
    for transit in var.transits : [
      for intf_type, subnet_config in transit.bgp_lan_subnets : {
        gw_name    = transit.gw_name
        project_id = transit.project_id
        region     = transit.region
        intf_type  = intf_type
        vpc_name   = [for hub in var.ncc_hubs : hub.existing_vpc_name if hub.name == intf_type && !hub.create][0]
      } if subnet_config.cidr != "" &&
           !contains([for hub in var.ncc_hubs : hub.name if hub.create], intf_type)
    ]
  ]) : "${pair.gw_name}-bgp-lan-${pair.intf_type}" => pair }

  name    = "${each.value.gw_name}-bgp-lan-${each.value.intf_type}-router"
  region  = each.value.region
  network = each.value.vpc_name
  project = each.value.project_id
}

# Data source for existing BGP addresses (when create = false)
data "google_compute_address" "existing_bgp_lan_addresses" {
  for_each = { for pair in flatten([
    for transit in var.transits : [
      for intf_type, subnet in transit.bgp_lan_subnets : [
        {
          gw_name    = transit.gw_name
          project_id = transit.project_id
          region     = transit.region
          intf_type  = intf_type
          type       = "pri"
        },
        {
          gw_name    = transit.gw_name
          project_id = transit.project_id
          region     = transit.region
          intf_type  = intf_type
          type       = "ha"
        }
      ] if subnet != "" &&
           !contains([for hub in var.ncc_hubs : hub.name if hub.create], intf_type)
    ]
  ]) : "${pair.gw_name}-bgp-lan-${pair.intf_type}-${pair.type}" => pair }

  name    = "${each.value.gw_name}-bgp-lan-${each.value.intf_type}-address-${each.value.type}"
  region  = each.value.region
  project = each.value.project_id
}