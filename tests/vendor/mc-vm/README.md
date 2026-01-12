# terraform-aviatrix-mc-vm

## Description
Deploys public/private Ubuntu/Linux instance pair(s) in a specified VPC/VNet/VCN's public/private subnet

## Usage examples
```
module "mc_vm" {
    source = "./modules/mc-vm"
    # insert required variables here
}
```

Please see the examples/README.md for more details

## Resources
### Prerequisites
- An existing VPC/VNet/VCN, with public and private subnets

### To be built
#### Common
- [tls_private_key](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key)
- [local_file](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file)

#### AWS
- [aws_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)
- [aws_key_pair](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/key_pair)
- [aws_eip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip)
- [aws_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance)

#### Azure
- [azurerm_network_security_group](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group)
- [azurerm_network_security_rule](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_rule)
- [azurerm_network_interface](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface)
- [azurerm_public_ip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip)
- [azurerm_linux_virtual_machine](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine)

#### GCP
- [google_compute_firewall](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall)
- [google_compute_instance](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance)

#### OCI
- [oci_core_network_security_group](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_network_security_group)
- [oci_core_network_security_group_rule](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_network_security_group_rule)
- [oci_core_instance](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_instance)

## Variables

The following variables are required:

|      Attribute      |   Type   |                                  Description                                  |
| :-----------------: | :------: | :---------------------------------------------------------------------------: |
| resource_name_label | `string` |                  Label for the resources + virtual machines                   |
|       region        | `string` |                         Region deploy this module in                          |
|       vpc_id        | `string` |                     VPC where the VMs will be deployed in                     |
|  public_subnet_id   | `string` |             Public subnet where the public VM will be deployed in             |
|  private_subnet_id  | `string` |            Private subnet where the private VM will be deployed in            |

> `vpc_id` format should be as follows:
> - **AWS:** "<vpc_id>"
> - **Azure:** "<vnet_name>:<resource_group_name>:<GUID>"
> - **GCP:** "<vpc_name>~-~<project_id>"
> - **OCI:** "<vcn_ocid>"


The following variables are optional:

