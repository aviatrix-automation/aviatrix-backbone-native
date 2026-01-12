# Aviatrix Controller
variable "aviatrix_controller_ip" {
  description = "Aviatrix controller IP address"
  type        = string
}

variable "aviatrix_controller_username" {
  description = "Aviatrix controller username"
  type        = string
}

variable "aviatrix_controller_password" {
  description = "Aviatrix controller password"
  type        = string
  sensitive   = true
}

# Aviatrix Access Accounts
variable "aviatrix_aws_access_account" {
  description = "Aviatrix access account name for AWS"
  type        = string
}

variable "aviatrix_gcp_access_account" {
  description = "Aviatrix access account name for GCP"
  type        = string
}

# AWS Configuration
variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-west-2"
}

variable "aws_access_key" {
  description = "AWS access key"
  type        = string
}

variable "aws_secret_key" {
  description = "AWS secret key"
  type        = string
  sensitive   = true
}

# GCP Configuration
variable "gcp_project_name" {
  description = "GCP project name/ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region for deployment"
  type        = string
  default     = "us-west1"
}

variable "gcp_credential_file_location" {
  description = "Path to GCP service account credentials JSON file"
  type        = string
}

# Network CIDR Configuration
variable "aws_transit_cidr" {
  description = "CIDR for AWS transit VPC"
  type        = string
  default     = "10.10.0.0/16"
}

variable "gcp_transit_cidr" {
  description = "CIDR for GCP transit VPC"
  type        = string
  default     = "10.20.0.0/16"
}

# BGP ASN Configuration
variable "aws_transit_asn" {
  description = "BGP ASN for AWS Aviatrix Transit Gateway"
  type        = number
  default     = 65001
}

variable "gcp_transit_asn" {
  description = "BGP ASN for GCP Aviatrix Transit Gateway"
  type        = number
  default     = 65002
}

# Resource naming
variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "bb"
}

# Gateway configuration
variable "ha_gw" {
  description = "Enable HA gateways"
  type        = bool
  default     = false
}

