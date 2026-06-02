terraform {
  backend "gcs" {
    bucket = "vprofile-tfstate"
    prefix = "terraform/tfstate"
  }
}