resource "google_certificate_manager_dns_authorization" "dns_auth" {
  name        = "vprofile-dns-auth"
  domain      = var.domain_name
  description = "DNS authorization of ownership of domain"
}

resource "google_certificate_manager_certificate" "managed_cert" {
  name        = "vprofile-managed-cert"
  description = "GCP managed SSL Certificate"
  scope       = "DEFAULT"

  managed {
    domains = [
      var.domain_name,
      "*.${var.domain_name}"
    ]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.dns_auth.id
    ]
  }
}

resource "google_certificate_manager_certificate_map" "cert_map" {
  name        = "vprofile-cert-map"
  description = "Certificate map for Vprofile"
}

resource "google_certificate_manager_certificate_map_entry" "cert_map_entry" {
  name         = "vprofile-cert-map-entry"
  description  = "Entry in map for domain"
  map          = google_certificate_manager_certificate_map.cert_map.name
  certificates = [google_certificate_manager_certificate.managed_cert.id]
  matcher      = "PRIMARY"
}