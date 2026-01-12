
# Required
variable "vpc_name" {
  description = "VPC name"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

# Optional
variable "secondary_vpc_cidr" {
  description = "Secondary VPC CIDR block"
  type        = string
  default     = ""
}

variable "number_subnet_pairs" {
  description = "Number of subnet pairs for VPC CIDR"
  type        = number
  default     = 2
}

variable "number_subnet_secondary" {
  description = "Number of private subnets for secondary VPC CIDR"
  type        = number
  default     = 0
}

variable "subnet_size" {
  description = "Subnet size in CIDR format"
  type        = number
  default     = 28
}

variable "create_eips" {
  description = "Number of EIPs to create for this VPC (for testing network creation with EIPs)"
  type        = number
  default     = 0
}
