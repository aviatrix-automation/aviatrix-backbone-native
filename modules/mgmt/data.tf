data "aws_ssm_parameter" "aviatrix_password" {
  name            = "/aviatrix/controller/password"
  with_decryption = true
}

data "aws_ssm_parameter" "aviatrix_customer_id" {
  name            = "/aviatrix/controller/customer_id"
  with_decryption = true
}
