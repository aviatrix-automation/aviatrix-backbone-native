# Usage Examples

This document contains examples on how to launch this module with various configurations (including using optional arguments).

For full details on available attributes, please see the original README.md

## Launching VMs into AWS

```
# Launching 1 VM pair into an AWS VPC
module aws_vm_module {
    source = "./vendor/modules/mc-vm/aws"

    resource_name_label = "foo-aws"
    region              = "us-east-1"
    vpc_id              = "vpc-abc123"
    public_subnet_id    = "subnet-0123"
    private_subnet_id   = "subnet-4567"
    ingress_cidrs       = ["<ip_cidr_range>", "<ip_cidr_range>"]
}
```
```
# Launching multiple VM pairs into an AWS VPC
module aws_vm_module {
    source = "./vendor/modules/mc-vm/aws"

    resource_name_label = "foo-aws"
    region              = "us-east-1"
    vpc_id              = "vpc-abc123"
    public_subnet_id    = "subnet-0123"
    private_subnet_id   = "subnet-4567"
    ingress_cidrs       = ["<ip_cidr_range>"]

    # optional
    vm_count                = 3
    egress_cidrs            = ["0.0.0.0/0"]
    owner                   = "foobar-name"
    termination_protection  = false
}
```
```
# Example showing referencing of a previously TF-created Aviatrix VPC
module aws_vm_module {
    source = "./vendor/modules/mc-vm/aws"

    resource_name_label = "foo-aws"
    region              = aviatrix_vpc.vpc.region
    vpc_id              = aviatrix_vpc.vpc.vpc_id
    public_subnet_id    = aviatrix_vpc.vpc.public_subnets[0].subnet_id
    private_subnet_id   = aviatrix_vpc.vpc.private_subnets[0].subnet_id
    ingress_cidrs       = ["<ip_cidr_range>"]

    # optional
    vm_count                = 2
    egress_cidrs            = ["0.0.0.0/0"]
    owner                   = "foobar-name"
    termination_protection  = false
}
```
```
# Example launching VM module into an AWS VPC, using an existing keypair
module aws_vm_module {
    source = "./vendor/modules/mc-vm/aws"

    resource_name_label = "foo-aws"
    region              = "us-east-1"
    vpc_id              = "vpc-abc123"
    public_subnet_id    = "subnet-0123"
    private_subnet_id   = "subnet-4567"
    ingress_cidrs       = ["<ip_cidr_range>", "<ip_cidr_range>"]

    # optional
    use_existing_keypair    = true
    public_key              = tls_private_key.ssh_key.public_key_openssh # Pass generated public key content
    # public_key            = file("foo-public-key.pub") # Alternatively, read the public key content using file()
}
```
```
# Example launching VM module into an AWS VPC, into multiple specified subnets, referencing a previously TF-created Aviatrix VPC
module aws_vm_module {
    source = "./vendor/modules/mc-vm/aws"

    resource_name_label = "foo-aws"
    region              = aviatrix_vpc.vpc.region
    vpc_id              = aviatrix_vpc.vpc.vpc_id
    ingress_cidrs       = ["<ip_cidr_range>", "<ip_cidr_range>"]

    # Required for multi-subnet launch
    use_custom_subnets  = true
    public_subnet_list  = [aviatrix_vpc.vpc.public_subnets[0].subnet_id, aviatrix_vpc.vpc.public_subnets[1].subnet_id, aviatrix_vpc.vpc.public_subnets[2].subnet_id]
    private_subnet_list = [aviatrix_vpc.vpc.private_subnets[0].subnet_id, aviatrix_vpc.vpc.private_subnets[1].subnet_id, aviatrix_vpc.vpc.private_subnets[2].subnet_id]

    # optional
    vm_count                = 3
    egress_cidrs            = ["0.0.0.0/0"]
    owner                   = "foobar-name"
    termination_protection  = false
}
```

