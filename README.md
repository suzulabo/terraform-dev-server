# terraform-dev-server

Terraform configuration that provisions a minimal Google Compute Engine VM (Always Free tier compatible) to host a VS Code Dev Server prototype.

## Prerequisites

- Docker and Docker Compose
- Access to the GCP project `suzulabo-playground`

## Directory layout

```
./terraform          # Terraform configuration
./gcp-auth           # (created locally) persisted gcloud credentials
docker-compose.yml   # Helper services for terraform & gcloud CLIs
```

Create the credentials folder once (kept out of git via `.gitignore`):

```bash
mkdir -p gcp-auth
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

Set at least `project_id` if your project differs, and tighten `allowed_source_ranges` to your public IP (recommended before exposing dev servers).

## Run Terraform via Docker

All commands execute inside the official `hashicorp/terraform` container with the current repo mounted in:

```bash
# Initialize providers and backends
docker compose run --rm terraform init

# Review the changes that will be applied
docker compose run --rm terraform plan

# Create / update the VM
docker compose run --rm terraform apply

# Tear everything down when finished
docker compose run --rm terraform destroy
```

Terraform state files are stored inside `./terraform`, so they stay on your machine.

## Next steps

The VM uses Ubuntu 22.04 LTS by default. You can supply a bootstrap script (for example, to install VS Code Dev Server) by setting the `startup_script` variable in `terraform.tfvars`. Keep ports locked down to your IP whenever you expose dev tooling.
