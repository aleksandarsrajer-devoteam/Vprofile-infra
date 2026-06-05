variable "project_id" {
  type        = string
  description = "GCP project ID where the image will be created"
}

variable "zone" {
  type        = string
  description = "GCP zone for the temporary Packer build VM"
  default     = "europe-west3-a"
}

variable "subnet_id" {
  type        = string
  description = "Full self_link of the subnet for the Packer build VM (private subnet)"
}

variable "git_sha" {
  type        = string
  description = "Git commit SHA — embedded in image name and labels for traceability"
  default     = "manual"
}

variable "war_path" {
  type        = string
  description = "Local path to the WAR file on the GitHub Actions runner (downloaded from GCS before Packer runs)"
}
