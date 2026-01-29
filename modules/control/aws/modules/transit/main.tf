locals {
  stripped_names = {
    for k, v in var.transits : k => (
      length(regexall("^(.+)-vpc$", k)) > 0 ?
      regex("^(.+)-vpc$", k)[0] :
      k
    )
  }
  tgw_name_to_info = { for k, v in var.tgws : k => v }
  tgw_name_to_id = merge(
    { for k, v in aws_ec2_transit_gateway.tgw : k => v.id },
    { for k, v in data.aws_ec2_transit_gateway.tgw : k => v.id }
  )

  transit_keys = [for k, v in var.transits : k if v.tgw_name != ""]

  tgw_names_per_transit = {
    for k, v in var.transits : k => v.tgw_name != "" ? (
      can(split(",", v.tgw_name)) ? split(",", v.tgw_name) : (
        can(tolist(v.tgw_name)) ? tolist(v.tgw_name) : [v.tgw_name]
      )
    ) : []
  }

  transit_tgw_pairs = flatten([
    for transit_key, tgw_names in local.tgw_names_per_transit : [
      for tgw_name in tgw_names : {
        transit_key = transit_key
        tgw_name    = tgw_name
        pair_key    = "${transit_key}.${tgw_name}"
      }
    ]
  ])

  transit_tgw_map = { for pair in local.transit_tgw_pairs : pair.pair_key => pair }

  tgw_connect_ip = {
    for pair in local.transit_tgw_pairs : pair.pair_key => {
      connect_peer_1    = cidrhost(element(local.tgw_name_to_info[pair.tgw_name].transit_gateway_cidr_blocks, 0), 1 + index(local.transit_keys, pair.transit_key) * 4)
      ha_connect_peer_1 = cidrhost(element(local.tgw_name_to_info[pair.tgw_name].transit_gateway_cidr_blocks, 0), 2 + index(local.transit_keys, pair.transit_key) * 4)
      connect_peer_2    = cidrhost(element(local.tgw_name_to_info[pair.tgw_name].transit_gateway_cidr_blocks, 0), 3 + index(local.transit_keys, pair.transit_key) * 4)
      ha_connect_peer_2 = cidrhost(element(local.tgw_name_to_info[pair.tgw_name].transit_gateway_cidr_blocks, 0), 4 + index(local.transit_keys, pair.transit_key) * 4)
      connect_peer_3    = cidrhost(element(local.tgw_name_to_info[pair.tgw_name].transit_gateway_cidr_blocks, 0), 5 + index(local.transit_keys, pair.transit_key) * 4)
      ha_connect_peer_3 = cidrhost(element(local.tgw_name_to_info[pair.tgw_name].transit_gateway_cidr_blocks, 0), 6 + index(local.transit_keys, pair.transit_key) * 4)
      connect_peer_4    = cidrhost(element(local.tgw_name_to_info[pair.tgw_name].transit_gateway_cidr_blocks, 0), 7 + index(local.transit_keys, pair.transit_key) * 4)
      ha_connect_peer_4 = cidrhost(element(local.tgw_name_to_info[pair.tgw_name].transit_gateway_cidr_blocks, 0), 8 + index(local.transit_keys, pair.transit_key) * 4)
      connect_peer_5    = cidrhost(element(local.tgw_name_to_info[pair.tgw_name].transit_gateway_cidr_blocks, 0), 9 + index(local.transit_keys, pair.transit_key) * 4)
      ha_connect_peer_5 = cidrhost(element(local.tgw_name_to_info[pair.tgw_name].transit_gateway_cidr_blocks, 0), 10 + index(local.transit_keys, pair.transit_key) * 4)
      connect_peer_6    = cidrhost(element(local.tgw_name_to_info[pair.tgw_name].transit_gateway_cidr_blocks, 0), 11 + index(local.transit_keys, pair.transit_key) * 4)
      ha_connect_peer_6 = cidrhost(element(local.tgw_name_to_info[pair.tgw_name].transit_gateway_cidr_blocks, 0), 12 + index(local.transit_keys, pair.transit_key) * 4)
      connect_peer_7    = cidrhost(element(local.tgw_name_to_info[pair.tgw_name].transit_gateway_cidr_blocks, 0), 13 + index(local.transit_keys, pair.transit_key) * 4)
      ha_connect_peer_7 = cidrhost(element(local.tgw_name_to_info[pair.tgw_name].transit_gateway_cidr_blocks, 0), 14 + index(local.transit_keys, pair.transit_key) * 4)
      connect_peer_8    = cidrhost(element(local.tgw_name_to_info[pair.tgw_name].transit_gateway_cidr_blocks, 0), 15 + index(local.transit_keys, pair.transit_key) * 4)
      ha_connect_peer_8 = cidrhost(element(local.tgw_name_to_info[pair.tgw_name].transit_gateway_cidr_blocks, 0), 16 + index(local.transit_keys, pair.transit_key) * 4)
    }
  }

  all_tgw_names = toset([for pair in local.transit_tgw_pairs : pair.tgw_name])

  firenet_transit_keys = [
    for k, v in var.transits : k if v.fw_amount > 0
  ]

  inspection_policies = flatten([
    for transit_key in local.firenet_transit_keys : [
      for tgw_name in local.tgw_names_per_transit[transit_key] : [
        {
          transit_key     = transit_key
          tgw_name        = tgw_name
          connection_name = "external-${tgw_name}-${local.tgw_name_to_id[tgw_name]}-1-${transit_key}"
          pair_key        = "${transit_key}.${tgw_name}.external-1"
        },
        {
          transit_key     = transit_key
          tgw_name        = tgw_name
          connection_name = "external-${tgw_name}-${local.tgw_name_to_id[tgw_name]}-2-${transit_key}"
          pair_key        = "${transit_key}.${tgw_name}.external-2"
        }
      ]
    ]
  ])

  external_device_pairs = {
    for k, v in var.external_devices : k => {
      transit_key               = v.transit_key
      connection_name           = v.connection_name
      pair_key                  = "${v.transit_key}.${v.connection_name}"
      remote_gateway_ip         = v.remote_gateway_ip
      bgp_enabled               = v.bgp_enabled
      bgp_remote_asn            = v.bgp_enabled ? v.bgp_remote_asn : null
      backup_bgp_remote_as_num  = v.ha_enabled ? v.bgp_remote_asn : null
      local_tunnel_cidr         = v.local_tunnel_cidr
      remote_tunnel_cidr        = v.remote_tunnel_cidr
      ha_enabled                = v.ha_enabled
      backup_remote_gateway_ip  = v.ha_enabled ? v.backup_remote_gateway_ip : null
      backup_local_tunnel_cidr  = v.ha_enabled ? v.backup_local_tunnel_cidr : null
      backup_remote_tunnel_cidr = v.ha_enabled ? v.backup_remote_tunnel_cidr : null
      enable_ikev2              = v.enable_ikev2
      inspected_by_firenet      = v.inspected_by_firenet
    }
  }

  external_inspection_policies = [
    for k, v in local.external_device_pairs : {
      transit_key     = v.transit_key
      connection_name = v.connection_name
      pair_key        = v.pair_key
    } if v.inspected_by_firenet && lookup(var.transits[v.transit_key], "fw_amount", 0) > 0
  ]

  tgw_account_pairs = flatten([
    for tgw_name, tgw in var.tgws : [
      for account_id in tgw.account_ids : {
        tgw_name   = tgw_name
        account_id = account_id
        key        = "${tgw_name}.${account_id}"
      }
    ] if tgw.create_tgw && length(tgw.account_ids) > 0
  ])
  tgw_account_pairs_map = { for pair in local.tgw_account_pairs : pair.key => pair }


  fws = flatten([
    for transit_key, transit in var.transits : concat(
      [for i in range(floor(tonumber(transit.fw_amount) / 2)) : {
        transit_key            = transit_key
        name                   = "${local.stripped_names[transit_key]}-fw${i + 1}"
        gw_name                = local.stripped_names[transit_key]
        index                  = i
        type                   = "pri"
        fw_instance_size       = transit.fw_instance_size
        firewall_image         = transit.firewall_image
        firewall_image_version = transit.firewall_image_version
        egress_enabled         = transit.egress_enabled
        inspection_enabled     = transit.inspection_enabled
        ssh_keys               = transit.ssh_keys
        egress_source_ranges   = transit.egress_source_ranges
        mgmt_source_ranges     = transit.mgmt_source_ranges
        lan_source_ranges      = transit.lan_source_ranges
      }],
      [for i in range(floor(tonumber(transit.fw_amount) / 2)) : {
        transit_key            = transit_key
        name                   = "${local.stripped_names[transit_key]}-fw${i + 1}"
        gw_name                = "${local.stripped_names[transit_key]}-hagw"
        index                  = i
        type                   = "ha"
        fw_instance_size       = transit.fw_instance_size
        firewall_image         = transit.firewall_image
        firewall_image_version = transit.firewall_image_version
        egress_enabled         = transit.egress_enabled
        inspection_enabled     = transit.inspection_enabled
        ssh_keys               = transit.ssh_keys
        egress_source_ranges   = transit.egress_source_ranges
        mgmt_source_ranges     = transit.mgmt_source_ranges
        lan_source_ranges      = transit.lan_source_ranges
      }]
    )
  ])

  ssh_key_name = {
    for k, v in var.transits : k => (
      lookup(v, "ssh_keys", "") != "" ?
      v.ssh_keys :
      aws_key_pair.generated[k].key_name
    )
  }

}

