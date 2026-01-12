output "mgmt_subnet_ids" {
  value = { for key, subnet in data.aws_subnet.mgmt_subnet : key => subnet.id }
}