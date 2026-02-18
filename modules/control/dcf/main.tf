locals {
  smart_groups_map         = { for sg in data.aviatrix_smart_groups.foo.smart_groups : sg.name => sg.uuid }
  created_smart_groups_map = { for name, sg in aviatrix_smart_group.smarties : name => sg.uuid }
}

locals {
  needs_s2c_lookup = anytrue([for k, v in var.smarties : v.s2c_domain != null])

  controller_cid = try(jsondecode(data.http.controller_login[0].response_body)["CID"], null)

  s2c_connections_list = try(
    jsondecode(terracurl_request.s2c_connections[0].response).results.connections, []
  )

  # Domains requested via s2c_domain, sorted longest-first to ensure the most
  # specific domain wins when one domain name is a substring of another (e.g.
  # "non-prod" must be evaluated before "prod" so that external-non-prod-* is
  # not incorrectly matched to the shorter "prod" domain).
  s2c_requested_domains     = distinct([for k, v in var.smarties : v.s2c_domain if v.s2c_domain != null])
  s2c_domain_length_keyed   = [for d in local.s2c_requested_domains : "${format("%03d", length(d))}${d}"]
  s2c_domain_sorted         = [for s in reverse(sort(local.s2c_domain_length_keyed)) : substr(s, 3, -1)]

  # Assign each connection to the single best-matching (longest) domain.
  s2c_connection_domain = {
    for conn in local.s2c_connections_list :
    conn.name => try(
      [
        for domain in local.s2c_domain_sorted :
        domain
        if startswith(lower(conn.name), "external-")
        && strcontains(lower(substr(conn.name, length("external-"), -1)), lower(domain))
      ][0],
      null
    )
  }

  # Invert: domain => [connection names assigned to it].
  s2c_connections_by_domain = {
    for domain in local.s2c_requested_domains :
    domain => [
      for conn_name, conn_domain in local.s2c_connection_domain :
      conn_name
      if conn_domain == domain
    ]
  }
}

resource "terracurl_request" "s2c_connections" {
  count           = local.needs_s2c_lookup ? 1 : 0
  name            = "dcf_s2c_connections"
  url             = "https://${data.aws_ssm_parameter.aviatrix_ip.value}/v2/api"
  method          = "POST"
  skip_tls_verify = true

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
    ignore_changes = all
  }
}

resource "aviatrix_distributed_firewalling_config" "enable_distributed_firewalling" {
  enable_distributed_firewalling = var.enable_distributed_firewalling
}

resource "aviatrix_distributed_firewalling_default_action_rule" "distributed_firewalling_default_action_rule" {
  action  = var.distributed_firewalling_default_action_rule_action
  logging = var.distributed_firewalling_default_action_rule_logging
}

resource "aviatrix_smart_group" "smarties" {
  for_each = var.smarties
  name     = each.key
  selector {
    dynamic "match_expressions" {
      for_each = each.value.cidr != null ? [1] : []
      content {
        cidr = each.value.cidr
      }
    }
    dynamic "match_expressions" {
      for_each = each.value.tags != null ? [1] : []
      content {
        type = "vm"
        tags = each.value.tags
      }
    }
    dynamic "match_expressions" {
      for_each = each.value.s2c != null ? each.value.s2c : []
      content {
        s2c = match_expressions.value
      }
    }
    dynamic "match_expressions" {
      for_each = each.value.s2c_domain != null ? lookup(local.s2c_connections_by_domain, each.value.s2c_domain, []) : []
      content {
        s2c = match_expressions.value
      }
    }
  }
}

resource "aviatrix_distributed_firewalling_policy_list" "policies" {
  dynamic "policies" {
    for_each = var.policies
    content {
      name             = policies.key
      action           = policies.value.action
      priority         = policies.value.priority
      protocol         = policies.value.protocol
      logging          = policies.value.logging
      watch            = policies.value.watch
      src_smart_groups = [for sg_name in policies.value.src_smart_groups : contains(keys(local.created_smart_groups_map), sg_name) ? local.created_smart_groups_map[sg_name] : local.smart_groups_map[sg_name]]
      dst_smart_groups = [for sg_name in policies.value.dst_smart_groups : contains(keys(local.created_smart_groups_map), sg_name) ? local.created_smart_groups_map[sg_name] : local.smart_groups_map[sg_name]]
      dynamic "port_ranges" {
        for_each = (policies.value.protocol != "icmp" && length(lookup(policies.value, "port_ranges", [])) > 0) ? lookup(policies.value, "port_ranges", []) : []

        content {
          lo = tonumber(port_ranges.value)
          hi = tonumber(port_ranges.value)
        }
      }
    }
  }
  depends_on = [aviatrix_distributed_firewalling_config.enable_distributed_firewalling]
}