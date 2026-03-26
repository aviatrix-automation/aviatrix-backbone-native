output "external_lb_ip_addresses" {
  description = "Map of transit gateway name to external Application LB public IP address."
  value       = module.transit.external_lb_ip_addresses
}
