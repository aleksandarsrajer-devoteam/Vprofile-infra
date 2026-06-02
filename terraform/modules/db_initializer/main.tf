# ── Dedicated Service Account for the DB Initializer ────────────────────────
# This is a one-shot job VM (powers off after seeding the DB).
# It needs its own SA with secret read access — separate from the Tomcat SA.
resource "google_service_account" "db_init_sa" {
  project      = var.project_id
  account_id   = "vprofile-db-init-sa"
  display_name = "VProfile DB Initializer Service Account"
}

# Grant the init SA permission to read the DB password secret
resource "google_secret_manager_secret_iam_member" "db_init_sa_secret_access" {
  secret_id = var.db_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.db_init_sa.email}"
}

resource "google_compute_instance" "db_init_worker" {
  name         = "vprofile-db-initializer-worker"
  machine_type = "e2-micro"
  zone         = var.zone

  # Tags ensure firewall rules from the VPC module apply to this VM
  tags = ["vprofile-app-node"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
    }
  }

  network_interface {
    subnetwork = var.subnet_id
    # No access_config block — 100% private VM, uses Cloud NAT for outbound
  }

  # Attach the dedicated SA so gcloud can authenticate automatically
  service_account {
    email  = google_service_account.db_init_sa.email
    scopes = ["cloud-platform"]
  }

  # The password is NO LONGER passed via templatefile.
  # The init script fetches it from Secret Manager at runtime.
  metadata_startup_script = templatefile("${path.module}/init.sh.tpl", {
    db_private_ip = var.db_private_ip
  })

  depends_on = [google_secret_manager_secret_iam_member.db_init_sa_secret_access]
}