output "vpc_id" {
  value       = google_compute_network.main_vpc.id
  description = "The ID of the created VPC network"
}

output "subnet_id" {
  value       = google_compute_subnetwork.private_subnet.id
  description = "The ID of the private subnet where application nodes will reside"
}