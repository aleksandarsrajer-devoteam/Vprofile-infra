resource "google_compute_region_instance_template" "tomcat_template" {
  name         = "vprofile-tomcat-template"
  machine_type = "e2-small"
  region       = var.region

  tags = ["vprofile-app-node"]

  disk {
    source_image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
    auto_delete  = true
    boot         = true
    disk_size_gb = 20
  }

  network_interface {
    subnetwork = var.subnet_id
  }

  metadata_startup_script = file("${path.module}/tomcat_init.sh")

  lifecycle {
    create_before_destroy = true
  }
}


resource "google_compute_region_instance_group_manager" "tomcat_mig" {
  name               = "vprofile-tomcat-mig"
  base_instance_name = "vprofile-tomcat-app"
  region             = var.region
  target_size        = 2

  version {
    instance_template = google_compute_region_instance_template.tomcat_template.self_link
  }

  named_port {
    name = "http"
    port = 8080
  }

  lifecycle {
    ignore_changes = [target_size]
  }
}

resource "google_compute_region_autoscaler" "tomcat_autoscaler" {
  name   = "vprofile-tomcat-autoscaler"
  region = var.region
  target = google_compute_region_instance_group_manager.tomcat_mig.self_link

  autoscaling_policy {
    max_replicas    = 4
    min_replicas    = 2
    cooldown_period = 90

    cpu_utilization {
      target = 0.60
    }
  }
}
