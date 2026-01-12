# Aviatrix-AWS VPC module

## Description
Deploys an AWS VPC with public and private subnets for internal Aviatrix use- similar to our Aviatrix Create VPC Tool, but using AWS provider

## Usage examples
```
module "vpc" {
    source = "./vendor/modules/aws_vpc"

    vpc_name = "foo"
    vpc_cidr = "192.168.0.0/24"

    # optional
    subnet_size = 28
    number_subnet_pairs = 3
    secondary_vpc_cidr = "192.169.0.0/24"
    number_subnet_secondary = 1
}
```

## Resources
### To be built
- [AWS VPC module](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/)

## Variables

The following variables are required:

| Attribute |   Type   |               Description                |
| :-------: | :------: | :--------------------------------------: |
| vpc_name  | `string` |      Name of the VPC to be deployed      |
| vpc_cidr  | `string` | CIDR block of the VPC in RFC 1918 format |

The following variables are optional:

|        Attribute        |   Type   | Default |                                  Description                                  |
| :---------------------: | :------: | :-----: | :---------------------------------------------------------------------------: |
|   secondary_vpc_cidr    | `string` |   ""    | Secondary VPC CIDR blocks to associate with the VPC to extend IP address pool |
|   number_subnet_pairs   | `number` |    2    |                    Number of subnet pairs for the VPC CIDR                    |
| number_subnet_secondary | `number` |    0    |               Number of private subnets for secondary VPC CIDR                |
|       subnet_size       | `number` |   28    |                          Subnet size in CIDR format                           |

## Outputs

This module will return one output as a map, `vpc {}`.

This map will contain the following attributes:

|         Key          |      Type      |              Description               |
| :------------------: | :------------: | :------------------------------------: |
|        vpc_id        |    `string`    |             ID of the VPC              |
|       vpc_name       |    `string`    |            Name of the VPC             |
|       vpc_cidr       |    `string`    |                VPC CIDR                |
| public_subnet_cidrs  | `list(string)` | List of cidr_blocks of public_subnets  |
| private_subnet_cidrs | `list(string)` | List of cidr_blocks of private_subnets |
|  public_subnet_ids   | `list(string)` |     List of IDs of public subnets      |
|  private_subnet_ids  | `list(string)` |     List of IDs of private subnets     |
| public_subnet_names  | `list(string)` |    List of names of public subnets     |
| private_subnet_names | `list(string)` |    List of names of private subnets    |
|   azs_for_subnets    | `list(string)` |              List of AZs               |