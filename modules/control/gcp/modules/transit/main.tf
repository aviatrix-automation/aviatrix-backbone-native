locals {
  # Normalize transits: auto-populate fw_ip_config with defaults when fw_amount > 0
  # This ensures all firewalls get static IPs, bootstrap template rendering, routes, and loopbacks
  transits_normalized = [
    for t in var.transits : merge(t, {
      fw_ip_config = t.fw_ip_config != null ? t.fw_ip_config : (
        t.fw_amount > 0 ? {
          egress_ip_start = 4
          lan_ip_start    = 4
        } : null
      )
    })
  ]

  transits_map = { for t in local.transits_normalized : t.gw_name => t }

  # Transits that need an external LB in front of FW egress interfaces
  lb_external_transits = { for t in local.transits_normalized : t.gw_name => t if length(t.external_lb_rules) > 0 && t.fw_amount > 0 }

  # Health check rule per transit (the one rule with health_check = true)
  lb_external_hc_rule = {
    for t in local.transits_normalized : t.gw_name => [for r in t.external_lb_rules : r if r.health_check][0]
    if length(t.external_lb_rules) > 0
  }

  # Flat map of per-rule entries for forwarding rules: {gw_name}-{rule_name} => { ... }
  lb_external_rules_flat = merge([
    for gw_name, t in local.lb_external_transits : {
      for rule in t.external_lb_rules :
      "${gw_name}-${rule.name}" => {
        gw_name       = gw_name
        project_id    = t.project_id
        region        = t.region
        rule_name     = rule.name
        frontend_port = rule.frontend_port
      }
    }
  ]...)

  bgp_lan_subnets_order = {
    for transit in local.transits_normalized :
    transit.gw_name => keys(transit.bgp_lan_subnets)
  }

  # Merge created and existing BGP LAN VPCs
  bgp_lan_vpcs = merge(
    { for k, v in google_compute_network.bgp_lan_vpcs : k => v },
    { for k, v in data.google_compute_network.existing_bgp_lan_vpcs : k => v }
  )

  # Merge created and existing BGP LAN subnets
  bgp_lan_subnets = merge(
    { for k, v in google_compute_subnetwork.bgp_lan_subnets : k => v },
    { for k, v in data.google_compute_subnetwork.existing_bgp_lan_subnets : k => v }
  )

  # Merge created and existing Cloud Routers
  bgp_lan_routers = merge(
    { for k, v in google_compute_router.bgp_lan_routers : k => v },
    { for k, v in data.google_compute_router.existing_bgp_lan_routers : k => v }
  )

  # Merge created and existing BGP addresses
  bgp_lan_addresses = merge(
    { for k, v in google_compute_address.bgp_lan_addresses : k => v },
    { for k, v in data.google_compute_address.existing_bgp_lan_addresses : k => v }
  )

  # Helper to get NCC hub ID (constructed for existing hubs, resource ID for created hubs)
  ncc_hub_ids = {
    for hub in var.ncc_hubs :
    hub.name => hub.create ? google_network_connectivity_hub.ncc_hubs[hub.name].id : "projects/${var.project_id}/locations/global/hubs/ncc-${hub.name}"
  }

  fws = flatten([
    for transit in local.transits_normalized : concat(
      [for i in range(floor(tonumber(transit.fw_amount) / 2)) : {
        gw_name                = transit.gw_name
        index                  = i
        type                   = "pri"
        zone                   = transit.zone
        project_id             = transit.project_id
        region                 = transit.region
        name                   = transit.name
        fw_instance_size       = transit.fw_instance_size
        firewall_image         = transit.firewall_image
        firewall_image_version = transit.firewall_image_version
        service_account        = transit.service_account
        ssh_keys               = transit.ssh_keys
        name_prefix            = transit.name_prefix
        files                  = transit.files
        # Static IP assignments (null when fw_ip_config is not set)
        egress_ip = transit.fw_ip_config != null ? cidrhost(transit.egress_cidr, transit.fw_ip_config.egress_ip_start + i * 2) : null
        lan_ip    = transit.fw_ip_config != null ? cidrhost(transit.lan_cidr, transit.fw_ip_config.lan_ip_start + i * 2) : null
        # Bootstrap template config
        fw_ip_config      = transit.fw_ip_config
        egress_cidr       = transit.egress_cidr
        lan_cidr          = transit.lan_cidr
        external_lb_rules = transit.external_lb_rules
      }],
      [for i in range(floor(tonumber(transit.fw_amount) / 2)) : {
        gw_name                = transit.gw_name
        index                  = i
        type                   = "ha"
        zone                   = transit.ha_zone
        project_id             = transit.project_id
        region                 = transit.region
        name                   = transit.name
        fw_instance_size       = transit.fw_instance_size
        firewall_image         = transit.firewall_image
        firewall_image_version = transit.firewall_image_version
        service_account        = transit.service_account
        ssh_keys               = transit.ssh_keys
        name_prefix            = transit.name_prefix
        files                  = transit.files
        # Static IP assignments (null when fw_ip_config is not set)
        egress_ip = transit.fw_ip_config != null ? cidrhost(transit.egress_cidr, transit.fw_ip_config.egress_ip_start + i * 2 + 1) : null
        lan_ip    = transit.fw_ip_config != null ? cidrhost(transit.lan_cidr, transit.fw_ip_config.lan_ip_start + i * 2 + 1) : null
        # Bootstrap template config
        fw_ip_config      = transit.fw_ip_config
        egress_cidr       = transit.egress_cidr
        lan_cidr          = transit.lan_cidr
        external_lb_rules = transit.external_lb_rules
      }]
    )
  ])

  inspection_policies = flatten([
    for transit in local.transits_normalized : [
      for intf_type, subnet_config in transit.bgp_lan_subnets : {
        transit_key     = transit.gw_name
        connection_name = "external-${intf_type}-${transit.gw_name}"
        pair_key        = "${transit.gw_name}-bgp-lan-${intf_type}"
      } if subnet_config.cidr != "" &&
      transit.fw_amount > 0
    ]
  ])

  external_device_pairs = {
    for k, v in var.external_devices : k => {
      transit_gw_name           = v.transit_gw_name
      connection_name           = v.connection_name
      pair_key                  = "${v.transit_gw_name}.${v.connection_name}"
      remote_gateway_ip         = v.remote_gateway_ip
      bgp_enabled               = v.bgp_enabled
      bgp_remote_asn            = v.bgp_enabled ? v.bgp_remote_asn : null
      backup_bgp_remote_as_num  = v.ha_enabled ? v.bgp_remote_asn : null
      local_tunnel_cidr         = v.local_tunnel_cidr
      remote_tunnel_cidr        = v.remote_tunnel_cidr
      ha_enabled                = v.ha_enabled
      backup_remote_gateway_ip  = v.ha_enabled ? v.backup_remote_gateway_ip : null
      backup_local_tunnel_cidr  = v.ha_enabled ? v.backup_local_tunnel_cidr : null
      backup_remote_tunnel_cidr = v.ha_enabled ? v.backup_remote_tunnel_cidr : null
      enable_ikev2              = v.enable_ikev2
      inspected_by_firenet      = v.inspected_by_firenet
      # Custom IPsec algorithm parameters
      custom_algorithms       = v.custom_algorithms
      pre_shared_key          = v.pre_shared_key
      backup_pre_shared_key   = v.backup_pre_shared_key
      phase_1_authentication  = v.phase_1_authentication
      phase_1_dh_groups       = v.phase_1_dh_groups
      phase_1_encryption      = v.phase_1_encryption
      phase_2_authentication  = v.phase_2_authentication
      phase_2_dh_groups       = v.phase_2_dh_groups
      phase_2_encryption      = v.phase_2_encryption
      phase1_local_identifier = v.phase1_local_identifier
      # BGP learned CIDRs and manual advertisement parameters
      enable_learned_cidrs_approval = v.enable_learned_cidrs_approval
      approved_cidrs                = v.approved_cidrs
      manual_bgp_advertised_cidrs   = v.manual_bgp_advertised_cidrs
    }
  }

  external_inspection_policies = [
    for k, v in local.external_device_pairs : {
      transit_key     = v.transit_gw_name
      connection_name = v.connection_name
      pair_key        = v.pair_key
      } if v.inspected_by_firenet && lookup(
      { for t in local.transits_normalized : t.gw_name => t.fw_amount },
      v.transit_gw_name,
      0
    ) > 0
  ]

  hub_topologies = {
    for hub in var.ncc_hubs :
    hub.name => hub.preset_topology
  }
}

