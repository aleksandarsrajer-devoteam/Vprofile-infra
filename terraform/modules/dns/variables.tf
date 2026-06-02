variable "project_id" {
  type        = string
  description = "The GCP Project ID"
}

variable "vpc_id" {
  type        = string
  description = "The self_link of the VPC network"
}

variable "db_private_ip" {
  type        = string
  description = "The private IP of the Cloud SQL instance"
}

variable "memcached_host" {
  type        = string
  description = "The host/IP of the Memcached node"
}