## Launching VMs into Azure
```
# Launching 1 VM pair into an Azure RG
module azure_vm_module {
    source = "./vendor/modules/mc-vm/azure"

    resource_name_label = "foo-azure"
    region              = "Central US"
    vpc_id              = "<VNet-Name>:<Resource-Group>:<VNet-ID>"
    public_subnet_id    = "/subscriptions/<redacted>/resourceGroups/<resource-group>/providers/Microsoft.Network/virtualNetworks/<vnet-name>/subnets/<public-subnet-name>"
    private_subnet_id   = "/subscriptions/<redacted>/resourceGroups/<resource-group>/providers/Microsoft.Network/virtualNetworks/<vnet-name>/subnets/<private-subnet-name>"
    ingress_cidrs       = ["<ip_cidr_range>", "<ip_cidr_range>"]
}
```
```
# Example showing referencing of a previously TF-created Aviatrix VPC
module azure_vm_module {
    source = "./vendor/modules/mc-vm/azure"

    resource_name_label = "foo-azure"
    region              = aviatrix_vpc.vnet.region
    vpc_id              = aviatrix_vpc.vnet.vpc_id
    public_subnet_id    = aviatrix_vpc.vnet.public_subnets[0].subnet_id
    private_subnet_id   = aviatrix_vpc.vnet.private_subnets[0].subnet_id
    ingress_cidrs       = ["<ip_cidr_range>"]

    # optional
    vm_count                = 2
    egress_cidrs            = ["0.0.0.0/0"]
    owner                   = "foobar-name"
}
```
```
# Example launching VM module into an Azure RG, using an existing keypair
module azure_vm_module {
    source = "./vendor/modules/mc-vm/azure"

    resource_name_label = "foo-azure"
    region              = aviatrix_vpc.vnet.region
    vpc_id              = aviatrix_vpc.vnet.vpc_id
    public_subnet_id    = aviatrix_vpc.vnet.public_subnets[0].subnet_id
    private_subnet_id   = aviatrix_vpc.vnet.private_subnets[0].subnet_id
    ingress_cidrs       = ["<ip_cidr_range>"]

    # optional
    use_existing_keypair    = true
    public_key              = tls_private_key.ssh_key.public_key_openssh # Pass generated public key content
    # public_key            = file("foo-public-key.pub") # Alternatively, read the public key content using file()
}
```
```
# Example launching VM module into an Azure RG, into multiple specified subnets, referencing a previously TF-created Aviatrix VPC
module azure_vm_module {
    source = "./vendor/modules/mc-vm/azure"

    resource_name_label = "foo-azure"
    region              = aviatrix_vpc.vnet.region
    vpc_id              = aviatrix_vpc.vnet.vpc_id
    ingress_cidrs       = ["<ip_cidr_range>"]

    # Required - for multi-subnet launch
    use_custom_subnets  = true
    public_subnet_list  = [aviatrix_vpc.vnet.public_subnets[0].subnet_id, aviatrix_vpc.vnet.public_subnets[1].subnet_id, aviatrix_vpc.vnet.public_subnets[2].subnet_id]
    private_subnet_list = [aviatrix_vpc.vnet.private_subnets[0].subnet_id, aviatrix_vpc.vnet.private_subnets[1].subnet_id]

    # optional
    vm_count                = 3
    egress_cidrs            = ["0.0.0.0/0"]
    owner                   = "foobar-name"
}
```

## Launching VMs into GCP
```
# Launching 1 VM pair into a GCP VCN
module gcp_vm_module {
    source = "./vendor/modules/mc-vm/gcp"

    resource_name_label = "foo-gcp"
    region              = "us-central1"
    region2             = "us-east1"
    vpc_id              = "<VPC-Name>~-~<Project-ID>"
    public_subnet_id    = "<public-subnet-name>"
    private_subnet_id   = "<private-subnet-name>"
    ingress_cidrs       = ["<ip_cidr_range>", "<ip_cidr_range>"]
}
```
```
# Example showing referencing of a previously TF-created Aviatrix VPC
module gcp_vm_module {
    source = "./vendor/modules/mc-vm/gcp"

    resource_name_label = "foo-gcp"
    region              = aviatrix_vpc.gcp_vpc.subnets.0.region
    region2             = aviatrix_vpc.gcp_vpc.subnets.1.region
    vpc_id              = aviatrix_vpc.gcp_vpc.vpc_id
    public_subnet_id    = aviatrix_vpc.gcp_vpc.subnets.0.name
    private_subnet_id   = aviatrix_vpc.gcp_vpc.subnets.1.name
    ingress_cidrs       = ["<ip_cidr_range>", "<ip_cidr_range>"]

    # optional
    vm_count                = 2
    az1                     = "a"
    az2                     = "b"
    egress_cidrs            = ["0.0.0.0/0"]
    owner                   = "foobar-name"
}
```
```
# Example launching VM module into a GCP VPC, using an existing keypair
module gcp_vm_module {
    source = "./vendor/modules/mc-vm/gcp"

    resource_name_label = "foo-gcp"
    region              = aviatrix_vpc.gcp_vpc.subnets.0.region
    region2             = aviatrix_vpc.gcp_vpc.subnets.1.region
    vpc_id              = aviatrix_vpc.gcp_vpc.vpc_id
    public_subnet_id    = aviatrix_vpc.gcp_vpc.subnets.0.name
    private_subnet_id   = aviatrix_vpc.gcp_vpc.subnets.1.name
    ingress_cidrs       = ["<ip_cidr_range>", "<ip_cidr_range>"]

    # optional
    use_existing_keypair    = true
    public_key              = tls_private_key.ssh_key.public_key_openssh # Pass generated public key content
    # public_key            = file("foo-public-key.pub") # Alternatively, read the public key content using file()
}
```
```
# Example launching VM module into a GCP VPC, into multiple specified subnets, referencing a previously TF-created Aviatrix VPC
module gcp_vm_module {
    source = "./vendor/modules/mc-vm/gcp"

    resource_name_label = "foo-gcp"
    vpc_id              = aviatrix_vpc.gcp_vpc.vpc_id
    ingress_cidrs       = ["<ip_cidr_range>", "<ip_cidr_range>"]

    # Required - for multi-subnet launch
    use_custom_subnets          = true
    public_subnet_list          = [aviatrix_vpc.gcp.subnets[0].name, aviatrix_vpc.gcp.subnets[1].name]
    public_subnet_region_list   = [aviatrix_vpc.gcp.subnets[0].region, aviatrix_vpc.gcp.subnets[1].region]
    private_subnet_region_list  = [aviatrix_vpc.gcp.subnets[2].region, aviatrix_vpc.gcp.subnets[3].region]
    private_subnet_list         = [aviatrix_vpc.gcp.subnets[2].name, aviatrix_vpc.gcp.subnets[3].name]

    # optional
    vm_count                = 3
    egress_cidrs            = ["0.0.0.0/0"]
    owner                   = "foobar-name"
}
```

