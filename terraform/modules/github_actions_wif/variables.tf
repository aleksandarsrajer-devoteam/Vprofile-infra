variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCS Region"
}

variable "app_repo" {
  type        = string
  description = "GitHub repo allowed to impersonate the SA — format: 'owner/repo-name'"
  default     = "aleksandarsrajer-devoteam/Vprofile-app"
}

variable "infra_repo" {
  type        = string
  description = "GitHub infra repo also allowed to impersonate the SA — format: 'owner/repo-name'"
  default     = "aleksandarsrajer-devoteam/Vprofile-infra"
}


variable "tfstate_bucket_name" {
  type        = string
  description = "Name of the GCS bucket used to store Terraform state"
  default     = "vprofile-tfstate"
}
