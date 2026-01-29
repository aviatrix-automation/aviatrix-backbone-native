locals {
  # Validation: Ensure panorama_config is provided when any transit uses panorama bootstrap
  _validate_panorama_config = [
    for k, v in var.transits : (
      v.bootstrap_type == "panorama" && var.panorama_config == null
      ? file("ERROR: panorama_config must be provided when bootstrap_type is 'panorama' (transit: ${k})")
      : true
    ) if v.fw_amount > 0
  ]

  stripped_names = {
    for k, v in merge(var.transits) : k => (
      length(regexall("^(.+)-vnet$", k)) > 0 ?
      regex("^(.+)-vnet$", k)[0] : k
    )
  }

  stripped_spoke_names = {
    for k, v in merge(var.transits, var.spokes) : k => (
      length(regexall("^(.+)-vnet$", k)) > 0 ?
      regex("^(.+)-vnet$", k)[0] : k
    )
  }

  transit_gw_map = { for k, v in var.transits : "${v.account}_${var.region}" => local.stripped_names[k] }

  spoke_transit_gw = { for k, v in var.spokes : k => local.transit_gw_map["${v.account}_${var.region}"] }

  vwan_names = toset(keys(var.vwan_configs))

  vwan_hub_to_vwan = { for k, v in var.vwan_hubs : k => "vwan-${k}" }

  vwan_hub_to_location = { for k, v in var.vwan_hubs : k => var.region }

  vwan_hub_names = { for k, v in var.vwan_hubs : k => "${k}-${lower(replace(var.region, " ", ""))}-hub" }

  vwan_hub_name_from_hub = { for k, v in local.vwan_hub_names : v => k }

  vwan_hub_info = {
    for k, v in var.vwan_hubs : k => {
      location         = var.region
      virtual_hub_cidr = v.virtual_hub_cidr
      azure_asn        = v.azure_asn
    }
  }

  vwan_names_per_transit = {
    for transit_key, transit in var.transits : transit_key => toset([
      for conn in(transit.vwan_connections != null ? transit.vwan_connections : []) : conn.vwan_name
      if try(conn.vwan_hub_name != "", false)
    ])
  }

  vwan_names_per_spoke = {
    for spoke_key, spoke in var.spokes : spoke_key => toset([
      for conn in(spoke.vwan_connections != null ? spoke.vwan_connections : []) : conn.vwan_name
      if try(conn.vwan_hub_name != "", false)
    ])
  }

  all_vwan_hub_names = toset(values(local.vwan_hub_names))

  transit_vnet_details = {
    for k, v in var.transits : k => {
      split_id        = split("/", module.mc-transit[k].vpc.vpc_id)
      subscription_id = data.azurerm_subscription.current.subscription_id
      resource_group  = element(split("/", module.mc-transit[k].vpc.vpc_id), 4)
      vnet_name       = element(split("/", module.mc-transit[k].vpc.vpc_id), 8)
    }
  }

  spoke_vnet_details = {
    for k, v in var.spokes : k => {
      split_id        = split("/", module.mc-spoke[k].vpc.vpc_id)
      subscription_id = data.azurerm_subscription.current.subscription_id
      resource_group  = element(split("/", module.mc-spoke[k].vpc.vpc_id), 4)
      vnet_name       = element(split("/", module.mc-spoke[k].vpc.vpc_id), 8)
    }
  }

  transit_hub_vnets = {
    for transit_key, transit in var.transits : transit_key => {
      for peering_name, peering_id in data.azurerm_virtual_network.transit_vnet[transit_key].vnet_peerings :
      peering_name => {
        vnet_name       = split("/", peering_id)[8]
        resource_group  = split("/", peering_id)[4]
        subscription_id = split("/", peering_id)[2]
      }
      if length(regexall("^HV_([^-]+)-", split("/", peering_id)[8])) > 0
    }
  }

  spoke_hub_vnets = {
    for spoke_key, spoke in var.spokes : spoke_key => {
      for peering_name, peering_id in data.azurerm_virtual_network.spoke_vnet[spoke_key].vnet_peerings :
      peering_name => {
        vnet_name       = split("/", peering_id)[8]
        resource_group  = split("/", peering_id)[4]
        subscription_id = split("/", peering_id)[2]
      }
      if length(regexall("^HV_([^-]+)-", split("/", peering_id)[8])) > 0
    }
  }

  hub_managed_vnets = {
    for k, v in var.vwan_hubs : k => {
      vnet_name = try(
        [for vnet in flatten([for tk, tv in local.transit_hub_vnets : [for peering in values(tv) : peering if length(regexall("^HV_${k}-", peering.vnet_name)) > 0]]) : vnet.vnet_name][0],
        [for vnet in flatten([for sk, sv in local.spoke_hub_vnets : [for peering in values(sv) : peering if length(regexall("^HV_${k}-", peering.vnet_name)) > 0]]) : vnet.vnet_name][0],
        "unknown"
      )
      resource_group = try(
        [for vnet in flatten([for tk, tv in local.transit_hub_vnets : [for peering in values(tv) : peering if length(regexall("^HV_${k}-", peering.vnet_name)) > 0]]) : vnet.resource_group][0],
        [for vnet in flatten([for sk, sv in local.spoke_hub_vnets : [for peering in values(sv) : peering if length(regexall("^HV_${k}-", peering.vnet_name)) > 0]]) : vnet.resource_group][0],
        "unknown"
      )
      subscription_id = try(
        [for vnet in flatten([for tk, tv in local.transit_hub_vnets : [for peering in values(tv) : peering if length(regexall("^HV_${k}-", peering.vnet_name)) > 0]]) : vnet.subscription_id][0],
        [for vnet in flatten([for sk, sv in local.spoke_hub_vnets : [for peering in values(sv) : peering if length(regexall("^HV_${k}-", peering.vnet_name)) > 0]]) : vnet.subscription_id][0],
        data.azurerm_subscription.current.subscription_id
      )
    }
  }

  transit_vwan_pairs = flatten([
    for transit_key, transit in var.transits : [
      for idx, conn in transit.vwan_connections : {
        transit_key     = transit_key
        key             = transit_key
        type            = "transit"
        vwan_name       = conn.vwan_name
        vwan_hub_name   = conn.vwan_hub_name
        local_as_number = transit.local_as_number
        bgp_lan_ips = {
          primary = module.mc-transit[transit_key].transit_gateway.bgp_lan_ip_list[0]
          ha      = module.mc-transit[transit_key].transit_gateway.ha_bgp_lan_ip_list[0]
        }
        pair_key        = "${transit_key}.${conn.vwan_hub_name}.${idx}"
        remote_vpc_name = "${local.hub_managed_vnets[conn.vwan_hub_name].vnet_name}:${local.hub_managed_vnets[conn.vwan_hub_name].resource_group}:${local.hub_managed_vnets[conn.vwan_hub_name].subscription_id}"
      } if try(conn.vwan_hub_name != "", false) && contains(keys(var.vwan_hubs), conn.vwan_hub_name)
    ] if length(transit.vwan_connections != null ? transit.vwan_connections : []) > 0
  ])

  spoke_vwan_pairs = flatten([
    for spoke_key, spoke in var.spokes : [
      for idx, conn in spoke.vwan_connections : {
        spoke_key       = spoke_key
        key             = spoke_key
        type            = "spoke"
        vwan_name       = conn.vwan_name
        vwan_hub_name   = conn.vwan_hub_name
        local_as_number = spoke.local_as_number
        bgp_lan_ips = {
          primary = module.mc-spoke[spoke_key].spoke_gateway.bgp_lan_ip_list[0]
          ha      = module.mc-spoke[spoke_key].spoke_gateway.ha_bgp_lan_ip_list[0]
        }
        pair_key        = "${spoke_key}.${conn.vwan_hub_name}.${idx}"
        remote_vpc_name = "${local.hub_managed_vnets[conn.vwan_hub_name].vnet_name}:${local.hub_managed_vnets[conn.vwan_hub_name].resource_group}:${local.hub_managed_vnets[conn.vwan_hub_name].subscription_id}"
      } if try(conn.vwan_hub_name != "", false) && contains(keys(var.vwan_hubs), conn.vwan_hub_name)
    ] if length(spoke.vwan_connections != null ? spoke.vwan_connections : []) > 0
  ])

  vwan_pairs = concat(local.transit_vwan_pairs, local.spoke_vwan_pairs)

  vwan_map = { for pair in local.vwan_pairs : pair.pair_key => pair }

  transit_vwan_map = { for pair in local.transit_vwan_pairs : pair.pair_key => pair }

  spoke_vwan_map = { for pair in local.spoke_vwan_pairs : pair.pair_key => pair }

  vwan_connect_ip = {
    for pair in local.vwan_pairs : pair.pair_key => {
      hub_ip_primary = azurerm_virtual_hub.hub[pair.vwan_hub_name].virtual_router_ips[0]
      hub_ip_ha      = azurerm_virtual_hub.hub[pair.vwan_hub_name].virtual_router_ips[1]
    }
  }

  firenet_transit_keys = [
    for k, v in var.transits : k if try(v.fw_amount, 0) > 0
  ]

  spoke_to_firenet_transit = {
    for spoke_key, spoke in var.spokes : spoke_key => [
      for transit_key, transit in var.transits : transit_key
      if transit.fw_amount > 0 && transit.account == spoke.account && var.region == var.region
      ][0] if length([
        for transit_key, transit in var.transits : transit_key
        if transit.fw_amount > 0 && transit.account == spoke.account && var.region == var.region
    ]) > 0
  }

  external_device_pairs = {
    for k, v in var.external_devices : k => {
      transit_key               = v.transit_key
      connection_name           = v.connection_name
      pair_key                  = "${v.transit_key}.${v.connection_name}"
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
      custom_algorithms         = v.custom_algorithms
      pre_shared_key            = v.pre_shared_key
      phase_1_authentication    = v.phase_1_authentication
      phase_1_dh_groups         = v.phase_1_dh_groups
      phase_1_encryption        = v.phase_1_encryption
      phase_2_authentication    = v.phase_2_authentication
      phase_2_dh_groups         = v.phase_2_dh_groups
      phase_2_encryption        = v.phase_2_encryption
      phase1_local_identifier   = v.phase1_local_identifier
    }
  }

  external_inspection_policies = [
    for k, v in local.external_device_pairs : {
      transit_key     = v.transit_key
      connection_name = v.connection_name
      pair_key        = v.pair_key
    } if v.inspected_by_firenet && lookup(var.transits[v.transit_key], "fw_amount", 0) > 0
  ]

  inspection_policies = flatten([
    for transit_key in local.firenet_transit_keys : [
      for conn in(var.transits[transit_key].vwan_connections != null ? var.transits[transit_key].vwan_connections : []) : {
        transit_key     = transit_key
        vwan_hub_name   = conn.vwan_hub_name
        connection_name = "external-${conn.vwan_hub_name}-${transit_key}"
        pair_key        = "${transit_key}.${conn.vwan_hub_name}"
      } if conn.vwan_hub_name != "" && contains(keys(var.vwan_hubs), conn.vwan_hub_name)
    ]
  ])

  fws = flatten([
    for transit_key, transit in var.transits : concat(
      [for i in range(floor(tonumber(transit.fw_amount) / 2)) : {
        transit_key            = transit_key
        name                   = "${local.stripped_names[transit_key]}-fw${i + 1}"
        gw_name                = local.stripped_names[transit_key]
        index                  = i
        type                   = "pri"
        fw_instance_size       = transit.fw_instance_size
        firewall_image_version = transit.firewall_image_version
        egress_enabled         = transit.egress_enabled
        inspection_enabled     = transit.inspection_enabled
        ssh_keys               = transit.ssh_keys
        bootstrap_type         = transit.bootstrap_type
        file_shares            = transit.file_shares
        egress_source_ranges   = transit.egress_source_ranges
        mgmt_source_ranges     = transit.mgmt_source_ranges
        lan_source_ranges      = transit.lan_source_ranges
        enable_password_auth   = transit.enable_password_auth
        admin_username         = transit.admin_username
        admin_password         = transit.admin_password
        # Per-transit Panorama overrides
        panorama_dgname  = transit.panorama_dgname
        panorama_tplname = transit.panorama_tplname
        panorama_cgname  = transit.panorama_cgname
      }],
      [for i in range(floor(tonumber(transit.fw_amount) / 2)) : {
        transit_key            = transit_key
        name                   = "${local.stripped_names[transit_key]}-fw${i + 1}"
        gw_name                = "${local.stripped_names[transit_key]}-hagw"
        index                  = i
        type                   = "ha"
        fw_instance_size       = transit.fw_instance_size
        firewall_image_version = transit.firewall_image_version
        egress_enabled         = transit.egress_enabled
        inspection_enabled     = transit.inspection_enabled
        ssh_keys               = transit.ssh_keys
        bootstrap_type         = transit.bootstrap_type
        file_shares            = transit.file_shares
        egress_source_ranges   = transit.egress_source_ranges
        mgmt_source_ranges     = transit.mgmt_source_ranges
        lan_source_ranges      = transit.lan_source_ranges
        enable_password_auth   = transit.enable_password_auth
        admin_username         = transit.admin_username
        admin_password         = transit.admin_password
        # Per-transit Panorama overrides
        panorama_dgname  = transit.panorama_dgname
        panorama_tplname = transit.panorama_tplname
        panorama_cgname  = transit.panorama_cgname
      }]
    )
  ])

}

