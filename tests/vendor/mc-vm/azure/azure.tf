/*
    Networking-level scope
*/
data "azurerm_virtual_network" "vnet" {
  count               = local.cloud == "azure" ? 1 : 0
  name                = local.vnet_name
  resource_group_name = local.vpc_id
}

resource "azurerm_network_security_group" "sg" {
  count               = local.cloud == "azure" ? 1 : 0
  name                = "${var.resource_name_label}-sg"
  location            = var.region
  resource_group_name = local.vpc_id
}

// local vars
locals {
  cloud = "azure"

  # Determine "sub" CSP
  is_china          = can(regex("^cn-|^china ", lower(var.region))) && contains(["aws", "azure"], local.cloud)            # If a region in Azure or AWS starts with China prefix, then results in true.
  is_gov            = can(regex("^us-gov|^usgov |^usdod ", lower(var.region))) && contains(["aws", "azure"], local.cloud) # If a region in Azure or AWS starts with Gov/DoD prefix, then results in true.
  azure_environment = local.is_china ? "AzureChina" : local.is_gov ? "AzureUSGovernment" : "AzureCloud"

  instance_size = length(var.instance_size) > 0 ? var.instance_size : lookup(local.instance_size_map, local.cloud, null)
  instance_size_map = {
    aws   = "t3.small",
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
  ubuntu_ami = var.ubuntu_ami

  public_key = var.use_existing_keypair ? var.public_key : tls_private_key.ssh_key[0].public_key_openssh

  # Use Resource Group for Azure
  # Use VPC name for GCP (split by project name)
  vpc_id = split(":", var.vpc_id)[1]
  # For Azure, grab VNet name from Aviatrix vpc_id
  vnet_name = split(":", var.vpc_id)[0]

  zone1 = "${var.region}-${var.az1}"
  zone2 = "${var.region2}-${var.az2}"

  # Use for looping custom subnets list, if vm_count > number of provided subnets
  num_pub_subnet  = length(var.public_subnet_list)
  num_priv_subnet = length(var.private_subnet_list)

  # Use for calculating list of default allowed CIDRs for ingress_cidrs if none provided
  my_ip                 = "${chomp(data.http.my_ip.response_body)}/32"
  vpc_cidr              = data.azurerm_virtual_network.vnet[0].address_space[0]
  rfc_1918_cidrs        = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  default_ingress_cidrs = concat(local.rfc_1918_cidrs, formatlist(local.my_ip), formatlist(local.vpc_cidr))
  ingress_cidrs         = length(var.ingress_cidrs) > 0 ? var.ingress_cidrs : local.default_ingress_cidrs

  # User data
  user_data = var.user_data_filename != "" ? "${file(var.user_data_filename)}" : "${file("${path.module}/../init.sh")}"
}

resource "azurerm_network_security_rule" "ssh" {
  # Only create if Azure. If var.ingress_cidrs are specified, num of rules == num of elements, otherwise create 5
  # hard-coded 5 value due to TF not handling calculated argument of num of local.ingress_cidrs
  count = (local.cloud == "azure" ? (length(var.ingress_cidrs) > 0 ? length(var.ingress_cidrs) : 5) : 0)

  resource_group_name         = local.vpc_id
  network_security_group_name = azurerm_network_security_group.sg[0].name

  name                       = "allow-ssh-${count.index}"
  priority                   = sum([1001, pow(2, count.index + 1)]) # +1 on the index to avoid overlap of calculation for priority/direction in SSH/ICMP rules
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "22"
  source_address_prefix      = local.ingress_cidrs["${count.index}"]
  destination_address_prefix = "*"
}

resource "azurerm_network_security_rule" "icmp" {
  # Only create if Azure. If var.ingress_cidrs are specified, num of rules == num of elements, otherwise create 5
  # hard-coded 5 value due to TF not handling calculated argument of num of local.ingress_cidrs
  count = (local.cloud == "azure" ? (length(var.ingress_cidrs) > 0 ? length(var.ingress_cidrs) : 5) : 0)

  resource_group_name         = local.vpc_id
  network_security_group_name = azurerm_network_security_group.sg[0].name

  name                       = "allow-icmp-${count.index}"
  priority                   = sum([1002, pow(2, count.index + 1)]) # +1 on the index to avoid overlap of calculation for priority/direction in SSH/ICMP rules
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Icmp"
  source_port_range          = "*"
  destination_port_range     = "*"
  source_address_prefix      = local.ingress_cidrs["${count.index}"]
  destination_address_prefix = "*"
}

resource "azurerm_public_ip" "public_ip" {
  count               = local.cloud == "azure" ? var.vm_count : 0
  name                = "${var.resource_name_label}-public-ip-${count.index}"
  location            = var.region
  resource_group_name = local.vpc_id
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "public_nic" {
  count               = local.cloud == "azure" ? var.vm_count : 0
  name                = "${var.resource_name_label}-public-nic-${count.index}"
  location            = var.region
  resource_group_name = local.vpc_id

  ip_configuration {
    name                          = "${var.resource_name_label}-public-nic-ip-config-${count.index}"
    subnet_id                     = var.use_custom_subnets ? var.public_subnet_list[count.index % local.num_pub_subnet] : var.public_subnet_id
    public_ip_address_id          = azurerm_public_ip.public_ip[count.index].id
    private_ip_address_allocation = length(var.public_vm_private_ip_list) > 0 ? "Static" : "Dynamic"
    private_ip_address            = length(var.public_vm_private_ip_list) > 0 ? var.public_vm_private_ip_list[count.index] : null
  }

  depends_on = [
    azurerm_network_security_group.sg
  ]
}

resource "azurerm_network_interface" "private_nic" {
  count               = local.cloud == "azure" ? var.vm_count : 0
  name                = "${var.resource_name_label}-private-nic-${count.index}"
  location            = var.region
  resource_group_name = local.vpc_id

  ip_configuration {
    name                          = "${var.resource_name_label}-private-nic-ip-config-${count.index}"
    subnet_id                     = var.use_custom_subnets ? var.private_subnet_list[count.index % local.num_priv_subnet] : var.private_subnet_id
    private_ip_address_allocation = length(var.private_vm_private_ip_list) > 0 ? "Static" : "Dynamic"
    private_ip_address            = length(var.private_vm_private_ip_list) > 0 ? var.private_vm_private_ip_list[count.index] : null
  }

  depends_on = [
    azurerm_network_security_group.sg
  ]
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "sg_public_asso" {
  count                     = local.cloud == "azure" ? var.vm_count : 0
  network_interface_id      = azurerm_network_interface.public_nic[count.index].id
  network_security_group_id = azurerm_network_security_group.sg[0].id
}

resource "azurerm_network_interface_security_group_association" "sg_private_asso" {
  count                     = local.cloud == "azure" ? var.vm_count : 0
  network_interface_id      = azurerm_network_interface.private_nic[count.index].id
  network_security_group_id = azurerm_network_security_group.sg[0].id
}

/*
    Instance-level scope
*/
resource "azurerm_linux_virtual_machine" "public_vm" {
  count                           = local.cloud == "azure" ? var.vm_count : 0
  name                            = "${var.resource_name_label}-public-vm-${count.index}"
  admin_username                  = var.vm_admin_username
  disable_password_authentication = true

  location              = var.region
  resource_group_name   = local.vpc_id
  size                  = local.instance_size
  network_interface_ids = [azurerm_network_interface.public_nic[count.index].id]

  admin_ssh_key {
    username   = var.vm_admin_username
    public_key = local.public_key
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    name                 = "${var.resource_name_label}-public-disk-${count.index}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # not simplified in locals due to use of count.index
  tags = merge(
    {
      Name  = "${var.resource_name_label}-public-vm${count.index}-${var.region}",
      Owner = var.owner
    },
    var.tags
  )

  depends_on = [
    azurerm_network_interface_security_group_association.sg_public_asso
  ]

  custom_data = base64encode(local.user_data)
}

resource "azurerm_linux_virtual_machine" "private_vm" {
  count                           = local.cloud == "azure" ? var.vm_count : 0
  name                            = "${var.resource_name_label}-private-vm-${count.index}"
  admin_username                  = var.vm_admin_username
  disable_password_authentication = true

  location              = var.region
  resource_group_name   = local.vpc_id
  size                  = local.instance_size
  network_interface_ids = [azurerm_network_interface.private_nic[count.index].id]

  admin_ssh_key {
    username   = var.vm_admin_username
    public_key = local.public_key
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    name                 = "${var.resource_name_label}-private-disk-${count.index}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # not simplified in locals due to use of count.index
  tags = merge(
    {
      Name  = "${var.resource_name_label}-private-vm${count.index}-${var.region}",
      Owner = var.owner
    },
    var.tags
  )

  depends_on = [
    azurerm_network_interface_security_group_association.sg_private_asso
  ]

  custom_data = filebase64("${path.module}/startup_script.sh")
}
