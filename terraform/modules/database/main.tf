resource "google_sql_database_instance" "mysql_instance" {
  name             = "${var.vpc_name}-mysql-db"
  database_version = "MYSQL_8_0"
  region           = var.region

  deletion_protection = false

  settings {
    tier = "db-f1-micro" # Shared-core machine instance type, ideal for sandbox/testing

    ip_configuration {
      ipv4_enabled    = false      # Disables public IP address completely
      private_network = var.vpc_id # injects the database into our VPC via PSA Peering
    }
  }
}

resource "google_sql_database" "accounts_db" {
  name     = "accounts"
  instance = google_sql_database_instance.mysql_instance.name
}

# 3. MySQL Root User Configuration
resource "google_sql_user" "root_user" {
  name     = "root"
  instance = google_sql_database_instance.mysql_instance.name
  host     = "%" # Allows internal connections from any private IP within the VPC
  password = var.db_password
}

resource "google_memcache_instance" "memcached" {
  name               = "${var.vpc_name}-memcached"
  region             = var.region
  authorized_network = var.vpc_id # Restricts access exclusively to resources inside our VPC

  node_config {
    cpu_count      = 2
    memory_size_mb = 2048 # 2GB of RAM allocation
  }
  node_count = 1
}