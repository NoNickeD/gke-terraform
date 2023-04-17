variable "region" {
  type    = string
  default = "europe-north1"
}

variable "project_id" {
  type    = string
  default = "gke-14042023133624-test"
}

variable "cluster_name" {
  type    = string
  default = "gke-test"
}

variable "min_node_count" {
  type    = number
  default = 1
}

variable "max_node_count" {
  type    = number
  default = 3
}

variable "machine_type" {
  type    = string
  default = "e2-standard-2"
}

variable "preemptible" {
  type    = bool
  default = true
}

variable "state_bucket" {
  type    = string
}

variable "environment" {
  type        = string
  description = "Environment name (test, preprod, or prod)"
  validation {
    condition     = contains(["test", "preprod", "prod"], var.environment)
    error_message = "The environment value must be one of: test, preprod, or prod."
  }
}

variable "created_by" {
  type = string
  default = "terraform"
}

variable "owner" {
  type = string
  default = "nikolkakisn"
}

variable "k8s_version" {
  type = string
  description = "For example: 1.25.8-gke.500"
}
