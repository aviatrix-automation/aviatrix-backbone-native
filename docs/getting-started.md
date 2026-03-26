# Getting Started

This guide walks you through deploying your first Aviatrix transit network.

## Prerequisites

1. **Aviatrix Controller**: A running Aviatrix Controller (version 8.x)
2. **AWS Account**: For SSM Parameter Store (controller credentials) and optional AWS transit
3. **Cloud Credentials**: Access to your target cloud(s) — AWS, Azure, and/or GCP
4. **Terraform**: Version 1.3 or later

## Step 1: Configure Credentials

Store your Aviatrix Controller credentials in AWS SSM Parameter Store:

```bash
# Controller IP
aws ssm put-parameter \
  --name "/aviatrix/controller/ip" \
  --value "your-controller-ip" \
  --type "SecureString"

# Username
aws ssm put-parameter \
  --name "/aviatrix/controller/username" \
  --value "admin" \
  --type "SecureString"

# Password
aws ssm put-parameter \
  --name "/aviatrix/controller/password" \
  --value "your-password" \
  --type "SecureString"
```

All modules retrieve controller credentials from SSM using the `aws_ssm_region` variable. This is the only cross-cloud dependency — your target cloud resources are deployed in their native region.

## Step 2: Choose Your Deployment

### Single Cloud (AWS)

Create a `main.tf` in your working directory:

```hcl
module "aws_transit" {
  source = "git::https://github.com/aviatrix-automation/aviatrix-backbone-native.git//modules/control/aws?ref=v0.8.0"

  aws_ssm_region = "us-east-1"
  region         = "us-east-1"

  transits = {
    "prod-transit" = {
      account         = "aws-prod"
      cidr            = "10.1.0.0/23"
      instance_size   = "c5n.9xlarge"
      local_as_number = 65011
    }
  }
}
```

### Single Cloud (Azure)

```hcl
module "azure_transit" {
  source = "git::https://github.com/aviatrix-automation/aviatrix-backbone-native.git//modules/control/azure?ref=v0.8.0"

  aws_ssm_region  = "us-east-1"
  region          = "East US 2"
  subscription_id = "your-subscription-id"

  transits = {
    "prod-transit" = {
      account         = "azure-prod"
      cidr            = "10.2.0.0/23"
      instance_size   = "Standard_D8_v5"
      local_as_number = 65021
      fw_amount       = 0
      bootstrap_type  = "file_share"
      file_shares     = null
    }
  }
}
```

### Single Cloud (GCP)

```hcl
module "gcp_transit" {
  source = "git::https://github.com/aviatrix-automation/aviatrix-backbone-native.git//modules/control/gcp?ref=v0.8.0"

  aws_ssm_region = "us-east-1"
  project_id     = "my-gcp-project"

  ncc_hubs = [
    { name = "prod", create = true, preset_topology = "MESH" }
  ]

  transits = [
    {
      gw_name             = "gcp-us-transit"
      project_id          = "my-gcp-project"
      region              = "us-east1"
      zone                = "us-east1-b"
      ha_zone             = "us-east1-c"
      name                = "us-transit"
      vpc_cidr            = "10.3.240.0/24"
      lan_cidr            = "10.3.241.0/24"
      gw_size             = "n2-highcpu-8"
      access_account_name = "gcp-prod"
      cloud_router_asn    = 16550
      aviatrix_gw_asn     = 65511
      bgp_lan_subnets     = { "prod" = { cidr = "10.3.0.0/24" } }
    }
  ]
}
```

### Multi-Cloud

Combine multiple modules in the same Terraform root. After deploying transit gateways, add peering:

```hcl
module "peering" {
  source = "git::https://github.com/aviatrix-automation/aviatrix-backbone-native.git//modules/control/peering?ref=v0.8.0"

  aws_ssm_region = "us-east-1"

  depends_on = [module.aws_transit, module.azure_transit, module.gcp_transit]
}
```

See the [examples/](../examples/) directory for complete `.tfvars.example` files with all available options.

## Step 3: Initialize and Apply

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan -var-file=your.tfvars

# Apply the configuration
terraform apply -var-file=your.tfvars
```

## Step 4: Verify Deployment

1. Log into your Aviatrix Controller
2. Navigate to **Multi-Cloud Transit** > **Transit Gateway**
3. Verify your transit gateway is in "UP" state
4. Check **CoPilot** > **Topology** for a visual network map

## Next Steps

- [Add network segmentation](../modules/control/segmentation/README.md) — Domain-based traffic isolation
- [Configure transit peering](../modules/control/peering/README.md) — Cross-cloud full-mesh connectivity
- [Enable distributed firewalling](../modules/control/dcf/README.md) — Policy-based micro-segmentation
- Review [USE_CASES.md](../USE_CASES.md) for supported deployment patterns

## Troubleshooting

### Common Issues

**Controller connection failed**
- Verify SSM parameters are correctly set in `aws_ssm_region`
- Check network connectivity to the controller
- Ensure controller security group allows your IP

**Transit gateway creation failed**
- Verify cloud credentials and Aviatrix access account names
- Check Aviatrix controller audit logs for detailed errors
- Ensure the account has sufficient permissions and quotas

**Provider version mismatch**
- This project requires Aviatrix provider ~> 8.2. Check your `.terraform.lock.hcl`
- Run `terraform init -upgrade` to update providers

### Getting Help

- Check the [Aviatrix documentation](https://docs.aviatrix.com/)
- Review module-specific README files in `modules/control/{cloud}/`
- Open an issue in this repository
