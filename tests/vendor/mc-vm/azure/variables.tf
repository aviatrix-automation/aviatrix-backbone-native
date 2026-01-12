# Required
variable "resource_name_label" {
  description = "The label to be prepended for the resource name"
  type        = string
}

variable "region" {
  description = "Region of the VPC/VNet/VCN - where the VMs will be deployed in"
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "ID of the VPC/VNet/VCN - where the VMs will be deployed in"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet where the public VM will be deployed"
  type        = string
  default     = ""
}

variable "private_subnet_id" {
  description = "Private subnet where the private VM will be deployed"
  type        = string
  default     = ""
}

variable "ingress_cidrs" {
  description = "List of CIDRs to allow ingress traffic thru SSH/ICMP to the VMs"
  type        = list(string)
  default     = []
}

# Optional
variable "use_existing_keypair" {
  description = "Set to true if using an existing keypair for the VM(s), rather than generating one"
  type        = bool
  default     = false
}

variable "public_key" {
  description = "Public key to be used for the VM(s). Required if using an existing keypair"
  type        = string
  default     = ""
}

variable "egress_cidrs" {
  description = "List of CIDRs to allow egress traffic to, from the VMs"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "vm_count" {
  description = "Number of VM pairs (public + private) to launch"
  type        = number
  default     = 1
}

variable "owner" {
  description = "Owner of the VMs. Will tag the resources in this module"
  type        = string
  default     = null
}

variable "instance_size" {
  description = "Instance size for the virtual machines"
  type        = string
  default     = ""
}

variable "use_custom_subnets" {
  description = "Set to true to use a custom list of subnets to launch public/private VM pairs into"
  type        = bool
  default     = false
}

variable "public_subnet_list" {
  description = "List of public subnet IDs, only to be used when use_custom_subnets = true"
  type        = list(string)
  default     = []
}

variable "private_subnet_list" {
  description = "List of private subnet IDs, only to be used when use_custom_subnets = true"
  type        = list(string)
  default     = []
}

variable "public_vm_private_ip_list" {
  description = "List of private IPs to assign to the public VMs; will be assigned chronologically"
  type        = list(string)
  default     = []
}

variable "private_vm_private_ip_list" {
  description = "List of private IPs to assign to the private VMs; will be assigned chronologically"
  type        = list(string)
  default     = []
}

variable "deploy_private_vm" {
  description = "Whether to deploy private vm or not, default to true"
  type        = bool
  default     = true
}

variable "tags" {
  description = "A map of key/value string pairs to assign to the VMs"
  type        = map(string)
  default     = {}
}

## AWS
variable "source_dest_check" {
  description = "Whether to allow the PRIVATE instance to send and receive traffic when the source or destination is not itself"
  type        = bool
  default     = true
}

variable "termination_protection" {
  description = "Whether to disable API termination for the AWS Ubuntu instances."
  type        = bool
  default     = true
}

variable "ubuntu_ami" {
  description = "AMI of the Ubuntu instances"
  type        = string
  default     = ""
}

## Azure
variable "vm_admin_username" {
  description = "Admin username of the VM"
  type        = string
  default     = "ubuntu"
}

## GCP
variable "region2" {
  description = "Region of the VCN's second subnet - where the private VM will be deployed in. Required for GCP only"
  type        = string
  default     = ""
}

variable "az1" {
  description = "Concatenate with region to form zones. eg. us-central1-a. Only used for GCP to launch public VM"
  type        = string
  default     = "a"
}

variable "az2" {
  description = "Concatenate with region to form zones. eg. us-central1-b. Only used for GCP to launch private VM"
  type        = string
  default     = "b"
}

variable "public_subnet_region_list" {
  description = "List of region of the VCN's public subnets (in respective order, as listed in the public_subnet_list) - where the public VMs will be launched"
  type        = list(string)
  default     = []
}

variable "private_subnet_region_list" {
  description = "List of region of the VCN's private subnets (in respective order, as listed in the private_subnet_list) - where the private VMs will be launched"
  type        = list(string)
  default     = []
}

variable "user_data_filename" {
  description = "The path to a bootstrap script that configure the instance at the first launch. If it is empty, {path.module}/../init.sh will be used"
  type        = string
  default     = ""
}

variable "use_custom_security_group" {
  description = "Set to true to use a custom list of security groups to launch public/private VM pairs into"
  type        = bool
  default     = false
}

variable "vpc_security_group_ids" {
  description = "List of security group IDs, only to be used when use_custom_security_group = true"
  type        = list(string)
  default     = []
}

# Retrieve local public IP
data "http" "my_ip" {
  url = "https://ipv4.icanhazip.com"
}

variable "azure_environment" {
  description = "Specifies the Azure environment to use"
  type        = string
  default     = "AzureCloud"
}

variable "environment" {
  description = "Map of Azure environment with their identifiers"
  type        = map(string)
  default = {
    AzureCloud        = "public"
    AzureUSGovernment = "usgovernment"
    AzureChinaCloud   = "china"
  }
}

variable "arm_subscription_id" {
  description = "Azure subscription ID"
  type        = string
  default     = ""
}