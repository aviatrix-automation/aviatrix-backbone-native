
variable "aws_ssm_region" {
  description = "AWS SSM region for parameter retrieval."
  type        = string
}

variable "project_id" {
  type        = string
  description = "GCP project ID for NCC hubs and for Palo Alto Network bootstrap storage buckets"
  validation {
    condition     = length(var.project_id) > 0
    error_message = "project_id must be non-empty."
  }
}

variable "transits" {
  type = list(object({
    gw_name                     = string
    project_id                  = string
    region                      = string
    name                        = string
    vpc_cidr                    = string
    gw_size                     = string
    access_account_name         = string
    cloud_router_asn            = number
    aviatrix_gw_asn             = number
    bgp_lan_subnets             = map(string)
    fw_amount                   = optional(number, 0)
    fw_instance_size            = optional(string, "n2-standard-4")
    firewall_image              = optional(string, "")
    firewall_image_version      = optional(string, "")
    attach_firewall             = optional(bool, true)
    lan_cidr                    = optional(string, "")
    mgmt_cidr                   = optional(string, "")
    egress_cidr                 = optional(string, "")
    manual_bgp_advertised_cidrs = optional(set(string), [])
    inspection_enabled          = optional(bool, false)
    egress_enabled              = optional(bool, true)
    zone                        = optional(string, "")
    ha_zone                     = optional(string, "")
    ssh_keys                    = optional(string, "admin:")
    source_ranges               = optional(set(string), ["0.0.0.0/0"])
    service_account             = optional(string, "")
    name_prefix                 = optional(string, "paloaltonetworks-firewall-bootstrap-")
    files                       = optional(map(string), {})
    # Learned CIDRs approval configuration
    learned_cidr_approval       = optional(string, "false")
    learned_cidrs_approval_mode = optional(string, null)
    approved_learned_cidrs      = optional(list(string), null)
  }))
  validation {
    condition = alltrue([
      for t in var.transits : length(t.bgp_lan_subnets) > 0
    ])
    error_message = "At least one BGP LAN subnet must be provided for each transit."
  }
  validation {
    condition = alltrue([
      for t in var.transits : alltrue([
        for s in values(t.bgp_lan_subnets) : s == "" || can(cidrhost(s, 1))
      ])
    ])
    error_message = "All non-empty BGP LAN subnets must be valid CIDR ranges."
  }
  validation {
    condition = alltrue([
      for t in var.transits : alltrue([
        for k in keys(t.bgp_lan_subnets) : contains([for h in var.ncc_hubs : h.name], k)
      ])
    ])
    error_message = "All bgp_lan_subnets keys must match an NCC hub name."
  }
  validation {
    condition     = alltrue([for t in var.transits : length(t.gw_name) <= 30])
    error_message = "gw_name must be 30 characters or less to ensure VPC/subnet names fit within GCP limits."
  }
  validation {
    condition     = alltrue([for t in var.transits : length(t.access_account_name) > 0])
    error_message = "access_account_name must be provided for each transit."
  }
  validation {
    condition = alltrue([
      for t in var.transits :
      contains(["n2-highcpu-8", "n1-standard-8", "c2-standard-8", "n4-highcpu-8", "n4-standard-8", "c2-standard-8"], t.gw_size)
    ])
    error_message = "gw_size must be an instance type supporting at least 5 network interfaces (e.g., n2-highcpu-8, n1-standard-8, c2-standard-8)."
  }
  validation {
    condition = alltrue([
      for t in var.transits :
      t.cloud_router_asn >= 64512 && t.cloud_router_asn <= 65534 || t.cloud_router_asn == 16550
    ])
    error_message = "cloud_router_asn must be a private ASN between 64512 and 6553 or 16550"
  }
  validation {
    condition = alltrue([
      for t in var.transits :
      t.aviatrix_gw_asn >= 64512 && t.aviatrix_gw_asn <= 65534 && t.aviatrix_gw_asn != t.cloud_router_asn
    ])
    error_message = "aviatrix_gw_asn must be a private ASN between 64512 and 65534 and must not match cloud_router_asn."
  }
}

variable "spokes" {
  type = list(object({
    vpc_name   = string
    project_id = string
    ncc_hub    = string
  }))
  default = []
  validation {
    condition = alltrue([
      for s in var.spokes : contains([for h in var.ncc_hubs : h.name if h.create], s.ncc_hub)
    ])
    error_message = "ncc_hub must match an NCC hub name with create = true."
  }
  validation {
    condition = alltrue([
      for s in var.spokes : length(s.vpc_name) > 0 && length(regexall("^[a-z][-a-z0-9]*[a-z0-9]$", s.vpc_name)) > 0
    ])
    error_message = "vpc_name must start with a lowercase letter, contain only lowercase letters, numbers, or hyphens, and end with a letter or number."
  }
  validation {
    condition     = length(var.spokes) == length(distinct([for s in var.spokes : "${s.vpc_name}-${s.ncc_hub}"]))
    error_message = "Each vpc_name must be attached to a given ncc_hub only once."
  }
}

variable "aviatrix_spokes" {
  description = "Map of Aviatrix spoke gateway configurations keyed by the spoke name. Note: BGP is NOT supported for GCP spoke gateways."
  type = map(object({
    account                          = string
    region                           = string
    attached                         = bool
    cidr                             = string
    customized_spoke_vpc_routes      = optional(string, "")
    included_advertised_spoke_routes = optional(string, "")
    insane_mode                      = optional(bool, true)
    enable_max_performance           = optional(bool, false)
    spoke_instance_size              = optional(string, "n1-standard-1")
    allocate_new_eip                 = optional(bool, false)
    eip                              = optional(string)
    ha_eip                           = optional(string)
    single_ip_snat                   = optional(bool, false)
    transit_gw_name                  = string
  }))

  default = {}
}

variable "ncc_hubs" {
  description = "List of NCC hubs to create"
  type = list(object({
    name            = string
    create          = optional(bool, true)
    preset_topology = optional(string, "STAR")
  }))
  default = []

  validation {
    condition = alltrue([
      for hub in var.ncc_hubs : contains(["STAR", "MESH"], hub.preset_topology)
    ])
    error_message = "Each hub's preset_topology must be 'STAR' or 'MESH'."
  }
}

variable "external_devices" {
  description = "Map of external devices to connect to Aviatrix Transit Gateways via IPSec."
  type = map(object({
    transit_gw_name           = string
    connection_name           = string
    remote_gateway_ip         = string
    bgp_enabled               = bool
    bgp_remote_asn            = optional(string)
    local_tunnel_cidr         = optional(string)
    remote_tunnel_cidr        = optional(string)
    ha_enabled                = bool
    backup_remote_gateway_ip  = optional(string)
    backup_local_tunnel_cidr  = optional(string)
    backup_remote_tunnel_cidr = optional(string)
    enable_ikev2              = optional(bool)
    inspected_by_firenet      = bool
    # Custom IPsec algorithm parameters
    custom_algorithms         = optional(bool, false)
    pre_shared_key            = optional(string)
    phase_1_authentication    = optional(string)
    phase_1_dh_groups         = optional(string)
    phase_1_encryption        = optional(string)
    phase_2_authentication    = optional(string)
    phase_2_dh_groups         = optional(string)
    phase_2_encryption        = optional(string)
    phase1_local_identifier   = optional(string)
  }))
  default = {}
}