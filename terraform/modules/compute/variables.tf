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
  description = "GCP project ID — required for SA creation and IAM bindings"
}

variable "db_secret_id" {
  type        = string
  description = "The Secret Manager secret ID (name) for the DB password. The VM fetches the value at runtime — this is NOT the password itself."
}

variable "image_id" {
  type        = string
  description = "GCE image self_link or family/project path. Defaults to ubuntu for bootstrap. Overridden by the pipeline via TF_VAR_image_id after first Packer build."
  default     = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
}