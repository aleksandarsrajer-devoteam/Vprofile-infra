resource "google_project_service" "enabled_apis" {
  for_each           = toset(var.gcp_apis)
  service            = each.key
  disable_on_destroy = false
}

resource "google_compute_network" "main_vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false

  depends_on = [google_project_service.enabled_apis]

}

resource "google_compute_subnetwork" "private_subnet" {
  name                     = "${var.vpc_name}-private-subnet"
  ip_cidr_range            = var.subnet_cidr
  network                  = google_compute_network.main_vpc.self_link
  region                   = var.region
  private_ip_google_access = true
}

resource "google_compute_router" "nat_router" {
  name    = "${var.vpc_name}-nat-router"
  region  = var.region
  network = google_compute_network.main_vpc.id
}

resource "google_compute_router_nat" "cloud_nat" {
  name                               = "${var.vpc_name}-cloud-nat"
  router                             = google_compute_router.nat_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS" //Witch subnetworks are allowed to nat, specified bellow in subnetworks

  subnetwork {
    name                    = google_compute_subnetwork.private_subnet.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "${var.vpc_name}-allow-iap-ssh"
  network = google_compute_network.main_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Official Google Cloud IAP source IP range
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["vprofile-app-node"]
}

resource "google_compute_firewall" "allow_lb_to_app" {
  name    = "${var.vpc_name}-allow-lb-to-app"
  network = google_compute_network.main_vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["vprofile-app-node"]
}

resource "google_compute_global_address" "private_ip_alloc" {
  name          = "${var.vpc_name}-private-ip-alloc"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.main_vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.main_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]

  depends_on = [google_project_service.enabled_apis]
}


