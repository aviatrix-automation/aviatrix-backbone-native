output "vm" {
  value = {
    public_vm_obj_list = concat(
      aws_instance.public_instance[*]
    )
    private_vm_obj_list = concat(
      aws_instance.private_instance[*]
    )
    public_vm_name_list = concat(
      aws_instance.public_instance[*].tags.Name
    )
    private_vm_name_list = concat(
      aws_instance.private_instance[*].tags.Name
    )
    public_vm_id_list = concat(
      aws_instance.public_instance[*].id
    )
    private_vm_id_list = concat(
      aws_instance.private_instance[*].id
    )
    public_vm_public_ip_list = concat(
      aws_instance.public_instance[*].public_ip
    )
    vm_private_ip_list = concat(
      aws_instance.public_instance[*].private_ip,
      aws_instance.private_instance[*].private_ip
    )
    private_vm_private_ip_list = concat(
      aws_instance.private_instance[*].private_ip
    )
    security_group_id    = aws_security_group.sg[0].id
    private_key_filename = var.use_existing_keypair ? null : local_file.private_key[0].filename
    aws_keypair_name     = local.cloud == "aws" ? aws_key_pair.key_pair[0].key_name : null
  }
}
