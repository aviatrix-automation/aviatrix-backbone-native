locals {
  bgp_lan_subnets_order = {
    for transit in var.transits :
    transit.gw_name => keys(transit.bgp_lan_subnets)
  }

  fws = flatten([
    for transit in var.transits : concat(
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
      }]
    )
  ])

  inspection_policies = flatten([
    for transit in var.transits : [
      for intf_type, subnet in transit.bgp_lan_subnets : {
        transit_key     = transit.gw_name
        connection_name = "external-${intf_type}-${transit.gw_name}"
        pair_key        = "${transit.gw_name}-bgp-lan-${intf_type}"
      } if subnet != "" &&
      contains([for hub in var.ncc_hubs : hub.name if hub.create], intf_type) &&
      transit.fw_amount > 0
    ]
  ])

  hub_topologies = {
    for hub in var.ncc_hubs :
    hub.name => hub.preset_topology
  }
}

resource "google_network_connectivity_hub" "ncc_hubs" {
  for_each = { for hub in var.ncc_hubs : hub.name => hub }

  name            = "ncc-${each.value.name}"
  project         = var.project_id
  description     = "NCC hub for ${each.value.name}"
  preset_topology = each.value.preset_topology
}

resource "google_network_connectivity_group" "center_group" {
  for_each = { for hub in var.ncc_hubs : hub.name => hub if hub.create && hub.preset_topology == "STAR" }

  name    = "center"
  hub     = google_network_connectivity_hub.ncc_hubs[each.key].id
  project = var.project_id

  auto_accept {
    auto_accept_projects = distinct([
      for transit in var.transits : transit.project_id
      if lookup(transit.bgp_lan_subnets, each.key, "") != ""
    ])
  }

  depends_on = [google_network_connectivity_hub.ncc_hubs]
}

resource "google_network_connectivity_group" "edge_group" {
  for_each = { for hub in var.ncc_hubs : hub.name => hub if hub.create && hub.preset_topology == "STAR" }

  name    = "edge"
  hub     = google_network_connectivity_hub.ncc_hubs[each.key].id
  project = var.project_id

  auto_accept {
    auto_accept_projects = distinct([
      for spoke in var.spokes : spoke.project_id
      if spoke.ncc_hub == each.key
    ])
  }

  depends_on = [google_network_connectivity_hub.ncc_hubs]
}

resource "google_network_connectivity_group" "default_group" {
  for_each = { for hub in var.ncc_hubs : hub.name => hub if hub.create && hub.preset_topology == "MESH" }

  name    = "default"
  hub     = google_network_connectivity_hub.ncc_hubs[each.key].id
  project = var.project_id

  auto_accept {
    auto_accept_projects = distinct(flatten([
      [for transit in var.transits : transit.project_id if lookup(transit.bgp_lan_subnets, each.key, "") != ""],
      [for spoke in var.spokes : spoke.project_id if spoke.ncc_hub == each.key]
    ]))
  }

  depends_on = [google_network_connectivity_hub.ncc_hubs]
}

