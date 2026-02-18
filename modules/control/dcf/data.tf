data "aws_ssm_parameter" "aviatrix_ip" {
  name            = "/aviatrix/controller/ip"
  with_decryption = true
  provider        = aws.ssm
}

data "aws_ssm_parameter" "aviatrix_username" {
  name            = "/aviatrix/controller/username"
  with_decryption = true
  provider        = aws.ssm
}

data "aws_ssm_parameter" "aviatrix_password" {
  name            = "/aviatrix/controller/password"
  with_decryption = true
  provider        = aws.ssm
}

data "aviatrix_smart_groups" "foo" {}

data "http" "controller_login" {
  count    = local.needs_s2c_lookup ? 1 : 0
  url      = "https://${data.aws_ssm_parameter.aviatrix_ip.value}/v2/api"
  insecure = true
  method   = "POST"
  request_headers = {
    "Content-Type" = "application/json"
  }
  request_body = jsonencode({
    action   = "login"
    username = data.aws_ssm_parameter.aviatrix_username.value
    password = data.aws_ssm_parameter.aviatrix_password.value
  })
  retry {
    attempts     = 5
    min_delay_ms = 1000
  }
  lifecycle {
    postcondition {
      condition     = jsondecode(self.response_body)["return"]
      error_message = "Failed to login to the controller: ${jsondecode(self.response_body)["reason"]}"
    }
  }
}