resource "google_network_connectivity_hub" "ncc_hubs" {
  for_each = { for hub in var.ncc_hubs : hub.name => hub if hub.create }

  name            = "ncc-${each.value.name}"
  project         = var.project_id
  description     = "NCC hub for ${each.value.name}"
  preset_topology = each.value.preset_topology
}

resource "google_network_connectivity_group" "center_group" {
  for_each = { for hub in var.ncc_hubs : hub.name => hub if hub.create && hub.preset_topology == "STAR" }

  name    = "center"
  hub     = local.ncc_hub_ids[each.key]
  project = var.project_id

  auto_accept {
    auto_accept_projects = distinct([
      for transit in local.transits_normalized : transit.project_id
      if contains(keys(transit.bgp_lan_subnets), each.key)
    ])
  }

  depends_on = [
    google_network_connectivity_hub.ncc_hubs
  ]
}

resource "google_network_connectivity_group" "edge_group" {
  for_each = { for hub in var.ncc_hubs : hub.name => hub if hub.create && hub.preset_topology == "STAR" }

  name    = "edge"
  hub     = local.ncc_hub_ids[each.key]
  project = var.project_id

  auto_accept {
    auto_accept_projects = distinct([
      for spoke in var.spokes : spoke.project_id
      if spoke.ncc_hub == each.key
    ])
  }

  depends_on = [
    google_network_connectivity_hub.ncc_hubs
  ]
}

resource "google_network_connectivity_group" "default_group" {
  for_each = { for hub in var.ncc_hubs : hub.name => hub if hub.create && hub.preset_topology == "MESH" }

  name    = "default"
  hub     = local.ncc_hub_ids[each.key]
  project = var.project_id

  auto_accept {
    auto_accept_projects = distinct(flatten([
      [for transit in local.transits_normalized : transit.project_id if contains(keys(transit.bgp_lan_subnets), each.key)],
      [for spoke in var.spokes : spoke.project_id if spoke.ncc_hub == each.key]
    ]))
  }

  depends_on = [
    google_network_connectivity_hub.ncc_hubs
  ]
}

resource "google_network_connectivity_spoke" "avx_spokes_star" {
  for_each = { for pair in flatten([
    for transit in local.transits_normalized : [
      for intf_type, subnet in transit.bgp_lan_subnets : {
        gw_name    = transit.gw_name
        project_id = transit.project_id
        region     = transit.region
        subnet     = subnet
        intf_type  = intf_type
      } if subnet != "" && contains([for hub in var.ncc_hubs : hub.name], intf_type) && local.hub_topologies[intf_type] == "STAR"
    ]
  ]) : "${pair.gw_name}-bgp-lan-${pair.intf_type}" => pair }

  name     = "${each.value.gw_name}-bgp-lan-${each.value.intf_type}-to-avx"
  project  = each.value.project_id
  location = each.value.region
  hub      = local.ncc_hub_ids[each.value.intf_type]
  group    = "center"

  linked_router_appliance_instances {
    instances {
      virtual_machine = "projects/${each.value.project_id}/zones/${module.mc_transit[each.value.gw_name].transit_gateway.vpc_reg}/instances/${each.value.gw_name}"
      ip_address      = module.mc_transit[each.value.gw_name].transit_gateway.bgp_lan_ip_list[index(local.bgp_lan_subnets_order[each.value.gw_name], each.value.intf_type)]
    }
    instances {
      virtual_machine = try(
        "projects/${each.value.project_id}/zones/${module.mc_transit[each.value.gw_name].transit_gateway.ha_zone}/instances/${module.mc_transit[each.value.gw_name].ha_transit_gateway.gw_name}",
        "projects/${each.value.project_id}/zones/${module.mc_transit[each.value.gw_name].transit_gateway.ha_zone}/instances/${each.value.gw_name}-hagw"
      )
      ip_address = try(
        module.mc_transit[each.value.gw_name].transit_gateway.ha_bgp_lan_ip_list[index(local.bgp_lan_subnets_order[each.value.gw_name], each.value.intf_type)],
        ""
      )
    }
    site_to_site_data_transfer = true
    include_import_ranges      = ["ALL_IPV4_RANGES"]
  }

  lifecycle {
    ignore_changes = [group]
  }

  depends_on = [
    google_network_connectivity_hub.ncc_hubs,
    google_network_connectivity_group.center_group,
    module.mc_transit
  ]
}

