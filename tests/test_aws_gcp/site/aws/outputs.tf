# -----------------------------------------------------------------------------
# Aggregated Site Outputs
# Merges outputs from all regional VPC modules into a single map
# -----------------------------------------------------------------------------
locals {
  # Merge all VPC outputs into a single map
  all_sites = merge(
    { for k, v in module.vpc_us_west_2 : k => v },
    { for k, v in module.vpc_us_east_1 : k => v },
    { for k, v in module.vpc_eu_west_1 : k => v },
    { for k, v in module.vpc_ap_southeast_1 : k => v },
  )
}

output "sites" {
  description = "Map of all site outputs"
  value = {
    for site_name, site in local.all_sites : site_name => {
      vpc_id            = site.vpc_id
      vpc_cidr          = site.vpc_cidr
      public_subnet_id  = site.public_subnet_id
      private_subnet_id = site.private_subnet_id
      region            = site.region
      vm                = site.vm
    }
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

# -----------------------------------------------------------------------------
# Site configuration (for reference)
# -----------------------------------------------------------------------------
output "site_config" {
  description = "Input site configuration"
  value       = var.sites
}

# -----------------------------------------------------------------------------
# Site VPCs for spoke gateway creation (used by backbone)
# -----------------------------------------------------------------------------
output "all_site_vpcs" {
  description = "All site VPC details for spoke gateway creation"
  value       = local.all_site_vpcs
}
