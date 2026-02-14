# ----------------------------------------------------------------------------
# Table-Formatted Outputs (Human-Readable)
# ----------------------------------------------------------------------------

output "transit_associations_table" {
  description = "Transit associations in table format for easy viewing"
  value = join("\n", concat(
    [
      "",
      "═══════════════════════════════════════════════════════════════════════════════════",
      "                         TRANSIT ASSOCIATIONS TABLE",
      "═══════════════════════════════════════════════════════════════════════════════════",
      format("%-15s | %-30s | %-30s", "Domain", "Transit Gateway", "Connection"),
      "───────────────────────────────────────────────────────────────────────────────────"
    ],
    [
      for k, v in aviatrix_segmentation_network_domain_association.transit_domain_associations :
      format("%-15s | %-30s | %-30s",
        v.network_domain_name,
        v.transit_gateway_name,
        v.attachment_name
      )
    ],
    [
      "═══════════════════════════════════════════════════════════════════════════════════",
      format("Total Transit Associations: %d", length(keys(aviatrix_segmentation_network_domain_association.transit_domain_associations))),
      ""
    ]
  ))
}