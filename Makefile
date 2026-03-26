.PHONY: lint lint-python lint-terraform lint-security lint-checkov lint-tfsec lint-trivy fmt install install-security

UV_CMD = uv tool run ruff

lint: lint-python lint-terraform

lint-python:
	@echo "Running code linter using ruff ..."
	@$(UV_CMD) check . || { echo "Linting failed!"; exit 1; }
	@echo "Code linted!"

lint-terraform:
	@echo "Running terraform linter using tflint ..."
	@tflint --chdir modules/ --recursive --minimum-failure-severity=error
	@echo "Terraform linted!"

lint-security: lint-checkov lint-tfsec lint-trivy

lint-checkov:
	@echo "Running Checkov security scan ..."
	@checkov --config-file .checkov.yaml || true
	@echo "Checkov scan complete!"

lint-tfsec:
	@echo "Running tfsec security scan ..."
	@tfsec modules/ --soft-fail \
		--exclude aws-ec2-no-public-egress-sgr,aws-ec2-enforce-http-token-imds,aws-ec2-require-vpc-flow-logs-for-all-vpcs,aws-ec2-add-description-to-security-group-rule,aws-ec2-volume-encryption-customer-key
	@echo "tfsec scan complete!"

lint-trivy:
	@echo "Running Trivy misconfiguration scan ..."
	@trivy fs --scanners misconfig --ignorefile .trivyignore --skip-version-check modules/
	@echo "Trivy scan complete!"

fmt:
	@echo "Formatting code using ruff ..."
	@$(UV_CMD) format . || { echo "Formatting failed!"; exit 1; }
	@echo "Code formatted!"

fmt-terraform:
	@echo "Formatting terraform code ..."
	@terraform fmt -recursive modules/
	@echo "Terraform formatted!"

install:
	@echo "Installing uv..."
	@curl --retry 3 --retry-delay 5 -LsSf https://astral.sh/uv/install.sh | sh || { echo "Installation failed!"; exit 1; }
	@echo "uv installed!"
	@echo "Installing tflint..."
	@curl --retry 3 --retry-delay 5 -LsSf https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash || { echo "Installation failed!"; exit 1; }
	@echo "tflint installed!"

install-security:
	@echo "Installing checkov..."
	@pip install checkov || { echo "Installation failed!"; exit 1; }
	@echo "checkov installed!"
	@echo "Installing tfsec..."
	@brew install tfsec || { echo "Installation failed!"; exit 1; }
	@echo "tfsec installed!"
	@echo "Installing trivy..."
	@brew install trivy || { echo "Installation failed!"; exit 1; }
	@echo "trivy installed!"
