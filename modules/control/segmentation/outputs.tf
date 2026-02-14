# ============================================================================
# Segmentation Module - Comprehensive Outputs
# ============================================================================

# ----------------------------------------------------------------------------
# Domain Outputs
# ----------------------------------------------------------------------------

output "domains" {
  description = "Map of created network domain names to their IDs"
  value = {
    for k, v in aviatrix_segmentation_network_domain.domains :
    k => {
      domain_name = v.domain_name
      id          = v.id
    }
  }
}

output "domain_list" {
  description = "List of all domain names"
  value       = [for k in keys(aviatrix_segmentation_network_domain.domains) : k]
}

# ----------------------------------------------------------------------------
# Connection Policy Outputs
# ----------------------------------------------------------------------------

output "connection_policies" {
  description = "Map of connection policies between domains"
  value = {
    for k, v in aviatrix_segmentation_network_domain_connection_policy.segmentation_network_domain_connection_policy :
    k => {
      domain_1 = v.domain_name_1
      domain_2 = v.domain_name_2
      id       = v.id
    }
  }
}

output "connection_policy_matrix" {
  description = "Matrix showing which domains can communicate (bidirectional)"
  value = {
    for domain in keys(aviatrix_segmentation_network_domain.domains) :
    domain => [
      for policy_key, policy in aviatrix_segmentation_network_domain_connection_policy.segmentation_network_domain_connection_policy :
      policy.domain_name_1 == domain ? policy.domain_name_2 : policy.domain_name_2
      if policy.domain_name_1 == domain || policy.domain_name_2 == domain
    ]
  }
}

# ----------------------------------------------------------------------------
# Transit Association Outputs
# ----------------------------------------------------------------------------

output "transit_associations" {
  description = "Map of all transit domain associations"
  value = {
    for k, v in aviatrix_segmentation_network_domain_association.transit_domain_associations :
    k => {
      domain          = v.network_domain_name
      transit_gateway = v.transit_gateway_name
      connection      = v.attachment_name
      id              = v.id
    }
  }
}

output "transit_associations_by_domain" {
  description = "Transit associations grouped by network domain"
  value = {
    for domain in keys(aviatrix_segmentation_network_domain.domains) :
    domain => [
      for k, v in aviatrix_segmentation_network_domain_association.transit_domain_associations :
      {
        transit_gateway = v.transit_gateway_name
        connection      = v.attachment_name
        id              = v.id
      }
      if v.network_domain_name == domain
    ]
  }
}

output "transit_associations_by_gateway" {
  description = "Transit associations grouped by transit gateway"
  value = {
    for gw in distinct([
      for k, v in aviatrix_segmentation_network_domain_association.transit_domain_associations :
      v.transit_gateway_name
    ]) :
    gw => [
      for k, v in aviatrix_segmentation_network_domain_association.transit_domain_associations :
      {
        domain     = v.network_domain_name
        connection = v.attachment_name
        id         = v.id
      }
      if v.transit_gateway_name == gw
    ]
  }
}

# ----------------------------------------------------------------------------
# Spoke Association Outputs
# ----------------------------------------------------------------------------

output "spoke_associations" {
  description = "Map of all spoke domain associations"
  value = {
    for k, v in aviatrix_segmentation_network_domain_association.spoke_domain_associations :
    k => {
      domain          = v.network_domain_name
      spoke_gateway   = v.attachment_name
      transit_gateway = v.transit_gateway_name
      id              = v.id
    }
  }
}

output "spoke_associations_by_domain" {
  description = "Spoke associations grouped by network domain"
  value = {
    for domain in keys(aviatrix_segmentation_network_domain.domains) :
    domain => [
      for k, v in aviatrix_segmentation_network_domain_association.spoke_domain_associations :
      {
        spoke_gateway   = v.attachment_name
        transit_gateway = v.transit_gateway_name
        id              = v.id
      }
      if v.network_domain_name == domain
    ]
  }
}

