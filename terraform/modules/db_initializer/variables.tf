variable "subnet_id" {
  type        = string
  description = "The ID of the private subnet where the initializer VM will run"
}

variable "zone" {
  type        = string
  description = "The zone where the VM instance will be launched"
}

variable "db_private_ip" {
  type        = string
  description = "The private IP address of the Cloud SQL MySQL instance"
}

variable "project_id" {
  type        = string
  description = "GCP project ID — required for SA creation and IAM bindings"
}

variable "db_secret_id" {
  type        = string
  description = "The Secret Manager secret ID (name) for the DB password. The init script fetches the value at runtime — this is NOT the password itself."
}