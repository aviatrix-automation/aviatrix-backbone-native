# Key pair is used for all ubuntu instances
# Public-Private key generation
resource "tls_private_key" "ssh_key" {
  count     = var.use_existing_keypair ? 0 : 1
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  count           = var.use_existing_keypair ? 0 : 1
  filename        = "${var.resource_name_label}-priv-key.pem"
  content         = tls_private_key.ssh_key[0].private_key_pem
  file_permission = "0600"
}