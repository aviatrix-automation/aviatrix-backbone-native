# -----------------------------------------------------------------------------
# Monitoring Stage Outputs
# -----------------------------------------------------------------------------

output "dashboard_url" {
  description = "URL of the main Gatus dashboard"
  value       = "http://${local.dashboard_ip}:${var.gatus_port}"
}

output "dashboard_site" {
  description = "Site name used as the dashboard"
  value       = local.dashboard_site_name
}

output "monitored_endpoints" {
  description = "List of monitored endpoints"
  value = concat(
    # Local dashboard
    ["aws-${local.dashboard_site_name}-${local.dashboard_region}"],
    ["aws-${local.dashboard_site_name}-${local.dashboard_region}-icmp"],
    # Other AWS sites
    [for name, _ in local.other_aws_sites : "aws-${name}-${local.aws_site_config[name].region}-gatus"],
    [for name, _ in local.other_aws_sites : "aws-${name}-${local.aws_site_config[name].region}-icmp"],
    [for name, _ in local.other_aws_sites : "aws-${name}-${local.aws_site_config[name].region}-ssh"],
    # GCP
    ["gcp-${local.gcp_vpc_name}-${local.gcp_region}-gatus"],
    ["gcp-${local.gcp_vpc_name}-${local.gcp_region}-icmp"],
    ["gcp-${local.gcp_vpc_name}-${local.gcp_region}-ssh"]
  )
}

output "gatus_config" {
  description = "Generated Gatus configuration"
  value       = local.gatus_config
}
