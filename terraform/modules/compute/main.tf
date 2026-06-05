# ── Dedicated Service Account for Tomcat VMs ────────────────────────────────
# Replaces the default Compute SA, which has broad Editor permissions by default.
resource "google_service_account" "tomcat_sa" {
  project      = var.project_id
  account_id   = "vprofile-tomcat-sa"
  display_name = "VProfile Tomcat App Service Account"
}

# Grant the SA permission to READ (access) the DB password secret at runtime.
# The VM calls: gcloud secrets versions access latest --secret=vprofile-db-password
resource "google_secret_manager_secret_iam_member" "tomcat_sa_secret_access" {
  secret_id = var.db_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.tomcat_sa.email}"
}

resource "google_project_iam_member" "tomcat_observability_permission" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter"
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.tomcat_sa.email}"
}

# ── Instance Template ────────────────────────────────────────────────────────
resource "google_compute_region_instance_template" "tomcat_template" {
  # name_prefix lets Terraform generate a unique name on each apply.
  # Combined with create_before_destroy, this allows zero-downtime template rotation:
  # new template is created first, MIG switches to it, old template is deleted.
  name_prefix  = "vprofile-tomcat-"
  machine_type = "e2-small"
  region       = var.region

  tags = ["vprofile-app-node"]

  disk {
    # Defaults to ubuntu base image for bootstrap (first terraform apply).
    # After the first pipeline run, GitHub Actions sets this to the Packer image.
    source_image = var.image_id
    auto_delete  = true
    boot         = true
    disk_size_gb = 20
  }

  network_interface {
    subnetwork = var.subnet_id
  }

  # Attach the dedicated least-privilege SA.
  # The "cloud-platform" scope is intentionally broad — actual permissions
  # are constrained by the IAM roles granted above (principle of least privilege).
  service_account {
    email  = google_service_account.tomcat_sa.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = file("${path.module}/tomcat_init.sh")

  lifecycle {
    create_before_destroy = true
  }
}


resource "google_compute_region_instance_group_manager" "tomcat_mig" {
  name               = "vprofile-tomcat-mig"
  base_instance_name = "vprofile-tomcat-app"
  region             = var.region
  target_size        = 2

  version {
    instance_template = google_compute_region_instance_template.tomcat_template.self_link
  }

  named_port {
    name = "http"
    port = 8080
  }

  # PROACTIVE: GCP automatically starts a rolling update whenever the MIG's
  # instance template changes. Combined with maxSurge=1/maxUnavailable=0,
  # this gives zero-downtime deployments with no extra gcloud commands needed.
  update_policy {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"
    max_surge_fixed       = 3
    max_unavailable_fixed = 0
    replacement_method    = "SUBSTITUTE"
  }

  lifecycle {
    ignore_changes = [target_size]
  }
}

resource "google_compute_region_autoscaler" "tomcat_autoscaler" {
  name   = "vprofile-tomcat-autoscaler"
  region = var.region
  target = google_compute_region_instance_group_manager.tomcat_mig.self_link

  autoscaling_policy {
    max_replicas    = 4
    min_replicas    = 2
    cooldown_period = 90

    cpu_utilization {
      target = 0.60
    }
  }
}
