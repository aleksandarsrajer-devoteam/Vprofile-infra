variable "project_id" {
  type        = string
  description = "The id of our project on GCP"
}

variable "region" {
  type        = string
  description = "The region of our vprofile project on GCP"
}

variable "zone" {
  type        = string
  description = "The primary availability zone"
}

variable "vpc_name" {
  type        = string
  description = "The name of the VPC network used for resource naming prefix"
}

variable "subnet_cidr" {
  type = string
  description = "The CIDR Range of subnet"
}

variable "domain" {
  type = string
  description = "Domain of our project"
}
