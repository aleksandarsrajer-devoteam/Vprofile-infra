variable "zone" {
  type        = string
  description = "The zone where instances will be launched"
}

variable "region" {
  type        = string
  description = "The region for the regional instance template and MIG"
}

variable "subnet_id" {
  type        = string
  description = "The ID of the private subnet where Tomcat servers will live"
}