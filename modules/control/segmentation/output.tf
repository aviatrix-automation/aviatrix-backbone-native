output "debug_filtered_connections" {
  description = "Debug: filtered Site2Cloud connections used for segmentation associations"
  value = local.filtered_connections
}

output "debug_domain_attachment_pairs" {
  description = "Debug: all domain_attachment_pairs generated for segmentation associations"
  value = local.domain_attachment_pairs
}

output "debug_connections_list" {
  description = "Debug: raw Site2Cloud connections list from API"
  value = local.connections_list
}

output "network_domains_pretty" {
  description = "Pretty-printed Aviatrix segmentation network domains"
  value = {
    for k, v in aviatrix_segmentation_network_domain.domains : k => {
      domain_name = v.domain_name
      id          = v.id
    }
  }
}


output "connection_policies_pretty" {
  description = "Pretty-printed segmentation network domain connection policies"
  value = {
    for k, v in aviatrix_segmentation_network_domain_connection_policy.segmentation_network_domain_connection_policy : k => {
      domain_name_1 = v.domain_name_1
      domain_name_2 = v.domain_name_2
      id            = v.id
    }
  }
}


output "transit_domain_associations_pretty" {
  description = "Pretty-printed transit domain associations"
  value = {
    for k, v in aviatrix_segmentation_network_domain_association.transit_domain_associations : k => {
      network_domain_name  = v.network_domain_name
      transit_gateway_name = v.transit_gateway_name
      attachment_name      = v.attachment_name
      id                   = v.id
    }
  }
}


output "spoke_domain_associations_pretty" {
  description = "Pretty-printed spoke domain associations"
  value = {
    for k, v in aviatrix_segmentation_network_domain_association.spoke_domain_associations : k => {
      network_domain_name  = v.network_domain_name
      transit_gateway_name = v.transit_gateway_name
      attachment_name      = v.attachment_name
      id                   = v.id
    }
  }
}