module "mc-transit" {
  for_each                      = var.transits
  source                        = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version                       = "8.0.0"
  account                       = each.value.account
  bgp_ecmp                      = true
  cloud                         = "aws"
  cidr                          = each.value.cidr
  connected_transit             = true
  enable_egress_transit_firenet = false
  enable_encrypt_volume         = true
  enable_firenet                = false
  enable_s2c_rx_balancing       = true
  enable_transit_firenet        = true
  instance_size                 = each.value.instance_size
  insane_mode                   = true
  local_as_number               = each.value.local_as_number
  name                          = each.key
  gw_name                       = local.stripped_names[each.key]
  region                        = var.region
  enable_preserve_as_path       = false
  enable_segmentation           = true
  enable_advertise_transit_cidr = true
  enable_multi_tier_transit     = true
  # Learned CIDRs approval configuration
  learned_cidr_approval       = each.value.learned_cidr_approval
  learned_cidrs_approval_mode = each.value.learned_cidrs_approval_mode
  approved_learned_cidrs      = each.value.approved_learned_cidrs
  tags                        = var.tags
}

resource "aviatrix_firenet" "firenet" {
  for_each = {
    for k, v in var.transits : k => v
  }

  vpc_id             = module.mc-transit[each.key].vpc.vpc_id
  inspection_enabled = each.value.inspection_enabled
  egress_enabled     = each.value.egress_enabled
}

resource "tls_private_key" "generated" {
  for_each = {
    for k, v in var.transits : k => v
    if lookup(v, "ssh_keys", "") == ""
  }

  algorithm = "RSA"
  rsa_bits  = 2048
}

# 
resource "aws_key_pair" "generated" {
  for_each = tls_private_key.generated

  key_name   = "${each.key}-generated-key"
  public_key = each.value.public_key_openssh

  tags = merge(var.tags, {
    Name        = "${each.key}-generated-key"
    GeneratedBy = "terraform"
  })
}