resource "google_network_connectivity_spoke" "avx_spokes_mesh" {
  for_each = { for pair in flatten([
    for transit in local.transits_normalized : [
      for intf_type, subnet in transit.bgp_lan_subnets : {
        gw_name    = transit.gw_name
        project_id = transit.project_id
        region     = transit.region
        subnet     = subnet
        intf_type  = intf_type
      } if subnet != "" && contains([for hub in var.ncc_hubs : hub.name], intf_type) && local.hub_topologies[intf_type] == "MESH"
    ]
  ]) : "${pair.gw_name}-bgp-lan-${pair.intf_type}" => pair }

  name     = "${each.value.gw_name}-bgp-lan-${each.value.intf_type}-to-avx"
  project  = each.value.project_id
  location = each.value.region
  hub      = local.ncc_hub_ids[each.value.intf_type]
  group    = "default"

  linked_router_appliance_instances {
    instances {
      virtual_machine = "projects/${each.value.project_id}/zones/${module.mc_transit[each.value.gw_name].transit_gateway.vpc_reg}/instances/${each.value.gw_name}"
      ip_address      = module.mc_transit[each.value.gw_name].transit_gateway.bgp_lan_ip_list[index(local.bgp_lan_subnets_order[each.value.gw_name], each.value.intf_type)]
    }
    instances {
      virtual_machine = try(
        "projects/${each.value.project_id}/zones/${module.mc_transit[each.value.gw_name].transit_gateway.ha_zone}/instances/${module.mc_transit[each.value.gw_name].ha_transit_gateway.gw_name}",
        "projects/${each.value.project_id}/zones/${module.mc_transit[each.value.gw_name].transit_gateway.ha_zone}/instances/${each.value.gw_name}-hagw"
      )
      ip_address = try(
        module.mc_transit[each.value.gw_name].transit_gateway.ha_bgp_lan_ip_list[index(local.bgp_lan_subnets_order[each.value.gw_name], each.value.intf_type)],
        ""
      )
    }
    site_to_site_data_transfer = true
    include_import_ranges      = ["ALL_IPV4_RANGES"]
  }

  lifecycle {
    ignore_changes = [group]
  }

  depends_on = [
    google_network_connectivity_hub.ncc_hubs,
    google_network_connectivity_group.default_group,
    module.mc_transit
  ]
}

resource "google_network_connectivity_spoke" "ncc_spokes_star" {
  for_each = { for spoke in var.spokes : "${spoke.vpc_name}-${spoke.ncc_hub}" => spoke
  if local.hub_topologies[spoke.ncc_hub] == "STAR" }

  name     = "${each.value.vpc_name}-spoke-${each.value.ncc_hub}"
  project  = each.value.project_id
  location = "global"
  hub      = local.ncc_hub_ids[each.value.ncc_hub]
  group    = "edge"

  linked_vpc_network {
    uri = "projects/${each.value.project_id}/global/networks/${each.value.vpc_name}"
  }

  lifecycle {
    ignore_changes = [group]
  }

  depends_on = [
    google_network_connectivity_hub.ncc_hubs,
    google_network_connectivity_group.edge_group,
    google_compute_network.bgp_lan_vpcs
  ]
}

resource "google_network_connectivity_spoke" "ncc_spokes_mesh" {
  for_each = { for spoke in var.spokes : "${spoke.vpc_name}-${spoke.ncc_hub}" => spoke
  if local.hub_topologies[spoke.ncc_hub] == "MESH" }

  name     = "${each.value.vpc_name}-spoke-${each.value.ncc_hub}"
  project  = each.value.project_id
  location = "global"
  hub      = local.ncc_hub_ids[each.value.ncc_hub]
  group    = "default"

  linked_vpc_network {
    uri = "projects/${each.value.project_id}/global/networks/${each.value.vpc_name}"
  }

  lifecycle {
    ignore_changes = [group]
  }

  depends_on = [
    google_network_connectivity_hub.ncc_hubs,
    google_network_connectivity_group.default_group,
    google_compute_network.bgp_lan_vpcs
  ]
}

