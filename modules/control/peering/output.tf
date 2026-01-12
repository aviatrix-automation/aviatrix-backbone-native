output "same_cloud_peerings" {
  description = "Same-cloud transit gateway peerings created"
  value = {
    for key, peering in aviatrix_transit_gateway_peering.same_cloud : key => {
      gateway_1  = peering.transit_gateway_name1
      gateway_2  = peering.transit_gateway_name2
      cloud_type = local.same_cloud_peering_map[key].cloud_type
    }
  }
}

output "cross_cloud_peerings" {
  description = "Cross-cloud transit gateway peerings created"
  value = {
    for key, peering in aviatrix_transit_gateway_peering.cross_cloud : key => {
      gateway_1    = peering.transit_gateway_name1
      gateway_2    = peering.transit_gateway_name2
      cloud_type_1 = local.cross_cloud_peering_map[key].cloud_type_1
      cloud_type_2 = local.cross_cloud_peering_map[key].cloud_type_2
    }
  }
}

output "all_primary_gateways" {
  description = "List of all primary transit gateways involved in peering"
  value       = local.all_primary_gateway_names
}

output "gateways_by_cloud_type" {
  description = "Primary transit gateways grouped by cloud type"
  value       = local.primary_gateways_by_cloud_type
}