resource "aws_security_group" "pan_mgmt" {
  for_each = {
    for fw in local.fws :
    "${fw.transit_key}-${fw.type}-fw${fw.index + 1}" => fw
  }
  name        = "${each.key}-mgmt-sg"
  description = "Security group for PAN management interface"
  vpc_id      = module.mc-transit[each.value.transit_key].vpc.vpc_id
  tags        = merge(var.tags, { Name = "${each.key}-mgmt-sg" })

  ingress {
    description = "Allow HTTPS for management"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = each.value.mgmt_source_ranges
  }

  ingress {
    description = "Allow SSH for troubleshooting"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = each.value.mgmt_source_ranges
  }

  ingress {
    description = "Allow SSH for troubleshooting"
    from_port   = 3978
    to_port     = 3978
    protocol    = "tcp"
    cidr_blocks = each.value.mgmt_source_ranges
  }

  ingress {
    description = "Allow ICMP for troubleshooting"
    from_port   = 0
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = each.value.mgmt_source_ranges
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Removed duplicate tags block
}

resource "aws_security_group" "pan_egress" {
  for_each = {
    for fw in local.fws :
    "${fw.transit_key}-${fw.type}-fw${fw.index + 1}" => fw
  }
  name        = "${each.key}-egress-sg"
  description = "Security group for PAN Egress interface"
  vpc_id      = module.mc-transit[each.value.transit_key].vpc.vpc_id

  ingress {
    description = "Allow return traffic from internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = each.value.egress_source_ranges
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${each.key}-egress-sg" })
}

resource "aws_security_group" "pan_lan" {
  for_each = {
    for fw in local.fws :
    "${fw.transit_key}-${fw.type}-fw${fw.index + 1}" => fw
  }
  name        = "${each.key}-lan-sg"
  description = "Security group for PAN LAN interface"
  vpc_id      = module.mc-transit[each.value.transit_key].vpc.vpc_id

  ingress {
    description = "Allow internal traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = each.value.lan_source_ranges
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${each.key}-lan-sg" })
}

module "swfw-modules_bootstrap" {
  for_each = {
    for fw in local.fws :
    "${fw.transit_key}-${fw.type}-fw${fw.index + 1}" => fw
  }
  source        = "PaloAltoNetworks/swfw-modules/aws//modules/bootstrap"
  version       = "3.0.0-rc.1"
  create_bucket = true
}

module "pan_fw" {
  source  = "PaloAltoNetworks/swfw-modules/aws//modules/vmseries"
  version = "3.0.0-rc.1"

  for_each = {
    for fw in local.fws :
    "${fw.transit_key}-${fw.type}-fw${fw.index + 1}" => fw
  }

  ebs_kms_key_alias = "alias/aws/ebs"

  name                  = each.key
  instance_type         = each.value.fw_instance_size
  enable_imdsv2         = true
  vmseries_product_code = each.value.firewall_image
  vmseries_version      = each.value.firewall_image_version

  bootstrap_options = "mgmt-interface-swap=enable, vmseries-bootstrap-aws-s3bucket=${module.swfw-modules_bootstrap[each.key].bucket_name}"

  interfaces = {
    egress = {
      device_index       = 0
      subnet_id          = each.value.type == "pri" ? data.aws_subnet.egress_subnet[each.value.transit_key].id : data.aws_subnet.hagw-egress_subnet[each.value.transit_key].id
      create_public_ip   = true
      source_dest_check  = false
      security_group_ids = [aws_security_group.pan_egress[each.key].id]

    }
    management = {
      device_index       = 1
      subnet_id          = each.value.type == "pri" ? data.aws_subnet.mgmt_subnet[each.value.transit_key].id : data.aws_subnet.hagw-mgmt_subnet[each.value.transit_key].id
      create_public_ip   = true
      source_dest_check  = true
      security_group_ids = [aws_security_group.pan_mgmt[each.key].id]
    },
    lan = {
      device_index       = 2
      subnet_id          = each.value.type == "pri" ? data.aws_subnet.lan_subnet[each.value.transit_key].id : data.aws_subnet.hagw-lan_subnet[each.value.transit_key].id
      create_public_ip   = false
      source_dest_check  = false
      security_group_ids = [aws_security_group.pan_lan[each.key].id]
    }
  }

  iam_instance_profile = module.swfw-modules_bootstrap[each.key].instance_profile_name

  ssh_key_name = local.ssh_key_name[each.value.transit_key]

  tags = var.tags
  # Name tag is handled by the module's name input

  depends_on = [
    module.mc-transit,
    module.swfw-modules_bootstrap,
    aviatrix_firenet.firenet,
    aws_key_pair.generated,
    aws_security_group.pan_egress,
    aws_security_group.pan_lan,
    aws_security_group.pan_mgmt
  ]
}

resource "aviatrix_firewall_instance_association" "fw_associations" {
  for_each = { for fw in local.fws : "${module.mc-transit[fw.transit_key].transit_gateway.gw_name}-${fw.type}-fw${fw.index + 1}" => fw if var.transits[fw.transit_key].attach_firewall }

  vpc_id               = module.mc-transit[each.value.transit_key].vpc.vpc_id
  firenet_gw_name      = each.value.type == "pri" ? module.mc-transit[each.value.transit_key].transit_gateway.gw_name : module.mc-transit[each.value.transit_key].transit_gateway.ha_gw_name
  firewall_name        = each.key
  instance_id          = module.pan_fw[each.key].instance.id
  lan_interface        = module.pan_fw[each.key].interfaces.lan.id
  management_interface = module.pan_fw[each.key].interfaces.management.id
  egress_interface     = module.pan_fw[each.key].interfaces.egress.id

  vendor_type = "Generic"
  attached    = true

  depends_on = [
    module.pan_fw,
  ]
}

resource "aws_ec2_transit_gateway" "tgw" {
  for_each                       = { for k, v in var.tgws : k => v if v.create_tgw }
  amazon_side_asn                = each.value.amazon_side_asn
  auto_accept_shared_attachments = "enable"
  transit_gateway_cidr_blocks    = each.value.transit_gateway_cidr_blocks
  tags = merge(var.tags, { Name = each.key })
}

resource "aws_route" "route" {
  for_each = {
    for pair in flatten([
      for k, v in var.transits : [
        for tgw_name in local.tgw_names_per_transit[k] : {
          key         = "${k}.${tgw_name}"
          transit_key = k
          tgw_name    = tgw_name
        }
      ] if v.tgw_name != ""
    ]) : pair.key => pair
  }
  route_table_id         = data.aws_route_table.route_table[each.value.transit_key].id
  destination_cidr_block = element(local.tgw_name_to_info[each.value.tgw_name].transit_gateway_cidr_blocks, 0)
  transit_gateway_id     = local.tgw_name_to_id[each.value.tgw_name]
}

resource "aws_ec2_transit_gateway_vpc_attachment" "attachment" {
  for_each           = local.transit_tgw_map
  subnet_ids         = [data.aws_subnet.gw_subnet[each.value.transit_key].id, data.aws_subnet.hagw_subnet[each.value.transit_key].id]
  transit_gateway_id = local.tgw_name_to_id[each.value.tgw_name]
  vpc_id             = module.mc-transit[each.value.transit_key].vpc.vpc_id

  tags = merge(var.tags, { Name = "${each.value.transit_key}-to-${each.value.tgw_name}" })
}

resource "aws_ec2_transit_gateway_connect" "connect-1" {
  for_each                = local.transit_tgw_map
  transport_attachment_id = aws_ec2_transit_gateway_vpc_attachment.attachment[each.key].id
  transit_gateway_id      = local.tgw_name_to_id[each.value.tgw_name]
}

resource "aws_ec2_transit_gateway_connect" "connect-2" {
  for_each                = local.transit_tgw_map
  transport_attachment_id = aws_ec2_transit_gateway_vpc_attachment.attachment[each.key].id
  transit_gateway_id      = local.tgw_name_to_id[each.value.tgw_name]
}

resource "aws_ec2_transit_gateway_connect" "connect-3" {
  for_each                = local.transit_tgw_map
  transport_attachment_id = aws_ec2_transit_gateway_vpc_attachment.attachment[each.key].id
  transit_gateway_id      = local.tgw_name_to_id[each.value.tgw_name]
}

resource "aws_ec2_transit_gateway_connect" "connect-4" {
  for_each                = local.transit_tgw_map
  transport_attachment_id = aws_ec2_transit_gateway_vpc_attachment.attachment[each.key].id
  transit_gateway_id      = local.tgw_name_to_id[each.value.tgw_name]
}

resource "aws_ec2_transit_gateway_connect_peer" "connect_peer-1" {
  for_each                      = local.transit_tgw_map
  bgp_asn                       = module.mc-transit[each.value.transit_key].transit_gateway.local_as_number
  inside_cidr_blocks            = [var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].connect_peer_1]
  peer_address                  = module.mc-transit[each.value.transit_key].transit_gateway.private_ip
  transit_gateway_address       = local.tgw_connect_ip[each.key].connect_peer_1
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.connect-1[each.key].id
}

resource "aws_ec2_transit_gateway_connect_peer" "ha_connect_peer-1" {
  for_each                      = local.transit_tgw_map
  bgp_asn                       = module.mc-transit[each.value.transit_key].transit_gateway.local_as_number
  inside_cidr_blocks            = [var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].ha_connect_peer_1]
  peer_address                  = module.mc-transit[each.value.transit_key].transit_gateway.ha_private_ip
  transit_gateway_address       = local.tgw_connect_ip[each.key].ha_connect_peer_1
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.connect-1[each.key].id
}

resource "aws_ec2_transit_gateway_connect_peer" "connect_peer-2" {
  for_each                      = local.transit_tgw_map
  bgp_asn                       = module.mc-transit[each.value.transit_key].transit_gateway.local_as_number
  inside_cidr_blocks            = [var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].connect_peer_2]
  peer_address                  = module.mc-transit[each.value.transit_key].transit_gateway.private_ip
  transit_gateway_address       = local.tgw_connect_ip[each.key].connect_peer_2
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.connect-1[each.key].id
}

