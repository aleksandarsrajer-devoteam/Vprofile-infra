# ── IAM Roles ────────────────────────────────────────────────────────────────
# Covers everything Terraform apply needs across all modules:
# compute, networking, Cloud SQL, Secret Manager, DNS, certificates.
locals {
  github_sa_project_roles = [
    "roles/compute.admin",                   # Instance templates, MIGs, networks, LB
    "roles/iam.serviceAccountAdmin",         # Create/manage SAs (tomcat-sa, db-init-sa)
    "roles/iam.serviceAccountUser",          # Attach SAs to instances
    "roles/secretmanager.admin",             # Manage secrets
    "roles/cloudsql.admin",                  # Manage Cloud SQL instances
    "roles/dns.admin",                       # Manage Cloud DNS zones and records
    "roles/certificatemanager.editor",       # Manage Certificate Manager certs
    "roles/resourcemanager.projectIamAdmin", # Set IAM policies on resources
    "roles/iap.tunnelResourceAccessor"
  ]
}


# ── Workload Identity Pool ───────────────────────────────────────────────────
# The trust anchor. GCP uses this pool to accept identity tokens from GitHub.
resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Allows GitHub Actions workflows to authenticate to GCP without SA key files"
}

# ── OIDC Provider ────────────────────────────────────────────────────────────
# Trusts tokens issued by GitHub's OIDC endpoint.
# The attribute_condition locks trust to ONLY our two specific repos —
# no other GitHub repo can use this pool even if it knows the provider name.
resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub OIDC Provider"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.actor"      = "assertion.actor"
    "attribute.ref"        = "assertion.ref"
  }

  # Only tokens from these two repos are accepted
  attribute_condition = "assertion.repository in ['${var.app_repo}', '${var.infra_repo}']"
}

# ── Service Account ──────────────────────────────────────────────────────────
# This SA is impersonated by GitHub Actions workflows.
# No key file is ever created — credentials are short-lived tokens via WIF.
resource "google_service_account" "github_actions_sa" {
  project      = var.project_id
  account_id   = "vprofile-github-actions-sa"
  display_name = "VProfile GitHub Actions SA"
  description  = "Impersonated by GitHub Actions via WIF "
}

resource "google_service_account_iam_member" "wif_bindings" {
  for_each           = toset([var.app_repo, var.infra_repo])
  service_account_id = google_service_account.github_actions_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${each.value}"
}


resource "google_project_iam_member" "github_sa_roles" {
  for_each = toset(local.github_sa_project_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.github_actions_sa.email}"

}


resource "google_storage_bucket" "build_artifacts" {
  name          = "vprofile-build-artifacts"
  location      = var.region
  project       = var.project_id
  force_destroy = true

  uniform_bucket_level_access = true

  lifecycle_rule {
    condition { age = 30 }
    action { type = "Delete" }
  }
}

# ── GCS Access ───────────────────────────────────────────────────────────────
# Build artifacts bucket — app pipeline uploads, infra pipeline downloads
resource "google_storage_bucket_iam_member" "bucket_access" {
  for_each = toset([google_storage_bucket.build_artifacts.name, var.tfstate_bucket_name])
  bucket   = each.value
  role     = "roles/storage.objectAdmin"
  member   = "serviceAccount:${google_service_account.github_actions_sa.email}"
}