resource "google_compute_network" "bgp_lan_vpcs" {
  for_each = { for hub in var.ncc_hubs : hub.name => hub if hub.create }

  name                    = "bgp-lan-${each.value.name}-vpc"
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "bgp_lan_subnets" {
  for_each = { for pair in flatten([
    for transit in local.transits_normalized : [
      for intf_type, subnet_config in transit.bgp_lan_subnets : {
        gw_name       = transit.gw_name
        project_id    = transit.project_id
        region        = transit.region
        subnet_config = subnet_config
        intf_type     = intf_type
      } if subnet_config.cidr != "" && contains([for hub in var.ncc_hubs : hub.name if hub.create], intf_type)
    ]
  ]) : "${pair.gw_name}-bgp-lan-${pair.intf_type}" => pair }

  name          = "${each.value.gw_name}-bgp-lan-${each.value.intf_type}-subnet"
  project       = each.value.project_id
  region        = each.value.region
  network       = google_compute_network.bgp_lan_vpcs[each.value.intf_type].self_link
  ip_cidr_range = each.value.subnet_config.cidr
  depends_on    = [google_compute_network.bgp_lan_vpcs]

  lifecycle {
    ignore_changes = [log_config]
  }

}

resource "google_compute_router" "bgp_lan_routers" {
  for_each = { for pair in flatten([
    for transit in local.transits_normalized : [
      for intf_type, subnet_config in transit.bgp_lan_subnets : {
        gw_name         = transit.gw_name
        project_id      = transit.project_id
        region          = transit.region
        subnet_config   = subnet_config
        intf_type       = intf_type
        asn             = transit.cloud_router_asn
        has_external_lb = length(transit.external_lb_rules) > 0
        lan_cidr        = transit.lan_cidr
      } if subnet_config.cidr != "" && contains([for hub in var.ncc_hubs : hub.name if hub.create], intf_type)
    ]
  ]) : "${pair.gw_name}-bgp-lan-${pair.intf_type}" => pair }

  name    = "${each.value.gw_name}-bgp-lan-${each.value.intf_type}-router"
  project = each.value.project_id
  region  = each.value.region
  network = local.bgp_lan_vpcs[each.value.intf_type].self_link

  bgp {
    asn            = each.value.asn
    advertise_mode = each.value.has_external_lb ? "CUSTOM" : "DEFAULT"

    dynamic "advertised_ip_ranges" {
      for_each = each.value.has_external_lb ? [each.value.lan_cidr] : []
      content {
        range = advertised_ip_ranges.value
      }
    }
  }

  depends_on = [
    google_compute_network.bgp_lan_vpcs,
    data.google_compute_network.existing_bgp_lan_vpcs
  ]
}

resource "google_compute_address" "bgp_lan_addresses" {
  for_each = { for pair in flatten([
    for transit in local.transits_normalized : [
      for intf_type, subnet in transit.bgp_lan_subnets : [
        {
          gw_name    = transit.gw_name
          project_id = transit.project_id
          region     = transit.region
          subnet     = subnet
          intf_type  = intf_type
          type       = "pri"
        },
        {
          gw_name    = transit.gw_name
          project_id = transit.project_id
          region     = transit.region
          subnet     = subnet
          intf_type  = intf_type
          type       = "ha"
        }
      ] if subnet != "" && contains([for hub in var.ncc_hubs : hub.name if hub.create], intf_type)
    ]
  ]) : "${pair.gw_name}-bgp-lan-${pair.intf_type}-${pair.type}" => pair }

  name         = "${each.value.gw_name}-bgp-lan-${each.value.intf_type}-address-${each.value.type}"
  project      = each.value.project_id
  region       = each.value.region
  subnetwork   = local.bgp_lan_subnets["${each.value.gw_name}-bgp-lan-${each.value.intf_type}"].self_link
  address_type = "INTERNAL"

  depends_on = [
    google_compute_subnetwork.bgp_lan_subnets,
    data.google_compute_subnetwork.existing_bgp_lan_subnets
  ]
}

resource "google_compute_router_interface" "bgp_lan_interfaces_pri" {
  for_each = { for pair in flatten([
    for transit in local.transits_normalized : [
      for intf_type, subnet in transit.bgp_lan_subnets : {
        gw_name    = transit.gw_name
        project_id = transit.project_id
        region     = transit.region
        subnet     = subnet
        intf_type  = intf_type
      } if subnet != "" && contains([for hub in var.ncc_hubs : hub.name], intf_type)
    ]
  ]) : "${pair.gw_name}-bgp-lan-${pair.intf_type}" => pair }

  name                = "${each.value.gw_name}-bgp-lan-${each.value.intf_type}-int-pri"
  project             = each.value.project_id
  region              = each.value.region
  router              = local.bgp_lan_routers[each.key].name
  subnetwork          = local.bgp_lan_subnets[each.key].self_link
  private_ip_address  = local.bgp_lan_addresses["${each.key}-pri"].address
  redundant_interface = google_compute_router_interface.bgp_lan_interfaces_ha[each.key].name

  depends_on = [
    google_compute_router.bgp_lan_routers,
    data.google_compute_router.existing_bgp_lan_routers,
    google_compute_subnetwork.bgp_lan_subnets,
    data.google_compute_subnetwork.existing_bgp_lan_subnets,
    google_compute_address.bgp_lan_addresses,
    data.google_compute_address.existing_bgp_lan_addresses,
    google_compute_router_interface.bgp_lan_interfaces_ha
  ]
}

resource "google_compute_router_interface" "bgp_lan_interfaces_ha" {
  for_each = { for pair in flatten([
    for transit in local.transits_normalized : [
      for intf_type, subnet in transit.bgp_lan_subnets : {
        gw_name    = transit.gw_name
        project_id = transit.project_id
        region     = transit.region
        subnet     = subnet
        intf_type  = intf_type
      } if subnet != "" && contains([for hub in var.ncc_hubs : hub.name], intf_type)
    ]
  ]) : "${pair.gw_name}-bgp-lan-${pair.intf_type}" => pair }

  name               = "${each.value.gw_name}-bgp-lan-${each.value.intf_type}-int-hagw"
  project            = each.value.project_id
  region             = each.value.region
  router             = local.bgp_lan_routers[each.key].name
  subnetwork         = local.bgp_lan_subnets[each.key].self_link
  private_ip_address = local.bgp_lan_addresses["${each.key}-ha"].address

  depends_on = [
    google_compute_router.bgp_lan_routers,
    data.google_compute_router.existing_bgp_lan_routers,
    google_compute_subnetwork.bgp_lan_subnets,
    data.google_compute_subnetwork.existing_bgp_lan_subnets,
    google_compute_address.bgp_lan_addresses,
    data.google_compute_address.existing_bgp_lan_addresses
  ]
}

resource "google_compute_firewall" "bgp_lan_bgp" {
  for_each = { for hub in var.ncc_hubs : hub.name => hub if hub.create }

  name    = "bgp-lan-${each.value.name}-allow-bgp"
  project = var.project_id
  network = local.bgp_lan_vpcs[each.value.name].self_link

  allow {
    protocol = "tcp"
    ports    = ["179"]
  }

  source_ranges = [for s in local.bgp_lan_subnets : s.ip_cidr_range if s.network == local.bgp_lan_vpcs[each.value.name].self_link]
  target_tags   = ["bgp-lan"]

  depends_on = [
    google_compute_network.bgp_lan_vpcs,
    google_compute_subnetwork.bgp_lan_subnets,
    data.google_compute_network.existing_bgp_lan_vpcs,
    data.google_compute_subnetwork.existing_bgp_lan_subnets
  ]
}

module "mc_transit" {
  for_each = { for transit in local.transits_normalized : transit.gw_name => transit }

  source  = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version = "8.2.0"

  cloud                         = "gcp"
  region                        = each.value.region
  name                          = each.value.name
  gw_name                       = each.value.gw_name
  cidr                          = each.value.vpc_cidr
  account                       = each.value.access_account_name
  instance_size                 = each.value.gw_size
  insane_mode                   = true
  ha_gw                         = true
  enable_bgp_over_lan           = true
  enable_transit_firenet        = true
  enable_segmentation           = true
  enable_advertise_transit_cidr = false
  enable_multi_tier_transit     = true
  bgp_ecmp                      = true
  local_as_number               = each.value.aviatrix_gw_asn
  lan_cidr                      = each.value.lan_cidr
  # Learned CIDRs approval configuration
  learned_cidr_approval       = each.value.learned_cidr_approval
  learned_cidrs_approval_mode = each.value.learned_cidrs_approval_mode
  approved_learned_cidrs      = each.value.approved_learned_cidrs
  bgp_lan_interfaces = [
    for intf_type in [for hub in var.ncc_hubs : hub.name] : {
      vpc_id     = local.bgp_lan_vpcs[intf_type].name
      subnet     = each.value.bgp_lan_subnets[intf_type].cidr
      create_vpc = false
    } if contains(keys(each.value.bgp_lan_subnets), intf_type) && each.value.bgp_lan_subnets[intf_type].cidr != ""
  ]

  ha_bgp_lan_interfaces = [
    for intf_type in [for hub in var.ncc_hubs : hub.name] : {
      vpc_id     = local.bgp_lan_vpcs[intf_type].name
      subnet     = each.value.bgp_lan_subnets[intf_type].cidr
      create_vpc = false
    } if contains(keys(each.value.bgp_lan_subnets), intf_type) && each.value.bgp_lan_subnets[intf_type].cidr != ""
  ]
  depends_on = [
    google_compute_network.bgp_lan_vpcs,
    google_compute_subnetwork.bgp_lan_subnets,
    data.google_compute_network.existing_bgp_lan_vpcs,
    data.google_compute_subnetwork.existing_bgp_lan_subnets
  ]
}

resource "google_compute_network" "mgmt_vpcs" {
  for_each = { for transit in local.transits_normalized : transit.gw_name => transit if transit.mgmt_cidr != "" }

  name                    = "${each.value.name}-mgmt-vpc"
  project                 = each.value.project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "mgmt_subnets" {
  for_each = { for transit in local.transits_normalized : transit.gw_name => transit if transit.mgmt_cidr != "" }

  name          = "${each.value.name}-mgmt-subnet"
  project       = each.value.project_id
  region        = each.value.region
  network       = google_compute_network.mgmt_vpcs[each.key].id
  ip_cidr_range = each.value.mgmt_cidr

  lifecycle {
    ignore_changes = [log_config]
  }

}

resource "google_compute_network" "egress_vpcs" {
  for_each = { for transit in local.transits_normalized : transit.gw_name => transit if transit.egress_cidr != "" }

  name                    = "${each.value.name}-egress-vpc"
  project                 = each.value.project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "egress_subnets" {
  for_each = { for transit in local.transits_normalized : transit.gw_name => transit if transit.egress_cidr != "" }

  name          = "${each.value.name}-egress-subnet"
  project       = each.value.project_id
  region        = each.value.region
  network       = google_compute_network.egress_vpcs[each.key].id
  ip_cidr_range = each.value.egress_cidr

  lifecycle {
    ignore_changes = [log_config]
  }

}

resource "google_compute_firewall" "mgmt_firewall_rules" {
  for_each = { for transit in local.transits_normalized : transit.gw_name => transit if transit.mgmt_cidr != "" }

  name    = "${each.key}-mgmt-allow"
  project = each.value.project_id
  network = google_compute_network.mgmt_vpcs[each.key].id

  allow {
    protocol = "all"
  }

  source_ranges = each.value.source_ranges
}


resource "google_compute_firewall" "egress_firewall_rules" {
  for_each = { for transit in local.transits_normalized : transit.gw_name => transit if transit.egress_cidr != "" }

  name    = "${each.key}-egress-allow"
  project = each.value.project_id
  network = google_compute_network.egress_vpcs[each.key].id

  allow {
    protocol = "all"
  }

  source_ranges = each.value.source_ranges
}

module "swfw-modules_bootstrap" {
  for_each        = { for fw in local.fws : "${fw.gw_name}-${fw.type}-fw${fw.index + 1}" => fw }
  source          = "PaloAltoNetworks/swfw-modules/google//modules/bootstrap"
  version         = "2.0.11"
  location        = each.value.region
  name_prefix     = each.value.name_prefix
  service_account = each.value.service_account
  # When fw_ip_config is set, exclude bootstrap.xml from files (we upload a rendered template instead)
  files = each.value.fw_ip_config != null ? {
    for k, v in each.value.files : k => v if v != "config/bootstrap.xml"
  } : each.value.files
}

# Upload per-firewall rendered bootstrap.xml when fw_ip_config is configured
resource "google_storage_bucket_object" "bootstrap_xml" {
  for_each = {
    for fw in local.fws : "${fw.gw_name}-${fw.type}-fw${fw.index + 1}" => fw
    if fw.fw_ip_config != null
  }

  name   = "config/bootstrap.xml"
  bucket = module.swfw-modules_bootstrap[each.key].bucket_name
  content = templatefile("${path.module}/../../bootstrap/bootstrap.xml.tftpl", {
    hostname          = each.key
    ssh_public_key    = can(regex("^[^:]+:(.*)", each.value.ssh_keys)) ? regex("^[^:]+:(.*)", each.value.ssh_keys)[0] : each.value.ssh_keys
    egress_gateway    = cidrhost(each.value.egress_cidr, 1)
    lan_gateway       = cidrhost(each.value.lan_cidr, 1)
    ilb_vips          = [cidrhost(each.value.lan_cidr, 99), cidrhost(each.value.lan_cidr, 100)]
    external_lb_rules = each.value.external_lb_rules
    fw_egress_ip      = each.value.egress_ip
  })

  depends_on = [module.swfw-modules_bootstrap]
}

module "pan_fw" {
  # NOTE: Previously referenced local module at ../../modules/terraform-google-swfw-modules/modules/vmseries
  # Reverted to registry source as local module was not committed to repo
  source  = "PaloAltoNetworks/swfw-modules/google//modules/vmseries"
  version = "2.0.11"


  for_each = { for fw in local.fws : "${fw.gw_name}-${fw.type}-fw${fw.index + 1}" => fw }

  project = each.value.project_id
  zone    = each.value.zone

  name           = each.key
  vmseries_image = "${each.value.firewall_image}-${each.value.firewall_image_version}"
  machine_type   = each.value.fw_instance_size

  bootstrap_options = {
    type                                 = "dhcp-client"
    mgmt-interface-swap                  = "enable"
    op-command-modes                     = "mgmt-interface-swap"
    vmseries-bootstrap-gce-storagebucket = module.swfw-modules_bootstrap[each.key].bucket_name
  }

  network_interfaces = [
    {
      subnetwork       = google_compute_subnetwork.egress_subnets[each.value.gw_name].self_link
      private_ip       = each.value.egress_ip
      create_public_ip = true
    },
    {
      subnetwork       = google_compute_subnetwork.mgmt_subnets[each.value.gw_name].self_link
      create_public_ip = true
    },
    {
      subnetwork       = data.google_compute_subnetwork.lan_subnetwork[each.value.name].self_link
      private_ip       = each.value.lan_ip
      create_public_ip = false
    }
  ]

  service_account = each.value.service_account

  ssh_keys = each.value.ssh_keys

  tags = ["avx-${google_compute_network.egress_vpcs[each.value.gw_name].name}-gbl", each.key, "vm-ilb"]

  depends_on = [
    module.mc_transit,
    google_compute_subnetwork.mgmt_subnets,
    google_compute_subnetwork.egress_subnets,
    google_compute_firewall.mgmt_firewall_rules,
    google_compute_firewall.egress_firewall_rules,
    module.swfw-modules_bootstrap
  ]
}

resource "aviatrix_firenet" "firenet" {
  for_each = { for transit in local.transits_normalized : transit.gw_name => transit if transit.fw_amount > 0 }

  vpc_id             = module.mc_transit[each.key].vpc.vpc_id
  inspection_enabled = each.value.inspection_enabled
  egress_enabled     = each.value.egress_enabled
}

resource "aviatrix_firewall_instance_association" "fw_associations" {
  for_each = { for fw in local.fws : "${fw.gw_name}-${fw.type}-fw${fw.index + 1}" => fw if local.transits_map[fw.gw_name].attach_firewall }

  vpc_id               = module.mc_transit[each.value.gw_name].vpc.vpc_id
  firenet_gw_name      = each.value.type == "pri" ? module.mc_transit[each.value.gw_name].transit_gateway.gw_name : module.mc_transit[each.value.gw_name].transit_gateway.ha_gw_name
  instance_id          = module.pan_fw[each.key].instance.instance_id
  lan_interface        = "LAN-2"
  management_interface = "Management-1"
  egress_interface     = "Egress-0"

  vendor_type = "Generic"
  attached    = true

  depends_on = [
    module.pan_fw,
    aviatrix_firenet.firenet
  ]
}


resource "google_compute_router_peer" "bgp_lan_peers_pri" {
  for_each = { for pair in flatten([
    for transit in local.transits_normalized : [
      for intf_type, subnet in transit.bgp_lan_subnets : {
        gw_name      = transit.gw_name
        project_id   = transit.project_id
        region       = transit.region
        subnet       = subnet
        intf_type    = intf_type
        aviatrix_asn = transit.aviatrix_gw_asn
      } if subnet != "" && contains([for hub in var.ncc_hubs : hub.name], intf_type)
    ]
  ]) : "${pair.gw_name}-bgp-lan-${pair.intf_type}" => pair }

  name                      = "${each.value.gw_name}-bgp-lan-${each.value.intf_type}-peer-pri"
  project                   = each.value.project_id
  region                    = each.value.region
  router                    = local.bgp_lan_routers[each.key].name
  interface                 = google_compute_router_interface.bgp_lan_interfaces_pri[each.key].name
  peer_ip_address           = module.mc_transit[each.value.gw_name].transit_gateway.bgp_lan_ip_list[index(local.bgp_lan_subnets_order[each.value.gw_name], each.value.intf_type)]
  peer_asn                  = each.value.aviatrix_asn
  advertised_route_priority = 100
  router_appliance_instance = "projects/${each.value.project_id}/zones/${module.mc_transit[each.value.gw_name].transit_gateway.vpc_reg}/instances/${each.value.gw_name}"

  depends_on = [
    google_compute_router.bgp_lan_routers,
    data.google_compute_router.existing_bgp_lan_routers,
    google_compute_router_interface.bgp_lan_interfaces_pri,
    module.mc_transit,
    google_network_connectivity_spoke.avx_spokes_star,
    google_network_connectivity_spoke.avx_spokes_mesh,
  ]
}

resource "google_compute_router_peer" "bgp_lan_peers_ha" {
  for_each = { for pair in flatten([
    for transit in local.transits_normalized : [
      for intf_type, subnet in transit.bgp_lan_subnets : {
        gw_name      = transit.gw_name
        project_id   = transit.project_id
        region       = transit.region
        subnet       = subnet
        intf_type    = intf_type
        aviatrix_asn = transit.aviatrix_gw_asn
      } if subnet != "" && contains([for hub in var.ncc_hubs : hub.name], intf_type)
    ]
  ]) : "${pair.gw_name}-bgp-lan-${pair.intf_type}" => pair }

  name                      = "${each.value.gw_name}-bgp-lan-${each.value.intf_type}-peer-ha"
  project                   = each.value.project_id
  region                    = each.value.region
  router                    = local.bgp_lan_routers[each.key].name
  interface                 = google_compute_router_interface.bgp_lan_interfaces_ha[each.key].name
  peer_ip_address           = module.mc_transit[each.value.gw_name].transit_gateway.ha_bgp_lan_ip_list[index(local.bgp_lan_subnets_order[each.value.gw_name], each.value.intf_type)]
  peer_asn                  = each.value.aviatrix_asn
  advertised_route_priority = 100
  router_appliance_instance = "projects/${each.value.project_id}/zones/${module.mc_transit[each.value.gw_name].transit_gateway.ha_zone}/instances/${each.value.gw_name}-hagw"

  depends_on = [
    google_compute_router.bgp_lan_routers,
    data.google_compute_router.existing_bgp_lan_routers,
    google_compute_router_interface.bgp_lan_interfaces_ha,
    module.mc_transit,
    google_network_connectivity_spoke.avx_spokes_star,
    google_network_connectivity_spoke.avx_spokes_mesh,
  ]
}

resource "google_compute_router_peer" "bgp_lan_peers_pri_to_ha" {
  for_each = { for pair in flatten([
    for transit in local.transits_normalized : [
      for intf_type, subnet in transit.bgp_lan_subnets : {
        gw_name      = transit.gw_name
        project_id   = transit.project_id
        region       = transit.region
        subnet       = subnet
        intf_type    = intf_type
        aviatrix_asn = transit.aviatrix_gw_asn
      } if subnet != "" && contains([for hub in var.ncc_hubs : hub.name], intf_type)
    ]
  ]) : "${pair.gw_name}-bgp-lan-${pair.intf_type}" => pair }

  name                      = "${each.value.gw_name}-bgp-lan-${each.value.intf_type}-peer-pri-to-ha"
  project                   = each.value.project_id
  region                    = each.value.region
  router                    = local.bgp_lan_routers[each.key].name
  interface                 = google_compute_router_interface.bgp_lan_interfaces_ha[each.key].name
  peer_ip_address           = module.mc_transit[each.value.gw_name].transit_gateway.bgp_lan_ip_list[index(local.bgp_lan_subnets_order[each.value.gw_name], each.value.intf_type)]
  peer_asn                  = each.value.aviatrix_asn
  advertised_route_priority = 100
  router_appliance_instance = "projects/${each.value.project_id}/zones/${module.mc_transit[each.value.gw_name].transit_gateway.vpc_reg}/instances/${each.value.gw_name}"

  depends_on = [
    google_compute_router.bgp_lan_routers,
    data.google_compute_router.existing_bgp_lan_routers,
    google_compute_router_interface.bgp_lan_interfaces_ha,
    module.mc_transit,
    google_network_connectivity_spoke.avx_spokes_star,
    google_network_connectivity_spoke.avx_spokes_mesh,
  ]
}

resource "google_compute_router_peer" "bgp_lan_peers_ha_to_pri" {
  for_each = { for pair in flatten([
    for transit in local.transits_normalized : [
      for intf_type, subnet in transit.bgp_lan_subnets : {
        gw_name      = transit.gw_name
        project_id   = transit.project_id
        region       = transit.region
        subnet       = subnet
        intf_type    = intf_type
        aviatrix_asn = transit.aviatrix_gw_asn
      } if subnet != "" && contains([for hub in var.ncc_hubs : hub.name], intf_type)
    ]
  ]) : "${pair.gw_name}-bgp-lan-${pair.intf_type}" => pair }

  name                      = "${each.value.gw_name}-bgp-lan-${each.value.intf_type}-peer-ha-to-pri"
  project                   = each.value.project_id
  region                    = each.value.region
  router                    = local.bgp_lan_routers[each.key].name
  interface                 = google_compute_router_interface.bgp_lan_interfaces_pri[each.key].name
  peer_ip_address           = module.mc_transit[each.value.gw_name].transit_gateway.ha_bgp_lan_ip_list[index(local.bgp_lan_subnets_order[each.value.gw_name], each.value.intf_type)]
  peer_asn                  = each.value.aviatrix_asn
  advertised_route_priority = 100
  router_appliance_instance = "projects/${each.value.project_id}/zones/${module.mc_transit[each.value.gw_name].transit_gateway.ha_zone}/instances/${each.value.gw_name}-hagw"

  depends_on = [
    google_compute_router.bgp_lan_routers,
    data.google_compute_router.existing_bgp_lan_routers,
    google_compute_router_interface.bgp_lan_interfaces_pri,
    module.mc_transit,
    google_network_connectivity_spoke.avx_spokes_star,
    google_network_connectivity_spoke.avx_spokes_mesh,
  ]
}

resource "aviatrix_transit_external_device_conn" "bgp_lan_connections" {
  for_each = { for pair in flatten([
    for transit in local.transits_normalized : [
      for intf_type, subnet in transit.bgp_lan_subnets : {
        gw_name                       = transit.gw_name
        project_id                    = transit.project_id
        region                        = transit.region
        subnet                        = subnet
        intf_type                     = intf_type
        manual_bgp_advertised_cidrs   = try(transit.bgp_lan_connection_cidrs[intf_type], transit.manual_bgp_advertised_cidrs)
        enable_learned_cidrs_approval = try(transit.bgp_lan_connection_learned_cidr_approval[intf_type], false)
        approved_cidrs                = try(transit.bgp_lan_connection_approved_cidrs[intf_type], [])
      } if subnet != "" && contains([for hub in var.ncc_hubs : hub.name], intf_type)
    ]
  ]) : "${pair.gw_name}-bgp-lan-${pair.intf_type}" => pair }
  vpc_id                    = module.mc_transit[each.value.gw_name].transit_gateway.vpc_id
  connection_name           = "external-${each.value.intf_type}-${each.value.gw_name}"
  gw_name                   = each.value.gw_name
  connection_type           = "bgp"
  tunnel_protocol           = "LAN"
  bgp_local_as_num          = [for t in local.transits_normalized : t.aviatrix_gw_asn if t.gw_name == each.value.gw_name][0]
  bgp_remote_as_num         = [for t in local.transits_normalized : t.cloud_router_asn if t.gw_name == each.value.gw_name][0]
  remote_lan_ip             = local.bgp_lan_addresses["${each.key}-pri"].address
  local_lan_ip              = module.mc_transit[each.value.gw_name].transit_gateway.bgp_lan_ip_list[index(local.bgp_lan_subnets_order[each.value.gw_name], each.value.intf_type)]
  ha_enabled                = true
  backup_bgp_remote_as_num  = [for t in local.transits_normalized : t.cloud_router_asn if t.gw_name == each.value.gw_name][0]
  backup_remote_lan_ip      = local.bgp_lan_addresses["${each.key}-ha"].address
  backup_local_lan_ip       = module.mc_transit[each.value.gw_name].transit_gateway.ha_bgp_lan_ip_list[index(local.bgp_lan_subnets_order[each.value.gw_name], each.value.intf_type)]
  enable_bgp_lan_activemesh = true

  manual_bgp_advertised_cidrs   = each.value.manual_bgp_advertised_cidrs
  enable_learned_cidrs_approval = each.value.enable_learned_cidrs_approval
  approved_cidrs                = each.value.enable_learned_cidrs_approval ? each.value.approved_cidrs : null

  depends_on = [
    module.mc_transit,
    google_compute_address.bgp_lan_addresses,
    data.google_compute_address.existing_bgp_lan_addresses
  ]
}

resource "aviatrix_transit_external_device_conn" "external_device" {
  for_each                  = local.external_device_pairs
  vpc_id                    = module.mc_transit[each.value.transit_gw_name].transit_gateway.vpc_id
  connection_name           = each.value.connection_name
  gw_name                   = each.value.transit_gw_name
  remote_gateway_ip         = each.value.remote_gateway_ip
  backup_remote_gateway_ip  = each.value.ha_enabled ? each.value.backup_remote_gateway_ip : null
  backup_bgp_remote_as_num  = each.value.ha_enabled ? each.value.bgp_remote_asn : null
  connection_type           = each.value.bgp_enabled ? "bgp" : "static"
  bgp_local_as_num          = each.value.bgp_enabled ? module.mc_transit[each.value.transit_gw_name].transit_gateway.local_as_number : null
  bgp_remote_as_num         = each.value.bgp_enabled ? each.value.bgp_remote_asn : null
  tunnel_protocol           = "IPsec"
  direct_connect            = false
  ha_enabled                = each.value.ha_enabled
  local_tunnel_cidr         = each.value.local_tunnel_cidr
  remote_tunnel_cidr        = each.value.remote_tunnel_cidr
  backup_local_tunnel_cidr  = each.value.ha_enabled ? each.value.backup_local_tunnel_cidr : null
  backup_remote_tunnel_cidr = each.value.ha_enabled ? each.value.backup_remote_tunnel_cidr : null
  enable_ikev2              = each.value.enable_ikev2 != null ? each.value.enable_ikev2 : false
  # Custom IPsec algorithm support - only set when custom_algorithms is true
  custom_algorithms       = each.value.custom_algorithms
  pre_shared_key          = each.value.pre_shared_key
  backup_pre_shared_key   = each.value.ha_enabled ? each.value.backup_pre_shared_key : null
  phase_1_authentication  = each.value.custom_algorithms ? each.value.phase_1_authentication : null
  phase_1_dh_groups       = each.value.custom_algorithms ? each.value.phase_1_dh_groups : null
  phase_1_encryption      = each.value.custom_algorithms ? each.value.phase_1_encryption : null
  phase_2_authentication  = each.value.custom_algorithms ? each.value.phase_2_authentication : null
  phase_2_dh_groups       = each.value.custom_algorithms ? each.value.phase_2_dh_groups : null
  phase_2_encryption      = each.value.custom_algorithms ? each.value.phase_2_encryption : null
  phase1_local_identifier = each.value.custom_algorithms ? each.value.phase1_local_identifier : null
  # BGP learned CIDRs and manual advertisement support - only set when bgp_enabled is true
  enable_learned_cidrs_approval = each.value.bgp_enabled ? each.value.enable_learned_cidrs_approval : null
  approved_cidrs                = each.value.bgp_enabled && each.value.enable_learned_cidrs_approval ? each.value.approved_cidrs : null
  manual_bgp_advertised_cidrs   = each.value.bgp_enabled ? each.value.manual_bgp_advertised_cidrs : null

  depends_on = [
    module.mc_transit
  ]
}

resource "aviatrix_transit_firenet_policy" "inspection_policies" {
  for_each = {
    for p in concat(local.inspection_policies, local.external_inspection_policies) :
    p.pair_key => p
    if lookup(
      { for t in local.transits_normalized : t.gw_name => t.inspection_enabled },
      p.transit_key,
      false
    )
  }

  transit_firenet_gateway_name = module.mc_transit[each.value.transit_key].transit_gateway.gw_name
  inspected_resource_name      = "SITE2CLOUD:${each.value.connection_name}"

  depends_on = [
    aviatrix_firenet.firenet,
    aviatrix_firewall_instance_association.fw_associations,
    aviatrix_transit_external_device_conn.bgp_lan_connections,
    aviatrix_transit_external_device_conn.external_device
  ]
}

module "mc-spoke" {
  depends_on = [module.mc_transit]
  for_each   = var.aviatrix_spokes
  source     = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version    = "8.2.0"

  account                          = each.value.account
  attached                         = each.value.attached
  cidr                             = each.value.cidr
  cloud                            = "gcp"
  customized_spoke_vpc_routes      = each.value.customized_spoke_vpc_routes
  enable_max_performance           = each.value.insane_mode ? each.value.enable_max_performance : true
  included_advertised_spoke_routes = each.value.included_advertised_spoke_routes
  insane_mode                      = each.value.insane_mode
  instance_size                    = each.value.spoke_instance_size
  region                           = each.value.region

  transit_gw = each.value.transit_gw_name

  name             = each.key
  allocate_new_eip = each.value.allocate_new_eip
  eip              = each.value.eip
  ha_eip           = each.value.ha_eip
  single_ip_snat   = each.value.single_ip_snat
}

# Global External Application LB fronting PAN firewall egress interfaces via Zonal NEGs.
# Uses GCE_VM_IP_PORT NEGs so GFE communicates with FW backends via Google's internal network.
# PAN-OS uses a single VR with a PBF rule (enforce-symmetric-return) to handle
# asymmetric routing caused by the GFE proxy sourcing all traffic from 35.191.0.0/16.

resource "google_compute_health_check" "ext_lb" {
  for_each = local.lb_external_transits

  name    = "${each.value.gw_name}-ext-lb-hc"
  project = each.value.project_id

  http_health_check {
    port = local.lb_external_hc_rule[each.key].frontend_port
  }
}

# One zonal NEG per firewall (each FW may be in a different zone)
resource "google_compute_network_endpoint_group" "ext_lb" {
  for_each = { for fw in local.fws : "${fw.gw_name}-${fw.type}-fw${fw.index + 1}" => fw if lookup(local.lb_external_transits, fw.gw_name, null) != null }

  name                  = "${each.key}-ext-lb-neg"
  project               = each.value.project_id
  zone                  = each.value.zone
  network               = google_compute_network.egress_vpcs[each.value.gw_name].self_link
  subnetwork            = google_compute_subnetwork.egress_subnets[each.value.gw_name].self_link
  network_endpoint_type = "GCE_VM_IP_PORT"
  default_port          = local.lb_external_hc_rule[each.value.gw_name].frontend_port
}

resource "google_compute_network_endpoint" "ext_lb" {
  for_each = { for fw in local.fws : "${fw.gw_name}-${fw.type}-fw${fw.index + 1}" => fw if lookup(local.lb_external_transits, fw.gw_name, null) != null }

  project                = each.value.project_id
  zone                   = each.value.zone
  network_endpoint_group = google_compute_network_endpoint_group.ext_lb[each.key].id
  instance               = module.pan_fw[each.key].instance.name
  ip_address             = each.value.egress_ip
  port                   = local.lb_external_hc_rule[each.value.gw_name].frontend_port

  depends_on = [module.pan_fw]
}

resource "google_compute_backend_service" "ext_lb" {
  for_each = local.lb_external_transits

  name    = "${each.value.gw_name}-ext-lb"
  project = each.value.project_id

  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTP"
  health_checks         = [google_compute_health_check.ext_lb[each.key].self_link]
  session_affinity      = "CLIENT_IP"

  dynamic "backend" {
    for_each = {
      for fw_key, fw in { for fw in local.fws : "${fw.gw_name}-${fw.type}-fw${fw.index + 1}" => fw if fw.gw_name == each.key } :
      fw_key => fw
    }
    content {
      group                 = google_compute_network_endpoint_group.ext_lb[backend.key].self_link
      balancing_mode        = "RATE"
      max_rate_per_endpoint = 1000
      capacity_scaler       = 1.0
    }
  }

  depends_on = [
    google_compute_network_endpoint.ext_lb,
  ]
}

resource "google_compute_url_map" "ext_lb" {
  for_each = local.lb_external_transits

  name            = "${each.value.gw_name}-ext-lb"
  project         = each.value.project_id
  default_service = google_compute_backend_service.ext_lb[each.key].self_link
}

resource "google_compute_target_http_proxy" "ext_lb" {
  for_each = local.lb_external_transits

  name    = "${each.value.gw_name}-ext-lb"
  project = each.value.project_id
  url_map = google_compute_url_map.ext_lb[each.key].self_link
}

resource "google_compute_global_address" "ext_lb" {
  for_each = local.lb_external_transits

  name         = "${each.value.gw_name}-ext-lb"
  project      = each.value.project_id
  address_type = "EXTERNAL"
}

resource "google_compute_global_forwarding_rule" "ext_lb" {
  for_each = local.lb_external_rules_flat

  name    = "${each.value.gw_name}-ext-lb-${each.value.rule_name}"
  project = each.value.project_id

  load_balancing_scheme = "EXTERNAL_MANAGED"
  target                = google_compute_target_http_proxy.ext_lb[each.value.gw_name].self_link
  ip_address            = google_compute_global_address.ext_lb[each.value.gw_name].address
  port_range            = each.value.frontend_port
}
