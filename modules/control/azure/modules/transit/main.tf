locals {
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

  inspection_policies = flatten([
    for transit_key in local.firenet_transit_keys : [
      for conn in(var.transits[transit_key].vwan_connections != null ? var.transits[transit_key].vwan_connections : []) : {
        transit_key     = transit_key
        vwan_hub_name   = conn.vwan_hub_name
        connection_name = "external-${conn.vwan_hub_name}-${transit_key}"
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
        file_shares            = transit.file_shares
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
        file_shares            = transit.file_shares
      }]
    )
  ])

}

resource "azurerm_resource_group" "vwan_rg" {
  for_each = { for k, v in var.vwan_configs : k => v if !v.existing }
  name     = "rg-${lower(each.key)}"
  location = each.value.location
}

resource "azurerm_resource_group" "transit_rg" {
  for_each = var.transits
  name     = "rg-transit-${lower(each.key)}-${lower(replace(var.region, " ", ""))}"
  location = var.region
}

resource "azurerm_resource_group" "vnet_rg" {
  for_each = {
    for k, v in merge(var.vnets, var.spokes) : k => v
    if lookup(var.spokes, k, null) != null || (!try(v.existing, false) && try(v.cidr, null) != null)
  }
  name     = "rg-vnet-${lower(each.key)}-${lower(replace(var.region, " ", ""))}"
  location = var.region
}

resource "azurerm_virtual_wan" "vwan" {
  for_each            = { for k, v in var.vwan_configs : k => v if !v.existing }
  name                = each.key
  resource_group_name = azurerm_resource_group.vwan_rg[each.key].name
  location            = each.value.location
  type                = "Standard"
  depends_on          = [azurerm_resource_group.vwan_rg]
}

resource "azurerm_virtual_network" "vnet" {
  for_each            = { for k, v in var.vnets : k => v if !try(v.existing, false) && v.cidr != null }
  name                = each.key
  resource_group_name = azurerm_resource_group.vnet_rg[each.key].name
  location            = var.region
  address_space       = [each.value.cidr]
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
  for_each            = { for k, v in var.vnets : k => v if !try(v.existing, false) && try(length(v.private_subnets), 0) > 0 }
  name                = "rt-${each.key}-private"
  location            = var.region
  resource_group_name = azurerm_resource_group.vnet_rg[each.key].name
}

resource "azurerm_route" "private_default_null" {
  for_each            = { for k, v in var.vnets : k => v if !try(v.existing, false) && try(length(v.private_subnets), 0) > 0 }
  name                = "default-to-null"
  resource_group_name = azurerm_resource_group.vnet_rg[each.key].name
  route_table_name    = azurerm_route_table.private_route_table[each.key].name
  address_prefix      = "0.0.0.0/0"
  next_hop_type       = "None"
}

resource "azurerm_subnet_route_table_association" "private_subnet_association" {
  for_each       = azurerm_subnet.private_subnet
  subnet_id      = each.value.id
  route_table_id = azurerm_route_table.private_route_table[split("-private-", each.key)[0]].id
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
  depends_on                             = [azurerm_virtual_wan.vwan, azurerm_resource_group.vwan_rg, data.azurerm_virtual_wan.existing_vwan, data.azurerm_resource_group.existing_vwan_rg]
}

