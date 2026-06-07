build {
  name    = "vprofile-tomcat"
  sources = ["source.googlecompute.vprofile_tomcat"]

  # ── Step 1: Upload the WAR ────────────────────────────────────────────────
  # The WAR was built by Maven in GithubAction pipeline.
  # Packer copies it from the CI runner to /tmp on the build VM.
  # The Ansible vprofile-app role then picks it up from /tmp.

  # provisioner "file" {
  #   source      = var.war_path
  #   destination = "/tmp/vprofile-v2.war"
  # }
  # ── Step 2: Run Ansible playbook ─────────────────────────────────────────
  # Ansible connects to the build VM (via the same SSH session Packer opened)
  # and runs the tomcat-setup.yml playbook which orchestrates 3 roles:
  #   java role        → installs OpenJDK 17
  #   tomcat role      → installs Tomcat 10, configures systemd service
  #   vprofile-app     → deploys the WAR, sets up /etc/tomcat directory

  provisioner "ansible" {
    playbook_file   = "ansible/playbooks/tomcat-setup.yml"
    user            = "packer"
    extra_arguments = [
      "--extra-vars", "war_src=/tmp/vprofile-v2.war",
      "-v"
    ]
  }
  # ── Step 3: Clean up before snapshotting ─────────────────────────────────
  # Remove anything that should not be in the golden image:
  # - Temporary files from the build process
  # - Logs (would be stale and confusing in production)
  # - The packer user's SSH keys (new keys are injected at GCE instance creation)
  # - machine-id (must be unique per instance; GCE regenerates it at first boot)
  provisioner "shell" {
    inline = [
      "echo 'Cleaning up build artifacts...'",
      "sudo apt-get clean",
      "sudo rm -rf /tmp/* /var/tmp/*",
      "sudo find /var/log -type f -delete",
      "sudo rm -f /home/packer/.ssh/authorized_keys",
      "sudo truncate -s 0 /etc/machine-id",
      "echo 'Cleanup complete.'"
    ]
  }
  # Writes a manifest.json file containing the image self_link.
  # GitHub Actions reads this to get the image ID for the Terraform apply step.
  post-processor "manifest" {
    output     = "packer/manifest.json"
    strip_path = true
  }
}