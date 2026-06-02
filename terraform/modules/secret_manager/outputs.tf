output "secret_id" {
  value       = google_secret_manager_secret.db_password.secret_id
  description = "The Secret Manager secret ID (the name, NOT the password value)"
}

output "secret_resource_name" {
  value       = google_secret_manager_secret.db_password.name
  description = "Full resource name of the secret, used for IAM bindings"
}