## Launching VMs into OCI
```
# Launching 1 VM pair into an OCI VCN
module oci_vm_module {
    source = "./vendor/modules/mc-vm/oci"

    resource_name_label = "foo-oci"
    region              = "us-ashburn-1"
    vpc_id              = "ocid1.vcn.oc1.iad.<ocid>"
    public_subnet_id    = "ocid1.subnet.oc1.iad.<ocid>"
    private_subnet_id   = "ocid1.subnet.oc1.iad.<ocid>"
    ingress_cidrs       = ["<ip_cidr_range>", "<ip_cidr_range>"]
}
```
```
# Example showing referencing of a previously TF-created Aviatrix VPC
module oci_vm_module {
    source = "./vendor/modules/mc-vm/oci"

    resource_name_label = "foo-oci"
    region              = aviatrix_vpc.vnet.region
    vpc_id              = aviatrix_vpc.vnet.vpc_id
    public_subnet_id    = aviatrix_vpc.vnet.public_subnets[0].subnet_id
    private_subnet_id   = aviatrix_vpc.vnet.private_subnets[0].subnet_id
    ingress_cidrs       = ["<ip_cidr_range>"]

    # optional
    vm_count                = 2
    egress_cidrs            = ["0.0.0.0/0"]
    owner                   = "foobar-name"
}
```
```
# Example launching VM module into an OCI VCN, using an existing keypair
module oci_vm_module {
    source = "./vendor/modules/mc-vm/oci"

    resource_name_label = "foo-oci"
    region              = aviatrix_vpc.vnet.region
    vpc_id              = aviatrix_vpc.vnet.vpc_id
    public_subnet_id    = aviatrix_vpc.vnet.public_subnets[0].subnet_id
    private_subnet_id   = aviatrix_vpc.vnet.private_subnets[0].subnet_id
    ingress_cidrs       = ["<ip_cidr_range>"]

    # optional
    use_existing_keypair    = true
    public_key              = tls_private_key.ssh_key.public_key_openssh # Pass generated public key content
    # public_key            = file("foo-public-key.pub") # Alternatively, read the public key content using file()
}
```
```
# Example launching VM module into an OCI VCN, into multiple specified subnets, referencing a previously TF-created Aviatrix VPC
module oci_vm_module {
    source = "./vendor/modules/mc-vm/oci"

    resource_name_label = "foo-oci"
    region              = aviatrix_vpc.vnet.region
    vpc_id              = aviatrix_vpc.vnet.vpc_id
    ingress_cidrs       = ["<ip_cidr_range>"]

    # Required - for multi-subnet launch
    use_custom_subnets  = true
    public_subnet_list  = [aviatrix_vpc.vnet.public_subnets[0].subnet_id, aviatrix_vpc.vnet.public_subnets[1].subnet_id, aviatrix_vpc.vnet.public_subnets[2].subnet_id]
    private_subnet_list = [aviatrix_vpc.vnet.private_subnets[0].subnet_id, aviatrix_vpc.vnet.private_subnets[1].subnet_id]

    # optional
    vm_count                = 3
    egress_cidrs            = ["0.0.0.0/0"]
    owner                   = "foobar-name"
}
```