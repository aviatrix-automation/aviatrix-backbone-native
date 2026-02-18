# Distributed Cloud Firewall (DCF) Module

Manages Aviatrix Distributed Cloud Firewall configuration, smart groups, and firewall policies.

## Features

- Enable/disable DCF globally with a configurable default action (`PERMIT` or `DENY`)
- Create smart groups matched by **CIDR**, **VM tags**, **explicit S2C connection name**, or **segmentation domain name**
- When `s2c_domain` is used, the module automatically fetches all Site2Cloud connections from the controller and resolves the matching connections using the same `external-{domain}` naming convention as the segmentation module — creating one selector per matched connection (OR logic)
- Reference both newly created and pre-existing smart groups in firewall policies
- Per-policy control of protocol, port ranges, logging, and watch mode

## Smart Group Selector Types

| Field | Selector Type | Example |
|-------|--------------|---------|
| `cidr` | Match by CIDR block | `cidr = "10.1.0.0/24"` |
| `tags` | Match VMs by tag map | `tags = { Env = "prod" }` |
| `s2c` | Match one explicit S2C connection | `s2c = "external-prod-chicago"` |
| `s2c_domain` | Auto-resolve all S2C connections for a domain | `s2c_domain = "prod"` |

`s2c_domain` follows the same naming convention as the segmentation module: it matches any connection whose name starts with `external-` and contains the domain name after that prefix (case-insensitive substring match).

## Usage

```hcl
module "dcf" {
  source = "./modules/control/dcf"

  aws_ssm_region                = "us-east-1"
  enable_distributed_firewalling = true

  distributed_firewalling_default_action_rule_action  = "DENY"
  distributed_firewalling_default_action_rule_logging = true

  smarties = {
    "prod-remote-sites" = {
      s2c_domain = "prod"             # auto-resolves external-prod-* connections
    }
    "specific-branch" = {
      s2c = "external-prod-chicago"   # explicit connection name
    }
    "web-tier" = {
      cidr = "10.1.0.0/24"
    }
    "prod-vms" = {
      tags = { Environment = "Production" }
    }
  }

  policies = {
    "allow-web-to-prod-remotes" = {
      action           = "PERMIT"
      priority         = 100
      protocol         = "tcp"
      logging          = true
      watch            = false
      src_smart_groups = ["web-tier"]
      dst_smart_groups = ["prod-remote-sites"]
      port_ranges      = ["443", "8443"]
    }
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aviatrix"></a> [aviatrix](#requirement\_aviatrix) | 8.1.1 |
| <a name="requirement_terracurl"></a> [terracurl](#requirement\_terracurl) | 2.1.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aviatrix"></a> [aviatrix](#provider\_aviatrix) | 8.1.1 |
| <a name="provider_aws.ssm"></a> [aws.ssm](#provider\_aws.ssm) | >= 5.0 |
| <a name="provider_http"></a> [http](#provider\_http) | >= 3.0 |
| <a name="provider_terracurl"></a> [terracurl](#provider\_terracurl) | 2.1.0 |

> `http` and `terracurl` providers are only used when at least one smartie sets `s2c_domain`.

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aviatrix_distributed_firewalling_config.enable_distributed_firewalling](https://registry.terraform.io/providers/AviatrixSystems/aviatrix/8.1.1/docs/resources/distributed_firewalling_config) | resource |
| [aviatrix_distributed_firewalling_default_action_rule.distributed_firewalling_default_action_rule](https://registry.terraform.io/providers/AviatrixSystems/aviatrix/8.1.1/docs/resources/distributed_firewalling_default_action_rule) | resource |
| [aviatrix_distributed_firewalling_policy_list.policies](https://registry.terraform.io/providers/AviatrixSystems/aviatrix/8.1.1/docs/resources/distributed_firewalling_policy_list) | resource |
| [aviatrix_smart_group.smarties](https://registry.terraform.io/providers/AviatrixSystems/aviatrix/8.1.1/docs/resources/smart_group) | resource |
| [terracurl_request.s2c_connections](https://registry.terraform.io/providers/devops-rob/terracurl/latest/docs/resources/request) | resource |
| [aviatrix_smart_groups.foo](https://registry.terraform.io/providers/AviatrixSystems/aviatrix/8.1.1/docs/data-sources/smart_groups) | data source |
| [aws_ssm_parameter.aviatrix_ip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.aviatrix_password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.aviatrix_username](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [http.controller_login](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

> `terracurl_request.s2c_connections` and `http.controller_login` are created only when `s2c_domain` is used in any smartie (`count = 0` otherwise).

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_ssw_region"></a> [aws\_ssw\_region](#input\_aws\_ssw\_region) | AWS region for SSM parameter retrieval | `string` | n/a | yes |
| <a name="input_enable_distributed_firewalling"></a> [enable\_distributed\_firewalling](#input\_enable\_distributed\_firewalling) | Enable or disable Distributed Cloud Firewall globally | `bool` | `false` | no |
| <a name="input_distributed_firewalling_default_action_rule_action"></a> [distributed\_firewalling\_default\_action\_rule\_action](#input\_distributed\_firewalling\_default\_action\_rule\_action) | Default action for traffic that does not match any policy. `PERMIT` or `DENY` | `string` | `"DENY"` | no |
| <a name="input_distributed_firewalling_default_action_rule_logging"></a> [distributed\_firewalling\_default\_action\_rule\_logging](#input\_distributed\_firewalling\_default\_action\_rule\_logging) | Enable logging for the default action rule | `bool` | `false` | no |
| <a name="input_smarties"></a> [smarties](#input\_smarties) | Map of smart groups to create. Each entry supports one selector type: `cidr`, `tags`, `s2c`, or `s2c_domain` | <pre>map(object({<br/>    cidr       = optional(string)<br/>    tags       = optional(map(string))<br/>    s2c        = optional(string)<br/>    s2c_domain = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_policies"></a> [policies](#input\_policies) | Map of distributed firewalling policies | <pre>map(object({<br/>    action           = string<br/>    priority         = number<br/>    protocol         = string<br/>    logging          = bool<br/>    watch            = bool<br/>    src_smart_groups = list(string)<br/>    dst_smart_groups = list(string)<br/>    port_ranges      = optional(list(string), [])<br/>  }))</pre> | `{}` | no |
| <a name="input_destroy_url"></a> [destroy\_url](#input\_destroy\_url) | Dummy URL used by terracurl during destroy operations | `string` | `"https://checkip.amazonaws.com"` | no |

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
