terraform {
  required_providers {
    aviatrix = {
      source  = "AviatrixSystems/aviatrix"
      version = "8.1.1"
    }
    terracurl = {
      source  = "devops-rob/terracurl"
      version = "2.1.0"
    }
  }
}

provider "aws" {
  alias  = "ssm"
  region = var.aws_ssw_region
}

provider "aviatrix" {
  controller_ip           = data.aws_ssm_parameter.aviatrix_ip.value
  username                = data.aws_ssm_parameter.aviatrix_username.value
  password                = data.aws_ssm_parameter.aviatrix_password.value
  skip_version_validation = false
}
