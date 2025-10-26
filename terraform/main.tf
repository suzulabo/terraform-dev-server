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

resource "google_compute_disk" "persist_disk" {
  name = "${var.persist_disk_name}"
  type = "hyperdisk-balanced"
  zone = var.zone
  size = var.persist_disk_size_gb

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_compute_instance" "dev_server" {
  name         = var.instance_name
  machine_type = var.machine_type

  depends_on = [
    google_project_service.compute,
    google_compute_disk.persist_disk,
  ]

  tags = ["dev-server"]

  boot_disk {
    initialize_params {
      image = var.boot_image
      size  = var.boot_disk_size_gb
      type  = "hyperdisk-balanced"
    }
    auto_delete = false
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

  metadata_startup_script = <<-EOT
    #!/bin/bash
    set -e
    DISK_ID="/dev/disk/by-id/google-persist-disk"
    MNT_DIR=/mnt/persist

    # マウント準備
    if ! grep -qs "$${DISK_ID}" /proc/mounts; then
      mkfs.ext4 -F $${DISK_ID}
      mkdir -p $${MNT_DIR}
      mount $${DISK_ID} $${MNT_DIR}
      echo "$${DISK_ID} $${MNT_DIR} ext4 defaults 0 2" >> /etc/fstab
    fi

    # swapを追加（開発用：2GB）
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab

    # swapの利用頻度を低くする
    sysctl vm.swappiness=10
    echo 'vm.swappiness=10' >> /etc/sysctl.conf

    timedatectl set-timezone "Asia/Tokyo"
  EOT

  scheduling {
    provisioning_model  = "SPOT"
    preemptible         = true
    automatic_restart   = false
    on_host_maintenance = "TERMINATE"
  }

  attached_disk {
    source      = google_compute_disk.persist_disk.id
    device_name = "persist-disk"
    mode        = "READ_WRITE"
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
