variable "project_id" {
  description = "The GCP project ID where resources will be created."
  type        = string
}

variable "region" {
  description = "Default region for regional resources."
  type        = string
  default     = "asia-northeast1"
}

variable "zone" {
  description = "Zone where the VM instance will run."
  type        = string
  default     = "asia-northeast1-c"
}

variable "instance_name" {
  description = "Name assigned to the development VM."
  type        = string
  default     = "dev-vscode-arm64"
}

variable "machine_type" {
  description = "GCE machine type for the development VM."
  type        = string
  default     = "c4a-standard-4"
}

variable "boot_disk_size_gb" {
  description = "Size of the boot disk in GB."
  type        = number
  default     = 20
}

variable "boot_image" {
  description = "Source image used to initialize the boot disk."
  type        = string
  default     = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2404-lts-arm64"
}

variable "allowed_ports" {
  description = "List of TCP ports opened to the internet for the dev server."
  type        = list(string)
  default     = ["22", "8080"]
}

variable "allowed_source_ranges" {
  description = "CIDR ranges that may reach the exposed ports."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "persist_disk_name" {
  description = "Name of the persistent Hyperdisk Balanced volume."
  type        = string
  default     = "dev-vscode-persist"
}

variable "persist_disk_size_gb" {
  description = "Size of the persistent Hyperdisk Balanced volume."
  type        = number
  default     = 10
}

variable "provisioning_model" {
  description = "Provisioning model for the VM scheduling policy (e.g., SPOT or STANDARD)."
  type        = string
  default     = "SPOT"
}
