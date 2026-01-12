output "aws_transit" {
  value = {
    gw_name   = module.aws_transit.transit_gateway.gw_name
    vpc_id    = module.aws_transit.transit_gateway.vpc_id
    public_ip = module.aws_transit.transit_gateway.public_ip
  }
}
