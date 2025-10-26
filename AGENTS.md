# Agent Notes

## Overview
- Terraform configuration provisioning a GCE dev VM (`c4a-standard-1` Spot in `asia-northeast1-c`) with a persistent Hyperdisk mounted at `/mnt/persist`.
- Tooling is expected to run via Docker Compose; Terraform commands are wrapped in pnpm scripts in `package.json`.
- Node project uses ESM (`"type": "module"`); see `scripts/run-instance-action.js` for shared gcloud invocations.

## Key Paths
- `terraform/` – main Terraform configuration (`main.tf`, `variables.tf`, `terraform.tfvars.example`). Persistent disk resource is `google_compute_disk.persist_disk`.
- `docker-compose.yml` – defines `terraform` and `gcloud` helper containers.
- `scripts/run-instance-action.js` – orchestrates SSH and lifecycle actions (requires Node ≥18).
- Persistent auth/key material lives in `gcp-auth/` and `gcloud-ssh/` (both gitignored).

## Common Commands (pnpm)
- `pnpm run gcp:login` – `gcloud auth login`.
- `pnpm run gcp:login-app` – `gcloud auth application-default login` (needed before Terraform).
- `pnpm run tf:init | tf:plan | tf:apply` – manage infrastructure via Dockerized Terraform.
- `pnpm run tf:destroy` – removes VM + firewall only; disk guarded by `prevent_destroy`.
- `pnpm run tf:ssh | tf:stop | tf:start | tf:suspend | tf:resume` – gcloud instance lifecycle helpers.

## Terraform Notes
- `google_compute_disk.persist_disk` has `prevent_destroy = true`; a full `terraform destroy` without targeting will fail unless this is overridden.
- Boot disk defaults to Hyperdisk Balanced with `auto_delete = false`. Persistent disk defaults to 10 GB (`persist_disk_size_gb`).
- Startup script mounts the persistent disk at `/mnt/persist`, adds a 2 GB swapfile, sets `vm.swappiness=10`, enforces `Asia/Tokyo` timezone, and installs GitHub CLI if missing.

## Workflow Tips
- Make sure `terraform.tfvars` (copied from the example) sets `project_id` and narrows firewall CIDRs before applying.
- Docker Compose commands assume local directories `gcp-auth/` and `gcloud-ssh/` already exist (create with `mkdir -p`).
- When updating lifecycle/process scripts, maintain compatibility with the ESM setting in `package.json`.

## /init?
- The Codex CLI `/init` command is not required for this repository; only run it if you explicitly need to reset the environment per project guidelines.
