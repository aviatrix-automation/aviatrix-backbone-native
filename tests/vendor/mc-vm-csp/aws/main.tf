# AWS VM Module
# Deploys public and optional private Ubuntu VMs for connectivity testing

locals {
  # Canonical's official AMI owner ID
  ami_owner  = "099720109477"
  public_key = var.use_existing_keypair ? var.public_key : tls_private_key.ssh_key[0].public_key_openssh

  # Gatus config without authentication
  gatus_config_no_auth = <<-YAML
endpoints:
  - name: Self
    url: "http://localhost:8080/health"
    interval: 30s
    conditions:
      - "[STATUS] == 200"
YAML

  # Gatus config with basic authentication
  gatus_config_with_auth = <<-YAML
security:
  basic:
    username: "${var.gatus_username}"
    password-bcrypt-base64: "${base64encode(bcrypt(var.gatus_password))}"
endpoints:
  - name: Self
    url: "http://localhost:8080/health"
    interval: 30s
    conditions:
      - "[STATUS] == 200"
YAML

  # Select config based on whether password is set
  default_gatus_config = var.gatus_password != "" ? local.gatus_config_with_auth : local.gatus_config_no_auth
  gatus_config_content = var.gatus_config != "" ? var.gatus_config : local.default_gatus_config

  # Gatus installation script (Docker-based)
  gatus_install_script = <<-EOF
#!/bin/bash
set -e
# Install Docker
apt-get update
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
# Write Gatus config
mkdir -p /etc/gatus
cat > /etc/gatus/config.yaml << 'GATUS_CONFIG'
${local.gatus_config_content}
GATUS_CONFIG
# Run Gatus container with config
docker run -d -p 8080:8080 --name gatus --restart unless-stopped \
  -v /etc/gatus/config.yaml:/config/config.yaml \
  ghcr.io/twin/gatus:stable
EOF
}

# Lookup Ubuntu 20.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = [local.ami_owner]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security group for SSH and ICMP access
resource "aws_security_group" "vm" {
  name        = "${var.resource_name_label}-sg"
  description = "Allow SSH and ICMP"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ingress_cidrs
  }

  ingress {
    description = "ICMP"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = var.ingress_cidrs
  }

  dynamic "ingress" {
    for_each = var.enable_gatus ? [1] : []
    content {
      description = "Gatus HTTP"
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = var.ingress_cidrs
    }
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({ Name = "${var.resource_name_label}-sg" }, var.tags)
}

# SSH key pair
resource "random_id" "key_id" {
  byte_length = 4
}

resource "aws_key_pair" "vm" {
  key_name   = "${var.resource_name_label}-key-${random_id.key_id.dec}"
  public_key = local.public_key
  tags       = merge({ Name = "${var.resource_name_label}-key" }, var.tags)
}

# Public VM (has public IP)
resource "aws_instance" "public" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_size
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.vm.id]
  key_name                    = aws_key_pair.vm.key_name
  associate_public_ip_address = true

  user_data = var.enable_gatus ? base64encode(local.gatus_install_script) : null

  tags = merge({ Name = "${var.resource_name_label}-public-vm" }, var.tags)
}

# Private VM (no public IP)
resource "aws_instance" "private" {
  count                       = var.deploy_private_vm ? 1 : 0
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_size
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [aws_security_group.vm.id]
  key_name                    = aws_key_pair.vm.key_name
  associate_public_ip_address = false

  tags = merge({ Name = "${var.resource_name_label}-private-vm" }, var.tags)
}