resource "aws_ec2_transit_gateway_connect_peer" "ha_connect_peer-2" {
  for_each                      = local.transit_tgw_map
  bgp_asn                       = module.mc-transit[each.value.transit_key].transit_gateway.local_as_number
  inside_cidr_blocks            = [var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].ha_connect_peer_2]
  peer_address                  = module.mc-transit[each.value.transit_key].transit_gateway.ha_private_ip
  transit_gateway_address       = local.tgw_connect_ip[each.key].ha_connect_peer_2
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.connect-1[each.key].id
}

resource "aws_ec2_transit_gateway_connect_peer" "connect_peer-3" {
  for_each                      = local.transit_tgw_map
  bgp_asn                       = module.mc-transit[each.value.transit_key].transit_gateway.local_as_number
  inside_cidr_blocks            = [var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].connect_peer_3]
  peer_address                  = module.mc-transit[each.value.transit_key].transit_gateway.private_ip
  transit_gateway_address       = local.tgw_connect_ip[each.key].connect_peer_3
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.connect-2[each.key].id
}

resource "aws_ec2_transit_gateway_connect_peer" "ha_connect_peer-3" {
  for_each                      = local.transit_tgw_map
  bgp_asn                       = module.mc-transit[each.value.transit_key].transit_gateway.local_as_number
  inside_cidr_blocks            = [var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].ha_connect_peer_3]
  peer_address                  = module.mc-transit[each.value.transit_key].transit_gateway.ha_private_ip
  transit_gateway_address       = local.tgw_connect_ip[each.key].ha_connect_peer_3
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.connect-2[each.key].id
}

resource "aws_ec2_transit_gateway_connect_peer" "connect_peer-4" {
  for_each                      = local.transit_tgw_map
  bgp_asn                       = module.mc-transit[each.value.transit_key].transit_gateway.local_as_number
  inside_cidr_blocks            = [var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].connect_peer_4]
  peer_address                  = module.mc-transit[each.value.transit_key].transit_gateway.private_ip
  transit_gateway_address       = local.tgw_connect_ip[each.key].connect_peer_4
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.connect-2[each.key].id
}

