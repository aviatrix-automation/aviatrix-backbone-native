output "mgmt_subnet_ids" {
  description = "Map of transit key to management subnet ID."
  value       = { for key, subnet in data.aws_subnet.mgmt_subnet : key => subnet.id }
}