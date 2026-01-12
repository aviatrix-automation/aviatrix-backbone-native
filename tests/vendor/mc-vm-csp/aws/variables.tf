variable "resource_name_label" {
  description = "Label to prepend to resource names"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where VMs will be deployed"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet for public VM"
  type        = string
}

variable "private_subnet_id" {
  description = "Private subnet for private VM"
  type        = string
  default     = ""
}

variable "ingress_cidrs" {
  description = "CIDRs allowed for SSH/ICMP ingress"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "instance_size" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "use_existing_keypair" {
  description = "Use existing keypair instead of generating one"
  type        = bool
  default     = false
}

variable "public_key" {
  description = "Public key for existing keypair"
  type        = string
  default     = ""
}

variable "deploy_private_vm" {
  description = "Deploy private VM in addition to public"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "enable_gatus" {
  description = "Install Gatus health monitoring on public VM"
  type        = bool
  default     = false
}

variable "gatus_config" {
  description = "Gatus configuration YAML content (see https://github.com/TwiN/gatus)"
  type        = string
  default     = ""
}

variable "gatus_username" {
  description = "Username for Gatus basic authentication"
  type        = string
  default     = "admin"
}

variable "gatus_password" {
  description = "Password for Gatus basic authentication"
  type        = string
  default     = ""
  sensitive   = true
}
