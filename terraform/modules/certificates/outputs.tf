output "certificate_map_id" {
  value       = google_certificate_manager_certificate_map.cert_map.id
  description = "ID of certificate map we give the LB"
}

output "godaddy_cname_name" {
  value       = google_certificate_manager_dns_authorization.dns_auth.dns_resource_record[0].name
  description = "Copy this to GoDaddy in NAME"
}

output "godaddy_cname_value" {
  value       = google_certificate_manager_dns_authorization.dns_auth.dns_resource_record[0].data
  description = "Copy this in GoDaddy in VALUE"
}