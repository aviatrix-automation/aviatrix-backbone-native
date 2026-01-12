output "vm" {
  value = {
    public_vm_obj_list       = google_compute_instance.public_instance[*]
    private_vm_obj_list      = google_compute_instance.private_instance[*]
    public_vm_name_list      = google_compute_instance.public_instance[*].name
    private_vm_name_list     = google_compute_instance.private_instance[*].name
    public_vm_id_list        = google_compute_instance.public_instance[*].instance_id
    private_vm_id_list       = google_compute_instance.private_instance[*].instance_id
    public_vm_public_ip_list = google_compute_instance.public_instance[*].network_interface[0].access_config[0].nat_ip
    vm_private_ip_list = concat(
      google_compute_instance.public_instance[*].network_interface[0].network_ip,
      google_compute_instance.private_instance[*].network_interface[0].network_ip
    )
    private_vm_private_ip_list = google_compute_instance.private_instance[*].network_interface[0].network_ip
    private_key_filename       = var.use_existing_keypair ? null : (length(local_file.private_key) > 0 ? local_file.private_key[0].filename : null)
  }
}