resource "azurerm_virtual_hub_connection" "transit_connection" {
  for_each                  = { for pair in local.vwan_pairs : pair.pair_key => pair }
  name                      = "${each.value.key}-to-vwan-${each.value.vwan_name}"
  virtual_hub_id            = azurerm_virtual_hub.hub[each.value.vwan_hub_name].id
  remote_virtual_network_id = each.value.type == "transit" ? "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${module.mc-transit[each.value.key].vpc.resource_group}/providers/Microsoft.Network/virtualNetworks/${module.mc-transit[each.value.key].vpc.name}" : "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${module.mc-spoke[each.value.key].vpc.resource_group}/providers/Microsoft.Network/virtualNetworks/${module.mc-spoke[each.value.key].vpc.name}"
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

  account                       = each.value.account
  az_support                    = false
  cloud                         = "azure"
  cidr                          = each.value.cidr
  region                        = var.region
  instance_size                 = each.value.instance_size
  name                          = each.key
  gw_name                       = local.stripped_names[each.key]
  local_as_number               = each.value.local_as_number
  enable_transit_firenet        = true
  enable_bgp_over_lan           = true
  bgp_ecmp                      = true
  enable_segmentation           = true
  enable_advertise_transit_cidr = true
  insane_mode                   = true
  resource_group                = azurerm_resource_group.transit_rg[each.key].name
  bgp_lan_interfaces_count      = length(local.vwan_names_per_transit[each.key]) > 0 ? min(length(local.vwan_names_per_transit[each.key]), 3) : 1
}

resource "aviatrix_firenet" "firenet" {
  for_each = {
    for k, v in var.transits : k => v
  }

  vpc_id             = module.mc-transit[each.key].vpc.vpc_id
  inspection_enabled = each.value.inspection_enabled
  egress_enabled     = each.value.egress_enabled
}


module "bootstrap" {

  for_each = {
    for fw in local.fws :
    "${local.stripped_names[fw.transit_key]}-${fw.type}-fw${fw.index + 1}" => fw
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

  authentication = {
    disable_password_authentication = true
    ssh_keys                        = each.value.ssh_keys
  }

  image = {
    version = each.value.firewall_image_version
  }

  virtual_machine = {
    zone      = null
    size      = each.value.fw_instance_size
    disk_name = "${each.key}-disk"

    bootstrap_options = jsonencode({
      storage_account_name               = module.bootstrap[each.key].storage_account_name
      storage_account_primary_access_key = module.bootstrap[each.key].storage_account_primary_access_key
    })

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

resource "aviatrix_firewall_instance_association" "fw_associations" {

  for_each = {
    for fw in local.fws :
    "${local.stripped_names[fw.transit_key]}-${fw.type}-fw${fw.index + 1}" => fw
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
  for_each                 = var.spokes
  source                   = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version                  = "8.0.0"
  account                  = each.value.account
  az_support               = false
  cloud                    = "azure"
  cidr                     = each.value.cidr
  region                   = var.region
  instance_size            = each.value.instance_size
  name                     = each.key
  gw_name                  = local.stripped_spoke_names[each.key]
  local_as_number          = try(each.value.enable_bgp, false) ? each.value.local_as_number : null
  bgp_ecmp                 = try(each.value.enable_bgp, false) ? true : null
  insane_mode              = true
  resource_group           = azurerm_resource_group.vnet_rg[each.key].name
  transit_gw               = local.spoke_transit_gw[each.key]
  enable_bgp               = try(each.value.enable_bgp, false)
  enable_bgp_over_lan      = try(each.value.enable_bgp, false) ? true : null
  bgp_lan_interfaces_count = try(each.value.enable_bgp, false) ? 1 : null
  inspection               = (contains(keys(local.spoke_to_firenet_transit), each.key) && try(var.transits[local.spoke_to_firenet_transit[each.key]].inspection_enabled, false)) ? true : false

  depends_on = [azurerm_resource_group.vnet_rg, module.mc-transit]

}

resource "time_sleep" "wait_for_hub_connection" {
  count           = length(local.vwan_pairs) > 0 ? 1 : 0
  depends_on      = [azurerm_virtual_hub_connection.transit_connection, module.mc-transit]
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


resource "aviatrix_transit_firenet_policy" "inspection_policies" {
  for_each = {
    for policy in local.inspection_policies : "${policy.transit_key}.${policy.vwan_hub_name}" => policy
    if try(var.transits[policy.transit_key].inspection_enabled, false)
  }

  transit_firenet_gateway_name = module.mc-transit[each.value.transit_key].transit_gateway.gw_name
  inspected_resource_name      = "SITE2CLOUD:${each.value.connection_name}"

  depends_on = [
    aviatrix_transit_external_device_conn.transit_external
  ]

}
