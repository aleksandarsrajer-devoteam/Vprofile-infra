variable "project_id" {
  type        = string
  description = "The GCP project ID where the secret will be created"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "The DB root password to store in Secret Manager. Pass from root via terraform.tfvars "
}
