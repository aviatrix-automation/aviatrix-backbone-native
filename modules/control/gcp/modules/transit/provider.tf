# Updated on May 22, 2025 at 04:11 PM EDT
terraform {
  required_providers {
    aviatrix = {
      source  = "AviatrixSystems/aviatrix"
      version = "8.1.1"
    }
    google = {
      source = "hashicorp/google"
    }
  }
}

provider "aws" {
  alias  = "ssm"
  region = var.aws_ssm_region

}

provider "google" {
  project = var.project_id
}

provider "aviatrix" {
  controller_ip           = data.aws_ssm_parameter.aviatrix_ip.value
  username                = data.aws_ssm_parameter.aviatrix_username.value
  password                = data.aws_ssm_parameter.aviatrix_password.value
  skip_version_validation = false
}

