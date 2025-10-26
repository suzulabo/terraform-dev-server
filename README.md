# terraform-dev-server

pnpm scripts for provisioning and operating the dev VM:

```bash
pnpm run gcp:login      # gcloud auth login (standard account login)
pnpm run gcp:login-app  # gcloud auth application-default login (ADC for Terraform)

pnpm run tf:init        # terraform init
pnpm run tf:plan        # terraform plan
pnpm run tf:apply       # terraform apply -auto-approve
pnpm run tf:destroy     # destroy VM + firewall (persistent disk is preserved)

pnpm run tf:ssh         # gcloud compute ssh into the instance
pnpm run tf:stop        # gcloud compute instances stop
pnpm run tf:start       # gcloud compute instances start
pnpm run tf:suspend     # gcloud compute instances suspend
pnpm run tf:resume      # gcloud compute instances resume
```
