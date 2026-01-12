# Required
variable "resource_name_label" {
  description = "The label to be prepended for the resource name"
  type        = string
}

variable "region" {
  description = "Region of the VPC - where the VMs will be deployed in"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC - where the VMs will be deployed in"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet where the public VM will be deployed"
  type        = string
}

variable "private_subnet_id" {
  description = "Private subnet where the private VM will be deployed"
  type        = string
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
  default     = "terraform"
}

variable "instance_size" {
  description = "Instance size for the virtual machines"
  type        = string
  default     = ""
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

variable "vm_admin_username" {
  description = "Admin username of the VM"
  type        = string
  default     = "ubuntu"
}

variable "az1" {
  description = "Concatenate with region to form zones. eg. us-central1-a. Used for public VM"
  type        = string
  default     = "a"
}

variable "az2" {
  description = "Concatenate with region to form zones. eg. us-central1-b. Used for private VM"
  type        = string
  default     = "b"
}
