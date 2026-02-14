# ----------------------------------------------------------------------------
# Table-Formatted Output (Human-Readable)
# ----------------------------------------------------------------------------

output "peering_table" {
  description = "Transit gateway peerings in table format for easy viewing"
  value = join("\n", concat(
    [
      "",
      "═══════════════════════════════════════════════════════════════════════════════════",
      "                      TRANSIT GATEWAY PEERING TABLE",
      "═══════════════════════════════════════════════════════════════════════════════════",
      "",
      "SAME-CLOUD PEERINGS:",
      format("%-35s | %-35s | %s", "Gateway 1", "Gateway 2", "Cloud Type"),
      "───────────────────────────────────────────────────────────────────────────────────"
    ],
    length(keys(aviatrix_transit_gateway_peering.same_cloud)) > 0 ? [
      for key, peering in aviatrix_transit_gateway_peering.same_cloud :
      format("%-35s | %-35s | %s",
        substr(peering.transit_gateway_name1, 0, 35),
        substr(peering.transit_gateway_name2, 0, 35),
        local.same_cloud_peering_map[key].cloud_type == 1 ? "AWS (1)" :
        local.same_cloud_peering_map[key].cloud_type == 4 ? "GCP (4)" :
        local.same_cloud_peering_map[key].cloud_type == 8 ? "Azure (8)" :
        tostring(local.same_cloud_peering_map[key].cloud_type)
      )
    ] : ["  (none)"],
    [
      "",
      "CROSS-CLOUD PEERINGS:",
      format("%-35s | %-35s | %s", "Gateway 1", "Gateway 2", "Cloud Types"),
      "───────────────────────────────────────────────────────────────────────────────────"
    ],
    length(keys(aviatrix_transit_gateway_peering.cross_cloud)) > 0 ? [
      for key, peering in aviatrix_transit_gateway_peering.cross_cloud :
      format("%-35s | %-35s | %s",
        substr(peering.transit_gateway_name1, 0, 35),
        substr(peering.transit_gateway_name2, 0, 35),
        format("%s <-> %s",
          local.cross_cloud_peering_map[key].cloud_type_1 == 1 ? "AWS" :
          local.cross_cloud_peering_map[key].cloud_type_1 == 4 ? "GCP" :
          local.cross_cloud_peering_map[key].cloud_type_1 == 8 ? "Azure" :
          tostring(local.cross_cloud_peering_map[key].cloud_type_1),
          local.cross_cloud_peering_map[key].cloud_type_2 == 1 ? "AWS" :
          local.cross_cloud_peering_map[key].cloud_type_2 == 4 ? "GCP" :
          local.cross_cloud_peering_map[key].cloud_type_2 == 8 ? "Azure" :
          tostring(local.cross_cloud_peering_map[key].cloud_type_2)
        )
      )
    ] : ["  (none)"],
    [
      "═══════════════════════════════════════════════════════════════════════════════════",
      format("Total Same-Cloud Peerings:  %d", length(keys(aviatrix_transit_gateway_peering.same_cloud))),
      format("Total Cross-Cloud Peerings: %d", length(keys(aviatrix_transit_gateway_peering.cross_cloud))),
      format("Total Peerings:             %d", (
        length(keys(aviatrix_transit_gateway_peering.same_cloud)) +
        length(keys(aviatrix_transit_gateway_peering.cross_cloud))
      )),
      ""
    ]
  ))
}

# ----------------------------------------------------------------------------
# Structured Outputs (for automation)
# ----------------------------------------------------------------------------

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
