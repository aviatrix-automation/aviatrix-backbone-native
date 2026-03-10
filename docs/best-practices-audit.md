# Terraform Best Practices Audit

**Repository:** aviatrix-backbone-native
**Date:** 2026-03-10
**Scope:** All modules under `modules/control/`, `modules/mgmt/`, and `tests/`

---

## Scorecard

| Category | Status | Grade |
|----------|--------|-------|
| Module structure & composition | Well-organized hierarchy | **A** |
| `for_each` over `count` | Excellent — count only for 0/1 conditionals | **A** |
| Secrets management | SSM Parameter Store, no hardcoded secrets in modules | **A** |
| `.gitignore` coverage | Comprehensive (tfstate, tfvars, .terraform, locks) | **A** |
| `depends_on` usage | Explicit only where implicit refs are insufficient | **A** |
| `lifecycle` blocks | Appropriate (ignore_changes for API cache, NCC group drift) | **A** |
| Provisioners | Only in test code, not production modules | **A** |
| Naming conventions | Consistent across clouds | **B+** |
| README documentation | Good at top-level; missing for transit submodules | **B** |
| Output descriptions | Partial — several outputs missing descriptions | **C+** |
| Variable descriptions | 10% missing (7/70) | **C+** |
| Provider version pinning | Inconsistent (exact for Aviatrix, none for AWS/GCP) | **C** |
| Variable validation | Only GCP has good coverage; AWS/Peering have zero | **C** |
| `sensitive` marking | 9 secret-like variables unmarked | **D** |
| `required_version` constraint | Missing entirely | **F** |
| Remote state backend | Not configured (local only) | **F** |

---

## Critical Gaps

### 1. No `required_version` constraint — anywhere

No module declares `terraform { required_version }`. A consumer could run any Terraform version and get cryptic errors.

**Fix:** Add to every module's `provider.tf`:

```hcl
terraform {
  required_version = ">= 1.3"
}
```

**Affected files:**

- `modules/control/aws/modules/transit/provider.tf`
- `modules/control/azure/modules/transit/provider.tf`
- `modules/control/gcp/modules/transit/provider.tf`
- `modules/control/peering/provider.tf`
- `modules/control/segmentation/provider.tf`
- `modules/control/dcf/provider.tf`
- `modules/mgmt/provider.tf`

### 2. Hardcoded password default in Azure module

`modules/control/azure/modules/transit/variables.tf:81` — `admin_password` defaults to `"Avtx1234#"`. This should have no default and be marked `sensitive = true`.

**Fix:**

```hcl
variable "admin_password" {
  type        = string
  description = "Admin password for firewall instances"
  sensitive   = true
  # No default — must be provided by caller
}
```

### 3. Nine secret-like variables missing `sensitive = true`

Pre-shared keys and passwords in AWS, Azure, and GCP transit modules are not marked sensitive. Terraform will display them in plan output and logs.

| Module | Variable | Location |
|--------|----------|----------|
| AWS Transit | `pre_shared_key` | `variables.tf` (inside `external_devices` object) |
| AWS Transit | `backup_pre_shared_key` | `variables.tf` (inside `external_devices` object) |
| Azure Transit | `admin_password` | `variables.tf:81` |
| Azure Transit | `pre_shared_key` | `variables.tf` (inside `external_devices` object) |
| Azure Transit | `backup_pre_shared_key` | `variables.tf` (inside `external_devices` object) |
| GCP Transit | `pre_shared_key` | `variables.tf` (inside `external_devices` object) |
| GCP Transit | `backup_pre_shared_key` | `variables.tf` (inside `external_devices` object) |

> **Note:** Nested attributes inside `object()` types cannot be individually marked sensitive. Consider extracting these as top-level variables or marking the parent variable as sensitive.

### 4. No remote state backend

All state is local. No locking, no team collaboration, no disaster recovery for state files.

**Fix:** Configure an S3+DynamoDB or GCS backend:

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "aviatrix-backbone/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

### 5. Provider versions unpinned for AWS and GCP

Aviatrix is pinned to exact `8.2.0`, but AWS and Google providers have **no version constraint at all**. A `terraform init` could pull a breaking major version.

**Fix:** Use pessimistic constraints:

```hcl
required_providers {
  aws    = { source = "hashicorp/aws",    version = "~> 5.0" }
  google = { source = "hashicorp/google", version = "~> 5.0" }
}
```

---

## Medium Gaps

### 6. Variable validation blocks inconsistent

GCP transit has 18 validation blocks (excellent). AWS transit and Peering have **zero**. Complex `map(object(...))` inputs like `transits`, `tgws`, and `external_devices` are entirely unvalidated.

**Recommendation:** At minimum, add validation for:

- CIDR format (regex match)
- ASN ranges (valid BGP ASN values)
- Gateway name length/characters
- Required nested fields in complex objects

### 7. Variable typo: `aws_ssw_region`

Segmentation and DCF modules use `aws_ssw_region` instead of `aws_ssm_region`. This is inconsistent with the rest of the codebase.

**Affected files:**

- `modules/control/segmentation/variables.tf`
- `modules/control/dcf/variables.tf`

### 8. Transit submodules have no READMEs

The actual implementation lives in `modules/transit/` subfolders (1,200+ LOC each) with zero documentation. A contributor would have to read raw HCL to understand inputs/outputs.

**Missing:**

- `modules/control/aws/modules/transit/README.md`
- `modules/control/azure/modules/transit/README.md`
- `modules/control/gcp/modules/transit/README.md`

