
variable "aws_ssm_region" {
  description = "AWS SSM region for parameter retrieval."
  type        = string
}

# Same-cloud peering configuration
variable "same_cloud_enable_peering_over_private_network" {
  description = "Enable peering over private network for same-cloud peering. Only applies when two transit gateways are in Insane Mode."
  type        = bool
  default     = false
}

variable "same_cloud_enable_max_performance" {
  description = "Enable maximum amount of HPE tunnels for same-cloud peering. Only valid when transit gateways are in Insane Mode and same cloud type. Supported for AWS, GCP, and Azure."
  type        = bool
  default     = true
}

variable "same_cloud_enable_single_tunnel_mode" {
  description = "Enable peering with Single-Tunnel mode for same-cloud peering. Only applies with enable_peering_over_private_network."
  type        = bool
  default     = false
}

# Cross-cloud peering configuration
variable "cross_cloud_enable_peering_over_private_network" {
  description = "Enable peering over private network for cross-cloud peering. Only applies when two transit gateways are in Insane Mode and different cloud types."
  type        = bool
  default     = false
}

variable "cross_cloud_enable_insane_mode_encryption_over_internet" {
  description = "Enable Insane Mode Encryption over Internet for cross-cloud peering. Transit gateways must be in Insane Mode. Supported among AWS, GCP, and Azure."
  type        = bool
  default     = null
}

variable "cross_cloud_enable_single_tunnel_mode" {
  description = "Enable peering with Single-Tunnel mode for cross-cloud peering. Only applies with enable_peering_over_private_network."
  type        = bool
  default     = false
}

variable "cross_cloud_tunnel_count" {
  description = "Number of public tunnels for cross-cloud Insane Mode Encryption over Internet. Valid range: 2-20. Supported for cross-cloud peerings with HPE."
  type        = number
  default     = null
}