output "instance_group" {
  value       = google_compute_region_instance_group_manager.tomcat_mig.instance_group
  description = "The link to the instance group manager for the Load Balancer"
}