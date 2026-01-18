
variable "aws_ssm_region" {
  description = "AWS SSM region for parameter retrieval."
  type        = string
}


variable "region" {
  description = "Azure region for resource deployment."
  type        = string
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
    inspection_enabled     = optional(bool, false)
    egress_enabled         = optional(bool, false)
    ssh_keys               = optional(list(string), [])
    egress_source_ranges   = optional(list(string), ["0.0.0.0/0"])
    mgmt_source_ranges     = optional(list(string), ["0.0.0.0/0"])
    lan_source_ranges      = optional(list(string), ["0.0.0.0/0"])
    file_shares = optional(map(object({
      name                   = string
      bootstrap_package_path = optional(string)
      bootstrap_files        = optional(map(string), {})
      bootstrap_files_md5    = optional(map(string), {})
      quota                  = optional(number)
      access_tier            = optional(string)
    })))
    vwan_connections = optional(list(object({
      vwan_name     = string
      vwan_hub_name = string
    })))
  }))
  default = {}
}

variable "spokes" {
  description = "Map of spoke gateway configurations for Aviatrix."
  type = map(object({
    account         = string
    cidr            = string
    instance_size   = string
    enable_bgp      = optional(bool, false)
    local_as_number = optional(number)
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
    virtual_router_auto_scale_min_capacity = optional(number)
    azure_asn                              = optional(number, 65515)
  }))
  default = {}
}