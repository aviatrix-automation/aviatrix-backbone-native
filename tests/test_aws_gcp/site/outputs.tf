# -----------------------------------------------------------------------------
# AWS Site Outputs (re-exported from aws/ submodule)
# -----------------------------------------------------------------------------
output "aws_sites" {
  description = "Map of all AWS site outputs"
  value       = module.aws.sites
}

output "aws_site_config" {
  description = "Input AWS site configuration"
  value       = module.aws.site_config
}

output "aws_all_site_vpcs" {
  description = "All AWS site VPC details for spoke gateway creation"
  value       = module.aws.all_site_vpcs
}

output "aws_ssh_private_key_file" {
  description = "Path to the AWS SSH private key file"
  value       = module.aws.ssh_private_key_file
}

output "aws_ssh_private_key_pem" {
  description = "AWS SSH private key PEM content"
  value       = module.aws.ssh_private_key_pem
  sensitive   = true
}

# -----------------------------------------------------------------------------
# GCP Site Outputs (re-exported from gcp/ submodule)
# -----------------------------------------------------------------------------
output "gcp_vm" {
  description = "GCP VM details"
  value       = module.gcp.vm
}

output "gcp_vm_vpc_id" {
  description = "GCP VM VPC ID"
  value       = module.gcp.vm_vpc_id
}

output "gcp_vm_vpc_name" {
  description = "GCP VM VPC name"
  value       = module.gcp.vm_vpc_name
}

output "gcp_vpc_info" {
  description = "GCP VPC details for spoke gateway creation"
  value       = module.gcp.gcp_vpc_info
}

output "gcp_ssh_private_key_file" {
  description = "Path to the GCP SSH private key file"
  value       = module.gcp.ssh_private_key_file
}

output "gcp_ssh_private_key_pem" {
  description = "GCP SSH private key PEM content"
  value       = module.gcp.ssh_private_key_pem
  sensitive   = true
}