|         Attribute          |      type      | Supported CSPs |                                    Default value                                    |                                                                  Description                                                                  |
| :------------------------: | :------------: | :------------: | :---------------------------------------------------------------------------------: | :-------------------------------------------------------------------------------------------------------------------------------------------: |
|    use_existing_keypair    |     `bool`     |      ALL       |                                        false                                        |                                  Set to true if using an existing keypair, rather than generating a new one                                   |
|         public_key         |    `string`    |      ALL       |                                         ""                                          |                             The public key content in ssh-rsa format. Required if `use_existing_keypair` is true                              |
|          vm_count          |    `number`    |      ALL       |                                          1                                          |                                                Number of VM pairs (public + private) to launch                                                |
|       instance_size        |    `string`    |      ALL       | t3.small<br>n1-standard-1<br>Standard_B1ms<br>VM.Standard2.2<br>VM.Standard.A1.Flex |                                                      Instance size for virtual machines                                                       |
|           owner            |    `string`    |      ALL       |                                                                                     |                                                                Owner of the VM                                                                |
|            tags            | `map(string)`  |      ALL       |                                         {}                                          |                                             A map of key/value string pairs to assign to the VMs                                              |
|       ingress_cidrs        | `list(string)` |      ALL       |                  ["<RFC1918>", "<VPC-CIDR>", "<HOST-MACHINE-IP>"]                   |                                List of ingress CIDR ranges to allow SSH/ICMP access to VMs. eg. ["0.0.0.0/0"]                                 |
|        egress_cidrs        | `list(string)` |      ALL       |                                    ["0.0.0.0/0"]                                    |                                List of egress CIDR ranges to allow SSH/ICMP access from VMs. eg. ["0.0.0.0/0"]                                |
|     use_custom_subnets     |     `bool`     |      ALL       |                                        false                                        |                   Set to true if launching VMs in specified subnets, rather than the default singular pub/priv subnet pair.                   |
|     public_subnet_list     | `list(string)` |      ALL       |                                         []                                          |                         List of public subnet IDs to launch public VMs into. Required if `use_custom_subnets` is true                         |
|    private_subnet_list     | `list(string)` |      ALL       |                                         []                                          |                        List of private subnet IDs to launch private VMs into. Required if `use_custom_subnets` is true                        |
| public_vm_private_ip_list  | `list(string)` |      ALL       |                                         []                                          |                 List of private IPs to assign to the public VMs; will be assigned chronologically<sup>[\[1\]](#note_1)</sup>                  |
| private_vm_private_ip_list | `list(string)` |      ALL       |                                         []                                          |                 List of private IPs to assign to the private VMs; will be assigned chronologically<sup>[\[1\]](#note_1)</sup>                 |
|   termination_protection   |     `bool`     |      AWS       |                                        true                                         |                                         Set to true to enable AWS termination protection of instances                                         |
|     source_dest_check      |     `bool`     |      AWS       |                                        true                                         |               Set to false to allow the PRIVATE instance to send and receive traffic when the source or destination is not itself                |
|         ubuntu_ami         |    `string`    |      AWS       |                                                                                     |                                             AMI ID for a specific image to be used for the VM(s)                                              |
|     vm_admin_username      |    `string`    |  Azure<br>GCP  |                                       ubuntu                                        |                                                    Username of the admin account on the VM                                                    |
|          region2           |    `string`    |      GCP       |                                         ""                                          |                      Region of the VCN's second subnet - where the private VM will be deployed in. Required for GCP only                      |
|            az1             |    `string`    |      GCP       |                                         "b"                                         |                        Concatenate with region to form zones. eg. us-central1-a. Only used for GCP to launch public VM                        |
|            az2             |    `string`    |      GCP       |                                         "c"                                         |                       Concatenate with region to form zones. eg. us-central1-b. Only used for GCP to launch private VM                        |
| public_subnet_region_list  | `list(string)` |      GCP       |                                         []                                          |  List of public subnets' regions (in their respective order, as listed in the `public_subnet_list`) - where the public VMs will be launched   |
| private_subnet_region_list | `list(string)` |      GCP       |                                         []                                          | List of private subnets' regions (in their respective order, as listed in the `private_subnet_list`) - where the private VMs will be launched |

<a id="note_1"></a><sup>[1]</sup> *Number of private IPs in the list must match the number of VMs being created (`vm_count`)*

## Outputs

This module will return one output as a map, `vm {}`.

This map will contain the following attributes:

### Common
|            Key             |      Type      |                                   Description                                   |
| :------------------------: | :------------: | :-----------------------------------------------------------------------------: |
|    private_key_filename    |    `string`    |                 The generated private key's filename (filepath)                 |
|     public_vm_obj_list     |  `list(obj)`   | List of public VM instance(s) as (an) object(s), with all attributes outputted  |
|    private_vm_obj_list     |  `list(obj)`   | List of private VM instance(s) as (an) object(s), with all attributes outputted |
|    public_vm_name_list     | `list(string)` |                     List of the name(s) of the public VM(s)                     |
|    private_vm_name_list    | `list(string)` |                    List of the name(s) of the private VM(s)                     |
|     public_vm_id_list      | `list(string)` |                 List of the instance ID(s) of the public VM(s)                  |
|     private_vm_id_list     | `list(string)` |                 List of the instance ID(s) of the private VM(s)                 |
|  public_vm_public_ip_list  | `list(string)` |                  List of the public IP(s) of the public VM(s)                   |
|     vm_private_ip_list     | `list(string)` |                           List of VM(s) private IP(s)                           |
| private_vm_private_ip_list | `list(string)` |                   List of private IP(s) of the private VM(s)                    |

### AWS
|       Key        |   Type   |            Description            |
| :--------------: | :------: | :-------------------------------: |
| aws_keypair_name | `string` | Name of the AWS keypair generated |

```
# Example output
vm = {
    "aws_keypair_name" = "foobar-aws-key-413872098"
    "private_key_filename" = "foobar-aws-priv-key.pem"
    "private_vm_id_list" = [
        "i-abc123",
        "i-def456",
    ]
    "private_vm_name_list" = [
        "foobar-aws-private-vm0-us-east-1",
        "foobar-aws-private-vm1-us-east-1",
    ]
    "private_vm_obj_list" = [
        {
            "ami" = "ami-04b9e92b5572fa0d1"
            "arn" = "arn:aws:ec2:us-east-1:<redacted>:instance/i-abc123"
            "associate_public_ip_address" = false
            "availability_zone" = "us-east-1a"
            "capacity_reservation_specification" = tolist([
                {
                    "capacity_reservation_preference" = "open"
                    "capacity_reservation_target" = tolist([])
                }
            ])
        },
    # ...
    ],
    # ...
}
```


