
data "aws_ssm_parameter" "aviatrix_ip" {
  provider        = aws.ssm
  name            = "/aviatrix/controller/ip"
  with_decryption = true
}

data "aws_ssm_parameter" "aviatrix_username" {
  provider        = aws.ssm
  name            = "/aviatrix/controller/username"
  with_decryption = true
}

data "aws_ssm_parameter" "aviatrix_password" {
  provider        = aws.ssm
  name            = "/aviatrix/controller/password"
  with_decryption = true
}

data "aws_ec2_transit_gateway" "tgw" {
  depends_on = [aws_ec2_transit_gateway.tgw]
  for_each   = { for k, v in var.tgws : k => v if !v.create_tgw }

  filter {
    name   = "options.amazon-side-asn"
    values = [each.value.amazon_side_asn]
  }
  filter {
    name   = "tag:Name"
    values = [each.key]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_subnet" "gw_subnet" {
  for_each   = var.transits
  depends_on = [module.mc-transit]

  vpc_id = module.mc-transit[each.key].vpc.vpc_id

  filter {
    name   = "tag:Name"
    values = ["aviatrix-${local.stripped_names[each.key]}"]
  }
}

data "aws_subnet" "lan_subnet" {
  for_each   = var.transits
  depends_on = [module.mc-transit, aviatrix_firenet.firenet]

  vpc_id = module.mc-transit[each.key].vpc.vpc_id

  filter {
    name   = "tag:Name"
    values = ["aviatrix-${local.stripped_names[each.key]}-dmz-firewall"]
  }
}

data "aws_subnet" "mgmt_subnet" {
  for_each   = var.transits
  depends_on = [module.mc-transit]

  vpc_id = module.mc-transit[each.key].vpc.vpc_id

  filter {
    name   = "tag:Name"
    values = ["${local.stripped_names[each.key]}-Public-gateway-and-firewall-mgmt-${module.mc-transit[each.key].transit_gateway.insane_mode_az}"]
  }
}

data "aws_subnet" "egress_subnet" {
  for_each   = var.transits
  depends_on = [module.mc-transit]

  vpc_id = module.mc-transit[each.key].vpc.vpc_id

  filter {
    name   = "tag:Name"
    values = ["${local.stripped_names[each.key]}-Public-FW-ingress-egress-${module.mc-transit[each.key].transit_gateway.insane_mode_az}"]
  }
}

data "aws_subnet" "hagw_subnet" {
  for_each   = var.transits
  depends_on = [module.mc-transit]

  vpc_id = module.mc-transit[each.key].vpc.vpc_id

  filter {
    name   = "tag:Name"
    values = ["aviatrix-${local.stripped_names[each.key]}-hagw"]
  }
}

data "aws_subnet" "hagw-lan_subnet" {
  for_each   = var.transits
  depends_on = [module.mc-transit, aviatrix_firenet.firenet]

  vpc_id = module.mc-transit[each.key].vpc.vpc_id

  filter {
    name   = "tag:Name"
    values = ["aviatrix-${local.stripped_names[each.key]}-hagw-dmz-firewall"]
  }
}

data "aws_subnet" "hagw-mgmt_subnet" {
  for_each   = var.transits
  depends_on = [module.mc-transit]

  vpc_id = module.mc-transit[each.key].vpc.vpc_id

  filter {
    name   = "tag:Name"
    values = ["${local.stripped_names[each.key]}-Public-gateway-and-firewall-mgmt-${module.mc-transit[each.key].transit_gateway.ha_insane_mode_az}"]
  }
}

data "aws_subnet" "hagw-egress_subnet" {
  for_each   = var.transits
  depends_on = [module.mc-transit]

  vpc_id = module.mc-transit[each.key].vpc.vpc_id

  filter {
    name   = "tag:Name"
    values = ["${local.stripped_names[each.key]}-Public-FW-ingress-egress-${module.mc-transit[each.key].transit_gateway.ha_insane_mode_az}"]
  }
}

data "aws_route_table" "route_table" {
  for_each = var.transits

  subnet_id = data.aws_subnet.gw_subnet[each.key].id
}

data "aws_availability_zones" "available" {
  state = "available"
}

