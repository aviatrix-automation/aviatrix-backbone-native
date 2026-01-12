<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.98.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_control_plane"></a> [control\_plane](#module\_control\_plane) | terraform-aviatrix-modules/aws-controlplane/aviatrix | 1.0.6 |

## Resources

| Name | Type |
|------|------|
| [aws_ssm_parameter.aviatrix_customer_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.aviatrix_password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_account_name"></a> [access\_account\_name](#input\_access\_account\_name) | Name of the Aviatrix access account | `string` | n/a | yes |
| <a name="input_account_email"></a> [account\_email](#input\_account\_email) | Email for the Aviatrix account | `string` | `"admin@example.com"` | no |
| <a name="input_aws_ssm_region"></a> [aws\_ssm\_region](#input\_aws\_ssm\_region) | AWS region for AWS SSM | `string` | `"us-east-1"` | no |
| <a name="input_controller_admin_email"></a> [controller\_admin\_email](#input\_controller\_admin\_email) | Admin email for the Aviatrix Controller | `string` | `"admin@example.com"` | no |
| <a name="input_controller_instance_type"></a> [controller\_instance\_type](#input\_controller\_instance\_type) | Instance type for the Aviatrix Controller EC2 instance | `string` | `"t3.xlarge"` | no |
| <a name="input_controller_name"></a> [controller\_name](#input\_controller\_name) | Name of the Aviatrix Controller | `string` | `"New-AviatrixController"` | no |
| <a name="input_controller_version"></a> [controller\_version](#input\_controller\_version) | Version of the Aviatrix Controller | `string` | `"latest"` | no |
| <a name="input_controlplane_subnet_cidr"></a> [controlplane\_subnet\_cidr](#input\_controlplane\_subnet\_cidr) | CIDR block for the subnet in the new VPC when use\_existing\_vpc is false | `string` | `null` | no |
| <a name="input_controlplane_vpc_cidr"></a> [controlplane\_vpc\_cidr](#input\_controlplane\_vpc\_cidr) | CIDR block for the new VPC when use\_existing\_vpc is false | `string` | `null` | no |
| <a name="input_copilot_data_volume_size"></a> [copilot\_data\_volume\_size](#input\_copilot\_data\_volume\_size) | Specifies the size of the CoPilot Data Disk Volume | `string` | `"100"` | no |
| <a name="input_copilot_instance_type"></a> [copilot\_instance\_type](#input\_copilot\_instance\_type) | Instance type for the Aviatrix CoPilot EC2 instance | `string` | `"m5n.2xlarge"` | no |
| <a name="input_copilot_name"></a> [copilot\_name](#input\_copilot\_name) | Name of the Aviatrix CoPilot | `string` | `"New-AviatrixCopilot"` | no |
| <a name="input_incoming_ssl_cidrs"></a> [incoming\_ssl\_cidrs](#input\_incoming\_ssl\_cidrs) | List of CIDR blocks allowed to access the Controller's SSL interface | `list(string)` | `null` | no |
| <a name="input_module_config"></a> [module\_config](#input\_module\_config) | Configuration map for module components | `map(bool)` | <pre>{<br/>  "account_onboarding": true,<br/>  "controller_deployment": true,<br/>  "controller_initialization": true,<br/>  "copilot_deployment": true,<br/>  "copilot_initialization": true,<br/>  "iam_roles": false<br/>}</pre> | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region for deploying the Aviatrix control plane | `string` | `"us-east-1"` | no |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | ID of the subnet for deployment (required if use\_existing\_vpc is true) | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Map of tags to apply to resources created by the module | `map(string)` | <pre>{<br/>  "Environment": "Production",<br/>  "Project": "Aviatrix-Control-Plane"<br/>}</pre> | no |
| <a name="input_use_existing_vpc"></a> [use\_existing\_vpc](#input\_use\_existing\_vpc) | Whether to use an existing VPC for deployment | `bool` | `false` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the existing VPC to use (required if use\_existing\_vpc is true) | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_controlplane_data"></a> [controlplane\_data](#output\_controlplane\_data) | n/a |
<!-- END_TF_DOCS -->