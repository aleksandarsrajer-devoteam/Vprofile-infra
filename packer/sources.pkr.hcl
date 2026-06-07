locals {
  image_name   = "vprofile-img-${formatdate("YYYYMMDDHHmmss", timestamp())}-${substr(var.git_sha, 0, 8)}"
  image_family = "vprofile-base"
}

source "googlecompute" "vprofile_tomcat" {
  project_id              = var.project_id
  zone                    = var.zone

  # Start from the standard Ubuntu 24.04 LTS base image
  source_image_family     = "ubuntu-2404-lts-amd64"
  source_image_project_id = ["ubuntu-os-cloud"]
  # Use a larger machine type for the build VM — faster apt installs and downloads.
  # This VM only lives for ~10-15 minutes and is then destroyed by Packer.
  # Production VMs use e2-small; build time is not a concern for them.

  machine_type            = "e2-standard-2"
  # Build inside your private VPC — Cloud NAT handles all outbound internet access.
  subnetwork              = var.subnet_id
  omit_external_ip        = true
  use_internal_ip         = true
  use_iap = true
  # Reuse the existing firewall tag so IAP SSH access works for Packer
  tags                    = ["vprofile-app-node"]
  image_name              = local.image_name
  image_family            = local.image_family
  image_description       = "VProfile Base Image (OS + Java + Tomcat) — built from git commit ${var.git_sha}"
  
  image_labels = {
    git_sha    = substr(var.git_sha, 0, 8)
    managed_by = "packer"
    app        = "vprofile"
  }
    
  ssh_username            = "packer"
  # Give the VM 30s to fully initialize networking before Packer tries to SSH
  pause_before_connecting = "30s"
}