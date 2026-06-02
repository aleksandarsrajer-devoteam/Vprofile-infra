output "vprofile_app_url" {
  value       = "${module.load_balancer.lb_public_ip}"
  description = "The HTTP URL for the Load Balancer!"
}

output "godaddy_cname_name" {
  value       = module.certificates.godaddy_cname_name
  description = "CNAME key that goes to GoDaddy"
}

output "godaddy_cname_value" {
  value       = module.certificates.godaddy_cname_value
  description = "CNAME value that goes to GoDaddy"
}

