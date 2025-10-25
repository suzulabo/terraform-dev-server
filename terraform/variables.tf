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
  default     = "dev-vscode"
}

variable "machine_type" {
  description = "GCE machine type for the development VM."
  type        = string
  default     = "c4a-standard-1"
}

variable "boot_disk_size_gb" {
  description = "Size of the boot disk in GB."
  type        = number
  default     = 10
}

variable "home_disk_size_gb" {
  description = "Size of the persistent Hyperdisk Balanced volume mounted at /home."
  type        = number
  default     = 10
}

variable "boot_image" {
  description = "Source image used to initialize the boot disk."
  type        = string
  default     = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts-arm64"
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

variable "startup_script" {
  description = "Optional script appended after the default swap setup; leave empty to accept only the built-in configuration."
  type        = string
  default     = ""
}
