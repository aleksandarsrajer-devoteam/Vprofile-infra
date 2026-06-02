variable "subnet_id" {
  type        = string
  description = "The ID of the private subnet where the initializer VM will run"
}

variable "zone" {
  type        = string
  description = "The zone where the VM instance will be launched"
}

variable "db_private_ip" {
  type        = string
  description = "The private IP address of the Cloud SQL MySQL instance"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "The root password for the MySQL database"
}