resource "azurerm_resource_group" "vwan_rg" {
  for_each = { for k, v in var.vwan_configs : k => v if !v.existing }
  name     = "rg-${lower(each.key)}"
  location = each.value.location
  tags     = var.tags
}

resource "azurerm_resource_group" "transit_rg" {
  for_each = var.transits
  name     = "rg-transit-${lower(each.key)}-${lower(replace(var.region, " ", ""))}"
  location = var.region
  tags     = var.tags
}

resource "azurerm_resource_group" "vnet_rg" {
  for_each = {
    for k, v in merge(var.vnets, var.spokes) : k => v
    if lookup(var.spokes, k, null) != null || (!try(v.existing, false) && try(v.cidr, null) != null)
  }
  name     = "rg-vnet-${lower(each.key)}-${lower(replace(var.region, " ", ""))}"
  location = var.region
  tags     = var.tags
}

resource "azurerm_virtual_wan" "vwan" {
  for_each            = { for k, v in var.vwan_configs : k => v if !v.existing }
  name                = each.key
  resource_group_name = azurerm_resource_group.vwan_rg[each.key].name
  location            = each.value.location
  type                = "Standard"
  tags                = var.tags
  depends_on          = [azurerm_resource_group.vwan_rg]
}

resource "azurerm_virtual_network" "vnet" {
  for_each            = { for k, v in var.vnets : k => v if !try(v.existing, false) && v.cidr != null }
  name                = each.key
  resource_group_name = azurerm_resource_group.vnet_rg[each.key].name
  location            = var.region
  address_space       = [each.value.cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "private_subnet" {
  for_each = {
    for s in flatten([
      for k, v in var.vnets : [
        for i, subnet in try(v.private_subnets, []) : {
          key    = k
          subnet = subnet
          region = var.region
          index  = i
        } if !try(v.existing, false) && v.cidr != null
      ]
    ]) : "${s.key}-private-${s.index + 1}" => s
  }
  name                 = "${each.value.key}-private-${each.value.index + 1}"
  resource_group_name  = azurerm_resource_group.vnet_rg[each.value.key].name
  virtual_network_name = azurerm_virtual_network.vnet[each.value.key].name
  address_prefixes     = [each.value.subnet]
}

resource "azurerm_subnet" "public_subnet" {
  for_each = {
    for s in flatten([
      for k, v in var.vnets : [
        for i, subnet in try(v.public_subnets, []) : {
          key    = k
          subnet = subnet
          region = var.region
          index  = i
        } if !try(v.existing, false) && v.cidr != null
      ]
    ]) : "${s.key}-public-${s.index + 1}" => s
  }
  name                 = "${each.value.key}-public-${each.value.index + 1}"
  resource_group_name  = azurerm_resource_group.vnet_rg[each.value.key].name
  virtual_network_name = azurerm_virtual_network.vnet[each.value.key].name
  address_prefixes     = [each.value.subnet]
}

resource "azurerm_route_table" "private_route_table" {
  for_each            = { for k, v in var.vnets : k => v if !try(v.existing, false) && try(length(v.private_subnets), 0) > 0 && try(v.vwan_hub_name, "") == "" }
  name                = "rt-${each.key}-private"
  location            = var.region
  resource_group_name = azurerm_resource_group.vnet_rg[each.key].name
  tags                = var.tags
}

resource "azurerm_route" "private_default_null" {
  for_each            = { for k, v in var.vnets : k => v if !try(v.existing, false) && try(length(v.private_subnets), 0) > 0 && try(v.vwan_hub_name, "") == "" }
  name                = "default-to-null"
  resource_group_name = azurerm_resource_group.vnet_rg[each.key].name
  route_table_name    = azurerm_route_table.private_route_table[each.key].name
  address_prefix      = "0.0.0.0/0"
  next_hop_type       = "None"
}

resource "azurerm_subnet_route_table_association" "private_subnet_association" {
  for_each = {
    for k, v in azurerm_subnet.private_subnet : k => v
    if try(var.vnets[split("-private-", k)[0]].vwan_hub_name, "") == ""
  }
  subnet_id      = each.value.id
  route_table_id = azurerm_route_table.private_route_table[split("-private-", each.key)[0]].id
}

resource "azurerm_route_table" "public_route_table" {
  for_each            = { for k, v in var.vnets : k => v if !try(v.existing, false) && try(length(v.public_subnets), 0) > 0 && try(v.vwan_hub_name, "") == "" }
  name                = "rt-${each.key}-public"
  location            = var.region
  resource_group_name = azurerm_resource_group.vnet_rg[each.key].name
  tags                = var.tags
}

resource "azurerm_subnet_route_table_association" "public_subnet_association" {
  for_each = {
    for k, v in azurerm_subnet.public_subnet : k => v
    if try(var.vnets[split("-public-", k)[0]].vwan_hub_name, "") == ""
  }
  subnet_id      = each.value.id
  route_table_id = azurerm_route_table.public_route_table[split("-public-", each.key)[0]].id
}

resource "azurerm_virtual_hub" "hub" {
  for_each = var.vwan_hubs
  name     = local.vwan_hub_names[each.key]
  resource_group_name = try(
    data.azurerm_resource_group.existing_vwan_rg[local.vwan_hub_to_vwan[each.key]].name,
    azurerm_resource_group.vwan_rg[local.vwan_hub_to_vwan[each.key]].name
  )
  location = var.region
  virtual_wan_id = try(
    data.azurerm_virtual_wan.existing_vwan[local.vwan_hub_to_vwan[each.key]].id,
    azurerm_virtual_wan.vwan[local.vwan_hub_to_vwan[each.key]].id
  )
  address_prefix                         = each.value.virtual_hub_cidr
  virtual_router_auto_scale_min_capacity = each.value.virtual_router_auto_scale_min_capacity
  tags                                   = var.tags
  depends_on                             = [azurerm_virtual_wan.vwan, azurerm_resource_group.vwan_rg, data.azurerm_virtual_wan.existing_vwan, data.azurerm_resource_group.existing_vwan_rg]
}

resource "azurerm_virtual_hub_connection" "transit_connection" {
  for_each                  = { for pair in local.vwan_pairs : pair.pair_key => pair }
  name                      = "${each.value.key}-to-vwan-${each.value.vwan_name}"
  virtual_hub_id            = azurerm_virtual_hub.hub[each.value.vwan_hub_name].id
  remote_virtual_network_id = each.value.type == "transit" ? "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${module.mc-transit[each.value.key].vpc.resource_group}/providers/Microsoft.Network/virtualNetworks/${module.mc-transit[each.value.key].vpc.name}" : "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${module.mc-spoke[each.value.key].vpc.resource_group}/providers/Microsoft.Network/virtualNetworks/${module.mc-spoke[each.value.key].vpc.name}"
  internet_security_enabled = var.vwan_hubs[each.value.vwan_hub_name].propagate_default_route
  routing {
    propagated_route_table {
      route_table_ids = [azurerm_virtual_hub.hub[each.value.vwan_hub_name].default_route_table_id]
    }
  }
  depends_on = [azurerm_virtual_hub.hub]
}

resource "azurerm_virtual_hub_connection" "vnet_connection" {
  for_each                  = var.vnets
  name                      = "${each.key}-to-vwan-${local.vwan_hub_to_vwan[each.value.vwan_hub_name]}"
  virtual_hub_id            = azurerm_virtual_hub.hub[each.value.vwan_hub_name].id
  remote_virtual_network_id = try(data.azurerm_virtual_network.existing_vnet[each.key].id, azurerm_virtual_network.vnet[each.key].id)
  internet_security_enabled = var.vwan_hubs[each.value.vwan_hub_name].propagate_default_route
  routing {
    propagated_route_table {
      route_table_ids = [azurerm_virtual_hub.hub[each.value.vwan_hub_name].default_route_table_id]
    }
  }
  depends_on = [azurerm_virtual_hub.hub]
}

module "mc-transit" {
  for_each = var.transits
  source   = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version  = "8.0.0"

  account                          = each.value.account
  az_support                       = false
  cloud                            = "azure"
  cidr                             = each.value.cidr
  region                           = var.region
  instance_size                    = each.value.instance_size
  name                             = each.key
  gw_name                          = local.stripped_names[each.key]
  local_as_number                  = each.value.local_as_number
  enable_transit_firenet           = true
  enable_bgp_over_lan              = true
  bgp_ecmp                         = true
  enable_segmentation              = true
  enable_advertise_transit_cidr    = true
  enable_multi_tier_transit        = true
  insane_mode                      = true
  bgp_manual_spoke_advertise_cidrs = each.value.bgp_manual_spoke_advertise_cidrs
  # Learned CIDRs approval configuration
  learned_cidr_approval       = each.value.learned_cidr_approval
  learned_cidrs_approval_mode = each.value.learned_cidrs_approval_mode
  approved_learned_cidrs      = each.value.approved_learned_cidrs
  resource_group                   = azurerm_resource_group.transit_rg[each.key].name
  bgp_lan_interfaces_count         = length(local.vwan_names_per_transit[each.key]) > 0 ? min(length(local.vwan_names_per_transit[each.key]), 3) : 1
  tags                             = var.tags
}

resource "aviatrix_firenet" "firenet" {
  for_each = {
    for k, v in var.transits : k => v
  }

  vpc_id             = module.mc-transit[each.key].vpc.vpc_id
  inspection_enabled = each.value.inspection_enabled
  egress_enabled     = each.value.egress_enabled
}

# NSG for PAN Management Interface
resource "azurerm_network_security_group" "pan_mgmt" {
  for_each = {
    for fw in local.fws :
    "${local.stripped_names[fw.transit_key]}-${fw.type}-fw${fw.index + 1}" => fw
  }

  name                = "${each.key}-mgmt-nsg"
  location            = var.region
  resource_group_name = module.mc-transit[each.value.transit_key].vpc.resource_group
  tags                = var.tags

  security_rule {
    name                       = "Allow-HTTPS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefixes    = each.value.mgmt_source_ranges
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = each.value.mgmt_source_ranges
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Panorama"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3978"
    source_address_prefixes    = each.value.mgmt_source_ranges
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-ICMP"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefixes    = each.value.mgmt_source_ranges
    destination_address_prefix = "*"
  }

  depends_on = [module.mc-transit]
}

# NSG for PAN Egress Interface
resource "azurerm_network_security_group" "pan_egress" {
  for_each = {
    for fw in local.fws :
    "${local.stripped_names[fw.transit_key]}-${fw.type}-fw${fw.index + 1}" => fw
  }

  name                = "${each.key}-egress-nsg"
  location            = var.region
  resource_group_name = module.mc-transit[each.value.transit_key].vpc.resource_group
  tags                = var.tags

  security_rule {
    name                       = "Allow-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefixes    = each.value.egress_source_ranges
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  depends_on = [module.mc-transit]
}

# NSG for PAN LAN Interface
resource "azurerm_network_security_group" "pan_lan" {
  for_each = {
    for fw in local.fws :
    "${local.stripped_names[fw.transit_key]}-${fw.type}-fw${fw.index + 1}" => fw
  }

  name                = "${each.key}-lan-nsg"
  location            = var.region
  resource_group_name = module.mc-transit[each.value.transit_key].vpc.resource_group
  tags                = var.tags

  security_rule {
    name                       = "Allow-Internal"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefixes    = each.value.lan_source_ranges
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  depends_on = [module.mc-transit]
}


module "bootstrap" {

  for_each = {
    for fw in local.fws :
    "${local.stripped_names[fw.transit_key]}-${fw.type}-fw${fw.index + 1}" => fw
    if fw.bootstrap_type == "file_share"
  }

  source              = "PaloAltoNetworks/swfw-modules/azurerm//modules/bootstrap"
  name                = substr(replace(each.key, "-", ""), 0, 24)
  resource_group_name = module.mc-transit[each.value.transit_key].vpc.resource_group
  region              = var.region
  file_shares         = each.value.file_shares

  depends_on = [
    module.mc-transit
  ]

}

module "pan_fw" {
  source  = "PaloAltoNetworks/swfw-modules/azurerm//modules/vmseries"
  version = "3.4.4"

  for_each = {
    for fw in local.fws :
    "${local.stripped_names[fw.transit_key]}-${fw.type}-fw${fw.index + 1}" => fw
  }

  name                = each.key
  region              = var.region
  resource_group_name = module.mc-transit[each.value.transit_key].vpc.resource_group
  tags                = var.tags

  authentication = {
    disable_password_authentication = !each.value.enable_password_auth
    username                        = each.value.enable_password_auth ? each.value.admin_username : null
    password                        = each.value.enable_password_auth ? each.value.admin_password : null
    ssh_keys                        = each.value.ssh_keys
  }

  image = {
    version = each.value.firewall_image_version
  }

  virtual_machine = {
    zone      = null
    size      = each.value.fw_instance_size
    disk_name = "${each.key}-disk"

    # Bootstrap options based on bootstrap_type
    # Panorama: Dynamic registration with Panorama for centralized management
    # File Share: Static configuration from Azure File Share
    bootstrap_options = each.value.bootstrap_type == "panorama" ? join(";", compact([
      "type=dhcp-client",
      # Hostname includes region for better Panorama identification
      "hostname=${each.key}-${lower(replace(var.region, " ", ""))}",
      # Panorama server configuration
      "panorama-server=${data.aws_ssm_parameter.panorama_public_ip[0].value}",
      var.panorama_config.panorama_server2 != null ? "panorama-server-2=${var.panorama_config.panorama_server2}" : "",
      # DNS configuration
      "dns-primary=${var.dns_primary}",
      "dns-secondary=${var.dns_secondary}",
      # Template and Device Group (per-transit override or global)
      "tplname=${coalesce(each.value.panorama_tplname, var.panorama_config.tplname)}",
      "dgname=${coalesce(each.value.panorama_dgname, var.panorama_config.dgname)}",
      # Authentication and licensing
      "vm-auth-key=${data.aws_ssm_parameter.vm_auth_key[0].value}",
      "vm-series-auto-registration-pin-id=${data.aws_ssm_parameter.palo_alto_pin_id[0].value}",
      "vm-series-auto-registration-pin-value=${data.aws_ssm_parameter.palo_alto_pin_value[0].value}",
      "authcodes=${data.aws_ssm_parameter.palo_alto_authcode[0].value}",
      # Collector group (per-transit override or global)
      coalesce(each.value.panorama_cgname, var.panorama_config.cgname) != null ? "cgname=${coalesce(each.value.panorama_cgname, var.panorama_config.cgname)}" : "",
      # Azure-specific optimizations
      var.panorama_config.mgmt_interface_swap ? "op-command-modes=mgmt-interface-swap" : "",
      var.panorama_config.enable_dpdk ? "op-cmd-dpdk-pkt-io=on" : "",
      # Plugin operational commands
      var.panorama_config.plugin_op_commands != null ? "plugin-op-commands=${var.panorama_config.plugin_op_commands}" : ""
      ])) : join(";", [
      "type=dhcp-client",
      "storage-account=${module.bootstrap[each.key].storage_account_name}",
      "access-key=${module.bootstrap[each.key].storage_account_primary_access_key}",
      "file-share=${each.value.file_shares[keys(each.value.file_shares)[0]].name}",
      "share-directory=None"
    ])

  }

  interfaces = [
    {
      name      = "${each.key}-mgmt"
      subnet_id = each.value.type == "pri" ? data.azurerm_subnet.mgmt_subnet[each.value.transit_key].id : data.azurerm_subnet.hagw-mgmt_subnet[each.value.transit_key].id
      ip_configurations = {
        primary-ip = {
          name             = "${each.key}-mgmt-ip"
          primary          = true
          create_public_ip = true
          public_ip_name   = "${each.key}-mgmt-pip"
        }
      }
    },
    {
      name      = "${each.key}-egress"
      subnet_id = each.value.type == "pri" ? data.azurerm_subnet.egress_subnet[each.value.transit_key].id : data.azurerm_subnet.hagw-egress_subnet[each.value.transit_key].id
      ip_configurations = {
        primary-ip = {
          name             = "${each.key}-egress-ip"
          primary          = true
          create_public_ip = true
          public_ip_name   = "${each.key}-egress-pip"
        }
      }
    },
    {
      name      = "${each.key}-lan"
      subnet_id = each.value.type == "pri" ? data.azurerm_subnet.lan_subnet[each.value.transit_key].id : data.azurerm_subnet.hagw-lan_subnet[each.value.transit_key].id
      ip_configurations = {
        primary-ip = {
          name             = "${each.key}-lan-ip"
          primary          = true
          create_public_ip = false
        }
      }
    }
  ]

  depends_on = [
    module.mc-transit,
  ]

}

# NSG Association for PAN Management Interface
resource "azurerm_network_interface_security_group_association" "pan_mgmt" {
  for_each = {
    for fw in local.fws :
    "${local.stripped_names[fw.transit_key]}-${fw.type}-fw${fw.index + 1}" => fw
  }

  network_interface_id      = module.pan_fw[each.key].interfaces["${each.key}-mgmt"].id
  network_security_group_id = azurerm_network_security_group.pan_mgmt[each.key].id
}

# NSG Association for PAN Egress Interface
resource "azurerm_network_interface_security_group_association" "pan_egress" {
  for_each = {
    for fw in local.fws :
    "${local.stripped_names[fw.transit_key]}-${fw.type}-fw${fw.index + 1}" => fw
  }

  network_interface_id      = module.pan_fw[each.key].interfaces["${each.key}-egress"].id
  network_security_group_id = azurerm_network_security_group.pan_egress[each.key].id
}

# NSG Association for PAN LAN Interface
resource "azurerm_network_interface_security_group_association" "pan_lan" {
  for_each = {
    for fw in local.fws :
    "${local.stripped_names[fw.transit_key]}-${fw.type}-fw${fw.index + 1}" => fw
  }

  network_interface_id      = module.pan_fw[each.key].interfaces["${each.key}-lan"].id
  network_security_group_id = azurerm_network_security_group.pan_lan[each.key].id
}

resource "aviatrix_firewall_instance_association" "fw_associations" {

  for_each = {
    for fw in local.fws :
    "${local.stripped_names[fw.transit_key]}-${fw.type}-fw${fw.index + 1}" => fw
    if var.transits[fw.transit_key].attach_firewall
  }


  vpc_id = module.mc-transit[each.value.transit_key].vpc.vpc_id

  firenet_gw_name = each.value.type == "pri" ? module.mc-transit[each.value.transit_key].transit_gateway.gw_name : module.mc-transit[each.value.transit_key].transit_gateway.ha_gw_name

  firewall_name = format("%s-%s-fw%d",
    local.stripped_names[each.value.transit_key],
    each.value.type,
    each.value.index + 1
  )

  instance_id = format(
    "%s:%s",
    format("%s-%s-fw%d", local.stripped_names[each.value.transit_key], each.value.type, each.value.index + 1),
    split(":", module.mc-transit[each.value.transit_key].vpc.vpc_id)[1]
  )

  management_interface = lookup({ for i in module.pan_fw[each.key].interfaces : i.name => i.name }, "${each.key}-mgmt")
  egress_interface     = lookup({ for i in module.pan_fw[each.key].interfaces : i.name => i.name }, "${each.key}-egress")
  lan_interface        = lookup({ for i in module.pan_fw[each.key].interfaces : i.name => i.name }, "${each.key}-lan")

  vendor_type = "Generic"
  attached    = true

  depends_on = [module.pan_fw]
}

module "mc-spoke" {
  for_each                         = var.spokes
  source                           = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version                          = "8.0.0"
  account                          = each.value.account
  az_support                       = false
  cloud                            = "azure"
  cidr                             = each.value.cidr
  region                           = var.region
  instance_size                    = each.value.instance_size
  name                             = each.key
  gw_name                          = local.stripped_spoke_names[each.key]
  local_as_number                  = try(each.value.enable_bgp, false) ? each.value.local_as_number : null
  bgp_ecmp                         = try(each.value.enable_bgp, false) ? true : null
  insane_mode                      = true
  resource_group                   = azurerm_resource_group.vnet_rg[each.key].name
  transit_gw                       = local.spoke_transit_gw[each.key]
  enable_bgp                       = try(each.value.enable_bgp, false)
  enable_bgp_over_lan              = try(each.value.enable_bgp, false) ? true : null
  bgp_lan_interfaces_count         = try(each.value.enable_bgp, false) ? 1 : null
  included_advertised_spoke_routes = each.value.included_advertised_spoke_routes
  enable_max_performance           = each.value.enable_max_performance
  disable_route_propagation        = each.value.disable_route_propagation
  inspection                       = (contains(keys(local.spoke_to_firenet_transit), each.key) && try(var.transits[local.spoke_to_firenet_transit[each.key]].inspection_enabled, false)) ? true : false
  tags                             = var.tags

  depends_on = [azurerm_resource_group.vnet_rg, module.mc-transit]

}

resource "time_sleep" "wait_for_hub_connection" {
  count           = length(local.vwan_pairs) > 0 ? 1 : 0
  depends_on      = [azurerm_virtual_hub_connection.transit_connection, module.mc-transit]
  create_duration = "600s"
}

resource "time_sleep" "wait_for_spoke_hub_connection" {
  count           = length(local.spoke_vwan_pairs) > 0 ? 1 : 0
  depends_on      = [azurerm_virtual_hub_connection.transit_connection, module.mc-spoke]
  create_duration = "600s"
}

resource "aviatrix_transit_external_device_conn" "transit_external" {

  for_each = {
    for pair in local.transit_vwan_pairs : pair.pair_key => pair
    if length(var.transits[pair.transit_key].vwan_connections != null ? var.transits[pair.transit_key].vwan_connections : []) > 0
  }

  vpc_id                    = each.value.type == "transit" ? module.mc-transit[each.value.key].vpc.vpc_id : module.mc-spoke[each.value.key].vpc.vpc_id
  connection_name           = "external-${each.value.vwan_hub_name}-${each.value.key}"
  gw_name                   = each.value.type == "transit" ? module.mc-transit[each.value.key].transit_gateway.gw_name : module.mc-spoke[each.value.key].spoke_gateway.gw_name
  connection_type           = "bgp"
  tunnel_protocol           = "LAN"
  remote_vpc_name           = format("%s:%s:%s", local.hub_managed_vnets[each.value.vwan_hub_name].vnet_name, local.hub_managed_vnets[each.value.vwan_hub_name].resource_group, local.hub_managed_vnets[each.value.vwan_hub_name].subscription_id)
  ha_enabled                = true
  bgp_local_as_num          = each.value.local_as_number
  bgp_remote_as_num         = local.vwan_hub_info[each.value.vwan_hub_name].azure_asn
  backup_bgp_remote_as_num  = local.vwan_hub_info[each.value.vwan_hub_name].azure_asn
  remote_lan_ip             = local.vwan_connect_ip[each.key].hub_ip_primary
  backup_remote_lan_ip      = local.vwan_connect_ip[each.key].hub_ip_ha
  local_lan_ip              = each.value.bgp_lan_ips.primary
  backup_local_lan_ip       = each.value.bgp_lan_ips.ha
  enable_bgp_lan_activemesh = true
  direct_connect            = false
  custom_algorithms         = false
  enable_edge_segmentation  = false
  phase1_local_identifier   = null

  depends_on = [
    time_sleep.wait_for_hub_connection,
    data.azurerm_virtual_network.transit_vnet,
    data.azurerm_virtual_network.spoke_vnet
  ]

  lifecycle {
    ignore_changes = all
  }
}

resource "aviatrix_spoke_external_device_conn" "spoke_external" {

  for_each = {
    for pair in local.spoke_vwan_pairs : pair.pair_key => pair
    if try(var.spokes[pair.spoke_key].enable_bgp, false)
  }

  vpc_id                      = each.value.type == "transit" ? module.mc-transit[each.value.key].vpc.vpc_id : module.mc-spoke[each.value.key].vpc.vpc_id
  connection_name             = "external-${each.value.vwan_hub_name}-${each.value.key}"
  gw_name                     = each.value.type == "transit" ? module.mc-transit[each.value.key].transit_gateway.gw_name : module.mc-spoke[each.value.key].spoke_gateway.gw_name
  connection_type             = "bgp"
  tunnel_protocol             = "LAN"
  remote_vpc_name             = format("%s:%s:%s", local.hub_managed_vnets[each.value.vwan_hub_name].vnet_name, local.hub_managed_vnets[each.value.vwan_hub_name].resource_group, local.hub_managed_vnets[each.value.vwan_hub_name].subscription_id)
  ha_enabled                  = true
  bgp_local_as_num            = each.value.local_as_number
  bgp_remote_as_num           = local.vwan_hub_info[each.value.vwan_hub_name].azure_asn
  backup_bgp_remote_as_num    = local.vwan_hub_info[each.value.vwan_hub_name].azure_asn
  remote_lan_ip               = local.vwan_connect_ip[each.key].hub_ip_primary
  backup_remote_lan_ip        = local.vwan_connect_ip[each.key].hub_ip_ha
  local_lan_ip                = each.value.bgp_lan_ips.primary
  backup_local_lan_ip         = each.value.bgp_lan_ips.ha
  enable_bgp_lan_activemesh   = true
  manual_bgp_advertised_cidrs = try(var.spokes[each.value.spoke_key].spoke_bgp_manual_advertise_cidrs, null)
  direct_connect              = false
  custom_algorithms           = false
  phase1_local_identifier     = null
  depends_on = [
    time_sleep.wait_for_spoke_hub_connection,
    data.azurerm_virtual_network.transit_vnet,
    data.azurerm_virtual_network.spoke_vnet
  ]
  lifecycle {
    ignore_changes = all
  }
}

resource "azurerm_virtual_hub_bgp_connection" "peer_avx_prim" {
  for_each                      = local.transit_vwan_map
  name                          = "${each.value.transit_key}-peer-prim"
  virtual_hub_id                = azurerm_virtual_hub.hub[each.value.vwan_hub_name].id
  peer_asn                      = module.mc-transit[each.value.transit_key].transit_gateway.local_as_number
  peer_ip                       = each.value.bgp_lan_ips.primary
  virtual_network_connection_id = azurerm_virtual_hub_connection.transit_connection[each.key].id
}

resource "azurerm_virtual_hub_bgp_connection" "peer_avx_ha" {
  for_each                      = local.transit_vwan_map
  name                          = "${each.value.transit_key}-peer-ha"
  virtual_hub_id                = azurerm_virtual_hub.hub[each.value.vwan_hub_name].id
  peer_asn                      = module.mc-transit[each.value.transit_key].transit_gateway.local_as_number
  peer_ip                       = each.value.bgp_lan_ips.ha
  virtual_network_connection_id = azurerm_virtual_hub_connection.transit_connection[each.key].id
}

resource "azurerm_virtual_hub_bgp_connection" "spoke_peer_avx_prim" {
  for_each                      = local.spoke_vwan_map
  name                          = "${each.value.spoke_key}-peer-prim"
  virtual_hub_id                = azurerm_virtual_hub.hub[each.value.vwan_hub_name].id
  peer_asn                      = module.mc-spoke[each.value.spoke_key].spoke_gateway.local_as_number
  peer_ip                       = each.value.bgp_lan_ips.primary
  virtual_network_connection_id = azurerm_virtual_hub_connection.transit_connection[each.key].id
  depends_on                    = [azurerm_virtual_hub_connection.transit_connection]
}

resource "azurerm_virtual_hub_bgp_connection" "spoke_peer_avx_ha" {
  for_each                      = local.spoke_vwan_map
  name                          = "${each.value.spoke_key}-peer-ha"
  virtual_hub_id                = azurerm_virtual_hub.hub[each.value.vwan_hub_name].id
  peer_asn                      = module.mc-spoke[each.value.spoke_key].spoke_gateway.local_as_number
  peer_ip                       = each.value.bgp_lan_ips.ha
  virtual_network_connection_id = azurerm_virtual_hub_connection.transit_connection[each.key].id
  depends_on                    = [azurerm_virtual_hub_connection.transit_connection]
}


resource "aviatrix_transit_external_device_conn" "external_device" {
  for_each                  = local.external_device_pairs
  vpc_id                    = module.mc-transit[each.value.transit_key].vpc.vpc_id
  connection_name           = each.value.connection_name
  gw_name                   = module.mc-transit[each.value.transit_key].transit_gateway.gw_name
  remote_gateway_ip         = each.value.remote_gateway_ip
  backup_remote_gateway_ip  = each.value.ha_enabled ? each.value.backup_remote_gateway_ip : null
  backup_bgp_remote_as_num  = each.value.ha_enabled ? each.value.bgp_remote_asn : null
  connection_type           = each.value.bgp_enabled ? "bgp" : "static"
  bgp_local_as_num          = each.value.bgp_enabled ? module.mc-transit[each.value.transit_key].transit_gateway.local_as_number : null
  bgp_remote_as_num         = each.value.bgp_enabled ? each.value.bgp_remote_asn : null
  tunnel_protocol           = "IPsec"
  direct_connect            = false
  ha_enabled                = each.value.ha_enabled
  local_tunnel_cidr         = each.value.local_tunnel_cidr
  remote_tunnel_cidr        = each.value.remote_tunnel_cidr
  backup_local_tunnel_cidr  = each.value.ha_enabled ? each.value.backup_local_tunnel_cidr : null
  backup_remote_tunnel_cidr = each.value.ha_enabled ? each.value.backup_remote_tunnel_cidr : null
  enable_ikev2              = each.value.enable_ikev2 != null ? each.value.enable_ikev2 : false
  # Custom IPsec algorithm support
  custom_algorithms         = each.value.custom_algorithms
  pre_shared_key            = each.value.pre_shared_key
  phase_1_authentication    = each.value.phase_1_authentication
  phase_1_dh_groups         = each.value.phase_1_dh_groups
  phase_1_encryption        = each.value.phase_1_encryption
  phase_2_authentication    = each.value.phase_2_authentication
  phase_2_dh_groups         = each.value.phase_2_dh_groups
  phase_2_encryption        = each.value.phase_2_encryption
  phase1_local_identifier   = each.value.phase1_local_identifier

  depends_on = [
    module.mc-transit
  ]
}

resource "aviatrix_transit_firenet_policy" "inspection_policies" {
  for_each = {
    for p in concat(local.inspection_policies, local.external_inspection_policies) :
    p.pair_key => p
    if lookup(
      { for k, v in var.transits : k => v.inspection_enabled },
      p.transit_key,
      false
    )
  }

  transit_firenet_gateway_name = module.mc-transit[each.value.transit_key].transit_gateway.gw_name
  inspected_resource_name      = "SITE2CLOUD:${each.value.connection_name}"

  depends_on = [
    aviatrix_transit_external_device_conn.transit_external,
    aviatrix_transit_external_device_conn.external_device,
    aviatrix_firenet.firenet,
    aviatrix_firewall_instance_association.fw_associations
  ]

}
