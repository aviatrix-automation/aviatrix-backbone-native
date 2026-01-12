locals {
  unique_domains = toset(var.domains)

  connections_list = try(jsondecode(terracurl_request.aviatrix_connections.response).results.connections, [])

  defined_domains = keys(aviatrix_segmentation_network_domain.domains)

  length_keyed        = [for d in local.defined_domains : "${format("%03d", length(d))}${d}"]
  sorted_keyed        = reverse(sort(local.length_keyed))
  sorted_domain_names = [for s in local.sorted_keyed : substr(s, 3, -1)]

  inferred_domains = {
    for conn in local.connections_list :
    conn.name => (
      startswith(lower(conn.name), "external-") ?
      try(
        [
          for domain in local.sorted_domain_names :
          domain
          if strcontains(lower(substr(conn.name, length("external-"), -1)), lower(domain))
        ][0],
        ""
      ) : ""
    )
  }

  filtered_connections = [
    for conn in local.connections_list :
    conn
    if conn.tunnel_type == "Transit_BGP"
    && conn.bgp_status == "enabled"
    && conn.bgp_transit == true
  ]

  domain_attachment_pairs = distinct(flatten([
    for conn in local.filtered_connections : [
      for gw_name in split(",", replace(conn.gw_name, " ", "")) :
        {
          key                = "${local.inferred_domains[conn.name]}~${conn.name}~${gw_name}"
          network_domain     = local.inferred_domains[conn.name]
          attachment_name    = conn.name
          transit_gateway    = gw_name
        }
      if local.inferred_domains[conn.name] != ""
         && contains(local.defined_domains, local.inferred_domains[conn.name])
         && !endswith(gw_name, "-hagw")
         && contains(conn.gateway_list, gw_name)
    ]
  ]))

  association_map = { for pair in local.domain_attachment_pairs : pair.key => pair }

  spoke_inferred_domains = {
    for gw in data.aviatrix_spoke_gateways.all_spoke_gws.gateway_list :
    gw.gw_name => try(
      [
        for domain in local.sorted_domain_names :
        domain
        if anytrue([
          for start in range(0, length(split("-", lower(gw.gw_name))) - length(split("-", lower(domain))) + 1) :
          join("-", slice(split("-", lower(gw.gw_name)), start, start + length(split("-", lower(domain))))) == lower(domain)
        ])
      ][0],
      ""
    )
    if gw.cloud_type == 8 && !endswith(gw.gw_name, "-hagw")
  }

  spoke_associations = flatten([
    for gw in data.aviatrix_spoke_gateways.all_spoke_gws.gateway_list : [
      for transit in(gw.transit_gw != "" ? split("~", gw.transit_gw) : []) : {
        spoke_gateway   = gw.gw_name
        transit_gateway = transit
        network_domain  = local.spoke_inferred_domains[gw.gw_name]
      }
    if lookup(local.spoke_inferred_domains, gw.gw_name, "") != "" && !endswith(transit, "-hagw")]
  ])

  spoke_association_map = {
    for assoc in local.spoke_associations : "${assoc.network_domain}~${assoc.spoke_gateway}~${assoc.transit_gateway}" => assoc
  }

}

locals {
  controller_login = jsondecode(data.http.controller_login.response_body)
  controller_cid   = try(local.controller_login["CID"], null)
  login_success    = try(local.controller_login["return"], false)
}

resource "terracurl_request" "aviatrix_connections" {
  name            = "aviatrix_connections"
  url             = "https://${data.aws_ssm_parameter.aviatrix_ip.value}/v2/api"
  method          = "POST"
  skip_tls_verify = false

  request_body = jsonencode({
    action = "list_site2cloud"
    CID    = local.controller_cid
  })

  headers = {
    "Content-Type" = "application/json"
  }

  response_codes = [200]
  depends_on     = [data.http.controller_login]

  destroy_url    = var.destroy_url
  destroy_method = "GET"

  lifecycle {
    postcondition {
      condition     = local.login_success && local.controller_cid != null && jsondecode(self.response)["return"]
      error_message = "Controller login failed, CID not found, or access account creation failed. Response: ${data.http.controller_login.response_body}"
    }
    ignore_changes = all
  }
}

resource "aviatrix_segmentation_network_domain" "domains" {
  for_each    = local.unique_domains
  domain_name = each.value
}

resource "aviatrix_segmentation_network_domain_connection_policy" "segmentation_network_domain_connection_policy" {
  for_each      = { for idx, policy in var.connection_policy : "${policy.source}-${policy.target}" => policy }
  domain_name_1 = each.value.source
  domain_name_2 = each.value.target
  depends_on    = [aviatrix_segmentation_network_domain.domains]
}

resource "aviatrix_segmentation_network_domain_association" "transit_domain_associations" {
  for_each             = local.association_map
  network_domain_name  = each.value.network_domain
  transit_gateway_name = each.value.transit_gateway
  attachment_name      = each.value.attachment_name

  depends_on = [aviatrix_segmentation_network_domain.domains, terracurl_request.aviatrix_connections]
}

resource "aviatrix_segmentation_network_domain_association" "spoke_domain_associations" {
  for_each             = local.spoke_association_map
  network_domain_name  = each.value.network_domain
  transit_gateway_name = each.value.transit_gateway
  attachment_name      = each.value.spoke_gateway

  depends_on = [aviatrix_segmentation_network_domain.domains]
}
