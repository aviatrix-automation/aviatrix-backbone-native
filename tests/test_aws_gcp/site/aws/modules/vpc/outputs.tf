# VPC outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc.vpc_cidr
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = module.vpc.vpc.public_subnet_ids[0]
}

output "public_subnet_cidr" {
  description = "Public subnet CIDR (for spoke gateway)"
  value       = module.vpc.vpc.public_subnet_cidrs[0]
}

output "private_subnet_id" {
  description = "Private subnet ID"
  value       = module.vpc.vpc.private_subnet_ids[0]
}

# VM outputs (mc-vm-csp format - single VM)
output "vm" {
  description = "VM details from mc-vm-csp module"
  value = {
    public_vm_public_ip   = module.vm.vm.public_vm_public_ip
    public_vm_private_ip  = module.vm.vm.public_vm_private_ip
    private_vm_private_ip = module.vm.vm.private_vm_private_ip
    gatus_url             = module.vm.vm.gatus_url
  }
}

output "region" {
  description = "AWS region"
  value       = var.region
}