output "spoke_associations_by_transit" {
  description = "Spoke associations grouped by transit gateway"
  value = {
    for gw in distinct([
      for k, v in aviatrix_segmentation_network_domain_association.spoke_domain_associations :
      v.transit_gateway_name
    ]) :
    gw => [
      for k, v in aviatrix_segmentation_network_domain_association.spoke_domain_associations :
      {
        domain        = v.network_domain_name
        spoke_gateway = v.attachment_name
        id            = v.id
      }
      if v.transit_gateway_name == gw
    ]
  }
}

# ----------------------------------------------------------------------------
# Summary Outputs
# ----------------------------------------------------------------------------

output "domain_summary" {
  description = "Comprehensive summary of each domain with associations and policies"
  value = {
    for domain in keys(aviatrix_segmentation_network_domain.domains) :
    domain => {
      domain_id = aviatrix_segmentation_network_domain.domains[domain].id

      # Transit associations for this domain
      transit_associations = {
        count = length([
          for k, v in aviatrix_segmentation_network_domain_association.transit_domain_associations :
          v if v.network_domain_name == domain
        ])
        connections = [
          for k, v in aviatrix_segmentation_network_domain_association.transit_domain_associations :
          {
            transit_gateway = v.transit_gateway_name
            connection      = v.attachment_name
          }
          if v.network_domain_name == domain
        ]
      }

      # Spoke associations for this domain
      spoke_associations = {
        count = length([
          for k, v in aviatrix_segmentation_network_domain_association.spoke_domain_associations :
          v if v.network_domain_name == domain
        ])
        spokes = [
          for k, v in aviatrix_segmentation_network_domain_association.spoke_domain_associations :
          {
            spoke_gateway   = v.attachment_name
            transit_gateway = v.transit_gateway_name
          }
          if v.network_domain_name == domain
        ]
      }

      # Connection policies for this domain
      connected_domains = [
        for policy_key, policy in aviatrix_segmentation_network_domain_connection_policy.segmentation_network_domain_connection_policy :
        policy.domain_name_1 == domain ? policy.domain_name_2 : policy.domain_name_2
        if policy.domain_name_1 == domain || policy.domain_name_2 == domain
      ]

      # Total resources
      total_associations = (
        length([
          for k, v in aviatrix_segmentation_network_domain_association.transit_domain_associations :
          v if v.network_domain_name == domain
        ]) +
        length([
          for k, v in aviatrix_segmentation_network_domain_association.spoke_domain_associations :
          v if v.network_domain_name == domain
        ])
      )
    }
  }
}

output "segmentation_status" {
  description = "Overall segmentation configuration status and statistics"
  value = {
    # Domain statistics
    total_domains        = length(keys(aviatrix_segmentation_network_domain.domains))
    domain_names         = [for k in keys(aviatrix_segmentation_network_domain.domains) : k]

    # Policy statistics
    total_policies       = length(keys(aviatrix_segmentation_network_domain_connection_policy.segmentation_network_domain_connection_policy))

    # Association statistics
    total_transit_associations = length(keys(aviatrix_segmentation_network_domain_association.transit_domain_associations))
    total_spoke_associations   = length(keys(aviatrix_segmentation_network_domain_association.spoke_domain_associations))
    total_associations         = (
      length(keys(aviatrix_segmentation_network_domain_association.transit_domain_associations)) +
      length(keys(aviatrix_segmentation_network_domain_association.spoke_domain_associations))
    )

    # Configuration sources
    auto_inferred_transits = length(keys(local.auto_transit_associations))
    manual_transits        = length(keys(var.manual_transit_associations))
    auto_inferred_spokes   = length(keys(local.auto_spoke_associations))
    manual_spokes          = length(keys(var.manual_spoke_associations))

    # Exclusions
    excluded_connections      = length(var.exclude_connections)
    excluded_spoke_gateways   = length(var.exclude_spoke_gateways)

    # Cloud types
    spoke_cloud_types = var.spoke_cloud_types
  }
}

