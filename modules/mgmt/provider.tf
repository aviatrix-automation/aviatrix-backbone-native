provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "ssm"
  region = var.aws_ssm_region
}