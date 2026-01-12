/*
    VPC-level scope
*/
data "aws_vpc" "vpc" {
  count = local.cloud == "aws" ? 1 : 0
  id    = local.vpc_id
}

// local vars
locals {
  cloud = "aws"

  # Determine "sub" CSP
  is_china = can(regex("^cn-|^china ", lower(var.region))) && contains(["aws", "azure"], local.cloud)            # If a region in Azure or AWS starts with China prefix, then results in true.
  is_gov   = can(regex("^us-gov|^usgov |^usdod ", lower(var.region))) && contains(["aws", "azure"], local.cloud) # If a region in Azure or AWS starts with Gov/DoD prefix, then results in true.

  instance_size = length(var.instance_size) > 0 ? var.instance_size : lookup(local.instance_size_map, local.cloud, null)
  instance_size_map = {
    aws   = "t3a.micro",
    gcp   = "n1-standard-1",
    azure = "Standard_B1ms",
    oci   = "VM.Standard.A1.Flex"
  }

  # Official Canonical OwnerId for Ubuntu AMIs
  ami_owner = (
    (local.is_gov ?
      "513442679011"
      :
      (local.is_china ?
        "837727238323"
        :
        "099720109477"
      )
    )
  )
  ubuntu_ami = (var.ubuntu_ami != "" ? var.ubuntu_ami : data.aws_ami.ubuntu_20_04_lts[0].id)

  public_key = var.use_existing_keypair ? var.public_key : tls_private_key.ssh_key[0].public_key_openssh

  # Use Resource Group for Azure
  # Use VPC name for GCP (split by project name)
  vpc_id = (
    (local.cloud == "azure" ?
      split(":", var.vpc_id)[1]
      :
      (local.cloud == "gcp" ?
        split("~-~", var.vpc_id)[0]
        :
        var.vpc_id
      )
    )
  )
  # For Azure, grab VNet name from Aviatrix vpc_id
  vnet_name = ""

  zone1 = "${var.region}-${var.az1}"
  zone2 = "${var.region2}-${var.az2}"

  # Use for looping custom subnets list, if vm_count > number of provided subnets
  num_pub_subnet  = length(var.public_subnet_list)
  num_priv_subnet = length(var.private_subnet_list)

  # Use for calculating list of default allowed CIDRs for ingress_cidrs if none provided
  my_ip                 = "${chomp(data.http.my_ip.response_body)}/32"
  vpc_cidr              = data.aws_vpc.vpc[0].cidr_block
  rfc_1918_cidrs        = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  default_ingress_cidrs = concat(local.rfc_1918_cidrs, formatlist(local.my_ip), formatlist(local.vpc_cidr))
  ingress_cidrs         = length(var.ingress_cidrs) > 0 ? var.ingress_cidrs : local.default_ingress_cidrs

  # "Default" tags for the VMs, to merge with additional user-inputted tags
  aws_sg_default_tags = {
    Name  = "${var.resource_name_label}-sg-${var.region}"
    Owner = var.owner
  }
  aws_key_default_tags = {
    Name  = "${var.resource_name_label}-key-${var.region}"
    Owner = var.owner
  }

  aws_sg_tags  = merge(local.aws_sg_default_tags, var.tags)
  aws_key_tags = merge(local.aws_key_default_tags, var.tags)

  # User data
  user_data = var.user_data_filename != "" ? "${file(var.user_data_filename)}" : "${file("${path.module}/../init.sh")}"
}

resource "aws_security_group" "sg" {
  count       = local.cloud == "aws" ? 1 : 0
  name        = "${var.resource_name_label}-sg"
  description = "Allow SSH connection and ICMP to ubuntu instances."
  vpc_id      = local.vpc_id

  ingress {
    # SSH
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = local.ingress_cidrs
  }
  ingress {
    # ICMP
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = local.ingress_cidrs
  }

  egress {
    # Allow all
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.egress_cidrs
  }

  tags = local.aws_sg_tags
}

/*
    Instance-level scope
*/
resource "random_id" "key_id" {
  count       = local.cloud == "aws" ? 1 : 0
  byte_length = 4
}

resource "aws_key_pair" "key_pair" {
  count      = local.cloud == "aws" ? 1 : 0
  key_name   = "${var.resource_name_label}-key-${random_id.key_id[0].dec}"
  public_key = local.public_key
  tags       = local.aws_key_tags
}

data "aws_ami" "ubuntu_20_04_lts" {
  count       = local.cloud == "aws" ? 1 : 0
  most_recent = true
  owners      = [local.ami_owner] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "public_instance" {
  count                       = local.cloud == "aws" ? var.vm_count : 0
  ami                         = local.ubuntu_ami
  instance_type               = local.instance_size
  disable_api_termination     = var.termination_protection
  associate_public_ip_address = true
  private_ip                  = length(var.public_vm_private_ip_list) > 0 ? var.public_vm_private_ip_list[count.index] : null
  subnet_id                   = var.use_custom_subnets ? var.public_subnet_list[count.index % local.num_pub_subnet] : var.public_subnet_id
  vpc_security_group_ids      = var.use_custom_security_group ? var.vpc_security_group_ids : [aws_security_group.sg[0].id]
  key_name                    = aws_key_pair.key_pair[0].key_name

  # not simplified in locals due to use of count.index
  tags = merge(
    {
      Name  = "${var.resource_name_label}-public-vm${count.index}-${var.region}",
      Owner = var.owner
    },
    var.tags
  )

  user_data = local.user_data
}

resource "aws_instance" "private_instance" {
  count                       = local.cloud == "aws" && var.deploy_private_vm ? var.vm_count : 0
  ami                         = local.ubuntu_ami
  instance_type               = local.instance_size
  disable_api_termination     = var.termination_protection
  associate_public_ip_address = false
  private_ip                  = length(var.private_vm_private_ip_list) > 0 ? var.private_vm_private_ip_list[count.index] : null
  subnet_id                   = var.use_custom_subnets ? var.private_subnet_list[count.index % local.num_priv_subnet] : var.private_subnet_id
  vpc_security_group_ids      = var.use_custom_security_group ? var.vpc_security_group_ids : [aws_security_group.sg[0].id]
  key_name                    = aws_key_pair.key_pair[0].key_name
  source_dest_check           = var.source_dest_check

  # not simplified in locals due to use of count.index
  tags = merge(
    {
      Name  = "${var.resource_name_label}-private-vm${count.index}-${var.region}",
      Owner = var.owner
    },
    var.tags
  )

  user_data = file("${path.module}/startup_script.sh")
}
