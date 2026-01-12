# -----------------------------------------------------------------------------
# Aviatrix Transit Outputs
# -----------------------------------------------------------------------------
output "aws_transit_gateway_name" {
  description = "AWS Aviatrix transit gateway name"
  value       = module.aws_transit.transit_gateway.gw_name
}

output "gcp_transit_gateway_name" {
  description = "GCP Aviatrix transit gateway name"
  value       = module.gcp_transit.transit_gateway.gw_name
}

output "aws_transit_vpc_id" {
  description = "AWS Transit VPC ID"
  value       = module.aws_transit.vpc.vpc_id
}

output "aws_transit_vpc_cidr" {
  description = "AWS Transit VPC CIDR"
  value       = module.aws_transit.vpc.cidr
}

output "gcp_transit_vpc_id" {
  description = "GCP Transit VPC ID"
  value       = module.gcp_transit.vpc.vpc_id
}

# -----------------------------------------------------------------------------
# Transit Peering Output
# -----------------------------------------------------------------------------
output "transit_peering" {
  description = "Transit peering details"
  value = {
    aws_transit = module.aws_transit.transit_gateway.gw_name
    gcp_transit = module.gcp_transit.transit_gateway.gw_name
  }
}

# -----------------------------------------------------------------------------
# Spoke Gateway Outputs
# -----------------------------------------------------------------------------
output "aws_spoke_gateways" {
  description = "AWS spoke gateway names"
  sensitive   = true
  value = {
    for k, v in module.aws_spoke : k => v.spoke_gateway.gw_name
  }
}

output "gcp_spoke_gateway_name" {
  description = "GCP spoke gateway name"
  sensitive   = true
  value       = length(module.gcp_spoke) > 0 ? module.gcp_spoke[0].spoke_gateway.gw_name : null
}