output "association_summary" {
  description = "Summary of associations by type and source"
  value = {
    transit = {
      total          = length(keys(aviatrix_segmentation_network_domain_association.transit_domain_associations))
      auto_inferred  = length(keys(local.auto_transit_associations))
      manual         = length(keys(var.manual_transit_associations))
      by_domain = {
        for domain in keys(aviatrix_segmentation_network_domain.domains) :
        domain => length([
          for k, v in aviatrix_segmentation_network_domain_association.transit_domain_associations :
          v if v.network_domain_name == domain
        ])
      }
    }
    spoke = {
      total          = length(keys(aviatrix_segmentation_network_domain_association.spoke_domain_associations))
      auto_inferred  = length(keys(local.auto_spoke_associations))
      manual         = length(keys(var.manual_spoke_associations))
      by_domain = {
        for domain in keys(aviatrix_segmentation_network_domain.domains) :
        domain => length([
          for k, v in aviatrix_segmentation_network_domain_association.spoke_domain_associations :
          v if v.network_domain_name == domain
        ])
      }
    }
  }
}

# ----------------------------------------------------------------------------
# Association Source Tracking
# ----------------------------------------------------------------------------

output "association_sources" {
  description = "Track which associations were auto-inferred vs manually configured"
  value = {
    transit = {
      auto_inferred = {
        for key, assoc in local.auto_transit_associations :
        key => {
          domain          = assoc.network_domain
          connection      = assoc.attachment_name
          transit_gateway = assoc.transit_gateway
          source          = "auto-inferred"
        }
      }
      manual = {
        for key, domain in var.manual_transit_associations :
        key => {
          domain          = domain
          connection      = split("~", key)[0]
          transit_gateway = split("~", key)[1]
          source          = "manual"
        }
      }
    }
    spoke = {
      auto_inferred = {
        for key, assoc in local.auto_spoke_associations :
        key => {
          domain          = assoc.network_domain
          spoke_gateway   = assoc.spoke_gateway
          transit_gateway = assoc.transit_gateway
          source          = "auto-inferred"
        }
      }
      manual = {
        for key, domain in var.manual_spoke_associations :
        key => {
          domain          = domain
          spoke_gateway   = split("~", key)[0]
          transit_gateway = split("~", key)[1]
          source          = "manual"
        }
      }
    }
  }
}

# ----------------------------------------------------------------------------
# Exclusion Information
# ----------------------------------------------------------------------------

output "excluded_resources" {
  description = "Resources that were excluded from segmentation"
  value = {
    connections = {
      count = length(var.exclude_connections)
      names = var.exclude_connections
    }
    spoke_gateways = {
      count = length(var.exclude_spoke_gateways)
      names = var.exclude_spoke_gateways
    }
  }
}

# ----------------------------------------------------------------------------
# Inferred Domain Mappings
# ----------------------------------------------------------------------------

output "inferred_domain_mappings" {
  description = "Auto-inferred domain mappings for connections and spokes"
  value = {
    connections = {
      for conn_name, domain in local.inferred_domains :
      conn_name => domain
      if domain != "" && !contains(var.exclude_connections, conn_name)
    }
    spokes = {
      for gw_name, domain in local.spoke_inferred_domains :
      gw_name => domain
      if domain != "" && !contains(var.exclude_spoke_gateways, gw_name)
    }
  }
}

# ----------------------------------------------------------------------------
# Connectivity Visualization
# ----------------------------------------------------------------------------

output "domain_connectivity_graph" {
  description = "Graph representation of domain connectivity for visualization"
  value = {
    nodes = [
      for domain in keys(aviatrix_segmentation_network_domain.domains) :
      {
        id    = domain
        label = domain
        type  = "domain"
      }
    ]
    edges = [
      for policy_key, policy in aviatrix_segmentation_network_domain_connection_policy.segmentation_network_domain_connection_policy :
      {
        from  = policy.domain_name_1
        to    = policy.domain_name_2
        type  = "bidirectional"
        label = "allowed"
      }
    ]
  }
}

# ----------------------------------------------------------------------------
# Debug Outputs (optional, for troubleshooting)
# ----------------------------------------------------------------------------

output "debug_filtered_connections" {
  description = "Debug: filtered Site2Cloud connections used for segmentation associations"
  value       = local.filtered_connections
}

output "debug_domain_attachment_pairs" {
  description = "Debug: all domain_attachment_pairs generated for segmentation associations"
  value       = local.domain_attachment_pairs
}

output "debug_connections_list" {
  description = "Debug: raw Site2Cloud connections list from API"
  value       = local.connections_list
}
