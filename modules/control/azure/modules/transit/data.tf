data "aws_ssm_parameter" "aviatrix_ip" {
  name            = "/aviatrix/controller/ip"
  with_decryption = true
  provider        = aws.ssm
}

data "aws_ssm_parameter" "aviatrix_username" {
  name            = "/aviatrix/controller/username"
  with_decryption = true
  provider        = aws.ssm
}

data "aws_ssm_parameter" "aviatrix_password" {
  name            = "/aviatrix/controller/password"
  with_decryption = true
  provider        = aws.ssm
}

data "azurerm_subscription" "current" {

}

data "aviatrix_transit_gateway" "transit" {
  for_each = var.transits

  gw_name    = module.mc-transit[each.key].transit_gateway.gw_name
  depends_on = [module.mc-transit]
}

data "azurerm_virtual_network" "transit_vnet" {
  for_each            = var.transits
  name                = module.mc-transit[each.key].vpc.name
  resource_group_name = module.mc-transit[each.key].vpc.resource_group
  depends_on          = [module.mc-transit]
}

data "azurerm_subnet" "mgmt_subnet" {
  for_each             = var.transits
  name                 = "${each.key}-Public-gateway-and-firewall-mgmt-1"
  virtual_network_name = module.mc-transit[each.key].vpc.name
  resource_group_name  = module.mc-transit[each.key].vpc.resource_group
  depends_on           = [module.mc-transit]
}

data "azurerm_subnet" "egress_subnet" {
  for_each             = var.transits
  name                 = "${each.key}-Public-FW-ingress-egress-1"
  virtual_network_name = module.mc-transit[each.key].vpc.name
  resource_group_name  = module.mc-transit[each.key].vpc.resource_group
  depends_on           = [module.mc-transit]
}

data "azurerm_subnet" "lan_subnet" {
  for_each             = var.transits
  name                 = "av-gw-${local.stripped_names[each.key]}-dmz-firewall-lan" # stripped name
  virtual_network_name = module.mc-transit[each.key].vpc.name                       # original key
  resource_group_name  = module.mc-transit[each.key].vpc.resource_group             # original key
  depends_on           = [module.mc-transit, aviatrix_firenet.firenet]
}

data "azurerm_subnet" "hagw-mgmt_subnet" {
  for_each             = var.transits
  name                 = "${each.key}-Public-gateway-and-firewall-mgmt-2"
  virtual_network_name = module.mc-transit[each.key].vpc.name
  resource_group_name  = module.mc-transit[each.key].vpc.resource_group
  depends_on           = [module.mc-transit]
}

data "azurerm_subnet" "hagw-egress_subnet" {
  for_each             = var.transits
  name                 = "${each.key}-Public-FW-ingress-egress-2"
  virtual_network_name = module.mc-transit[each.key].vpc.name
  resource_group_name  = module.mc-transit[each.key].vpc.resource_group
  depends_on           = [module.mc-transit]
}

data "azurerm_subnet" "hagw-lan_subnet" {
  for_each             = var.transits
  name                 = "av-gw-${local.stripped_names[each.key]}-hagw-dmz-firewall-lan"
  virtual_network_name = module.mc-transit[each.key].vpc.name
  resource_group_name  = module.mc-transit[each.key].vpc.resource_group
  depends_on           = [module.mc-transit, aviatrix_firenet.firenet]
}

data "azurerm_virtual_network" "spoke_vnet" {
  for_each            = var.spokes
  name                = module.mc-spoke[each.key].vpc.name
  resource_group_name = module.mc-spoke[each.key].vpc.resource_group
  depends_on          = [module.mc-spoke]
}

data "azurerm_resource_group" "existing_vwan_rg" {
  for_each = { for k, v in var.vwan_configs : k => v if v.existing }
  name     = each.value.resource_group_name
}

data "azurerm_virtual_wan" "existing_vwan" {
  for_each            = { for k, v in var.vwan_configs : k => v if v.existing }
  name                = each.key # vWAN name is the key
  resource_group_name = each.value.resource_group_name
}

data "azurerm_virtual_network" "existing_vnet" {
  for_each            = { for k, v in var.vnets : k => v if try(v.existing, false) && v.resource_group_name != null }
  name                = each.key
  resource_group_name = each.value.resource_group_name
}