locals {
  gw_name_to_cloud_type = {
    for gw in data.aviatrix_transit_gateways.all_transit_gws.gateway_list :
    replace(gw.gw_name, ",", "-") => gw.cloud_type # Sanitize gateway names
  }

  all_gateways_by_cloud_type = {
    for gw in data.aviatrix_transit_gateways.all_transit_gws.gateway_list :
    gw.cloud_type => replace(gw.gw_name, ",", "-")...
  }

  primary_gateways_by_cloud_type = {
    for cloud_type, gateways in local.all_gateways_by_cloud_type :
    cloud_type => [
      for gw in gateways : gw if !endswith(gw, "-hagw")
    ]
  }

  # List of gateways for same-cloud peering (per cloud type with multiple gateways)
  same_cloud_peering = {
    for cloud_type, gateways in local.primary_gateways_by_cloud_type :
    cloud_type => gateways if length(gateways) > 1
  }

  # All primary gateways for cross-cloud peering
  all_primary_gateway_names = flatten(values(local.primary_gateways_by_cloud_type))

  # Cloud types: 1=AWS, 4=GCP, 8=Azure
  # HPE/Insane mode over internet only supported between AWS (1) and Azure (8)
  hpe_supported_cloud_types = [1, 8]

  # Generate same-cloud peering pairs (full mesh within each cloud type)
  same_cloud_peering_pairs = flatten([
    for cloud_type, gateways in local.same_cloud_peering : [
      for i, gw1 in gateways : [
        for j, gw2 in gateways : {
          key           = "${gw1}:${gw2}"
          gateway_1     = gw1
          gateway_2     = gw2
          cloud_type    = cloud_type
          hpe_supported = contains(local.hpe_supported_cloud_types, cloud_type)
        } if i < j
      ]
    ]
  ])

  same_cloud_peering_map = { for pair in local.same_cloud_peering_pairs : pair.key => pair }

  # Generate cross-cloud peering pairs (between different cloud types)
  cross_cloud_peering_pairs = flatten([
    for i, gw1 in local.all_primary_gateway_names : [
      for j, gw2 in local.all_primary_gateway_names : {
        key          = "${gw1}:${gw2}"
        gateway_1    = gw1
        gateway_2    = gw2
        cloud_type_1 = local.gw_name_to_cloud_type[gw1]
        cloud_type_2 = local.gw_name_to_cloud_type[gw2]
        # HPE only supported if BOTH gateways are AWS or Azure
        hpe_supported = (
          contains(local.hpe_supported_cloud_types, local.gw_name_to_cloud_type[gw1]) &&
          contains(local.hpe_supported_cloud_types, local.gw_name_to_cloud_type[gw2])
        )
      } if i < j && local.gw_name_to_cloud_type[gw1] != local.gw_name_to_cloud_type[gw2]
    ]
  ])

  cross_cloud_peering_map = { for pair in local.cross_cloud_peering_pairs : pair.key => pair }
}

# Same-cloud peering
resource "aviatrix_transit_gateway_peering" "same_cloud" {
  for_each = local.same_cloud_peering_map

  transit_gateway_name1                       = each.value.gateway_1
  transit_gateway_name2                       = each.value.gateway_2
  enable_peering_over_private_network         = false
  enable_insane_mode_encryption_over_internet = each.value.hpe_supported
  enable_max_performance                      = true
  enable_single_tunnel_mode                   = false
  tunnel_count                                = each.value.hpe_supported ? 15 : null
  insane_mode                                 = true
}

# Cross-cloud peering
resource "aviatrix_transit_gateway_peering" "cross_cloud" {
  for_each = local.cross_cloud_peering_map

  transit_gateway_name1                       = each.value.gateway_1
  transit_gateway_name2                       = each.value.gateway_2
  enable_peering_over_private_network         = false
  enable_insane_mode_encryption_over_internet = each.value.hpe_supported
  enable_max_performance                      = true
  enable_single_tunnel_mode                   = false
  tunnel_count                                = each.value.hpe_supported ? 15 : null
}