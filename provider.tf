provider "google" {
  credentials = file("gkesa_acc.json")
  project     = var.project_id
  region      = var.region
}