resource "aws_ec2_transit_gateway_connect_peer" "ha_connect_peer-4" {
  for_each                      = local.transit_tgw_map
  bgp_asn                       = module.mc-transit[each.value.transit_key].transit_gateway.local_as_number
  inside_cidr_blocks            = [var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].ha_connect_peer_4]
  peer_address                  = module.mc-transit[each.value.transit_key].transit_gateway.ha_private_ip
  transit_gateway_address       = local.tgw_connect_ip[each.key].ha_connect_peer_4
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.connect-2[each.key].id
}

resource "aws_ec2_transit_gateway_connect_peer" "connect_peer-5" {
  for_each                      = local.transit_tgw_map
  bgp_asn                       = module.mc-transit[each.value.transit_key].transit_gateway.local_as_number
  inside_cidr_blocks            = [var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].connect_peer_5]
  peer_address                  = module.mc-transit[each.value.transit_key].transit_gateway.private_ip
  transit_gateway_address       = local.tgw_connect_ip[each.key].connect_peer_5
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.connect-3[each.key].id
}

resource "aws_ec2_transit_gateway_connect_peer" "ha_connect_peer-5" {
  for_each                      = local.transit_tgw_map
  bgp_asn                       = module.mc-transit[each.value.transit_key].transit_gateway.local_as_number
  inside_cidr_blocks            = [var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].ha_connect_peer_5]
  peer_address                  = module.mc-transit[each.value.transit_key].transit_gateway.ha_private_ip
  transit_gateway_address       = local.tgw_connect_ip[each.key].ha_connect_peer_5
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.connect-3[each.key].id
}

resource "aws_ec2_transit_gateway_connect_peer" "connect_peer-6" {
  for_each                      = local.transit_tgw_map
  bgp_asn                       = module.mc-transit[each.value.transit_key].transit_gateway.local_as_number
  inside_cidr_blocks            = [var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].connect_peer_6]
  peer_address                  = module.mc-transit[each.value.transit_key].transit_gateway.private_ip
  transit_gateway_address       = local.tgw_connect_ip[each.key].connect_peer_6
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.connect-3[each.key].id
}

resource "aws_ec2_transit_gateway_connect_peer" "ha_connect_peer-6" {
  for_each                      = local.transit_tgw_map
  bgp_asn                       = module.mc-transit[each.value.transit_key].transit_gateway.local_as_number
  inside_cidr_blocks            = [var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].ha_connect_peer_6]
  peer_address                  = module.mc-transit[each.value.transit_key].transit_gateway.ha_private_ip
  transit_gateway_address       = local.tgw_connect_ip[each.key].ha_connect_peer_6
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.connect-3[each.key].id
}

resource "aws_ec2_transit_gateway_connect_peer" "connect_peer-7" {
  for_each                      = local.transit_tgw_map
  bgp_asn                       = module.mc-transit[each.value.transit_key].transit_gateway.local_as_number
  inside_cidr_blocks            = [var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].connect_peer_7]
  peer_address                  = module.mc-transit[each.value.transit_key].transit_gateway.private_ip
  transit_gateway_address       = local.tgw_connect_ip[each.key].connect_peer_7
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.connect-4[each.key].id
}

resource "aws_ec2_transit_gateway_connect_peer" "ha_connect_peer-7" {
  for_each                      = local.transit_tgw_map
  bgp_asn                       = module.mc-transit[each.value.transit_key].transit_gateway.local_as_number
  inside_cidr_blocks            = [var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].ha_connect_peer_7]
  peer_address                  = module.mc-transit[each.value.transit_key].transit_gateway.ha_private_ip
  transit_gateway_address       = local.tgw_connect_ip[each.key].ha_connect_peer_7
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.connect-4[each.key].id
}

resource "aws_ec2_transit_gateway_connect_peer" "connect_peer-8" {
  for_each                      = local.transit_tgw_map
  bgp_asn                       = module.mc-transit[each.value.transit_key].transit_gateway.local_as_number
  inside_cidr_blocks            = [var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].connect_peer_8]
  peer_address                  = module.mc-transit[each.value.transit_key].transit_gateway.private_ip
  transit_gateway_address       = local.tgw_connect_ip[each.key].connect_peer_8
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.connect-4[each.key].id
}

resource "aws_ec2_transit_gateway_connect_peer" "ha_connect_peer-8" {
  for_each                      = local.transit_tgw_map
  bgp_asn                       = module.mc-transit[each.value.transit_key].transit_gateway.local_as_number
  inside_cidr_blocks            = [var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].ha_connect_peer_8]
  peer_address                  = module.mc-transit[each.value.transit_key].transit_gateway.ha_private_ip
  transit_gateway_address       = local.tgw_connect_ip[each.key].ha_connect_peer_8
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.connect-4[each.key].id
}

resource "aviatrix_transit_external_device_conn" "external-1" {
  for_each                    = local.transit_tgw_map
  vpc_id                      = module.mc-transit[each.value.transit_key].vpc.vpc_id
  connection_name             = "external-${each.value.tgw_name}-${local.tgw_name_to_id[each.value.tgw_name]}-1-${each.value.transit_key}"
  gw_name                     = module.mc-transit[each.value.transit_key].transit_gateway.gw_name
  remote_gateway_ip           = "${local.tgw_connect_ip[each.key].connect_peer_1},${local.tgw_connect_ip[each.key].ha_connect_peer_1}"
  direct_connect              = true
  bgp_local_as_num            = module.mc-transit[each.value.transit_key].transit_gateway.local_as_number
  bgp_remote_as_num           = local.tgw_name_to_info[each.value.tgw_name].amazon_side_asn
  tunnel_protocol             = "GRE"
  ha_enabled                  = false
  local_tunnel_cidr           = "${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].connect_peer_1, 1)}/29,${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].ha_connect_peer_1, 1)}/29"
  remote_tunnel_cidr          = "${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].connect_peer_1, 2)}/29,${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].ha_connect_peer_1, 2)}/29"
  custom_algorithms           = false
  phase1_local_identifier     = null
  enable_jumbo_frame          = true
  manual_bgp_advertised_cidrs = var.transits[each.value.transit_key].manual_bgp_advertised_cidrs

  lifecycle {
    ignore_changes = [backup_bgp_remote_as_num, backup_direct_connect, backup_remote_gateway_ip, disable_activemesh, ha_enabled, local_tunnel_cidr, remote_gateway_ip, remote_tunnel_cidr]
  }
}

