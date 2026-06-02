# Enable the Secret Manager API
resource "google_project_service" "secretmanager_api" {
  project            = var.project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

# Create the secret resource (the "container" — stores no value yet)
resource "google_secret_manager_secret" "db_password" {
  secret_id = "vprofile-db-password"
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager_api]
}

# Store the actual password value as version 1
# Note: google_secret_manager_secret_version marks secret_data as sensitive,
# so the password value is NOT stored in plaintext in the Terraform state file.
resource "google_secret_manager_secret_version" "db_password_v1" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = var.db_password
}
