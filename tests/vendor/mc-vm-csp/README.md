# mc-vm-csp

Multi-cloud VM module for deploying test VMs.

## Gatus Health Monitoring

Optional [Gatus](https://github.com/TwiN/gatus) health monitoring can be installed on public VMs. When enabled, Gatus runs as a Docker container and exposes a dashboard on port 8080.

### Enabling Gatus

```hcl
module "test_vm" {
  source = "../../vendor/mc-vm-csp/aws"
  # ... other vars ...

  install_gatus  = true
  gatus_username = "admin"
  gatus_password = "secret123"
  gatus_config   = <<-YAML
endpoints:
  - name: Target VM
    url: "icmp://10.0.0.5"
    interval: 30s
    conditions:
      - "[CONNECTED] == true"
YAML
}

output "dashboard" {
  value = module.test_vm.gatus_url
}
```

### Gatus Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| install_gatus | Install Gatus health monitoring on public VM | bool | false |
| gatus_config | Custom Gatus YAML configuration | string | "" |
| gatus_username | Username for basic authentication | string | "admin" |
| gatus_password | Password for basic authentication (sensitive) | string | "" |

### Gatus Outputs

| Name | Description |
|------|-------------|
| gatus_url | Gatus dashboard URL (http://\<public_ip\>:8080) |

## AWS Usage

```hcl
module "test_vm" {
  source = "../../vendor/mc-vm-csp/aws"

  resource_name_label = "my-test"
  region              = "us-west-2"
  vpc_id              = module.spoke.vpc.vpc_id
  public_subnet_id    = module.spoke.vpc.public_subnets[0].subnet_id
  private_subnet_id   = module.spoke.vpc.private_subnets[1].subnet_id
  ingress_cidrs       = ["0.0.0.0/0"]
  tags                = { Environment = "test" }
}
```

### AWS Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| resource_name_label | Label to prepend to resource names | string | required |
| region | AWS region | string | required |
| vpc_id | VPC ID | string | required |
| public_subnet_id | Public subnet ID | string | required |
| private_subnet_id | Private subnet ID | string | "" |
| ingress_cidrs | CIDRs for SSH/ICMP | list(string) | ["0.0.0.0/0"] |
| instance_size | EC2 instance type | string | "t3.small" |
| deploy_private_vm | Deploy private VM | bool | true |
| use_existing_keypair | Use existing SSH key | bool | false |
| public_key | Public key (if existing) | string | "" |
| tags | Resource tags | map(string) | {} |

### AWS Outputs

| Name | Description |
|------|-------------|
| vm.public_vm_name | Public VM name |
| vm.public_vm_id | Public VM instance ID |
| vm.public_vm_public_ip | Public VM public IP |
| vm.public_vm_private_ip | Public VM private IP |
| vm.private_vm_name | Private VM name |
| vm.private_vm_id | Private VM instance ID |
| vm.private_vm_private_ip | Private VM private IP |
| vm.security_group_id | Security group ID |
| vm.key_name | SSH key pair name |
| vm.private_key_file | Path to generated private key |
| gatus_url | Gatus dashboard URL (when enabled) |

## GCP Usage

```hcl
module "test_vm" {
  source = "../../vendor/mc-vm-csp/gcp"

  resource_name_label = "my-test"
  zone                = "us-west1-a"
  vpc_id              = module.spoke.vpc.vpc_id
  public_subnet_name  = module.spoke.vpc.subnets[0].name
  private_subnet_name = module.spoke.vpc.subnets[1].name
  ingress_cidrs       = ["0.0.0.0/0"]
  labels              = { environment = "test" }
}
```

### GCP Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| resource_name_label | Label to prepend to resource names | string | required |
| zone | GCP zone | string | required |
| vpc_id | VPC ID (supports mc-spoke format) | string | required |
| public_subnet_name | Subnet name for public VM | string | required |
| private_subnet_name | Subnet name for private VM | string | "" |
| ingress_cidrs | CIDRs for SSH/ICMP | list(string) | ["0.0.0.0/0"] |
| machine_type | GCP machine type | string | "e2-small" |
| deploy_private_vm | Deploy private VM | bool | true |
| use_existing_keypair | Use existing SSH key | bool | false |
| public_key | Public key (if existing) | string | "" |
| labels | Resource labels | map(string) | {} |

### GCP Outputs

| Name | Description |
|------|-------------|
| vm.public_vm_name | Public VM name |
| vm.public_vm_id | Public VM instance ID |
| vm.public_vm_public_ip | Public VM external IP |
| vm.public_vm_private_ip | Public VM internal IP |
| vm.private_vm_name | Private VM name |
| vm.private_vm_id | Private VM instance ID |
| vm.private_vm_private_ip | Private VM internal IP |
| vm.ssh_firewall_name | SSH firewall rule name |
| vm.icmp_firewall_name | ICMP firewall rule name |
| vm.private_key_file | Path to generated private key |
| gatus_url | Gatus dashboard URL (when enabled) |
