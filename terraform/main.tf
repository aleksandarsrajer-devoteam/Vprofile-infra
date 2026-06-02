module "network" {
  source      = "./modules/vpc"
  vpc_name    = var.vpc_name
  subnet_cidr = var.subnet_cidr
  region      = var.region
}

# Stores the DB password securely in Secret Manager.
# VMs retrieve it at runtime via gcloud — the plaintext never appears in metadata or state.
module "secrets" {
  source      = "./modules/secret_manager"
  project_id  = var.project_id
  db_password = var.db_password

  depends_on = [module.network]
}

module "database" {
  source      = "./modules/database"
  vpc_id      = module.network.vpc_id
  vpc_name    = var.vpc_name
  region      = var.region
  db_password = var.db_password 

  depends_on = [module.network]
}

module "db_initializer" {
  source        = "./modules/db_initializer"
  subnet_id     = module.network.subnet_id
  zone          = var.zone
  db_private_ip = module.database.db_private_ip
  project_id    = var.project_id
  db_secret_id  = module.secrets.secret_id # Passes the secret NAME, not the password itself

  depends_on = [module.network, module.database, module.secrets]
}

module "dns" {
  source         = "./modules/dns"
  project_id     = var.project_id
  vpc_id         = module.network.vpc_id
  db_private_ip  = module.database.db_private_ip
  memcached_host = module.database.memcached_node_ips[0]
  depends_on     = [module.network, module.database]
}


module "compute" {
  source        = "./modules/compute"
  zone          = var.zone
  region        = var.region
  subnet_id     = module.network.subnet_id
  project_id    = var.project_id
  db_secret_id  = module.secrets.secret_id # Passes the secret NAME, not the password itself

  depends_on = [module.network, module.database, module.secrets]
}

module "certificates" {
  source      = "./modules/certificates"
  domain_name = var.domain
}

module "load_balancer" {
  source             = "./modules/load_balancer"
  instance_group     = module.compute.instance_group
  certificate_map_id = module.certificates.certificate_map_id
}
