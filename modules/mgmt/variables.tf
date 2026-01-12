variable "region" {
  description = "AWS region for deploying the Aviatrix control plane"
  type        = string
  default     = "us-east-1"
}

variable "aws_ssm_region" {
  description = "AWS region for AWS SSM"
  type        = string
  default     = "us-east-1"
}

variable "controller_name" {
  description = "Name of the Aviatrix Controller"
  type        = string
  default     = "New-AviatrixController"
}

variable "copilot_name" {
  description = "Name of the Aviatrix CoPilot"
  type        = string
  default     = "New-AviatrixCopilot"
}

variable "controlplane_vpc_cidr" {
  description = "CIDR block for the new VPC when use_existing_vpc is false"
  type        = string
  default     = null

  validation {
    condition     = var.controlplane_vpc_cidr == null || can(cidrhost(var.controlplane_vpc_cidr, 0))
    error_message = "controlplane_vpc_cidr must be a valid CIDR block (e.g., '10.0.0.0/16') or null."
  }
}

variable "controlplane_subnet_cidr" {
  description = "CIDR block for the subnet in the new VPC when use_existing_vpc is false"
  type        = string
  default     = null

  validation {
    condition     = var.controlplane_subnet_cidr == null || can(cidrhost(var.controlplane_subnet_cidr, 0))
    error_message = "controlplane_subnet_cidr must be a valid CIDR block (e.g., '10.0.1.0/24') or null."
  }
}

variable "incoming_ssl_cidrs" {
  description = "List of CIDR blocks allowed to access the Controller's SSL interface"
  type        = list(string)
  default     = null

  validation {
    condition     = var.incoming_ssl_cidrs != null && length(var.incoming_ssl_cidrs) > 0
    error_message = "incoming_ssl_cidrs must be a non-empty list of valid CIDR blocks."
  }
}

variable "controller_admin_email" {
  description = "Admin email for the Aviatrix Controller"
  type        = string
  default     = "admin@example.com"
}

variable "account_email" {
  description = "Email for the Aviatrix account"
  type        = string
  default     = "admin@example.com"
}

variable "access_account_name" {
  description = "Name of the Aviatrix access account"
  type        = string
  sensitive   = true
}

variable "use_existing_vpc" {
  description = "Whether to use an existing VPC for deployment"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "ID of the existing VPC to use (required if use_existing_vpc is true)"
  type        = string
  default     = null

  validation {
    condition     = var.use_existing_vpc ? var.vpc_id != null : true
    error_message = "vpc_id must be provided when use_existing_vpc is true."
  }
}

variable "subnet_id" {
  description = "ID of the subnet for deployment (required if use_existing_vpc is true)"
  type        = string
  default     = null

  validation {
    condition     = var.use_existing_vpc ? var.subnet_id != null : true
    error_message = "subnet_id must be provided when use_existing_vpc is true."
  }
}

variable "controller_version" {
  description = "Version of the Aviatrix Controller"
  type        = string
  default     = "latest"
}

variable "module_config" {
  description = "Configuration map for module components"
  type        = map(bool)
  default = {
    account_onboarding        = true
    controller_deployment     = true
    controller_initialization = true
    copilot_deployment        = true
    copilot_initialization    = true
    iam_roles                 = false
  }
}

variable "tags" {
  description = "Map of tags to apply to resources created by the module"
  type        = map(string)
  default = {
    Environment = "Production"
    Project     = "Aviatrix-Control-Plane"
  }
}

variable "controller_instance_type" {
  description = "Instance type for the Aviatrix Controller EC2 instance"
  type        = string
  default     = "t3.xlarge"
  validation {
    condition     = can(regex("^[a-z0-9]+\\.[a-z0-9]+$", var.controller_instance_type))
    error_message = "controller_instance_type must be a valid AWS EC2 instance type (e.g., 't3.large')."
  }
}

variable "copilot_instance_type" {
  description = "Instance type for the Aviatrix CoPilot EC2 instance"
  type        = string
  default     = "m5n.2xlarge"
  validation {
    condition     = can(regex("^[a-z0-9]+\\.[a-z0-9]+$", var.copilot_instance_type))
    error_message = "copilot_instance_type must be a valid AWS EC2 instance type (e.g., 't3.large')."
  }
}

variable "copilot_data_volume_size" {
  description = "Specifies the size of the CoPilot Data Disk Volume"
  type        = string
  default     = "100"
}