## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aviatrix"></a> [aviatrix](#requirement\_aviatrix) | 8.1.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aviatrix"></a> [aviatrix](#provider\_aviatrix) | 8.1.1 |
| <a name="provider_aws.ssm"></a> [aws.ssm](#provider\_aws.ssm) | 6.18.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aviatrix_distributed_firewalling_config.enable_distributed_firewalling](https://registry.terraform.io/providers/AviatrixSystems/aviatrix/8.1.1/docs/resources/distributed_firewalling_config) | resource |
| [aviatrix_distributed_firewalling_default_action_rule.distributed_firewalling_default_action_rule](https://registry.terraform.io/providers/AviatrixSystems/aviatrix/8.1.1/docs/resources/distributed_firewalling_default_action_rule) | resource |
| [aviatrix_distributed_firewalling_policy_list.policies](https://registry.terraform.io/providers/AviatrixSystems/aviatrix/8.1.1/docs/resources/distributed_firewalling_policy_list) | resource |
| [aviatrix_smart_group.smarties](https://registry.terraform.io/providers/AviatrixSystems/aviatrix/8.1.1/docs/resources/smart_group) | resource |
| [aviatrix_smart_groups.foo](https://registry.terraform.io/providers/AviatrixSystems/aviatrix/8.1.1/docs/data-sources/smart_groups) | data source |
| [aws_ssm_parameter.aviatrix_ip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.aviatrix_password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.aviatrix_username](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_ssw_region"></a> [aws\_ssw\_region](#input\_aws\_ssw\_region) | n/a | `string` | n/a | yes |
| <a name="input_distributed_firewalling_default_action_rule_action"></a> [distributed\_firewalling\_default\_action\_rule\_action](#input\_distributed\_firewalling\_default\_action\_rule\_action) | n/a | `string` | `"DENY"` | no |
| <a name="input_distributed_firewalling_default_action_rule_logging"></a> [distributed\_firewalling\_default\_action\_rule\_logging](#input\_distributed\_firewalling\_default\_action\_rule\_logging) | n/a | `bool` | `false` | no |
| <a name="input_enable_distributed_firewalling"></a> [enable\_distributed\_firewalling](#input\_enable\_distributed\_firewalling) | n/a | `bool` | `false` | no |
| <a name="input_policies"></a> [policies](#input\_policies) | Map of distributed firewalling policies | <pre>map(object({<br/>    action           = string<br/>    priority         = number<br/>    protocol         = string<br/>    logging          = bool<br/>    watch            = bool<br/>    src_smart_groups = list(string)<br/>    dst_smart_groups = list(string)<br/>    port_ranges      = optional(list(string), [])<br/>  }))</pre> | `{}` | no |
| <a name="input_smarties"></a> [smarties](#input\_smarties) | Map of smart groups to create | <pre>map(object({<br/>    cidr = optional(string)<br/>    tags = optional(map(string))<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_created_smart_groups"></a> [created\_smart\_groups](#output\_created\_smart\_groups) | Map of created smart group names to their UUIDs |
| <a name="output_created_smart_groups_details"></a> [created\_smart\_groups\_details](#output\_created\_smart\_groups\_details) | Full details of created smart groups including selectors |
| <a name="output_all_smart_groups"></a> [all\_smart\_groups](#output\_all\_smart\_groups) | Map of all smart group names to their UUIDs (existing + created) |
| <a name="output_policies_summary"></a> [policies\_summary](#output\_policies\_summary) | Summary of configured distributed firewall policies |
| <a name="output_dcf_status"></a> [dcf\_status](#output\_dcf\_status) | Distributed Cloud Firewall configuration status |
| <a name="output_policy_list_id"></a> [policy\_list\_id](#output\_policy\_list\_id) | ID of the distributed firewalling policy list resource |
| <a name="output_smart_group_uuid_lookup"></a> [smart\_group\_uuid\_lookup](#output\_smart\_group\_uuid\_lookup) | Helper output for looking up smart group UUIDs by name with source indication |
