resource "google_compute_health_check" "http_health_check" {
  name               = "vprofile-http-health-check"
  check_interval_sec = 5
  timeout_sec        = 5

  http_health_check {
    port         = 8080
    request_path = "/" # Checking the root page of app
  }
}

resource "google_compute_global_address" "global_ip" {
  name         = "vprofile-lb-static-ip"
  address_type = "EXTERNAL"
}

resource "google_compute_backend_service" "backend_service" {
  name                  = "vprofile-backend-service"
  protocol              = "HTTP"
  port_name             = "http" # Ovo mora da se poklapa sa named_port iz compute modula
  load_balancing_scheme = "EXTERNAL_MANAGED"
  health_checks         = [google_compute_health_check.http_health_check.id]

  # Attach the Cloud Armor WAF policy — all traffic is inspected before
  # reaching the Tomcat MIG (OWASP Top 10 + rate limiting + Adaptive Protection)
  security_policy = google_compute_security_policy.vprofile_waf.id

  # ── Cloud CDN ──────────────────────────────────────────────────────────────
  # Caches static assets (CSS, JS, images, fonts) at Google's global edge PoPs.
  # Static requests are served from cache and never hit the Tomcat MIG.
  # Dynamic requests (JSP pages, login, API calls) always pass through.
  enable_cdn = true

  cdn_policy {
    cache_mode       = "CACHE_ALL_STATIC" # Auto-detects static MIME types and caches them
    default_ttl      = 3600               # 1 hour — how long edge caches the object
    max_ttl          = 86400              # 24 hours — ceiling if origin sets a longer TTL
    client_ttl       = 3600              # 1 hour — browser-side cache TTL
    negative_caching = true              # Cache 404s to protect Tomcat from repeated misses

    cache_key_policy {
      include_host         = true  # Separate cache per hostname (good for wildcard cert setup)
      include_protocol     = true  # Separate cache for HTTP vs HTTPS
      include_query_string = false # Ignore query strings for static files (?v=123 won't bypass cache)
    }
  }

  backend {
    group           = var.instance_group
    balancing_mode  = "UTILIZATION"
    max_utilization = 0.8
  }
}

resource "google_compute_url_map" "url_map" {
  name            = "vprofile-url-map"
  default_service = google_compute_backend_service.backend_service.id
}

resource "google_compute_target_https_proxy" "https_proxy" {
  name            = "vprofile-target-https-proxy"
  url_map         = google_compute_url_map.url_map.id
  certificate_map = "//certificatemanager.googleapis.com/${var.certificate_map_id}"
}


resource "google_compute_global_forwarding_rule" "https_forwarding_rule" {
  name                  = "vprofile-https-forwarding-rule"
  ip_address            = google_compute_global_address.global_ip.id
  ip_protocol           = "TCP"
  port_range            = "443"
  target                = google_compute_target_https_proxy.https_proxy.id
  load_balancing_scheme = "EXTERNAL_MANAGED"
}


resource "google_compute_url_map" "redirect_url_map" {
  name = "vprofile-redirect-url-map"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "http_proxy" {
  name    = "vprofile-target-http-proxy"
  url_map = google_compute_url_map.redirect_url_map.id
}

resource "google_compute_global_forwarding_rule" "http_forwarding_rule" {
  name                  = "vprofile-http-forwarding-rule"
  ip_address            = google_compute_global_address.global_ip.id
  ip_protocol           = "TCP"
  port_range            = "80"
  target                = google_compute_target_http_proxy.http_proxy.id
  load_balancing_scheme = "EXTERNAL_MANAGED"
}