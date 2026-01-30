
variable "aws_ssm_region" {
  description = "AWS SSM region for parameter retrieval."
  type        = string
}

variable "tags" {
  description = "A map of tags to apply to resources."
  type        = map(string)
  default     = {}
}


variable "region" {
  description = "AWS region for resource deployment."
  type        = string
}

variable "transits" {
  description = "Map of transit gateway configurations."
  type        = map(object({
    account                     = string
    cidr                        = string
    instance_size               = string
    local_as_number             = number
    manual_bgp_advertised_cidrs = optional(set(string), [])
    fw_amount                   = optional(number, 0)
    fw_instance_size            = optional(string, "c5.xlarge")
    firewall_image              = optional(string, "")
    firewall_image_version      = optional(string, "")
    attach_firewall             = optional(bool, true)
    bootstrap_bucket_name_1     = optional(string, "")
    tgw_name                    = optional(string, "")
    inspection_enabled          = optional(bool, false)
    egress_enabled              = optional(bool, true)
    ssh_keys                    = optional(string, "")
    mgmt_source_ranges          = optional(set(string), ["0.0.0.0/0"])
    egress_source_ranges        = optional(set(string), ["0.0.0.0/0"])
    lan_source_ranges           = optional(set(string), ["0.0.0.0/0"])
    # Learned CIDRs approval configuration
    learned_cidr_approval      = optional(string, "false")
    learned_cidrs_approval_mode = optional(string, null)
    approved_learned_cidrs      = optional(list(string), null)
    inside_cidr_blocks = optional(map(object({
      connect_peer_1    = string
      ha_connect_peer_1 = string
      connect_peer_2    = string
      ha_connect_peer_2 = string
      connect_peer_3    = string
      ha_connect_peer_3 = string
      connect_peer_4    = string
      ha_connect_peer_4 = string
      connect_peer_5    = string
      ha_connect_peer_5 = string
      connect_peer_6    = string
      ha_connect_peer_6 = string
      connect_peer_7    = string
      ha_connect_peer_7 = string
      connect_peer_8    = string
      ha_connect_peer_8 = string
    })))
  }))
  default = {}
}

variable "tgws" {
  description = "Map of AWS Transit Gateway configurations."
  type        = map(object({
    amazon_side_asn             = optional(number)
    transit_gateway_cidr_blocks = optional(list(string), [])
    create_tgw                  = bool
    account_ids                 = optional(list(string))
  }))
  default = {}
}

variable "external_devices" {
  description = "Map of external devices to connect to Aviatrix Transit Gateways."
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
    # Custom IPsec algorithm parameters
    custom_algorithms         = optional(bool, false)
    pre_shared_key            = optional(string)
    backup_pre_shared_key     = optional(string)
    phase_1_authentication    = optional(string)
    phase_1_dh_groups         = optional(string)
    phase_1_encryption        = optional(string)
    phase_2_authentication    = optional(string)
    phase_2_dh_groups         = optional(string)
    phase_2_encryption        = optional(string)
    phase1_local_identifier   = optional(string)
    # BGP learned CIDRs and manual advertisement parameters
    enable_learned_cidrs_approval = optional(bool, false)
    approved_cidrs                = optional(set(string))
    manual_bgp_advertised_cidrs   = optional(list(string))
    disable_activemesh        = optional(bool, false)
  }))
  default = {}
}

variable "spokes" {
  description = "Map of spoke configurations keyed by the spoke name."
  type        = map(object({
    account                          = string
    attached                         = bool
    cidr                             = string
    customized_spoke_vpc_routes      = optional(string, "")
    included_advertised_spoke_routes = optional(string, "")
    insane_mode                      = optional(bool, true)
    enable_max_performance           = optional(bool, false)
    spoke_instance_size              = optional(string, "t3.large")
    enable_bgp                       = optional(bool, false)
    local_as_number                  = optional(string)
    allocate_new_eip                 = optional(bool, true)
    eip                              = optional(string)
    ha_eip                           = optional(string)
    use_existing_vpc                 = optional(bool, false)
    vpc_id                           = optional(string)
    gw_subnet                        = optional(string)
    hagw_subnet                      = optional(string)
    single_ip_snat                   = optional(bool, false)
    transit_key                      = string
  }))

  default = {}
}