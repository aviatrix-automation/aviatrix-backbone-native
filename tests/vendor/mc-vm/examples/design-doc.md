# AVX-20570 Module Design

---
Last updated: 17 Mar 2022 - by Anthony Lee
---

## Description
Design a proper foundational topology to have a repeatable template in Terraform to launch Ubuntu/Linux virtual machines in the supported multiple CSPs.

## Design
No matter the CSP, the prequsites for this VM module will be to have a pre-existing VPC/VNet/VCN, preferably created by Aviatrix.
This assumption allows us to have all the underlying complexities of (cloud) networking be abstracted away.

The main goal is to launch a public and private VM, in the specified public and private subnet respectively.

## Issue
The issue comes due to the way different CSPs handle their networking in terms of required resources and how they define a "VPC"
eg. AWS vs Azure, where Azure is compartmentalized by an over-arching "container" aka "resource group" that is global, and contains specific resources, such as a Virtual Network (VNet) aka VPC, which are region-specific.

There is a need to gather CSP-specific inputs, and abstract away into a common input attribute for this module.

## Requirements
### Common resources
- **tls_private_key** - generate private key for SSH purposes
- **local_file** - to write private key to a local file for ease of use
- some sort of public IP address resource, to be attached to the public VM

### Common attributes
- `vpc_id`
- `region`
- `public_subnet_id`
- `private_subnet_id`

### AWS
- **aws_eip** - AWS elastic (public) IP address
- **aws_key_pair** - created from the generated private key
- **aws_security_group** - to allow SSH and ICMP connections
- **aws_instance**
  - `ami` - the image ID (Amazon Machine Image)
  - `subnet_id` - the subnet (public/private) ID, which can be retrieved from **aviatrix_vpc**
  - `vpc_security_group_ids` - the security group ID as mentioned above
  - `key_name` - referenced from the **aws_key_pair**

### Azure
The RG, VNet, and subnet will be handled by the **aviatrix_vpc**
- **azurerm_public_ip** - Azure's equivalent of public IP address
- The **network_interface** might be something to either source from data_source, or created
  - network interface determines if the VM launched is public or private
  - public/private subnet is defined by UDR (user defined routing) explicitly in the route tables
    - this is already handled by Aviatrix if VNet is created thru tool
- **azurerm_ssh_public_key** - write openssh cred from **tls_private_key**
- **azurerm_linux_virtual_machine**
  - `resource_group_name` - reference from **aviatrix_vpc**'s `vpc_id`
  - `location`
  - `network_interface_ids = []` - TBD
  - `admin_ssh_keys {}` - referenced from the **azurerm_ssh_public_key**

### GCP
- **google_compute_project_metadata** - write openssh cred from **tls_private_key**
- **google_compute_firewall** - the GCP equivalent of the AWS security group, to allow SSH and ICMP
- **google_compute_address** - GCP's equivalent of elastic IP address
- **google_compute_instance**
  - `network_interface {}`
    - `network` - reference from **aviatrix_vpc**'s `vpc_id`
    - `subnetwork` - reference from **aviatrix_vpc**'s `subnets` 's `name`
    - `network_ip` - private IP (cidr host of existing subnetwork) - use data source
  - `metadata = {}`
    - `ssh-keys` - "${var.gce_ssh_user}:${file(var.gce_ssh_pub_key_file)}" - referenced from **google_compute_project_metadata**

### OCI
- **oci_core_subnet** - data source
- **oci_identity_availability_domains** - data source
- **oci_core_images** - data source
- **oci_core_instance**
  - `availability_domain` - can be referenced from **oci_identity_availability_domains**
  - `compartment_id` - can be referenced from **oci_core_subnet**
  - `create_vnic_details {}` - conveniently creates the NIC (network interface card) within the VM resource
    - `subnet_id` - OCID of the subnet to create NIC in
    - `private_ip` - private IP (cidr host of existing subnet) - use data source **oci_core_subnet**
  - `source_details {}`
    - `source_id` - the image ID for the VM - use data source **oci_core_images**
  - `metadata = {}`
    - `ssh_authorized_keys` - file(public_key) - tls_private_key.key01public_key_openssh - referenced from **tls_private_key**