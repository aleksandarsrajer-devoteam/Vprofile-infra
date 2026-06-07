output "vprofile_app_url" {
  value       = module.load_balancer.lb_public_ip
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

output "workload_identity_provider" {
  value       = module.github_actions_wif.workload_identity_provider
  description = "Full provider resource name — add this as GitHub Secret: WIF_PROVIDER"
}

output "service_account_email" {
  value       = module.github_actions_wif.service_account_email
  description = "SA email — add this as GitHub Secret: GH_ACTIONS_SA"
}
