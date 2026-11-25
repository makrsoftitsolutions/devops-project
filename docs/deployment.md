# Dev deployment runbook

1. Sign in to the intended personal Azure tenant with `az login`.
2. Select the personal subscription using `az account set`.
3. Confirm the subscription with `az account show`.
4. Confirm the pre-created state resource group, storage account and blob container.
5. Confirm the signed-in identity has Storage Blob Data Contributor on the state account/container.
6. Review `terraform/environments/dev/backend.hcl` and `terraform.tfvars`.
7. Run `terraform fmt -recursive`.
8. Run `terraform init -backend-config="backend.hcl" -reconfigure`.
9. Run `terraform validate` and `terraform plan`.
10. Review resource names, CIDRs, region, permissions and estimated costs.
11. Apply only after the plan is understood and approved.
12. Enable optional paid modules individually and re-run plan before applying.