### 9. No `prevent_destroy` on critical resources

Controller, FireNet, and transit gateways have no `prevent_destroy = true`. An accidental `terraform destroy` would take everything down.

**Recommendation:** Add to critical resources:

```hcl
lifecycle {
  prevent_destroy = true
}
```

Candidates:

- Aviatrix Controller (mgmt module)
- Aviatrix FireNet resources
- Transit gateway modules
- NCC Hubs (GCP)

### 10. Exact provider pinning instead of pessimistic constraints

Using `version = "8.2.0"` blocks patch updates. Use `~> 8.2` to allow `8.2.x` patches while preventing breaking `8.3+` changes.

**Current:**

```hcl
aviatrix = { version = "8.2.0" }
terracurl = { version = "2.1.0" }
```

**Recommended:**

```hcl
aviatrix = { version = "~> 8.2" }
terracurl = { version = "~> 2.1" }
```

### 11. Hardcoded values in wrapper `main.tf` files

`modules/control/gcp/main.tf` contains hardcoded `project_id = "rtrentin-01"`, `service_account`, SSH keys, ASNs, CIDRs, and zones. These are effectively example/test configs living alongside production module code.

**Fix:** Move wrapper `main.tf` files to a dedicated `examples/` directory structure:

```
examples/
  gcp-transit/
    main.tf
    variables.tf
    terraform.tfvars.example
```

---

## Minor Gaps

| Issue | Detail | Recommendation |
|-------|--------|----------------|
| No `terraform-docs` automation | Only mgmt uses auto-generated docs; rest are hand-written and will drift | Add `terraform-docs` to pre-commit hooks |
| Azure transit outputs empty | `modules/control/azure/modules/transit/output.tf` is 0 bytes | Define outputs for transit gateway names, IDs, IPs |
| Output descriptions missing | AWS `mgmt_subnet_ids`, mgmt `controlplane_data`, several DCF outputs | Add `description` to all output blocks |
| No `moved` blocks | Acceptable now, but refactoring will require manual state surgery | Use `moved` blocks for any future resource renames |
| `versions.tf` not separated | All modules combine `required_providers` + provider config in `provider.tf` | Convention is to split into `versions.tf` (constraints) and `provider.tf` (config) |
| No pre-commit hooks | No `.pre-commit-config.yaml` for automated fmt/validate/docs on commit | Add pre-commit with `terraform fmt`, `terraform validate`, `terraform-docs`, `tflint` |
| 7 variables missing descriptions | Spread across GCP, Segmentation, and DCF modules | Add `description` to all 70 variables |
| Placeholder defaults in mgmt | `controller_admin_email` and `account_email` default to `admin@example.com` | Remove defaults to force explicit configuration |
| `controller_version = "latest"` | Unpinned controller version in mgmt module | Default to a specific version for reproducibility |

---

## What's Done Well

These areas already follow or exceed best practices:

- **Module composition**: Clean hierarchy with wrapper modules delegating to transit submodules
- **`for_each` everywhere**: Maps used for stable resource addresses; `count` only for 0/1 conditionals
- **Secrets externalized**: All credentials sourced from AWS SSM Parameter Store — no secrets in code
- **`.gitignore`**: Comprehensive coverage of state files, tfvars, lock files, and provider caches
- **`depends_on` discipline**: Used sparingly and only where implicit dependencies are insufficient
- **`lifecycle` blocks**: Targeted `ignore_changes` for API-cached data (terracurl) and NCC group drift
- **No provisioners in production**: `remote-exec` confined to test monitoring setup only
- **Naming conventions**: Consistent `{cloud}-{region}-transit` pattern across all cloud modules
- **Complex locals**: Well-structured data transformations with clear intermediate variables
- **Segmentation auto-inference**: Sophisticated longest-match algorithm for domain association from naming conventions

---

## Recommended Priority Actions

| Priority | Action | Effort | Impact |
|----------|--------|--------|--------|
| **P0** | Add `required_version = ">= 1.3"` to all modules | 15 min | Prevents silent breakage on wrong Terraform version |
| **P0** | Mark secret variables as `sensitive = true` | 30 min | Prevents credentials leaking in plan output and logs |
| **P0** | Remove hardcoded `admin_password` default | 5 min | Eliminates known default credential |
| **P1** | Pin AWS and Google provider versions (`~> 5.0`) | 15 min | Prevents surprise breaking changes on `terraform init` |
| **P1** | Switch Aviatrix/terracurl to pessimistic pinning (`~> 8.2`) | 10 min | Allows safe patch updates |
| **P1** | Add `prevent_destroy` to controller and transit resources | 30 min | Safety net against accidental destruction |
| **P2** | Move hardcoded wrapper configs to `examples/` | 1 hr | Separates examples from reusable module code |
| **P2** | Add variable validation blocks to AWS and Peering | 2 hrs | Catches invalid input before plan/apply |
| **P2** | Fix `aws_ssw_region` typo in segmentation/DCF | 10 min | Naming consistency |
| **P3** | Set up `terraform-docs` + pre-commit hooks | 1 hr | Keeps docs in sync automatically |
| **P3** | Add READMEs to transit submodules | 2 hrs | Onboarding for new contributors |
| **P3** | Configure remote state backend | 1 hr | Enables team collaboration and state safety |
| **P3** | Add descriptions to all outputs and variables | 1 hr | Improved discoverability and self-documentation |
