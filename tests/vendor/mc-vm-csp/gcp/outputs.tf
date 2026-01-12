output "vm" {
  description = "VM deployment details"
  value = {
    public_vm_name        = google_compute_instance.public.name
    public_vm_id          = google_compute_instance.public.instance_id
    public_vm_public_ip   = google_compute_instance.public.network_interface[0].access_config[0].nat_ip
    public_vm_private_ip  = google_compute_instance.public.network_interface[0].network_ip
    private_vm_name       = var.deploy_private_vm ? google_compute_instance.private[0].name : null
    private_vm_id         = var.deploy_private_vm ? google_compute_instance.private[0].instance_id : null
    private_vm_private_ip = var.deploy_private_vm ? google_compute_instance.private[0].network_interface[0].network_ip : null
    ssh_firewall_name     = google_compute_firewall.ssh.name
    icmp_firewall_name    = google_compute_firewall.icmp.name
    private_key_file      = var.use_existing_keypair ? null : local_file.private_key[0].filename
    gatus_url             = var.enable_gatus ? "http://${google_compute_instance.public.network_interface[0].access_config[0].nat_ip}:8080" : null
  }
}
