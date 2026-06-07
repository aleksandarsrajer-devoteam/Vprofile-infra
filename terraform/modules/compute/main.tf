# ── Base Image (Dynamic) ─────────────────────────────────────────────────────
# Fetches the most recent image baked by Packer in the 'vprofile-base' family.
# This eliminates state drift: every local 'terraform plan' uses the same image
# as the pipeline without needing TF_VAR_image_id to be set manually.
data "google_compute_image" "vprofile_base" {
  project     = var.project_id
  family      = "vprofile-base"
  most_recent = true
}

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


# ── GCS Read Access for Tomcat VMs ───────────────────────────────────────────
# Startup script downloads vprofile-latest.war from the artifacts bucket.
# objectViewer is the minimum permission needed — write access is NOT granted.
resource "google_storage_bucket_iam_member" "tomcat_sa_artifacts_read" {
  bucket = var.artifacts_bucket_name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.tomcat_sa.email}"
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
    # Always uses the latest image from the 'vprofile-base' Packer family.
    # No variable injection needed — data source resolves at plan time.
    source_image = data.google_compute_image.vprofile_base.self_link
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

  # OPPORTUNISTIC: instance template changes only affect instances that are
  # recreated for other reasons (crash, manual delete, autoscaler action).
  # The app deployment pipeline triggers rolling-restarts directly via gcloud,
  # so we do not want Terraform to auto-replace running instances on every apply.
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
