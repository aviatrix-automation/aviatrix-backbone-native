# -----------------------------------------------------------------------------
# VM Outputs (from mc-vm-csp module)
# -----------------------------------------------------------------------------
output "vm" {
  description = "VM details from mc-vm-csp module"
  value       = module.vm.vm
}

# -----------------------------------------------------------------------------
# Network Outputs (native GCP VPC)
# -----------------------------------------------------------------------------
output "vm_vpc_id" {
  description = "GCP VM VPC ID"
  value       = google_compute_network.vm_vpc.id
}

output "vm_vpc_name" {
  description = "GCP VM VPC name"
  value       = google_compute_network.vm_vpc.name
}

output "vm_subnet_name" {
  description = "GCP VM subnet name"
  value       = google_compute_subnetwork.vm_subnet.name
}

output "vm_subnet_cidr" {
  description = "GCP VM subnet CIDR"
  value       = var.gcp_vm_cidr
}

# -----------------------------------------------------------------------------
# VPC info for backbone to create spoke gateway
# -----------------------------------------------------------------------------
output "gcp_vpc_info" {
  description = "GCP VPC details for spoke gateway creation"
  value = {
    vpc_id      = google_compute_network.vm_vpc.id
    vpc_name    = google_compute_network.vm_vpc.name
    subnet_name = google_compute_subnetwork.vm_subnet.name
    subnet_cidr = var.gcp_vm_cidr
    region      = var.gcp_region
  }
}

# -----------------------------------------------------------------------------
# SSH Key Output
# -----------------------------------------------------------------------------
output "ssh_private_key_file" {
  description = "Path to the generated SSH private key file"
  value       = abspath(local_file.private_key.filename)
}

output "ssh_private_key_pem" {
  description = "SSH private key PEM content"
  value       = tls_private_key.ssh_key.private_key_pem
  sensitive   = true
}
