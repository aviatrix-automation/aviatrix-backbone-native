# Getting Started

This guide walks you through deploying your first Aviatrix transit network.

## Prerequisites

1. **Aviatrix Controller**: A running Aviatrix Controller (version 8.0+)
2. **AWS Account**: For SSM Parameter Store and optional AWS transit
3. **Cloud Credentials**: Access to your target cloud(s)
4. **Terraform**: Version 1.0 or later

## Step 1: Configure Credentials

Store your Aviatrix credentials in AWS SSM Parameter Store:

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

## Step 2: Choose Your Deployment

### Single Cloud (AWS)

```hcl
module "aws_transit" {
  source = "path/to/modules/control/aws"

  region         = "us-west-2"
  aws_ssm_region = "us-west-2"

  transit_name = "prod-transit"
  transit_cidr = "10.1.0.0/23"
}
```

### Multi-Cloud

See [examples/multi-cloud](../examples/multi-cloud/README.md) for a complete multi-cloud deployment.

## Step 3: Initialize and Apply

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

## Step 4: Verify Deployment

1. Log into your Aviatrix Controller
2. Navigate to **Multi-Cloud Transit** > **Transit Gateway**
3. Verify your transit gateway is in "UP" state

## Next Steps

- [Add network segmentation](../modules/control/segmentation/README.md)
- [Configure transit peering](../modules/control/peering/README.md)
- [Enable distributed firewalling](../modules/control/dcf/README.md)

## Troubleshooting

### Common Issues

**Controller connection failed**
- Verify SSM parameters are correctly set
- Check network connectivity to the controller
- Ensure controller security group allows your IP

**Transit gateway creation failed**
- Verify cloud credentials are valid
- Check Aviatrix access account configuration
- Review controller audit logs

### Getting Help

- Check the [Aviatrix documentation](https://docs.aviatrix.com/)
- Review module-specific README files
- Open an issue in this repository
