output "vm" {
  description = "VM deployment details"
  value = {
    public_vm_name        = aws_instance.public.tags.Name
    public_vm_id          = aws_instance.public.id
    public_vm_public_ip   = aws_instance.public.public_ip
    public_vm_private_ip  = aws_instance.public.private_ip
    private_vm_name       = var.deploy_private_vm ? aws_instance.private[0].tags.Name : null
    private_vm_id         = var.deploy_private_vm ? aws_instance.private[0].id : null
    private_vm_private_ip = var.deploy_private_vm ? aws_instance.private[0].private_ip : null
    security_group_id     = aws_security_group.vm.id
    key_name              = aws_key_pair.vm.key_name
    private_key_file      = var.use_existing_keypair ? null : local_file.private_key[0].filename
    gatus_url             = var.enable_gatus ? "http://${aws_instance.public.public_ip}:8080" : null
  }
}
