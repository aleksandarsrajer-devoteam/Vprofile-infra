variable "vpc_name" {
  type        = string
  description = "The name of our VPC"
}

variable "subnet_cidr" {
  type        = string
  description = "IP range of our private subnet (npr. 172.20.1.0/24)"
}

variable "region" {
  type        = string
  description = "Region where we are creating a vpc"
}

variable "gcp_apis" {
  type = list(string)
  default = [
    "compute.googleapis.com",
    "dns.googleapis.com",
    "sqladmin.googleapis.com",
    "memcache.googleapis.com",
    "servicenetworking.googleapis.com",
    "certificatemanager.googleapis.com"
  ]
}