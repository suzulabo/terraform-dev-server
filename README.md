# terraform-dev-server

Terraform configuration that provisions a Google Compute Engine VM (defaulting to a `c4a-standard-1` Spot instance in `asia-northeast1`) to host a VS Code Dev Server prototype.

## Prerequisites

- Docker and Docker Compose
- Access to the GCP project `suzulabo-playground`

## Directory layout

```
./terraform          # Terraform configuration
./gcp-auth           # (created locally) persisted gcloud credentials
./gcloud-ssh         # (created locally) persisted SSH key material
docker-compose.yml   # Helper services for terraform & gcloud CLIs
```

Create the credentials folder once (kept out of git via `.gitignore`):

```bash
mkdir -p gcp-auth gcloud-ssh
chmod 700 gcloud-ssh
```

## Authenticate with GCP (persisted locally)

Run gcloud inside the Docker container so authentication files end up in `./gcp-auth` and can be reused by Terraform:

```bash
# Interactive browser login (writes Application Default Credentials)
docker compose run --rm gcloud "gcloud auth application-default login"

# (Optional) standard gcloud login for CLI use while debugging
docker compose run --rm gcloud "gcloud auth login"
```

The mounted `gcp-auth` directory keeps the generated tokens and JSON files so future terraform runs can reuse them without re-authenticating.

## Configure Terraform variables

Copy and adjust the sample vars file:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Set at least `project_id` if your project differs, and tighten `allowed_source_ranges` to your public IP (recommended before exposing dev servers). By default the configuration uses `asia-northeast1-c`, `c4a-standard-1`, the ARM64 Ubuntu 22.04 LTS image, a 10 GB Hyperdisk Balanced boot disk, and the Spot provisioning model; override these variables in `terraform.tfvars` if you prefer a different region, machine size, image, disk type/size, or need on-demand capacity.

## Run Terraform via Docker

All commands execute inside the official `hashicorp/terraform` container with the current repo mounted in:

```bash
# Initialize providers and backends
docker compose run --rm terraform init

# Review the changes that will be applied
docker compose run --rm terraform plan

# Create / update the VM
docker compose run --rm terraform apply

# Tear everything down when finished (keeps the persistent home disk)
docker compose run --rm terraform destroy -target google_compute_instance.dev_server -target google_compute_firewall.dev_server_ports
```

Terraform state files are stored inside `./terraform`, so they stay on your machine.

## SSH into the VM

After `terraform apply` succeeds, reuse the recorded outputs to open an interactive shell:

```bash
npm run tf:ssh
```

(Replace `npm` with your preferred package manager command, e.g. `pnpm`.) The helper script looks up the project, zone, and instance name from Terraform state, then launches `gcloud compute ssh` inside the Docker container.
SSH keys are cached inside `./gcloud-ssh`, so you will not be prompted to regenerate them on each run.
Pass additional SSH flags by appending them after `--`, for example `npm run tf:ssh -- -- -L 8080:localhost:8080`.

## Start/stop the VM

Use the cached Terraform outputs to control power state without retyping identifiers:

```bash
npm run tf:stop     # stop the instance (shuts down)
npm run tf:start    # start after a full stop
npm run tf:suspend  # suspend to disk (beta feature, billed for storage only)
npm run tf:resume   # resume a suspended instance
```

Each command runs the appropriate `gcloud compute instances` action inside the Docker container with `--quiet` to avoid confirmation prompts.

## Persistent home volume

A 10 GB Hyperdisk Balanced volume (`${instance_name}-home`) is created and attached to the VM. On first boot the startup script formats it, migrates the current `/home` contents, and mounts the disk directly at `/home` so all user profiles and dev data live on the persistent volume.

When you run `npm run tf:destroy` (or the equivalent compose command shown above), Terraform only deletes the VM and firewall rule; the home volume remains intact. A `prevent_destroy = true` lifecycle guard on the disk also blocks accidental removal if you ever run a full `terraform destroy`. Reapply later and Terraform will reattach and reuse the same disk.

To remove the disk permanently, delete it explicitly:

```bash
docker compose run --rm terraform destroy -target google_compute_disk.dev_home -auto-approve
# or remove the lifecycle guard temporarily and run a full destroy
# or
docker compose run --rm gcloud "gcloud compute disks delete dev-vscode-home --zone asia-northeast1-c"
```

## Next steps

The VM uses Ubuntu 22.04 LTS by default. A 2 GB swapfile and `vm.swappiness=10` are provisioned automatically on first boot. You can append your own bootstrap commands (for example, to install VS Code Dev Server) by setting the `startup_script` variable in `terraform.tfvars`—your script runs after the swap configuration. Keep ports locked down to your IP whenever you expose dev tooling.
