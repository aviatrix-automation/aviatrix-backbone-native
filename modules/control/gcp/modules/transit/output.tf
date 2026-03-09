output "external_lb_ip_addresses" {
  description = "Map of transit gateway name to external Application LB public IP address"
  value = {
    for k, v in google_compute_global_address.ext_lb : k => v.address
  }
}