resource "aviatrix_transit_external_device_conn" "external-2" {
  for_each                    = local.transit_tgw_map
  vpc_id                      = module.mc-transit[each.value.transit_key].vpc.vpc_id
  connection_name             = "external-${each.value.tgw_name}-${local.tgw_name_to_id[each.value.tgw_name]}-2-${each.value.transit_key}"
  gw_name                     = module.mc-transit[each.value.transit_key].transit_gateway.gw_name
  remote_gateway_ip           = "${local.tgw_connect_ip[each.key].connect_peer_2},${local.tgw_connect_ip[each.key].ha_connect_peer_2}"
  direct_connect              = true
  bgp_local_as_num            = module.mc-transit[each.value.transit_key].transit_gateway.local_as_number
  bgp_remote_as_num           = local.tgw_name_to_info[each.value.tgw_name].amazon_side_asn
  tunnel_protocol             = "GRE"
  ha_enabled                  = false
  local_tunnel_cidr           = "${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].connect_peer_2, 1)}/29,${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].ha_connect_peer_2, 1)}/29"
  remote_tunnel_cidr          = "${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].connect_peer_2, 2)}/29,${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].ha_connect_peer_2, 2)}/29"
  custom_algorithms           = false
  phase1_local_identifier     = null
  enable_jumbo_frame          = true
  manual_bgp_advertised_cidrs = var.transits[each.value.transit_key].manual_bgp_advertised_cidrs

  lifecycle {
    ignore_changes = [backup_bgp_remote_as_num, backup_direct_connect, backup_remote_gateway_ip, disable_activemesh, ha_enabled, local_tunnel_cidr, remote_gateway_ip, remote_tunnel_cidr]
  }
}

resource "aviatrix_transit_external_device_conn" "external-3" {
  for_each                    = local.transit_tgw_map
  vpc_id                      = module.mc-transit[each.value.transit_key].vpc.vpc_id
  connection_name             = "external-${each.value.tgw_name}-${local.tgw_name_to_id[each.value.tgw_name]}-3-${each.value.transit_key}"
  gw_name                     = module.mc-transit[each.value.transit_key].transit_gateway.gw_name
  remote_gateway_ip           = "${local.tgw_connect_ip[each.key].connect_peer_3},${local.tgw_connect_ip[each.key].ha_connect_peer_3}"
  direct_connect              = true
  bgp_local_as_num            = module.mc-transit[each.value.transit_key].transit_gateway.local_as_number
  bgp_remote_as_num           = local.tgw_name_to_info[each.value.tgw_name].amazon_side_asn
  tunnel_protocol             = "GRE"
  ha_enabled                  = false
  local_tunnel_cidr           = "${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].connect_peer_3, 1)}/29,${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].ha_connect_peer_3, 1)}/29"
  remote_tunnel_cidr          = "${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].connect_peer_3, 2)}/29,${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].ha_connect_peer_3, 2)}/29"
  custom_algorithms           = false
  phase1_local_identifier     = null
  enable_jumbo_frame          = true
  manual_bgp_advertised_cidrs = var.transits[each.value.transit_key].manual_bgp_advertised_cidrs

  lifecycle {
    ignore_changes = [backup_bgp_remote_as_num, backup_direct_connect, backup_remote_gateway_ip, disable_activemesh, ha_enabled, local_tunnel_cidr, remote_gateway_ip, remote_tunnel_cidr]
  }
}

resource "aviatrix_transit_external_device_conn" "external-4" {
  for_each                    = local.transit_tgw_map
  vpc_id                      = module.mc-transit[each.value.transit_key].vpc.vpc_id
  connection_name             = "external-${each.value.tgw_name}-${local.tgw_name_to_id[each.value.tgw_name]}-4-${each.value.transit_key}"
  gw_name                     = module.mc-transit[each.value.transit_key].transit_gateway.gw_name
  remote_gateway_ip           = "${local.tgw_connect_ip[each.key].connect_peer_4},${local.tgw_connect_ip[each.key].ha_connect_peer_4}"
  direct_connect              = true
  bgp_local_as_num            = module.mc-transit[each.value.transit_key].transit_gateway.local_as_number
  bgp_remote_as_num           = local.tgw_name_to_info[each.value.tgw_name].amazon_side_asn
  tunnel_protocol             = "GRE"
  ha_enabled                  = false
  local_tunnel_cidr           = "${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].connect_peer_4, 1)}/29,${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].ha_connect_peer_4, 1)}/29"
  remote_tunnel_cidr          = "${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].connect_peer_4, 2)}/29,${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].ha_connect_peer_4, 2)}/29"
  custom_algorithms           = false
  phase1_local_identifier     = null
  enable_jumbo_frame          = true
  manual_bgp_advertised_cidrs = var.transits[each.value.transit_key].manual_bgp_advertised_cidrs

  lifecycle {
    ignore_changes = [backup_bgp_remote_as_num, backup_direct_connect, backup_remote_gateway_ip, disable_activemesh, ha_enabled, local_tunnel_cidr, remote_gateway_ip, remote_tunnel_cidr]
  }
}