resource "google_network_connectivity_spoke" "avx_spokes_star" {
  for_each = { for pair in flatten([
    for transit in var.transits : [
      for intf_type, subnet in transit.bgp_lan_subnets : {
        gw_name    = transit.gw_name
        project_id = transit.project_id
        region     = transit.region
        subnet     = subnet
        intf_type  = intf_type
      } if subnet != "" && contains([for hub in var.ncc_hubs : hub.name if hub.create], intf_type) && local.hub_topologies[intf_type] == "STAR"
    ]
  ]) : "${pair.gw_name}-bgp-lan-${pair.intf_type}" => pair }

  name     = "${each.value.gw_name}-bgp-lan-${each.value.intf_type}-to-avx"
  project  = each.value.project_id
  location = each.value.region
  hub      = google_network_connectivity_hub.ncc_hubs[each.value.intf_type].id
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
    for transit in var.transits : [
      for intf_type, subnet in transit.bgp_lan_subnets : {
        gw_name    = transit.gw_name
        project_id = transit.project_id
        region     = transit.region
        subnet     = subnet
        intf_type  = intf_type
      } if subnet != "" && contains([for hub in var.ncc_hubs : hub.name if hub.create], intf_type) && local.hub_topologies[intf_type] == "MESH"
    ]
  ]) : "${pair.gw_name}-bgp-lan-${pair.intf_type}" => pair }

  name     = "${each.value.gw_name}-bgp-lan-${each.value.intf_type}-to-avx"
  project  = each.value.project_id
  location = each.value.region
  hub      = google_network_connectivity_hub.ncc_hubs[each.value.intf_type].id
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
  hub      = google_network_connectivity_hub.ncc_hubs[each.value.ncc_hub].id
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
  hub      = google_network_connectivity_hub.ncc_hubs[each.value.ncc_hub].id
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
    for transit in var.transits : [
      for intf_type, subnet in transit.bgp_lan_subnets : {
        gw_name    = transit.gw_name
        project_id = transit.project_id
        region     = transit.region
        subnet     = subnet
        intf_type  = intf_type
      } if subnet != "" && contains([for hub in var.ncc_hubs : hub.name if hub.create], intf_type)
    ]
  ]) : "${pair.gw_name}-bgp-lan-${pair.intf_type}" => pair }

  name          = "${each.value.gw_name}-bgp-lan-${each.value.intf_type}-subnet"
  project       = each.value.project_id
  region        = each.value.region
  network       = google_compute_network.bgp_lan_vpcs[each.value.intf_type].self_link
  ip_cidr_range = each.value.subnet
  depends_on    = [google_compute_network.bgp_lan_vpcs]

  lifecycle {
    ignore_changes = [log_config]
  }

}

resource "google_compute_router" "bgp_lan_routers" {
  for_each = { for pair in flatten([
    for transit in var.transits : [
      for intf_type, subnet in transit.bgp_lan_subnets : {
        gw_name    = transit.gw_name
        project_id = transit.project_id
        region     = transit.region
        subnet     = subnet
        intf_type  = intf_type
        asn        = transit.cloud_router_asn
      } if subnet != "" && contains([for hub in var.ncc_hubs : hub.name if hub.create], intf_type)
    ]
  ]) : "${pair.gw_name}-bgp-lan-${pair.intf_type}" => pair }

  name    = "${each.value.gw_name}-bgp-lan-${each.value.intf_type}-router"
  project = each.value.project_id
  region  = each.value.region
  network = google_compute_network.bgp_lan_vpcs[each.value.intf_type].self_link

  bgp {
    asn = each.value.asn
  }

  depends_on = [google_compute_network.bgp_lan_vpcs]
}

