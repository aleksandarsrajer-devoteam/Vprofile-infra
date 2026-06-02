resource "google_dns_managed_zone" "private_zone" {
  name        = "vprofile-private-zone"
  dns_name    = "vprofile.internal."
  description = "Private internal DNS zone for VProfile"
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = var.vpc_id
    }
  }
}

resource "google_dns_record_set" "db_record" {
  name         = "vprodb.${google_dns_managed_zone.private_zone.dns_name}"
  managed_zone = google_dns_managed_zone.private_zone.name
  type         = "A"
  ttl          = 300
  rrdatas      = [var.db_private_ip]
}

resource "google_dns_record_set" "memcached_record" {
  name         = "vpromc.${google_dns_managed_zone.private_zone.dns_name}"
  managed_zone = google_dns_managed_zone.private_zone.name
  type         = "A"
  ttl          = 300
  rrdatas      = [var.memcached_host]
}