resource "aviatrix_transit_external_device_conn" "external-5" {
  for_each                    = local.transit_tgw_map
  vpc_id                      = module.mc-transit[each.value.transit_key].vpc.vpc_id
  connection_name             = "external-${each.value.tgw_name}-${local.tgw_name_to_id[each.value.tgw_name]}-5-${each.value.transit_key}"
  gw_name                     = module.mc-transit[each.value.transit_key].transit_gateway.gw_name
  remote_gateway_ip           = "${local.tgw_connect_ip[each.key].connect_peer_5},${local.tgw_connect_ip[each.key].ha_connect_peer_5}"
  direct_connect              = true
  bgp_local_as_num            = module.mc-transit[each.value.transit_key].transit_gateway.local_as_number
  bgp_remote_as_num           = local.tgw_name_to_info[each.value.tgw_name].amazon_side_asn
  tunnel_protocol             = "GRE"
  ha_enabled                  = false
  local_tunnel_cidr           = "${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].connect_peer_5, 1)}/29,${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].ha_connect_peer_5, 1)}/29"
  remote_tunnel_cidr          = "${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].connect_peer_5, 2)}/29,${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].ha_connect_peer_5, 2)}/29"
  custom_algorithms           = false
  phase1_local_identifier     = null
  enable_jumbo_frame          = true
  manual_bgp_advertised_cidrs = var.transits[each.value.transit_key].manual_bgp_advertised_cidrs

  lifecycle {
    ignore_changes = [backup_bgp_remote_as_num, backup_direct_connect, backup_remote_gateway_ip, disable_activemesh, ha_enabled, local_tunnel_cidr, remote_gateway_ip, remote_tunnel_cidr]
  }
}

resource "aviatrix_transit_external_device_conn" "external-6" {
  for_each                    = local.transit_tgw_map
  vpc_id                      = module.mc-transit[each.value.transit_key].vpc.vpc_id
  connection_name             = "external-${each.value.tgw_name}-${local.tgw_name_to_id[each.value.tgw_name]}-6-${each.value.transit_key}"
  gw_name                     = module.mc-transit[each.value.transit_key].transit_gateway.gw_name
  remote_gateway_ip           = "${local.tgw_connect_ip[each.key].connect_peer_6},${local.tgw_connect_ip[each.key].ha_connect_peer_6}"
  direct_connect              = true
  bgp_local_as_num            = module.mc-transit[each.value.transit_key].transit_gateway.local_as_number
  bgp_remote_as_num           = local.tgw_name_to_info[each.value.tgw_name].amazon_side_asn
  tunnel_protocol             = "GRE"
  ha_enabled                  = false
  local_tunnel_cidr           = "${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].connect_peer_6, 1)}/29,${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].ha_connect_peer_6, 1)}/29"
  remote_tunnel_cidr          = "${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].connect_peer_6, 2)}/29,${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].ha_connect_peer_6, 2)}/29"
  custom_algorithms           = false
  phase1_local_identifier     = null
  enable_jumbo_frame          = true
  manual_bgp_advertised_cidrs = var.transits[each.value.transit_key].manual_bgp_advertised_cidrs

  lifecycle {
    ignore_changes = [backup_bgp_remote_as_num, backup_direct_connect, backup_remote_gateway_ip, disable_activemesh, ha_enabled, local_tunnel_cidr, remote_gateway_ip, remote_tunnel_cidr]
  }
}

resource "aviatrix_transit_external_device_conn" "external-7" {
  for_each                    = local.transit_tgw_map
  vpc_id                      = module.mc-transit[each.value.transit_key].vpc.vpc_id
  connection_name             = "external-${each.value.tgw_name}-${local.tgw_name_to_id[each.value.tgw_name]}-7-${each.value.transit_key}"
  gw_name                     = module.mc-transit[each.value.transit_key].transit_gateway.gw_name
  remote_gateway_ip           = "${local.tgw_connect_ip[each.key].connect_peer_7},${local.tgw_connect_ip[each.key].ha_connect_peer_7}"
  direct_connect              = true
  bgp_local_as_num            = module.mc-transit[each.value.transit_key].transit_gateway.local_as_number
  bgp_remote_as_num           = local.tgw_name_to_info[each.value.tgw_name].amazon_side_asn
  tunnel_protocol             = "GRE"
  ha_enabled                  = false
  local_tunnel_cidr           = "${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].connect_peer_7, 1)}/29,${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].ha_connect_peer_7, 1)}/29"
  remote_tunnel_cidr          = "${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].connect_peer_7, 2)}/29,${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].ha_connect_peer_7, 2)}/29"
  custom_algorithms           = false
  phase1_local_identifier     = null
  enable_jumbo_frame          = true
  manual_bgp_advertised_cidrs = var.transits[each.value.transit_key].manual_bgp_advertised_cidrs

  lifecycle {
    ignore_changes = [backup_bgp_remote_as_num, backup_direct_connect, backup_remote_gateway_ip, disable_activemesh, ha_enabled, local_tunnel_cidr, remote_gateway_ip, remote_tunnel_cidr]
  }
}

resource "aviatrix_transit_external_device_conn" "external-8" {
  for_each                    = local.transit_tgw_map
  vpc_id                      = module.mc-transit[each.value.transit_key].vpc.vpc_id
  connection_name             = "external-${each.value.tgw_name}-${local.tgw_name_to_id[each.value.tgw_name]}-8-${each.value.transit_key}"
  gw_name                     = module.mc-transit[each.value.transit_key].transit_gateway.gw_name
  remote_gateway_ip           = "${local.tgw_connect_ip[each.key].connect_peer_8},${local.tgw_connect_ip[each.key].ha_connect_peer_8}"
  direct_connect              = true
  bgp_local_as_num            = module.mc-transit[each.value.transit_key].transit_gateway.local_as_number
  bgp_remote_as_num           = local.tgw_name_to_info[each.value.tgw_name].amazon_side_asn
  tunnel_protocol             = "GRE"
  ha_enabled                  = false
  local_tunnel_cidr           = "${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].connect_peer_8, 1)}/29,${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].ha_connect_peer_8, 1)}/29"
  remote_tunnel_cidr          = "${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].connect_peer_8, 2)}/29,${cidrhost(var.transits[each.value.transit_key].inside_cidr_blocks[each.value.tgw_name].ha_connect_peer_8, 2)}/29"
  custom_algorithms           = false
  phase1_local_identifier     = null
  enable_jumbo_frame          = true
  manual_bgp_advertised_cidrs = var.transits[each.value.transit_key].manual_bgp_advertised_cidrs

  lifecycle {
    ignore_changes = [backup_bgp_remote_as_num, backup_direct_connect, backup_remote_gateway_ip, disable_activemesh, ha_enabled, local_tunnel_cidr, remote_gateway_ip, remote_tunnel_cidr]
  }
}

