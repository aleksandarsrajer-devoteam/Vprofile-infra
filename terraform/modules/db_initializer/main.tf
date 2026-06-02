resource "google_compute_instance" "db_init_worker" {
  name         = "vprofile-db-initializer-worker"
  machine_type = "e2-micro"
  zone         = var.zone

  # Tags ensure firewall rules from Phase 1 are applied to this VM
  tags = ["vprofile-app-node"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
    }
  }

  network_interface {
    subnetwork = var.subnet_id
    # NO public_ip block here! The VM is 100% private.
  }

  metadata_startup_script = templatefile("${path.module}/init.sh.tpl", {
    db_private_ip = var.db_private_ip
    db_password   = var.db_password
  })
}