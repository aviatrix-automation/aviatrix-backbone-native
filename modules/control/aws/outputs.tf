output "mgmt_subnet_ids" {
  description = "Map of transit key to management subnet ID."
  value       = module.transit.mgmt_subnet_ids
}
