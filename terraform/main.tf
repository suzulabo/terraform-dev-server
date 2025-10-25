terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.35"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

resource "google_project_service" "compute" {
  project = var.project_id
  service = "compute.googleapis.com"

  disable_on_destroy = false
}

resource "google_compute_instance" "dev_server" {
  name         = var.instance_name
  machine_type = var.machine_type

  depends_on = [
    google_project_service.compute,
  ]

  tags = ["dev-server"]

  boot_disk {
    initialize_params {
      image = var.boot_image
      size  = var.boot_disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = "default"

    access_config {
      // Ephemeral external IP address
    }
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  metadata_startup_script = trimspace(var.startup_script) == "" ? null : var.startup_script

  scheduling {
    preemptible       = false
    automatic_restart = true
  }
}

resource "google_compute_firewall" "dev_server_ports" {
  name    = "${var.instance_name}-allowed-ports"
  network = "default"

  depends_on = [
    google_project_service.compute,
  ]

  allow {
    protocol = "tcp"
    ports    = var.allowed_ports
  }

  source_ranges = var.allowed_source_ranges
  target_tags   = ["dev-server"]
}

output "instance_external_ip" {
  description = "The external IPv4 address of the development VM."
  value       = google_compute_instance.dev_server.network_interface[0].access_config[0].nat_ip
}

output "instance_zone" {
  description = "Zone where the instance was created."
  value       = google_compute_instance.dev_server.zone
}

output "instance_name" {
  description = "Name of the development VM."
  value       = google_compute_instance.dev_server.name
}

output "project_id" {
  description = "Project that owns the resources."
  value       = var.project_id
}