resource "google_compute_address" "bgp_lan_addresses" {
  for_each = { for pair in flatten([
    for transit in var.transits : [
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
  subnetwork   = google_compute_subnetwork.bgp_lan_subnets["${each.value.gw_name}-bgp-lan-${each.value.intf_type}"].self_link
  address_type = "INTERNAL"

  depends_on = [google_compute_subnetwork.bgp_lan_subnets]
}

resource "google_compute_router_interface" "bgp_lan_interfaces_pri" {
  for_each = { for pair in flatten([
    for transit in var.transits : [
      for intf_type, subnet in transit.bgp_lan_subnets : {
        gw_name    = transit.gw_name
        project_id = transit.project_id
        region     = transit.region
        subnet     = subnet
        intf_type  = intf_type
      } if subnet != "" && contains([for hub in var.ncc_hubs : hub.name if hub.create], intf_type)
    ]
  ]) : "${pair.gw_name}-bgp-lan-${pair.intf_type}" => pair }

  name                = "${each.value.gw_name}-bgp-lan-${each.value.intf_type}-int-pri"
  project             = each.value.project_id
  region              = each.value.region
  router              = google_compute_router.bgp_lan_routers[each.key].name
  subnetwork          = google_compute_subnetwork.bgp_lan_subnets[each.key].self_link
  private_ip_address  = google_compute_address.bgp_lan_addresses["${each.key}-pri"].address
  redundant_interface = google_compute_router_interface.bgp_lan_interfaces_ha[each.key].name

  depends_on = [
    google_compute_router.bgp_lan_routers,
    google_compute_subnetwork.bgp_lan_subnets,
    google_compute_address.bgp_lan_addresses,
    google_compute_router_interface.bgp_lan_interfaces_ha
  ]
}

resource "google_compute_router_interface" "bgp_lan_interfaces_ha" {
  for_each = { for pair in flatten([
    for transit in var.transits : [
      for intf_type, subnet in transit.bgp_lan_subnets : {
        gw_name    = transit.gw_name
        project_id = transit.project_id
        region     = transit.region
        subnet     = subnet
        intf_type  = intf_type
      } if subnet != "" && contains([for hub in var.ncc_hubs : hub.name if hub.create], intf_type)
    ]
  ]) : "${pair.gw_name}-bgp-lan-${pair.intf_type}" => pair }

  name               = "${each.value.gw_name}-bgp-lan-${each.value.intf_type}-int-hagw"
  project            = each.value.project_id
  region             = each.value.region
  router             = google_compute_router.bgp_lan_routers[each.key].name
  subnetwork         = google_compute_subnetwork.bgp_lan_subnets[each.key].self_link
  private_ip_address = google_compute_address.bgp_lan_addresses["${each.key}-ha"].address

  depends_on = [
    google_compute_router.bgp_lan_routers,
    google_compute_subnetwork.bgp_lan_subnets,
    google_compute_address.bgp_lan_addresses
  ]
}

resource "google_compute_firewall" "bgp_lan_bgp" {
  for_each = { for hub in var.ncc_hubs : hub.name => hub if hub.create }

  name    = "bgp-lan-${each.value.name}-allow-bgp"
  project = var.project_id
  network = google_compute_network.bgp_lan_vpcs[each.value.name].self_link

  allow {
    protocol = "tcp"
    ports    = ["179"]
  }

  source_ranges = [for s in google_compute_subnetwork.bgp_lan_subnets : s.ip_cidr_range if s.network == google_compute_network.bgp_lan_vpcs[each.value.name].self_link]
  target_tags   = ["bgp-lan"]

  depends_on = [
    google_compute_network.bgp_lan_vpcs,
    google_compute_subnetwork.bgp_lan_subnets
  ]
}

module "mc_transit" {
  for_each = { for transit in var.transits : transit.gw_name => transit }

  source  = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version = "8.0.0"

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
  enable_learned_cidrs_approval = each.value.enable_learned_cidrs_approval
  learned_cidrs_approval_mode   = each.value.learned_cidrs_approval_mode
  approved_learned_cidrs        = length(each.value.approved_learned_cidrs) > 0 ? each.value.approved_learned_cidrs : null
  bgp_lan_interfaces = [
    for intf_type in [for hub in var.ncc_hubs : hub.name if hub.create] : {
      vpc_id     = google_compute_network.bgp_lan_vpcs[intf_type].name
      subnet     = each.value.bgp_lan_subnets[intf_type]
      create_vpc = false
    } if lookup(each.value.bgp_lan_subnets, intf_type, "") != ""
  ]

  ha_bgp_lan_interfaces = [
    for intf_type in [for hub in var.ncc_hubs : hub.name if hub.create] : {
      vpc_id     = google_compute_network.bgp_lan_vpcs[intf_type].name
      subnet     = each.value.bgp_lan_subnets[intf_type]
      create_vpc = false
    } if lookup(each.value.bgp_lan_subnets, intf_type, "") != ""
  ]
  depends_on = [
    google_compute_network.bgp_lan_vpcs,
    google_compute_subnetwork.bgp_lan_subnets
  ]
}

resource "google_compute_network" "mgmt_vpcs" {
  for_each = { for transit in var.transits : transit.gw_name => transit if transit.fw_amount > 0 }

  name                    = "${each.value.name}-mgmt-vpc"
  project                 = each.value.project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "mgmt_subnets" {
  for_each = { for transit in var.transits : transit.gw_name => transit if transit.fw_amount > 0 }

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
  for_each = { for transit in var.transits : transit.gw_name => transit if transit.fw_amount > 0 }

  name                    = "${each.value.name}-egress-vpc"
  project                 = each.value.project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "egress_subnets" {
  for_each = { for transit in var.transits : transit.gw_name => transit if transit.fw_amount > 0 }

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
  for_each = { for transit in var.transits : transit.gw_name => transit if transit.fw_amount > 0 }

  name    = "${each.key}-mgmt-allow"
  project = each.value.project_id
  network = google_compute_network.mgmt_vpcs[each.key].id

  allow {
    protocol = "all"
  }

  source_ranges = each.value.source_ranges
}


resource "google_compute_firewall" "egress_firewall_rules" {
  for_each = { for transit in var.transits : transit.gw_name => transit if transit.fw_amount > 0 }

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
  files           = each.value.files
}

module "pan_fw" {
  # NOTE: Previously referenced local module at ../../modules/terraform-google-swfw-modules/modules/vmseries
  # Reverted to registry source as local module was not committed to repo
  source  = "PaloAltoNetworks/swfw-modules/google//modules/vmseries"
  version = "2.0.11"


  for_each = { for fw in local.fws : "${fw.gw_name}-${fw.type}-fw${fw.index + 1}" => fw }

  project = each.value.project_id
  zone    = each.value.zone
  region  = each.value.region

  name         = each.key
  custom_image = "${each.value.firewall_image}-${each.value.firewall_image_version}"
  machine_type = each.value.fw_instance_size

  bootstrap_options = {
    type                                 = "dhcp-client"
    mgmt-interface-swap                  = "enable"
    op-command-modes                     = "mgmt-interface-swap"
    vmseries-bootstrap-gce-storagebucket = module.swfw-modules_bootstrap[each.key].bucket_name
  }

  network_interfaces = [
    {
      subnetwork       = google_compute_subnetwork.egress_subnets[each.value.gw_name].self_link
      create_public_ip = true
    },
    {
      subnetwork       = google_compute_subnetwork.mgmt_subnets[each.value.gw_name].self_link
      create_public_ip = true
    },
    {
      subnetwork       = data.google_compute_subnetwork.lan_subnetwork[each.value.name].self_link
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
  for_each = { for transit in var.transits : transit.gw_name => transit if transit.fw_amount > 0 }

  vpc_id             = module.mc_transit[each.key].vpc.vpc_id
  inspection_enabled = each.value.inspection_enabled
  egress_enabled     = each.value.egress_enabled
}

resource "aviatrix_firewall_instance_association" "fw_associations" {
  for_each = { for fw in local.fws : "${fw.gw_name}-${fw.type}-fw${fw.index + 1}" => fw if var.transits[fw.gw_name].attach_firewall }

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
    for transit in var.transits : [
      for intf_type, subnet in transit.bgp_lan_subnets : {
        gw_name      = transit.gw_name
        project_id   = transit.project_id
        region       = transit.region
        subnet       = subnet
        intf_type    = intf_type
        aviatrix_asn = transit.aviatrix_gw_asn
      } if subnet != "" && contains([for hub in var.ncc_hubs : hub.name if hub.create], intf_type)
    ]
  ]) : "${pair.gw_name}-bgp-lan-${pair.intf_type}" => pair }

  name                      = "${each.value.gw_name}-bgp-lan-${each.value.intf_type}-peer-pri"
  project                   = each.value.project_id
  region                    = each.value.region
  router                    = google_compute_router.bgp_lan_routers[each.key].name
  interface                 = google_compute_router_interface.bgp_lan_interfaces_pri[each.key].name
  peer_ip_address           = module.mc_transit[each.value.gw_name].transit_gateway.bgp_lan_ip_list[index(local.bgp_lan_subnets_order[each.value.gw_name], each.value.intf_type)]
  peer_asn                  = each.value.aviatrix_asn
  advertised_route_priority = 100
  router_appliance_instance = "projects/${each.value.project_id}/zones/${module.mc_transit[each.value.gw_name].transit_gateway.vpc_reg}/instances/${each.value.gw_name}"

  depends_on = [
    google_compute_router.bgp_lan_routers,
    google_compute_router_interface.bgp_lan_interfaces_pri,
    module.mc_transit
  ]
}

resource "google_compute_router_peer" "bgp_lan_peers_ha" {
  for_each = { for pair in flatten([
    for transit in var.transits : [
      for intf_type, subnet in transit.bgp_lan_subnets : {
        gw_name      = transit.gw_name
        project_id   = transit.project_id
        region       = transit.region
        subnet       = subnet
        intf_type    = intf_type
        aviatrix_asn = transit.aviatrix_gw_asn
      } if subnet != "" && contains([for hub in var.ncc_hubs : hub.name if hub.create], intf_type)
    ]
  ]) : "${pair.gw_name}-bgp-lan-${pair.intf_type}" => pair }

  name                      = "${each.value.gw_name}-bgp-lan-${each.value.intf_type}-peer-ha"
  project                   = each.value.project_id
  region                    = each.value.region
  router                    = google_compute_router.bgp_lan_routers[each.key].name
  interface                 = google_compute_router_interface.bgp_lan_interfaces_ha[each.key].name
  peer_ip_address           = module.mc_transit[each.value.gw_name].transit_gateway.ha_bgp_lan_ip_list[index(local.bgp_lan_subnets_order[each.value.gw_name], each.value.intf_type)]
  peer_asn                  = each.value.aviatrix_asn
  advertised_route_priority = 100
  router_appliance_instance = "projects/${each.value.project_id}/zones/${module.mc_transit[each.value.gw_name].transit_gateway.ha_zone}/instances/${each.value.gw_name}-hagw"

  depends_on = [
    google_compute_router.bgp_lan_routers,
    google_compute_router_interface.bgp_lan_interfaces_ha,
    module.mc_transit
  ]
}

resource "google_compute_router_peer" "bgp_lan_peers_pri_to_ha" {
  for_each = { for pair in flatten([
    for transit in var.transits : [
      for intf_type, subnet in transit.bgp_lan_subnets : {
        gw_name      = transit.gw_name
        project_id   = transit.project_id
        region       = transit.region
        subnet       = subnet
        intf_type    = intf_type
        aviatrix_asn = transit.aviatrix_gw_asn
      } if subnet != "" && contains([for hub in var.ncc_hubs : hub.name if hub.create], intf_type)
    ]
  ]) : "${pair.gw_name}-bgp-lan-${pair.intf_type}" => pair }

  name                      = "${each.value.gw_name}-bgp-lan-${each.value.intf_type}-peer-pri-to-ha"
  project                   = each.value.project_id
  region                    = each.value.region
  router                    = google_compute_router.bgp_lan_routers[each.key].name
  interface                 = google_compute_router_interface.bgp_lan_interfaces_ha[each.key].name
  peer_ip_address           = module.mc_transit[each.value.gw_name].transit_gateway.bgp_lan_ip_list[index(local.bgp_lan_subnets_order[each.value.gw_name], each.value.intf_type)]
  peer_asn                  = each.value.aviatrix_asn
  advertised_route_priority = 100
  router_appliance_instance = "projects/${each.value.project_id}/zones/${module.mc_transit[each.value.gw_name].transit_gateway.vpc_reg}/instances/${each.value.gw_name}"

  depends_on = [
    google_compute_router.bgp_lan_routers,
    google_compute_router_interface.bgp_lan_interfaces_ha,
    module.mc_transit
  ]
}

resource "google_compute_router_peer" "bgp_lan_peers_ha_to_pri" {
  for_each = { for pair in flatten([
    for transit in var.transits : [
      for intf_type, subnet in transit.bgp_lan_subnets : {
        gw_name      = transit.gw_name
        project_id   = transit.project_id
        region       = transit.region
        subnet       = subnet
        intf_type    = intf_type
        aviatrix_asn = transit.aviatrix_gw_asn
      } if subnet != "" && contains([for hub in var.ncc_hubs : hub.name if hub.create], intf_type)
    ]
  ]) : "${pair.gw_name}-bgp-lan-${pair.intf_type}" => pair }

  name                      = "${each.value.gw_name}-bgp-lan-${each.value.intf_type}-peer-ha-to-pri"
  project                   = each.value.project_id
  region                    = each.value.region
  router                    = google_compute_router.bgp_lan_routers[each.key].name
  interface                 = google_compute_router_interface.bgp_lan_interfaces_pri[each.key].name
  peer_ip_address           = module.mc_transit[each.value.gw_name].transit_gateway.ha_bgp_lan_ip_list[index(local.bgp_lan_subnets_order[each.value.gw_name], each.value.intf_type)]
  peer_asn                  = each.value.aviatrix_asn
  advertised_route_priority = 100
  router_appliance_instance = "projects/${each.value.project_id}/zones/${module.mc_transit[each.value.gw_name].transit_gateway.ha_zone}/instances/${each.value.gw_name}-hagw"

  depends_on = [
    google_compute_router.bgp_lan_routers,
    google_compute_router_interface.bgp_lan_interfaces_pri,
    module.mc_transit
  ]
}

resource "aviatrix_transit_external_device_conn" "bgp_lan_connections" {
  for_each = { for pair in flatten([
    for transit in var.transits : [
      for intf_type, subnet in transit.bgp_lan_subnets : {
        gw_name                     = transit.gw_name
        project_id                  = transit.project_id
        region                      = transit.region
        subnet                      = subnet
        intf_type                   = intf_type
        manual_bgp_advertised_cidrs = transit.manual_bgp_advertised_cidrs
      } if subnet != "" && contains([for hub in var.ncc_hubs : hub.name if hub.create], intf_type)
    ]
  ]) : "${pair.gw_name}-bgp-lan-${pair.intf_type}" => pair }
  vpc_id                    = module.mc_transit[each.value.gw_name].transit_gateway.vpc_id
  connection_name           = "external-${each.value.intf_type}-${each.value.gw_name}"
  gw_name                   = each.value.gw_name
  connection_type           = "bgp"
  tunnel_protocol           = "LAN"
  bgp_local_as_num          = [for t in var.transits : t.aviatrix_gw_asn if t.gw_name == each.value.gw_name][0]
  bgp_remote_as_num         = [for t in var.transits : t.cloud_router_asn if t.gw_name == each.value.gw_name][0]
  remote_lan_ip             = google_compute_address.bgp_lan_addresses["${each.key}-pri"].address
  local_lan_ip              = module.mc_transit[each.value.gw_name].transit_gateway.bgp_lan_ip_list[index(local.bgp_lan_subnets_order[each.value.gw_name], each.value.intf_type)]
  ha_enabled                = true
  backup_bgp_remote_as_num  = [for t in var.transits : t.cloud_router_asn if t.gw_name == each.value.gw_name][0]
  backup_remote_lan_ip      = google_compute_address.bgp_lan_addresses["${each.key}-ha"].address
  backup_local_lan_ip       = module.mc_transit[each.value.gw_name].transit_gateway.ha_bgp_lan_ip_list[index(local.bgp_lan_subnets_order[each.value.gw_name], each.value.intf_type)]
  enable_bgp_lan_activemesh = true

  manual_bgp_advertised_cidrs = each.value.manual_bgp_advertised_cidrs

  depends_on = [
    module.mc_transit,
    google_compute_address.bgp_lan_addresses
  ]
}

resource "aviatrix_transit_firenet_policy" "inspection_policies" {
  for_each = {
    for policy in local.inspection_policies : policy.pair_key => policy

    if lookup(
      { for t in var.transits : t.gw_name => t.inspection_enabled },
      policy.transit_key,
      false
    )

  }

  transit_firenet_gateway_name = module.mc_transit[each.value.transit_key].transit_gateway.gw_name
  inspected_resource_name      = "SITE2CLOUD:${each.value.connection_name}"

  depends_on = [
    aviatrix_firenet.firenet,
    aviatrix_firewall_instance_association.fw_associations,
    aviatrix_transit_external_device_conn.bgp_lan_connections
  ]
}

module "mc-spoke" {
  depends_on = [module.mc_transit]
  for_each   = var.aviatrix_spokes
  source     = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version    = "8.0.0"

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
  enable_bgp       = each.value.enable_bgp
  local_as_number  = each.value.enable_bgp ? each.value.local_as_number : null
  allocate_new_eip = each.value.allocate_new_eip
  eip              = each.value.eip
  ha_eip           = each.value.ha_eip
  single_ip_snat   = each.value.single_ip_snat
}
