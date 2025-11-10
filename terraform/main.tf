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
  is_spot_instance = upper(var.provisioning_model) == "SPOT"
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

  service_account {
    email  = "default"
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

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
    set -euo pipefail

    # ---------- Mount persist disk ----------
    DISK_ID="/dev/disk/by-id/google-persist-disk"
    MNT_DIR="/mnt/persist"

    # Format persist disk
    if ! blkid "$DISK_ID" >/dev/null 2>&1; then
      echo "[INFO] Formatting new persist disk: $DISK_ID"
      mkfs.ext4 -F "$DISK_ID"
    else
      echo "[INFO] Existing filesystem detected on $DISK_ID — skip format"
    fi

    mkdir -p "$MNT_DIR"

    # Append persist disk to fstab
    if ! grep -qs "$DISK_ID" /etc/fstab; then
      echo "$DISK_ID $MNT_DIR ext4 defaults 0 2" >> /etc/fstab
    fi

    # Mount persist disk
    if ! mountpoint -q "$MNT_DIR"; then
      mount "$DISK_ID" "$MNT_DIR"
    fi

    echo "[OK] persist disk mounted at $MNT_DIR"

    # ---------- Add swap (2GB) ----------
    if ! swapon --show | grep -q "/swapfile"; then
      echo "[INFO] Creating swapfile"
      fallocate -l 2G /swapfile
      chmod 600 /swapfile
      mkswap /swapfile
      swapon /swapfile
      if ! grep -qs '/swapfile' /etc/fstab; then
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
      fi
    else
      echo "[INFO] Swapfile already active"
    fi

    # ---------- vm.swappiness ----------
    if ! grep -qs 'vm.swappiness=10' /etc/sysctl.conf; then
      echo "[INFO] Setting vm.swappiness=10"
      sysctl vm.swappiness=10
      echo 'vm.swappiness=10' >> /etc/sysctl.conf
    fi

    # ---------- Timezone ----------
    if [ "$(timedatectl show -p Timezone --value)" != "Asia/Tokyo" ]; then
      echo "[INFO] Setting timezone to Asia/Tokyo"
      timedatectl set-timezone "Asia/Tokyo"
    fi

    # ---------- Install gh ----------
    if ! command -v gh >/dev/null 2>&1; then
      echo "[INFO] Installing GitHub CLI"
      (type -p wget >/dev/null || (apt-get update && apt-get install wget -y)) \
        && mkdir -p -m 755 /etc/apt/keyrings \
        && out=$(mktemp) && wget -nv -O "$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        && cat "$out" | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null \
        && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
        && mkdir -p -m 755 /etc/apt/sources.list.d \
        && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list >/dev/null \
        && apt-get update \
        && apt-get install gh -y
    else
      echo "[INFO] GitHub CLI already installed"
    fi

    # ---------- Install Google Cloud Ops Agent ----------
    if ! dpkg -s google-cloud-ops-agent >/dev/null 2>&1; then
      echo "[INFO] Installing Google Cloud Ops Agent"
      curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
      bash add-google-cloud-ops-agent-repo.sh --also-install
      rm -f add-google-cloud-ops-agent-repo.sh
    else
      echo "[INFO] Google Cloud Ops Agent already installed"
    fi

    # ---------- Install docker ----------
    if [ ! -e /var/lib/docker/volumes ]; then
      mkdir -p /mnt/persist/docker/volumes
      mkdir -p /var/lib/docker
      ln -s /mnt/persist/docker/volumes /var/lib/docker
    fi
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh

    # --------------------
    echo "[SUCCESS] Startup script completed"
  EOT

  scheduling {
    provisioning_model        = var.provisioning_model
    preemptible               = local.is_spot_instance
    automatic_restart         = local.is_spot_instance ? false : true
    on_host_maintenance       = local.is_spot_instance ? "TERMINATE" : "MIGRATE"
    instance_termination_action = local.is_spot_instance ? "STOP" : null

    dynamic "max_run_duration" {
      for_each = local.is_spot_instance ? [1] : []
      content {
        seconds = 43200  # 12hours
      }
    }
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
