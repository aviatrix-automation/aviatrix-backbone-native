
variable "aws_ssm_region" {
  description = "AWS SSM region for parameter retrieval."
  type        = string
}


variable "region" {
  description = "Azure region for resource deployment."
  type        = string
}

variable "dns_primary" {
  description = "Primary DNS server for firewall bootstrap."
  type        = string
  default     = "168.63.129.16" # Azure DNS
}

variable "dns_secondary" {
  description = "Secondary DNS server for firewall bootstrap."
  type        = string
  default     = "8.8.8.8"
}


variable "subscription_id" {
  description = "Azure subscription ID."
  type        = string
}

variable "vwan_configs" {
  description = "Map of Virtual WAN configurations (new or existing)."
  type = map(object({
    resource_group_name = string
    location            = optional(string) # Required for new vWANs
    existing            = bool             # True for existing vWANs, false for new
  }))
  default = {}
}

variable "vnets" {
  description = "Map of VNET configurations for new or pre-existing VNETs to connect to Virtual WAN hubs."
  type = map(object({
    resource_group_name = optional(string)
    existing            = optional(bool, false)
    cidr                = optional(string)
    private_subnets     = optional(list(string), [])
    public_subnets      = optional(list(string), [])
    vwan_hub_name       = string
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.vnets :
      v.existing == false ? v.cidr != null : true
    ])
    error_message = "The 'cidr' attribute is required for new VNETs (when existing = false or not set)."
  }
}

variable "transits" {
  description = "Map of transit gateway configurations for Aviatrix."
  type = map(object({
    account                = string
    cidr                   = string
    instance_size          = string
    local_as_number        = number
    fw_amount              = optional(number, 0)
    fw_instance_size       = optional(string)
    firewall_image_version = optional(string)
    attach_firewall        = optional(bool, true)
    inspection_enabled     = optional(bool, false)
    egress_enabled         = optional(bool, true)
    ssh_keys               = optional(list(string), [])
    egress_source_ranges   = optional(list(string), ["0.0.0.0/0"])
    mgmt_source_ranges     = optional(list(string), ["0.0.0.0/0"])
    lan_source_ranges      = optional(list(string), ["0.0.0.0/0"])
    enable_password_auth   = optional(bool, false)
    admin_username         = optional(string, "panadmin")
    admin_password         = optional(string, "Avtx1234#")
    bootstrap_type         = optional(string, "file_share") # "file_share" or "panorama"
    # Per-transit Panorama overrides (uses global panorama_config if not set)
    panorama_dgname  = optional(string) # Override device group for this transit
    panorama_tplname = optional(string) # Override template stack for this transit
    panorama_cgname  = optional(string) # Override collector group for this transit
    file_shares = optional(map(object({
      name                   = string
      bootstrap_package_path = optional(string)
      bootstrap_files        = optional(map(string), {})
      bootstrap_files_md5    = optional(map(string), {})
      quota                  = optional(number)
      access_tier            = optional(string)
    })))
    bgp_manual_spoke_advertise_cidrs = optional(string)
    # Learned CIDRs approval configuration
    learned_cidr_approval       = optional(string, "false")
    learned_cidrs_approval_mode = optional(string, null)
    approved_learned_cidrs      = optional(list(string), null)
    vwan_connections = optional(list(object({
      vwan_name     = string
      vwan_hub_name = string
    })))
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.transits :
      v.bootstrap_type == "file_share" || v.bootstrap_type == "panorama"
    ])
    error_message = "bootstrap_type must be either 'file_share' or 'panorama'."
  }

  validation {
    condition = alltrue([
      for k, v in var.transits :
      v.bootstrap_type != "file_share" || v.file_shares != null
    ])
    error_message = "file_shares must be provided when bootstrap_type is 'file_share'."
  }
}

variable "spokes" {
  description = "Map of spoke gateway configurations for Aviatrix."
  type = map(object({
    account                          = string
    cidr                             = string
    instance_size                    = string
    enable_bgp                       = optional(bool, false)
    local_as_number                  = optional(number)
    included_advertised_spoke_routes = optional(string)       # CIDRs to advertise to transit (comma-separated)
    spoke_bgp_manual_advertise_cidrs = optional(list(string)) # CIDRs to advertise to BGP peers
    enable_max_performance           = optional(bool, true)   # Enable maximum performance for spoke gateway
    disable_route_propagation        = optional(bool, false)  # Disable route propagation on spoke subnets
    vwan_connections = optional(list(object({
      vwan_name     = string
      vwan_hub_name = string
    })))
  }))
  default = {}
}

variable "vwan_hubs" {
  description = "Map of Virtual WAN hub configurations."
  type = map(object({
    virtual_hub_cidr                       = string
    virtual_router_auto_scale_min_capacity = optional(number, 2)
    azure_asn                              = optional(number, 65515)
    propagate_default_route                = optional(bool, true) # Propagate 0.0.0.0/0 to connected VNets
  }))
  default = {}
}

variable "panorama_config" {
  description = "Panorama configuration for dynamic bootstrap. When used, firewalls will register with Panorama for configuration management."
  type = object({
    panorama_server    = string
    panorama_server2   = optional(string)
    tplname            = string
    dgname             = string
    vm_auth_key        = string
    auth_key_ttl       = optional(string, "8760") # Default to 1 year in hours
    cgname             = optional(string)         # Collector group name
    plugin_op_commands = optional(string)         # Plugin operational commands
    # Azure-specific options
    enable_dpdk         = optional(bool, true) # Enable DPDK for accelerated networking
    mgmt_interface_swap = optional(bool, true) # Swap management interface (required for Azure)
    # CSP plugin options for Azure metadata integration
    csp_pinid    = optional(string) # CSP PIN ID (for PAYG licensing)
    csp_pinvalue = optional(string) # CSP PIN value
  })
  default = null

  validation {
    condition = (
      var.panorama_config == null ||
      (try(var.panorama_config.tplname, "") != "" && try(var.panorama_config.dgname, "") != "")
    )
    error_message = "panorama_config.tplname and panorama_config.dgname must not be empty when panorama_config is provided."
  }
}

variable "external_devices" {
  description = "Map of external devices to connect to Aviatrix Transit Gateways via IPSec."
  type        = map(object({
    transit_key               = string
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
  }))
  default = {}
}

variable "tags" {
  description = "Map of tags to apply to all resources."
  type        = map(string)
  default     = {}
}