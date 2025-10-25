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

locals {
  base_startup_script = <<-EOT
    #!/usr/bin/env bash
    set -euxo pipefail

    if [ ! -f /swapfile ]; then
      fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
      chmod 600 /swapfile
      mkswap /swapfile
    fi

    if ! swapon --show=NAME --noheadings | grep -q '^/swapfile$'; then
      swapon /swapfile
    fi

    if ! grep -q '^/swapfile ' /etc/fstab; then
      echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi

    cat <<'SYSCTL' >/etc/sysctl.d/99-dev-server.conf
    vm.swappiness = 10
    SYSCTL

    sysctl -p /etc/sysctl.d/99-dev-server.conf

    DEVICE_PATH="/dev/disk/by-id/google-dev-home"
    TEMP_MOUNT="/mnt/dev-home"
    TARGET_MOUNT="/home"

    for _ in $(seq 1 30); do
      if [ -b "$DEVICE_PATH" ]; then
        break
      fi
      sleep 1
    done

    if [ -b "$DEVICE_PATH" ]; then
      FSTYPE=$(lsblk -no FSTYPE "$DEVICE_PATH" || true)
      if [ -z "$FSTYPE" ]; then
        mkfs.ext4 -F "$DEVICE_PATH"
      fi

      DISK_UUID=$(blkid -s UUID -o value "$DEVICE_PATH")

      if ! grep -q "$DISK_UUID" /etc/fstab; then
        mkdir -p "$TEMP_MOUNT"
        mount "$DEVICE_PATH" "$TEMP_MOUNT"
        rsync -a "${TARGET_MOUNT}/." "${TEMP_MOUNT}/."
        umount "$TEMP_MOUNT"
        printf 'UUID=%s %s ext4 defaults 0 2\n' "$DISK_UUID" "$TARGET_MOUNT" >> /etc/fstab
      fi

      if ! mountpoint -q "$TARGET_MOUNT"; then
        mount "$TARGET_MOUNT"
      fi

      chmod 755 "$TARGET_MOUNT"
    else
      echo "Persistent disk ${DEVICE_PATH} not found; skipping home mount" >&2
    fi
  EOT

  user_startup_script = trimspace(var.startup_script)

  combined_startup_script = trimspace(local.user_startup_script == "" ? local.base_startup_script : "${local.base_startup_script}\n\n${local.user_startup_script}")
}

resource "google_project_service" "compute" {
  project = var.project_id
  service = "compute.googleapis.com"

  disable_on_destroy = false
}

resource "google_compute_disk" "dev_home" {
  name = "${var.instance_name}-home"
  type = "hyperdisk-balanced"
  zone = var.zone
  size = var.home_disk_size_gb

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_compute_instance" "dev_server" {
  name         = var.instance_name
  machine_type = var.machine_type

  depends_on = [
    google_project_service.compute,
    google_compute_disk.dev_home,
  ]

  tags = ["dev-server"]

  boot_disk {
    initialize_params {
      image = var.boot_image
      size  = var.boot_disk_size_gb
      type  = "hyperdisk-balanced"
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

  metadata_startup_script = local.combined_startup_script == "" ? null : local.combined_startup_script

  scheduling {
    provisioning_model  = "SPOT"
    preemptible         = true
    automatic_restart   = false
    on_host_maintenance = "TERMINATE"
  }

  attached_disk {
    source      = google_compute_disk.dev_home.id
    device_name = "dev-home"
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
