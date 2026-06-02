output "lb_public_ip" {
  value       = google_compute_global_address.global_ip.address
  description = "The public IP address of the Global Load Balancer"
}