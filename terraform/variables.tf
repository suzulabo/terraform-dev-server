variable "project_id" {
  description = "The GCP project ID where resources will be created."
  type        = string
}

variable "region" {
  description = "Default region for regional resources."
  type        = string
  default     = "us-west1"
}

variable "zone" {
  description = "Zone where the VM instance will run."
  type        = string
  default     = "us-west1-b"
}

variable "instance_name" {
  description = "Name assigned to the development VM."
  type        = string
  default     = "dev-vscode"
}

variable "machine_type" {
  description = "GCE machine type. e2-micro is covered by the Always Free tier in eligible regions."
  type        = string
  default     = "e2-micro"
}

variable "boot_disk_size_gb" {
  description = "Size of the boot disk in GB."
  type        = number
  default     = 30
}

variable "boot_image" {
  description = "Source image used to initialize the boot disk."
  type        = string
  default     = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
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
  description = "Optional startup script to configure the VM (leave empty to skip)."
  type        = string
  default     = ""
}
