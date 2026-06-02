resource "google_compute_security_policy" "vprofile_waf" {
  name        = "vprofile-waf-policy"
  description = "Cloud Armor WAF + DDoS policy for VProfile (OWASP Top 10 + rate limiting)"
  type        = "CLOUD_ARMOR"

  # ── Adaptive Protection ────────────────────────────────────────────────────
  # ML-based layer-7 DDoS detection — automatically flags anomalous traffic
  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable          = true
      rule_visibility = "STANDARD"
    }
  }

  # ── Rule 2000: SQL Injection (OWASP A03) ──────────────────────────────────
  rule {
    priority    = 2000
    action      = "deny(403)"
    description = "Block SQL injection attempts — OWASP ModSecurity CRS sqli-v33-stable"

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-v33-stable')"
      }
    }
  }

  # ── Rule 2001: Cross-Site Scripting (OWASP A03) ───────────────────────────
  rule {
    priority    = 2001
    action      = "deny(403)"
    description = "Block XSS attempts — OWASP ModSecurity CRS xss-v33-stable"

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-v33-stable')"
      }
    }
  }

  # ── Rule 2002: Local File Inclusion ───────────────────────────────────────
  rule {
    priority    = 2002
    action      = "deny(403)"
    description = "Block LFI attempts — OWASP ModSecurity CRS lfi-v33-stable"

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('lfi-v33-stable')"
      }
    }
  }

  # ── Rule 2003: Remote File Inclusion ──────────────────────────────────────
  rule {
    priority    = 2003
    action      = "deny(403)"
    description = "Block RFI attempts — OWASP ModSecurity CRS rfi-v33-stable"

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rfi-v33-stable')"
      }
    }
  }

  # ── Rule 2004: Remote Code Execution (OWASP A03) ──────────────────────────
  rule {
    priority    = 2004
    action      = "deny(403)"
    description = "Block RCE attempts — OWASP ModSecurity CRS rce-v33-stable"

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rce-v33-stable')"
      }
    }
  }

  # ── Rule 2005: Scanner & Bot Detection ────────────────────────────────────
  rule {
    priority    = 2005
    action      = "deny(403)"
    description = "Block known vulnerability scanners (Nmap, Nikto, etc.)"

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('scannerdetection-v33-stable')"
      }
    }
  }



  # ── Rule 3000: Rate Limiting (DDoS / brute-force protection) ──────────────
  # Throttles any single IP that fires more than 100 requests in 60 seconds.
  # conform_action = allow under the limit; exceed_action = HTTP 429 over it.
  rule {
    priority    = 3000
    action      = "throttle"
    description = "Rate-limit IPs exceeding 100 req/60s — DDoS and brute-force protection"

    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }

    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"

      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }

      enforce_on_key = "IP"
    }
  }

  # ── Default Rule (required) ────────────────────────────────────────────────
  # Priority 2147483647 is the reserved "catch-all" slot in Cloud Armor.
  # Everything not matched by rules above is allowed through to the backend.
  rule {
    priority    = 2147483647
    action      = "allow"
    description = "Default allow — traffic not matched by any rule above passes through"

    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }
}
