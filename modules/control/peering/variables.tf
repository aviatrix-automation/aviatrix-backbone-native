
variable "aws_ssm_region" {
  description = "AWS SSM region for parameter retrieval."
  type        = string
}

variable "enable_peering_over_private_network" {
  description = "Enable peering over private network. Only applies when two transit gateways are in Insane Mode and different cloud types."
  type        = bool
  default     = false
}

variable "enable_insane_mode_encryption_over_internet" {
  description = "Enable Insane Mode Encryption over Internet. Transit gateways must be in Insane Mode. Only supported between AWS and Azure."
  type        = bool
  default     = null
}

variable "enable_max_performance" {
  description = "Enable maximum amount of HPE tunnels. Only valid when transit gateways are in Insane Mode and same cloud type."
  type        = bool
  default     = true
}

variable "enable_single_tunnel_mode" {
  description = "Enable peering with Single-Tunnel mode. Only applies with enable_peering_over_private_network."
  type        = bool
  default     = false
}

variable "tunnel_count" {
  description = "Number of public tunnels for Insane Mode Encryption over Internet. Valid range: 2-20. Only for AWS-Azure peerings."
  type        = number
  default     = null
}