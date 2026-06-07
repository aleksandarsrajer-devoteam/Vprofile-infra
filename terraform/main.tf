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


module "dns" {
  source         = "./modules/dns"
  project_id     = var.project_id
  vpc_id         = module.network.vpc_id
  db_private_ip  = module.database.db_private_ip
  memcached_host = module.database.memcached_node_ips[0]
  depends_on     = [module.network, module.database]
}


module "compute" {
  source                = "./modules/compute"
  zone                  = var.zone
  region                = var.region
  subnet_id             = module.network.subnet_id
  project_id            = var.project_id
  db_secret_id          = module.secrets.secret_id
  artifacts_bucket_name = module.github_actions_wif.artifacts_bucket_name

  depends_on = [module.network, module.database, module.secrets, module.github_actions_wif]
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

# ── Workload Identity Federation ──────────────────────────────────────────────
# Enables GitHub Actions to authenticate to GCP without SA key files.
# After terraform apply, run: terraform output -module=github_actions_wif
# Copy the two output values into GitHub Secrets: WIF_PROVIDER + GH_ACTIONS_SA
module "github_actions_wif" {
  source              = "./modules/github_actions_wif"
  project_id          = var.project_id
  region              = var.region
  tfstate_bucket_name = "vprofile-tfstate"
}


