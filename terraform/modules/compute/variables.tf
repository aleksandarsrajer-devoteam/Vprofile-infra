variable "zone" {
  type        = string
  description = "The zone where instances will be launched"
}

variable "region" {
  type        = string
  description = "The region for the regional instance template and MIG"
}

variable "subnet_id" {
  type        = string
  description = "The ID of the private subnet where Tomcat servers will live"
}

variable "project_id" {
  type        = string
  description = "GCP project ID — required for SA creation, IAM bindings, and image data source"
}

variable "db_secret_id" {
  type        = string
  description = "The Secret Manager secret ID (name) for the DB password. The VM fetches the value at runtime — this is NOT the password itself."
}

variable "artifacts_bucket_name" {
  type        = string
  description = "Name of the GCS bucket holding vprofile-latest.war. The tomcat SA is granted objectViewer on this bucket so instances can download the WAR at boot."
}