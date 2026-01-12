# GCP VM Module

This module creates Google Cloud Platform (GCP) VM instances for testing purposes, providing a reusable and focused solution for VM provisioning.

## Features

- Creates both public and private VM instances in GCP
- Automatic SSH key generation or use of existing keys
- Configurable firewall rules for ingress and egress traffic
- Support for multiple VM instances per call
- Configurable instance sizes and zones
- Support for custom VM private IP assignments
- Integration with existing VPC and subnet infrastructure

## Usage

```hcl
module "gcp_vm" {
  source = "../../modules/mc-vm/gcp"

  resource_name_label = "test-vm"
  region              = "us-central1"
  vpc_id              = "projects/my-project/global/networks/my-vpc"
  public_subnet_id    = "projects/my-project/regions/us-central1/subnetworks/public-subnet"
  private_subnet_id   = "projects/my-project/regions/us-central1/subnetworks/private-subnet"
  
  vm_count = 2
  az1      = "a"
  az2      = "b"
  
  ingress_cidrs = ["10.0.0.0/8", "172.16.0.0/12"]
  owner         = "terraform"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| resource_name_label | The label to be prepended for the resource name | `string` | n/a | yes |
| region | Region of the VPC - where the VMs will be deployed in | `string` | n/a | yes |
| vpc_id | ID of the VPC - where the VMs will be deployed in | `string` | n/a | yes |
| public_subnet_id | Public subnet where the public VM will be deployed | `string` | n/a | yes |
| private_subnet_id | Private subnet where the private VM will be deployed | `string` | n/a | yes |
| ingress_cidrs | List of CIDRs to allow ingress traffic thru SSH/ICMP to the VMs | `list(string)` | `[]` | no |
| use_existing_keypair | Set to true if using an existing keypair for the VM(s) | `bool` | `false` | no |
| public_key | Public key to be used for the VM(s). Required if using an existing keypair | `string` | `""` | no |
| egress_cidrs | List of CIDRs to allow egress traffic to, from the VMs | `list(string)` | `["0.0.0.0/0"]` | no |
| vm_count | Number of VM pairs (public + private) to launch | `number` | `1` | no |
| owner | Owner of the VMs. Will tag the resources in this module | `string` | `"terraform"` | no |
| instance_size | Instance size for the virtual machines | `string` | `""` | no |
| deploy_private_vm | Whether to deploy private vm or not | `bool` | `true` | no |
| tags | A map of key/value string pairs to assign to the VMs | `map(string)` | `{}` | no |
| vm_admin_username | Admin username of the VM | `string` | `"ubuntu"` | no |
| az1 | Concatenate with region to form zones. eg. us-central1-a. Used for public VM | `string` | `"a"` | no |
| az2 | Concatenate with region to form zones. eg. us-central1-b. Used for private VM | `string` | `"b"` | no |

## Outputs

| Name | Description |
|------|-------------|
| vm | Complete VM information including instances, IPs, and SSH key details |

The `vm` output contains:
- `public_vm_obj_list`: List of public VM instance objects
- `private_vm_obj_list`: List of private VM instance objects  
- `public_vm_name_list`: List of public VM names
- `private_vm_name_list`: List of private VM names
- `public_vm_id_list`: List of public VM instance IDs
- `private_vm_id_list`: List of private VM instance IDs
- `public_vm_public_ip_list`: List of public VM external IP addresses
- `vm_private_ip_list`: List of all VM private IP addresses
- `private_vm_private_ip_list`: List of private VM private IP addresses
- `private_key_filename`: Path to the generated private key file

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| google | ~> 6.0 |
| http | ~> 3.0 |
| local | ~> 2.5 |
| tls | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| google | ~> 6.0 |
| http | ~> 3.0 |
| local | ~> 2.5 |
| tls | ~> 4.0 |
