output "vm" {
  value = {
    public_vm_obj_list = concat(
      azurerm_linux_virtual_machine.public_vm[*]
    )
    private_vm_obj_list = concat(
      azurerm_linux_virtual_machine.private_vm[*]
    )
    public_vm_name_list = concat(
      azurerm_linux_virtual_machine.public_vm[*].name
    )
    private_vm_name_list = concat(
      azurerm_linux_virtual_machine.private_vm[*].name
    )
    public_vm_id_list = concat(
      azurerm_linux_virtual_machine.public_vm[*].id
    )
    private_vm_id_list = concat(
      azurerm_linux_virtual_machine.private_vm[*].id
    )
    public_vm_public_ip_list = concat(
      azurerm_public_ip.public_ip[*].ip_address
    )
    vm_private_ip_list = concat(
      azurerm_linux_virtual_machine.public_vm[*].private_ip_address,
      azurerm_linux_virtual_machine.private_vm[*].private_ip_address
    )
    private_vm_private_ip_list = concat(
      azurerm_linux_virtual_machine.private_vm[*].private_ip_address
    )
    private_key_filename = var.use_existing_keypair ? null : local_file.private_key[0].filename
  }
}
