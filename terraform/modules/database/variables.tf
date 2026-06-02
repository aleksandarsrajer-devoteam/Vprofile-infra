variable "vpc_id" {
  type        = string
  description = "The ID  of the VPC network"
}

variable "vpc_name" {
  type        = string
  description = "The name of the VPC network used for resource naming prefix"
}

variable "region" {
  type        = string
  description = "The GCP region where the database resources will reside"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "The root password for the MySQL database instance"
}