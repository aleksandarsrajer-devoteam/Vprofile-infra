module "network" {
  source      = "./modules/vpc"
  vpc_name    = var.vpc_name
  subnet_cidr = var.subnet_cidr
  region      = var.region
}

module "database" {
  source      = "./modules/database"
  vpc_id      = module.network.vpc_id
  vpc_name    = var.vpc_name
  region      = var.region
  db_password = "GcpVproSqlAdmin9040" # U produkciji ovo vuces iz tajnog fajla ili Vault-a

  depends_on = [module.network]
}

module "db_initializer" {
  source        = "./modules/db_initializer"
  subnet_id     = module.network.subnet_id
  zone          = var.zone
  db_private_ip = module.database.db_private_ip
  db_password   = "GcpVproSqlAdmin9040" # U produkciji ovo vuces iz tajnog fajla ili Vault-a
  depends_on    = [module.network, module.database]
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
  source    = "./modules/compute"
  zone      = var.zone
  region    = var.region
  subnet_id = module.network.subnet_id

  depends_on = [module.network, module.database]
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


