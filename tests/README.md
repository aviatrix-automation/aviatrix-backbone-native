# Terraform Tests

Infrastructure tests using Aviatrix mc-modules.

## Prerequisites

- Terraform >= 1.3.0
- Aviatrix controller access
- Cloud provider credentials (AWS/GCP/Azure)

## Credentials Setup

Create `avx_cred.tfvars` in the test directory (e.g., `tests/test_aws/avx_cred.tfvars`):

```hcl
aws_region                   = "us-west-2"
aws_access_key               = "AKIA..."
aws_secret_key               = "..."
aviatrix_controller_ip       = "x.x.x.x"
aviatrix_controller_username = "admin"
aviatrix_controller_password = "..."
aviatrix_aws_access_account  = "aws-account-name"
```

## Running Tests

```bash
# Run AWS tests (will deploy and destroy infrastructure)
uv run pytest tests/test_aws/ -v

# Keep infrastructure after test (for debugging)
AVX_NODESTROY=1 uv run pytest tests/test_aws/ -v

# Use custom credentials file
AVX_TFVARS=/path/to/creds.tfvars uv run pytest tests/test_aws/ -v
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `AVX_TFVARS` | `./avx_cred.tfvars` | Path to credentials file |
| `AVX_NODESTROY` | unset | Skip terraform destroy if set |

## Test Structure

```
tests/
├── conftest.py      # Shared terraform fixtures
├── test_aws/        # AWS transit tests
├── test_gcp/        # GCP tests (planned)
└── test_azure/      # Azure tests (planned)
```