resource "aviatrix_transit_firenet_policy" "inspection_policies" {
  for_each = {
    for p in concat(local.inspection_policies, local.external_inspection_policies) :
    p.pair_key => p
    if lookup(
      { for k, v in var.transits : local.stripped_names[k] => v.inspection_enabled },
      p.transit_key,
      false
    )
  }

  transit_firenet_gateway_name = module.mc-transit[each.value.transit_key].transit_gateway.gw_name
  inspected_resource_name      = "SITE2CLOUD:${each.value.connection_name}"

  depends_on = [
    aviatrix_firenet.firenet,
    aviatrix_transit_external_device_conn.external_device,
    aviatrix_transit_external_device_conn.external-1,
    aviatrix_transit_external_device_conn.external-2,
    aviatrix_transit_external_device_conn.external-3,
    aviatrix_transit_external_device_conn.external-4,
    aviatrix_transit_external_device_conn.external-5,
    aviatrix_transit_external_device_conn.external-6,
    aviatrix_transit_external_device_conn.external-7,
    aviatrix_transit_external_device_conn.external-8,
  ]
}

resource "aviatrix_transit_external_device_conn" "external_device" {
  for_each                  = local.external_device_pairs
  vpc_id                    = module.mc-transit[each.value.transit_key].vpc.vpc_id
  connection_name           = each.value.connection_name
  gw_name                   = module.mc-transit[each.value.transit_key].transit_gateway.gw_name
  remote_gateway_ip         = each.value.remote_gateway_ip
  backup_remote_gateway_ip  = each.value.ha_enabled ? each.value.backup_remote_gateway_ip : null
  backup_bgp_remote_as_num  = each.value.ha_enabled ? each.value.bgp_remote_asn : null
  connection_type           = each.value.bgp_enabled ? "bgp" : "static"
  bgp_local_as_num          = each.value.bgp_enabled ? module.mc-transit[each.value.transit_key].transit_gateway.local_as_number : null
  bgp_remote_as_num         = each.value.bgp_enabled ? each.value.bgp_remote_asn : null
  tunnel_protocol           = "IPsec"
  direct_connect            = false
  ha_enabled                = each.value.ha_enabled
  local_tunnel_cidr         = each.value.local_tunnel_cidr
  remote_tunnel_cidr        = each.value.remote_tunnel_cidr
  backup_local_tunnel_cidr  = each.value.ha_enabled ? each.value.backup_local_tunnel_cidr : null
  backup_remote_tunnel_cidr = each.value.ha_enabled ? each.value.backup_remote_tunnel_cidr : null
  enable_ikev2              = each.value.enable_ikev2 != null ? each.value.enable_ikev2 : false
  custom_algorithms         = false
  phase1_local_identifier   = null

  depends_on = [module.mc-transit]
}

resource "aws_ram_resource_share" "tgw_share" {
  for_each = { for k, v in var.tgws : k => v if v.create_tgw && (length(v.account_ids) > 0) }

  name                      = "tgw-share-${each.key}"
  allow_external_principals = length(each.value.account_ids) > 0 ? true : false

  tags = merge(var.tags, { Name = "tgw-share-${each.key}" })
}

resource "aws_ram_resource_association" "tgw_association" {
  for_each = { for k, v in var.tgws : k => v if v.create_tgw && (length(v.account_ids) > 0) }

  resource_arn       = aws_ec2_transit_gateway.tgw[each.key].arn
  resource_share_arn = aws_ram_resource_share.tgw_share[each.key].arn
}

resource "aws_ram_principal_association" "tgw_principal_account" {
  for_each           = local.tgw_account_pairs_map
  resource_share_arn = aws_ram_resource_share.tgw_share[each.value.tgw_name].arn
  principal          = each.value.account_id
}

module "mc-spoke" {
  depends_on = [module.mc-transit]
  for_each   = var.spokes
  source     = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version    = "8.0.0"

  account                          = each.value.account
  attached                         = each.value.attached
  cidr                             = each.value.cidr
  cloud                            = "aws"
  customized_spoke_vpc_routes      = each.value.customized_spoke_vpc_routes
  enable_max_performance           = each.value.insane_mode ? each.value.enable_max_performance : true
  included_advertised_spoke_routes = each.value.included_advertised_spoke_routes
  insane_mode                      = each.value.insane_mode
  instance_size                    = each.value.spoke_instance_size
  region                           = var.region

  transit_gw = module.mc-transit[each.value.transit_key].transit_gateway.gw_name

  name             = each.key
  enable_bgp       = each.value.enable_bgp
  local_as_number  = each.value.enable_bgp ? each.value.local_as_number : null
  allocate_new_eip = each.value.allocate_new_eip
  eip              = each.value.eip
  ha_eip           = each.value.ha_eip
  use_existing_vpc = each.value.use_existing_vpc
  vpc_id           = each.value.vpc_id
  gw_subnet        = each.value.gw_subnet
  hagw_subnet      = each.value.hagw_subnet
  single_ip_snat   = each.value.single_ip_snat
}

resource "random_id" "suffix" {
  for_each    = tls_private_key.generated
  byte_length = 4
}

resource "aws_secretsmanager_secret" "private_key" {
  for_each = tls_private_key.generated
  name     = "${each.key}-private-key-${random_id.suffix[each.key].hex}"
}

resource "aws_secretsmanager_secret_version" "private_key_version" {
  for_each      = tls_private_key.generated
  secret_id     = aws_secretsmanager_secret.private_key[each.key].id
  secret_string = each.value.private_key_pem
}

resource "aws_secretsmanager_secret" "public_key" {
  for_each = tls_private_key.generated
  name     = "${each.key}-public-key-${random_id.suffix[each.key].hex}"
}

resource "aws_secretsmanager_secret_version" "public_key_version" {
  for_each      = tls_private_key.generated
  secret_id     = aws_secretsmanager_secret.public_key[each.key].id
  secret_string = each.value.public_key_openssh
}
